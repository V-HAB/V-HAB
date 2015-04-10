classdef hx_flow < solver.matter.iterative.procs.f2f
    %HX_FLOW: flow to flow processor to set the values for the outflows of 
    %         a heat exchanger 

    properties (SetAccess = protected, GetAccess = public)
        fDeltaTemp = 0;
        fDeltaPressure = 0;
        fDeltaPress = 0;
        fHydrDiam = 0;
        fHydrLength = 0;
        bActive = true;
    end
    
    properties (SetAccess = protected, GetAccess = protected)
        oParent;    % An object to reference the parent heat exchanger object
    end
    
    methods
        function this = hx_flow(oParent, oMT, sName, fHydrDiam, fHydrLength)
            this@solver.matter.iterative.procs.f2f(oMT, sName);
            
            this.fHydrDiam   = fHydrDiam;
            this.fHydrLength = fHydrLength;
            this.oParent     = oParent;
        end
        
        function update(this)
           this.oParent.update(); 
        end
        
        function [ fDeltaPress, fDeltaTemp ] = solverDeltas(this, ~)
           this.oParent.update(); 
           fDeltaPress = 0;
           fDeltaTemp = 0;
        end
        
        %function to set the outlet temperature and pressure of the heat
        %exchanger
        function setOutFlow(this, fDeltaTemp, fDeltaPress)
            
            this.fDeltaTemp = fDeltaTemp;
            this.fDeltaPress = fDeltaPress;
            this.fDeltaPressure = this.fDeltaPress;
        end
        
        function oInFlow = getInFlow(this)
            [ oInFlow, ~ ] = this.getFlows(); 
        end
            
        
    end
end

