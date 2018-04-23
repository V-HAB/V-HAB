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
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName);
            
            
            %TODO -> DOCUMENT!
            %   -> here, just process Ctor params and set e.g. defualt
            %      properties
            %   -> ALSO, add subsystems
            
            
            % Adding the subsystem
            tutorials.subsubsystems.subsystems.MiddleSystem(this, 'MiddleSystem');
            
            
            
            
            % THEN do this:
            eval(this.oRoot.oCfgParams.configCode(this));
            % -> COnfig params
            
            
            
            
            
            % MAtter stuff in createMatterStructure, solvers in
            % createSovlerStructure. Stuff like connectIfs has to be done
            % in createMatterStructure!
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            % Adding a phase to the store 'Tank_1', 2 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 2);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            
            % Adding a phase to the store 'Tank_2', 1 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
            
            
                        
            %% Adding some pipes
            components.pipe(this, 'Pipe1', 1, 0.005);
            components.pipe(this, 'Pipe2', 1, 0.005);
            
            % Creating the flowpath (=branch) into a subsystem
            % Input parameter format is always: 
            % 'Interface port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'MiddleSystemInput', {'Pipe1'}, 'Tank_1.Port_1');
            
            % Creating the flowpath (=branch) out of a subsystem
            % Input parameter format is always: 
            % 'Interface port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'MiddleSystemOutput', {'Pipe2'}, 'Tank_2.Port_2');
            
            
            
            
            %%% NOTE!!! setIfFlows has to be done in createMatterStructure!
            
            % Now we need to connect the subsystem with the top level system (this one). This is
            % done by a method provided by the subsystem.
            this.toChildren.MiddleSystem.setIfFlows('MiddleSystemOutput', 'MiddleSystemInput');
            
            
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            %this.seal();
            % NOT ANY MORE!
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            % SOLVERS ETC!
            
            % specific properties for rMaxChange etc, possibly depending on
            % this.tSolverProperties.XXX
            % OR this.oRoot.tSolverProperties !!!
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
        end
        
     end
    
end

