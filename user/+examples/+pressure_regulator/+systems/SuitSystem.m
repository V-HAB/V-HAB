classdef SuitSystem < vsys
    
    properties (SetAccess = protected, GetAccess = public)
        % value for suit leakage (real value 7.5e-7 m/s (ICES 2010_6064)), 
        % set higher for better visual impact on plot) 
        %fLeakageSuit = 7.5e-7;                          % [kg/s]
        fLeakageSuit = 1.9e-5;                          % [kg/s]
        % environmental pressure at beginning,
        % used to initialize the stores
        fPressureEnvironment = 101325;                  % [Pa]
        % manual branch object for fixed flowrate simulating suit leakage
        oManual;
        % environment reference branch object
        oReference;
        % pressure relief branch object, may be unused,
        % depending on bPPRVExists
        oRelief;
        % if true, a pressure relief branch consisting of a pressure relief
        % valve and a buffer store will be created, logfiles and plots
        % included
        bPPRVExists = true;
        % fixed timestep from setup.m, used for changeSetpoint (modulo 
        % function), not used for the SSM as timestep can still vary  
        fFixedTimeStep = 0;
        
        % A string that identifies the phase create helper to be used for
        % all phases in the regulator.
        sAtmosphereHelper = 'SuitAtmosphere';
    end
    
    methods
        % constructor function
        function this = SuitSystem(oParent, sName, fFixedTimeStep)
            % call parent constructor
            this@vsys(oParent, sName, -1);
            
            this.fFixedTimeStep = fFixedTimeStep;
            
            % Creating the regulator parameters
            tParameters = struct('fFixedTimeStep', fFixedTimeStep);
            
            % Creating the first stage parameters
            tFirstStageParameters = struct();
            tFirstStageParameters.fMaximumDeltaPressure = 3400000;
            tFirstStageParameters.fPressureSetpoint = 15.4e5;
            tFirstStageParameters.fThetaCone = 30;
            tFirstStageParameters.fHeightCone = 0.05;
            tFirstStageParameters.fCSpring = 6700;
            tFirstStageParameters.fMaxValveOpening = 0.004;
            tFirstStageParameters.fAreaDiaphragm = 0.0001;
            tFirstStageParameters.fMassDiaphragm = 0.01;
            tFirstStageParameters.fTPT1 = 0.01;
            tParameters.tFirstStageParameters = tFirstStageParameters;
            
            % Creating the second stage parameters. We use less here, since
            % the default parameters are already set to what we want. If
            % the regulator is used in a different system, they would have
            % to be set in the same way as the first stage parameters. 
            tParameters.tSecondStageParameters = struct('fPressureSetpoint', 56500);
            
            % create regulator subsystem
            components.matter.PressureRegulator(this, 'Regulator', tParameters);
            
            this.sAtmosphereHelper = 'SuitAtmosphere';
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % create a store oxygen tank, volume 0.1 m^3
            matter.store(this, 'O2Tank', 0.1);
            % add phase to store oxygen tank, pressure 50 bar
            oGasPhaseTank = this.toStores.O2Tank.createPhase(this.sAtmosphereHelper, 0.1, 293.15, 0, 50e5);
