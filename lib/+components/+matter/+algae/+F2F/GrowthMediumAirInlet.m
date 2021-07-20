classdef GrowthMediumAirInlet < matter.procs.f2f
   
    properties (SetAccess = protected, GetAccess = public)
        fTargetPressure = 60000;
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = GrowthMediumAirInlet(oContainer, sName)

            this@matter.procs.f2f(oContainer, sName);
            
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
        end
        %% Update function for callback solver
        function fDeltaPressure = solverDeltas(this, ~)
            
            [ oFlowIn, ~ ] = this.getFlows();
            
            fDeltaPressure = oFlowIn.fPressure - this.fTargetPressure;
            this.fDeltaPressure = fDeltaPressure;
        end

    end

end
