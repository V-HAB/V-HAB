classdef Greenhouse < vsys
    % This class represents the setup of the lunar greenhouse prototype
    % described in ICES-2014-167: "Poly-Culture Food Production and Air 
    % Revitalization Mass and Energy Balances Measured in a Semi-Closed 
    % Lunar Greenhouse Prototype (LGH)", R. Lane Patterson et al.
    
    properties
        % subsystem object
        oPlantModule;
    end
    
    methods
        function this = Greenhouse(oParent, sName)
            this@vsys(oParent, sName);
            
            % necessary for configuration
            eval(this.oRoot.oCfgParams.configCode(this));
            
            %% Create Subsystems
            
            % Initializing Subsystem: PlantModule
            this.oPlantModule = tutorials.LunarGreenhouseMMEC.subsystems.PlantModule(this, 'PlantModule');
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% Greenhouse Unit
            
            % create the greenhouse main unit (volume ref ICES-2014-167),
            % currently only one, should be four in the future.
            % store contains 3 phases, important for volume
            matter.store(this, 'GreenhouseUnit', (22.9 - this.oPlantModule.toStores.PlantModule.toPhases.Atmosphere.fVolume) + 0.5 + 0.5);
            
            % add atmosphere phase to greenhouse unit
            % TODO: maybe write atmosphere helper later for standard plant
            % atmosphere phase
            oAtmosphere = matter.phases.gas(...         
                this.toStores.GreenhouseUnit , ...  % store containing phase
                'Atmosphere', ...                   % phase name
                struct(...                          % phase contents    [kg]
                    'O2', 6.394, ...
                    'N2', 21.192, ...
                    'CO2', 0.040, ...
                    'H2O', 0.193), ...     
                    ... % phase volume [m^3], substract plant module 
                    ... % atmosphere volume to not oversize 
                22.9 - this.oPlantModule.toStores.PlantModule.toPhases.Atmosphere.fVolume, ...                           
                fTemperatureInit);                  % phase temperature [K]
            
            % add exmes to atmosphere phase
            % in- and output exmes to connect with plant module interfaces
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_ToInterface_Out');
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_FromInterface_In');
            
            % input exmes from CO2 and N2 supply
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_FromCO2Supply_In');
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_FromN2Supply_In');
            
            % output exmes to CO2 and O2 excess phases
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_ToCO2Excess_Out');
            matter.procs.exmes.gas(oAtmosphere, 'Atmosphere_ToO2Excess_Out');
            
            
            % Add Phase for excess CO2 - Excess CO2 is ejected to this 
            % phase. (Avoid to exceed CO2 limit due to nightly CO2 
            % production by plants)
            oCO2Excess = matter.phases.gas(...
                this.toStores.GreenhouseUnit, ...   % store containing phase
                'CO2Excess', ...                    % phase name
                struct(...                          % phase contens     [kg]
                    'CO2', 1e-3), ...      
                0.5, ...                            % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            % add exme to CO2 excess phase
            matter.procs.exmes.gas(oCO2Excess, 'CO2Excess_FromAtmosphere_In');

            
            % Add Phase for excess O2 - Excess O2 is ejected to this phase.
            % (Because of no O2 consumers, just the plants nightly O2
            % consumption - the exceeding O2 has to be ejected)
            oO2Excess = matter.phases.gas(...
                this.toStores.GreenhouseUnit, ...   % store containing phase
                'O2ExcessPhase', ...                % phase name
                struct(...                          % phase contens     % [kg]
                    'O2', 1e-3), ...       
                0.5, ...                            % phase volume      % [m^3]
                fTemperatureInit);                  % phase temperature % [K]

            % add exmes to CO2 excess phase
            matter.procs.exmes.gas(oO2Excess, 'O2Excess_FromAtmosphere_In');
            
            % TODO: add P2Ps to manage excess flowrates
            
            %% Water Supply
            
            % create water supply tank
            matter. store(this, 'WaterSupplyTank', 1e3);
            
            % add phase to water supply tank
            oWaterSupply = matter.phases.liquid(...
                this.toStores.WaterTank, ...    % store containing phase
                'WaterSupply', ...              % phase name
                struct(...                      % phase contents    [kg]
                    'H2O', 1e3 * 1e3), ...
                1e3, ...                        % phase volume      [m^3]
                fTemperatureInit, ...           % phase temperature [K]
                fPressureInit);                 % phase pressure    [Pa]
            
            % add exmes to water supply phase
            % output exme to connect with plant module interface
            matter.procs.exmes.liquid(oWaterSupply, 'WaterSupply_ToInterface_Out');
            
            %% Nutrient Supply
            
            % create nutrient supply tank
            matter.store(this, 'NutrientSupplyTank', 1e3);
            
            % add phase to water supply tank
            % TODO: create nutrients data in matter table
            oNutrientSupply = matter.phases.liquid(...
                this.toStores.NutrientTank, ... % store containing phase
                'NutrientSupply', ...           % phase name
                struct(...                      % phase contents    [kg]
                    'nutrients', 1e3 * 1e3), ...
                1e3, ...                        % phase volume      [m^3]
                fTemperatureInit, ...           % phase temperature [K]
                fPressureInit);                 % phase pressure    [Pa]
            
            % add exmes to nutrient supply phase
            % output exme to connect with plant module interface
            matter.procs.exmes.liquid(oNutrientSupply, 'NutrientSupply_ToInterface_Out');
            
            %% CO2 Supply
            
            % create CO2 supply tank
            matter.store(this, 'CO2SupplyTank', 1e3);
            
            % add phase to CO2 supply tank
            oCO2Supply = matter.phases.gas(...
                this.toStores.CO2SupplyTank, ...    % store containing phase
                'CO2Supply', ...                    % phase name
                struct(...                          % phase contents    [kg]
                    'CO2', 1e3), ...
                1e3, ...                            % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            % add exmes to CO2 supply phase
            matter.procs.exmes.gas(oCO2Supply, 'CO2Supply_ToAtmosphere_Out');
            
            %% N2 Supply
            
            % create N2 supply tank
            matter.store(this, 'N2SupplyTank', 1e3);
            
            % add phase to N2 supply tank
            oN2Supply = matter.phases.gas(...
                this.toStores.N2SupplyTank, ...     % store containing phase
                'N2Supply', ...                     % phase name
                struct(...                          % phase contents    [kg]
                    'N2', 1e3), ...
                1e3, ...                            % phase volume      [m^3]
                fTemperatureInit);                  % phase temperature [K]
            
            % add exmes to N2 supply phase
            matter.procs.exmes.gas(oN2Supply, 'N2Supply_ToAtmosphere_Out');
            
            %% Leakage
            
            % create leakage tank
            matter.store(this, 'LeakageTank', 1e6);
            
            % add phase to leakage tank
            oLeakage = matter.phases.gas(...
                this.toStores.LeakageTank, ...  % store containing phase
                'Leakage', ...                  % phase name
                struct(...                      % phase contents    [kg]
                    'O2', 6.394, ...
                    'N2', 21.192, ...
                    'CO2', 0.040, ...
                    'H2O', 0.193), ...
                 1e6, ...                       % phase volume      [m^3]
                 fTemperatureInit);             % phase temperature [K]
            
            % add exmes to leakage tank
            matter.procs.exmes.gas(oLeakage, 'FromGreenhouseUnit_In');
            
            %% Food Storage (Edible Biomass)
            
            % create food store
            matter.store(this, 'FoodStore', 1e3);
            
            % add edible biomass phase to food store
            oBiomassEdible = matter.phases.solid(...
                this.toStores.FoodStore, ...    % store containing phase
                'EdibleBiomass', ...            % phase name
                struct(...                      % phase contents    [kg]
                    ), ...          
                1e3, ...                        % phase volume      [m^3]
                293.15);                        % phase temperature [K]
            
            % add exmes to edible biomass 
            matter.procs.exmes.solid(oBiomassEdible, 'BiomassEdible_FromInterface_In');

            %% Waste Storage (Inedible Biomass)
            
            % create waste store
            matter.store(this, 'WasteStore', 1e3);
            
            % add inedible biomass phase to waste store
            oBiomassInedible = matter.phases.solid(...
                this.toStores.WasteStore, ...   % store containing phase
                'InedibleBiomass', ...          % phase name
                struct(...                      % phase contents    [kg]
                    ), ...          
                1e3, ...                        % phase volume      [m^3]
                293.15);                        % phase temperature [K]
            
            % add exmes to edible biomass 
            matter.procs.exmes.solid(oBiomassInedible, 'BiomassInedible_FromInterface_In');
            
            %% Water Separator
            
            % TODO
            
            %% Set Reference Phases
            
            % atmosphere, water and nutrient supply paths for plant module
            this.toChildren.PlantModule.setReferencePhase(...
                this.toStores.GreenhouseUnit.aoPhases(1,1), ...     % atmosphere phase
                this.toStores.WaterTank.aoPhases(1,1), ...          % water phase
                this.toStores.NutrientTank.aoPhases(1,1));          % nutrient phase
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
        end
    end
end