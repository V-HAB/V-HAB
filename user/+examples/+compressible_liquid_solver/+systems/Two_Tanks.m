classdef Two_Tanks < vsys
    %EXAMPLE Example simulation for V-HAB 2.0
    %   This class creates blubb
    
    properties
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
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            % Creating a store
            matter.store(this, 'Tank_1', 1);
            
            % Creating a second store
            matter.store(this, 'Tank_2', 1);
            
            oWaterPhase1 = this.toStores.Tank_1.createPhase('water', 1, 293, 2*10^5);
            %oAirPhase1 = this.toStores.Tank_1.createPhase('air', 0.5, 293, 0, 2*10^5);
            
            % Adding a phase to the store 'Tank_2'
            oWaterPhase2 = this.toStores.Tank_2.createPhase('water', 1, 293, 1*10^5);
            %oAirPhase2 = this.toStores.Tank_2.createPhase('air', 0.5, 293, 0, 1*10^5);
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.liquid(oWaterPhase1, 'Port_1' );
            matter.procs.exmes.liquid(oWaterPhase2, 'Port_2');
            
            % Adding pipes to connect the components
            components.matter.pipe(this, 'Pipe_1', 1.0, 0.01, 0.002);
            
            matter.branch(this, 'Tank_1.Port_1', {'Pipe_1'}, 'Tank_2.Port_2');

        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %for branch liquid the second entry is the number of cells used
            %to calculate the branches
            %branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, sCourantAdaption)
            sCourantAdaption = struct( 'bAdaption', 0,'fIncreaseFactor', 1.001, 'iTicksBetweenIncrease', 100, 'iInitialTicks', 10000, 'fMaxCourantNumber', 1);
            solver.matter.fdm_liquid.branch_liquid(this.aoBranches(1), 10, 10^-5, 0, 1, sCourantAdaption);
            
            this.setThermalSolvers();
        end
        
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
    end
    
end

