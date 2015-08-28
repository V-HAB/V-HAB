classdef hx_flow < matter.procs.f2f
    %HX_FLOW: flow to flow processor to set the values for the outflows of 
    %         a heat exchanger 

    properties (SetAccess = protected, GetAccess = public)
        fDeltaTemp = 0;
        fDeltaPress = 0;
        bActive = true;
    end
    
    properties (SetAccess = protected, GetAccess = protected)
        oParent;    % An object to reference the parent heat exchanger object
    end
    
    methods
        function this = hx_flow(oParent, sName)
            this@matter.procs.f2f(sName);
            
            this.oParent     = oParent;
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        function update(this)
           this.oParent.update(); 
        end
        
        function [ fDeltaPress, fDeltaTemp ] = solverDeltas(this, ~)
           this.oParent.update(); 
           fDeltaPress = this.fDeltaPress;
           fDeltaTemp  = this.fDeltaTemp;
        end
        
        % Function to set the heat flow and pressure of the heat exchanger
        function setOutFlow(this, fHeatFlow, fDeltaPress)
            this.fHeatFlow   = fHeatFlow;
            this.fDeltaPress = fDeltaPress;
        end
        
        function oInFlow = getInFlow(this)
            [ oInFlow, ~ ] = this.getFlows(); 
        end
            
        function fDeltaTemperature = updateManualSolver(this)
            this.oParent.update();
            fDeltaTemperature = this.fDeltaTemp;
            
        end
    end
end

