classdef PhotobioreactorTutorial< vsys
    %Cabin system that incorporates human, CCAA and PBR (PBR has algae as
    %subsysstem). The cabin system and human are based on the V-HAB
    %tutorial of the human model
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        %% Photobioreactor
        txPhotobioreactorProperties  %struct with Photobioreactor Properties
        oPBR                    %PBR object
        
        %% human (from V-HAB Human Tutorial)
        tCurrentFoodRequest;
        cScheduledFoodRequest = cell(0,0);
        fFoodPrepTime = 3*60;
        fInitialFoodPrepMass;
        iNumberOfCrewMembers;
        
    end
    
    methods
        function this = PhotobioreactorTutorial(oParent, sName)
            this@vsys(oParent, sName, -1);
            
            %% Create Photobioreactor
           
            %set some important input values. set[] for value if should not
            %be specified. E.g. struct('sLightColor', [])
            this.txPhotobioreactorProperties = ...
                struct(...
                'sLightColor',              'RedExperimental', ...  %Radiation energy source (light) of photobioreactor. options:Red, Blue, Yellow, Green, Daylight, RedExperimental
                'fSurfacePPFD',             400, ...                %[µmol/m2s] irradiance on surface of PBR. best performance when selecting a value at or just below inhibition -> maximum of PBR in saturated growth zone. Above inhibition growth would be inhibited. 
                'fGrowthVolume',            0.5, ...               %[m3]. Algal growth volume filled with growth medium.
                'fDepthBelowSurface',       0.0025, ...             %[m]. depth of the photobioreactor below the irradiated surface. Typically has strong influence on growth because of radiation attenuation at high depths.     
                'fMembraneSurface',         10, ...                 %[m2]. Area of air exchange membrane. can be limiting when pressure gradient is low and surface small
                'fMembraneThickness',       0.0001, ...             %[m]. Thickness of air exchange membrane.
                'sMembraneMaterial',        'SSP-M823 Silicone',... %type of air exchange membrane. options: 'none', 'SSP-M823 Silicone' or 'Cole Parmer Silicone' (details see AtmosphericGasExchange P2P of algae module)
                'fCirculationVolumetricFlowPerFilter', 4.167*10^-7,... %[m3/s] equal to 25ml/min. Volumetric flow to each filter of the harvester. More means higher ciruclation and faster harvesting capability
                'fNumberOfParallelFilters', 30, ...                 %number of parallel filters since one is not enough for large volumes.
                'bUseUrine',                true);                  %should urine be used for supply or just nitrate (then set to false).
        
         %create photobioreactor object and pass the set properties. If not
         %specified here, the struct does not have to be passed and values
         %will be set automatically by the photobioreactor system. This
         %automatically set photobioreactor is capable of supporting one
         %human in terms of air revitalization and water processing.
         %Further changes, e.g. to the growth rate (large potential for
         %size decrease)
        
        components.matter.PBR.systems.Photobioreactor(this, 'Photobioreactor', this.txPhotobioreactorProperties);
        %photobioreactor class creates algae as its own child system
        
        %% Create CCAA subsystem from V-HAB tutorial for CCAA
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
        components.matter.CCAA.CCAA(this, 'CCAA', 5, fCoolantTemperature, tAtmosphere, sCDRA);
        
        
        %% Add Human to cabin from V-HAB tutorial for Human Model
        
        % crew planer
        % Since the crew schedule follows the same pattern every day,
        % it was changed to a loop. Thereby, longer mission durations
        % can easily be set just by changing the iLengthOfMission
        % parameter. Currently, 10 days are set. If the number is
        % higher tan the actual simulation time, this does not make any
        % difference. If it is too short, the impact of the humans
        % stops somewhen during the simulation time and the simulation
        % is not usable. So make sure to ajust the parameter properly.
        
        %Number of CrewMember goes here:
        this.iNumberOfCrewMembers = 1;
        iLengthOfMission = 200; % [d
        ctEvents = cell(iLengthOfMission, this.iNumberOfCrewMembers);
        
        % Nominal Operation
        tMealTimes.Breakfast = 0*3600;
        tMealTimes.Lunch = 6*3600;
        tMealTimes.Dinner = 15*3600;
        
        for iCrewMember = 1:this.iNumberOfCrewMembers
            
            iEvent = 1;
            
            for iDay = 1:iLengthOfMission
                if iCrewMember == 1 || iCrewMember == 4
                    
                    ctEvents{iEvent, iCrewMember}.State = 2;
                    ctEvents{iEvent, iCrewMember}.Start = ((iDay-1) * 24 +  1) * 3600;
                    ctEvents{iEvent, iCrewMember}.End = ((iDay-1) * 24 +  2) * 3600;
                    ctEvents{iEvent, iCrewMember}.Started = false;
                    ctEvents{iEvent, iCrewMember}.Ended = false;
                    ctEvents{iEvent, iCrewMember}.VO2_percent = 0.75;
                    
                elseif iCrewMember==2 || iCrewMember ==5
                    ctEvents{iEvent, iCrewMember}.State = 2;
                    ctEvents{iEvent, iCrewMember}.Start = ((iDay-1) * 24 +  5) * 3600;
                    ctEvents{iEvent, iCrewMember}.End = ((iDay-1) * 24 +  6) * 3600;
                    ctEvents{iEvent, iCrewMember}.Started = false;
                    ctEvents{iEvent, iCrewMember}.Ended = false;
                    ctEvents{iEvent, iCrewMember}.VO2_percent = 0.75;
                    
                elseif iCrewMember ==3 || iCrewMember == 6
                    ctEvents{iEvent, iCrewMember}.State = 2;
                    ctEvents{iEvent, iCrewMember}.Start = ((iDay-1) * 24 +  9) * 3600;
                    ctEvents{iEvent, iCrewMember}.End = ((iDay-1) * 24 +  10) * 3600;
                    ctEvents{iEvent, iCrewMember}.Started = false;
                    ctEvents{iEvent, iCrewMember}.Ended = false;
                    ctEvents{iEvent, iCrewMember}.VO2_percent = 0.75;
                end
                
                iEvent = iEvent + 1;
                
                ctEvents{iEvent, iCrewMember}.State = 0;
                ctEvents{iEvent, iCrewMember}.Start =   ((iDay-1) * 24 +  14) * 3600;
                ctEvents{iEvent, iCrewMember}.End =     ((iDay-1) * 24 +  22) * 3600;
                ctEvents{iEvent, iCrewMember}.Started = false;
                ctEvents{iEvent, iCrewMember}.Ended = false;
                
                iEvent = iEvent + 1;
            end
        end
        
        for iCrewMember = 1:this.iNumberOfCrewMembers
            
            txCrewPlaner.ctEvents = ctEvents(:, iCrewMember);
            txCrewPlaner.tMealTimes = tMealTimes;
            
            % add human subsystem
            %Human          (oParent, sName,                       Male,fAge, fHumanMass, fHumanHeight, txCrewPlaner, trInitialFoodComposition)
            components.matter.Human(this, ['Human_', num2str(iCrewMember)], true, 28, 84.5, 1.84, txCrewPlaner);
            
            clear txCrewPlaner;
        end
        
        eval(this.oRoot.oCfgParams.configCode(this));
        
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% cabin stores
            % cabin store
            % atmosphere
            matter.store(this, 'Cabin', 65);
            
            fAmbientTemperature = 295; %
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            fCO2Percent = 0.0062;
            %                                                       %store         volume      %deviation from air_custom phase, set Argon to 0                                        rel hum   pressure
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 65, struct('CO2', fCO2Percent),  fAmbientTemperature, 0.4, 1e5);
            % Adding a phase to the store 'Cabin', 65 m^3 air
            oCabinPhase = matter.phases.gas(this.toStores.Cabin, 'CabinAir', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            % Store for Potable Water
            matter.store(this, 'PotableWaterStorage', 1);
            oPotableWaterPhase = matter.phases.liquid(this.toStores.PotableWaterStorage, 'PotableWater', struct('H2O', 100), 295, 101325);
            
            % store for urine
            matter.store(this, 'UrineStorage', 1);
            oUrinePhase = matter.phases.mixture(this.toStores.UrineStorage, 'Urine', 'liquid', struct('C2H6O2N2', 0.059, 'H2O', 1.6), 295, 101325);
            
            % store for  feces storage
            matter.store(this, 'FecesStorage', 1);
            oFecesPhase = matter.phases.mixture(this.toStores.FecesStorage, 'Feces', 'solid', struct('C42H69O13N5', 0.032, 'H2O', 0.1), 295, 101325);
            
            % food store
            % Adds a food store to the system
            %10 kg carrots additional to normal food (could add algae)
            %can fill food store with algae from harvest through exme
            %make sure enough food is in the store for entire time
            %should be per person around 1.5kg/d (from V-HAB Human Model Tutorial)
            tfFood = struct('Food', 100, 'Carrots', 10);
            oFoodStore = components.matter.FoodStore(this, 'FoodStore', 100, tfFood);
            
            
            %% Photobioreactor Connections
            %Interface to PBR for air revitalization
            matter.procs.exmes.gas(this.toStores.Cabin.toPhases.CabinAir, 'To_PBR');
            matter.procs.exmes.gas(this.toStores.Cabin.toPhases.CabinAir, 'From_PBR');
            matter.branch(this,'Cabin_Outlet' ,{}, 'Cabin.To_PBR');
            matter.branch(this, 'Cabin_Inlet' ,{},'Cabin.From_PBR');
            
            %interface from PBR for produced water
            matter.procs.exmes.liquid(this.toStores.PotableWaterStorage.toPhases.PotableWater, 'Water_from_PBR');
            matter.branch(this, 'Water_Inlet',{} ,'PotableWaterStorage.Water_from_PBR');
            
            % interface to PBR for urine processing
            matter.procs.exmes.mixture(this.toStores.UrineStorage.toPhases.Urine, 'Urine_to_PBR');
            matter.branch(this, 'Urine_PBR',{}, 'UrineStorage.Urine_to_PBR');
            
            %connection from PBR for harvested Chlorella biomass
            matter.procs.exmes.mixture(this.toStores.FoodStore.toPhases.Food, 'Chlorella_from_PBR');
            matter.branch(this, 'Chlorella_Inlet',{} ,'FoodStore.Chlorella_from_PBR');
            
            %set interfaces in photobioreactor child system
            this.toChildren.Photobioreactor.setIfFlows('Cabin_Outlet', 'Cabin_Inlet', 'Water_Inlet', 'Urine_PBR', 'Chlorella_Inlet');
            
            %% human model connections
            for iHuman = 1:this.iNumberOfCrewMembers
                % Add Exmes for each human (from V-HAB Human Model Tutorial)
                matter.procs.exmes.gas(oCabinPhase,             ['AirOut',      num2str(iHuman)]);
                matter.procs.exmes.gas(oCabinPhase,             ['AirIn',       num2str(iHuman)]);
                matter.procs.exmes.liquid(oPotableWaterPhase,   ['DrinkingOut', num2str(iHuman)]);
                matter.procs.exmes.mixture(oFecesPhase,         ['Feces_In',    num2str(iHuman)]);
                matter.procs.exmes.mixture(oUrinePhase,         ['Urine_In',    num2str(iHuman)]);
                
                % Add interface branches for each human (from V-HAB Human Model Tutorial)
                matter.branch(this, ['Air_Out',         num2str(iHuman)],  	{}, ['Cabin.AirOut',                    num2str(iHuman)]);
                matter.branch(this, ['Air_In',          num2str(iHuman)], 	{}, ['Cabin.AirIn',                     num2str(iHuman)]);
                matter.branch(this, ['Feces',           num2str(iHuman)],  	{}, ['FecesStorage.Feces_In',           num2str(iHuman)]);
                matter.branch(this, ['PotableWater',    num2str(iHuman)], 	{}, ['PotableWaterStorage.DrinkingOut', num2str(iHuman)]);
                matter.branch(this, ['Urine',           num2str(iHuman)], 	{}, ['UrineStorage.Urine_In',           num2str(iHuman)]);
                
                % register each human at the food store (from V-HAB Human Model Tutorial)
                requestFood = oFoodStore.registerHuman(['Solid_Food_', num2str(iHuman)]);
                this.toChildren.(['Human_', num2str(iHuman)]).bindRequestFoodFunction(requestFood);
                
                % Set the interfaces for each human (from V-HAB Human Model Tutorial)
                this.toChildren.(['Human_',         num2str(iHuman)]).setIfFlows(...
                    ['Air_Out',         num2str(iHuman)],...
                    ['Air_In',          num2str(iHuman)],...
                    ['PotableWater',    num2str(iHuman)],...
                    ['Solid_Food_',     num2str(iHuman)],...
                    ['Feces',           num2str(iHuman)],...
                    ['Urine',           num2str(iHuman)]);
            end
            
            
            
            %% CCAA  (from V-HAB CCAA Tutorial)
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oCabinPhase, 'Port_1');
            matter.procs.exmes.gas(oCabinPhase, 'Port_2');
            matter.procs.exmes.gas(oCabinPhase, 'Port_3');
            
            % Coolant store for the coolant water supplied to CCAA
            matter.store(this, 'CoolantStore', 1);
            
            % Adding a phase to the store 'Tank_3', 1 m^3 water
            oCoolantPhase = matter.phases.liquid(this.toStores.CoolantStore, ...  Store in which the phase is located
                'Coolant_Phase', ...        Phase name
                struct('H2O', 1), ...      Phase contents
                280.15, ...                Phase temperature
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
            
            %define branches for CCAA
            matter.branch(this, 'CCAAinput', {}, 'Cabin.Port_1');
            matter.branch(this, 'CCAA_CHX_Output', {}, 'Cabin.Port_2');
            matter.branch(this, 'CCAA_TCCV_Output', {}, 'Cabin.Port_3');
            matter.branch(this, 'CCAA_CondensateOutput', {}, 'CondensateStore.Port_1');
            matter.branch(this, 'CCAA_CoolantInput', {}, 'CoolantStore.Port_1');
            matter.branch(this, 'CCAA_CoolantOutput', {}, 'CoolantStore.Port_2');
            
            
            % now the interfaces between this system and the CCAA subsystem
            % are defined
            this.toChildren.CCAA.setIfFlows('CCAAinput', 'CCAA_CHX_Output', 'CCAA_TCCV_Output', 'CCAA_CondensateOutput', 'CCAA_CoolantInput', 'CCAA_CoolantOutput');
            
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            % Adding heat sources to keep the cabin and coolant water at a
            % constant temperature
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Cabin_Constant_Temperature');
            this.toStores.Cabin.toPhases.CabinAir.oCapacity.addHeatSource(oHeatSource);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Coolant_Constant_Temperature');
            this.toStores.CoolantStore.toPhases.Coolant_Phase.oCapacity.addHeatSource(oHeatSource);
            
            for iHuman = 1:this.iNumberOfCrewMembers
                this.toChildren.(['Human_', num2str(iHuman)]).createHumanHeatSource();
            end
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % For storage phases we set a fixed time step of 20 seconds
            tTimeStepProperties.fFixedTimeStep = 20;
            
            this.toStores.UrineStorage.toPhases.Urine.setTimeStepProperties(tTimeStepProperties);
            this.toStores.FecesStorage.toPhases.Feces.setTimeStepProperties(tTimeStepProperties);
            this.toStores.PotableWaterStorage.toPhases.PotableWater.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
        end
    end
    
end

