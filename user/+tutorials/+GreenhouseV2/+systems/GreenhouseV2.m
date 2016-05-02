classdef GreenhouseV2 < vsys
    properties
        ttxPlantParameters;
        
        ttxInput;
        
        toCultures;
        
        csCultures;
    end
    
    methods
        function this = GreenhouseV2(oParent, sName)
            this@vsys(oParent, sName);
            
            %% Import Plant Parameters
            
            % import plant parameters from .csv file
            this.ttxPlantParameters = ...
                tutorials.GreenhouseV2.plantparameters.importPlantParameters();
            
            % import coefficient matrices for CQY and T_A
            % save fieldnames to temporary cell array
            csPlantSpecies = fieldnames(this.ttxPlantParameters);
            
            % loop over entries in cell array (= number of plant species)
            for iI = 1:size(csPlantSpecies)
                % import coefficient matrices for CQY
                this.ttxPlantParameters.(csPlantSpecies{iI}).mfMatrix_CQY = ...
                    csvread(['user/+tutorials/+GreenhouseV2/+plantparameters/', csPlantSpecies{iI}, '_Coefficient_Matrix_CQY.csv']);
                
                % import coefficient matrices for T_A
                this.ttxPlantParameters.(csPlantSpecies{iI}).mfMatrix_T_A = ...
                    csvread(['user/+tutorials/+GreenhouseV2/+plantparameters/', csPlantSpecies{iI}, '_Coefficient_Matrix_T_A.csv']);
                
                %% Additional Required Parameters
                
                % Unit conversion factor. not a true "plant" parameter per
                % se but needed in the MMEC calculations so it will be part 
                % of ttxPlantParameters.
                % [s h^-1 mol µmol^-1]
                this.ttxPlantParameters.(csPlantSpecies{iI}).fAlpha = 0.0036;
                
                % fresh basis water factor FBWF_Edible = WBF * (1 - WBF)^-1
                % for edible biomass
                % [fluid mass over dry mass]
                this.ttxPlantParameters.(csPlantSpecies{iI}).fFBWF_Edible = ...
                    this.ttxPlantParameters.(csPlantSpecies{iI}).fWBF * ...
                    (1 - this.ttxPlantParameters.(csPlantSpecies{iI}).fWBF)^-1;
                
                % fresh basis water factor for inedible biomass
                % FBWF_Inedible. since inedible biomass water content is
                % always assumed to be 90% this factor equals 9 for all
                % species
                % [fluid mass over dry mass]
                this.ttxPlantParameters.(csPlantSpecies{iI}).fFBWF_Inedible = 9;
            end
            
            %% Import Culture Setup Inputs
            
            % temporary variable to shorten property structure (to get
            % layout ttxInput.cultureXYZ.blablubb instead of
            % ttxInput.CultureInput.cultureXYZ.blablubb). 
            % TODO: find a better way for providing inputs for culture
            % setup. old way will have to do for now, it works at least.
            blubb = load(...
                strrep('tutorials\+GreenhouseV2\+components\+cultures\CultureInput.mat', '\', filesep));
            
            % write to property
            this.ttxInput = blubb.CultureInput;
            
            %% Create Culture Objects
            
            % write culture names into cell array to be accessed within
            % loop
            this.csCultures = fieldnames(this.ttxInput);
            
            % loop over total cultures amount
            for iI = 1:length(this.csCultures)
                % culture object gets assigned using its culture name 
                this.toCultures.(this.csCultures{iI}) = ...
                    tutorials.GreenhouseV2.components.Culture3Phases(...
                        this, ...                               % parent system reference
                        this.ttxPlantParameters.(this.ttxInput.(this.csCultures{iI}).sPlantSpecies), ...
                        this.ttxInput.(this.csCultures{iI}));   % input for specific culture
            end
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % init stuff just for testing, will be reomved when proper
            % initialization scenario has been found. most/all volumes are
            % arbitrary values as well
            fTemperatureInit = 293.15;  % [K]
            fPressureInit = 101325;     % [Pa]
            
            %% Atmosphere
            
            matter.store(this, 'Atmosphere', 20);
            
%             oAtmosphere = matter.phases.gas(...
%                 this.toStores.Atmosphere, ...       % store containing phase
%                 'Atmosphere', ...                   % phase name
%                 struct(...                          % phase contents    [kg]
%                     'N2',   1, ...
%                     'O2',   0.27, ...
%                     'CO2',  0.05, ...
%                     'H2O',  0.05), ...
%                 20, ...                             % phase volume      [m^3]
%                 fTemperatureInit);                  % phase temperature [K]

            oAtmosphere = this.toStores.Atmosphere.createPhase('air', 20, 293.15, 0.5, 101325);
                  
            %% Water Supply
            
            matter.store(this, 'WaterSupply', 20);
            
            oWaterSupply = matter.phases.liquid(...
                this.toStores.WaterSupply, ...      % store containing phase
                'WaterSupply', ...                  % phase name
                struct(...                          % phase contents    [kg]
                    'H2O', 10), ...
                20, ...                             % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                fPressureInit);                     % phase pressure    [Pa]
                       
            %% Nutrient Supply
            
            matter.store(this, 'NutrientSupply', 20);
            
            oNutrientSupply = matter.phases.liquid(...
                this.toStores.NutrientSupply, ...   % store containing phase
                'NutrientSupply', ...               % phase name
                struct(...                          % phase contens     [kg]
                    'Nutrients', 10), ...
                20, ...                             % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                fPressureInit);                     % phase pressure    [Pa]
            
            %% Biomass Edible/Inedible Split Buffer
            
            matter.store(this, 'BiomassSplit', 1);
            
            oBiomassEdibleSplit = matter.phases.solid(...
                this.toStores.BiomassSplit, ...     % store containing phase
                'BiomassEdible', ...                % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            matter.procs.exmes.solid(oBiomassEdibleSplit, 'BiomassEdible_Out_ToStorage');
            matter.procs.exmes.solid(oBiomassEdibleSplit, 'EdibleInedible_Split_P2P');
            
            oBiomassInedibleSplit = matter.phases.solid(...
                this.toStores.BiomassSplit, ...     % store containing phase
                'BiomassInedible', ...              % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]

            matter.procs.exmes.solid(oBiomassInedibleSplit, 'BiomassInedible_Out_ToStorage');
            matter.procs.exmes.solid(oBiomassInedibleSplit, 'EdibleInedible_Split_P2P');
            
            %% Biomass Storage
            
            matter.store(this, 'BiomassEdible', 20);
            
            oBiomassEdible = matter.phases.solid(...
                this.toStores.BiomassEdible, ...    % store containing phase
                'BiomassEdible', ...                % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            matter.procs.exmes.solid(oBiomassEdible, 'BiomassEdible_In_FromSplit');
            
            matter.store(this, 'BiomassInedible', 20);
            
            oBiomassInedible = matter.phases.solid(...
                this.toStores.BiomassInedible, ...  % store containing phase
                'BiomassInedible', ...              % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            matter.procs.exmes.solid(oBiomassInedible, 'BiomassInedible_In_FromSplit');
           
            %% Create Biomass Split P2P
            
            tutorials.GreenhouseV2.components.BiomassSplit(...
                this.toStores.BiomassSplit, ...
                'EdibleInedible_Split_P2P', ...
                'BiomassEdible.EdibleInedible_Split_P2P', ...
                'BiomassInedible.EdibleInedible_Split_P2P');
            
            %% Create EXMEs for Culture Connections
            
            % get names and number of grown cultures
            this.csCultures = fieldnames(this.toCultures);
            
            % loop over all cultures to create each required exmes 
            for iI = 1:length(this.csCultures)
                % subsystem interfaces
                matter.procs.exmes.gas(oAtmosphere,             [this.toCultures.(this.csCultures{iI}).sName, '_AtmosphereCirculation_Out']);
                matter.procs.exmes.gas(oAtmosphere,             [this.toCultures.(this.csCultures{iI}).sName, '_AtmosphereCirculation_In']);
                matter.procs.exmes.liquid(oWaterSupply,         [this.toCultures.(this.csCultures{iI}).sName, '_WaterSupply_Out']);
                matter.procs.exmes.liquid(oNutrientSupply,      [this.toCultures.(this.csCultures{iI}).sName, '_NutrientSupply_Out']);
                matter.procs.exmes.solid(oBiomassEdibleSplit,   [this.toCultures.(this.csCultures{iI}).sName, '_Biomass_In']);
            end
            
            %% Create Branches
            
            % create edible and inedible biomass branch from split buffer
            % to storage tanks
            matter.branch(this, 'BiomassSplit.BiomassEdible_Out_ToStorage',     {}, 'BiomassEdible.BiomassEdible_In_FromSplit',     'SplitToEdible');
            matter.branch(this, 'BiomassSplit.BiomassInedible_Out_ToStorage',   {}, 'BiomassInedible.BiomassInedible_In_FromSplit', 'SplitToInedible');
            
            % create subsystem branches, 5 per culture object
            for  iI = 1:length(this.csCultures)
                matter.branch(this, [this.toCultures.(this.csCultures{iI}).sName, '_Atmosphere_ToIF_Out'],      {}, ['Atmosphere.',     this.toCultures.(this.csCultures{iI}).sName, '_AtmosphereCirculation_Out']);
                matter.branch(this, [this.toCultures.(this.csCultures{iI}).sName, '_Atmosphere_FromIF_In'],     {}, ['Atmosphere.',     this.toCultures.(this.csCultures{iI}).sName, '_AtmosphereCirculation_In']);
                matter.branch(this, [this.toCultures.(this.csCultures{iI}).sName, '_WaterSupply_ToIF_Out'],     {}, ['WaterSupply.',    this.toCultures.(this.csCultures{iI}).sName, '_WaterSupply_Out']);
                matter.branch(this, [this.toCultures.(this.csCultures{iI}).sName, '_NutrientSupply_ToIF_Out'],  {}, ['NutrientSupply.', this.toCultures.(this.csCultures{iI}).sName, '_NutrientSupply_Out']);
                matter.branch(this, [this.toCultures.(this.csCultures{iI}).sName, '_Biomass_FromIF_In'],        {}, ['BiomassSplit.',   this.toCultures.(this.csCultures{iI}).sName, '_Biomass_In']);
            end
            
            %% Connect Interfaces
            
            for iI = 1:length(this.csCultures)
                this.toCultures.(this.csCultures{iI}).setIfFlows(...
                    [this.toCultures.(this.csCultures{iI}).sName, '_Atmosphere_ToIF_Out'], ...
                    [this.toCultures.(this.csCultures{iI}).sName ,'_Atmosphere_FromIF_In'], ...
                    [this.toCultures.(this.csCultures{iI}).sName ,'_WaterSupply_ToIF_Out'], ...
                    [this.toCultures.(this.csCultures{iI}).sName ,'_NutrientSupply_ToIF_Out'], ...
                    [this.toCultures.(this.csCultures{iI}).sName ,'_Biomass_FromIF_In']);
            end
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.SplitToEdible);
            solver.matter.manual.branch(this.toBranches.SplitToInedible);
            
            this.toBranches.SplitToEdible.oHandler.setFlowRate(0);
            this.toBranches.SplitToInedible.oHandler.setFlowRate(0);
        end
        
        %% Calculate Atmosphere CO2 Concentration
        
        function [ fCO2 ] = CalculateCO2Concentration(this)
            % function to calculate the CO2 concentration in the referenced
            % atmosphere
            fCO2 = ((this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afMass(this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.oMT.tiN2I.CO2) * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMolarMass) / (this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMass * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.oMT.afMolarMass(this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.oMT.tiN2I.CO2))) * 1e6;
        end
        
        % placeholder for later. it should be possible for user comfort to
        % add cultures via the following method. will be implemented after
        % new plant model has been validated as inputs etc. have to be
        % adjusted.
        function this = addCulture(this, sCultureName, sPlantSpecies, fGrowthArea, fEmergeTime, iConsecutiveGenerations, fHarvestTime, fPPFD, fH)
        end
    end 
end