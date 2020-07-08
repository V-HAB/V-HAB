classdef CRA_H2_Regulator < matter.procs.f2f
   % This components regulates the inlet H2 pressure of CRA to a maximum of
   % 1.5 bar
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = CRA_H2_Regulator(oContainer, sName)

            this@matter.procs.f2f(oContainer, sName);
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
        end
        %% Update function for callback solver
        function fDeltaPressure = solverDeltas(this, ~)
            
            fSCRA_InletPressure = this.oBranch.coExmes{2}.getExMeProperties;
            if fSCRA_InletPressure > 1.5e5
                fDeltaPressure = fSCRA_InletPressure - 1.5e5;
            else
                fDeltaPressure = 0;
            end
            this.fDeltaPressure = fDeltaPressure;
        end

    end

end
