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
            sCDRA = [];
            
            % Adding the subsystem CCAA
            components.CCAA.CCAA(this, 'CCAA', 5, fCoolantTemperature, tAtmosphere, sCDRA);
            
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
            matter.procs.exmes.gas(oCabinPhase, 'Port_1');
            matter.procs.exmes.gas(oCabinPhase, 'Port_2');
            matter.procs.exmes.gas(oCabinPhase, 'Port_3');
            matter.procs.exmes.gas(oCabinPhase, 'Port_4');
            matter.procs.exmes.gas(oCabinPhase, 'Port_5');
            
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
            
            % Adding a Temperature Dummy to keep the Cabin at a constant
            % temperature
            components.Temp_Dummy(this, 'Cabin_TempDummy', 295);
            components.Temp_Dummy(this, 'Coolant_TempDummy', 280.15);
            
            matter.branch(this, 'CCAAinput', {}, 'Cabin.Port_1');
            matter.branch(this, 'CCAA_CHX_Output', {}, 'Cabin.Port_2');
            matter.branch(this, 'CCAA_TCCV_Output', {}, 'Cabin.Port_3');
            matter.branch(this, 'CCAA_CondensateOutput', {}, 'CondensateStore.Port_1');
            matter.branch(this, 'CCAA_CoolantInput', {}, 'CoolantStore.Port_1');
            matter.branch(this, 'CCAA_CoolantOutput', {}, 'CoolantStore.Port_2');
            
            
            matter.branch(this, 'Cabin.Port_4', {'Cabin_TempDummy'}, 'Cabin.Port_5', 'Cabin_TempControl');
            matter.branch(this, 'CoolantStore.Port_3', {'Coolant_TempDummy'}, 'CoolantStore.Port_4', 'Coolant_TempControl');
            
            % now the interfaces between this system and the CCAA subsystem
            % are defined
            this.toChildren.CCAA.setIfFlows('CCAAinput', 'CCAA_CHX_Output', 'CCAA_TCCV_Output', 'CCAA_CondensateOutput', 'CCAA_CoolantInput', 'CCAA_CoolantOutput');
            
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

