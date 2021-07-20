classdef Greenhouse < vsys
    properties
        % Concentration of CO2 in PPM
        fCO2 = 330; %PPM
        
        bTurnedNutrientsOff = false;
        
        % Struct containing information about the utilized plants
        txPlants;
        
        % Maximum Time Step allowed for this system
        fMaxTimeStep = 3600;
        
        fDayModuleCounter;
        
        
        % plant lighting energy demand in W during the photoperiod
        mfPlantLightEnergy;
        
        tfPlantControlParameters;
    end
    
    methods
        function this = Greenhouse(oParent, sName)
            this@vsys(oParent, sName, 3600*5);
            
            %% Set Culture Setup Inputs
            this.txPlants.iAssumedPreviousPlantGrowthDays = 0;
            this.txPlants.csPlants        = {'Sweetpotato',   'Whitepotato',  'Rice'  , 'Drybean' , 'Soybean' , 'Tomato'  , 'Peanut'  , 'Lettuce',  'Wheat',    'Wheat_I',	'Whitepotato_I',    'Soybean_I'};
            this.txPlants.mfPlantArea     = [ 20          ,   20           ,  20      , 20        , 20        , 20        , 20        , 20,         20,         20,         20,                 20];          % m^2 / CM
            this.txPlants.mfHarvestTime   = [ 85          ,   132          ,  85      , 85        , 97        , 85        , 104       , 28,         70,         85,         138,                97];          % days
            this.txPlants.miSubcultures   = [ 1           ,   1            ,  1       , 1         , 1         , 1         , 1         , 1,          1,          1,          1,                  1];           % -
            this.txPlants.mfPhotoperiod   = [ 12          ,   12           ,  12      , 18        , 12        , 12        , 12        , 16,         20,         20,         12,                 12];          % h/day
            this.txPlants.mfPPFD          = [ 650         ,   650          ,  764     , 370       , 650       , 625       , 625       , 295,        1330,       690,        860,                650];         % micromol/m^2 s
            this.txPlants.mfEmergeTime    = [ 0           ,   0            ,  0       , 0         , 0         , 0         , 0         , 0,          0,          0,          0,                  0];           % days
            
            %% Plants
            iLengthOfMission = 180; %days
            
            tInput = struct();
            for iPlant = 1:length(this.txPlants.csPlants)
                
                mfFirstSowTimeInit = 0 : this.txPlants.mfHarvestTime(iPlant) / this.txPlants.miSubcultures(iPlant) : this.txPlants.mfHarvestTime(iPlant);
                mfFirstSowTimeInit = mfFirstSowTimeInit - this.txPlants.iAssumedPreviousPlantGrowthDays;
                mfFirstSowTimeInit(end) = [];
                mfPlantTimeInit     = zeros(length(mfFirstSowTimeInit),1);
                mfPlantTimeInit(mfFirstSowTimeInit < 0) = -mfFirstSowTimeInit(mfFirstSowTimeInit < 0);
                
                mfPlantTimeInit = mod(mfPlantTimeInit, this.txPlants.mfHarvestTime(iPlant));
                
                for iSubculture = 1:this.txPlants.miSubcultures(iPlant)
                    % Custom name you want to give this specific culture, select a 
                    % name that is easy for you to identify
                    tInput(iPlant, iSubculture).sName       	= [this.txPlants.csPlants{iPlant}, '_', num2str(iSubculture)];
                    
                    % Name of the plant before the '_' has to fit the names defined in 
                    % lib/+components/*PlantModule/+plantparameters/PlantParameters.csv
                    sPlant = strsplit( this.txPlants.csPlants{iPlant}, '_');
                    tInput(iPlant, iSubculture).sPlantSpecies    = sPlant{1};
                    % The growth area defines how many plants are used in the
                    % culture. Please note that depending on your application you
                    % have to set the area to represent the number of plants (see
                    % the plant density parameter in lib/+components/*PlantModule/+plantparameters/PlantParameters.csv
                    % for information on that parameter) and not the actual area.
                    % The area depends on the density of plants and can vary by
                    % some degree! (for very high density shadowing effects will
                    % come into effect)
                    tInput(iPlant, iSubculture).fGrowthArea      = this.txPlants.mfPlantArea(iPlant); % m^2
                    % time after which the plants are harvested
                    tInput(iPlant, iSubculture).fHarvestTime     = this.txPlants.mfHarvestTime(iPlant); % days
                    % The time after which the first part of the plant can be seen
                    tInput(iPlant, iSubculture).fEmergeTime      = this.txPlants.mfEmergeTime(iPlant); % days
                    % Particle Photon Flux Density, which is ony value to define
                    % the intensity of the light the plants receive
                    tInput(iPlant, iSubculture).fPPFD            = this.txPlants.mfPPFD(iPlant); % micromol/m^2s
                    % Photoperiod in hours (time per day that the plants receive
                    % light)
                    tInput(iPlant, iSubculture).fPhotoperiod     = this.txPlants.mfPhotoperiod(iPlant); % h
                    % This parameter defines how many generations of this culture
                    % are planted in succession. Here we want continoues
                    % plantation and therefore divide the mission duration
                    % with the plant harvest time and roundup
                    tInput(iPlant, iSubculture).iConsecutiveGenerations      = 1 + ceil(iLengthOfMission / this.txPlants.mfHarvestTime(iPlant));
                    
                    components.matter.PlantModule.PlantCulture(...
                            this, ...                   % parent system reference
                            tInput(iPlant, iSubculture).sName,...
                            this.fTimeStep,...          % Time step initially used for this culture in [s]
                            tInput(iPlant, iSubculture),...
                            mfPlantTimeInit(iSubculture));          % input for specific culture
                end
            end
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% Atmosphere
            fTemperature = 293;
            rRelativeHumidity = 0.7;
            fTotalPressure = 101325;
            fCO2_ppm = 1000;
            oStore = matter.store(this, 'Atmosphere', 600);
            oCabinPhase = oStore.createPhase(	'gas', 'boundary',  'Atmosphere',	oStore.fVolume,	struct('CO2', fCO2_ppm/1e6 * fTotalPressure, 'N2', 0.78*fTotalPressure, 'O2', 0.21 * fTotalPressure),	fTemperature,	rRelativeHumidity);
            
            %% Stores and phases required for plants:
            % This store is the connection to the plant NFT system. It
            % receives potable water from the potable water store and CROP
            % output solution
            oStore = matter.store(this,     'NutrientSupply',    0.1);
            fN_Mol_Concentration = 1; % mol/m^3
            fN_Mass = fN_Mol_Concentration * 0.1 * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);
            fWaterMass = 0.1 * 998;
            rNRatio = fN_Mass ./ (fN_Mass + fWaterMass);
            oNutrientSupply 	= oStore.createPhase(	'liquid',   'boundary', 'NutrientSupply',   	oStore.fVolume,	struct('H2O', 1-rNRatio, 'NO3', rNRatio),	293.15,	oCabinPhase.fPressure);
            
            % Biomass Edible/Inedible Split Buffer
            
            oStore = matter.store(this,     'Plant_Preparation',    0.1);
            oInedibleSplit   	= oStore.createPhase(	'mixture',  'flow',    	'Inedible',	'solid', 0.5*oStore.fVolume, struct('H2O', 0),                          oCabinPhase.fTemperature,	oCabinPhase.fPressure);
            oEdibleSplit        = oStore.createPhase(	'mixture',  'flow',    	'Edible',  	'solid', 0.5*oStore.fVolume, struct('H2O', 0),                          oCabinPhase.fTemperature,	oCabinPhase.fPressure);
            
            oFoodStore = components.matter.FoodStore(this, 'Food_Store', 1e6, struct('Food', 1e6));
            
            %% Plant Interfaces
            csInedibleBiomass = cell(length(this.txPlants.csPlants));
            for iPlant = 1:length(this.txPlants.csPlants)
                csInedibleBiomass{iPlant} = [this.toChildren.([this.txPlants.csPlants{iPlant},'_1']).txPlantParameters.sPlantSpecies, 'Inedible'];
            end
            
            matter.procs.exmes.mixture(this.toStores.Plant_Preparation.toPhases.Inedible, 'Plant_Preparation_Out');
            matter.procs.exmes.mixture(this.toStores.Plant_Preparation.toPhases.Edible, 'Plant_Preparation_In');
            components.matter.P2Ps.ConstantMassP2P(this.toStores.Plant_Preparation, 'Plant_Preparation', 'Inedible.Plant_Preparation_Out', 'Edible.Plant_Preparation_In', csInedibleBiomass, 1);
            
            matter.branch(this, oEdibleSplit,                       {}, oFoodStore.toPhases.Food, 	'Plants_to_Foodstore');

            this.tfPlantControlParameters.InitialWater  = oNutrientSupply.afMass(this.oMT.tiN2I.H2O);
            this.tfPlantControlParameters.InitialNO3    = oNutrientSupply.afMass(this.oMT.tiN2I.NO3);

            for iPlant = 1:length(this.txPlants.csPlants)
                for iSubculture = 1:this.txPlants.miSubcultures(iPlant)
                    sCultureName = [this.txPlants.csPlants{iPlant},'_', num2str(iSubculture)];
                    
                    matter.procs.exmes.gas(oCabinPhase,              [sCultureName, '_AtmosphereCirculation_Out']);
                    matter.procs.exmes.gas(oCabinPhase,              [sCultureName, '_AtmosphereCirculation_In']);
                    matter.procs.exmes.liquid(oNutrientSupply,       [sCultureName, '_to_NFT']);
                    matter.procs.exmes.liquid(oNutrientSupply,       [sCultureName, '_from_NFT']);
                    matter.procs.exmes.mixture(oEdibleSplit,         [sCultureName, '_Biomass_In']);

                    matter.branch(this, [sCultureName, '_Atmosphere_ToIF_Out'],      {}, [oCabinPhase.oStore.sName,         '.',	sCultureName, '_AtmosphereCirculation_Out']);
                    matter.branch(this, [sCultureName, '_Atmosphere_FromIF_In'],     {}, [oCabinPhase.oStore.sName,         '.',  	sCultureName, '_AtmosphereCirculation_In']);
                    matter.branch(this, [sCultureName, '_WaterSupply_ToIF_Out'],     {}, [oNutrientSupply.oStore.sName,     '.',    sCultureName, '_to_NFT']);
                    matter.branch(this, [sCultureName, '_NutrientSupply_ToIF_Out'],  {}, [oNutrientSupply.oStore.sName,     '.',    sCultureName, '_from_NFT']);
                    matter.branch(this, [sCultureName, '_Biomass_FromIF_In'],        {}, [oEdibleSplit.oStore.sName,        '.',    sCultureName, '_Biomass_In']);

                    this.toChildren.(sCultureName).setIfFlows(...
                        [sCultureName, '_Atmosphere_ToIF_Out'], ...
                        [sCultureName ,'_Atmosphere_FromIF_In'], ...
                        [sCultureName ,'_WaterSupply_ToIF_Out'], ...
                        [sCultureName ,'_NutrientSupply_ToIF_Out'], ...
                        [sCultureName ,'_Biomass_FromIF_In']);
                end
            end
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %% Solvers required for plant system
            aoMultiSolverBranches = [this.toBranches.Plants_to_Foodstore];
            solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            
            tTimeStepProperties.fMaxStep = this.fTimeStep;
                    
            % set time steps
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    oPhase.setTimeStepProperties(tTimeStepProperties);
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            clear tTimeStepProperties
            tTimeStepProperties.rMaxChange = inf;
            this.toStores.Plant_Preparation.toPhases.Inedible.setTimeStepProperties(tTimeStepProperties);
            this.toStores.Plant_Preparation.toPhases.Edible.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
        
        %% Calculate Atmosphere CO2 Concentration
        
        function [ fCO2 ] = CalculateCO2Concentration(this)
            % function to calculate the CO2 concentration in the referenced
            % atmosphere
            fCO2 = ((this.toStores.Atmosphere.toPhases.Atmosphere.afMass(this.toStores.Atmosphere.toPhases.Atmosphere.oMT.tiN2I.CO2) * this.toStores.Atmosphere.toPhases.Atmosphere.fMolarMass) / (this.toStores.Atmosphere.toPhases.Atmosphere.fMass * this.toStores.Atmosphere.toPhases.Atmosphere.oMT.afMolarMass(this.toStores.Atmosphere.toPhases.Atmosphere.oMT.tiN2I.CO2))) * 1e6;
        end
        
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
            %% Control Logic for plant nutrient supply
            % use if the nutrient deficiency in this example shall be
            % modelled
%             if ~this.bTurnedNutrientsOff
%                 % Remove nutrients to simulate nutrient deficiency:
%                 if this.oTimer.fTime > 80*3600*24
%                     if this.toStores.NutrientSupply.toPhases.NutrientSupply.afMass(this.oMT.tiN2I.NO3) == 0
%                         this.bTurnedNutrientsOff = true;
%                     else
%                         tProperties.afMass = this.toStores.NutrientSupply.toPhases.NutrientSupply.afMass;
%                         tProperties.afMass(this.oMT.tiN2I.NO3) = 0;
%                         this.toStores.WaterSupply.toPhases.WaterSupply.setBoundaryProperties(tProperties);
%                     end
%                 end
%             end
            
            % This code synchronizes everything once a day
            if mod(this.oTimer.fTime, 86400) < this.fDayModuleCounter
                this.oTimer.synchronizeCallBacks();
            end
            this.fDayModuleCounter = mod(this.oTimer.fTime, 86400);
        end
    end 
end