%             oGasPhaseTank.bSynced = true;
            
            % create store suit tank, acts as a reference for the
            % space suit working pressure,
            % the regulator will check the phase pressure of this store
            % to calculate, system input #2
            matter.store(this, 'SuitTank', 1);
            % add phase to store suit tank
            oGasPhaseSuit = this.toStores.SuitTank.createPhase(this.sAtmosphereHelper, 1, 293.15, 0, this.fPressureEnvironment);

            % add buffer store for suit leakage simulation 
            % and pressure relief branch to feed into
            matter.store(this, 'BufferTank', 1);
            % add phase to buffer store
            oGasPhaseBuffer = this.toStores.BufferTank.createPhase(this.sAtmosphereHelper, 1, 293.15, 0, this.fPressureEnvironment);
            
            % create a reference store for environmental pressure,
            % the regulator will check the phase pressure of this store
            % to calculate, system input #1
            matter.store(this, 'EnvironmentReference', 1);
            % add phase to environment reference store
            oGasPhaseEnvRef = this.toStores.EnvironmentReference.createPhase(this.sAtmosphereHelper, 1, 293.15, 0, this.fPressureEnvironment);
            
            % Setting the reference phase on the regulator.
            this.toChildren.Regulator.setEnvironmentReference(oGasPhaseEnvRef);
            
            % create second reference store, used for changing pressure
            % in the "true" reference store due to pressure equalization
            matter.store(this, 'EnvironmentBuffer', 1);
            % add phase to environment buffer store
            oGasPhaseEnvBuf = this.toStores.EnvironmentBuffer.createPhase(this.sAtmosphereHelper, 1, 293.15, 0, this.fPressureEnvironment * 2);
            
            % add pipe for suit leakage branch
            components.matter.pipe(this, 'Pipe_Suit_Buffer', 0.05, 0.005);
            % add pipe for environment reference branch
            components.matter.pipe(this, 'Pipe_EnvRef_EnvBuf', 0.05, 0.005);

            % add extract/merge processors
            matter.procs.exmes.gas(oGasPhaseTank, 'PortTank');
            matter.procs.exmes.gas(oGasPhaseSuit, 'PortSuitIn');
            matter.procs.exmes.gas(oGasPhaseSuit, 'PortSuitOut');
            matter.procs.exmes.gas(oGasPhaseBuffer, 'PortBuffer');
            matter.procs.exmes.gas(oGasPhaseEnvRef, 'PortEnvRef');
            matter.procs.exmes.gas(oGasPhaseEnvBuf, 'PortEnvBuf');
            
            % connect components to set flowpath
            matter.branch(this, 'SubSystemInput', {}, 'O2Tank.PortTank');
            matter.branch(this, 'SubSystemOutput', {}, 'SuitTank.PortSuitIn');
            
            % connect environment reference stores
            matter.branch(this, 'EnvironmentReference.PortEnvRef', {'Pipe_EnvRef_EnvBuf'}, 'EnvironmentBuffer.PortEnvBuf', 'ReferenceBranch');
            
            % create manual solver branch for suit leakage
            matter.branch(this, 'SuitTank.PortSuitOut', {'Pipe_Suit_Buffer'}, 'BufferTank.PortBuffer', 'LeakageBranch');

            % set subsystem flows
            this.toChildren.Regulator.setIfFlows('SubSystemInput', 'SubSystemOutput');
            
            % optional block for including a pressure relief valve,  easy
            % activation/deactivation with bPPRVExists in class properties
            if this.bPPRVExists
                % add pressure relief valve
                oProc = examples.pressure_regulator.components.PPRV(this, 'ValvePPRV', 0.6e5);
                oProc.setEnvironmentReference(oGasPhaseEnvRef);
                
                % add extract/merge processors, exme after the PPRV should 
                % be a constant pressure exme to always fill the store 
                % regardless of pressure difference. avoids malfunction
                % with longer simulation times due to too high a pressure
                % in the buffer store
                matter.procs.exmes.gas(oGasPhaseSuit, 'PortSuitPPRV');
                matter.procs.exmes.gas(oGasPhaseBuffer, 'PortBufferPPRV');
                % connect pressure relief branch
                matter.branch(this, 'SuitTank.PortSuitPPRV', {'ValvePPRV'}, 'BufferTank.PortBufferPPRV', 'PPRVBranch');
                
            end
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % add suit leakage branch to manual solver
            this.oManual = solver.matter.manual.branch(this.toBranches.LeakageBranch);
            
            % set flowrate for manual solver
            this.oManual.setFlowRate(this.fLeakageSuit);
            
            % add environment reference branch to solver
            this.oReference = solver.matter.interval.branch(this.toBranches.ReferenceBranch);
            
            if this.bPPRVExists
                % add pressure relief branch to solver
                this.oRelief = solver.matter.interval.branch(this.toBranches.PPRVBranch);
            end
            
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            % call parent exec function
            exec@vsys(this);
            
        end
    end
end