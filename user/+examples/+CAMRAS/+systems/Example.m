classdef Example < vsys
    properties
        
        %% Atmosphere Control Paramters
        
        % H2O flowrate
        fFlowRateH2O = 0.000078667;
        
        % CO2 flowrate
        fFlowRateCO2 = 0.0000583; % CO2 Output for nominal Activity
        
        
        % N2 flowrate
        fFlowRateN2 = 0.01;
        
        % O2 flowrate
        fFlowRateO2 = 0.01;
        
        % Time Step of the Subsystem
        fUpdateFrequency;
        iCounter =0;
        iOn = 0;
        iOff =0;
        
        iOn2  = 0;
        iOff2 = 0;
        
        iTickModuloCounter = 0;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 10);
            
            this.fUpdateFrequency = this.fTimeStep;
            
            
            %% Insert CAMRAS subsystem
            % The required inputs for CAMRAS are:   oParent, sName,     fTimeStep,  fVolumetricFlowrateMain,    sCase)
            components.matter.CAMRAS.CAMRAS(this, 'CAMRAS', 1, 0.0122706, 'exercise'); 
            % Description of the Inputs:
            % case: Adjusts the cycle time of CAMRAS. It has three possible
            %       cases: 'nominal', 'exercise' and 'sleep'. These reflect
            %       the usual crew loads and CAMRAS is adjusted to match
            %       those
            % Volumetric Flowrate: This parameter can be used to adjust the
            %       flowrate passing through CAMRAS
            
            %% In the case of using a second CAMRAS
            components.matter.CAMRAS.CAMRAS(this, 'CAMRAS_2', 1, 0.0122706, 'exercise');
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            fTemperatureInit = 295;         % [K] equals 70 °F
            fPressureInit    = 101325;      % [Pa]
            fRelHumidityInit = 0.2;         % Chosen to match test data
            fCO2Percent      = 0.002;       % Chosen to match test data
            
            
            %% Atmosphere of Orion Test Rig
            
            fTestRigVolume = (16.2);
            matter.store(this, 'Atmosphere', fTestRigVolume);
            
            oAtmosphere    	= this.toStores.Atmosphere.createPhase(       'gas',	'Atmosphere_Phase_1',  fTestRigVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 150),	fTemperatureInit, fRelHumidityInit);
            
            this.toChildren.CAMRAS.setReferencePhase(oAtmosphere);
            
            
            matter.procs.exmes.gas(oAtmosphere, 'From_H2O');
            matter.procs.exmes.gas(oAtmosphere, 'From_CO2');
            matter.procs.exmes.gas(oAtmosphere, 'From_N2');
            matter.procs.exmes.gas(oAtmosphere, 'From_O2');
            matter.procs.exmes.gas(oAtmosphere, 'ToCAMRAS_C1');
            matter.procs.exmes.gas(oAtmosphere, 'FromCAMRAS_C1');
            matter.procs.exmes.gas(oAtmosphere, 'ToCAMRAS_C2');
            matter.procs.exmes.gas(oAtmosphere, 'FromCAMRAS_C2');
            
            
            %% Water Supply
            
            matter.store(this, 'WaterSupply', 100e3/997);
            oWaterSupply = matter.phases.liquid(...
                this.toStores.WaterSupply, ...      % store containing phase
                'WaterSupply', ...                  % phase name
                struct(...                          % phase contents    [kg]
                'H2O', 100e3), ...
                fTemperatureInit, ...               % phase temperature [K]
                fPressureInit);                     % phase pressure    [Pa]
            
            matter.procs.exmes.liquid(oWaterSupply, 'To_Atmosphere');
            
            %% CO2 Supply
            
            matter.store(this, 'CO2Supply', 20);
            oCO2Supply = matter.phases.gas(...
                this.toStores.CO2Supply, ...   % store containing phase
                'CO2Supply', ...               % phase name
                struct(...                     % phase contents    [kg]
                'CO2', 50), ...
                2, ...                         % phase volume      [m^3]
                fTemperatureInit);             % phase temperature [K]
            
            matter.procs.exmes.gas(oCO2Supply, 'To_Atmosphere');
            
            %% Nitrogen Supply
            
            matter.store(this, 'N2Supply', 100);
            oN2Supply = matter.phases.gas(...
                this.toStores.N2Supply, ...         % store containing phase
                'N2Supply', ...                     % phase name
                struct(...                          % phase contents    [kg]
                'N2', 50), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            matter.procs.exmes.gas(oN2Supply, 'To_Atmosphere');
            
            %% Oxygen Supply
            
            matter.store(this, 'O2Supply', 20);
            oO2Supply = matter.phases.gas(...
                this.toStores.O2Supply, ...   % store containing phase
                'O2Supply', ...               % phase name
                struct(...                    % phase contents    [kg]
                'O2', 50), ...
                2, ...                        % phase volume      [m^3]
                fTemperatureInit);            % phase temperature [K]
            
            
            matter.procs.exmes.gas(oO2Supply, 'To_Atmosphere');
            
            %% Vacuum
            
            matter.store(this, 'Vacuum', 100000);
            oVacuum = matter.phases.gas(this.toStores.Vacuum, ...
                'Vacuum_Phase', ...     	   % Phase name
                struct('N2',1.12*100000), ...  % Phase contents
                100000, ...                    % Phase volume
                293.15);                       % Phase temperature
            
            matter.procs.exmes.gas(oVacuum, 'FromCAMRAS_C1_Desorb');
            matter.procs.exmes.gas(oVacuum, 'FromCAMRAS_C2_Desorb');
            matter.procs.exmes.gas(oVacuum, 'FromCAMRAS_C1_Vacuum');
            matter.procs.exmes.gas(oVacuum, 'FromCAMRAS_C2_Vacuum');
            
            
            %% Branches for the Subsystem
            
            % Creating the flowpath (=branch) into a subsystem
            % Input parameter format is always:
            % 'Interface port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            
            % Atmosphere - CAMRAS
            matter.branch(this, 'FromAtmosphereToCAMRAS_C1', {}, 'Atmosphere.ToCAMRAS_C1');
            matter.branch(this, 'ToAtmosphereFromCAMRAS_C1', {}, 'Atmosphere.FromCAMRAS_C1');
            matter.branch(this, 'FromAtmosphereToCAMRAS_C2', {}, 'Atmosphere.ToCAMRAS_C2');
            matter.branch(this, 'ToAtmosphereFromCAMRAS_C2', {}, 'Atmosphere.FromCAMRAS_C2');
            
            
            % Vacuum - CAMRAS
            matter.branch(this, 'ToVacuumFromCAMRAS_C1_Desorb', {}, 'Vacuum.FromCAMRAS_C1_Desorb');
            matter.branch(this, 'ToVacuumFromCAMRAS_C2_Desorb', {}, 'Vacuum.FromCAMRAS_C2_Desorb');
            matter.branch(this, 'ToVacuumFromCAMRAS_C1_Vacuum', {}, 'Vacuum.FromCAMRAS_C1_Vacuum');
            matter.branch(this, 'ToVacuumFromCAMRAS_C2_Vacuum', {}, 'Vacuum.FromCAMRAS_C2_Vacuum');
            
            
            % Now we need to connect the subsystem with the top level system (this one). This is
            % done by a method provided by the subsystem.
            this.toChildren.CAMRAS.setIfFlows('FromAtmosphereToCAMRAS_C1', 'ToAtmosphereFromCAMRAS_C1','FromAtmosphereToCAMRAS_C2','ToAtmosphereFromCAMRAS_C2', 'ToVacuumFromCAMRAS_C1_Vacuum','ToVacuumFromCAMRAS_C2_Vacuum', 'ToVacuumFromCAMRAS_C1_Desorb', 'ToVacuumFromCAMRAS_C2_Desorb');
            
            
            %% Branches
            % create branches exclusive to this section
            matter.branch(this, 'WaterSupply.To_Atmosphere', {}, 'Atmosphere.From_H2O', 'H2OBufferSupply');
            matter.branch(this, 'CO2Supply.To_Atmosphere',   {}, 'Atmosphere.From_CO2', 'CO2BufferSupply');
            matter.branch(this, 'N2Supply.To_Atmosphere',    {}, 'Atmosphere.From_N2',  'N2BufferSupply');
            matter.branch(this, 'O2Supply.To_Atmosphere',    {}, 'Atmosphere.From_O2',  'O2BufferSupply');
            
            
            %% All stuff needed for a second CAMRAS goes here. If only one CAMRAS is used --> Comment this section
            
            % Atmosphere
            matter.procs.exmes.gas(oAtmosphere, 'ToCAMRAS_C1_2');
            matter.procs.exmes.gas(oAtmosphere, 'FromCAMRAS_C1_2');
            matter.procs.exmes.gas(oAtmosphere, 'ToCAMRAS_C2_2');
            matter.procs.exmes.gas(oAtmosphere, 'FromCAMRAS_C2_2');
            
            % Vacuum
            matter.procs.exmes.gas(oVacuum, 'FromCAMRAS_C1_Desorb_2');
            matter.procs.exmes.gas(oVacuum, 'FromCAMRAS_C2_Desorb_2');
            matter.procs.exmes.gas(oVacuum, 'FromCAMRAS_C1_Vacuum_2');
            matter.procs.exmes.gas(oVacuum, 'FromCAMRAS_C2_Vacuum_2');
            
            % Atmosphere - CAMRAS
            matter.branch(this, 'FromAtmosphereToCAMRAS_C1_2', {}, 'Atmosphere.ToCAMRAS_C1_2');
            matter.branch(this, 'ToAtmosphereFromCAMRAS_C1_2', {}, 'Atmosphere.FromCAMRAS_C1_2');
            matter.branch(this, 'FromAtmosphereToCAMRAS_C2_2', {}, 'Atmosphere.ToCAMRAS_C2_2');
            matter.branch(this, 'ToAtmosphereFromCAMRAS_C2_2', {}, 'Atmosphere.FromCAMRAS_C2_2');
            
            
            % Vacuum - CAMRAS
            matter.branch(this, 'ToVacuumFromCAMRAS_C1_Desorb_2', {}, 'Vacuum.FromCAMRAS_C1_Desorb_2');
            matter.branch(this, 'ToVacuumFromCAMRAS_C2_Desorb_2', {}, 'Vacuum.FromCAMRAS_C2_Desorb_2');
            matter.branch(this, 'ToVacuumFromCAMRAS_C1_Vacuum_2', {}, 'Vacuum.FromCAMRAS_C1_Vacuum_2');
            matter.branch(this, 'ToVacuumFromCAMRAS_C2_Vacuum_2', {}, 'Vacuum.FromCAMRAS_C2_Vacuum_2');
            
            this.toChildren.CAMRAS_2.setReferencePhase(oAtmosphere);
            
            % Now we need to connect the subsystem with the top level system (this one). This is
            % done by a method provided by the subsystem.
            this.toChildren.CAMRAS_2.setIfFlows('FromAtmosphereToCAMRAS_C1_2', 'ToAtmosphereFromCAMRAS_C1_2','FromAtmosphereToCAMRAS_C2_2','ToAtmosphereFromCAMRAS_C2_2', 'ToVacuumFromCAMRAS_C1_Vacuum_2','ToVacuumFromCAMRAS_C2_Vacuum_2', 'ToVacuumFromCAMRAS_C1_Desorb_2', 'ToVacuumFromCAMRAS_C2_Desorb_2');
            
        end
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.H2OBufferSupply);
            solver.matter.manual.branch(this.toBranches.CO2BufferSupply);
            solver.matter.manual.branch(this.toBranches.N2BufferSupply);
            solver.matter.manual.branch(this.toBranches.O2BufferSupply);
            
            this.toBranches.H2OBufferSupply.oHandler.setFlowRate(this.fFlowRateH2O);
            this.toBranches.CO2BufferSupply.oHandler.setFlowRate(this.fFlowRateCO2);
            this.toBranches.N2BufferSupply.oHandler.setFlowRate(0);
            this.toBranches.O2BufferSupply.oHandler.setFlowRate(0);
            
            this.setThermalSolvers();
        end
        
        function update(this)
            
            if ~this.oTimer.fTime
                return;
            end
            if this.oTimer.fTime > 1800
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00012267);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
                
            end
            if this.oTimer.fTime > 2250
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000201);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 2742
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00027283);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 3197
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000315);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 3668.4
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.0002295);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 4118.4
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00016983);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 4578
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.0001945);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 5030.4
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000259);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 5488.2
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000321);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 5850
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.0003528);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 6426
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00026533);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 6882
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.0002005);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 7326
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.0001945);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 7794
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000259);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 8250
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000321);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 8706
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00035633);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 9156
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00026533);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 9612
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000205);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 10086
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.0001945);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 10548
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000259);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 10992
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000321);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 11460
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00035633);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.00010833);
            end
            if this.oTimer.fTime > 11910
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00026533);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 12408
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00019917);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 12828
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.0001445);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 13284
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00013067);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 13746
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00012083);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 14202
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.000114);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 14670
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.0001085);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 15132
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.00010333);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            if this.oTimer.fTime > 15600
                this.toBranches.H2OBufferSupply.oHandler.setFlowRate(0.0000785);
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0.0000583);
            end
            
            %% Get Values for Atmosphere Controller
            fPartialPressureO2  = this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afPP(this.oMT.tiN2I.O2);
            fPressure           = this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fPressure;
            
            %% O2 Controller
            if fPartialPressureO2 <= 18665
                this.toBranches.O2BufferSupply.oHandler.setFlowRate(this.fFlowRateO2);
                
            elseif fPartialPressureO2 > 23000
                this.toBranches.O2BufferSupply.oHandler.setFlowRate(0);
                
            end
            
            %% Pressure Controller
            if fPressure < 100000
                this.toBranches.N2BufferSupply.oHandler.setFlowRate(this.fFlowRateN2);
            else
                this.toBranches.N2BufferSupply.oHandler.setFlowRate(0);
            end
            
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            this.update();
            
            if mod(this.oTimer.iTick, 500) < this.iTickModuloCounter
                this.oTimer.synchronizeCallBacks();
            end
            this.iTickModuloCounter = mod(this.oTimer.iTick, 500);
        end
    end
end