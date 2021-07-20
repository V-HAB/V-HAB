classdef CondenserCounterpart < matter.procs.f2f
    
    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam = 1;          % Hydraulic diameter value irrelevant for manual solver
        fHydrLength = 0;        % hydrauloc length, value irrelevant for manual solver
        bActiveTemperatureRegulation = true;
       
        oCondenser;
        oCondenserP2P;
    end
    
    methods
        function this = CondenserCounterpart(oMT, sName, oCondenser, oCondenserP2P)
            this@matter.procs.f2f(oMT, sName);
            
            this.oCondenser = oCondenser;
            this.oCondenserP2P = oCondenserP2P;
            
            this.supportSolver('manual', true, @this.updateManualSolver);
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        function updateManualSolver(~)
        end
        function fDeltaPressure = solverDeltas(~, ~)
            fDeltaPressure = 0;
        end
        function updateThermal(this)
            
            this.fHeatFlow = -this.oCondenser.fTempChangeHeatFlow + 2.2564e+06 * this.oCondenserP2P.fFlowRate;
        end
        
        
        function setActive(this, bActive, ~)
            this.bActiveTemperatureRegulation = bActive;
        end
    end
end