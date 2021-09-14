classdef MiddleSystem < vsys
    %EXAMPLESUBSYSTEM A subsystem containing nothin except another
    % subsystem. This is just used to showcase "pass-through" branches and
    % hierarchical subsystem in V-HAB
    
    properties
    end
    
    methods
        function this = MiddleSystem(oParent, sName)
            
            this@vsys(oParent, sName);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            % Adding the subsystem. For this purpose, we reuse the
            % subsystem from the subsystem example:
            tutorials.subsystems.subsystems.ExampleSubsystem(this, 'SubSystem');
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            components.matter.pipe(this, 'Pipe3', 1, 0.005);
            components.matter.pipe(this, 'Pipe4', 1, 0.005);
            
            % Pass through branches are branches, which only have interface
            % and are not connected to any phase within the current system.
            % In this example, the branches connect the subsystem with the
            % parent system.
            matter.branch(this, 'FromSubOut', {'Pipe3'}, 'ToSupIn');
            matter.branch(this, 'FromSubIn',  {'Pipe4'}, 'ToSupOut');
            
            this.toChildren.SubSystem.setIfFlows('FromSubIn', 'FromSubOut');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            this.setThermalSolvers();
        end
        
        function setIfFlows(this, sToSupIn, sToSupOut)
            this.connectIF('ToSupIn',  sToSupIn);
            this.connectIF('ToSupOut', sToSupOut);
        end
    end
    
     methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
        end
     end
end