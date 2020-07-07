classdef hx_flow < matter.procs.f2f
    %HX_FLOW: flow to flow processor to set the values for the outflows of 
    %         a heat exchanger 

    properties (SetAccess = protected, GetAccess = public)
        fFlowRate = 0;
        
    end
    
    properties (SetAccess = protected, GetAccess = protected)
        oHXParent;    % An object to reference the parent heat exchanger object
    end
    
    methods
        function this = hx_flow(oHXParent, oContainer, sName)
            this@matter.procs.f2f(oContainer, sName);
            
            this.oHXParent = oHXParent;
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        function update(this)
           this.oBranch.oThermalBranch.setOutdated(); 
        end
        
        function updateThermal(this)
           this.oHXParent.update(); 
        end
        
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            % Setting the flow rate given to us by the solver
            this.fFlowRate = fFlowRate;
            
            % Updating the parent HX system, this will update both the
            % fDeltaPressure and fHeatFlow property of this processor.
            this.oBranch.oThermalBranch.setOutdated(); 
            
            % If the flow rate is non-zero we set the delta pressure
            % according to our property, otherwise it's just zero.
            if fFlowRate ~= 0
                fDeltaPressure = this.fDeltaPressure;
            else
                fDeltaPressure = 0;
            end
        end
        
        % Function to set the heat flow and pressure of the heat exchanger
        function setOutFlow(this, fHeatFlow, fDeltaPressure)
            this.fHeatFlow   = fHeatFlow;
            this.fDeltaPressure = fDeltaPressure;
        end
        
        function oInFlow = getInFlow(this)
            [ oInFlow, ~ ] = this.getFlows(); 
        end
            
        function updateManualSolver(this)
            this.fFlowRate = this.oBranch.fFlowRate;
            
            % Updating the parent HX system, this will update both the
            % fDeltaPressure and fHeatFlow property of this processor.
            this.oBranch.oThermalBranch.setOutdated(); 

        end
    end
end

