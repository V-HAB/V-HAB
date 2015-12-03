classdef Two_Tanks < vsys
    %EXAMPLE Example simulation for V-HAB 2.0
    %   This class creates blubb
    
    properties
        oSystemSolver;
        aoPhases;
    end
    
    methods
        function this = Two_Tanks(oParent, sName)
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
            this@vsys(oParent, sName, 60);
            
            % Creating a store, volume 0.5 m^3
            matter.store(this, 'Tank_1', 0.5);
            
            % Adding a phase to the store 'Tank_1'
            oPhaseTank(1) = this.toStores.Tank_1.createPhase('air', 0.5, 293, 0.4, 2*10^5);
            
            % Creating a second store, volume 0.5 m^3
            matter.store(this, 'Tank_2', 0.5);
            
            % Adding a phase to the store 'Tank_2
            oPhaseTank(2) = this.toStores.Tank_2.createPhase('air', 0.5, 293, 0.4, 1*10^5);
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.gas(oPhaseTank(1), 'Port_Out1' );
            matter.procs.exmes.gas(oPhaseTank(2), 'Port_In1');
            
            this.aoPhases = oPhaseTank;
            
            % Adding pipes to connect the components
            tutorials.incompressible_solver.components.pipe(this, 'Pipe_1', 1.0, 0.01, 0.0002);
            
            oBranch1 = matter.branch(this, 'Tank_1.Port_Out1', {'Pipe_1'}, 'Tank_2.Port_In1');
            
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch1);
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

