classdef CRA_Vacuum_Outlet < matter.procs.f2f
   
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = CRA_Vacuum_Outlet(oContainer, sName)

            this@matter.procs.f2f(oContainer, sName);
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
        end
        %% Update function for callback solver
        function fDeltaPressure = solverDeltas(this, ~)
            
            fDeltaPressure = 9e4;
            this.fDeltaPressure = fDeltaPressure;
        end

    end

end
