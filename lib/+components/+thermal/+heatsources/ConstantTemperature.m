classdef ConstantTemperature < thermal.heatsource
    % The ConstantTemperature heat source can be used to keep a capacity at
    % a constant temperature.
    % A constant temperature heat source will calculate the required heat
    % flow to maintain the temperature of the capacity in which it is
    % placed and sets itself that heat flow to maintain the temperature.
    
    properties (SetAccess = protected, GetAccess = public)
        fTemperature;
    end
    
    methods
        
        function this = ConstantTemperature(sName)
            this@thermal.heatsource(sName, 0);
            this.sName  = sName;
            
        end
        
        function setCapacity(this, oCapacity, fTemperature)
            % overwrite the generic setCapacity function so that we can
            % bind a callback to the capacity temperature update
            if isempty(this.oCapacity)
                this.oCapacity      = oCapacity;
                if nargin < 3
                    this.fTemperature   = oCapacity.fTemperature;
                else
                    this.fTemperature   = fTemperature;
                end
            else
                this.throw('setCapacity', 'Heatsource already has a capacity object');
            end
            
            % bin callpack to update this heat source before updating the
            % heatsource heatflows of the capacity. Note do not use a
            % consant temperature heat source together with any other heat
            % source (why would you do that?)
            oCapacity.bind('calculateHeatsource_pre',@(~)this.update());
            oCapacity.bind('calculateFlowConstantTemperature',@(~)this.update());
        end
        
        function setTemperature(this, fTemperature)
            % This function allows the user to set a desired target
            % temperature for the constant temperature heat source, also
            % enabling it to be used to keep a specific temperature, if
            % that temperature changes over the simulation
            this.fTemperature = fTemperature;
            
            % tell the capacity to update, also triggering the update of
            % this heatsource
            this.oCapacity.setOutdatedTS();
        end
        
        function update(this,~)
            
            fHeatSourceFlow = 0;
            for iHeatSource = 1:length(this.oCapacity.coHeatSource)
                if this.oCapacity.coHeatSource{iHeatSource} ~= this
                    fHeatSourceFlow = fHeatSourceFlow + this.oCapacity.coHeatSource{iHeatSource}.fHeatFlow;
                end
            end
            % calculate the temperature by which we have to adjust the
            % capacity temperature to reach the desired target temperature
            % (positive values represent a heatup)
            fRequiredTemperatureAdjustment = this.fTemperature - this.oCapacity.fTemperature;
            
            if this.oCapacity.oPhase.bFlow
                % For a flow node it is possible that the mass flows have
                % already changed, which is handled directly in the
                % capacity temperature calculation. For the constant
                % temperature heat source to work in this case, we must
                % reuse the same calculation from the capacity to calculate
                % the required heat flow for constant temperature
                mfFlowRate              = zeros(1,this.oCapacity.iProcsEXME);
                mfSpecificHeatCapacity  = zeros(1,this.oCapacity.iProcsEXME);
                mfTemperature           = zeros(1,this.oCapacity.iProcsEXME);
                for iExme = 1:this.oCapacity.iProcsEXME
                    if isa(this.oCapacity.aoExmes(iExme).oBranch.oHandler, 'solver.thermal.basic_fluidic.branch')
                        
                        if this.oCapacity.aoExmes(iExme).oBranch.oMatterObject.coExmes{1}.oPhase == this.oCapacity.oPhase
                            iMatterExme = 1;
                            iOtherExme = 2;
                        else
                            iMatterExme = 2;
                            iOtherExme = 1;
                        end
                        fFlowRate = this.oCapacity.aoExmes(iExme).oBranch.oMatterObject.fFlowRate * this.oCapacity.aoExmes(iExme).oBranch.oMatterObject.coExmes{iMatterExme}.iSign;
                        
                        if fFlowRate > 0
                            mfFlowRate(iExme) = fFlowRate;
                            mfSpecificHeatCapacity(iExme) = this.oCapacity.aoExmes(iExme).oBranch.oMatterObject.coExmes{iOtherExme}.oFlow.fSpecificHeatCapacity;
                            if iOtherExme == 2
                                mfTemperature(iExme) = this.oCapacity.aoExmes(iExme).oBranch.afTemperatures(end);
                            else
                                mfTemperature(iExme) = this.oCapacity.aoExmes(iExme).oBranch.afTemperatures(1);
                            end
                            
                        end
                    end
                end
                
                fOverallHeatCapacityFlow = sum(mfFlowRate .* mfSpecificHeatCapacity);
                
                if fOverallHeatCapacityFlow == 0
                    this.fHeatFlow = 0;
                else
                    this.fHeatFlow = - fHeatSourceFlow + (((this.oCapacity.fTemperature + fRequiredTemperatureAdjustment) - (sum(mfFlowRate .* mfSpecificHeatCapacity .* mfTemperature) / fOverallHeatCapacityFlow)) * fOverallHeatCapacityFlow);
                end
            else
                fExmeHeatFlow = 0;
                for iExme = 1:length(this.oCapacity.aoExmes)
                    fExmeHeatFlow = fExmeHeatFlow + (this.oCapacity.aoExmes(iExme).iSign * this.oCapacity.aoExmes(iExme).fHeatFlow);
                end
                % Calculated in a way to adjust the capacity temperature
                % within one minute
                fTemperatureAdjustmentHeatFlow = (fRequiredTemperatureAdjustment * this.oCapacity.fTotalHeatCapacity) / 60;
                
                this.fHeatFlow = - fExmeHeatFlow - fHeatSourceFlow + fTemperatureAdjustmentHeatFlow;
                
            end
        end
    end
end