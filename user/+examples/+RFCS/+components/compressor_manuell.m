classdef compressor_manuell < matter.procs.f2f
    %compressor Generic compressor model with an optional characterisic
    % This is a generic, dynamic model of a compressor that is controlled by
    % setting a compressor speed in RMP. The user therefore needs to enter a set
    % point for the compressor speed as well as a string indicating the direction
    % in which the compressor is blowing relative to the branch in which it is
    % contained. If desired, a compressor characteristic can also be passed as a
    % parameter. For Information on how the characteristic has to be input,
    % see the description in this class' properties.
    %
    % WARNING: The default values of this compressor model require it to run at
    % fairly high speeds, the inter- and extrapolation of values is done
    % using 1 and 10 RPM as anchor points.
    
    properties (SetAccess = public, GetAccess = public)
        % Setpoint for the speed of the compressor in RPM
        fSpeedSetpoint = 0;
        oPhase_in;
        oPhase_out;
        fPressure_in;
        bclosed=0;
        % The power factor is a compressor-specific figure of merit that is
        % dependent on the difference between the inlet and outlet
        % pressures. It is part of the calculation of the temperature
        % differences caused by the compressor. It is rarely found in literature,
        % so it is assumed, that most sources set it to 1. We set the
        % default value to 0.95 because that works well with the default
        % compressor characteristic.
        fPowerFactor = 1;
        
        % The internal efficiency of the compressor describes the temperature
        % changes in the flow due to friction. It is also a compressor-specific
        % figure of merit. The default value of 0.85 works well with the
        % default compressor characteristic.
        fInternalEfficiency = 1;
        
        % This value is used to calculate the power draw from the compressor. It
        % is also compressor-specific.
        fElectricalEfficiency = 1;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Switched off?
        bActive = true;
        
        temp=0;
        % Direction of the flow the compressor is trying to produce. Default
        % direction is left to right -> iBlowDirection = 1. For right to
        % left -> iBlowDirection = -1;
        iBlowDirection = 1;
        
        % Power Consumtion of the compressor in [W]
        fPowerConsumtioncompressor = 0;
        
        
        %for the moment i take a linear characteristik
        
        tCharacteristic = struct(...
            ...% Upper and speed and respective characteristic function
            'fSpeedUpper', 100, ...
            'calculateUpperDeltaP', @(fVolumetricFlowRate) 30*10^5-fVolumetricFlowRate*2*10^5*10^4, ...
            ...% Lower and speed and respective characteristic function
            'fSpeedLower', 0, ...
            'calculateLowerDeltaP', @(fVolumetricFlowRate) 0.03*10^5-fVolumetricFlowRate*0.002*10^5*10^4, ...
            ...% Pressure, temperature, gas constant and density of the gas
            ...% used during the determination of the characteristic
            'fTestPressure',    29649, ...      Pa
            'fTestTemperature',   294.26, ...   K
            'fTestGasConstant',   287.058, ...  J/kgK
            'fTestDensity',         0.3510 ...  kg/m3
            );
        
        % Pressure difference produced by this compressor.
        fDeltaPressure;
        fVolumetricFlowRate;
        
        
    end
    
    properties (SetAccess = private, GetAccess = private)
        % A reference to the incoming flow object. This is used to
        % calculate the properties of the inflowing gas.
        oFlowIn;
        
    end
    
    methods
        function this = compressor_manuell(oContainer, sName, fSpeedSetpoint, sDirection,oPhase_in,oPhase_out,fPressure_in, tCharacteristic)
            % Constructor
            % Required inputs:
            % oContainer        Reference to the matter container this f2f
            %                   is created in
            % sName             Name as string
            % fSpeedSetpoint    compressor speed setpoint in revolutions per
            %                   minute [RPM]
            % sDirection        String indicating in which direction the
            %                   compressor is blowing. Can eiter be 'Left2Right'
            %                   or 'Right2Left'. This is with respect to
            %                   the positive flow direction of the branch
            %                   the compressor is part of.
            %
            % Optional inputs:
            % tCharacteristic   Struct containing characteristic
            %                   information for a specific compressor, see
            %                   properties.
            
            this@matter.procs.f2f(oContainer, sName);
            
            this.oPhase_in=oPhase_in;
            this.oPhase_out=oPhase_out;
            this.fPressure_in=fPressure_in;
            this.fSpeedSetpoint = fSpeedSetpoint;
            
            if strcmp(sDirection, 'Left2Right')
                this.iBlowDirection = 1;
            elseif strcmp(sDirection, 'Right2Left')
                this.iBlowDirection = -1;
            else
                this.throw('compressor','Illegal value for the direction parameter of the compressor. The input may only be ''Left2Right'' or ''Right2Left''.');
            end
            
            % If a specific characteristic is used, read in the data and
            % override the defaults
            if nargin > 7
                this.tCharacteristic = tCharacteristic;
            end
            
            
            % Support these two solver architectures - hydr used by the
            % linear solver, fct by the iterative.
            this.supportSolver('hydraulic', -1, 1, true, @this.solverDeltas);
            this.supportSolver('callback', @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        
        function switchOn(this)
            this.bActive = true;
            this.oBranch.setOutdated();
        end
        
        function switchOff(this)
            this.bActive = false;
            this.oBranch.setOutdated();
        end
        
        
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            
            
            % Switched off? No dP no matter what
            if ~this.bActive
                fDeltaPressure = 0;
                return;
            end
            
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
            % one that is the inflow if the flow rate through the compressor is in
            % the same direction as the compressor is blowing. The opposite case
            % only happens rarely, so the error made here should be fairly
            % small.
            if isempty(this.oFlowIn)
                % This line of code takes quite some time to execute, so
                % we'll only do it once at the very beginning. We can't do
                % this in the constructor, because there the getFlows()
                % method will only return an empty flow object because it
                % hasn't been set yet. This is done when the branch this
                % compressor is contained in is created.
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
            this.fVolumetricFlowRate = this.oFlowIn.calculateVolumetricFlowRate(fFlowRate);
            
            % Now we use the characteristic functions to calculate the
            % delta pressure at the two different compressor speeds depending on
            % the volumetric flow rate
            fDeltaPressureLower  = this.tCharacteristic.calculateLowerDeltaP(this.fVolumetricFlowRate);
            
            fDeltaPressureHigher = this.tCharacteristic.calculateUpperDeltaP(this.fVolumetricFlowRate);
            
            
            
            
            % Now we can interpolate between the two
            fInterpolatedDeltaPressure = fDeltaPressureLower + ...
                (this.fSpeedSetpoint - this.tCharacteristic.fSpeedLower ) / ...
                (this.tCharacteristic.fSpeedUpper - this.tCharacteristic.fSpeedLower) * ...
                (fDeltaPressureHigher - fDeltaPressureLower);
            
            %            delta=this.oContainer.toStores.Tank_2.toPhases.H2_2.fPressure-...
            %                this.oContainer.toStores.Tank_1.toPhases.H2_1.fPressure ;
            %            delta=this.aoFlows(1,2).fPressure-this.aoFlows(1, 1).fPressure;
            delta=this.oPhase_out.fPressure-this.oPhase_in.fPressure;
            %                if delta > (fInterpolatedDeltaPressure-500)
            %                  if  this.oPhase_in.fPressure>2*10^5
            %                this.temp=this.temp+1;
            %
            %                         if this.temp>500
            %
            %                      this.fSpeedSetpoint=this.fSpeedSetpoint+1-0.51*(fInterpolatedDeltaPressure/3000000);
            %
            %                      this.temp=0;
            %                         end
            %
            %
            %                else
            %
            %              this.fSpeedSetpoint=this.fSpeedSetpoint-1;
            %                  end
            
            %new try-----------------------------------------------
            
            
            
            
            
            
            % Considering the influence of the density:
            %             fDensityCorrectedDeltaPressure = fInterpolatedDeltaPressure *  (fDensity / this.tCharacteristic.fTestDensity);
            %
            % Setting the correct sign to respect the iterative solver's
            % directivity. If the direction of the flow and the direction
            % of the compressor are pointing in the same direction (are both
            % positive or negative), then the compressor produces a pressure rise.
            % Pressure rises are negative in the world of the iterative
            % solver, hence the '* (-1)'. If the two are not aligned (compressor
            % is blowing against a flow but is not powerful enough, so
            % there is backflow), the compressor produces a pressure drop.
            
            
            fDeltaPressure = fInterpolatedDeltaPressure * this.iBlowDirection * iFlowDir * (-1);
            
            fRiseTime = 1;
            if this.oTimer.fTime < fRiseTime
                fDeltaPressure = fDeltaPressure * (-1 * ((this.oTimer.fTime - fRiseTime) / fRiseTime)^2 + 1);
            end
            
            %closing like a valve
            i=0;
            if this.bclosed==1
                i=i+1;
                
                this.fSpeedSetpoint=(abs(delta)-fDeltaPressure)*K;
                if i>100
                    fDeltaPressure=-delta;
                end
            end
            this.fDeltaPressure = fDeltaPressure;
            
            % Calculating the delta temperatures of the flowing matter.
            %             fDeltaTemperature = fInterpolatedDeltaPressure / fDensity / ...
            %                 this.oFlowIn.fSpecificHeatCapacity / this.fInternalEfficiency * ...
            %                 this.fPowerFactor;
            fDeltaTemperature=0;
            
            % In case something went wrong, we'll just set the termpature
            % difference to zero.
            if isnan(fDeltaTemperature) || isinf(fDeltaTemperature)
                fDeltaTemperature = 0;
            end
            
            % Calculating the heat flow produced by the compressor that is
            % imparted onto the gas flow.
            this.fHeatFlow = fFlowRate * this.oFlowIn.fSpecificHeatCapacity * fDeltaTemperature;
            
            % Calculating Power consumed by the compressor in [W]
            if fFlowRate > 0
                this.fPowerConsumtioncompressor = (fInterpolatedDeltaPressure * this.fVolumetricFlowRate) / this.fElectricalEfficiency;
            else
                this.fPowerConsumtioncompressor = 0;
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