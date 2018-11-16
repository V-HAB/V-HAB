classdef Example < vsys
    %EXAMPLE Example liquid flow simulation for V-HAB 2.0
    %   Two tanks, connected by two pipes with a pump in between. The flow
    %   rate setpoint for the pump is changed every 100 seconds. 
    
    properties
        iCells = 10;
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
            this@vsys(oParent, sName, 60);
            
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store
            matter.store(this, 'WaterTank_1', 2, false);
            
            % Creating a second store
            matter.store(this, 'WaterTank_2', 2, false);
            
            % Adding a phase with liquid water to the store
            oWaterPhase1 = matter.phases.liquid(this.toStores.WaterTank_1, ...  Store in which the phase is located
                                                'Water_Phase', ...        Phase name
                                                struct('H2O', 100), ...   Phase contents
                                                293.15, ...                Phase temperature
                                                101325);                 % Phase pressure
            
            
            % Adding an empty phase to the second store, this represents an
            % empty tank
            oWaterPhase2 = matter.phases.liquid(this.toStores.WaterTank_2, ...   Store in which the phase is located
                                                'Water_Phase', ...         Phase name
                                                struct('H2O', 100), ...      Phase contents
                                                293.15, ...                Phase temperature
                                                101325);                 % Phase pressure
            
            % Now we had a gas phase without any connections to fill the
            % remaining volume of the store
            this.toStores.WaterTank_1.createPhase('air', 2 - oWaterPhase1.fVolume, 293.15, 0.5, 1e5);
            this.toStores.WaterTank_2.createPhase('air', 2 - oWaterPhase2.fVolume, 293.15, 0.5, 1.1e5);                     
            
            % We also add two stores containing air
            matter.store(this, 'AirTank_1', 2);
            matter.store(this, 'AirTank_2', 2);
            oAir1 = this.toStores.AirTank_1.createPhase('gas', 'AirPhase', 2, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293.15, 0.5);
            oAir2 = this.toStores.AirTank_2.createPhase('gas', 'AirPhase', 2, struct('N2', 1.1*8e4, 'O2', 1.1*2e4, 'CO2', 1.1*500), 293.15, 0.5);
            
            
            fFlowVolume = 1e-4;
            matter.store(this, 'FlowPath', fFlowVolume);
            
            
            % Adding flow nodes to the store for water and air
            coFlowNodeAir = cell(this.iCells,1);
            coFlowNodeWater = cell(this.iCells,1);
            for iCell = 1:this.iCells
                coFlowNodeAir{iCell}    = this.toStores.FlowPath.createPhase('gas', 'flow', ['AirCell_', num2str(iCell)], 0.5 * fFlowVolume / this.iCells, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293.15, 0.5);
                coFlowNodeWater{iCell}  = matter.phases.flow.liquid(this.toStores.FlowPath, ['WaterCell_', num2str(iCell)], struct('H2O', 1e-9), 0.5 * fFlowVolume / this.iCells, 293.15);
            end
            
            fAirPipeLength = 0.1;
            fAirPipeDiameter = 0.05;
            
            fWaterPipeLength = 0.1;
            fWaterPipeDiameter = 0.05;
            % Adding pipes tand branches to connect the flownodes
            for iCell = 1:this.iCells-1
                components.pipe(this, ['AirPipe_',      num2str(iCell)], fAirPipeLength, fAirPipeDiameter, 2e-3);
                components.pipe(this, ['WaterPipe_',    num2str(iCell)], fWaterPipeLength, fWaterPipeDiameter, 2e-3);
                
                matter.branch(this, coFlowNodeAir{iCell},   {['AirPipe_', num2str(iCell)]},     coFlowNodeAir{iCell+1},     ['AirFlowBranch_', num2str(iCell)]);
                matter.branch(this, coFlowNodeWater{iCell}, {['WaterPipe_', num2str(iCell)]},   coFlowNodeWater{iCell+1},   ['WaterFlowBranch_', num2str(iCell)]);
                
            end
            
            % Add in and outflow of the flow path for air
            components.pipe(this, ['AirPipe_', num2str(this.iCells)], fAirPipeLength, fAirPipeDiameter, 2e-3);
            % Creating the flowpath between the components
            matter.branch(this, oAir1, {}, coFlowNodeAir{1}, 'AirFlowBranchInlet');
            matter.branch(this, coFlowNodeAir{end}, {['AirPipe_', num2str(this.iCells)]}, oAir2, ['AirFlowBranch_', num2str(this.iCells)]);
            
            % Adding a reflow pipe and branch for the air
            components.pipe(this, 'AirPipe_Reflow', 1, 0.03, 2e-3);
            matter.branch(this, oAir2, {'AirPipe_Reflow'}, oAir1, 'AirReflow');
            
            % Add in and outflow of the flow path for water
            components.pipe(this, ['WaterPipe_', num2str(this.iCells)], fWaterPipeLength, fWaterPipeDiameter, 2e-3);
            matter.branch(this, oWaterPhase1, {}, coFlowNodeWater{1}, 'WaterFlowBranchInlet');
            matter.branch(this, coFlowNodeWater{end}, {['WaterPipe_', num2str(this.iCells)]}, oWaterPhase2, ['WaterFlowBranch_', num2str(this.iCells)]);
            
            % Adding a reflow pipe and branch for the water
            components.pipe(this, 'WaterPipe_Reflow', 1, 0.01, 2e-3);
            matter.branch(this, oWaterPhase2, {'WaterPipe_Reflow'}, oWaterPhase1, 'WaterReflow');
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the linear
            % solver. 
            solver.matter.manual.branch(this.toBranches.AirFlowBranchInlet);
            solver.matter.manual.branch(this.toBranches.WaterFlowBranchInlet);
            
            this.toBranches.AirFlowBranchInlet.oHandler.setFlowRate(0.1);
            this.toBranches.WaterFlowBranchInlet.oHandler.setFlowRate(0.1);
            
            for iCell = 1:this.iCells
                aoAirFlowBranches(iCell)    = this.toBranches.(['AirFlowBranch_', num2str(iCell)]); %#ok
                aoWaterFlowBranches(iCell)  = this.toBranches.(['WaterFlowBranch_', num2str(iCell)]); %#ok
            end
            aoAirFlowBranches(end+1)    = this.toBranches.AirReflow;
            aoWaterFlowBranches(end+1)  = this.toBranches.WaterReflow;
            
            solver.matter_multibranch.iterative.branch([aoAirFlowBranches, aoWaterFlowBranches]);
            
            tTimeStepProperties.rMaxChange = 0.001;
            this.toStores.WaterTank_1.toPhases.Water_Phase.setTimeStepProperties(tTimeStepProperties);
            this.toStores.WaterTank_2.toPhases.Water_Phase.setTimeStepProperties(tTimeStepProperties);
            this.toStores.AirTank_1.toPhases.AirPhase.setTimeStepProperties(tTimeStepProperties);
            this.toStores.AirTank_2.toPhases.AirPhase.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
        end
        
     end
    
end

