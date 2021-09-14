classdef Example < vsys
    %EXAMPLE Example simulation for a system with subsystems in V-HAB 2.0
    %   The difference to the subsystems example is, that an additional
    %   layer is added here (we have this parent system, which has a
    %   subsystem called MiddleSystem and then the subsystem containing a
    %   filter from the subsystems tutorial). This serves to show the
    %   option to have multiple hierarchical layers of systems in V-HAB and
    %   also to showcase so called "pass through" branches which have no
    %   connection within a system but are only a connection from subsystem
    %   of the current system to the parent system. These will be located
    %   in the middle system for this tutorial.
    
    properties
        
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 10);
            
            tutorials.subsubsystems.subsystems.MiddleSystem(this, 'MiddleSystem');
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Tank_1', 20);
            oGasPhase = this.toStores.Tank_1.createPhase('air', 20, 293, 0.5, 2e5);
            
            matter.store(this, 'Tank_2', 20);
            oAirPhase = this.toStores.Tank_2.createPhase('air', 20);
            
            components.matter.pipe(this, 'Pipe1', 1, 0.005);
            components.matter.pipe(this, 'Pipe2', 1, 0.005);
            
            matter.branch(this, 'MiddleSystemInput',  {'Pipe1'}, oGasPhase);
            matter.branch(this, 'MiddleSystemOutput', {'Pipe2'}, oAirPhase);
            
            this.toChildren.MiddleSystem.setIfFlows('MiddleSystemOutput', 'MiddleSystemInput');
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