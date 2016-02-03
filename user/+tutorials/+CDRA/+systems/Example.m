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
            this@vsys(oParent, sName);
            
            % Initial ratio for amount of flow that is channeled through the
            % CHX
            rInitialCHX_Ratio = 0.21;
            % temperature for the coolant passing through the CCAA
            fCoolantTemperature = 280;
            % Struct containg basic atmospheric values for the
            % initialization of the CCAA
            tAtmosphere.fTemperature = 295;
            tAtmosphere.fRelHumidity = 0.8;
            tAtmosphere.fPressure = 101325;
            % name for the asscociated CDRA subsystem, leave empty if CCAA
            % is used as standalone
            sCDRA = 'CDRA';
            
            % Adding the subsystem CCAA
            components.CCAA.CCAA(this, 'CCAA', 5, rInitialCHX_Ratio, fCoolantTemperature, tAtmosphere, sCDRA);
            
            % name for the asscociated CCAA subsystem, CDRA can only be
            % used together with a CCAA
            sCCAA = 'CCAA';
            
            % Adding the subsystem CDRA
            components.CDRA.CDRA(this, 'CDRA', 5, tAtmosphere, sCCAA);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %% Gas System
            % Creating a store, volume 1 m^3
            matter.store(this, 'Cabin', 100);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            fCO2Percent = 0.4;
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 100, struct('CO2', fCO2Percent),  295, 0.8, 1e5);
               
            % Adding a phase to the store 'Cabin', 100 m^3 air
            oCabinPhase = matter.phases.gas(this.toStores.Cabin, 'CabinAir', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oCabinPhase, 'Port_ToCCAA');
            matter.procs.exmes.gas(oCabinPhase, 'Port_FromCCAA_CHX');
            matter.procs.exmes.gas(oCabinPhase, 'Port_FromCCAA_TCCV');
            matter.procs.exmes.gas(oCabinPhase, 'Port_TempControlIn');
            matter.procs.exmes.gas(oCabinPhase, 'Port_TempControlOut');
            matter.procs.exmes.gas(oCabinPhase, 'Port_FromCDRAAirSafe1');
            matter.procs.exmes.gas(oCabinPhase, 'Port_FromCDRAAirSafe2');
            
            % For the CCAA to function properly the cabin phase to which
            % the CCAA is attached has to be set as reference
            this.toChildren.CCAA.setReferencePhase(oCabinPhase);
            
            % Coolant store for the coolant water supplied to CCAA
            matter.store(this, 'CoolantStore', 1);
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oCoolantPhase = matter.phases.liquid(this.toStores.CoolantStore, ...  Store in which the phase is located
                'Coolant_Phase', ...        Phase name
                struct('H2O', 1), ...      Phase contents
                1, ...                     Phase volume
                280.15, ...                Phase temperature
                101325);                 % Phase pressure
            
            matter.procs.exmes.liquid(oCoolantPhase, 'Port_1');
            matter.procs.exmes.liquid(oCoolantPhase, 'Port_2');
            matter.procs.exmes.liquid(oCoolantPhase, 'Port_3');
            matter.procs.exmes.liquid(oCoolantPhase, 'Port_4');
            
            % Store to gather the condensate from CCAA
            matter.store(this, 'CondensateStore', 1);
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oCondensatePhase = matter.phases.liquid(this.toStores.CondensateStore, ...  Store in which the phase is located
                'Condensate_Phase', ...        Phase name
                struct('H2O', 1), ...      Phase contents
                1, ...                     Phase volume
                280.15, ...                Phase temperature
                101325);                 % Phase pressure
            
            matter.procs.exmes.liquid(oCondensatePhase, 'Port_1');
            
            % creates a store into which CDRA can vent
            matter.store(this, 'Vented', 100);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            fCO2Percent = 0.04;
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 100, struct('CO2', fCO2Percent),  295, 0.8, 1e2);
               
            % Adding a phase to the store
            oVentedPhase = matter.phases.gas(this.toStores.Vented, 'VentedMass', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            matter.procs.exmes.gas(oVentedPhase, 'Port_1');
            matter.procs.exmes.gas(oVentedPhase, 'Port_2');
            
            % creates a store to connect the CCAA and the CDRA
            matter.store(this, 'CCAA_CDRA_Connection', 0.1);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 0.1, struct('CO2', fCO2Percent),  295, 0.8, 1e5);
               
            % Adding a phase to the store
            oConnectionPhase = matter.phases.gas(this.toStores.CCAA_CDRA_Connection, 'ConnectionPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            oConnectionPhase.fFixedTS = 5;
            matter.procs.exmes.gas( oConnectionPhase, 'Port_1');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_2');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_3');
            
            % creates a store to connect the CCAA and the CDRA
            matter.store(this, 'CDRA_CCAA_Connection', 0.1);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 0.2, struct('CO2', fCO2Percent),  295, 0.8, 1e5);
               
            % Adding a phase to the store
             oConnectionPhase = matter.phases.gas(this.toStores.CDRA_CCAA_Connection, 'VentedMass', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            oConnectionPhase.fFixedTS = 5;
            matter.procs.exmes.gas( oConnectionPhase, 'Port_1');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_2');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_3');
            
            % Adding a Temperature Dummy to keep the Cabin at a constant
            % temperature
            components.Temp_Dummy(this, 'Cabin_TempDummy', 295);
            components.Temp_Dummy(this, 'Coolant_TempDummy', 280.15);
            
            matter.branch(this, 'CCAAinput', {}, 'Cabin.Port_ToCCAA');
            matter.branch(this, 'CCAA_CHX_Output', {}, 'Cabin.Port_FromCCAA_CHX');
            matter.branch(this, 'CCAA_TCCV_Output', {}, 'Cabin.Port_FromCCAA_TCCV');
            matter.branch(this, 'CCAA_CondensateOutput', {}, 'CondensateStore.Port_1');
            matter.branch(this, 'CCAA_CoolantInput', {}, 'CoolantStore.Port_1');
            matter.branch(this, 'CCAA_CoolantOutput', {}, 'CoolantStore.Port_2');
            matter.branch(this, 'CCAA_In_FromCDRA', {}, 'CDRA_CCAA_Connection.Port_1');
            matter.branch(this, 'CCAA_CHX_to_CDRA_Out', {}, 'CCAA_CDRA_Connection.Port_1');
            
            matter.branch(this, 'CDRA_Input1', {}, 'CCAA_CDRA_Connection.Port_2');
            matter.branch(this, 'CDRA_Input2', {}, 'CCAA_CDRA_Connection.Port_3');
            matter.branch(this, 'CDRA_Output1', {}, 'CDRA_CCAA_Connection.Port_2');
            matter.branch(this, 'CDRA_Output2', {}, 'CDRA_CCAA_Connection.Port_3');
            matter.branch(this, 'CDRA_Airsafe1', {}, 'Cabin.Port_FromCDRAAirSafe1');
            matter.branch(this, 'CDRA_Airsafe2', {}, 'Cabin.Port_FromCDRAAirSafe2');
            matter.branch(this, 'CDRA_Vent1', {}, 'Vented.Port_1');
            matter.branch(this, 'CDRA_Vent2', {}, 'Vented.Port_2');
            
            matter.branch(this, 'Cabin.Port_TempControlIn', {'Cabin_TempDummy'}, 'Cabin.Port_TempControlOut', 'Cabin_TempControl');
            matter.branch(this, 'CoolantStore.Port_3', {'Coolant_TempDummy'}, 'CoolantStore.Port_4', 'Coolant_TempControl');
            
            % now the interfaces between this system and the CCAA subsystem
            % are defined
            this.toChildren.CCAA.setIfFlows('CCAAinput', 'CCAA_In_FromCDRA', 'CCAA_CHX_Output', 'CCAA_TCCV_Output', 'CCAA_CondensateOutput', 'CCAA_CHX_to_CDRA_Out', 'CCAA_CoolantInput', 'CCAA_CoolantOutput');
            
            this.toChildren.CDRA.setIfFlows('CDRA_Input1', 'CDRA_Input2', 'CDRA_Output1', 'CDRA_Output2', 'CDRA_Vent1', 'CDRA_Vent2', 'CDRA_Airsafe1', 'CDRA_Airsafe2');
            
        end
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.Cabin_TempControl);
            this.toBranches.Cabin_TempControl.oHandler.setFlowRate(10);
            
            solver.matter.manual.branch(this.toBranches.Coolant_TempControl);
            this.toBranches.Coolant_TempControl.oHandler.setFlowRate(1);
            
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
        end
        
    end
    
end

