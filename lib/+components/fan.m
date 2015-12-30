classdef fan < matter.procs.f2f
    %FAN Generic fan model with an optional characterisic
    % This is a generic, dynamic model of a fan. There are two different
    % mode of operation: 1. constant fan speed and 2. speed regulation/control
    % to generate a certain flowrate. There are four different entries the
    % user needs to do before simulating. These are 1.) the mode of
    % operation (setSpeed or setFlowRate), 2.) the speed of the fan,
    % 3.) if in setFlowRate mode the required flow rate and 4.) if desired,
    % a fan characteristic. For Information on how the characteristic has
    % to be input, see the description in this class' properties.
    %
    % WARNING: The default values of this fan model require it to run at
    % fairly high speeds, the inter- and extrapolation of values is done
    % using 40,000 and 75,000 RPM as anchor points.
    %
    % The model is currently adapted to work with the linear solver and
    % therfore sets the fDeltaPressure property at the end of the update()
    % method.
    
    properties (SetAccess = public, GetAccess = public)
        % Setpoint for the speed of the fan in RPM
        fSpeedSetpoint = 0;
        
        % Setpoint for the volumetric flow rate in [m3/s]
        fVolumetricFlowRateSetpoint = 0;
        
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
        
        % Power Consumtion of the FAN in [W]
        fPowerConsumtionFan = 0; 
        
        % Needed for the second operation mode:
        % equals the new pressure after adjusting
        % the speed. In [Pa]
        fDeltaPressureNew = 0;   
        
        % The current speed of the fan in [RPM]
        fSpeed;                  
    
        % 2 modes of operation:
        % setSpeed:    You set the fan speed in RPM
        % setFlowRate: You set the volumetric flow rate in m3/s
        sMode;
        
        % This struct contains the data neccessary if you want to enter
        % your own characteristic. The default values correspond to the fan
        % used in NASA's PLSS 1.0 prototype. See AIAA-2011-5222.
        % To get a full characteristic of a fan, you need the function
        % describing the differential pressure the fan can produce
        % depending on the volumetric flow rate through the fan. This is
        % usually determined experimentally, so you'll probably need to do
        % some curve fitting to get the function. A third order polynomial
        % is sufficient for most fans. Since the differential pressure
        % also depends on the fan's speed, we need two polynomials for two
        % different fan speeds between which we can then interpolate.
        % Lastly we also need the environmental conditions at which the
        % tests that generated the data were performed.
        
        tCharacteristic = struct(...
            ...% Upper and speed and respective characteristic function
            'fSpeedUpper', 75000, ...
            'calculateUpperDeltaP', @(fVolumetricFlowRate) -9064144377.669 *  ((fVolumetricFlowRate).^3) + 9755592.99525*((fVolumetricFlowRate).^2) + 4716.6727883 *(fVolumetricFlowRate) + 2607, ...
            ...% Lower and speed and respective characteristic function
            'fSpeedLower', 40000, ...
            'calculateLowerDeltaP', @(fVolumetricFlowRate) -6727505231.41735 *  ((fVolumetricFlowRate).^3) - 7128360.09755 *((fVolumetricFlowRate).^2) + 33153.83752 * (fVolumetricFlowRate) + 752, ...
            ...% Pressure, temperature, gas constant and density of the gas
            ...% used during the determination of the characteristic
            'fTestPressure',      29649, ...
            'fTestTemperature',  294.26, ...
            'fTestGasConstant', 287.058, ...
            'fTestDensity',      0.3510 ...
            );
        
    end
    
    methods
        function this = fan(varargin)
            % Constructor
            % Required inputs:
            % varargin{1} = oContainer
            % varargin{2} = sName
            % varargin{3} = sMode
            % varargin{4} = setpoint (either speed or flow rate or manual 
            %                         delta pressure)
            %
            % Optional inputs:
            % varargin{5} = sDirection
            % varargin{6} = struct containing characteristic information
            %               for a specific fan, see properties
            
            
            this@matter.procs.f2f(varargin{1}, varargin{2});
            
            % Setting the operational mode
            this.sMode = varargin{3};
            iNargin    = nargin;
            
            % See which setpoint we are using depending on the mode
            if strcmp(varargin{3}, 'setSpeed')
                this.fSpeedSetpoint = varargin{4};
                this.fSpeed         = varargin{4};
            elseif strcmp(varargin{3}, 'setFlowRate')
                this.fVolumetricFlowRateSetpoint = varargin{4};
            elseif strcmp(varargin{3}, 'manual')
                 if iNargin > 3
                     this.fDeltaPressure = varargin{4};
                 end
            else
                % Looks like someone didn't read the documentation...
                this.throw('fan', 'The mode input for a fan must be either ''setSpeed'', ''setFlowRate'' or ''manual''.');
            end
            
            % Setting the direction in which the fan blows relative to the
            % positive direction of the branch in which the fan is placed.
            % Branch flow rates are positive (1) from left to right and
            % negative from right to left (-1).
            if iNargin > 4 && ~isempty(varargin{5})
                if strcmp(varargin{5}, 'Left2Right')
                    this.iBlowDirection = 1;
                elseif strcmp(varargin{5}, 'Right2Left')
                    this.iBlowDirection = -1;
                end
            end
            
            % If a specific characteristic is used, read in the data and
            % override the defaults
            if iNargin > 5 && ~isempty(varargin{6})
                this.tCharacteristic = varargin{6};
            end
            
            
            % Support these two solver architectures - hydr used by the
            % linear solver, fct by the iterative.
            this.supportSolver('hydraulic', -1, 1, true, @this.update);
            this.supportSolver('callback', @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        
        function fDeltaPressure = update(this)
            % If this is the very first execution, the method will produce
            % many errors, so we just skip this time and wait until
            % everything else is ready.
            if ~this.oBranch.oContainer.oTimer.fTime
                fDeltaPressure = 0;
                
                return;
            end
            %keyboard();
            % Getting the incoming flow if the current flowrate is not zero!
            if ~((this.aoFlows(1).fFlowRate == 0) || (this.aoFlows(2).fFlowRate == 0))
                [ oFlowIn, ~ ] = this.getFlows();
            else
                % The following is a workaround, should be fixed at some
                % point via a more intelligent solver
                
                % If the current flow rate is zero, we need to trick the
                % getFlows() method into still giving us the flow objects.
                % The method needs a flow rate that is not zero to
                % determine, which is the 'in' flow and which is the 'out'
                % flow. Here we just pass on the direction of positive flow
                % through the fan.
                
                [ oFlowIn, ~ ] = this.getFlows(this.iBlowDirection);
                
                %                 %TODO make the numbers here properties
                %                 this.fDeltaPressure = 752 + ((this.fSpeedSetpoint - this.tCharacteristic.fSpeedLower)/(this.tCharacteristic.fSpeedUpper-this.tCharacteristic.fSpeedLower)) * (2607 - 752); % Interpolation of max. DeltaPressure that can be generated by the FAN!
                %                 disp(['Current Delta P: ', num2str(this.fDeltaPressure)])
                %                 return;
            end
            
            % To be able to use the functions of the characteristics, as a
            % next step, the matter flow needs to be calculated into
            % a volumetric flow. Luckily, every flow has a method for that!
            fVolumetricFlowRate = oFlowIn.calculateVolumetricFlowRate();
            
            % Now we use the characteristic functions to calculate the
            % delta pressure at the two different fan speeds depending on
            % the volumetric flow rate
            fDeltaPressureLower  = this.tCharacteristic.calculateLowerDeltaP(fVolumetricFlowRate);
            
            fDeltaPressureHigher = this.tCharacteristic.calculateUpperDeltaP(fVolumetricFlowRate);
            
            % Now we can interpolate between the two
            fDeltaPressure = fDeltaPressureLower + ((this.fSpeedSetpoint - this.tCharacteristic.fSpeedLower )/(this.tCharacteristic.fSpeedUpper-this.tCharacteristic.fSpeedLower)) * (fDeltaPressureHigher - fDeltaPressureLower);
            
            
            %If the FlowRate is > Maximum FlowRate of the Fan,
            %fDeltaPressure needs to be limited to zero:
            if (fDeltaPressure < 0)
                
                fDeltaPressure = 0;
                
            end
            
            %Calculating the density of the incoming flowing matter:
            fDensity = this.oMT.calculateDensity(oFlowIn);
            
            
            switch this.sMode
                
                case 'setSpeed'
                    %% Constant speed mode
                    
                    %Considering the influence of the density:
                    fDeltaPressure = fDeltaPressure *  (fDensity /this.tCharacteristic.fTestDensity);
                    
                    %Calculating the DeltaTemps of the flowing matter :
                    %TODO changed - fHeatFlow used now. Change that,
                    %     calculate heat flow in separate method. Call that
                    %     method whenever e.g. a fan setting and with that
                    %     the produced heat change.
%                     if oFlowIn.fFlowRate >= 0
%                         fDeltaTemp = (((fDeltaPressure / 1000))/ (fDensity * oFlowIn.fHeatCapacity * 0.85)) * 0.95; %[K] --> Teperature rise
%                     else
%                         fDeltaTemp = ((( -1*fDeltaPressure ) / 1000)/ (fDensity * oFlowIn.fHeatCapacity * 0.85) ) * 0.95 ; %[K] --> Temperature loss
%                     end
                    
                    %Calculating Power consumed by the FAN
                    if oFlowIn.fFlowRate > 0
                        this.fPowerConsumtionFan = (fDeltaPressure * fVolumetricFlowRate) / (0.80); %[W] for  VolumetricFlowrate in [m?/s] and a DeltaPress in [Pa]
                    else
                        this.fPowerConsumtionFan = 0;
                    end
                    
                    %The following differentiation is needed to simulate
                    %the resistance the fan creates when beeing
                    %throughflowed in the wrong direction(indicated by a
                    %negative flow rate and therefor a positive fHydrDiam):
                    
                    % This won't work!
                    
                    oHydr = this.toSolve.hydraulic;
                    
                    if oFlowIn.fFlowRate > 0
                        
                        oHydr.fHydrDiam = -1;
                        
                    elseif oFlowIn.fFlowRate == 0
                        
                        oHydr.fHydrDiam =  -1;
                    else
                        oHydr.fHydrDiam =  1;
                    end
                    
%                 case 'setFlowRate'
%                     %% Constant volumetric flowrate mode
%                     
%                     %Calculating for which running speed the VolumetricFlowRate
%                     %matches the asked VolumetricFlowRate according to the
%                     %ventilation rules:
%                     this.fSpeed = (this.fVolumetricFlowRateRequired / fVolumetricFlowRate) * this.fSpeed;
%                     
%                     %Now the required DeltaPressure is calculated.
%                     %This Pressure is constant if no changes in the
%                     %setup of the simulation happen.
%                     
%                     fDeltaPressureNew = (this.fVolumetricFlowRateRequired / fVolumetricFlowRate).^2 * fDeltaPressure;
%                     
%                     
%                     %Calculating of the "test" density:
%                     fTestDensity = ((fPressureTest) / (fTempsTest * fGasConstantTest));
%                     
%                     %Considering the influence of the varying density:
%                     fDeltaPressureNew = fDeltaPressureNew *  (fDensity  /fTestDensity); %  AIR , T = 294,26, P = 29649 Pa (4,3 psi), R = 287,058)
%                     
%                     this.fDeltaPressure =  this.fDeltaPressureNew;
%                     
%                     %Calculating the TDeltaTemps:
%                     if oFlowIn.fFlowRate >= 0
%                         fDeltaTemp = ((( fDeltaPressure )/1000)/ (fDensity * oFlowIn.fHeatCapacity * 0.85) ) * 1 ; %[K]
%                     else
%                         fDeltaTemp = ((( -1 * fDeltaPressure )/1000)/ (fDensity * oFlowIn.fHeatCapacity * 0.85) ) * 1 ; %[K]
%                     end
%                     
%                     %PowerConsumtion:
%                     if oFlowIn.fFlowRate > 0
%                         this.fPowerConsumtionFan = (fDeltaPressure * fVolumetricFlowRate) / (0.80); %[ in Watt for a VolumetricFlowrate in m?/s and a DeltaPress in Pa
%                         
%                     else
%                         this.fPowerConsumtionFan = 0;
%                     end
            end

        end
        
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            % If this is the very first execution, the method will produce
            % many errors, so we just skip this time and wait until
            % everything else is ready.

%             if ~(this.oBranch.oTimer.fTime >= 0)
%                 fDeltaPressure     = 0;
%                 fDeltaTemperature  = 0;
%                 return;
%             end
            
            % Getting the incoming flow if the current flowrate is not zero!
            if fFlowRate
                [ oFlowIn, ~ ] = this.getFlows(fFlowRate);
                
                %Calculating the density of the incoming flowing matter:
                %fDensity = this.oMT.calculateDensity(oFlowIn);
                fDensity = oFlowIn.getDensity();
                
                if fFlowRate < 0
                    iFlowDir = -1;
                else
                    iFlowDir = 1;
                end
            else
                % The following is a workaround, should be fixed at some
                % point via a more intelligent solver
                
                % If the current flow rate is zero, we need to trick the
                % getFlows() method into still giving us the flow objects.
                % The method needs a flow rate that is not zero to
                % determine, which is the 'in' flow and which is the 'out'
                % flow. Here we just pass on the direction of positive flow
                % through the fan.
                
                [ oFlowIn, ~ ] = this.getFlows(this.iBlowDirection);
                iFlowDir = 0;
                fDensity = this.oMT.calculateDensity(this.oBranch.coExmes{1}.oPhase);
            end
            %keyboard();
            % To be able to use the functions of the characteristics, as a
            % next step, the matter flow needs to be calculated into
            % a volumetric flow. Luckily, every flow has a method for that!
            fVolumetricFlowRate = oFlowIn.calculateVolumetricFlowRate();
            
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
            
            
            %If the FlowRate is > Maximum FlowRate of the Fan,
            %fDeltaPressure needs to be limited to zero:
            if fInterpolatedDeltaPressure < 0
                fInterpolatedDeltaPressure = 0;
            end
            
            switch this.sMode
                
                case 'setSpeed'
                    %% Constant speed mode
                    
                    %Considering the influence of the density:
                    fDensityCorrectedDeltaPressure = fInterpolatedDeltaPressure *  (fDensity / this.tCharacteristic.fTestDensity);
                    
                    % Calculating the delta temperatures of the flowing matter:
                    fDeltaTemperature = fDensityCorrectedDeltaPressure / fDensity / ...
                                        oFlowIn.fSpecificHeatCapacity / this.fInternalEfficiency * ...
                                        this.fPowerFactor; 
                    
                    % In case something went wrong, we'll just set the
                    % termpature difference to zero.
                    if isnan(fDeltaTemperature) || isinf(fDeltaTemperature)
                        fDeltaTemperature = 0;
                    end

                    
                    % And finally setting the correct sign to respect the
                    % iterative solver's directivity.
                    % If the direction of the flow and the direction of the
                    % fan are pointing in the same direction (are both
                    % positive or negative), then the fan produces a
                    % pressure rise. Pressure rises are negative in the
                    % world of the iterative solver, hence the '* (-1)'. If
                    % the two are not aligned (fan is blowing against a
                    % flow but is not powerful enough, so there is
                    % backflow), the fan produces a pressure drop.
                    fDeltaPressure = fDensityCorrectedDeltaPressure * this.iBlowDirection * iFlowDir * (-1);
                    
                    %Calculating Power consumed by the FAN
                    if oFlowIn.fFlowRate > 0
                        this.fPowerConsumtionFan = (fDeltaPressure * fVolumetricFlowRate) / (0.80); %[W] for  VolumetricFlowrate in [m?/s] and a DeltaPress in [Pa]
                    else
                        this.fPowerConsumtionFan = 0;
                    end
                    
                    %TODO
                    this.fHeatFlow = 1;
                    
                    
                    
%                 case 'setFlowRate'
%                     %% Constant volumetric flowrate mode
%                     
%                     %Calculating for which running speed the VolumetricFlowRate
%                     %matches the asked VolumetricFlowRate according to the
%                     %ventilation rules:
%                     this.fSpeed = (this.fVolumetricFlowRateRequired / fVolumetricFlowRate) * this.fSpeed;
%                     
%                     %Now the required DeltaPressure is calculated.
%                     %This Pressure is constant if no changes in the
%                     %setup of the simulation happen.
%                     
%                     fDeltaPressureNew = (this.fVolumetricFlowRateRequired / fVolumetricFlowRate).^2 * fDeltaPressure;
%                     
%                     
%                     %Calculating of the "test" density:
%                     fTestDensity = ((fPressureTest) / (fTempsTest * fGasConstantTest));
%                     
%                     %Considering the influence of the varying density:
%                     fDeltaPressureNew = fDeltaPressureNew *  (fDensity  /fTestDensity); %  AIR , T = 294,26, P = 29649 Pa (4,3 psi), R = 287,058)
%                     
%                     this.fDeltaPressure =  this.fDeltaPressureNew;
%                     
%                     %Calculating the TDeltaTemps:
%                     if oFlowIn.fFlowRate >= 0
%                         fDeltaTemperature = ((( fDeltaPressure )/1000)/ (fDensity * oFlowIn.fHeatCapacity * 0.85) ) * 1 ; %[K]
%                     else
%                         fDeltaTemperature = ((( -1 * fDeltaPressure )/1000)/ (fDensity * oFlowIn.fHeatCapacity * 0.85) ) * 1 ; %[K]
%                     end
%                     
%                     %PowerConsumtion:
%                     if oFlowIn.fFlowRate > 0
%                         this.fPowerConsumtionFan = (fDeltaPressure * fVolumetricFlowRate) / (0.80); %[ in Watt for a VolumetricFlowrate in m?/s and a DeltaPress in Pa
%                         
%                     else
%                         this.fPowerConsumtionFan = 0;
%                     end
            end
            
        end
        
        function updateManualSolver(~)
            
            % Maybe someday we'll have to do something here...
            
        end
    end
    
end

