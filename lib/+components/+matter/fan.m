classdef fan < matter.procs.f2f
    %FAN Generic fan model with an optional characterisic
    % This is a generic, dynamic model of a fan that is controlled by
    % setting a fan speed in RMP. The user therefore needs to enter a set
    % point for the fan speed as well as a string indicating the direction
    % in which the fan is blowing relative to the branch in which it is
    % contained. If desired, a fan characteristic can also be passed as a
    % parameter. For Information on how the characteristic has to be input,
    % see the description in this class' properties.
    %
    % WARNING: The default values of this fan model require it to run at
    % fairly high speeds, the inter- and extrapolation of values is done
    % using 40,000 and 75,000 RPM as anchor points.
    
    properties (SetAccess = public, GetAccess = public)
        % Setpoint for the speed of the fan in RPM
        fSpeedSetpoint = 0;
        
        % The power factor is a fan-specific figure of merit that is
        % dependent on the difference between the inlet and outlet
        % pressures. It is part of the calculation of the temperature
        % differences caused by the fan. It is rarely found in literature,
        % so it is assumed, that most sources set it to 1. We set the
        % default value to 0.95 because that works well with the default
        % fan characteristic.
        fPowerFactor = 0.95;
        
        % The internal efficiency of the fan describes the temperature
        % changes in the flow due to friction. It is also a fan-specific
        % figure of merit. The default value of 0.85 works well with the
        % default fan characteristic.
        fInternalEfficiency = 0.85;
        
        % This value is used to calculate the power draw from the fan. It
        % is also fan-specific.
        fElectricalEfficiency = 0.8;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Boolean variable determining if the fan is turned on at all
        bTurnedOn = false;
        
        % Power Consumtion of the fan in [W]
        fPowerConsumtionFan = 0;
        
        % This struct contains the data neccessary if you want to enter
        % your own characteristic. The default values correspond to the fan
        % used in NASA's PLSS 1.0 prototype. See AIAA-2011-5222. To get a
        % full characteristic of a fan, you need the function describing
        % the differential pressure the fan can produce depending on the
        % volumetric flow rate through the fan. This is usually determined
        % experimentally, so you'll probably need to do some curve fitting
        % to get the function. A third order polynomial is sufficient for
        % most fans. Since the differential pressure also depends on the
        % fan's speed, we need two polynomials for two different fan speeds
        % between which we can then interpolate. Lastly we also need the
        % environmental conditions at which the tests that generated the
        % data were performed.
        
        tCharacteristic = struct(...
            ...% Upper and speed and respective characteristic function
            'fSpeedUpper', 75000, ...
            'calculateUpperDeltaP', @(fVolumetricFlowRate) -9064144377.669 *  ((fVolumetricFlowRate).^3) + 9755592.99525*((fVolumetricFlowRate).^2) + 4716.6727883 *(fVolumetricFlowRate) + 2607, ...
            ...% Lower and speed and respective characteristic function
            'fSpeedLower', 40000, ...
            'calculateLowerDeltaP', @(fVolumetricFlowRate) -6727505231.41735 *  ((fVolumetricFlowRate).^3) - 7128360.09755 *((fVolumetricFlowRate).^2) + 33153.83752 * (fVolumetricFlowRate) + 752, ...
            ...% Pressure, temperature, gas constant and density of the gas
            ...% used during the determination of the characteristic
            'fTestPressure',    29649, ...      Pa
            'fTestTemperature',   294.26, ...   K
            'fTestGasConstant',   287.058, ...  J/kgK
            'fTestDensity',         0.3510, ... kg/m3
            'fZeroCrossingUpper',   0.007, ...  m^3/s
            'fZeroCrossingLower',   0.0048 ...  m^3/s
            );
        
        % Boolean variable to enable or disable the gradual pressure rise
        % after the fan is turned on. This prevents some solvers from
        % becoming unstable due to the large pressure spike produced by the
        % fan when starting at zero flow rate.
        bUsePressureRise = false;
        
        % Simulation time index when the state of this fan switched from
        % off to on. 
        fTurnOnTime = -1;
        
        % Boolean variable that stores the previous state of this fan.
        bPreviouslyOff = true;
        
        % Maximum delta pressure of the fan at the current speed setpoint
        fMaximumDeltaPressure;
        
        % Maximum volumetric flow rate of the fan at the current speed
        % setpoint. 
        fMaximumVolumetricFlowRate;
        
        % Maximum upper and lower volumetric flow rates of this fan with
        % the given characteristic. 
        fMaxFlowRateUpper;
        fMaxFlowRateLower;
    end
    
    methods
        function this = fan(oContainer, sName, fSpeedSetpoint, bUsePressureRise, tCharacteristic)
            % Constructor 
            % Required inputs: 
            % oContainer        Reference to the matter container this f2f
            %                   is created in
            % sName             Name as string 
            % fSpeedSetpoint    Fan speed setpoint in revolutions per
            %                   minute [RPM]
            % sDirection        String indicating in which direction the
            %                   fan is blowing. Can eiter be 'Left2Right'
            %                   or 'Right2Left'. This is with respect to
            %                   the positive flow direction of the branch
            %                   the fan is part of.
            %
            % Optional inputs: 
            % tCharacteristic   Struct containing characteristic 
            %                   information for a specific fan, see
            %                   properties.
            
            this@matter.procs.f2f(oContainer, sName);
            
            % tells solvers that this component produces a pressure rise
            this.bActive = true;
            
            % The user can opt to turn on a feature that gradually
            % increases the pressure rise created by this fan over one
            % second after it is turned on. 
            if nargin > 3
                this.bUsePressureRise = bUsePressureRise;
            end
            
            % If a specific characteristic is used, read in the data and
            % override the defaults
            if nargin > 4
                this.tCharacteristic = tCharacteristic;
            end
            
            % Calculating the maximum flow rates for the upper and lower
            % speeds, which is where the delta pressure is zero. So here we
            % have to find the zero crossing of the fan characteristics and
            % interpolate between them. The second input parameter to the
            % fzero() function is the starting point for the interpolation.
            this.fMaxFlowRateUpper = fzero(this.tCharacteristic.calculateUpperDeltaP, this.tCharacteristic.fZeroCrossingUpper);
            this.fMaxFlowRateLower = fzero(this.tCharacteristic.calculateLowerDeltaP, this.tCharacteristic.fZeroCrossingLower);
            
            % Setting the fan speed
            this.setFanSpeed(fSpeedSetpoint);
            
            % Support these two solver architectures - hydr used by the
            % linear solver, fct by the iterative.
            this.supportSolver('hydraulic', -1, 1, true, @this.solverDeltas);
            this.supportSolver('callback', @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        
        function switchOn(this)
            this.bTurnedOn = true;
            this.oBranch.setOutdated();
        end
        
        function switchOff(this)
            this.bTurnedOn = false;
            this.bPreviouslyOff = true;
            this.oBranch.setOutdated();
        end
        
        function setFanSpeed(this, fFanSpeed)
            %SETFANSPEED Sets a new speed setpoint
            
            % Setting the property
            this.fSpeedSetpoint = fFanSpeed;
            
            % Calculating the maximum delta pressure for this speed. This
            % occurs when the volumetric flow rate is zero. 
            this.fMaximumDeltaPressure = this.calculateDeltaPressure(0);
            
            % Calculating the maximum volumetric flow rate for the fan at
            % this speed.
            this.fMaximumVolumetricFlowRate = this.fMaxFlowRateLower + ...
                (this.fSpeedSetpoint - this.tCharacteristic.fSpeedLower) / ...
                (this.tCharacteristic.fSpeedUpper - this.tCharacteristic.fSpeedLower) * ...
                (this.fMaxFlowRateUpper - this.fMaxFlowRateLower);
        end
        
        function fDeltaPressure = calculateDeltaPressure(this, fVolumetricFlowRate)
            % Since the characteristic only has two specific speeds, we
            % need to interpolate between them.
            
            % Calculating the delta pressure for the lower end of the
            % characteristic
            fDeltaPressureLower  = this.tCharacteristic.calculateLowerDeltaP(fVolumetricFlowRate);
            
            % Calculating the delta pressure for the upper end of the
            % characteristic
            fDeltaPressureHigher = this.tCharacteristic.calculateUpperDeltaP(fVolumetricFlowRate);
            
            % Interpolating between the two using the fan speeds as a
            % linear reference.
            fDeltaPressure = fDeltaPressureLower + ...
                (this.fSpeedSetpoint - this.tCharacteristic.fSpeedLower ) / ...
                (this.tCharacteristic.fSpeedUpper - this.tCharacteristic.fSpeedLower) * ...
                (fDeltaPressureHigher - fDeltaPressureLower);
            
        end
        
        
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            
            
            % Switched off? No dP no matter what
            if ~this.bTurnedOn
                
                % VERY IMPORTANT! No flow -> no heat transfer!!
                this.fHeatFlow = 0;
                
                fDeltaPressure = 0;
                this.fDeltaPressure = fDeltaPressure;
                
                return;
            end
            
            [ oFlowIn, ~ ] = this.getFlows(fFlowRate);
            
            % Calculating the density of the incoming flowing matter
            fDensity = oFlowIn.getDensity();
                    
            % If the flow rate is zero or smaller, the fan will simply
            % output the maximum delta pressure
            if fFlowRate <= 0
                % pressure rises are negative
                fDeltaPressure = -this.fMaximumDeltaPressure;
            else
                % To be able to use the functions of the characteristics,
                % as a next step, the mass flow needs to be converted into
                % a volumetric flow. Luckily, every flow has a method for
                % that!
                fVolumetricFlowRate = oFlowIn.calculateVolumetricFlowRate(fFlowRate);
                
                % Calculating the delta pressure generated by the fan
                % according to the characteristic
                fInterpolatedDeltaPressure = this.calculateDeltaPressure(fVolumetricFlowRate);
                
                % The way the fan characteristic looks like, the delta
                % pressure actually becomes negative if the flow rate is
                % higher than the maximum volumetric flow rate. This makes
                % sense physically, because if the fan is flowed through
                % faster than it can blow, it becomes a flow restriction
                % causing a pressure drop. 
                if fInterpolatedDeltaPressure < 0 
                    fInterpolatedDeltaPressure = 0;
                end
                
                % Considering the influence of the density:
                fDensityCorrectedDeltaPressure = fInterpolatedDeltaPressure *  (fDensity / this.tCharacteristic.fTestDensity);

                % Pressure rises are negative in V-HAB solvers, so we
                % need to change the sign.
                fDeltaPressure = fDensityCorrectedDeltaPressure * (-1);
            end
            
            % We might want to log this value, so we set the property
            % accordingly.
            this.fDeltaPressure = fDeltaPressure;
            
            % Calculating the delta temperatures of the flowing matter. We
            % need to use the absolute value of the delta pressure here
            % because in case the flow speed is higher than the maximum
            % flow speed of the fan, the pressure difference becomes
            % negative. We still will produce a positive temperature change
            % though. 
            fDeltaTemperature = abs(fDeltaPressure) / fDensity / ...
                oFlowIn.fSpecificHeatCapacity / this.fInternalEfficiency * ...
                this.fPowerFactor;
            
            % In case something went wrong, we'll just set the termpature
            % difference to zero.
            if isnan(fDeltaTemperature) || isinf(fDeltaTemperature)
                fDeltaTemperature = 0;
            end
            
            % Calculating the heat flow produced by the fan that is
            % imparted onto the gas flow.
            this.fHeatFlow = abs(fFlowRate) * oFlowIn.fSpecificHeatCapacity * fDeltaTemperature;
            
            % Calculating Power consumed by the fan in [W]
            if fFlowRate > 0
                this.fPowerConsumtionFan = (fDeltaPressure * fVolumetricFlowRate) / this.fElectricalEfficiency;
            else
                this.fPowerConsumtionFan = 0;
            end
            
            % If it is turned on, we gradually increase the
            % pressure at the start of a simulation over a time
            % period of one second. This is done to prevent solver
            % issues caused by a large pressure spike.
            if this.bUsePressureRise && fFlowRate >= 0
                if this.bPreviouslyOff == true
                    this.fTurnOnTime = this.oTimer.fTime;
                    this.bPreviouslyOff = false;
                end
                
                fTotalRiseTime = 1;
                fCurrentRiseTime = this.oTimer.fTime - this.fTurnOnTime - fTotalRiseTime;
                if fCurrentRiseTime < fTotalRiseTime
                    if fFlowRate > 0
                        fNudgeFactor = -1;
                    else
                        fNudgeFactor = 0;
                    end
                    fDeltaPressure = fDeltaPressure * (-1 * (fCurrentRiseTime / fTotalRiseTime)^2 + 1) + fNudgeFactor;
                end
            end
            
        end
        
        function updateManualSolver(~)
            
            % Maybe someday we'll have to do something here... For now,
            % nothing is fine. This is just here so one can switch between
            % solver types without having to change the composition of the
            % matter branch.
            
        end
    end
    
end

