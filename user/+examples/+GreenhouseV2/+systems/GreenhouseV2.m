classdef GreenhouseV2 < vsys
    properties
        % Concentration of CO2 in PPM
        fCO2 = 330; %PPM
        
        % Cell array containing the names of all plant cultures
        csCultures;
        
        % Maximum Time Step allowed for this system
        fMaxTimeStep = 3600;
    end
    
    methods
        function this = GreenhouseV2(oParent, sName)
            this@vsys(oParent, sName, 3600);
            
            %% Set Culture Setup Inputs
            
            % Custom name you want to give this specific culture, select a 
            % name that is easy for you to identify
            tInput(1).sCultureName     = 'MyLettuceCulture';
            % Name of the plant species, has to fit the names defined in 
            % lib/+components/*PlantModuleV2/+plantparameters/PlantParameters.csv
            tInput(1).sPlantSpecies    = 'Lettuce';
            % The growth area defines how many plants are used in the
            % culture. Please note that depending on your application you
            % have to set the area to represent the number of plants (see
            % the plant density parameter in lib/+components/*PlantModuleV2/+plantparameters/PlantParameters.csv
            % for information on that parameter) and not the actual area.
            % The area depends on the density of plants and can vary by
            % some degree! (for very high density shadowing effects will
            % come into effect)
            tInput(1).fGrowthArea      = 5; % m^2
            % time after which the plants are harvested
            tInput(1).fHarvestTime     = 30; % days
            % The time after which the first part of the plant can be seen
            tInput(1).fEmergeTime      = 0; % days
            % Particle Photon Flux Density, which is ony value to define
            % the intensity of the light the plants receive
            tInput(1).fPPFD            = 330; % micromol/m^2s
            % Photoperiod in hours (time per day that the plants receive
            % light)
            tInput(1).fPhotoperiod     = 17; % h
            % This parameter defines how many generations of this culture
            % are planted in succession
            tInput(1).iConsecutiveGenerations      = 5;
            
            % Additional cultures can be added here by adding more fields
            % to the tInput struct (because we loop over them below).
            % Otherwise you can simply create individual input structs and
            % define the PlantCulture.m multiple times without a loop
            tInput(2).sCultureName     = 'MySweetpotatoCulture';
            tInput(2).sPlantSpecies    = 'Sweetpotato';
            tInput(2).fGrowthArea      = 5; % m^2
            tInput(2).fHarvestTime     = 120; % days
            tInput(2).fEmergeTime      = 0; % days
            tInput(2).fPPFD            = 330; % micromol/m^2s
            tInput(2).fPhotoperiod     = 17; % h
            tInput(2).iConsecutiveGenerations      = 5;
            
            %% Create Culture Objects
            
            % loop over total cultures amount
            for iCulture = 1:length(tInput)
                components.PlantModuleV2.PlantCulture(...
                        this, ...                   % parent system reference
                        tInput(iCulture), ...       % input for specific culture
                        this.fTimeStep);            % Time step initially used for this culture in [s]
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
            matter.store(this, 'Atmosphere', 200);
            
            % this.toStores.Atmosphere.bPreventVolumeOverwrite = true;
            oAtmosphere = this.toStores.Atmosphere.createPhase('air', 200, 293.15, 0.5, 101325);
            
            % Go through the children and set the reference atmosphere for
            % the plants
            csPlantCultures = {};
            for iChild = 1:length(this.csChildren)
                % culture object gets assigned using its culture name 
                if isa(this.toChildren.(this.csChildren{iChild}), 'components.PlantModuleV2.PlantCulture')
                    this.toChildren.(this.csChildren{iChild}).setReferenceAtmosphere(oAtmosphere);
                    csPlantCultures{length(csPlantCultures)+1} = this.csChildren{iChild};
                end
            end
            this.csCultures = csPlantCultures;
            
            matter.procs.exmes.gas(oAtmosphere, 'WaterAbsorber_P2P_Out');
            
            %% Water Supply
            
            matter.store(this, 'WaterSupply', 100e3);
            
            oWaterSupply = matter.phases.liquid(...
                this.toStores.WaterSupply, ...      % store containing phase
                'WaterSupply', ...                  % phase name
                struct(...                          % phase contents    [kg]
                    'H2O', 100e3), ...
                fTemperatureInit, ...               % phase temperature [K]
                fPressureInit);                     % phase pressure    [Pa]
                       
            %% Nutrient Supply
            
            matter.store(this, 'NutrientSupply', 20);
            
            oNutrientSupply = matter.phases.liquid(...
                this.toStores.NutrientSupply, ...   % store containing phase
                'NutrientSupply', ...               % phase name
                struct(...                          % phase contens     [kg]
                    'Nutrients', 1e3), ...
                fTemperatureInit, ...               % phase temperature [K]
                fPressureInit);                     % phase pressure    [Pa]
            
            %% Biomass Edible/Inedible Split Buffer
            
            matter.store(this, 'BiomassSplit', 4);
            
            oBiomassEdibleSplit = matter.phases.liquid(...
                this.toStores.BiomassSplit, ...     % store containing phase
                'BiomassEdible', ...                % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                fTemperatureInit, ...               % phase temperature [K]
                101325);
            
            matter.procs.exmes.liquid(oBiomassEdibleSplit, 'BiomassEdible_Out_ToStorage');
            matter.procs.exmes.liquid(oBiomassEdibleSplit, 'EdibleInedible_Split_P2P_Out');
            
            oBiomassInedibleSplit = matter.phases.liquid(...
                this.toStores.BiomassSplit, ...     % store containing phase
                'BiomassInedible', ...              % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
                fTemperatureInit, ...               % phase temperature [K]
                101325);

            matter.procs.exmes.liquid(oBiomassInedibleSplit, 'BiomassInedible_Out_ToStorage');
            matter.procs.exmes.liquid(oBiomassInedibleSplit, 'EdibleInedible_Split_P2P_In');
            
            %% Biomass Storage
            
            matter.store(this, 'BiomassEdible', 20);
            
            oBiomassEdible = matter.phases.liquid(...
                this.toStores.BiomassEdible, ...    % store containing phase
                'BiomassEdible', ...                % phase name
                struct(...                          % phase contents    [kg]
                    'CabbageEdibleWet', 5, ...
                    'StrawberryEdibleWet', 3), ...
                fTemperatureInit, ...               % phase temperature [K]
                101325);
            
            matter.procs.exmes.liquid(oBiomassEdible, 'BiomassEdible_In_FromSplit');
            
            matter.store(this, 'BiomassInedible', 20);
            
            oBiomassInedible = matter.phases.liquid(...
                this.toStores.BiomassInedible, ...  % store containing phase
                'BiomassInedible', ...              % phase name
                struct(...                          % phase contents    [kg]
                    ), ...
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
                'N2', 1e-3,...
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
            matter.store(this, 'N2BufferSupply', 20e3);
            
            % add phase to N2 buffer store
            oN2BufferSupply = matter.phases.gas(...
                this.toStores.N2BufferSupply, ...       % store containing phase
                'N2BufferSupply', ...                   % phase name
                struct(...                              % phase contents    [kg]
                    'N2', 20e3), ...
                20e3, ...                                % phase volume      [m^3]
                fTemperatureInit);                      % phase temperature [K]
                
            % add exmes
            matter.procs.exmes.gas(oN2BufferSupply, 'N2_Out_ToAtmosphere');
            matter.procs.exmes.gas(oAtmosphere, 'N2_In_FromBuffer');
            
            
            % add CO2 buffer store
            matter.store(this, 'CO2BufferSupply', 20e3);
            
            % add phase to N2 buffer store
            oCO2BufferSupply = matter.phases.gas(...
                this.toStores.CO2BufferSupply, ...      % store containing phase
                'CO2BufferSupply', ...                  % phase name
                struct(...                              % phase contents    [kg]
                    'CO2', 20e3), ...
                20e3, ...                                % phase volume      [m^3]
                fTemperatureInit);                      % phase temperature [K]
                
            % add exmes
            matter.procs.exmes.gas(oCO2BufferSupply, 'CO2_Out_ToAtmosphere');
            matter.procs.exmes.gas(oAtmosphere, 'CO2_In_FromBuffer');
            
            
            % add O2 buffer Store
             matter.store(this, 'O2BufferSupply', 20e3);
            
            % add phase to N2 buffer store
            oO2BufferSupply = matter.phases.gas(...
                this.toStores.O2BufferSupply, ...       % store containing phase
                'O2BufferSupply', ...                   % phase name
                struct(...                              % phase contents    [kg]
                    'O2', 20e3), ...
                20e3, ...                                % phase volume      [m^3]
                fTemperatureInit);                      % phase temperature [K]
                
            % add exmes
            matter.procs.exmes.gas(oO2BufferSupply, 'O2_Out_ToAtmosphere');
            matter.procs.exmes.gas(oAtmosphere, 'O2_In_FromBuffer');
            
            
            % add water separator store
            % matter.store(this, 'WaterSeparator', 5);
           
            % add water phase to water separator
            oWaterWS = matter.phases.liquid(...
              	this.toStores.Atmosphere, ...       % store containing phase
                'WaterWS', ...                          % phase name
                struct(...                              % phase contents    [kg]
                    'H2O', 10), ...
                fTemperatureInit, ...                   % phase temperature [K]
                fPressureInit);                         % phase pressure    [Pa]
           
            % add exmes
            
            % water absorber exmes
            matter.procs.exmes.liquid(oWaterWS, 'WaterAbsorber_P2P_In');
            
            % add O2 an CO2 excess phases and exmes to atmosphere store 
            oExcessO2 = matter.phases.gas(...
                this.toStores.Atmosphere, ...       % store containing phase
                'ExcessO2', ...                     % phase name
                struct(...                          % phase contents    [kg]
                    'O2', 20), ...
                200, ...                            % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            matter.procs.exmes.gas(oExcessO2, 'ExcessO2_P2P_In');
            matter.procs.exmes.gas(oAtmosphere, 'ExcessO2_P2P_Out');
            
            oExcessCO2 = matter.phases.gas(...
                this.toStores.Atmosphere, ...       % store containing phase
                'ExcessCO2', ...                    % phase name
                struct(...                          % phase contents    [kg]
                    'CO2', 20), ...
                200, ...                            % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            matter.procs.exmes.gas(oExcessCO2, 'ExcessCO2_P2P_In');
            matter.procs.exmes.gas(oAtmosphere, 'ExcessCO2_P2P_Out');
            
            % add excess extraction p2ps
            components.P2Ps.ManualP2P(...
                this, ...                                   % parent system reference
                this.toStores.Atmosphere, ...               % store containing phases
                'ExcessO2_P2P', ...                         % p2p processor name
                'Atmosphere_Phase_1.ExcessO2_P2P_Out', ... 	% first phase and exme
                'ExcessO2.ExcessO2_P2P_In');               	% second phase and exme
                
            components.P2Ps.ManualP2P(...
                this, ...                                   % parent system reference
                this.toStores.Atmosphere, ...               % store containing phases
                'ExcessCO2_P2P', ...                        % p2p processor name
                'Atmosphere_Phase_1.ExcessCO2_P2P_Out', ...	% first phase and exme
                'ExcessCO2.ExcessCO2_P2P_In');             	% second phase and exme
                        
            components.P2Ps.ManualP2P(...
                this, ...                                   % parent system reference
                this.toStores.Atmosphere, ...               % store containing phases
                'WaterAbsorber_P2P', ...                 	% p2p processor name
                'Atmosphere_Phase_1.WaterAbsorber_P2P_Out', ...	% first phase and exme
                'WaterWS.WaterAbsorber_P2P_In');           	% second phase and exme
            

            % create branches exclusive to this section
            matter.branch(this, 'N2BufferSupply.N2_Out_ToAtmosphere',           {}, 'Atmosphere.N2_In_FromBuffer',                  'N2BufferSupply');
            matter.branch(this, 'CO2BufferSupply.CO2_Out_ToAtmosphere',         {}, 'Atmosphere.CO2_In_FromBuffer',                 'CO2BufferSupply');
            matter.branch(this, 'O2BufferSupply.O2_Out_ToAtmosphere',           {}, 'Atmosphere.O2_In_FromBuffer',                  'O2BufferSupply');
            % matter.branch(this, 'Atmosphere.WaterAbsorber_P2P',                 {}, 'WaterSeparator.WaterAbsorber_P2P',             'WaterAbsorber',    true);
       
            
            %% Create EXMEs for Culture Connections
            
            csInedibleBiomass = cell(1, length(csPlantCultures));
            
            % loop over all cultures to create each required exmes 
            for iI = 1:length(csPlantCultures)
                % subsystem interfaces
                matter.procs.exmes.gas(oAtmosphere,             [this.toChildren.(csPlantCultures{iI}).sName, '_AtmosphereCirculation_Out']);
                matter.procs.exmes.gas(oAtmosphere,             [this.toChildren.(csPlantCultures{iI}).sName, '_AtmosphereCirculation_In']);
                matter.procs.exmes.liquid(oWaterSupply,         [this.toChildren.(csPlantCultures{iI}).sName, '_WaterSupply_Out']);
                matter.procs.exmes.liquid(oNutrientSupply,      [this.toChildren.(csPlantCultures{iI}).sName, '_NutrientSupply_Out']);
                matter.procs.exmes.liquid(oBiomassEdibleSplit,  [this.toChildren.(csPlantCultures{iI}).sName, '_Biomass_In']);
                
                csInedibleBiomass{iI} = [this.toChildren.(csPlantCultures{iI}).txPlantParameters.sPlantSpecies, 'InedibleWet'];
            end
            
            %% Create Biomass Split P2P
            
            oConstantP2P = components.P2Ps.ConstantMassP2P(this, ...
                this.toStores.BiomassSplit, ...
                'EdibleInedible_Split_P2P', ...
                'BiomassEdible.EdibleInedible_Split_P2P_Out', ...
                'BiomassInedible.EdibleInedible_Split_P2P_In',...
                csInedibleBiomass, 1);
            
            oConstantP2P.fTimeStep = 3600;
            %% Create Branches
            
            % create leakage branch
            matter.branch(this, 'Atmosphere.Leakage_Out_ToBuffer', {}, 'LeakageBuffer.Leakage_In_FromAtmosphere', 'Leakage');
            
            % create edible and inedible biomass branch from split buffer
            % to storage tanks
            matter.branch(this, 'BiomassSplit.BiomassEdible_Out_ToStorage',     {}, 'BiomassEdible.BiomassEdible_In_FromSplit',     'SplitToEdible');
            matter.branch(this, 'BiomassSplit.BiomassInedible_Out_ToStorage',   {}, 'BiomassInedible.BiomassInedible_In_FromSplit', 'SplitToInedible');
            
            % create subsystem branches, 5 per culture object
            for  iI = 1:length(csPlantCultures)
                matter.branch(this, [this.toChildren.(csPlantCultures{iI}).sName, '_Atmosphere_ToIF_Out'],      {}, ['Atmosphere.',     this.toChildren.(csPlantCultures{iI}).sName, '_AtmosphereCirculation_Out'],     [this.toChildren.(csPlantCultures{iI}).sName, '_Atmosphere_Circulation_In']);
                matter.branch(this, [this.toChildren.(csPlantCultures{iI}).sName, '_Atmosphere_FromIF_In'],     {}, ['Atmosphere.',     this.toChildren.(csPlantCultures{iI}).sName, '_AtmosphereCirculation_In'],      [this.toChildren.(csPlantCultures{iI}).sName, '_Atmosphere_Circulation_Out']);
                matter.branch(this, [this.toChildren.(csPlantCultures{iI}).sName, '_WaterSupply_ToIF_Out'],     {}, ['WaterSupply.',    this.toChildren.(csPlantCultures{iI}).sName, '_WaterSupply_Out'],               [this.toChildren.(csPlantCultures{iI}).sName, '_WaterSupply']);
                matter.branch(this, [this.toChildren.(csPlantCultures{iI}).sName, '_NutrientSupply_ToIF_Out'],  {}, ['NutrientSupply.', this.toChildren.(csPlantCultures{iI}).sName, '_NutrientSupply_Out'],            [this.toChildren.(csPlantCultures{iI}).sName, '_NutrientSupply']);
                matter.branch(this, [this.toChildren.(csPlantCultures{iI}).sName, '_Biomass_FromIF_In'],        {}, ['BiomassSplit.',   this.toChildren.(csPlantCultures{iI}).sName, '_Biomass_In'],                    [this.toChildren.(csPlantCultures{iI}).sName, '_BiomassOut']);
            end
            
            %% Connect Interfaces
            
            for iI = 1:length(csPlantCultures)
                this.toChildren.(csPlantCultures{iI}).setIfFlows(...
                    [this.toChildren.(csPlantCultures{iI}).sName, '_Atmosphere_ToIF_Out'], ...
                    [this.toChildren.(csPlantCultures{iI}).sName ,'_Atmosphere_FromIF_In'], ...
                    [this.toChildren.(csPlantCultures{iI}).sName ,'_WaterSupply_ToIF_Out'], ...
                    [this.toChildren.(csPlantCultures{iI}).sName ,'_NutrientSupply_ToIF_Out'], ...
                    [this.toChildren.(csPlantCultures{iI}).sName ,'_Biomass_FromIF_In']);
            end
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % comment if commented atmosphere CC in createMatterStructure 
            
            solver.matter.manual.branch(this.toBranches.N2BufferSupply);
            solver.matter.manual.branch(this.toBranches.CO2BufferSupply);
            solver.matter.manual.branch(this.toBranches.O2BufferSupply);
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            solver.matter.manual.branch(this.toBranches.Leakage);
            solver.matter.manual.branch(this.toBranches.SplitToEdible);
            solver.matter.manual.branch(this.toBranches.SplitToInedible);
            
            this.toBranches.Leakage.oHandler.setFlowRate(1e-5);

            tTimeStepProperties.fMaxStep = this.fTimeStep;
                    
            % set time steps
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    oPhase.setTimeStepProperties(tTimeStepProperties);
                    this.toStores.(csStoreNames{iStore}).fDefaultTimeStep = this.fTimeStep;
                end
            end

            arMaxChange = zeros(1,this.oMT.iSubstances);
            arMaxChange(this.oMT.tiN2I.H2O) = 0.05;
            arMaxChange(this.oMT.tiN2I.CO2) = 0.05;
            arMaxChange(this.oMT.tiN2I.O2)  = 0.05;
            arMaxChange(this.oMT.tiN2I.N2)  = 0.05;
            tTimeStepProperties.arMaxChange = arMaxChange;
            
            this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.setTimeStepProperties(tTimeStepProperties);

            this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.bind('massupdate_post',@(~)this.update());
            
            this.setThermalSolvers();
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
%         function this = addCulture(this, sCultureName, sPlantSpecies, fGrowthArea, fEmergeTime, iConsecutiveGenerations, fHarvestTime, fPPFD, fH)
%         end

        function update(this)
            
            % Atmosphere controllers required for standalone greenhouse. If
            % atmosphere control managed by other (sub)systems comment this
            % section
            if ~this.oTimer.fTime
                return;
            end
            %this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.update();
             
            fNominalCondensateFlow = 0;
            fNominalO2Flow = 0;
            fNominalCO2Flow = 0;
            
            % Positive Values are outflows out fo the plants
            for iCulture = 1:length(this.csCultures)
                fNominalO2Flow          = fNominalO2Flow            + this.toChildren.(this.csCultures{iCulture}).tfGasExchangeRates.fO2ExchangeRate;
                fNominalCO2Flow         = fNominalCO2Flow           + this.toChildren.(this.csCultures{iCulture}).tfGasExchangeRates.fCO2ExchangeRate;
                fNominalCondensateFlow  = fNominalCondensateFlow    + this.toChildren.(this.csCultures{iCulture}).tfGasExchangeRates.fTranspirationRate;
            end
            fH2O_Leakage = this.toBranches.Leakage.fFlowRate * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.arPartialMass(this.oMT.tiN2I.H2O);
            fCO2_Leakage = this.toBranches.Leakage.fFlowRate * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.arPartialMass(this.oMT.tiN2I.CO2);
            %fO2_Leakage  = this.toBranches.Leakage.fFlowRate * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.arPartialMass(this.oMT.tiN2I.O2);
            fN2_Leakage  = this.toBranches.Leakage.fFlowRate * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.arPartialMass(this.oMT.tiN2I.N2);
            
            %% Decide on the time step:
            fPartialPressureO2  = this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afPP(this.oMT.tiN2I.O2);
            fCO2_Concentration  = this.CalculateCO2Concentration();
            this.fCO2           = fCO2_Concentration;
            fRelativeHumidity   = this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.rRelHumidity;
            fPressure           = this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fPressure;
            
            % TBD: Well its just an example system with stupid unrealistic
            % controllers :)
            if (fRelativeHumidity > 0.85) || (fPartialPressureO2 > 23000) || (fCO2_Concentration > 2500)
                this.setTimeStep(this.fMaxTimeStep/100);
            elseif (fRelativeHumidity > 0.7) || (fPartialPressureO2 > 22500) || (fCO2_Concentration > 1500)
                this.setTimeStep(this.fMaxTimeStep/10);
            elseif (fRelativeHumidity < 0.25) || (fPartialPressureO2 < 18000) || (fCO2_Concentration < 150) || (fPressure < 7e4)
                this.setTimeStep(this.fMaxTimeStep/100);
            elseif (fRelativeHumidity < 0.45) || (fPartialPressureO2 < 19000) || (fCO2_Concentration < 300) || (fPressure < 9e4)
                this.setTimeStep(this.fMaxTimeStep/10);
            else
                this.setTimeStep(this.fMaxTimeStep);
            end
            
            %% O2 Controller
            fNominalO2Flow = abs(fNominalO2Flow);
            if fPartialPressureO2 <= 19500
                this.toStores.Atmosphere.toProcsP2P.ExcessO2_P2P.setFlowRate(zeros(1,this.oMT.iSubstances));
                this.toBranches.O2BufferSupply.oHandler.setFlowRate(((1e-2 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMass) / this.fTimeStep) + fNominalO2Flow);

            elseif fPartialPressureO2 > 23000
                afFlowRate = zeros(1,this.oMT.iSubstances);
                afFlowRate(this.oMT.tiN2I.O2) = 2 * fNominalO2Flow + ((1e-2 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afMass(this.oMT.tiN2I.O2)) / this.fTimeStep);
                this.toStores.Atmosphere.toProcsP2P.ExcessO2_P2P.setFlowRate(afFlowRate);
                this.toBranches.O2BufferSupply.oHandler.setFlowRate(0);

            elseif fPartialPressureO2 > 22000
                afFlowRate = zeros(1,this.oMT.iSubstances);
                afFlowRate(this.oMT.tiN2I.O2) = 2 * fNominalO2Flow;
                this.toStores.Atmosphere.toProcsP2P.ExcessO2_P2P.setFlowRate(afFlowRate);
                this.toBranches.O2BufferSupply.oHandler.setFlowRate(0);
                
            else
                afFlowRate = zeros(1,this.oMT.iSubstances);
                afFlowRate(this.oMT.tiN2I.O2) = fNominalO2Flow;
                this.toStores.Atmosphere.toProcsP2P.ExcessO2_P2P.setFlowRate(afFlowRate);
                this.toBranches.O2BufferSupply.oHandler.setFlowRate(0);
            end
            
            %% CO2 Controller
            fNominalCO2Flow = abs(fNominalCO2Flow) + fCO2_Leakage;
            if fCO2_Concentration >= 3000
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0);
                afFlowRate = zeros(1,this.oMT.iSubstances);
                afFlowRate(this.oMT.tiN2I.CO2) = ((1e-1 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afMass(this.oMT.tiN2I.CO2)) / this.fTimeStep);
                this.toStores.Atmosphere.toProcsP2P.ExcessCO2_P2P.setFlowRate(afFlowRate);
                
            elseif fCO2_Concentration > 2500
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate(0);
                afFlowRate = zeros(1,this.oMT.iSubstances);
                afFlowRate(this.oMT.tiN2I.CO2) = ((1e-2 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afMass(this.oMT.tiN2I.CO2)) / this.fTimeStep);
                this.toStores.Atmosphere.toProcsP2P.ExcessCO2_P2P.setFlowRate(afFlowRate);
                
            elseif fCO2_Concentration < 150
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate( ((1e-3 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMass) / this.fTimeStep) + 2 * fNominalCO2Flow);
                this.toStores.Atmosphere.toProcsP2P.ExcessCO2_P2P.setFlowRate(zeros(1,this.oMT.iSubstances));
                
            elseif fCO2_Concentration < 330
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate( ((1e-4 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMass) / this.fTimeStep) + 2 * fNominalCO2Flow);
                this.toStores.Atmosphere.toProcsP2P.ExcessCO2_P2P.setFlowRate(zeros(1,this.oMT.iSubstances));
                            
            elseif fCO2_Concentration < 1300
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate( fNominalCO2Flow );
                this.toStores.Atmosphere.toProcsP2P.ExcessCO2_P2P.setFlowRate(zeros(1,this.oMT.iSubstances));
                
            else
                this.toBranches.CO2BufferSupply.oHandler.setFlowRate( 0 );
                afFlowRate = zeros(1,this.oMT.iSubstances);
                afFlowRate(this.oMT.tiN2I.CO2) = ((1e-3 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afMass(this.oMT.tiN2I.CO2)) / this.fTimeStep + fNominalCO2Flow);
                this.toStores.Atmosphere.toProcsP2P.ExcessCO2_P2P.setFlowRate(afFlowRate);
                
            end
            
            %% Humidity Controller
            fNominalCondensateFlow = abs(fNominalCondensateFlow) + fH2O_Leakage;
            
            fPreviousCondensateFlow = this.toStores.Atmosphere.toProcsP2P.WaterAbsorber_P2P.fFlowRate;

            if fPreviousCondensateFlow == 0 || (fRelativeHumidity > 0.6 && fPreviousCondensateFlow < fNominalCondensateFlow) || (fRelativeHumidity < 0.5 && fPreviousCondensateFlow > fNominalCondensateFlow)
                fPreviousCondensateFlow = fNominalCondensateFlow;
            end
            if fRelativeHumidity >= 0.85
                fCondensateFlow = 0.25 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afMass(this.oMT.tiN2I.H2O) / this.fTimeStep;
                
            elseif fRelativeHumidity >= 0.75
                fCondensateFlow = 1.1 * fPreviousCondensateFlow;
                
            elseif fRelativeHumidity > 0.6
                fCondensateFlow = 1.01 * fPreviousCondensateFlow;
                
            elseif fRelativeHumidity < 0.4
                if this.toStores.Atmosphere.toPhases.WaterWS.fMass > (1/3600 * this.fTimeStep)
                    fCondensateFlow = - 1/3600;
                else
                    fCondensateFlow = 0;
                end
            elseif fRelativeHumidity < 0.5
                fCondensateFlow = 0.9 * fPreviousCondensateFlow;
                
            else
                fCondensateFlow = fNominalCondensateFlow;
            end
            
            afFlowRate = zeros(1,this.oMT.iSubstances);
            afFlowRate(this.oMT.tiN2I.H2O) = fCondensateFlow;
            this.toStores.Atmosphere.toProcsP2P.WaterAbsorber_P2P.setFlowRate(afFlowRate);


            % In case the plant module results in mass errors for you try
            % outcommenting this function, it should help with debugging ;)
            % tools.findMassBalanceErrors(this.oMT, 1e-20);
            
            %% Pressure Controller
            if fPressure < 7e4
                this.toBranches.N2BufferSupply.oHandler.setFlowRate( 20 / this.fTimeStep);
                
            elseif fPressure < 9e4
                this.toBranches.N2BufferSupply.oHandler.setFlowRate( (1e-1 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMass / this.fTimeStep) + fNominalCondensateFlow + fNominalO2Flow + fNominalCO2Flow);
                
          	elseif fPressure < 1e5
                this.toBranches.N2BufferSupply.oHandler.setFlowRate(((1e-2 * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMass) / this.fTimeStep) + fNominalCondensateFlow + fNominalO2Flow + fNominalCO2Flow);
               
            else
                this.toBranches.N2BufferSupply.oHandler.setFlowRate(fN2_Leakage);
            end
            %% Split to Storage
            
%             if this.toStores.BiomassSplit.toPhases.BiomassEdible.fMass > 0
%             end
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
                        
            % as a second layer of check to prevent the mass from changing
            % to rapidly here the mass will be predicted and in case it
            % changes too rapidly the update frequency will be reduced
            afPredictedMass = this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afMass + (this.fTimeStep * this.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.afCurrentTotalInOuts);
            
            if any(afPredictedMass < 0)
                this.setTimeStep(this.fTimeStep/10);
                this.update();
            else
                this.update();
            end
            
            % In order to resynchronize the phase update ticks we update
            % all of them in the exec
            for iStore = 1:length(this.csStores)
                for iPhase = 1:this.toStores.(this.csStores{iStore}).iPhases
                    this.toStores.(this.csStores{iStore}).aoPhases(iPhase).registerUpdate();
                end
            end
        end
    end 
end