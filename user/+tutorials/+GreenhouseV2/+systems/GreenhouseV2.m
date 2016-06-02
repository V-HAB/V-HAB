classdef GreenhouseV2 < vsys
    properties
        ttxNutrientData;
        
        ttxPlantParameters;
        
        ttxInput;
        
        toCultures;
        
        csCultures;
        
        fUpdateFrequency = 60;   % [s]
        
        %% Atmosphere Control Paramters
        
        % water separator flowrate (value taken from old plant module)
        fFlowRateWS = 0.065;
        
        %
        fCO2 = 330;
    end
    
    methods
        function this = GreenhouseV2(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            %% Import Nutrient Data
            
            % import nutirent data from .csv file
            this.ttxNutrientData = ...
                tutorials.GreenhouseV2.food.data.importNutrientData();
            
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
                strrep('tutorials\+GreenhouseV2\+components\+cultures\CultureInputLSP.mat', '\', filesep));
            
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
                        this, ...                                   % parent system reference
                        this.ttxPlantParameters.(this.ttxInput.(this.csCultures{iI}).sPlantSpecies), ...
                        this.ttxInput.(this.csCultures{iI}), ...    % input for specific culture
                        this.fUpdateFrequency);
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
            
            % comment 2e6 if regulation is not needed
            matter.store(this, 'Atmosphere', 20 + 2e6);
            
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
                    'H2O', 20e3), ...
                20, ...                             % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                fPressureInit);                     % phase pressure    [Pa]
                       
            %% Nutrient Supply
            
            matter.store(this, 'NutrientSupply', 20);
            
            oNutrientSupply = matter.phases.liquid(...
                this.toStores.NutrientSupply, ...   % store containing phase
                'NutrientSupply', ...               % phase name
                struct(...                          % phase contens     [kg]
                    'Nutrients', 1e3), ...
                20, ...                             % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                fPressureInit);                     % phase pressure    [Pa]
            
            %% Biomass Edible/Inedible Split Buffer
            
            matter.store(this, 'BiomassSplit', 1);
            
            oBiomassEdibleSplit = matter.phases.liquid(...
                this.toStores.BiomassSplit, ...     % store containing phase
                'BiomassEdible', ...                % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                101325);
            
            matter.procs.exmes.liquid(oBiomassEdibleSplit, 'BiomassEdible_Out_ToStorage');
            matter.procs.exmes.liquid(oBiomassEdibleSplit, 'EdibleInedible_Split_P2P');
            
            oBiomassInedibleSplit = matter.phases.liquid(...
                this.toStores.BiomassSplit, ...     % store containing phase
                'BiomassInedible', ...              % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                101325);

            matter.procs.exmes.liquid(oBiomassInedibleSplit, 'BiomassInedible_Out_ToStorage');
            matter.procs.exmes.liquid(oBiomassInedibleSplit, 'EdibleInedible_Split_P2P');
            
            %% Biomass Storage
            
            matter.store(this, 'BiomassEdible', 20);
            
            oBiomassEdible = matter.phases.liquid(...
                this.toStores.BiomassEdible, ...    % store containing phase
                'BiomassEdible', ...                % phase name
                struct(...                          % phase contents    [kg]
                    'CabbageEdibleWet', 5, ...
                    'StrawberryEdibleWet', 3), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                101325);
            
            matter.procs.exmes.liquid(oBiomassEdible, 'BiomassEdible_In_FromSplit');
            
            matter.store(this, 'BiomassInedible', 20);
            
            oBiomassInedible = matter.phases.liquid(...
                this.toStores.BiomassInedible, ...  % store containing phase
                'BiomassInedible', ...              % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                101325);
            
            matter.procs.exmes.liquid(oBiomassInedible, 'BiomassInedible_In_FromSplit');
            
            %% Leakage Buffer
            
            % add leakage buffer store
            matter.store(this, 'LeakageBuffer', 1e3);
            
            % add phase to leakage buffer store
            oLeakageBuffer = matter.phases.gas(...
                this.toStores.LeakageBuffer, ...        % store containing phase
                'LeakageBuffer', ...                    % phase name
                struct(...                              % phase contents    [kg]
                'CO2', 1e-3), ...
                1e3, ...                                % phase volume      [m^3]
                fTemperatureInit);                      % phase temperature [K]
                
            % add exmes
            matter.procs.exmes.gas(oLeakageBuffer, 'Leakage_In_FromAtmosphere');
            matter.procs.exmes.gas(oAtmosphere, 'Leakage_Out_ToBuffer');
            
            %% Create Atmosphere Composition Control 
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % For usage as standalone system. If atmosphere control is    %
            % managed by other (sub)systems, this section can be          %
            % commented for easy adjusting.                               %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Need to keep O2, CO2 and H2O in check and within certain
            % ranges
            
            % need provision stores for CO2 and N2, a water separator as 
            % well as O2 and CO2 extraction
            
            % add N2 buffer store
            matter.store(this, 'N2BufferSupply', 1e3);
            
            % add phase to N2 buffer store
            oN2BufferSupply = matter.phases.gas(...
                this.toStores.N2BufferSupply, ...       % store containing phase
                'N2BufferSupply', ...                   % phase name
                struct(...                              % phase contents    [kg]
                    'N2', 20e3), ...
                1e3, ...                                % phase volume      [m^3]
                fTemperatureInit);                      % phase temperature [K]
                
            % add exmes
            matter.procs.exmes.gas(oN2BufferSupply, 'N2_Out_ToAtmosphere');
            matter.procs.exmes.gas(oAtmosphere, 'N2_In_FromBuffer');
            
            
            % add CO2 buffer store
            matter.store(this, 'CO2BufferSupply', 1e3);
            
            % add phase to N2 buffer store
            oCO2BufferSupply = matter.phases.gas(...
                this.toStores.CO2BufferSupply, ...      % store containing phase
                'CO2BufferSupply', ...                  % phase name
                struct(...                              % phase contents    [kg]
                    'CO2', 20e3), ...
                1e3, ...                                % phase volume      [m^3]
                fTemperatureInit);                      % phase temperature [K]
                
            % add exmes
            matter.procs.exmes.gas(oCO2BufferSupply, 'CO2_Out_ToAtmosphere');
            matter.procs.exmes.gas(oAtmosphere, 'CO2_In_FromBuffer');
            
            
            % add O2 buffer Store
             matter.store(this, 'O2BufferSupply', 1e3);
            
            % add phase to N2 buffer store
            oO2BufferSupply = matter.phases.gas(...
                this.toStores.O2BufferSupply, ...       % store containing phase
                'O2BufferSupply', ...                   % phase name
                struct(...                              % phase contents    [kg]
                    'O2', 20e3), ...
                1e3, ...                                % phase volume      [m^3]
                fTemperatureInit);                      % phase temperature [K]
                
            % add exmes
            matter.procs.exmes.gas(oO2BufferSupply, 'O2_Out_ToAtmosphere');
            matter.procs.exmes.gas(oAtmosphere, 'O2_In_FromBuffer');
            
            
            % add water separator store
            matter.store(this, 'WaterSeparator', 5);
            
            % add atmosphere phase to water separator
            oAtmosphereWS = this.toStores.WaterSeparator.createPhase('air', 1, 293.15, 0, 101325);
           
            % add water phase to water separator
            oWaterWS = matter.phases.liquid(...
                this.toStores.WaterSeparator, ...       % store containing phase
                'WaterWS', ...                          % phase name
                struct(...                              % phase contents    [kg]
                    'H2O', 1e-3), ...
                4, ...                                  % phase volume      [m^3]
                fTemperatureInit, ...                   % phase temperature [K]
                fPressureInit);                         % phase pressure    [Pa]
           
            % add exmes
            % from and to atmosphere
            matter.procs.exmes.gas(oAtmosphereWS, 'Atmosphere_In_FromAtmosphere');
            matter.procs.exmes.gas(oAtmosphereWS, 'Atmosphere_Out_ToAtmosphere');
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_In_FromSeparator');
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_Out_ToSeparator');
            
            % water absorber exmes
            matter.procs.exmes.gas(oAtmosphereWS, 'WaterAbsorber_P2P');
            matter.procs.exmes.liquid(oWaterWS, 'WaterAbsorber_P2P');
            
            % add water absorber p2p processor
            tutorials.GreenhouseV2.components.WaterAbsorber(this, this.toStores.WaterSeparator, 'WaterAbsorber_P2P', 'WaterSeparator_Phase_1.WaterAbsorber_P2P', 'WaterWS.WaterAbsorber_P2P');
            
            
            % add O2 an CO2 excess phases and exmes to atmosphere store 
            oExcessO2 = matter.phases.gas(...
                this.toStores.Atmosphere, ...       % store containing phase
                'ExcessO2', ...                     % phase name
                struct(...                          % phase contents    [kg]
                    'O2', 1e-3), ...
                1e6, ...                            % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            matter.procs.exmes.gas(oExcessO2, 'ExcessO2_P2P');
            matter.procs.exmes.gas(oAtmosphere, 'ExcessO2_P2P');
            
            oExcessCO2 = matter.phases.gas(...
                this.toStores.Atmosphere, ...       % store containing phase
                'ExcessCO2', ...                    % phase name
                struct(...                          % phase contents    [kg]
                    'CO2', 1e-3), ...
                1e6, ...                            % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            matter.procs.exmes.gas(oExcessCO2, 'ExcessCO2_P2P');
            matter.procs.exmes.gas(oAtmosphere, 'ExcessCO2_P2P');
            
            % add excess extraction p2ps
            tutorials.GreenhouseV2.components.SingleSubstanceExtractor(...
                this, ...                                   % parent system reference
                this.toStores.Atmosphere, ...               % store containing phases
                'ExcessO2_P2P', ...                         % p2p processor name
                'Atmosphere_Phase_1.ExcessO2_P2P', ...      % first phase and exme
                'ExcessO2.ExcessO2_P2P', ...                % second phase and exme
                'O2');                                      % substance to extract
            
            tutorials.GreenhouseV2.components.SingleSubstanceExtractor(...
                this, ...                                   % parent system reference
                this.toStores.Atmosphere, ...               % store containing phases
                'ExcessCO2_P2P', ...                        % p2p processor name
                'Atmosphere_Phase_1.ExcessCO2_P2P', ...     % first phase and exme
                'ExcessCO2.ExcessCO2_P2P', ...              % second phase and exme
                'CO2');                                     % substance to extract
            
            % create branches exclusive to this section
            matter.branch(this, 'N2BufferSupply.N2_Out_ToAtmosphere',           {}, 'Atmosphere.N2_In_FromBuffer',                  'N2BufferSupply');
            matter.branch(this, 'CO2BufferSupply.CO2_Out_ToAtmosphere',         {}, 'Atmosphere.CO2_In_FromBuffer',                 'CO2BufferSupply');
            matter.branch(this, 'O2BufferSupply.O2_Out_ToAtmosphere',           {}, 'Atmosphere.O2_In_FromBuffer',                  'O2BufferSupply');
            matter.branch(this, 'Atmosphere.Atmosphere_Out_ToSeparator',        {}, 'WaterSeparator.Atmosphere_In_FromAtmosphere',  'AtmosphereToWS');
            matter.branch(this, 'WaterSeparator.Atmosphere_Out_ToAtmosphere',   {}, 'Atmosphere.Atmosphere_In_FromSeparator',       'AtmosphereFromWS');
       
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
                matter.procs.exmes.liquid(oBiomassEdibleSplit,  [this.toCultures.(this.csCultures{iI}).sName, '_Biomass_In']);
            end
            
            %% Create Branches
            
            % create leakage branch
            matter.branch(this, 'Atmosphere.Leakage_Out_ToBuffer', {}, 'LeakageBuffer.Leakage_In_FromAtmosphere', 'Leakage');
            
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
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % comment if commented atmosphere CC in createMatterStructure 
            
            solver.matter.manual.branch(this.toBranches.N2BufferSupply);
            solver.matter.manual.branch(this.toBranches.CO2BufferSupply);
            solver.matter.manual.branch(this.toBranches.O2BufferSupply);
            solver.matter.manual.branch(this.toBranches.AtmosphereToWS);
            solver.matter.manual.branch(this.toBranches.AtmosphereFromWS);
            
            this.toBranches.N2BufferSupply.oHandler.setFlowRate(0);
            this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0);
            this.toBranches.O2BufferSupply.oHandler.setFlowRate(0);
            this.toBranches.AtmosphereToWS.oHandler.setFlowRate(0);
            this.toBranches.AtmosphereFromWS.oHandler.setFlowRate(0);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            solver.matter.manual.branch(this.toBranches.Leakage);
            solver.matter.manual.branch(this.toBranches.SplitToEdible);
            solver.matter.manual.branch(this.toBranches.SplitToInedible);
            
            this.toBranches.Leakage.oHandler.setFlowRate(1e-5);
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
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
            % Atmosphere controllers required for standalone greenhouse. If
            % atmosphere control managed by other (sub)systems comment this
            % section
            if ~this.oTimer.fTime
                return;
            end
            
%             % output
%             this.toStores.BiomassEdible.toPhases.BiomassEdible.calculateNutritionalContent();
            
            if this.oTimer.fTime >= 1e5
                keyboard();
            end

            %% O2 Controller
            
            if this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afPP(this.oMT.tiN2I.O2) <= 21000
                this.toStores.Atmosphere.toProcsP2P.ExcessO2_P2P.fExtractionRate = 0;
                this.toBranches.O2BufferSupply.oHandler.setFlowRate(1e-3);
            elseif this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afPP(this.oMT.tiN2I.O2) > 22000
                this.toStores.Atmosphere.toProcsP2P.ExcessO2_P2P.fExtractionRate = 1e-4;
                this.toBranches.O2BufferSupply.oHandler.setFlowRate(0);
            else
                this.toStores.Atmosphere.toProcsP2P.ExcessO2_P2P.fExtractionRate = 0;
                this.toBranches.O2BufferSupply.oHandler.setFlowRate(0);
            end
            
            %% CO2 Controller
            
            this.fCO2 = this.CalculateCO2Concentration();
            if this.fCO2 >= 1300
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0);
                this.toStores.Atmosphere.toProcsP2P.ExcessCO2_P2P.fExtractionRate = 1e-4;
            elseif this.fCO2 < 330
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(1e-3);
                this.toStores.Atmosphere.toProcsP2P.ExcessCO2_P2P.fExtractionRate = 0;
            else
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0);
                this.toStores.Atmosphere.toProcsP2P.ExcessCO2_P2P.fExtractionRate = 0;
            end
            
            %% Humidity Controller
            
            if this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.rRelHumidity >= 0.7
                
                this.toBranches.AtmosphereToWS.oHandler.setFlowRate(this.fFlowRateWS);
                
                fPressureAtmosphereWS = this.toStores.WaterSeparator.toPhases.WaterSeparator_Phase_1.fMass * this.toStores.WaterSeparator.toPhases.WaterSeparator_Phase_1.fMassToPressure;
                
                if fPressureAtmosphereWS > 1e5
                    this.toBranches.AtmosphereFromWS.oHandler.setFlowRate(this.fFlowRateWS);
                elseif fPressureAtmosphereWS >= 9e4
                    this.toBranches.AtmosphereFromWS.oHandler.setFlowRate(this.fFlowRateWS - 0.00045);
                else 
                    this.toBranches.AtmosphereFromWS.oHandler.setFlowRate(this.fFlowRateWS - 0.0009);
                end
                
                
                
%                 this.toBranches.AtmosphereFromWS.oHandler.setFlowRate(this.fFlowRateWS - this.toStores.WaterSeparator.toProcsP2P.WaterAbsorber_P2P.fFlowRate);
            else
                this.toBranches.AtmosphereToWS.oHandler.setFlowRate(0);
                this.toBranches.AtmosphereFromWS.oHandler.setFlowRate(0);
            end
            
            %% Pressure Controller
            
            if this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fPressure < 1e5
                this.toBranches.N2BufferSupply.oHandler.setFlowRate(1e-3);
            else 
                this.toBranches.N2BufferSupply.oHandler.setFlowRate(0);
            end
            
            %% Split to Storage
            
%             if this.toStores.BiomassSplit.toPhases.BiomassEdible.fMass > 0
%             end
        end
    end 
end