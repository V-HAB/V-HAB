classdef Filter_F2F < matter.procs.f2f
    
    properties (SetAccess = protected, GetAccess = public)
        
        fFrictionFactor   = 0;
        
        % Pressure differential caused by the pipe in [Pa]
        fDeltaPressure  = 0;
        
        bActive = false;
        
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = Filter_F2F(oContainer, sName, fFrictionFactor)

            this@matter.procs.f2f(oContainer, sName);

            this.fFrictionFactor   = fFrictionFactor;
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
        end
        %% Update function for callback solver
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            fDeltaPressure = fFlowRate^2 * this.fFrictionFactor;
            this.fDeltaPressure = fDeltaPressure;
        end

    end

end
