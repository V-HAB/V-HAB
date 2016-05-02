classdef Example < vsys
    %EXAMPLE Example simulation for a fan driven gas flow in V-HAB 2.0
    %   Two tanks, filled with gas at different pressures, a fan in between
    %   and two pipes to connect it all
    
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
            this@vsys(oParent, sName, 30);
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 2);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
            
            % Adding a fan to move the gas
            components.fan_simple(this, 'Fan', 2000, false);
            
            % Adding a pipe to connect the tanks
            components.pipe(this, 'Pipe_1', 1, 0.01);
            components.pipe(this, 'Pipe_2', 1, 0.01);
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe_1', 'Fan', 'Pipe_2'}, 'Tank_2.Port_2', 'Branch');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the iterative
            % solver. 
            solver.matter.iterative.branch(this.toBranches.Branch);
            
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

