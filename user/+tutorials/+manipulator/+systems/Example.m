classdef Example < vsys
    %EXAMPLE Example simulation for V-HAB 2.0 including a manipulator
    %   Creates two tanks with 1 and 2  atmospheres of pressure,
    %   respectively. The tanks are connected via two pipes. In between the
    %   pipes, there is a simple model of a Bosch reactor system, removing
    %   CO2 from the air flow and reducing it to C and O2. 
    
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
            % Creating a store - volume 10m3
            matter.store(this, 'Tank_1', 10);
             
            % Create normal air (standard atmosphere) for 10m3 and 2 bar
            oAir = this.toStores.Tank_1.createPhase('air', 10, 293, 0.5, 2e5);
            
            % Adding an extract/merge processor to the phase
            matter.procs.exmes.gas(oAir, 'Outlet');
            
            
            % Creating a store - right side.
            matter.store(this, 'Tank_2', 10);
            
            % Create normal air (standard atmosphere) for 10m3. Here the 
            % tank and phase volume are the same, so the pressure will be
            % sea-level. 
            oAir = this.toStores.Tank_2.createPhase('air', 10);
            
            % Adding an extract/merge processor to the phase
            matter.procs.exmes.gas(oAir, 'Inlet');
            
            
            % Create the reactor. See the according files, just an example
            % for an implementation - copy to your own directory and change
            % as needed.
            fReactorVolume = 1;
            matter.store(this, 'Reactor', 1);
            
            % Creating two phases, on for the flow, one for the filter
            oFlowPhase     = this.toStores.Reactor.createPhase('air', 'FlowPhase',     fReactorVolume/2);
            oFilteredPhase = this.toStores.Reactor.createPhase('air', 'FilteredPhase', fReactorVolume/2);

                        % Create the according exmes
            % In- and Outlet for the flow phase
            matter.procs.exmes.gas(oFlowPhase,     'Inlet');
            matter.procs.exmes.gas(oFlowPhase,     'Outlet');
            % Each phase gets one exme for connection to the p2p proc. 
            matter.procs.exmes.gas(oFlowPhase,     'FilterPortIn');
            matter.procs.exmes.gas(oFilteredPhase, 'FilterPortOut');
            
            % Creating the manipulator
            tutorials.manipulator.components.DummyBoschProcess('DummyBoschProcess', oFlowPhase);
            
            % Createing the p2p processor.
            % Parameter: name, from, to, substance, capacity
            tutorials.manipulator.components.AbsorberExample(this, this.toStores.Reactor, 'FilterProc', 'FlowPhase.FilterPortIn', 'FilteredPhase.FilterPortOut', 'C', inf);

            
            % Adding pipes to connect the components
            components.matter.pipe(this, 'Pipe_1', 0.5, 0.005);
            components.matter.pipe(this, 'Pipe_2', 0.5, 0.005);
            
            % Creating the flowpath between the components
            matter.branch(this, 'Tank_1.Outlet',  { 'Pipe_1' }, 'Reactor.Inlet');
            matter.branch(this, 'Reactor.Outlet', { 'Pipe_2' }, 'Tank_2.Inlet');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.interval.branch(this.aoBranches(1));
            solver.matter.interval.branch(this.aoBranches(2));
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            % See above - time step of this .exec() method is set above,
            % can be used to update some stuff (e.g. apply external
            % disturbances as closing a valve).

        end
        
     end
    
end

