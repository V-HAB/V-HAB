classdef (Abstract) vsys < matter.container & thermal.container & electrical.container & systems.timed
    %VSYS Basic system class in VHAB
    %   Inherits from matter.container, i.e. contains matter stores and
    %   processors. 
    %   Also inherits from thermal.container to include thermal
    %   network and associated solvers. These are also coupled to the
    %   current time step. 
    %   Also inherits from electrical container to
    %   include electrical circuits and their associated solvers, also
    %   coupled to current time step. 
    %   Also inherits from the systems.timed class and is executed with the
    %   parent or from the timer with the according time step.
    %   The class is defined as abstract since it must inherit from at
    %   least one domain (i.e. matter, thermal or electrical) to be able to
    %   execute simulations. 
    
    properties (SetAccess = protected, GetAccess = public)
        % A boolean variable indicating if the assembly of the vsys object
        % has been completed.
        bSealed;
    end

    
    methods
        function this = vsys(oParent, sName, xTimeStep)
            % Constructor method
            
            % If the provied time step is empty([]) the system is executed
            % a the same time step as its parent. If the time step is -1
            % the system is executed every tick. If the time step is a
            % logical false the system is executed with the global time
            % step of the timer. If no time step is set, the default value
            % is logical false.
            if nargin < 3, xTimeStep = false; end
            
            % Calling the constructors of all of the parent classes. This
            % leads to multiple calls of the sys constructor, that's ok
            % since this expected to happen and accordingly caught.
            this@systems.timed(oParent, sName, xTimeStep);
            this@matter.container(oParent, sName);
            this@thermal.container(oParent, sName);
            this@electrical.container(oParent, sName);
        
        end
        
        function createSolverStructure(this)
            %CREATESOLVERSTRUCTURE Calls the method of the same name on all
            % child systems of this object
            % Call in child elems
            
            % Getting the fieldnames
            csChildren = fieldnames(this.toChildren);
            
            % Looping throuhg all children and calling the
            % createSolverStructure() method.
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                this.toChildren.(sChild).createSolverStructure();
            end
        end
        
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            %EXEC Execution method where values pertaining to the operation
            % of a sytem are calculated.
            
            % Debugging output for each execution
            if ~base.oLog.bOff, this.out(2, 1, 'exec', 'vsys.exec system "%s"', { this.sName }); end
            
            % Calling the exec method of the parent class. 
            exec@systems.timed(this);
        end
    end 
end