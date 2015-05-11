classdef heater < matter.procs.f2f
    %HEATER dummy heater
    
    
    properties (SetAccess = protected, GetAccess = public)
        fPower      = 0;
        rEfficiency = 0.75;
    end
    
    methods
        function this = heater(oMT, sName)
            this@matter.procs.f2f(oMT, sName);
            
            this.supportSolver('hydraulic', 1, 0);
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        
        function setPower(this, fPower)
            this.fPower    = fPower;
            this.fHeatFlow = this.fPower * this.rEfficiency;
            
            this.oBranch.setOutdated();
        end
        
        function fDeltaPress = solverDeltas(this, ~) %#ok<INUSD>
            fDeltaPress = 0;
        end
    end
    
end

