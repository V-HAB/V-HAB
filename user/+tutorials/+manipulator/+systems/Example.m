classdef Example < vsys
    %EXAMPLE Example simulation for V-HAB including a manipulator
    %   Creates two tanks with 1 and 2 atmospheres of pressure,
    %   respectively. The tanks are connected via two pipes. In between the
    %   pipes, there is a simple model of a Bosch reactor system, removing
    %   CO2 from the air flow and reducing it to C and O2. 
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 30);
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Tank_1', 10);
            oAir = this.toStores.Tank_1.createPhase('air', 10, 293, 0.5, 2e5);
            matter.procs.exmes.gas(oAir, 'Outlet');
            
            matter.store(this, 'Tank_2', 10);
            oAir = this.toStores.Tank_2.createPhase('air', 10);
            matter.procs.exmes.gas(oAir, 'Inlet');
            
            fReactorVolume = 1;
            matter.store(this, 'Reactor', 1);
            oFlowPhase     = this.toStores.Reactor.createPhase('air', 'FlowPhase',     fReactorVolume/2);
            oFilteredPhase = this.toStores.Reactor.createPhase('air', 'FilteredPhase', fReactorVolume/2);

            matter.procs.exmes.gas(oFlowPhase,     'Inlet');
            matter.procs.exmes.gas(oFlowPhase,     'Outlet');
            matter.procs.exmes.gas(oFlowPhase,     'FilterPortIn');
            matter.procs.exmes.gas(oFilteredPhase, 'FilterPortOut');
            
            % Creating the manipulator. The filepath
            % "tutorials.manipulator.components.DummyBoschProcess" depends
            % on the location of the class file for the manipulator we want
            % to add. The inputs depend on the definition of the respecitve
            % manipulator class. Please open the manipulator file of this
            % tutorial to find additional information with regard to
            % manipulators.
            tutorials.manipulator.components.DummyBoschProcess('DummyBoschProcess', oFlowPhase);
            
            % Use the P2P from the P2P example, if you want to learn more
            % about P2Ps please view that tutorial!
            components.matter.P2Ps.ConstantMassP2P(this.toStores.Reactor, 'FilterProc', 'FlowPhase.FilterPortIn', 'FilteredPhase.FilterPortOut', {'C'}, 1);
            
            components.matter.pipe(this, 'Pipe_1', 0.5, 0.005);
            components.matter.pipe(this, 'Pipe_2', 0.5, 0.005);
            
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
        end
     end
end