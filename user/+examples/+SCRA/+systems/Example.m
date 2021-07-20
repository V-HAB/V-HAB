classdef Example < vsys
    %EXAMPLE Example simulation for a system with the sabatier carbon
    %dioxide reduction assembly (SCRA). It requires the CDRA for Co2 supply
    %and therefore also the CCAA. Test Data is from ICES 2005-07-11
    %"Integrated Test and Evaluation of a 4-Bed Molecular Sieve (4BMS)
    %Carbon Dioxide Removal System (CDRA), Mechanical Compressor
    %Engineering Development Unit (EDU), and Sabatier Engineering
    %Development Unit (EDU)" https://doi.org/10.4271/2005-01-2864
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
            
            % SCRA
            components.matter.SCRA.SCRA(this,           'SCRA',   20, 277.31);
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %% Gas System
            % Creating a store, volume 1 m^3
            matter.store(this, 'Cabin', 97.71);
            
            fCoolantTemperature = 277.31;
            
            % Adding a phase to the store 'Cabin', 100 m^3 air
            oCabinPhase = this.toStores.Cabin.createPhase('gas', 'boundary',	'CabinAir',	97.71, struct('N2', 8e4, 'O2', 2e4, 'CO2', 200), 295, 0.4);
            
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
            
            % Adding a phase to the store
            oVentedPhase = this.toStores.Vented.createPhase('gas', 'boundary',	'VentedMass',	200, struct('N2', 3), 295, 0);
            
            % creates a store to connect the CCAA and the CDRA
            matter.store(this, 'CCAA_CDRA_Connection', 0.1);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            oConnectionPhase = this.toStores.CCAA_CDRA_Connection.createPhase('gas', 'flow',	'CabinAir',	0.1, struct('N2', 8e4, 'O2', 2e4, 'CO2', 200), 295, 0);
            matter.procs.exmes.gas( oConnectionPhase, 'Port_1');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_2');
            
            % Creating the CO2 Connection tank between CDRA and SCRA Note
            % that in "Integrated Test and Evaluation of a 4-Bed Molecular
            % Sieve (4BMS) Carbon Dioxide Removal System (CDRA), Mechanical
            % Compressor Engineering Development Unit (EDU), and Sabatier
            % Engineering Development Unit (EDU)", Knox et. al., 2005 ICES
            % 2005-01-2864 the SCRA is mentioned to have a 0.73 ft^3
            % accumulator tank, which is located in the subsystem!
            fConnectionVolume = 1e-6;
            matter.store(this, 'CO2_Connection', fConnectionVolume); % CO2 from CDRA to SCRA
            oConnectionCO2                          = this.toStores.CO2_Connection.createPhase(             'gas', 'flow',   'CO2_Connection_Phase',            fConnectionVolume, struct('CO2', 1e5), 295, 0);
            
            % Creating the H2 connection store between OGA and SCRA
            matter.store(this, 'H2_Connection', 100+fConnectionVolume); % H2 from OGA to SCRA
            oH2                                     = this.toStores.H2_Connection.createPhase(              'gas', 'boundary', 'H2_Phase',                        100, struct('H2', 1e5), 295, 0);
            oConnectionH2                           = this.toStores.H2_Connection.createPhase(              'gas', 'flow',     'H2_Connection_Phase',             fConnectionVolume, struct('H2', 1e5), 295, 0);
            
            matter.branch(this, 'CCAA_Input',               {}, 'Cabin.Port_ToCCAA');
            matter.branch(this, 'CCAA_Output',              {}, 'Cabin.Port_FromCCAA');
            matter.branch(this, 'CCAA_CondensateOutput',    {}, 'CondensateStore.Port_1');
            matter.branch(this, 'CCAA_CoolantInput',        {}, 'CoolantStore.Port_1');
            matter.branch(this, 'CCAA_CoolantOutput',       {}, 'CoolantStore.Port_2');
            matter.branch(this, 'CCAA_CHX_to_CDRA_Out',     {}, 'CCAA_CDRA_Connection.Port_1');
            
            matter.branch(this, 'CDRA_Input',               {}, 'CCAA_CDRA_Connection.Port_2');
            matter.branch(this, 'CDRA_Output',              {}, 'Cabin.CDRA_Port_1');
            matter.branch(this, 'CDRA_Vent',                {}, oConnectionCO2);
            
            % SCRA
            matter.branch(this, oH2,                    {}, oConnectionH2, 'H2_to_SCRA');
            matter.branch(this, 'SCRA_H2_In',           {}, oConnectionH2);
            matter.branch(this, 'SCRA_CO2_In',          {}, oConnectionCO2);
            matter.branch(this, 'SCRA_DryGas_Out',      {}, oVentedPhase);
            matter.branch(this, 'SCRA_Condensate_Out', 	{}, oCondensatePhase);
            matter.branch(this, 'SCRA_CoolantIn',   	{}, oCoolantPhase);
            matter.branch(this, 'SCRA_CoolantOut',   	{}, oCoolantPhase);
            
            
            % now the interfaces between this system and the CCAA subsystem
            % are defined
            this.toChildren.CCAA.setIfFlows('CCAA_Input', 'CCAA_Output', 'CCAA_CondensateOutput', 'CCAA_CoolantInput', 'CCAA_CoolantOutput', 'CCAA_CHX_to_CDRA_Out');
            
            this.toChildren.CDRA.setIfFlows('CDRA_Input', 'CDRA_Output', 'CDRA_Vent');
            
            
            this.toChildren.SCRA.setIfFlows('SCRA_H2_In', 'SCRA_CO2_In', 'SCRA_DryGas_Out', 'SCRA_Condensate_Out', 'SCRA_CoolantIn', 'SCRA_CoolantOut');
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            % Adding heat sources to keep the cabin and coolant water at a
            % constant temperature
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
            
            solver.matter.manual.branch(this.toBranches.H2_to_SCRA);
            
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
            
            
            %% Assign thermal solvers
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            exec@vsys(this);
            
            if this.oTimer.fTime > 143*60 && this.toBranches.H2_to_SCRA.fFlowRate == 0
                % Flowrate of test case was 2.461 standard liter per minute.
                % Assuming 273.15 K and 1 atm the density of H2 is 0.089885 kg/m^3
                this.toBranches.H2_to_SCRA.oHandler.setFlowRate((2.461e-3 * 0.089885)/60);
            end
            
            this.oTimer.synchronizeCallBacks();
        end
        
    end
    
end

