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
        % Direction of the flow the fan is trying to produce. Default
        % direction is left to right -> iBlowDirection = 1
        iBlowDirection = 1;
        
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
            'fTestDensity',         0.3510 ...  kg/m3
            );
        
        % Pressure difference produced by this fan.
        fDeltaPressure;
        
    end
    
    properties (SetAccess = private, GetAccess = private)
        % A reference to the incoming flow object. This is used to
        % calculate the properties of the inflowing gas.
        oFlowIn;
        
    end
    
    methods
        function this = fan(oContainer, sName, fSpeedSetpoint, sDirection, tCharacteristic)
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
            
            
            this.fSpeedSetpoint = fSpeedSetpoint;
            
            if strcmp(sDirection, 'Left2Right')
                this.iBlowDirection = 1;
            elseif strcmp(sDirection, 'Right2Left')
                this.iBlowDirection = -1;
            else
                this.throw('fan','Illegal value for the direction parameter of the fan. The input may only be ''Left2Right'' or ''Right2Left''.');
            end
            
            % If a specific characteristic is used, read in the data and
            % override the defaults
            if nargin > 4
                this.tCharacteristic = tCharacteristic;
            end
            
            
            % Support these two solver architectures - hydr used by the
            % linear solver, fct by the iterative.
            this.supportSolver('hydraulic', -1, 1, true, @this.solverDeltas);
            this.supportSolver('callback', @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            
            % We're setting the incoming flow with respect to the blow
            % direction. Technically this should be done with respect to
            % the flow rate, taking whichever flow is the actual incoming
            % flow. This has some repercussions in the solver however,
            % since it also determines, which flow and therefore pressure
            % will be used to calculate the volumetric flow rate. If the
            % flow rate switches directions between calls of solverDeltas()
            % a different flow with a much different pressure will be used
            % to calculate the volumetric flow rate. This leads to
            % instabilities in the flow rate solver. Therefore we use the
            % one that is the inflow if the flow rate through the fan is in
            % the same direction as the fan is blowing. The opposite case
            % only happens rarely, so the error made here should be fairly
            % small.
            if isempty(this.oFlowIn)
                % This line of code takes quite some time to execute, so
                % we'll only do it once at the very beginning. We can't do
                % this in the constructor, because there the getFlows()
                % method will only return an empty flow object because it
                % hasn't been set yet. This is done when the branch this
                % fan is contained in is created. 
                [ this.oFlowIn, ~ ] = this.getFlows(this.iBlowDirection);
            end
            
            % Calculating the density of the incoming flowing matter:
            fDensity = this.oFlowIn.getDensity();
            
            % We need to check, if the flow rate is positive or negative
            % and set our iFlowDir variable accordingly.
            if fFlowRate < 0
                iFlowDir = -1;
            else
                iFlowDir = 1;
            end
            
            % To be able to use the functions of the characteristics, as a
            % next step, the matter flow needs to be calculated into a
            % volumetric flow. Luckily, every flow has a method for that!
            fVolumetricFlowRate = this.oFlowIn.calculateVolumetricFlowRate(fFlowRate);
            
            % Now we use the characteristic functions to calculate the
            % delta pressure at the two different fan speeds depending on
            % the volumetric flow rate
            fDeltaPressureLower  = this.tCharacteristic.calculateLowerDeltaP(fVolumetricFlowRate);
            
            fDeltaPressureHigher = this.tCharacteristic.calculateUpperDeltaP(fVolumetricFlowRate);
            
            % Now we can interpolate between the two
            fInterpolatedDeltaPressure = fDeltaPressureLower + ...
                (this.fSpeedSetpoint - this.tCharacteristic.fSpeedLower ) / ...
                (this.tCharacteristic.fSpeedUpper - this.tCharacteristic.fSpeedLower) * ...
                (fDeltaPressureHigher - fDeltaPressureLower);
            
            % Considering the influence of the density:
            fDensityCorrectedDeltaPressure = fInterpolatedDeltaPressure *  (fDensity / this.tCharacteristic.fTestDensity);
            
            % Setting the correct sign to respect the iterative solver's
            % directivity. If the direction of the flow and the direction
            % of the fan are pointing in the same direction (are both
            % positive or negative), then the fan produces a pressure rise.
            % Pressure rises are negative in the world of the iterative
            % solver, hence the '* (-1)'. If the two are not aligned (fan
            % is blowing against a flow but is not powerful enough, so
            % there is backflow), the fan produces a pressure drop.
            fDeltaPressure = fDensityCorrectedDeltaPressure * this.iBlowDirection * iFlowDir * (-1);
            
            % We might want to log this value, so we set the property
            % accordingly.
            this.fDeltaPressure = fDeltaPressure;
            
            % Calculating the delta temperatures of the flowing matter.
            fDeltaTemperature = fDensityCorrectedDeltaPressure / fDensity / ...
                this.oFlowIn.fSpecificHeatCapacity / this.fInternalEfficiency * ...
                this.fPowerFactor;
            
            % In case something went wrong, we'll just set the termpature
            % difference to zero.
            if isnan(fDeltaTemperature) || isinf(fDeltaTemperature)
                fDeltaTemperature = 0;
            end
            
            % Calculating the heat flow produced by the fan that is
            % imparted onto the gas flow.
            this.fHeatFlow = fFlowRate * this.oFlowIn.fSpecificHeatCapacity * fDeltaTemperature;
            
            % Calculating Power consumed by the fan in [W]
            if fFlowRate > 0
                this.fPowerConsumtionFan = (fDensityCorrectedDeltaPressure * fVolumetricFlowRate) / this.fElectricalEfficiency;
            else
                this.fPowerConsumtionFan = 0;
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

