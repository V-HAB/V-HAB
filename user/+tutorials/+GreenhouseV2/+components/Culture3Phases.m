classdef Culture3Phases < vsys
    % This class is used in creating the culture objects. It provides the
    % phase for plant growth, adds a p2p processor which is automatically 
    % connected to biomass buffer store, two exmes and corresponding p2p 
    % processors which are automatically connected to the edible and 
    % inedible biomass phases and a manipulator to convert the incoming 
    % biomass into the culture's specific one. It also contains specific
    % plant data depending on the species grown.
    
    properties 
        % struct containing plant parameters specific to the grown culture, 
        % from parent system
        txPlantParameters;
        
        % save input parameters, they need to be requested
        txInput;
        
        % struct containing the 8 parameters calculated via the (M)MEC and
        % FAO model equations. written by PlantGrowth() call in parent
        % system's exec() function.
        tfMMECRates = struct();     % [kg s^-1]
        
        % internal time of plant culture (passed time AFTER planting)
        fInternalTime = 0;          % [s]
        
        % TODO: maybe later implement some kind of decay mechanic, already 
        % using a placeholder for it here.
        % using numbers instead of strings for quicker and easier access
        % state of culture: 1 = growth, 2 = harvest, 3 = decay, 4 = fallow
        % default is fallow
        iState = 4;
        
        % internal generation counter, start at 1
        iInternalGeneration = 1;
        
        %
        fCO2 = 330;
        
        %
        bLight = 1;
        
        % 
        fLightTimeFlag = 0;  
    end
    
    properties
        %% Culture Mass Transfer Rates
        
        % culture gas exchange with atmosphere (O2, CO2, H2O)
        tfGasExchangeRates = struct();      % [kg s^-1]
        
        % culture water consumption
        fWaterConsumptionRate = 0;          % [kg s^-1]
        
        % culture nutrient consumption
        fNutrientConsumptionRate = 0;       % [kg s^-1]
        
        % culture biomass growth (edible and inedible, both wet)
        tfBiomassGrowthRates = struct();    % [kg s^-1]
    end
    
    methods
        function this = Culture3Phases(oParent, txPlantParameters, txInput, fUpdateFrequency)
            this@vsys(oParent, txInput.sCultureName, fUpdateFrequency);
            
            this.txPlantParameters = txPlantParameters;
            this.txInput = txInput;
            
            % intialize empty structs
            this.tfGasExchangeRates.fO2ExchangeRate = 0;
            this.tfGasExchangeRates.fCO2ExchangeRate = 0;
            this.tfGasExchangeRates.fTranspirationRate = 0;
            
            this.tfBiomassGrowthRates.fGrowthRateEdible = 0;
            this.tfBiomassGrowthRates.fGrowthRateInedible = 0;
        
            this.tfMMECRates.fWC = 0;
            this.tfMMECRates.fTR = 0;
            this.tfMMECRates.fOC = 0;
            this.tfMMECRates.fOP = 0;
            this.tfMMECRates.fCO2C = 0;
            this.tfMMECRates.fCO2P = 0;
            this.tfMMECRates.fNC = 0;
            this.tfMMECRates.fCGR = 0;
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %% Create Store, Phases and Processors
            
            % write helper for standard plant atmosphere later
            fVolumeAirCirculation = 1;
            
            matter.store(this, this.txInput.sCultureName, 20);
            
            oAtmosphere = this.toStores.(this.txInput.sCultureName).createPhase('air', fVolumeAirCirculation, 293.15, 0.5, 101325);
            
