classdef CultureV2 % < vsys
    % This class is used in creating the culture objects. It provides the
    % phase for plant growth, adds a p2p processor which is automatically 
    % connected to biomass buffer store, two exmes and corresponding p2p 
    % processors which are automatically connected to the edible and 
    % inedible biomass phases and a manipulator to convert the incoming 
    % biomass into the culture's specific one. It also contains specific
    % plant data depending on the species grown.
    
    properties
        % matter table object (from parent system)
        oMT;
        
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
        
        %% Culture Mass Transfer Rates
        
        % culture gas exchange with atmosphere (O2, CO2, H2O)
        tfGasExchangeRates;         % [kg s^-1]
        
        % culture water consumption
        fWaterConsumptionRate;      % [kg s^-1]
        
        % culture nutrient consumption
        fNutrientConsumptionRate;   % [kg s^-1]
        
        % culture biomass growth (edible and inedible, both wet)
        tfBiomassGrowthRates;       % [kg s^-1]
    end
    
    methods
        function this = CultureV2(oParent, txPlantParameters, txInput)
%             this@vsys(oParent, txInput.sCultureName);
            
            % write properties
%             this.oMT = oParent.oMT;
            this.txPlantParameters = txPlantParameters;
            this.txInput = txInput;
            
            %% Create Store, Phases and Processors
%         end
%         
%         function createMatterStructure(this)
%             createMatterStructure@vsys(this);
            
            % write helper for standard plant atmosphere later
            fVolumeAirCirculation = 0.2;
            
            matter.store(oParent, this.txInput.sCultureName, 20);
            
            oAtmosphere = matter.phases.gas(...
                oParent.toStores.(this.txInput.sCultureName), ...        % store containing phase
                [this.txInput.sCultureName, '_Atmosphere'], ...          % phase name 
                struct(...                                          % phase contents    [kg]
                    'N2', 0.79 * fVolumeAirCirculation * 1e-3, ...
                    'O2', 0.21 * fVolumeAirCirculation * 1e-3), ...
                fVolumeAirCirculation, ...                          % ignored volume    [m^3]
                293.15);                                            % phase temperature [K]
            
            matter.procs.exmes.gas(oAtmosphere, [this.txInput.sCultureName, '_AtmosphereCirculation_In']);
            matter.procs.exmes.gas(oAtmosphere, [this.txInput.sCultureName, '_AtmosphereCirculation_Out']);
            
            matter.procs.exmes.gas(oAtmosphere, [this.txInput.sCultureName, '_GasExchange_P2P']);
            
            oPlants = matter.phases.solid(...
                oParent.toStores.(this.txInput.sCultureName), ...        % store containing phase
                [this.txInput.sCultureName, '_Plants'], ...              % phase name 
                struct(...                                          % phase contents    [kg]
                    [this.txPlantParameters.sPlantSpecies, 'EdibleWet'], 1e-3, ...
                    [this.txPlantParameters.sPlantSpecies, 'InedibleWet'], 1e-3), ...
                19.8, ...                                           % ignored volume    [m^3]
                293.15);                                            % phase temperature [K]
            
            matter.procs.exmes.solid(oPlants, [this.txInput.sCultureName, '_NutrientSupply_In']);
            matter.procs.exmes.solid(oPlants, [this.txInput.sCultureName, '_WaterSupply_In']);
            matter.procs.exmes.solid(oPlants, [this.txInput.sCultureName, '_BiomassEdible_Out']);
            matter.procs.exmes.solid(oPlants, [this.txInput.sCultureName, '_BiomassInedible_Out']);
            
            matter.procs.exmes.solid(oPlants, [this.txInput.sCultureName, '_GasExchange_P2P']);
            
            
            matter.procs.exmes.gas(oParent.toStores.Atmosphere.toPhases.Atmosphere, [this.txInput.sCultureName, '_AtmosphereCirculation_In']);
            matter.procs.exmes.gas(oParent.toStores.Atmosphere.toPhases.Atmosphere, [this.txInput.sCultureName, '_AtmosphereCirculation_Out']);
            
            matter.procs.exmes.liquid(oParent.toStores.WaterSupply.toPhases.WaterSupply, [this.txInput.sCultureName, '_WaterSupply_Out']);
            matter.procs.exmes.liquid(oParent.toStores.NutrientSupply.toPhases.NutrientSupply, [this.txInput.sCultureName, '_NutrientSupply_Out']);
            
            matter.procs.exmes.solid(oParent.toStores.BiomassEdible.toPhases.BiomassEdible, [this.txInput.sCultureName, '_BiomassEdible_In']);
            matter.procs.exmes.solid(oParent.toStores.BiomassInedible.toPhases.BiomassInedible, [this.txInput.sCultureName, '_BiomassInedible_In']);

            %% Create P2P processors
            
            % p2p for simulation of gas exchange (O2, CO2, H2O)
            tutorials.GreenhouseV2.components.GasExchange(...
                oParent.toStores.(txInput.sCultureName), ...                                    % store containing phases
                [txInput.sCultureName, '_GasExchange_P2P'], ...                                 % p2p processor name
                [oAtmosphere.sName, '.', this.txInput.sCultureName, '_GasExchange_P2P'], ...    % first phase and exme
                [oPlants.sName, '.', this.txInput.sCultureName, '_GasExchange_P2P'], ...        % second phase and exme
                [this.txInput.sCultureName, '_GasExchange']);                                   % substance to extract
        end
        
%         function createSolverStructure(this)
%             createSolverStructure@vsys(this);
%             
%             %% Add Branches To Solvers
%             
%             
%         end
%         
%         %% Connect Subsystem Interfaces with Parent System
%         
%         function setIfFlows(this, sInterface1, sInterface2, sInterface3, sInterface4, sInterface5, sInterface6)
%             this.connectIF('Atmosphere_In_FromIF', sInterface1);
%             this.connectIF('Atmosphere_Out_ToIF', sInterface2);
%             this.connectIF('WaterSupply_In_FromIF', sInterface3);
%             this.connectIF('NutrientSupply_In_FromIF', sInterface4);
%             this.connectIF('BiomassEdible_Out_ToIF', sInterface5);
%             this.connectIF('BiomassInedible_Out_ToIF', sInterface6);
%         end
    end
    
    methods (Access = protected)
        function update(this)
            
            
        end
    end
end