classdef PlantModule < vsys
    % This class represents the plant module as a complete subsystem ready
    % to be included in other systems. It requires six (6) interfaces: two
    % for connection to the desired atmosphere to model the gas exchange
    % between plants and the atmosphere, one each for water and nutrient 
    % input required for plant growth and two for the output of edible and
    % inedible biomass respectively.
    
    
    %% WARNING!! -- VERY IMPORTANT!! %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % Be careful with UNITS as the plant module does NOT use SI units for
    % calculation until after all the MMEC parameters are calculated. The
    % MMEC model uses Multi Polynomial Regression (MPR) with coefficient
    % matrices containing values where each one is a different unit. It is
    % also an experimental model and not analytic, so to prevent mistakes
    % due to misunderstanding and the most probable conversion errors the 
    % plant module uses NON-SI units until all calculations regarding MMEC 
    % are done, the resulting rates are then immediately converted to SI 
    % units and all further calculations including everythin V-HAB related 
    % will be in SI units. Be mindful of this when altering code!
    %
    %% WARNING!! -- VERY IMPORTANT!! %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    properties
        % TODO: implement!
        % fixed time step for plant module file (between 1 to 60 min)
        fFixedTimeStep;         % [s]
        
        % struct containing structs containing a dataset for each culture, 
        % NOT in SI units!!!!
        ttxPlantParameters;
        
        % struct containing inputs for the grown cultures,
        % NOT in SI units!!!!
        ttxInput;
        
        % cell arry containing the names of all grown cultures
        csCultures;
        
        % struct containing all culture objects grown within the plant
        % module
        toCultures;
        
        % phase object to connected parent system atmosphere phase 
        oAtmosphereReference;
        
        % phase object to connected parent system water supply phase
        oWaterReference;
        
        % phase object to connected parent system nutrient supply phase
        oNutrientReference;
        
        % harvest activity speed factor, time required per square meter and
        % crew member 
        fHarvestSpeed;                  % [s m^-2]
        
        % atmosphere circulation 
        fAtmosphereCirculation = 0;     % [kg s^-1]
        
        % CO2 concentration in ppm, required for MMEC calculations 
        fCO2 = 0;                       % [ppm]
    end
    
    methods
        function this = PlantModule(oParent, sName, fFixedTimeStep)
            this@vsys(oParent, sName, fFixedTimeStep);
            
            this.fFixedTimeStep = fFixedTimeStep;
            
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
            
            %% Create Plant Module Infrastructure
            
            % One store containing all of the phases, namely an atmosphere
            % phase to model the gas exchange, water and nutrient buffer
            % phases which receive their contents from outside the
            % subsystem, a biomass phase which is connected to the
            % aforementioned three via various p2p procs. This phase is 
            % also connected via p2p proc to the biomass buffer phase which
            % purpose it is to split the "general" biomass into specific 
            % biomass determined by the grown cultures. The last two phases 
            % contain the edible and inedible wet biomass respectively.
            
            % TODO: phase contents and volumes and all initializing
            % parameters. some require new matter tabale entries (nutrients
            % and all kinds of biomass). also do some proper sizing since
            % those should be small(er) buffer stores receiving stuff from
            % outside, must be big enough to work within the whole allowed
            % timestep range which should be customizable
            
            %% Create store and atmosphere phase with exmes
            
            % TODO: call calculateSolidVolume
            
            % create the plant module store, volume 100 just for
            % initialization, store size depends on how many plant cultures
            % are grown inside the module, volume has to be recalculated
            % afterwards to fit each setup.
            matter.store(this, 'PlantModule', 100);
            
            % add atmosphere phase to plant module, try to keep it at 2 m^3
            % TODO: maybe write atmosphere helper later for standard plant
            % atmosphere phase
            oAtmosphere = matter.phases.gas(...
                this.toStores.PlantModule, ...      % store containing phase
                'Atmosphere', ...                   % phase name
                struct(...                          % phase contents    [kg]
                    'N2',   1, ...
                    'O2',   0.27, ...
                    'CO2',  0.05, ...
                    'H2O',  0.05), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
                
            % add exmes to atmosphere phase
            % in- and output exmes to connect the plant module with the 
            % upper level atmosphere phase
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_FromInterface_In');
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_ToInterface_Out');
            
            % exmes to connect the p2p procs for O2, CO2 and H2O gas
            % exchange
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_O2GasExchange_P2P');
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_CO2GasExchange_P2P');
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_H2OGasExchange_P2P');
            
            %% Create water supply phase with exmes
            
            % add water supply phase to plant module
            oWaterSupply = matter.phases.liquid(...
                this.toStores.PlantModule, ...      % store containing phase
                'WaterSupply', ...                  % phase name
                struct(...                          % phase contents    [kg]
                    'H2O', 10), ...
                1, ...                              % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                fPressureInit);                     % phase pressure    [Pa]
            
            % add exmes to water phase
            % input exme to connect the plant module with the upper level
            % water supply
            matter.procs.exmes.liquid(oWaterSupply, 'WaterSupply_FromInterface_In');
            
            % exme to connect the p2p proc for water supply
            matter.procs.exmes.liquid(oWaterSupply, 'WaterSupply_WaterSupply_P2P');
            
            %% Create nutrient supply phase with exmes
            
            % add nutrient supply phase to plant module
            oNutrientSupply = matter.phases.liquid(...
                this.toStores.PlantModule, ...      % store containing phase
                'NutrientSupply', ...               % phase name
                struct(...                          % phase contens     [kg]
                    'Nutrients', 10), ...
                1, ...                              % phase volume      [m^3]
                fTemperatureInit, ...               % phase temperature [K]
                fPressureInit);                     % phase pressure    [Pa]
            
            % add exmes to nutrient supply phase
            % input exme to connect the plant module with the upper level
            % nutrient supply
            matter.procs.exmes.liquid(oNutrientSupply, 'NutrientSupply_FromInterface_In');
            
            % exme to connect the p2p proc for nutrient supply
            matter.procs.exmes.liquid(oNutrientSupply, 'NutrientSupply_NutrientSupply_P2P');
            
            %% Create biomass balance and biomass buffer phases with exmes
            
            % add biomass balance phase to plant module
            oBiomassBalance = matter.phases.absorber(...
                this.toStores.PlantModule, ...      % store containing phase
                'BiomassBalance', ...               % phase name
                struct(...                          % phase contents    [kg]
                    'BiomassBalance', 10), ...
                fTemperatureInit, ...               % phase temperature [K]
                'solid', ...                        % phase state
                'BiomassBalance');                  % phase absorbing substance
            
            % add exmes to biomass balance phase
            % exmes to connect the p2p procs for O2, CO2 and H2O gas
            % exchange, water and nutrient supply as well as one p2p proc
            % to the biomass buffer phase (for mass transfer)
            matter.procs.exmes.absorber(oBiomassBalance, 'BiomassBalance_O2GasExchange_P2P');
            matter.procs.exmes.absorber(oBiomassBalance, 'BiomassBalance_CO2GasExchange_P2P');
            matter.procs.exmes.absorber(oBiomassBalance, 'BiomassBalance_H2OGasExchange_P2P');
            matter.procs.exmes.absorber(oBiomassBalance, 'BiomassBalance_WaterSupply_P2P');
            matter.procs.exmes.absorber(oBiomassBalance, 'BiomassBalance_NutrientSupply_P2P');
            matter.procs.exmes.absorber(oBiomassBalance, 'BiomassBalance_BufferTransfer_P2P');
            
            % add biomass bufferphase to plant module
            oBiomassBuffer = matter.phases.solid(...
                this.toStores.PlantModule, ...      % store containing phase
                'BiomassBuffer', ...                % phase name
                struct(...                          % phase contents    [kg]
                    'BiomassBalance', 10), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            % add exmes to biomass buffer phase
            % exme to connect the p2p proc for mass transfer from the
            % biomass balance phase
            matter.procs.exmes.solid(oBiomassBuffer, 'BiomassBuffer_BufferTransfer_P2P');
            
            % other exmes required to connect the culture phases to this
            % phase via p2p procs will be created automatically upon
            % creation of the specific culture objects
            
            %% Create edible and inedible biomass phases with exmes
            
            % add edible biomass phase to plant module
            oBiomassEdible = matter.phases.solid(...
                this.toStores.PlantModule, ...      % store containing phase
                'BiomassEdible', ...                % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            % add exmes to edible biomass phase
            % output exme to upper level biomass storage
            matter.procs.exmes.solid(oBiomassEdible, 'BiomassEdible_ToInterface_Out');
            
            % other exmes required to connect the culture phases to this
            % phase via p2p procs will be created automatically upon
            % creation of the specific culture objects
            
            % add inedible biomass phase to plant module
            oBiomassInedible = matter.phases.solid(...
                this.toStores.PlantModule, ...      % store containing phase
                'BiomassInedible', ...              % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                2, ...                              % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            % add exmes to inedible biomass phase
            % output exme to upper level biomass storage
            matter.procs.exmes.solid(oBiomassInedible, 'BiomassInedible_ToInterface_Out');
            
            % other exmes required to connect the culture phases to this
            % phase via p2p procs will be created automatically upon
            % creation of the specific culture objects
            
            %% Create P2P processors (except culture connections)
            
            % O2 gas exchange
            tutorials.LunarGreenhouseMMEC.components.HourlyRatesMMEC(...
                this.toStores.PlantModule, ...                              % store containing phases
                'O2_GasExchange_P2P', ...                                   % p2p processor name
                'BiomassBalance.BiomassBalance_O2GasExchange_P2P', ...      % first phase and exme
                'Atmosphere.Atmosphere_O2GasExchange_P2P', ...              % second phase and exme
                'O2');                                                      % substance to extract
            
            % CO2 gas exchange
            tutorials.LunarGreenhouseMMEC.components.HourlyRatesMMEC(...
                this.toStores.PlantModule, ...                              % store containing phases
                'CO2_GasExchange_P2P', ...                                  % p2p processor name
                'BiomassBalance.BiomassBalance_CO2GasExchange_P2P', ...     % first phase and exme
                'Atmosphere.Atmosphere_CO2GasExchange_P2P', ...             % second phase and exme
                'CO2');                                                     % substance to extract
            
            % H2O gas exchange
            tutorials.LunarGreenhouseMMEC.components.HourlyRatesMMEC(...
                this.toStores.PlantModule, ...                              % store containing phases
                'H2O_GasExchange_P2P', ...                                  % p2p processor name
                'BiomassBalance.BiomassBalance_H2OGasExchange_P2P', ...     % first phase and exme
                'Atmosphere.Atmosphere_H2OGasExchange_P2P', ...             % second phase and exme
                'H2O');                                                     % substance to extract
            
            % water supply
            tutorials.LunarGreenhouseMMEC.components.HourlyRatesMMEC(...
                this.toStores.PlantModule, ...                              % store containing phases
                'WaterSupply_P2P', ...                                      % p2p processor name
                'WaterSupply.WaterSupply_WaterSupply_P2P', ...              % first phase and exme
                'BiomassBalance.BiomassBalance_WaterSupply_P2P', ...        % second phase and exme
                'H2O');                                                     % substance to extract
            
            % nutrient supply
            tutorials.LunarGreenhouseMMEC.components.HourlyRatesMMEC(...
                this.toStores.PlantModule, ...                              % store containing phases
                'NutrientSupply_P2P', ...                                   % p2p processor name
                'NutrientSupply.NutrientSupply_NutrientSupply_P2P', ...     % first phase and exme
                'BiomassBalance.BiomassBalance_NutrientSupply_P2P', ...     % second phase and exme
                'Nutrients');                                               % substance to extract
            
            % biomass transfer from balance to buffer
            tutorials.LunarGreenhouseMMEC.components.HourlyRatesMMEC(...
                this.toStores.PlantModule, ...                              % store containing phases
                'BufferTransfer_P2P', ...                                   % p2p processor name
                'BiomassBalance.BiomassBalance_BufferTransfer_P2P', ...     % first phase and exme
                'BiomassBuffer.BiomassBuffer_BufferTransfer_P2P', ...       % second phase and exme
                'BiomassBalance');                                          % substance to extract
            
            %% Create mass balance manipulator
            
            % create manipulator and link it to mass balance phase
            tutorials.LunarGreenhouseMMEC.components.MassBalance(this, 'MassBalance_Manip', this.toStores.PlantModule.toPhases.BiomassBalance);
            
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
                % culuture object gets assigned using its culture name 
                this.toCultures.(this.csCultures{iI}) = ...
                    tutorials.LunarGreenhouseMMEC.components.cultures.Culture(...
                        this, ...                               % parent system reference
                        this.ttxPlantParameters.(this.ttxInput.(this.csCultures{iI}).sPlantSpecies), ...
                        this.ttxInput.(this.csCultures{iI}));   % input for specific culture
            end
            
            %% Create Branches
            
            matter.branch(this, 'PlantModule.Atmosphere_FromInterface_In',      {}, 'Atmosphere_Interface_In',          'Atmosphere_In');
            matter.branch(this, 'PlantModule.Atmosphere_ToInterface_Out',       {}, 'Atmosphere_Interface_Out',         'Atmosphere_Out');
            matter.branch(this, 'PlantModule.WaterSupply_FromInterface_In',     {}, 'WaterSupply_Interface_In',         'WaterSupply_In');
            matter.branch(this, 'PlantModule.NutrientSupply_FromInterface_In',  {}, 'NutrientSupply_Interface_In',      'NutrientSupply_In');
            matter.branch(this, 'PlantModule.BiomassEdible_ToInterface_Out',    {}, 'BiomassEdible_Interface_Out',      'BiomassEdible_Out');
            matter.branch(this, 'PlantModule.BiomassInedible_ToInterface_Out',  {}, 'BiomassInedible_Interface_Out',    'BiomassInedible_Out');
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %% Add Branches To Solvers
            
            solver.matter.manual.branch(this.toBranches.Atmosphere_In);
            solver.matter.manual.branch(this.toBranches.Atmosphere_Out);
            solver.matter.manual.branch(this.toBranches.WaterSupply_In);
            solver.matter.manual.branch(this.toBranches.NutrientSupply_In);
            solver.matter.manual.branch(this.toBranches.BiomassEdible_Out);
            solver.matter.manual.branch(this.toBranches.BiomassInedible_Out);
            
            %% Initialzie Branch Flow Rates
            
            this.toBranches.Atmosphere_In.oHandler.setFlowRate(this.fAtmosphereCirculation);
            this.toBranches.Atmosphere_Out.oHandler.setFlowRate(this.fAtmosphereCirculation);
            this.toBranches.WaterSupply_In.oHandler.setFlowRate(0);
            this.toBranches.NutrientSupply_In.oHandler.setFlowRate(0);
            this.toBranches.BiomassEdible_Out.oHandler.setFlowRate(0);
            this.toBranches.BiomassInedible_Out.oHandler.setFlowRate(0);
        end
        
        %% Connect Subsystem Interfaces with Parent System
        
        function setIfFlows(this, sInterface1, sInterface2, sInterface3, sInterface4, sInterface5, sInterface6)
                this.connectIF('Atmosphere_Interface_In',       sInterface1);
                this.connectIF('Atmosphere_Interface_Out',      sInterface2);
                this.connectIF('WaterSupply_Interface_In',      sInterface3);
                this.connectIF('NutrientSupply_Interface_In',   sInterface4);
                this.connectIF('BiomassEdible_Interface_Out',   sInterface5);
                this.connectIF('BiomassInedible_Interface_Out', sInterface6);
        end
        
        %% Set Reference Phases
        
        % set path for reference phases, must be called from the parent 
        % system
        function setReferencePhase(this, oAtmosphereReference, oWaterReference, oNutrientReference)
            this.oAtmosphereReference   = oAtmosphereReference;
            this.oWaterReference        = oWaterReference;
            this.oNutrientReference     = oNutrientReference;
        end
        
        %% Calculate Atmosphere CO2 Concentration
        
        function [ fCO2 ] = CalculateCO2Concentration(this)
            % function to calculate the CO2 concentration in the referenced
            % atmosphere
            fCO2 = ((this.oAtmosphereReference.afMass(this.oAtmosphereReference.oMT.tiN2I.CO2) * this.oAtmosphereReference.fMolarMass) / (this.oAtmosphereReference.fMass * this.oAtmosphereReference.oMT.afMolarMass(this.oAtmosphereReference.oMT.tiN2I.CO2))) * 1e6;
        end

    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
            %% Calculate 8 MMEC Parameters
            
            % calculate density of liquid H2O, required for transpiration
            tH2O.sSubstance = 'H2O';
            tH2O.sProperty = 'Density';
            tH2O.sFirstDepName = 'Pressure';
            tH2O.fFirstDepValue = this.oAtmosphereReference.fPressure;
            tH2O.sSecondDepName = 'Temperature';
            tH2O.fSecondDepValue = this.oAtmosphereReference.fTemperature;
            tH2O.sPhaseType = 'liquid';
            
            fDensityH2O = this.oMT.findProperty(tH2O);
            
            % calculate CO2 concentration of atmosphere
            this.fCO2 = this.CalculateCO2Concentration();
            
            % loop over all cultures
            % TODO: maybe parfor later
            % TODO: implement check for enough water available HERE, not
            % inside the function!!
            for iI = 1:length(this.csCultures)
                % calculate plant induced flowrates
                [ this.toCultures.(this.csCultures{iI}) ] = ...                 % return current culture object
                    tutorials.LunarGreenhouseMMEC.components.PlantGrowth(...
                        this.toCultures.(this.csCultures{iI}), ...              % current culture object
                        this.oTimer.fTime, ...                                  % current simulation time
                        this.oAtmosphereReference.fPressure, ...                % atmosphere pressure
                        this.oAtmosphereReference.fDensity, ...                 % atmosphere density
                        this.oAtmosphereReference.fTemperature, ...             % atmosphere temperature
                        this.oAtmosphereReference.rRelHumidity, ...             % atmosphere relative humidity
                        this.oAtmosphereReference.fSpecificHeatCapacity, ...    % atmosphere heat capacity
                        fDensityH2O, ...                                        % density of liquid water under atmosphere conditions
                        this.fCO2);                                             % CO2 concentration in ppm
            
            
                %% Biomass Growth
            
%                 % calculate produced biomass from growth rates 
%                 % produced edible biomass
%                 this.toCultures.(this.csCultures{iI}).tfBiomass.fEdibleBiomass = ...
%                     this.toCultures.(this.csCultures{iI}).tfBiomassGrowthRates.fGrowthRateEdible * this.fFixedTimeStep;
%                 
%                 % produced inedible biomass
%                 this.toCultures.(this.csCultures{iI}).tfBiomass.fInedibleBiomass = ...
%                     this.toCultures.(this.csCultures{iI}).tfBiomassGrowthRates.fGrowthRateInedible * this.fFixedTimeStep;
%             
            
                %% Set P2P Flow Rates
            
            

                %% Harvest
            
                % if current culture state is harvest
                if this.toCultures.(this.csCultures{iI}).iState == 2
                
                else
                    
                end
            end
        end
    end
end