classdef f2f_wrapper < base & event.source
    %F2F_WRAPPER Summary of this class goes here
    %   Detailed explanation goes here
    %
    %TODO
    %   * on update of heat flow / alpha, set container tainted?
    %   * if heat source on capa is of type thermal.heatsource_multiple,
    %     add normal HS and add to that multiple HS
    
    properties (SetAccess = protected, GetAccess = public)
        oFlowProcessor;
        
        oCapacity;
        
        % Heat transfer coefficient in W/m^2/K
        fAlpha = 0;
        
        % Heat transfer area in m^2
        fArea = 1;
        
        
        fHeatFlow = 0;
    end
    
    methods
        function this = f2f_wrapper(oFlowToFlowProcessor, oCapacity, fAlpha, fArea)
            this.oFlowProcessor = oFlowToFlowProcessor;
            this.oCapacity      = oCapacity;
            
            % Optional parameters
            if nargin >= 3 && ~isempty(fAlpha) && isnumeric(fAlpha)
                this.fAlpha = fAlpha;
            end
            
            if nargin >= 4 && ~isempty(fArea) && isnumeric(fArea)
                this.fArea = fArea;
            end
            
            
            % Only creat if not present in capacity.
            if isempty(oCapacity.oHeatSource)
                oHeatSource = thermal.heatsource([ oFlowToFlowProcessor.oBranch.sName '__' oFlowToFlowProcessor.sName '__2__' oCapacity.sName ]);
                
                oCapacity.setHeatSource(oHeatSource);
            else
                oHeatSource = oCapacity.oHeatSource;
            end
            
            % Sign NEGATIVE -> if negative heat flow, means INTO the proc,
            % because heat source already added to capacity above where the
            % sign is treated that way (negative -> OUT of the capacity)
            oFlowToFlowProcessor.setHeatFlowObject(oHeatSource, -1);
            
            
            this.oFlowProcessor.oBranch.bind('setFlowRate', @this.updateHeatFlow);
            
            
            this.warn('constructor', 'untested!');
        end
        
        
        function this = updateAlpha(this, fAlpha)
            this.fAlpha = fAlpha;
            
            this.recalculateHeatFlow();
        end
        
        function this = updateArea(this, fArea)
            this.fArea = fArea;
            
            this.recalculateHeatFlow();
        end
    end
    
    
    methods (Access = protected)
        function updateHeatFlow(this, ~)
            % Give someone a chance to update e.g. fAlpha based on the flow
            % velocity etc.
            this.trigger('update', struct('oInFlow', this.getProcInFlow(), 'fFlowRate', this.oFlowProcessor.oBranch.fFlowRate));
            
            this.recalculateHeatFlow();
        end
        
        
        function oFlow = getProcInFlow(this)
            if this.oFlowProcessor.oBranch.fFlowRate < 0
                oFlow = this.oFlowProcessor.aoFlows(2);
            else
                oFlow = this.oFlowProcessor.aoFlows(1);
            end
        end
        
        
        function recalculateHeatFlow(this)
            % Get temperatures from capacity, f2f
            % With alpha/area, calc heat transfer
            % update in heat source
            % TAINT container!
            %
            %NOTE for temp capa > f2f, flow FROM f2f. Therefore:
            % fHeatFlow = fAlpha * fArea * (fTempFlowProc - fTempCapa)
            
            if this.fHeatFlow ~= this.oFlowProcessor.oHeatFlowObject.fPower
                this.warn('updateHeatFlow', 'Power on heat source does not match the one stored here, i.e. someone else is changing the heat source power!');
            end
            
            
            fTempCapa = this.oCapacity.oMatterObject.fTemperature;
            fTempFlow = this.getProcInFlow().fTemperature;
            
            
            if this.oFlowProcessor.oBranch.fFlowRate == 0
                this.fHeatFlow = 0; 
            else
                this.fHeatFlow = this.fAlpha * this.fArea * (fTempFlow - fTempCapa);
            end
            
            this.oFlowProcessor.oHeatFlowObject.setPower(this.fHeatFlow);
            
            
            %NOW:
            %   * this.out --> calculated area etc
            %   * TEST: shorter pipe - less transfer!
            %   * T FR change: flow temp change, phase temp change rate EQ
            %   * T change alpha during run - phase temp chagne rate CHANGE
            
            
            %TODO taint thermal container!
        end
    end
end

