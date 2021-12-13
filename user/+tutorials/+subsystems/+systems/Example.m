classdef Example < vsys
    %EXAMPLE Example simulation for a system with subsystems in V-HAB 2.0
    %   Two Tanks are connected to each other via pipes with a filter in
    %   between. The filter is modeled as a store with two phases, one
    %   being the connection (via exmes) to the system level branch. The
    %   filter itself is in a subsystem of this system called 'SubSystem'.
    %   So this tutorial serves as an example to show how branches between
    %   subsystems are created. The important thing to remember here is,
    %   that you have to discern between a branch from a suPersystem to a
    %   suBsystem or the other direction. This determines how you create
    %   the branch. 
    
    properties
        
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName);
            
            % If you want to use subsystems, you should add them here in
            % the constructor of the parent object.
            tutorials.subsystems.subsystems.ExampleSubsystem(this, 'SubSystem');
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Tank_1', 100);
            oGasPhase = this.toStores.Tank_1.createPhase('air', 20, 293, 0.5, 2e5);
            
            matter.store(this, 'Tank_2', 100);
            oAirPhase = this.toStores.Tank_2.createPhase('air', 20);
            
            components.matter.pipe(this, 'Pipe1', 1, 0.005);
            components.matter.pipe(this, 'Pipe2', 1, 0.005);
            
            %% Create Subsystem Connections:
            % Interface branches between the system and its subsystems are
            % always from the subsystem to the parent system, which means a
            % positive flowrate of the branch represents matter entering
            % the parent system and leaving the subsystem. Therefore, the
            % interfaces in the branch definition are always on the "left"
            % side! As interface, a string without any dots is used, as
            % string with dots (like e.g. 'Tank.Port1') represent a
            % Store.ExMe combination. These interfaces are then used in the
            % setIfFlows function to connect the branches of the parent
            % system to the corresponding branches in the subsystem. Note
            % that the branches will be removed from the parent system
            % (they will no longer be in the aoBranches or toBranches
            % struct of the parent system) as the logic is, that interface
            % branches belong to the respective subsystem (which therefore
            % also assigns the solvers etc.). The F2F components of the two
            % branches are combined to create one single branch. So any
            % F2Fs on the subsystem side are added to the left of the F2Fs
            % defined here! (They are the lower indices in the
            % oBranch.aoFlowProcs property)
            matter.branch(this, 'SubsystemInput',  {'Pipe1'}, oGasPhase);
            matter.branch(this, 'SubsystemOutput', {'Pipe2'}, oAirPhase);
            
            % The order in which the interfaces are handed to the
            % setIfFlows function depends on its function definition.
            % Please view the subsystem file for more information.
            this.toChildren.SubSystem.setIfFlows('SubsystemInput', 'SubsystemOutput');
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
        end
     end
end