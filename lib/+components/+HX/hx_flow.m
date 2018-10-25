classdef hx_flow < matter.procs.f2f
    %HX_FLOW: flow to flow processor to set the values for the outflows of 
    %         a heat exchanger 

    properties (SetAccess = protected, GetAccess = public)
        fDeltaPress = 0;
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
           this.oHXParent.update(); 
        end
        
        function updateThermal(this)
           this.oHXParent.update(); 
        end
        
        function fDeltaPress = solverDeltas(this, fFlowRate)
            % Setting the flow rate given to us by the solver
            this.fFlowRate = fFlowRate;
            
            % Updating the parent HX system, this will update both the
            % fDeltaPressure and fHeatFlow property of this processor.
            this.oHXParent.update(); 
            
            % If the flow rate is non-zero we set the delta pressure
            % according to our property, otherwise it's just zero.
            if fFlowRate ~= 0
                fDeltaPress = this.fDeltaPress;
            else
                fDeltaPress = 0;
            end
        end
        
        % Function to set the heat flow and pressure of the heat exchanger
        function setOutFlow(this, fHeatFlow, fDeltaPress)
            this.fHeatFlow   = fHeatFlow;
            this.fDeltaPress = fDeltaPress;
        end
        
        function oInFlow = getInFlow(this)
            [ oInFlow, ~ ] = this.getFlows(); 
        end
            
        function updateManualSolver(this)
            this.fFlowRate = this.oBranch.fFlowRate;
            
            % Updating the parent HX system, this will update both the
            % fDeltaPressure and fHeatFlow property of this processor.
            this.oHXParent.update();

        end
    end
end

