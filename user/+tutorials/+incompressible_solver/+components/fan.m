classdef fan < matter.procs.f2f
    % Just a f2f die create a constant delta pressure
    properties
        fDeltaPressure = 0;      % Pressure difference created by the fan in Pa
        iDir = 1;            % Direction of flow
       
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fDiameter = 0.1;        % diameter
        fLength = 0;            % Length of the component
        fDeltaTemp = 0;         % This fan model does not include temperature changes
        bActive = true;         % Must be true so the update function is called from the branch solver
    end
    
    methods
        function this = fan(oMT, sName, fMaxDeltaP, iDir)
            this@matter.procs.f2f(oMT, sName);
                        
            this.fDeltaPressure = fMaxDeltaP;
            this.iDir = iDir;
            
            this.supportSolver('hydraulic', this.fDiameter, this.fLength);

        end
        
        %% Update function for hydraulic solver
        function update(this)
            %constant pressure rise, so nothing is updated
        end
    end
    
end

