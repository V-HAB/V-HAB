classdef hx_flow < matter.procs.f2f
    %HX_FLOW: flow to flow processor to set the values for the outflows of 
    %         a heat exchanger 

    properties (SetAccess = protected, GetAccess = public)
        fDeltaTemp = 0;
        fDeltaPress = 0;
        bActive = true;
        
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
        
        function [ fDeltaPress, fDeltaTemp ] = solverDeltas(this, ~)
            this.oHXParent.update(); 
            if this.aoFlows(1).fFlowRate ~= 0
                fDeltaPress = this.fDeltaPress;
                oInFlow = this.getInFlow();
                this.fDeltaTemp = this.fHeatFlow/(oInFlow.fSpecificHeatCapacity*oInFlow.fFlowRate);
                fDeltaTemp  = this.fDeltaTemp;
            else
                fDeltaPress = 0;
                fDeltaTemp = 0;
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
            
        function fDeltaTemperature = updateManualSolver(this)
            this.oHXParent.update();
            if this.aoFlows(1).fFlowRate ~= 0
                oInFlow = this.getInFlow();
                this.fDeltaTemp = this.fHeatFlow/(oInFlow.fSpecificHeatCapacity*oInFlow.fFlowRate);
                fDeltaTemperature  = this.fDeltaTemp;
            else
                fDeltaTemperature = 0;
            end
            
        end
    end
end