%             oAtmosphere = matter.phases.gas(...
%                 this.toStores.(this.txInput.sCultureName), ...          % store containing phase
%                 [this.txInput.sCultureName, '_Atmosphere'], ...         % phase name 
%                 struct(...                                              % phase contents    [kg]
%                     'N2', 0.79 * fVolumeAirCirculation * 1e-3, ...
%                     'O2', 0.21 * fVolumeAirCirculation * 1e-3), ...
%                 fVolumeAirCirculation, ...                              % ignored volume    [m^3]
%                 293.15);                                                % phase temperature [K]
            
            matter.procs.exmes.gas(oAtmosphere, [this.txInput.sCultureName, '_AtmosphereCirculation_In']);
            matter.procs.exmes.gas(oAtmosphere, [this.txInput.sCultureName, '_AtmosphereCirculation_Out']);
            
            matter.procs.exmes.gas(oAtmosphere, [this.txInput.sCultureName, '_GasExchange_P2P']);
            
            oPlants = matter.phases.liquid(...
                this.toStores.(this.txInput.sCultureName), ...          % store containing phase
                [this.txInput.sCultureName, '_Plants'], ...             % phase name 
                struct(...                                              % phase contents    [kg]
                    ), ...
                19 - fVolumeAirCirculation, ...                         % ignored volume    [m^3]
                293.15, ...                                             % phase temperature [K]
                101325);                                                
            
            matter.procs.exmes.liquid(oPlants, [this.txInput.sCultureName, '_BiomassGrowth_P2P'])
            matter.procs.exmes.liquid(oPlants, [this.txInput.sCultureName, '_Biomass_Out']); 
            
            oBalance = matter.phases.liquid(...
                this.toStores.(this.txInput.sCultureName), ...          % store containing phase
                [this.txInput.sCultureName, '_Balance'], ...            % phase name 
                struct(...                                              % phase contents    [kg]
                    'BiomassBalance', 5), ...
                1, ...                                                  % ignored volume    [m^3]
                293.15, ...                                             % phase temperature [K]
                101325);
            
            matter.procs.exmes.liquid(oBalance, [this.txInput.sCultureName, '_BiomassGrowth_P2P'])
            matter.procs.exmes.liquid(oBalance, [this.txInput.sCultureName, '_WaterSupply_In']);
            matter.procs.exmes.liquid(oBalance, [this.txInput.sCultureName, '_NutrientSupply_In']);
             
            matter.procs.exmes.liquid(oBalance, [this.txInput.sCultureName, '_GasExchange_P2P']);
            
            %% Create Gas Exchange P2P Processor
            
            % p2p for simulation of gas exchange (O2, CO2, H2O)
            tutorials.GreenhouseV2.components.SingleSubstanceExtractor(...
                this, ...                                                                       % parent system reference
                this.toStores.(this.txInput.sCultureName), ...                                  % store containing phases
                [this.txInput.sCultureName, '_GasExchange_P2P'], ...                            % p2p processor name
                [oBalance.sName, '.', this.txInput.sCultureName, '_GasExchange_P2P'], ...       % first phase and exme
                [oAtmosphere.sName, '.', this.txInput.sCultureName, '_GasExchange_P2P'], ...    % second phase and exme
                'BiomassBalance');                                                              % substance to extract
            
            %% Create Biomass Growth P2P Processor
            
            % 
            tutorials.GreenhouseV2.components.SingleSubstanceExtractor(...
                this, ...                                                                       % parent system reference
                this.toStores.(this.txInput.sCultureName), ...                                  % store containing phases
                [this.txInput.sCultureName, '_BiomassGrowth_P2P'], ...                          % p2p processor name
                [oBalance.sName, '.', this.txInput.sCultureName, '_BiomassGrowth_P2P'], ...     % first phase and exme
                [oPlants.sName, '.', this.txInput.sCultureName, '_BiomassGrowth_P2P'], ...      % second phase and exme
                'BiomassBalance');                                                              % substance to extract
            
            %% Create Substance Conversion Manipulators
            
            tutorials.GreenhouseV2.components.SubstanceConverterWaterNutrients(this, [this.txInput.sCultureName, '_SubstanceConverterWaterNutrients'], this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Balance']));
            tutorials.GreenhouseV2.components.SubstanceConverterGasExchange(this, [this.txInput.sCultureName, '_SubstanceConverterGasExchange'], this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']));
            tutorials.GreenhouseV2.components.SubstanceConverterPlantGrowth(this, [this.txInput.sCultureName, '_SubstanceConverterPlantGrowth'], this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']));
            
            %% Create Branches
            
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_AtmosphereCirculation_In'],   {}, 'Atmosphere_FromIF_In',     'Atmosphere_In');
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_AtmosphereCirculation_Out'],  {}, 'Atmosphere_ToIF_Out',      'Atmosphere_Out');
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_WaterSupply_In'],             {}, 'WaterSupply_FromIF_In',    'WaterSupply_In');
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_NutrientSupply_In'],          {}, 'NutrientSupply_FromIF_In', 'NutrientSupply_In');
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_Biomass_Out'],                {}, 'Biomass_ToIF_Out',         'Biomass_Out');
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % add branches to solvers
            solver.matter.manual.branch(this.toBranches.Atmosphere_In);
            solver.matter.manual.branch(this.toBranches.Atmosphere_Out);
            solver.matter.manual.branch(this.toBranches.WaterSupply_In);
            solver.matter.manual.branch(this.toBranches.NutrientSupply_In);
            solver.matter.manual.branch(this.toBranches.Biomass_Out);
            
            % initialize flowrates
            this.toBranches.Atmosphere_In.oHandler.setFlowRate(0);
            this.toBranches.Atmosphere_Out.oHandler.setFlowRate(0);
            this.toBranches.WaterSupply_In.oHandler.setFlowRate(0);
            this.toBranches.NutrientSupply_In.oHandler.setFlowRate(0);
            this.toBranches.Biomass_Out.oHandler.setFlowRate(0);
        end
        
        %% Connect Subsystem Interfaces with Parent System
        
        function setIfFlows(this, sIF1, sIF2, sIF3, sIF4, sIF5)
            this.connectIF('Atmosphere_FromIF_In', sIF1);
            this.connectIF('Atmosphere_ToIF_Out', sIF2);
            this.connectIF('WaterSupply_FromIF_In', sIF3);
            this.connectIF('NutrientSupply_FromIF_In', sIF4);
            this.connectIF('Biomass_ToIF_Out', sIF5);
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
            if this.oTimer.iTick == 0
                return;
            end
            
            %% Calculate 8 MMEC Parameters
            
            % calculate density of liquid H2O, required for transpiration
            tH2O.sSubstance = 'H2O';
            tH2O.sProperty = 'Density';
            tH2O.sFirstDepName = 'Pressure';
            tH2O.fFirstDepValue = this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fPressure;
            tH2O.sSecondDepName = 'Temperature';
            tH2O.fSecondDepValue = this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fTemperature;
            tH2O.sPhaseType = 'liquid';
            
            fDensityH2O = this.oMT.findProperty(tH2O);
            
            % calculate CO2 concentration of atmosphere
            this.fCO2 = this.oParent.CalculateCO2Concentration();
            
            % loop over all cultures
            % TODO: maybe parfor later
            % TODO: implement check for enough water available HERE, not
            % inside the function!!
%             for iI = 1:length(this.csCultures)
                % calculate plant induced flowrates
%             [ this ] = ...                                                  % return current culture object
%                 tutorials.GreenhouseV2.components.PlantGrowth(...
%                     this, ...                                               % current culture object
%                     this.oTimer.fTime, ...                                  % current simulation time
%                     this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fPressure, ...                 % atmosphere pressure
%                     this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fDensity, ...                  % atmosphere density
%                     this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fTemperature, ...              % atmosphere temperature
%                     this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).rRelHumidity, ...              % atmosphere relative humidity
%                     this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fSpecificHeatCapacity, ...     % atmosphere heat capacity
%                     fDensityH2O, ...                                        % density of liquid water under atmosphere conditions
%                     this.fCO2);                                             % CO2 concentration in ppm
                
                [ this ] = ...                                                  % return current culture object
                tutorials.GreenhouseV2.components.PlantGrowth(...
                    this, ...                                               % current culture object
                    this.oTimer.fTime, ...                                  % current simulation time
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMass * this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMassToPressure, ...                 % atmosphere pressure
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fDensity, ...                  % atmosphere density
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fTemperature, ...              % atmosphere temperature
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.rRelHumidity, ...              % atmosphere relative humidity
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fSpecificHeatCapacity, ...     % atmosphere heat capacity
                    fDensityH2O, ...                                        % density of liquid water under atmosphere conditions
                    this.fCO2);                                             % CO2 concentration in ppm
            
                %% Harvest
            
                % if current culture state is harvest
                if this.iState == 2
                    %
                    this.toBranches.Biomass_Out.oHandler.setFlowRate(...
                        this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).fMass / this.oParent.fUpdateFrequency);
                    
%                     this.toBranches.Biomass_Out.oHandler.setFlowRate(0.1);
                
                    disp('Harvesting');
                % if phase empty too, increase generation and change status
                % to growth, or set to fallow 
                elseif (this.iState == 2) && (this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).fMass <= 1e-3)
                    if this.iInternalGeneration < this.txInput.iConsecutiveGenerations
                        this.iInternalGeneration = this.iInternalGeneration + 1;
                        this.iState = 1;
                    else
                        this.iState = 4;
                    end
                end
                
                %% Set manipulator conversion ratios
                
                % PlantGrowth
                if this.tfBiomassGrowthRates.fGrowthRateEdible == 0
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).toManips.substance.fFactorEdible = 0;
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).toManips.substance.fFactorInedible = 1;
                else
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).toManips.substance.fFactorEdible = this.tfBiomassGrowthRates.fGrowthRateEdible / (this.tfBiomassGrowthRates.fGrowthRateEdible + this.tfBiomassGrowthRates.fGrowthRateInedible);
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).toManips.substance.fFactorInedible = 1 - this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).toManips.substance.fFactorEdible;
                end
                
                % GasExchange
                if (abs(this.tfGasExchangeRates.fO2ExchangeRate) + abs(this.tfGasExchangeRates.fCO2ExchangeRate) + this.tfGasExchangeRates.fTranspirationRate) == 0
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).toManips.substance.fFactorO2 = 0;
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).toManips.substance.fFactorCO2 = 0;
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).toManips.substance.fFactorH2O = 0;
                else
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).toManips.substance.fFactorO2 = this.tfGasExchangeRates.fO2ExchangeRate / (abs(this.tfGasExchangeRates.fO2ExchangeRate) + abs(this.tfGasExchangeRates.fCO2ExchangeRate) + this.tfGasExchangeRates.fTranspirationRate);
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).toManips.substance.fFactorCO2 = this.tfGasExchangeRates.fCO2ExchangeRate / (abs(this.tfGasExchangeRates.fO2ExchangeRate) + abs(this.tfGasExchangeRates.fCO2ExchangeRate) + this.tfGasExchangeRates.fTranspirationRate);
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).toManips.substance.fFactorH2O = 1 - (abs(this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).toManips.substance.fFactorO2) + abs(this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).toManips.substance.fFactorCO2));
                end
                
                %% Set P2P flow rates
                
                if (this.tfBiomassGrowthRates.fGrowthRateEdible + this.tfBiomassGrowthRates.fGrowthRateInedible) <= 0
                    this.toStores.(this.txInput.sCultureName).toProcsP2P.([this.txInput.sCultureName, '_BiomassGrowth_P2P']).fExtractionRate = 0;
                else
                    this.toStores.(this.txInput.sCultureName).toProcsP2P.([this.txInput.sCultureName, '_BiomassGrowth_P2P']).fExtractionRate = this.tfBiomassGrowthRates.fGrowthRateEdible + this.tfBiomassGrowthRates.fGrowthRateInedible;
                end 
                
                if (this.tfGasExchangeRates.fO2ExchangeRate + this.tfGasExchangeRates.fCO2ExchangeRate + this.tfGasExchangeRates.fTranspirationRate) <= 0
                    this.toStores.(this.txInput.sCultureName).toProcsP2P.([this.txInput.sCultureName, '_GasExchange_P2P']).fExtractionRate = 0;
                else
                    this.toStores.(this.txInput.sCultureName).toProcsP2P.([this.txInput.sCultureName, '_GasExchange_P2P']).fExtractionRate = this.tfGasExchangeRates.fO2ExchangeRate + this.tfGasExchangeRates.fCO2ExchangeRate + this.tfGasExchangeRates.fTranspirationRate;
                end
                
                %% Set branch flow rates
                
                this.toBranches.Atmosphere_In.oHandler.setFlowRate(-1e-2);
                this.toBranches.Atmosphere_Out.oHandler.setFlowRate(1e-2 + this.tfGasExchangeRates.fO2ExchangeRate + this.tfGasExchangeRates.fCO2ExchangeRate + this.tfGasExchangeRates.fTranspirationRate);
                this.toBranches.WaterSupply_In.oHandler.setFlowRate(-this.fWaterConsumptionRate);
                this.toBranches.NutrientSupply_In.oHandler.setFlowRate(-this.fNutrientConsumptionRate);
                
                this.toStores.(this.txInput.sCultureName).update();
%                 this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Balance']).toManips.substance.update();
%                 this.toStores.(this.txInput.sCultureName).toProcsP2P.([this.txInput.sCultureName, '_GasExchange_P2P']).update();
%                 this.toStores.(this.txInput.sCultureName).toProcsP2P.([this.txInput.sCultureName, '_BiomassGrowth_P2P']).update();
%                 this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).toManips.substance.update();
%                 this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).toManips.substance.update();
        end
    end
end