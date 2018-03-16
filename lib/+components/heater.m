classdef heater < matter.procs.f2f
    %HEATER dummy heater
    
    
    properties (SetAccess = public, GetAccess = public)
        fPower      = 0;
        rEfficiency = 1;
    end
    
    methods
        function this = heater(oMT, sName, fPower, rEfficiency)
            this@matter.procs.f2f(oMT, sName);
            
            if nargin > 2
                this.fPower = fPower;
            end
            
            if nargin > 3
                this.rEfficiency = rEfficiency;
            end
            
            this.fHeatFlow = this.fPower * this.rEfficiency;
            
            this.supportSolver('hydraulic', 1, 0);
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        function updateManualSolver(this)
            this.fHeatFlow = this.fPower * this.rEfficiency;
        end
        
        function fDeltaPress = solverDeltas(this, ~)
            this.fHeatFlow = this.fPower * this.rEfficiency;
            fDeltaPress = 0;
        end
        
        function setPower(this, fPower)
            this.fPower = fPower;
            this.fHeatFlow = this.fPower * this.rEfficiency;
        end
        
    end
    
end

