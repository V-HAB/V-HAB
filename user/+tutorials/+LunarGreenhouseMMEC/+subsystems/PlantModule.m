classdef PlantModule < vsys
    % This class represents the plant module as a complete subsystem ready
    % to be included in other systems. It requires six (6) interfaces: two
    % for connection to the desired atmosphere to model the gas exchange
    % between plants and the atmosphere, one each for water and nutrient 
    % input required for plant growth and two for the output of edible and
    % inedible biomass respectively.
    
    properties
        % struct containing structs containing a dataset for each culture
        ttxPlantParameters;
        
        % struct containing all culture objects grown within the plant
        % module
        toCultures;
        
        % phase object to connected parent system atmosphere phase 
        oAtmosphereReference;
        
        % phase object to connected parent system water supply phase
        oWaterReference;
        
        % phase object to connected parent system nutrient supply phase
        oNutrientReference;
    end
    
    methods
        function this = PlantModule(oParent, sName)
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
            end
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
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
                'Atmosphere', ...                   % phas name
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
                fVolumeInit, ...                    % phase volume      [m^3]
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
                    'nutrients', 10), ...
                fVolumeInit, ...                    % phase volume      [m^3]
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
                    'biomass', 10), ...
                fTemperatureInit, ...               % phase temperature [K]
                'solid', ...                        % phase state
                'biomass');                         % phase absorbing substance
            
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
                    'biomass', 10), ...
                fVolumeInit, ...                    % phase volume      [m^3]
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
                fVolumeInit, ...                    % phase volume      [m^3]
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
                fVolumeInit, ...                    % phase volume      [m^3]
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
                'nutrients');                                               % substance to extract
            
            % biomass transfer from balance to buffer
            tutorials.LunarGreenhouseMMEC.components.HourlyRatesMMEC(...
                this.toStores.PlantModule, ...                              % store containing phases
                'WaterSupply_P2P', ...                                      % p2p processor name
                'BiomassBalance.BiomassBalance_BufferTransfer_P2P', ...     % first phase and exme
                'BiomassBuffer.BiomassBuffer_BufferTransfer_P2P', ...       % second phase and exme
                'biomass');                                                 % substance to extract
            
            %% Create mass balance manipulator
            
            % create manipulator and link it to mass balance phase
            tutorials.LunarGreenhouseMMEC.components.MassBalance(this, 'MassBalance_Manip', this.toStores.PlantModule.toPhases.BiomassBalance);
            
            %% Create culture objects
            
            % TODO:
            % use something like a struct as a transfer parameter to create
            % all cultures via simple use of a for-loop. How to organize
            % struct/whatever and how/where to get inputs has yet to be
            % determined. Inputs should be stuff like planting area and
            % PPFD, fixed plant parameters will be taken from matter table 
            % inside the culture object.
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
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
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
            
        end
    end
end