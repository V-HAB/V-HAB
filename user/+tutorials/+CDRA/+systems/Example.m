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
        
        %Number of Crew Members used for this simulation
        iCrewMembers = 6
        
        %% Crew Planer Properties
        %struct containing the human metabolic values for O2 consumption,
        %heat relase, CO2, TC and H2O production
        tHumanMetabolicValues;
        
        %current state the crew is in containing a field for each crew
        %member that contains a string with the current status for that
        %crew member. For example if crew member one is sleeping the first
        %field contains the string 'sleep'
        cCrewState;
        
        %vector with one field for each crew member that contains when the
        %current state for this crew member began. Necessary for automatic
        %changes between certain states
        mCrewStateStartTime; %s
        
        %cell array as planer for crew activities that contains one row for
        %each crew member and one column per event. Each field therefore 
        %stands for a certain event for a certain crew member. For example
        %if crew member 2 falls asleep the second row would contain an
        %event 'sleep'. Each event is a struct containing the fields sName
        %for the event name (sleep) a start time when this event should
        %begin and an end time when it should end. It also contains two
        %boolean variables to keep track if the event has already started
        %or ended
        cCrewPlaner = [];
        
        fCoolantTemperature;
    end
    
    methods
        function this = Example(oParent, sName, bSimpleCDRA)
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
            
            % temperature for the coolant passing through the CCAA
            this.fCoolantTemperature = 277.55;
            % Struct containg basic atmospheric values for the
            % initialization of the CCAA
            tAtmosphere.fTemperature = 295;
            tAtmosphere.fRelHumidity = 0.5;
            tAtmosphere.fPressure = 101325;
            tAtmosphere.fCO2Percent = 0.0062;
            
            % name for the asscociated CDRA subsystem, leave empty if CCAA
            % is used as standalone
            sCDRA = 'CDRA';
            
            % Adding the subsystem CCAA
            components.CCAA.CCAA(this, 'CCAA', 10, this.fCoolantTemperature, tAtmosphere, sCDRA);
            
            % name for the asscociated CCAA subsystem, CDRA can only be
            % used together with a CCAA
            sCCAA = 'CCAA';
            
            % Adding the subsystem CDRA
            if bSimpleCDRA
                components.CDRA.CDRA_simple(this, 'CDRA', 60, tAtmosphere, sCCAA);
            else
                components.CDRA.CDRA(this, 'CDRA', tAtmosphere, sCCAA);
            end
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %% Gas System
            % Creating a store, volume 1 m^3
            matter.store(this, 'Cabin', 100);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            fCO2Percent = 0.0062;
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 97.71, struct('CO2', fCO2Percent),  295, 0.4, 1e5);
               
            % Adding a phase to the store 'Cabin', 100 m^3 air
            oCabinPhase = matter.phases.gas(this.toStores.Cabin, 'CabinAir', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oCabinPhase, 'Port_ToCCAA');
            matter.procs.exmes.gas(oCabinPhase, 'Port_FromCCAA_CHX');
            matter.procs.exmes.gas(oCabinPhase, 'Port_FromCCAA_TCCV');
            matter.procs.exmes.gas(oCabinPhase, 'Port_FromCDRAAirSafe1');
            matter.procs.exmes.gas(oCabinPhase, 'Port_FromCDRAAirSafe2');
            %Human Exmes
