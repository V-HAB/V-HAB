classdef PlantModuleIMPROVED < vsys
    
    properties
        % struct containing all data on grown plant species
        tPlantData = 0;
        
        % struct containing various plant parameters listed in
        % PlantParameters.m in lib/+components/+PlantModule
        tPlantParameters = 0;
                
        % struct to store plant gas exchange rates with the atmosphere,
        % calculated by CreateBiomass manipulator, used by gas exchange
        % p2p-procs
        tPlantGasExchange = 0;
        
        % Set temperatures, need to be constant for now.
        % TODO: according to previous comments, some parts of the plant 
        % module are not capable of handling changing temperatures, find
        % out which parts and why
        fTemperatureLight =     22.5;   % [°C]
        fTemperatureDark =      22.5;   % [°C]
        
        % availbale water for plant growth in the referenced water tank
        fWaterAvailable;    % [kg]
        
        %% Initialize LSS Atmosphere Values
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % if bUseLSSConditions = 0 the following parameters will remain   %
        % unchanged for the duration of the simulation or until or until  %
        % bUseLSSConditions is set to true                                %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % if bUseLSSConditions = 1 the following parameters will be       %
        % dynamically calculated from the reference phase                 %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % relative humidity during light period
        fRelativeHumidityLight =    0.43;   % [-]
        
        % relative humidity during dark period
        fRelativeHumidityDark =     0.43;   % [-]
        
        % atmospheric pressure
        fPressureAtmosphere =       101325; % [Pa]
        
        % atmospheric CO2 concentration
        fCO2ppm =                   1300;   % [µmol/mol]
        
        %% Initialize Plant Lighting Conditions
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % if bGlobalLightingConditions = 0 photoperiod and photon flux    %
        % will be taken from the *.mat file and may be different for each %
        % planted species. In this case they take priority over the       %
        % values below                                                    %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % if bGlobalLightingConditions = 1 photoperiod and photon flux    %
        % below will be valid for all planted species                     %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % photosynthetic photon flux
        fPPF =  1000;   % [µmol/m^2s]
        
        % photoperiod
        fH =    16;     % [hours/day]
        
        %% Required Objects
        
        % LSS atmosphere phase
        oAtmosphereReference;
        
        % LSS water supply phase
        oWaterReference;
        
        % biomass manipulator object
        oCreateBiomass;
    end
    
    methods
        % constructor function
        function this = PlantModuleIMPROVED(oParent, sName, bGlobalLSS, bGlobalLighting)
            % call superconstructor
            % TODO: the ominous factor 60 for sec-min conversion, find out
            % what EXACTLY it does!
            this@vsys(oParent, sName, 60);

            eval(this.oRoot.oCfgParams.configCode(this));
            
            %% Load Plant Species Data File
            
            % Load plant setup from *.mat file
            % TODO: maybe take some other input instead of *.mat
            this.tPlantData = load(strrep(...
                'hocl\+marsone\+components\+PlantModule\+setups\PlantData_VhabCrops_Macro_80m2_staggered.mat', ...
                '\', ...   %PlantEng: Setup containing several plant cultures
                filesep));
            
            % load plant parameters into struct property
            this.tPlantParameters = ...
                components.PlantModule.PlantParameters();
            
            %% Global Variables
            
            % variable to define if dynamic atmosphere conditions of a
            % chosen reference phase are used (global = 1) or a static and 
            % predefined set of atmospheric parameters is used (global = 0)
            global bLSSConditions
            
            % variable to define if plant lighting conditions (PPF and H)
            % are globally valid for all grown species (global = 1) or if 
            % each species uses its own set of lighting conditions defined 
            % in the PlantEng.mat file (global = 0)
            global bGlobalLightingConditions
            
            bLSSConditions =            bGlobalLSS;
            bGlobalLightingConditions = bGlobalLighting;
            
        end
        
        function createMatterStructure(this)
            % call superconstructor
            createMatterStructure@vsys(this);
            
            %% Create Stores and Phases
            
            % create store
            matter.store(this, 'PlantCultivationStore', 40);
            
            
            % add phase to store; contains atmosphere, is connected with
            % the LSS atmosphere phase
            oAerationPhase = this.toStores.PlantCultivationStore.createPhase('air', 10);
            
            % add exmes to phase
            matter.procs.exmes.gas(oAerationPhase,  'Atmosphere_InFromLSS');    % atmosphere input from LSS 
            matter.procs.exmes.gas(oAerationPhase,  'Atmosphere_OutToLSS');     % atmosphere output to LSS
            matter.procs.exmes.gas(oAerationPhase,  'H2O_ExchangePlants');      % plant H2O exchange with atmosphere
            matter.procs.exmes.gas(oAerationPhase,  'O2_ExchangePlants');       % plant O2 exchange with atmosphere
            matter.procs.exmes.gas(oAerationPhase,  'CO2_ExchangePlants');      % plant CO2 exchange with atmosphere
            
            
            % add phase to store; contains plants, is used for plant gas 
            % exchange with the atmosphere, required water for plant growth
            % enters this phase and the biomass is also created in this
            % phase
            % TODO: this phase is all liquid, may conflict with gas
            % exchanges as everything happens at once, maybe split off the
            % exchange part to a separate phase, look into this later
            oPlants = matter.phases.liquid( ...
                this.toStores.PlantCultivationStore, ...    % store in which the phase is located
                'Plants', ...                               % phase name
                struct(...                                  % phase contents
                    'H2O', 0.1, ...
                    'CO2', 0.1, ...
                    'O2', 0.1), ...                            
                10, ...                                     % phase volume
                this.oParent.fTemperatureInit, ...          % phase temperature
                this.oParent.fPressureInit, ...             % phase pressure
                true);                                      % adsorber true
            
            % add exmes to phase
            matter.procs.exmes.liquid(oPlants, 'H2O_ExchangePlants');       % plant H2O exchange with atmosphere
            matter.procs.exmes.liquid(oPlants, 'O2_ExchangePlants');        % plant O2 exchange with atmosphere
            matter.procs.exmes.liquid(oPlants, 'CO2_ExchangePlants');       % plant CO2 exchange with atmosphere
            matter.procs.exmes.liquid(oPlants, 'H2O_InputWaterNeed');       % plant water input
            matter.procs.exmes.liquid(oPlants, 'Biomass_HarvestEdible');    % plant edible biomass to food phase
            matter.procs.exmes.liquid(oPlants, 'Biomass_HarvestInedible');  % plant inedible biomass to waste phase
            
            
            % add phase to store; harvested edible biomass is extracted
            % into this phase before leaving the module as food
            oBiomassEdible = matter.phases.liquid(...
                this.toStores.PlantCultivationStore, ...    % store in which the phase is located
                'BiomassEdible', ...                        % phase name
                struct(...                                  % phase contents
                    'Food', 0.1), ...      
                10, ...                                     % phase volume
                this.oParent.fTemperatureInit, ...          % phase temperature
                this.oParent.fPressureInit);                % phase pressure
            
            % add exmes to phase
            matter.procs.exmes.liquid(oBiomassEdible, 'Biomass_HarvestEdible'); % plant edible biomass from plant phase
            matter.procs.exmes.liquid(oBiomassEdible, 'Biomass_OutputEdible');  % plant edible biomass subsystem output
            
            
            % add phase to store; harvested inedible biomass is extracted
            % into this phase before leaving the module as waste
            oBiomassInedible = matter.phases.liquid(...
                this.toStores.PlantCultivationStore, ...    % store in which the phase is located
                'BiomassInedible', ...                      % phase name
                struct(...                                  % phase contents
                    'Waste', 0.1), ...                                    
                10, ...                                     % phase volume
                this.oParent.fTemperatureInit, ...          % phase temperature
                this.oParent.fPressureInit);                % phase pressure    
            
            % add exmes to phase       
            matter.procs.exmes.liquid(oBiomassInedible, 'Biomass_HarvestInedible'); % plant inedible biomass from plant phase
            matter.procs.exmes.liquid(oBiomassInedible, 'Biomass_OutputInedible');  % plant inedible biomass subsystem output
            
            %% Create Biomass Manipulator
            
            % Initializing manipulator for creating biomass and handling 
            % gas exchanges
            this.oCreateBiomass = ...         
                components.PlantModule.Create_Biomass(...    
                this, ...       
                'CreateBiomass', ...                % manipulator name    
                oPlants, ...                        % plants phase reference
                this.tPlantData, ...                % culture setups
                this.tPlantParameters, ...          % plant parameters
                this.fTemperatureLight, ...         % atmosphere temperature light [°C]
                this.fTemperatureDark, ...          % atmosphere temperature dark [°C]
                this.fRelativeHumidityLight, ...    % relative humidity light [-]
                this.fRelativeHumidityDark, ...     % relative humidity dark [-]
                this.fPressureAtmosphere, ...       % atmosphere pressure [Pa]
                this.fCO2ppm, ...                   % CO2 concentration [µmol/mol]
                this.fPPF, ...                      % photosynthetic photon flux [µmol/m^2s]
                this.fH, ...                        % photoperiod [h/d]
                this.fWaterAvailable);              % available water for plant growth [kg]                       
                
            %% Create Gas Exchange Processors
            
            % create three filter procs for H2O, O2 and CO2
            
            components.PlantModule.Set_Plants_H2OGasExchange(... 
                this.toStores.PlantCultivationStore, ...                % store of treated phases
                'H2O_ExchangePlants', ...                               % processor name
                'Plants.H2O_ExchangePlants', ...                        % input phase
                'PlantCultivationStore_Phase_1.H2O_ExchangePlants', ... % output phase
                this);                                                  % system reference
            
            components.PlantModule.Set_Plants_O2GasExchange(... 
                this.toStores.PlantCultivationStore, ...                % store of treated phases
                'O2_ExchangePlants', ...                                % processor name
                'Plants.O2_ExchangePlants', ...                         % input phase
                'PlantCultivationStore_Phase_1.O2_ExchangePlants', ...  % output phase
                this);                                                  % system reference
            
            components.PlantModule.Set_Plants_CO2GasExchange(... 
                this.toStores.PlantCultivationStore, ...                % store of treated phases
                'CO2_ExchangePlants', ...                               % processor name
                'Plants.CO2_ExchangePlants', ...                        % input phase
                'PlantCultivationStore_Phase_1.CO2_ExchangePlants', ... % output phase
                this);                                                  % system reference
            
            %% Create Harvest Processors
            
            % TODO: check if system reference is necessary
            
            components.PlantModule.Harvest_EdibleBiomass(... 
                this.toStores.PlantCultivationStore, ...        % store of treated phases
                'Biomass_HarvestEdible', ...                    % processor name
                'Plants.Biomass_HarvestEdible', ...             % input phase
                'BiomassEdible.Biomass_HarvestEdible' ...    % output phase
                );                                          % system reference 
            
            components.PlantModule.Harvest_InedibleBiomass(... 
                this.toStores.PlantCultivationStore, ...        % store of treated phases
                'Biomass_HarvestInedible', ...                  % processor name
                'Plants.Biomass_HarvestInedible', ...           % input phase
                'BiomassInedible.Biomass_HarvestInedible' ...  % output phase
                );                                          % system reference  
            
            %% Create Branches
            
            % atmosphere input from LSS
            matter.branch(this, 'PlantCultivationStore.Atmosphere_InFromLSS',   {}, 'Atmosphere_InFromLSS',     'AtmosphereInput');
            
            % atmosphere output to LSS
            matter.branch(this, 'PlantCultivationStore.Atmosphere_OutToLSS',    {}, 'Atmosphere_OutToLSS',      'AtmosphereOutput');
            
            % water input from water tank
            matter.branch(this, 'PlantCultivationStore.H2O_InputWaterNeed',     {}, 'H2O_InputWaterNeed',       'WaterInput');
            
            % food output to food storage
            matter.branch(this, 'PlantCultivationStore.Biomass_OutputEdible',   {}, 'Biomass_OutputEdible',     'FoodOutput');
            
            % waste output to waste storage
            matter.branch(this, 'PlantCultivationStore.Biomass_OutputInedible', {}, 'Biomass_OutputInedible',   'WasteOutput');
        end
        
        function createSolverStructure(this)
            % call superconstructor
            createSolverStructure@vsys(this);
            
            %% Add Branches to Solver
            
            solver.matter.manual.branch(this.toBranches.AtmosphereInput);
            solver.matter.manual.branch(this.toBranches.AtmosphereOutput);
            solver.matter.manual.branch(this.toBranches.WaterInput);
            solver.matter.manual.branch(this.toBranches.FoodOutput);
            solver.matter.manual.branch(this.toBranches.WasteOutput);
            
            %% Initialize Flowrates
            
            this.toBranches.AtmosphereInput.oHandler.setFlowRate(0);
            this.toBranches.AtmosphereOutput.oHandler.setFlowRate(0);
            this.toBranches.WaterInput.oHandler.setFlowRate(0);
            this.toBranches.FoodOutput.oHandler.setFlowRate(0);
            this.toBranches.WasteOutput.oHandler.setFlowRate(0);
        end
        
        %% Connect Subsystem Interfaces with Parent System
        
        function setIfFlows(this, sInterface1, sInterface2, sInterface3, sInterface4, sInterface5)
                this.connectIF('Atmosphere_InFromLSS',      sInterface1);
                this.connectIF('Atmosphere_OutToLSS',       sInterface2);
                this.connectIF('H2O_InputWaterNeed',        sInterface3);
                this.connectIF('Biomass_OutputEdible',      sInterface4);
                this.connectIF('Biomass_OutputInedible',    sInterface5);
        end
        
        %% Set Reference Phases
        
        % set path for reference phases to enable dynamic calculation, must
        % be called from the parent system with the correct paths
        function setReferencePhase(this, oAtmosphere, oWater)
            this.oAtmosphereReference   = oAtmosphere;
            this.oWaterReference        = oWater;
        end
    end
    
    methods (Access = protected)
        
        % update system
        function exec(this, ~)
            % call superconstructor
            exec@vsys(this);
            
            global bLSSConditions
            
            if this.oTimer.iTick > 0
                if bLSSConditions == 1
                    % CO2 level in atmosphere phase, parts per million. MEC 
                    % model is only valid for up to 1300 ppm, so CO2 
                    % concentration is capped at 1300 for calculation 
                    % purposes as plants do grow with a higher ppm value.
                    % Temporary solution only, CO2 should be kept within 
                    % allowed range by atmosphere regulation to keep 
                    % validity of model results.
                    if this.oParent.fCO2ppm_Measured > 1300
                        this.fCO2ppm = 1300;
                    else
                        this.fCO2ppm = this.oParent.fCO2ppm_Measured;  
                    end
                end
                
                % take humidity and pressure from referenced phase
                this.fRelativeHumidityLight     = this.oAtmosphereReference.rRelHumidity;
                this.fRelativeHumidityDark      = this.oAtmosphereReference.rRelHumidity;
                this.fPressureAtmosphere        = this.oAtmosphereReference.fPressure;

                % available water in referenced water tank
                this.fWaterAvailable = this.oWaterReference.fMass;
            
 
                % Setting gas/water exchange rates:  LSS <-> PlantModule
                
                % atmosphere input from LSS
                this.toBranches.AtmosphereInput.oHandler.setFlowRate(-0.5);  
                
                % atmosphere output to LSS plus plant gas exchange
                this.toBranches.AtmosphereOutput.oHandler.setFlowRate(0.5 + ...
                    this.toStores.PlantCultivationStore.toProcsP2P.H2O_ExchangePlants.fFlowRate + ...
                    this.toStores.PlantCultivationStore.toProcsP2P.O2_ExchangePlants.fFlowRate - ...
                    this.toStores.PlantCultivationStore.toProcsP2P.CO2_ExchangePlants.fFlowRate);
                
                % water input from LSS water tank
                this.toBranches.WaterInput.oHandler.setFlowRate(-this.oCreateBiomass.fWaterNeed);  
                
                
                % Harvesting - Produced biomass in PlantModule is extracted 
                % to biomass stores (food/waste) located in the connected 
                % LSS main system
                
                % Edible Biomass to LSS food storage
                if this.toStores.PlantCultivationStore.aoPhases(1, 3).fMass > 0.1
                    this.toBranches.FoodOutput.oHandler.setFlowRate(0.01);
                else
                    this.toBranches.FoodOutput.oHandler.setFlowRate(0);
                end
                   
                % Inedible Biomass to LSS waste storage
                if this.toStores.PlantCultivationStore.aoPhases(1, 4).fMass > 0.1
                    this.toBranches.WasteOutput.oHandler.setFlowRate(0.01);
                else
                    this.toBranches.WasteOutput.oHandler.setFlowRate(0);
                end
            end
        end
    end
end