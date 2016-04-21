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
                tutorials.LunarGreenhouseMMEC.plantparameters.importPlantParameters();
            
            % import coefficient matrices for CQY and T_A
            % save fieldnames to temporary cell array
            csPlantSpecies = fieldnames(this.ttxPlantParameters);
            
            % loop over entries in cell array (= number of plant species)
            for iI = 1:size(csPlantSpecies)
                % import coefficient matrices for CQY
                this.ttxPlantParameters.(csPlantSpecies{iI}).mfMatrix_CQY = ...
                    csvread(['user/+tutorials/+LunarGreenhouseMMEC/+plantparameters/', csPlantSpecies{iI}, '_Coefficient_Matrix_CQY.csv']);
                
                % import coefficient matrices for T_A
                this.ttxPlantParameters.(csPlantSpecies{iI}).mfMatrix_T_A = ...
                    csvread(['user/+tutorials/+LunarGreenhouseMMEC/+plantparameters/', csPlantSpecies{iI}, '_Coefficient_Matrix_T_A.csv']);
                
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
                strrep('tutorials\+LunarGreenhouseMMEC\+components\+cultures\CultureInput.mat', '\', filesep));
            
            % write to property
            this.ttxInput = blubb.CultureInput;
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
            
            oAtmosphere = matter.phases.gas(...
                this.toStores.Atmosphere, ...       % store containing phase
                'Atmosphere', ...                   % phase name
                struct(...                          % phase contents    [kg]
                    'N2',   1, ...
                    'O2',   0.27, ...
                    'CO2',  0.05, ...
                    'H2O',  0.05), ...
                20, ...                             % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
%             matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_FromInterface_In');
%             matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_ToInterface_Out');
            
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
            
%             matter.procs.exmes.liquid(oWaterSupply, 'WaterSupply_FromInterface_In');
            
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
            
%             matter.procs.exmes.liquid(oNutrientSupply, 'NutrientSupply_FromInterface_In');
            
            %% Biomass Storage
            
            matter.store(this, 'BiomassEdible', 20);
            
            oBiomassEdible = matter.phases.solid(...
                this.toStores.BiomassEdible, ...    % store containing phase
                'BiomassEdible', ...                % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
%             matter.procs.exmes.solid(oBiomassEdible, 'BiomassEdible_ToInterface_Out');
            
            matter.store(this, 'BiomassInedible', 20);
            
            oBiomassInedible = matter.phases.solid(...
                this.toStores.BiomassInedible, ...  % store containing phase
                'BiomassInedible', ...              % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
%             matter.procs.exmes.solid(oBiomassInedible, 'BiomassInedible_ToInterface_Out');
            
            %% Create culture objects
            
            % TODO:
            % use something like a struct as a transfer parameter to create
            % all cultures via simple use of a for-loop. How to organize
            % struct/whatever and how/where to get inputs has yet to be
            % determined. Inputs should be stuff like planting area and
            % PPFD.
            
            % write culture names into cell array to be accessed within
            % loop
            this.csCultures = fieldnames(this.ttxInput);
            
            % loop over total cultures amount
            for iI = 1:length(this.csCultures)
                % culture object gets assigned using its culture name 
                this.toCultures.(this.csCultures{iI}) = ...
                    tutorials.GreenhouseV2.components.CultureV2(...
                        this, ...                               % parent system reference
                        this.ttxPlantParameters.(this.ttxInput.(this.csCultures{iI}).sPlantSpecies), ...
                        this.ttxInput.(this.csCultures{iI}));   % input for specific culture
            end

%             %% Create EXMEs for Culture Connections
%             
%             % loop over all cultures to create each six required exmes 
%             for iI = 1:length(this.csCultures)
%                 matter.procs.exmes.gas(oAtmosphere, [this.toCultures.(this.csCultures{iI}), '_AtmosphereCirculation_In']);
%                 matter.procs.exmes.gas(oAtmosphere, [this.toCultures.(this.csCultures{iI}), '_AtmosphereCirculation_Out']);
%                 matter.procs.exmes.liquid(oWaterSupply, [this.toCultures.(this.csCultures{iI}), '_WaterSupply_Out']);
%                 matter.procs.exmes.liquid(oNutrientSupply, [this.toCultures.(this.csCultures{iI}), '_NutrientSupply_Out']);
%                 matter.procs.exmes.solid(oBiomassEdible, [this.toCultures.(this.csCultures{iI}), '_BiomassEdible_In']);
%                 matter.procs.exmes.solid(oBiomassInedible, [this.toCultures.(this.csCultures{iI}), '_BiomassInedible_In']);
%             end
            
            %% Create Branches
            
            % 
            this.csCultures = fieldnames(this.toCultures);
            
            for  iI = 1:length(this.csCultures)
                matter.branch(...
                    this, ...
                    [this.toStores.Atmosphere.sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_AtmosphereCirculation_Out'], ...
                     {}, ...
                    [this.toStores.(this.ttxInput.(this.csCultures{iI}).sCultureName).sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_AtmosphereCirculation_In'], ...
                    [this.ttxInput.(this.csCultures{iI}).sCultureName, '_AtmosphereCirculation_In']);
            
                matter.branch(...
                    this, ...
                    [this.toStores.(this.ttxInput.(this.csCultures{iI}).sCultureName).sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_AtmosphereCirculation_Out'], ...
                    {}, ...
                    [this.toStores.Atmosphere.sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_AtmosphereCirculation_In'], ...
                    [this.ttxInput.(this.csCultures{iI}).sCultureName, '_AtmosphereCirculation_Out']);
            
                matter.branch(...
                    this, ...
                    [this.toStores.WaterSupply.sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_WaterSupply_Out'], ...
                    {}, ...
                    [this.toStores.(this.ttxInput.(this.csCultures{iI}).sCultureName).sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_WaterSupply_In'], ...
                    [this.ttxInput.(this.csCultures{iI}).sCultureName, '_WaterSupply_In']);
            
                matter.branch(...
                    this, ...
                    [this.toStores.NutrientSupply.sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_NutrientSupply_Out'], ...
                    {}, ...
                    [this.toStores.(this.ttxInput.(this.csCultures{iI}).sCultureName).sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_NutrientSupply_In'], ...
                    [this.ttxInput.(this.csCultures{iI}).sCultureName, '_NutrientSupply_In']);
            
                matter.branch(...
                    this, ...
                    [this.toStores.(this.ttxInput.(this.csCultures{iI}).sCultureName).sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_BiomassEdible_Out'], ...
                    {}, ...
                    [this.toStores.BiomassEdible.sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_BiomassEdible_In'], ...
                    [this.ttxInput.(this.csCultures{iI}).sCultureName, '_BiomassEdible_Out']);
            
                matter.branch(...
                    this, ...
                    [this.toStores.(this.ttxInput.(this.csCultures{iI}).sCultureName).sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_BiomassInedible_Out'], ...
                    {}, ...
                    [this.toStores.BiomassInedible.sName, '.', this.ttxInput.(this.csCultures{iI}).sCultureName, '_BiomassInedible_In'], ...
                    [this.ttxInput.(this.csCultures{iI}).sCultureName, '_BiomassInedible_Out']);
            end
            
            %% Connect Interfaces
            
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
        end
        
        % placeholder for later. it should be possible for user comfort to
        % add cultures via the following method. will be implemented after
        % new plant model has been validated as inputs etc. have to be
        % adjusted.
        function this = addCulture(this, sCultureName, sPlantSpecies, fGrowthArea, fEmergeTime, iConsecutiveGenerations, fHarvestTime, fPPFD, fH)
        end
    end 
end