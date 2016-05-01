classdef CultureV2 < vsys
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
        fCO2;
        
        %% Culture Mass Transfer Rates
        
        % culture gas exchange with atmosphere (O2, CO2, H2O)
        tfGasExchangeRates = struct();         % [kg s^-1]
        
        % culture water consumption
        fWaterConsumptionRate = 0;      % [kg s^-1]
        
        % culture nutrient consumption
        fNutrientConsumptionRate = 0;   % [kg s^-1]
        
        % culture biomass growth (edible and inedible, both wet)
        tfBiomassGrowthRates = struct();       % [kg s^-1]
    end
    
    methods
        function this = CultureV2(oParent, txPlantParameters, txInput)
            this@vsys(oParent, txInput.sCultureName, -1);
            
            this.txPlantParameters = txPlantParameters;
            this.txInput = txInput;
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %% Create Store, Phases and Processors
            
            % write helper for standard plant atmosphere later
            fVolumeAirCirculation = 0.01;
            
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
            
            oPlants = matter.phases.solid(...
                this.toStores.(this.txInput.sCultureName), ...          % store containing phase
                [this.txInput.sCultureName, '_Plants'], ...             % phase name 
                struct(...                                              % phase contents    [kg]
                    ), ...
                20 - fVolumeAirCirculation, ...                         % ignored volume    [m^3]
                293.15);                                                % phase temperature [K]
            
            matter.procs.exmes.solid(oPlants, [this.txInput.sCultureName, '_WaterSupply_In']);
            matter.procs.exmes.solid(oPlants, [this.txInput.sCultureName, '_NutrientSupply_In']);
            matter.procs.exmes.solid(oPlants, [this.txInput.sCultureName, '_Biomass_Out']); 
            
            matter.procs.exmes.solid(oPlants, [this.txInput.sCultureName, '_GasExchange_P2P']);
            
            %% Create Gas Exchange P2P processor
            
            % p2p for simulation of gas exchange (O2, CO2, H2O)
            tutorials.GreenhouseV2.components.GasExchange(...
                this.toStores.(this.txInput.sCultureName), ...                                  % store containing phases
                [this.txInput.sCultureName, '_GasExchange_P2P'], ...                            % p2p processor name
                [oAtmosphere.sName, '.', this.txInput.sCultureName, '_GasExchange_P2P'], ...    % first phase and exme
                [oPlants.sName, '.', this.txInput.sCultureName, '_GasExchange_P2P']);           % second phase and exme
            
            %% Create Substance Conversion Manipulator
            
            tutorials.GreenhouseV2.components.SubstanceConverter(this, [this.txInput.sCultureName, '_SubstanceConverter'], this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']));
            
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
            [ this ] = ...                                                  % return current culture object
                tutorials.GreenhouseV2.components.PlantGrowth(...
                    this, ...              % current culture object
                    this.oTimer.fTime, ...                                  % current simulation time
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fPressure, ...                 % atmosphere pressure
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fDensity, ...                  % atmosphere density
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fTemperature, ...              % atmosphere temperature
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).rRelHumidity, ...              % atmosphere relative humidity
                    this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fSpecificHeatCapacity, ...     % atmosphere heat capacity
                    fDensityH2O, ...                                        % density of liquid water under atmosphere conditions
                    this.fCO2);                                             % CO2 concentration in ppm
            
                %% Harvest
            
                % if current culture state is harvest
                if this.iState == 2
                
                else
                    
                end
                
                this.toBranches.Atmosphere_In.oHandler.setFlowRate(-0.1);
                this.toBranches.Atmosphere_Out.oHandler.setFlowRate(0.1 + this.tfGasExchangeRates.fO2ExchangeRate + this.tfGasExchangeRates.fCO2ExchangeRate + this.tfGasExchangeRates.fTranspirationRate);
                
%                 update@matter.store(this.toCultures);
%             end   
        end
    end
end