%             matter.procs.exmes.gas(oCabinPhase, 'O2Out'); 
%             O2 is not part of the CDRA test case!
            matter.procs.exmes.gas(oCabinPhase, 'CO2In');
            matter.procs.exmes.gas(oCabinPhase, 'HumidityIn');
            
            % For the CCAA to function properly the cabin phase to which
            % the CCAA is attached has to be set as reference
            this.toChildren.CCAA.setReferencePhase(oCabinPhase);
            this.toChildren.CDRA.setReferencePhase(oCabinPhase);
            
            % Coolant store for the coolant water supplied to CCAA
            matter.store(this, 'CoolantStore', 1);
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oCoolantPhase = matter.phases.liquid(this.toStores.CoolantStore, ...  Store in which the phase is located
                'Coolant_Phase', ...        Phase name
                struct('H2O', 1), ...      Phase contents
                1, ...                     Phase volume
                this.fCoolantTemperature, ...Phase temperature
                101325);                 % Phase pressure
            
            matter.procs.exmes.liquid(oCoolantPhase, 'Port_1');
            matter.procs.exmes.liquid(oCoolantPhase, 'Port_2');
            
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
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 100, struct('CO2', fCO2Percent),  295, 0, 2000);
               
            % Adding a phase to the store
            oVentedPhase = matter.phases.gas(this.toStores.Vented, 'VentedMass', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            matter.procs.exmes.gas(oVentedPhase, 'Port_1');
            matter.procs.exmes.gas(oVentedPhase, 'Port_2');
            
            % creates a store to connect the CCAA and the CDRA
            matter.store(this, 'CCAA_CDRA_Connection', 0.1);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 0.1, struct('CO2', fCO2Percent),  295, 0, 2.5e5);
               
            % Adding a phase to the store
            oConnectionPhase = matter.phases.gas_flow_node(this.toStores.CCAA_CDRA_Connection, 'ConnectionPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            matter.procs.exmes.gas( oConnectionPhase, 'Port_1');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_2');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_3');
            
            % creates a store to connect the CCAA and the CDRA
            matter.store(this, 'CDRA_CCAA_Connection', 0.1);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 0.1, struct('CO2', fCO2Percent),  295, 0, 1e5);
               
            % Adding a phase to the store
            oConnectionPhase = matter.phases.gas_flow_node(this.toStores.CDRA_CCAA_Connection, 'ConnectionPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            matter.procs.exmes.gas( oConnectionPhase, 'Port_1');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_2');
            matter.procs.exmes.gas( oConnectionPhase, 'Port_3');
            
            % Adding heat sources to keep the cabin and coolant water at a
            % constant temperature
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Cabin_Constant_Temperature');
            oCabinPhase.oCapacity.addHeatSource(oHeatSource);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Coolant_Constant_Temperature');
            oCoolantPhase.oCapacity.addHeatSource(oHeatSource);
            
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
            
            % now the interfaces between this system and the CCAA subsystem
            % are defined
            this.toChildren.CCAA.setIfFlows('CCAAinput', 'CCAA_In_FromCDRA', 'CCAA_CHX_Output', 'CCAA_TCCV_Output', 'CCAA_CondensateOutput', 'CCAA_CHX_to_CDRA_Out', 'CCAA_CoolantInput', 'CCAA_CoolantOutput');
            
            this.toChildren.CDRA.setIfFlows('CDRA_Input1', 'CDRA_Input2', 'CDRA_Output1', 'CDRA_Output2', 'CDRA_Vent1', 'CDRA_Vent2', 'CDRA_Airsafe1', 'CDRA_Airsafe2');
            
            %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                        CREW SYSTEM                      %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %the model for the crew does not have a mass balance since
            %there is no food taken into account. Also a lot of the actual
            %processes are severly simplified.
            %all values taken from NASA/TP-2015–218570 "Life Support 
            %Baseline Values and Assumptions Document"
            
            %these are multiple states for the human metabolic rate taken
            %from table 3.22 in the above mentioned document saved into a
            %struct to allow easy access:
            this.tHumanMetabolicValues = struct();
            %all values converted to SI units
            %sleeping state
            this.tHumanMetabolicValues.sleep.fDryHeat = 224*1000/3600;
            this.tHumanMetabolicValues.sleep.fWaterVapor = (6.3*10^-4)/60;
            this.tHumanMetabolicValues.sleep.fSweat = 0;
            this.tHumanMetabolicValues.sleep.fO2Consumption = (3.6*10^-4)/60;
            this.tHumanMetabolicValues.sleep.fCO2Production = (4.55*10^-4)/60;
            %nominal state
            this.tHumanMetabolicValues.nominal.fDryHeat = 329*1000/3600;
            this.tHumanMetabolicValues.nominal.fWaterVapor = (11.77*10^-4)/60;
            this.tHumanMetabolicValues.nominal.fSweat = 0;
            this.tHumanMetabolicValues.nominal.fO2Consumption = (5.68*10^-4)/60;
            % THIS VALUE IS DIFFERENT FROM BVAD!
            % since the CO2 release for the test case was lower than the
            % value from the BVAD this value has been adapted for this
            % case.
            % For the test case a CO2 release of 13.2 lb/day for 6 CM was
            % assumed which is the same as 6.92986e-05 kg/s for 6 CM
            this.tHumanMetabolicValues.nominal.fCO2Production = (6.92986e-05)/6;%(7.2*10^-4)/60;
            %exercise minute 0-15
            this.tHumanMetabolicValues.exercise015.fDryHeat = 514*1000/3600;
            this.tHumanMetabolicValues.exercise015.fWaterVapor = (46.16*10^-4)/60;
            this.tHumanMetabolicValues.exercise015.fSweat = (1.56*10^-4)/60;
            this.tHumanMetabolicValues.exercise015.fO2Consumption = (39.40*10^-4)/60;
            this.tHumanMetabolicValues.exercise015.fCO2Production = (49.85*10^-4)/60;
            %exercise minute 15-30
            this.tHumanMetabolicValues.exercise1530.fDryHeat = 624*1000/3600;
            this.tHumanMetabolicValues.exercise1530.fWaterVapor = (128.42*10^-4)/60;
            this.tHumanMetabolicValues.exercise1530.fSweat = (33.52*10^-4)/60;
            this.tHumanMetabolicValues.exercise1530.fO2Consumption = (39.40*10^-4)/60;
            this.tHumanMetabolicValues.exercise1530.fCO2Production = (49.85*10^-4)/60;
            %recovery minute 0-15
            this.tHumanMetabolicValues.recovery015.fDryHeat = 568*1000/3600;
            this.tHumanMetabolicValues.recovery015.fWaterVapor = (83.83*10^-4)/60;
            this.tHumanMetabolicValues.recovery015.fSweat = (15.16*10^-4)/60;
            this.tHumanMetabolicValues.recovery015.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery015.fCO2Production = (7.2*10^-4)/60;
            %recovery minute 15-30
            this.tHumanMetabolicValues.recovery1530.fDryHeat = 488*1000/3600;
            this.tHumanMetabolicValues.recovery1530.fWaterVapor = (40.29*10^-4)/60;
            this.tHumanMetabolicValues.recovery1530.fSweat = (0.36*10^-4)/60;
            this.tHumanMetabolicValues.recovery1530.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery1530.fCO2Production = (7.2*10^-4)/60;
            %recovery minute 30-45
            this.tHumanMetabolicValues.recovery3045.fDryHeat = 466*1000/3600;
            this.tHumanMetabolicValues.recovery3045.fWaterVapor = (27.44*10^-4)/60;
            this.tHumanMetabolicValues.recovery3045.fSweat = (0*10^-4)/60;
            this.tHumanMetabolicValues.recovery3045.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery3045.fCO2Production = (7.2*10^-4)/60;
            %recovery minute 45-60
            this.tHumanMetabolicValues.recovery4560.fDryHeat = 455*1000/3600;
            this.tHumanMetabolicValues.recovery4560.fWaterVapor = (20.4*10^-4)/60;
            this.tHumanMetabolicValues.recovery4560.fSweat = (0*10^-4)/60;
            this.tHumanMetabolicValues.recovery4560.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery4560.fCO2Production = (7.2*10^-4)/60;
            
            %defines the initial crew conditions as nominal for each crew
            %member and sets the start time for this event to 0
            for k = 1:this.iCrewMembers
                this.cCrewState{k} = 'nominal';
                this.mCrewStateStartTime(k) = 0;
            end
            
            %This phase is used to simulate the human metabolism on a very
            %simple level. It takes in Oxygen and transforms it into CO2.
            %The oxygen intake is simulated by flowing cabin air through
            %the lung phase and using a p2p proc to remove oxygen from it.
            %In the carbon dioxide phase this oxygen is then transformed
            %into carbon dioxide which is then released into the cabin. Of
            %course this does not result in a closed mass balance for the
            %human and instead the store will lose mass (for long
            %simulation times the store volume might have to be increased)
            tCO2.sSubstance = 'CO2';
            tCO2.sProperty = 'Density';
            tCO2.sFirstDepName = 'Pressure';
            tCO2.fFirstDepValue = 101325;
            tCO2.sSecondDepName = 'Temperature';
            tCO2.fSecondDepValue = 309.15;
            tCO2.sPhaseType = 'gas';
            fDensityCO2 = this.oMT.findProperty(tCO2);
               
            oLungPhase = matter.phases.gas(this.toStores.Cabin, 'Lung', struct(...
                'CO2', this.iCrewMembers*10*fDensityCO2),...
                this.iCrewMembers*10, 309.15);
            
            %lung volume not realistic but not a direct connection to the
            %vehicle anyway, the interactions are only through p2p and the
            %volume has to be large because the mass balance is not closed
            %and it only contains CO2 because that is the only thing
            %removed from the phase
            
            matter.procs.exmes.gas(oLungPhase, 'CO2_Out');
