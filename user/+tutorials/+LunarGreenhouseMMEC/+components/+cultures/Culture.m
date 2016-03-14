classdef Culture
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
        tfMMECRates = struct();
        
        % internal time of plant culture (passed time AFTER planting)
        fInternalTime = 0;
        
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
        function this = Culture(oParent, txPlantParameters, txInput)
            
            this.txPlantParameters = txPlantParameters;
            this.txInput = txInput;
            
            %% Create culture phase and exmes
            
            % TODO: phase name and content from input
            % add phase to plant module store
            oPhase = matter.phases.solid(...
                oParent.toStores.PlantModule, ...       % store containing phase
                txInput.sCultureName, ...               % phase name 
                struct(...                              % phase contents    [kg]
                    'BiomassBalance', 1), ...
                [], ...                                 % ignored volume    [m^3]
                293.15);                                % phase temperature [K]
            
            % add exmes to culture phase
            % exmes to connect the p2p procs for biomass input from biomass
            % buffer phase and for output to edible and inedible biomass
            matter.procs.exmes.solid(oPhase, [txInput.sCultureName, '_CultureGrowth_P2P']);
            matter.procs.exmes.solid(oPhase, [txInput.sCultureName, '_HarvestEdible_P2P']);
            matter.procs.exmes.solid(oPhase, [txInput.sCultureName, '_HarvestInedible_P2P']);
            
            % exmes in the parent system phases to connect the p2p procs
            matter.procs.exmes.solid(oParent.toStores.PlantModule.toPhases.BiomassBuffer, [txInput.sCultureName, '_CultureGrowth_P2P']);
            matter.procs.exmes.solid(oParent.toStores.PlantModule.toPhases.BiomassEdible, [txInput.sCultureName, '_HarvestEdible_P2P']);
            matter.procs.exmes.solid(oParent.toStores.PlantModule.toPhases.BiomassInedible, [txInput.sCultureName, '_HarvestInedible_P2P']);
            
            %% Create P2P processors
            
            % culture growth rate
            tutorials.LunarGreenhouseMMEC.components.cultures.CultureGrowth(...
                oParent.toStores.PlantModule, ...                                               % store containing phases
                [txInput.sCultureName, '_CultureGrowth_P2P'], ...                               % p2p processor name
                ['BiomassBuffer.', txInput.sCultureName, '_CultureGrowth_P2P'], ...             % first phase and exme
                [txInput.sCultureName, '.', txInput.sCultureName, '_CultureGrowth_P2P'], ...    % second phase and exme
                'BiomassBalance');                                                              % substance to extract
            
            % harvest edible biomass
            tutorials.LunarGreenhouseMMEC.components.cultures.CultureHarvest(...
                oParent.toStores.PlantModule, ...                                               % store containing phases
                [txInput.sCultureName, '_HarvestEdible_P2P'], ...                               % p2p processor name
                [txInput.sCultureName, '.', txInput.sCultureName, '_HarvestEdible_P2P'], ...    % first phase and exme
                ['BiomassEdible.', txInput.sCultureName, '_HarvestEdible_P2P'], ...             % second phase and exme
                'BiomassBalance');                                                              % substance to extract
            
            % harvest inedible biomass
            tutorials.LunarGreenhouseMMEC.components.cultures.CultureHarvest(...
                oParent.toStores.PlantModule, ...                                               % store containing phases
                [txInput.sCultureName, '_HarvestInedible_P2P'], ...                             % p2p processor name
                [txInput.sCultureName, '.', txInput.sCultureName, '_HarvestInedible_P2P'], ...  % first phase and exme
                ['BiomassInedible.', txInput.sCultureName, '_HarvestInedible_P2P'], ...         % second phase and exme
                'BiomassBalance');                                                              % substance to extract
            
            %% Create biomass conversion manipulator
            
            % TODO: path correct? or can do better?
            tutorials.LunarGreenhouseMMEC.components.cultures.ConvertBiomass(oParent, [txInput.sCultureName, '_CultureConversion_Manip'], oPhase);
        end
    end
end