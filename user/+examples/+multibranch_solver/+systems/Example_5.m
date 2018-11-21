classdef Example_5 < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 0.5;
        fPipeDiameter = 0.0254/3; 
    end
    
    methods
        function this = Example_5(oParent, sName)
            this@vsys(oParent, sName, 100);
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            %% Define Stuff
            
            % Col - Store Idx, Row 1 - pressure factor, Row 2 - volume
            aafStores = [
                1, 1, 3,     0, 5;
                1, 1, 2.5, 100, 0.5
            ];
            
            iValves = 2;
            
            % Connections - S1, S2, ..., Sx; V1 ... Vx
            % Values - pipe lengths
            cConnections = {
                'S1', 1, 'V1';
                'S2', 2, 'V1';
                
                'V1', 1, 'S3';
                'S3', 2, 'V2';
                
                'V2', 5, 'S4';
                'V2', 1, 'S5';
            };
            
            
            
            %% Auto-Create Stuff
            
            %%%%%%%% Create stores %%%%%%%%
            for iStore = 1:size(aafStores, 2)
                sStore = sprintf('S%i', iStore);
                oStore = matter.store(this, sStore, aafStores(2, iStore));
                
                oStore.createPhase('N2Atmosphere', oStore.fVolume, 293, 0.5, 10^5 * aafStores(1, iStore));
            end
            
            
            %%%%%%%% Valves %%%%%%%%
            for iValve = 1:iValves
                sValve = sprintf('V%i', iValve);
                oStore = matter.store(this, sValve, 1e-6);
                
                cParams = matter.helper.phase.create.N2Atmosphere(this, oStore.fVolume);
                matter.phases.flow.gas(oStore, 'flow', cParams{:});
            end
            
            
            %%%%%%%% Connections %%%%%%%%
            for iBranch = 1:size(cConnections, 1)
                sBranch = sprintf('%s_%s', cConnections{iBranch, 1}, cConnections{iBranch, 3});
                sPipe   = [ 'Pipe__' sBranch ];
                sExmeL  = [ 'To__' sBranch ];
                sExmeR  = [ 'From__' sBranch ];
                
                % Pipe with length defined in cConnections
                components.matter.pipe(this, sPipe, cConnections{iBranch, 2}, 0.0035);
                
                
                %%%% Create exmes
                oStoreLeft  = this.toStores.(cConnections{iBranch, 1});
                oStoreRight = this.toStores.(cConnections{iBranch, 3});
                
                matter.procs.exmes.gas(oStoreLeft.aoPhases(1),  sExmeL);
                matter.procs.exmes.gas(oStoreRight.aoPhases(1), sExmeR);
                
                %%%% Create branch
                matter.branch(this, ...
                    sprintf('%s.%s', cConnections{iBranch, 1}, sExmeL), ...
                    { sPipe }, ...
                    sprintf('%s.%s', cConnections{iBranch, 3}, sExmeR) ...
                );
            end
            
            
            
            
            return;
            
            matter.store(this, 'Store_1', 10);
            this.toStores.Store_1.createPhase('N2Atmosphere', this.toStores.Store_1.fVolume);
            matter.procs.exmes.gas(this.toStores.Store_1.aoPhases(1), 'Port_ToV1');
            
            matter.store(this, 'Store_2', 2.5);
            this.toStores.Store_2.createPhase('N2Atmosphere', this.toStores.Store_2.fVolume * 3);
            matter.procs.exmes.gas(this.toStores.Store_2.aoPhases(1), 'Port_FromV1');
            matter.procs.exmes.gas(this.toStores.Store_2.aoPhases(1), 'Port_ToV2');
            matter.procs.exmes.gas(this.toStores.Store_2.aoPhases(1), 'Port_ToV3');
            
            matter.store(this, 'Store_3', 1);
            this.toStores.Store_3.createPhase('N2Atmosphere', this.toStores.Store_3.fVolume * 2);
            matter.procs.exmes.gas(this.toStores.Store_2.aoPhases(1), 'Port_FromV2');
            matter.procs.exmes.gas(this.toStores.Store_2.aoPhases(1), 'Port_ToV4');
            
            matter.store(this, 'Vacuum', 1000000);
            this.toStores.Vacuum.createPhase('N2Atmosphere', 0);
            matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_FromV3');
            matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_FromV4');
            
            
            iValves = 4;
            
            for iT = 1:iValves
                sN = sprintf('Valve_%i', iT);
                
                matter.store(this, sN, 1e-6);
                cParams = matter.helper.phase.create.N2Atmosphere(this, this.toStores.(sN).fVolume);
                matter.phases.flow.gas(this.toStores.(sN), 'flow', cParams{:});
                matter.procs.exmes.gas(this.toStores.(sN).aoPhases(1), 'Port_1');
                matter.procs.exmes.gas(this.toStores.(sN).aoPhases(1), 'Port_2');
                matter.procs.exmes.gas(this.toStores.(sN).aoPhases(1), 'Port_3');
            
            end
            
            
            tiPipesWithFactors = struct(...
                'T1_V1', 1, ...
                'V1_T2', 1, ...
                'V1_V2', 1, ...
                'T2_V2', 2, ...
                'V2_T3', 1, ...
                'T2_V3', 1, ...
                'V3_V4', 3, ...
                'T3_V4', 1, ...
                'V3_T4', 1, ...
                'V4_T4', 3 ...
            );
            csPipesWithFactors = fieldnames(tiPipesWithFactors);
            
            for iP = 1:length(csPipesWithFactors)
                sPipe   = [ 'Pipe_' csPipesWithFactors{iP} ];
                iFactor = tiPipesWithFactors.(csPipesWithFactors{iP});
                
                components.matter.pipe(this, sPipe, this.fPipeLength * iFactor, this.fPipeDiameter);
            end
            
            % Resistors
            components.matter.pipe(this, 'R_1',  0.1, 0.001);
            components.matter.pipe(this, 'R_2',  0.1, 0.001);
            components.matter.pipe(this, 'R_3',  0.1, 0.001);
            components.matter.pipe(this, 'R_4',  0.1, 0.001);
            components.matter.pipe(this, 'R_5',  0.1, 0.001);
            
            
            matter.branch(this, 'Store.Port_Out', { 'Pipe_1' }, 'Valve_1.Port_1');
            
            %matter.branch(this, 'Valve_1.Port_2', { 'Pipe_2', 'R_2' }, 'Valve_2.Port_1');
            matter.branch(this, 'Valve_1.Port_2', { 'Pipe_2' }, 'Valve_2.Port_1');
            
            matter.branch(this, 'Valve_1.Port_3', { 'Pipe_3' }, 'Valve_3.Port_1');
            
            matter.branch(this, 'Valve_2.Port_2', { 'Pipe_4', 'R_4', 'R_5' }, 'Valve_3.Port_2');
            %matter.branch(this, 'Valve_2.Port_2', { 'Pipe_4' }, 'Valve_3.Port_2');
            
            %matter.branch(this, 'Valve_2.Port_3', { 'Pipe_5', 'R_1', 'R_3' }, 'Valve_4.Port_1');
            matter.branch(this, 'Valve_2.Port_3', { 'Pipe_5', 'R_1' }, 'Valve_4.Port_1');
            %matter.branch(this, 'Valve_2.Port_3', { 'Pipe_5' }, 'Valve_4.Port_1');
            
            matter.branch(this, 'Valve_3.Port_3', { 'Pipe_6' }, 'Valve_4.Port_2');
            matter.branch(this, 'Valve_4.Port_3', { 'Pipe_7' }, 'Store.Port_Rtn');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            solver.matter_multibranch.iterative.branch(this.aoBranches, 'complex');
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

