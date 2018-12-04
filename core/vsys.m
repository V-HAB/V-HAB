    %VSYS Typical system in VHAB
    %   Derives from matter.container and the systems.timed class, i.e. 
    %   contains matter stores/processors and is executed with the parent 
    %   or from the timer with the according time step. Also derives from
    %   thermal.container to include thermal network and associated
    %   solvers. These are also coupled to the current time step.
    %   Also derives from electrical container to include electrical
    %   circuits and their associated solvers, also coupled to current time
    %   step.
classdef (Abstract) vsys < matter.container & thermal.container & electrical.container & systems.timed
    
    properties (SetAccess = protected, GetAccess = public)
        bSealed;
    end
    
    methods
        function this = vsys(oParent, sName, fTimeStep)
            % Time step [] means with parent, -1 for every tick, 0 for
            % global time step.
            if nargin < 3, fTimeStep = false; end
            
            % Leads to a double call of the sys constructor, that's ok
            % since this expected to happen and accordingly caught
            this@systems.timed(oParent, sName, fTimeStep);
            this@matter.container(oParent, sName);
            this@thermal.container(oParent, sName);
            this@electrical.container(oParent, sName);
        
        end
        
        function createSolverStructure(this)
            % Call in child elems
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                this.toChildren.(sChild).createSolverStructure();
            end
        end
        
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            if ~base.oLog.bOff, this.out(2, 1, 'exec', 'vsys.exec system "%s"', { this.sName }); end
            
            exec@systems.timed(this);
        end
    end 
end