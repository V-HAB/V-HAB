classdef Filter_F2F < matter.procs.f2f
    % This F2F models the air outlet filter of CDRA which can become
    % clogged, resulting in increased pressure losses
    properties (SetAccess = protected, GetAccess = public)
        
        fFrictionFactor   = 1.6e8;
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = Filter_F2F(oContainer, sName, fFrictionFactor)

            this@matter.procs.f2f(oContainer, sName);

            if nargin >= 3
                this.fFrictionFactor   = fFrictionFactor;
            end
            
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
