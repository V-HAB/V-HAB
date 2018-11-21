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
        fDiameter = 1;          % Hydraulic diameter 
        fLength = 0;            % This just has to be there because of parent class and solver, value is irrelevant
        fDeltaTemp = 0;         % This fan model does not include temperature changes
            
    end
    
    methods
        function this = fan(oContainer, sName, fMaxDeltaP)
            this@matter.procs.f2f(oContainer, sName);
                        
            this.fMaxDeltaP   = fMaxDeltaP;
            this.fDeltaPressure = fMaxDeltaP;
            this.bActive = true;         % Must be true so the update function is called from the branch solver


            this.supportSolver('hydraulic', this.fDiameter, this.fLength);
        end
        
        
        function update(this)
            %no function just necessary for solver
        end
        
    end
    
end

