classdef Example < vsys
    %EXAMPLE Example liquid flow simulation for V-HAB 2.0
    %   Two tanks, connected by two pipes with a pump in between. The flow
    %   rate setpoint for the pump is changed every 100 seconds. 
    
    properties
        iCells = 10;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 60);
            
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'WaterTank_1', 2);
            matter.store(this, 'WaterTank_2', 2);
            
            fDensityH2O = this.oMT.calculateDensity('liquid', struct('H2O', 100), 293, 101325);
            
            oWaterPhase1 = matter.phases.mixture(this.toStores.WaterTank_1, ...  Store in which the phase is located
                                                'Water_Phase', ...        Phase name
                                                'liquid',...
                                                struct('H2O', fDensityH2O * 0.1), ...   Phase contents
                                                293.15, ...                Phase temperature
                                                101325);                 % Phase pressure
            
            oWaterPhase2 = matter.phases.mixture(this.toStores.WaterTank_2, ...   Store in which the phase is located
                                                'Water_Phase', ...         Phase name
                                                'liquid',...
                                                struct('H2O', fDensityH2O * 0.1), ...      Phase contents
                                                293.15, ...                Phase temperature
                                                101325);                 % Phase pressure
            
            % Now we had a gas phase without any connections to fill the
            % remaining volume of the store
            this.toStores.WaterTank_1.createPhase('air', 2 - oWaterPhase1.fVolume, 293.15, 0.5, 1e5);
            oAir2 = this.toStores.WaterTank_2.createPhase('air', 2 - oWaterPhase2.fVolume, 293.15, 0.5, 1.1e5);                     
            
            % There are two options to calculate the volume distribution
            % within a store automatically. Either the standard definition
            % of phases that are compressible/incompressible can be used by
            % using the store function addStandardVolumeManipulators. In
            % that case only gases are considered compressible (and
            % mixtures with phase type gas)
            this.toStores.WaterTank_1.addStandardVolumeManipulators();
            
            % Alternativly the corresponding manipulators to identify a
            % phase as compressible can be added directly to the phases, to
            % allow the user to define what is compressible and what is
            % incompressible
            matter.manips.volume.StoreVolumeCalculation.compressibleMedium([oAir2.sName, '_CompressibleManip'], oAir2);
            matter.manips.volume.StoreVolumeCalculation.compressibleMedium([oWaterPhase2.sName, '_CompressibleManip'], oWaterPhase2);
            % An incompressible phase could be defined with the following
            % definition:
            % matter.manips.StoreVolumeCalculation.incompressibleMedium([oWaterPhase2.sName, '_CompressibleManip'], oWaterPhase2);
            
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
                coFlowNodeWater{iCell}  = this.toStores.FlowPath.createPhase('mixture', 'flow', ['WaterCell_', num2str(iCell)], 'liquid', 0.5 * fFlowVolume / this.iCells, struct('H2O', 1), 293.15, 1e5);
                
                matter.procs.exmes.gas(coFlowNodeAir{iCell},       ['P2P_Air', num2str(iCell)]);
                matter.procs.exmes.mixture(coFlowNodeWater{iCell}, ['P2P_Water', num2str(iCell)]);
                
                tests.mixture_flow.components.Adsorber(this.toStores.FlowPath, ['Adsorber_', num2str(iCell)], [coFlowNodeAir{iCell}.sName, '.P2P_Air', num2str(iCell)], [coFlowNodeWater{iCell}.sName, '.P2P_Water', num2str(iCell)]);
            end
            
            fAirPipeLength = 0.1;
            fAirPipeDiameter = 0.05;
            
            fWaterPipeLength = 0.1;
            fWaterPipeDiameter = 0.05;
            % Adding pipes tand branches to connect the flownodes
            for iCell = 1:this.iCells-1
                components.matter.pipe(this, ['AirPipe_',      num2str(iCell)], fAirPipeLength, fAirPipeDiameter, 2e-3);
                components.matter.pipe(this, ['WaterPipe_',    num2str(iCell)], fWaterPipeLength, fWaterPipeDiameter, 2e-3);
                
                matter.branch(this, coFlowNodeAir{iCell},   {['AirPipe_', num2str(iCell)]},     coFlowNodeAir{iCell+1},     ['AirFlowBranch_', num2str(iCell)]);
                matter.branch(this, coFlowNodeWater{iCell}, {['WaterPipe_', num2str(iCell)]},   coFlowNodeWater{iCell+1},   ['WaterFlowBranch_', num2str(iCell)]);
               
            end
            
            % Add in and outflow of the flow path for air
            components.matter.pipe(this, ['AirPipe_', num2str(this.iCells)], fAirPipeLength, fAirPipeDiameter, 2e-3);
            % Creating the flowpath between the components
            matter.branch(this, oAir1, {}, coFlowNodeAir{1}, 'AirFlowBranchInlet');
            matter.branch(this, coFlowNodeAir{end}, {['AirPipe_', num2str(this.iCells)]}, oAir2, ['AirFlowBranch_', num2str(this.iCells)]);
            
            % Adding a reflow pipe and branch for the air
            components.matter.pipe(this, 'AirPipe_Reflow', 1, 0.03, 2e-3);
            matter.branch(this, oAir2, {'AirPipe_Reflow'}, oAir1, 'AirReflow');
            
            % Add in and outflow of the flow path for water
            components.matter.pipe(this, ['WaterPipe_', num2str(this.iCells)], fWaterPipeLength, fWaterPipeDiameter, 2e-3);
            matter.branch(this, oWaterPhase1, {}, coFlowNodeWater{1}, 'WaterFlowBranchInlet');
            matter.branch(this, coFlowNodeWater{end}, {['WaterPipe_', num2str(this.iCells)]}, oWaterPhase2, ['WaterFlowBranch_', num2str(this.iCells)]);
            
            % Adding a reflow pipe and branch for the water
            components.matter.pipe(this, 'WaterPipe_Reflow', 1, 0.01, 2e-3);
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