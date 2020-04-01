classdef radiator < matter.procs.f2f
    
    properties (SetAccess = protected, GetAccess = public)
        fArea;
        fEmissivity;
    end
    
    methods
        function this = radiator(oMT, sName, fArea, fEmissivity)
            this@matter.procs.f2f(oMT, sName);
            
            this.fArea = fArea;
            this.fEmissivity = fEmissivity;
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        function updateManualSolver(this)
            try
                [Flow1, Flow2] = this.getFlows();
                
                if Flow1.fFlowRate > 0
                    inFlow = Flow1;
                else
                    inFlow = Flow2;
                end
            catch
                inFlow = this.aoFlows(1);
            end
            
            this.fHeatFlow = - this.oMT.Const.fStefanBoltzmann * inFlow.fTemperature^4 * this.fArea * this.fEmissivity;
        end
        
        function setActive(this, bActive, ~)
            this.bActive = bActive;
        end
    end
end