%             matter.procs.exmes.gas(oLungPhase, 'O2In');
%           O2 is not part of the CDRA test case
            
            %p2p proc to remove the consumed O2 from the cabin air
            %p2p proc to put the produced CO2 into the cabin air
            tutorials.CDRA.components.Crew_Respiratory_Simulator_CO2(...
                this.toStores.Cabin, 'CrewCO2Prod', 'Lung.CO2_Out',...
                'CabinAir.CO2In', [1,1,1,1,1,1], this);
            
            %p2p proc to convert O2 taken in by humans to CO2 to somewhat
            %close the mass balance
            oHumanWaterPhase = matter.phases.gas(this.toStores.Cabin, 'HumanWater', struct(...
                'H2O', this.iCrewMembers*70),...
                this.iCrewMembers*70, 309.15);
            
            matter.procs.exmes.gas(oHumanWaterPhase, 'HumidityOut');
            
            %p2p proc for the crew humidity generator
            tutorials.CDRA.components.Crew_Humidity_Generator(...
                this.toStores.Cabin,'CrewHumidityGen',...
                'HumanWater.HumidityOut', 'CabinAir.HumidityIn',...
                [1,1], this);
            
        end
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %% Assign thermal solvers
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            exec@vsys(this);
            
            %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%              Crew Metabolism Simulator                  %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % this section sets the correct values for the humans according
            % to their current state and also takes care of automatic
            % transitions to follow up states (like recovery after
            % exercise)
            
            %%%%%%%%%%%%%% automatic crew state changes %%%%%%%%%%%%%%%%%%% 
            % switches the crew state between the different time dependant
            % states automatically
            for k = 1:this.iCrewMembers
                if strcmp(this.cCrewState{k}, 'exercise015')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'exercise1530';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
                elseif strcmp(this.cCrewState{k}, 'recovery015')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'recovery1530';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
                elseif strcmp(this.cCrewState{k}, 'recovery1530')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'recovery3045';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
               	elseif strcmp(this.cCrewState{k}, 'recovery3045')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'recovery4560';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
                elseif strcmp(this.cCrewState{k}, 'recovery4560')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'nominal';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
                end
            end
            
            %%%%%%%%%%%%%%%%%%%% crew state planner %%%%%%%%%%%%%%%%%%%%%%%
            % using the cCrewPlaner variable for this object it is
            % possible to set different states for each crew member for
            % different times. This section takes care of all the necessary
            % allocations
            
            % if the variable is empty nothing happens because nothing is
            % planned for the crew. In that case the initial values remain
            % valid for the whole simulation.
            if ~isempty(this.cCrewPlaner)
                %if the planer is not empty it has to move through each
                %crew member. The index used for this is iCM (for Crew
                %Member)
                miCrewPlanerSize = size(this.cCrewPlaner);
                for iCM = 1:miCrewPlanerSize(1)
                    %each CM may have multiple events assigned so it is
                    %necessary to iterate through all the events as well
                    for iEvent = 1:miCrewPlanerSize(2)
                        %if the event start time has been reached and the event
                        %has not been started yet the crew state has to be
                        %switched
                        if (this.cCrewPlaner{iCM,iEvent}.Start < this.oTimer.fTime) && (~this.cCrewPlaner{iCM,iEvent}.Started)
                            this.cCrewState{iCM} = this.cCrewPlaner{iCM,iEvent}.State;
                            this.cCrewPlaner{iCM,iEvent}.Started = true;
                            this.mCrewStateStartTime(iCM) = this.oTimer.fTime;
                        %if the event end time has been reached and the event
                        %has not ended yet the crew state has to be switched
                        elseif (this.cCrewPlaner{iCM,iEvent}.End < this.oTimer.fTime) && (~this.cCrewPlaner{iCM,iEvent}.Ended)
                            this.cCrewPlaner{iCM,iEvent}.Ended = true;
                            %if the crew member was sleeping --> enter nominal
                            %state
                            if strcmp(this.cCrewPlaner{iCM,iEvent}.State, 'sleep');
                                this.cCrewState{iCM} = 'nominal';
                            %of the crew member was working out --> enter
                            %recovery state
                            else
                                this.cCrewState{iCM} = 'recovery015';
                            end
                            this.mCrewStateStartTime(iCM) = this.oTimer.fTime;
                        end
                    end
                end
            end
            
            if (this.oTimer.fTime > (19.3*3600)) && (this.oTimer.fTime < (37.8*3600))
                this.iCrewMembers = 4;
                this.toStores.Cabin.toProcsP2P.CrewCO2Prod.setCrew([1,1,1,1]);
            elseif (this.oTimer.fTime >= (37.8*3600))
                this.iCrewMembers = 3;
                this.toStores.Cabin.toProcsP2P.CrewCO2Prod.setCrew([1,1,1]);
            end
            
        end
        
    end
    
end

