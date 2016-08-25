classdef dummyF2F < matter.procs.f2f
    %DUMMYF2F A filler f2f processor for use in pass-through branches
    %   This processor does nothing except provide an interface for two
    %   flows to attach to.
    
    properties
    end
    
    methods
        function this = dummyF2F(oContainer, sName)

            this@matter.procs.f2f(oContainer, sName);

            this.supportSolver('hydraulic', 0, 0);
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
            this.supportSolver('coefficient',  @this.calculatePressureDropCoefficient);

        end
        
        function fReturnValue = solverDeltas(~, ~)
            fReturnValue = 0;
        end
        
        function fReturnValue = calculatePressureDropCoefficient(~, ~)
            fReturnValue = 0;
        end
        
    end
    
end

