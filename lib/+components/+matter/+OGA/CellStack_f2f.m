classdef CellStack_f2f < matter.procs.f2f

    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam = -1;         % Hydraulic diameter negative to indicate pressure rise
        fHydrLength = 1;        % This just has to be there because of parent class and solver, value is irrelevant
        fDeltaTemp = 0;         % Temperature difference created by the component in [K]
        fDeltaPress = 0;        % Pressure difference created by the component in [Pa]
        sStore;
    end
    
    methods
        function this = CellStack_f2f(oMT, sName, sStore)
            this@matter.procs.f2f(oMT, sName);

            this.sStore = sStore;
            this.supportSolver('manual', true, @this.update);
        end
        
%         % Get in/out flow object references
%         [ oFlowIn, oFlowOut ] = this.getFlows(fFlowRate);
        
        function update(this)
            
            % Getting the flow object if the flow rate is not zero
            if ~(this.aoFlows(1).fFlowRate == 0)
                [ oFlowIn, ~ ] = this.getFlows();
            else
                % If the current flow rate is zero, the temperatur didn´t 
                % change
                this.fDeltaTemp = 0;
                return;
            end
            
            this.fDeltaTemp = oFlowIn.fTemperature - this.oBranch.oContainer.toStores.(this.sStore).aoPhases(1).toManips.substance.fTemperatureToFlow;
        end
    end
end