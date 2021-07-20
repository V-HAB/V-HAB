classdef SimplePressureRegulator < matter.procs.f2f
   % This components reduces the pressure in the branch to a specifiable
   % value as long as a higher inlet pressure is available
    properties (SetAccess = protected, GetAccess = public)
        fLimitPressure;
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = SimplePressureRegulator(oContainer, sName, fLimitPressure)

            this@matter.procs.f2f(oContainer, sName);
            
            this.fLimitPressure = fLimitPressure;
            
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
        end
        %% Update function for callback solver
        function fDeltaPressure = solverDeltas(this, ~)
            
            if this.oBranch.fFlowRate > 0
                fInletPressure = this.oBranch.coExmes{1}.getExMeProperties;
            else
                fInletPressure = this.oBranch.coExmes{2}.getExMeProperties;
            end
            
            if fInletPressure > this.fLimitPressure
                fDeltaPressure = fInletPressure - this.fLimitPressure;
            else
                fDeltaPressure = 0;
            end
            
            this.fDeltaPressure = fDeltaPressure;
        end

        function setLimitPressure(this, fLimitPressure)
            this.fLimitPressure = fLimitPressure;
        end
    end

end
