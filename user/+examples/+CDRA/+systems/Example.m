classdef Example < vsys
    %EXAMPLE Example simulation for a system with a heat exchanger in V-HAB 2.0
    %   This system has four stores with one phase each. There are two gas
    %   phases and two liquid phases. The gas phases and the liquid phases
    %   are connected to each other with two branches. A heat exchanger
    %   provides two f2f processors, one of each is integrated into each of
    %   the two branches. The flow through the gas branch is driven by the
    %   pressure difference between the two tanks. The flow through the
    %   liquid branch is set by using a manual solver branch. 
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
            this@vsys(oParent, sName, 60);
            
            % Struct containg basic atmospheric values for the
            % initialization of the CCAA
            tAtmosphere.fTemperature = 295;
            tAtmosphere.rRelHumidity = 0.5;
            tAtmosphere.fPressure = 101325;
            tAtmosphere.fCO2Percent = 0.0062;
            
            % name for the asscociated CDRA subsystem, leave empty if CCAA
            % is used as standalone
            sCDRA = 'CDRA';
            
            % Adding the subsystem CCAA
            components.matter.CCAA.CCAA(this, 'CCAA', 60, 277.31, tAtmosphere, sCDRA);
            
            % Adding the subsystem CDRA
            try
                tInitialization = oParent.oCfgParams.ptConfigParams('tInitialization');
                components.matter.CDRA.CDRA(this, 'CDRA', tAtmosphere, tInitialization, 60);
            catch
                components.matter.CDRA.CDRA(this, 'CDRA', tAtmosphere, [], 60);
            end
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %% Gas System
            % Creating a store, volume 1 m^3
            matter.store(this, 'Cabin', 498.71);
            
            fCoolantTemperature = 277.31;
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            fCO2Percent = 0.0062;
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 97.71, struct('CO2', fCO2Percent),  295, 0.4, 1e5);
               
            % Adding a phase to the store 'Cabin', 100 m^3 air
            oCabinPhase = matter.phases.gas(this.toStores.Cabin, 'CabinAir', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oCabinPhase, 'Port_ToCCAA');
            matter.procs.exmes.gas(oCabinPhase, 'Port_FromCCAA');
            
            matter.procs.exmes.gas( oCabinPhase, 'CDRA_Port_1');
            
            % Coolant store for the coolant water supplied to CCAA
            matter.store(this, 'CoolantStore', 1);
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oCoolantPhase = matter.phases.liquid(this.toStores.CoolantStore, ...  Store in which the phase is located
                'Coolant_Phase', ...        Phase name
                struct('H2O', 1), ...      Phase contents
                fCoolantTemperature, ...Phase temperature
                101325);                 % Phase pressure
            
            matter.procs.exmes.liquid(oCoolantPhase, 'Port_1');
            matter.procs.exmes.liquid(oCoolantPhase, 'Port_2');
            
            % Store to gather the condensate from CCAA
            matter.store(this, 'CondensateStore', 1);
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oCondensatePhase = matter.phases.liquid(this.toStores.CondensateStore, ...  Store in which the phase is located
                'Condensate_Phase', ...        Phase name
                struct('H2O', 1), ...      Phase contents
                280.15, ...                Phase temperature
                101325);                 % Phase pressure
            
            matter.procs.exmes.liquid(oCondensatePhase, 'Port_1');
            
            % creates a store into which CDRA can vent
            matter.store(this, 'Vented', 100);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 100, struct('CO2', fCO2Percent),  295, 0, 2000);
               
            % Adding a phase to the store
            oVentedPhase = matter.phases.gas(this.toStores.Vented, 'VentedMass', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            matter.procs.exmes.gas(oVentedPhase, 'Port_1');
            
            % creates a store to connect the CCAA and the CDRA
            matter.store(this, 'CCAA_CDRA_Connection', 0.1);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 0.1, struct('CO2', fCO2Percent),  295, 0, 2.5e5);
               
            % Adding a phase to the store
            oConnectionPhase = matter.phases.flow.gas(this.toStores.CCAA_CDRA_Connection, 'ConnectionPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            matter.procs.exmes.gas( oConnectionPhase, 'Port_1');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_2');
            
            matter.branch(this, 'CCAA_Input',               {}, 'Cabin.Port_ToCCAA');
            matter.branch(this, 'CCAA_Output',              {}, 'Cabin.Port_FromCCAA');
            matter.branch(this, 'CCAA_CondensateOutput',    {}, 'CondensateStore.Port_1');
            matter.branch(this, 'CCAA_CoolantInput',        {}, 'CoolantStore.Port_1');
            matter.branch(this, 'CCAA_CoolantOutput',       {}, 'CoolantStore.Port_2');
            matter.branch(this, 'CCAA_CHX_to_CDRA_Out',     {}, 'CCAA_CDRA_Connection.Port_1');
            
            matter.branch(this, 'CDRA_Input',               {}, 'CCAA_CDRA_Connection.Port_2');
            matter.branch(this, 'CDRA_Output',              {}, 'Cabin.CDRA_Port_1');
            matter.branch(this, 'CDRA_Vent',                {}, 'Vented.Port_1');
            
            % now the interfaces between this system and the CCAA subsystem
            % are defined
            this.toChildren.CCAA.setIfFlows('CCAA_Input', 'CCAA_Output', 'CCAA_CondensateOutput', 'CCAA_CoolantInput', 'CCAA_CoolantOutput', 'CCAA_CHX_to_CDRA_Out');
            
            this.toChildren.CDRA.setIfFlows('CDRA_Input', 'CDRA_Output', 'CDRA_Vent');
            
            oLungPhase          = this.toStores.Cabin.createPhase(  'gas',      'Lung',         400,    struct('CO2', 5e5),    	293,          0);
            oHumanWaterPhase    = this.toStores.Cabin.createPhase(  'liquid',   'HumanWater',	1,      struct('H2O', 1),     	293,          1e5);
            
            components.matter.P2Ps.ManualP2P(this.toStores.Cabin,          'CrewCO2',       oLungPhase,         oCabinPhase);
            components.matter.P2Ps.ManualP2P(this.toStores.Cabin,          'CrewHumidity',	oHumanWaterPhase,   oCabinPhase);
            
            
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            % Adding heat sources to keep the cabin and coolant water at a
            % constant temperature
            oHeatSource = thermal.heatsource('Heater', 940); %according to ICES 2000-01-2345 940 W of sensible load)
            this.toStores.Cabin.toPhases.CabinAir.oCapacity.addHeatSource(oHeatSource);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Coolant_Constant_Temperature');
            this.toStores.CoolantStore.toPhases.Coolant_Phase.oCapacity.addHeatSource(oHeatSource);
            
            this.toChildren.CDRA.setReferencePhase(this.toStores.Cabin.toPhases.CabinAir);
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Cabin setpoint according to ICES 2000-01-2345 was 65 degree
            % fahrenheit
            this.toChildren.CCAA.setTemperature(273.15 + 18.33);
            
            tTimeStepProperties.rMaxChange = 0.5;
            this.toStores.CondensateStore.toPhases.Condensate_Phase.setTimeStepProperties(tTimeStepProperties);
            
            
            csStores = fieldnames(this.toStores);
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    tTimeStepProperties.fMaxStep = 300;
                    tTimeStepProperties.rMaxChange = 0.05;

                    oPhase.setTimeStepProperties(tTimeStepProperties);
                    tTimeStepProperties = struct();
                    tTimeStepProperties.fMaxStep = 300;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                end
            end
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = 0.5;
            this.toStores.CondensateStore.toPhases.Condensate_Phase.setTimeStepProperties(tTimeStepProperties);
            
            
            tTimeStepProperties = struct();
            arMaxChange = zeros(1,this.oMT.iSubstances);
            arMaxChange(this.oMT.tiN2I.H2O) = 0.05;
            arMaxChange(this.oMT.tiN2I.CO2) = 0.05;
            tTimeStepProperties.arMaxChange = arMaxChange;
            this.toStores.Cabin.toPhases.CabinAir.setTimeStepProperties(tTimeStepProperties);
            
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = inf;
            this.toStores.Cabin.toPhases.Lung.setTimeStepProperties(tTimeStepProperties);
            this.toStores.Cabin.toPhases.HumanWater.setTimeStepProperties(tTimeStepProperties);
            this.toStores.Cabin.toPhases.Lung.oCapacity.setTimeStepProperties(tTimeStepProperties);
            this.toStores.Cabin.toPhases.HumanWater.oCapacity.setTimeStepProperties(tTimeStepProperties);
            
            %% Assign thermal solvers
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            exec@vsys(this);
            
            % The values are from  ICES 2000-01-2345 table 1 and model the
            % test case used for CDRA
            if (this.oTimer.fTime <= (19.3*3600))
                fCO2Production   = 13.2 * 0.45359237 / 86400;
                fWaterVapor      = 12 * 0.45359237 / 86400;
                fDryHeat         = 940;
                % temperature for the coolant passing through the CCAA,
                % according to ICES 2000-01-2345 the setpoint was 40 degree
                % fahrenheit +3° -2° during the initial 6 person case and then
                % was increased to 43°F +0° -5°. Therefore initial setpoint is
                % 39.5°F which is then raised to 40.5°F
                fCoolantTemperature = 277.31;
            elseif (this.oTimer.fTime > (19.3*3600)) && (this.oTimer.fTime < (37.8*3600))
                fCO2Production   = 8.8 * 0.45359237 / 86400;
                fWaterVapor      = 12 * 0.45359237 / 86400;
                fDryHeat         = 940;
                fCoolantTemperature = 277.594;
            elseif (this.oTimer.fTime >= (37.8*3600))
                fCO2Production   = 6.6 * 0.45359237 / 86400;
                fWaterVapor      = 12 * 0.45359237 / 86400;
                fDryHeat         = 940;
                fCoolantTemperature = 277.594;
            end
            
            afCO2Flow = zeros(1, this.oMT.iSubstances);
            afCO2Flow(this.oMT.tiN2I.CO2) = fCO2Production;
            this.toStores.Cabin.toProcsP2P.CrewCO2.setFlowRate(afCO2Flow);
            
            afH2OFlow = zeros(1, this.oMT.iSubstances);
            afH2OFlow(this.oMT.tiN2I.H2O) = fWaterVapor;
            this.toStores.Cabin.toProcsP2P.CrewHumidity.setFlowRate(afH2OFlow)
                
            this.toStores.Cabin.toPhases.CabinAir.oCapacity.toHeatSources.Heater.setHeatFlow(fDryHeat);
        	this.toStores.CoolantStore.toPhases.Coolant_Phase.oCapacity.toHeatSources.Coolant_Constant_Temperature.setTemperature(fCoolantTemperature);
            
            this.oTimer.synchronizeCallBacks();
        end
        
    end
    
end

