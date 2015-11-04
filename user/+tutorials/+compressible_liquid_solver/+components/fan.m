classdef fan < matter.procs.f2f
    %FAN Linar, static, RPM independent fan model
    %   Interpolates between max flow rate and max pressure rise, values
    %   taken from AIAA-2012-3460 for a fan running at 4630 RMP
    
    properties
        fDeltaPressure = 0;      % Pressure difference created by the fan in Pa
        fMaxDeltaP;          % Maximum pressure rise in [Pa]
        iDir = 1;            % Direction of flow
       
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fDiameter = -1;         % Hydraulic diameter negative to indicate pressure rise
        fLength = 0;            % This just has to be there because of parent class and solver, value is irrelevant
        fDeltaTemp = 0;         % This fan model does not include temperature changes
        bActive = true;         % Must be true so the update function is called from the branch solver
    end
    
    methods
        function this = fan(sName, fMaxDeltaP)
            this@matter.procs.f2f(sName);
                        
            this.fMaxDeltaP   = fMaxDeltaP;
            this.fDeltaPressure = fMaxDeltaP;

        end
        
        function update(~)
            % Just need this here to shut up the solver
        end
        
    end
    
end

