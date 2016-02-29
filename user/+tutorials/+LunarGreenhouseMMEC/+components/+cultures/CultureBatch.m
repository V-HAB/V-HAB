classdef CultureBatch
    % This class is used in creating the culture objects. It provides the
    % phase for plant growth, adds a p2p processor which is automatically 
    % connected to biomass buffer store, two exmes and corresponding p2p 
    % processors which are automatically connected to the edible and 
    % inedible biomass phases and a manipulator to convert the incoming 
    % biomass into the culture's specific one. It also contains specific
    % plant data depending on the species grown.
    
    properties
        % struct containing plant parameters, from matter table
        tPlantData;
        
        % save input parameters, they need to be requested
        tInput;
    end
    
    methods
        function this = CultureBatch(oParent, tInput)
            
            this.tInput = tInput;
            
            %% Create culture phase and exmes
            
            % TODO: phase name and content from input
            % add phase to plant module store
            eval(['o' tInput.sCultureName]) = matter.phases.solid(...
                oParent.toStores.PlantModule, ...       % store containing phase
                tInput.sCultureName, ...                % phase name
                struct(...                              % phase contents    [kg]
                    ), ...
                oParent.fVolumeInit, ...                % phase volume      [m^3]
                oParent.fTemperatureInit);              % phase temperature [K]
            
            % add exmes to culture phase
            % exmes to connect the p2p procs for biomass input from biomass
            % buffer phase and for output to edible and inedible biomass
            matter.procs.exmes.solid(eval(['o' tInput.sCultureName]), 'Culture_CultureGrowth_P2P');
            matter.procs.exmes.solid(eval(['o' tInput.sCultureName]), 'Culture_HarvestEdible_P2P');
            matter.procs.exmes.solid(eval(['o' tInput.sCultureName]), 'Culture_HarvestInedible_P2P');
            
            % exmes in the parent system phases to connect the p2p procs
            matter.procs.exmes.solid(oParent.toStores.PlantModule.toPhases.BiomassBuffer, 'BiomassBuffer_CultureGrowth_P2P');
            matter.procs.exmes.solid(oParent.toStores.PlantModule.toPhases.BiomassEdible, 'BiomassEdible_HarvestEdible_P2P');
            matter.procs.exmes.solid(oParent.toStores.PlantModule.toPhases.BiomassInedible, 'BiomassInedible_HarvestInedible_P2P');
            
            %% Create P2P processors
            
            % culture growth rate
            tutorials.LunarGreenhouseMMEC.cultures.CultureGrowth(...
                oParent.toStores.PlantModule, ...                           % store containing phases
                'CultureGrowth_P2P', ...                                    % p2p processor name
                'BiomassBuffer.BiomassBuffer_CultureGrowth_P2P', ...        % first phase and exme
                [tInput.sCultureName, '.Culture_CultureGrowth_P2P'], ...    % second phase and exme
                '');                                                        % substance to extract
            
            % harvest edible biomass
            tutorials.LunarGreenhouseMMEC.cultures.CultureHarvest(...
                oParent.toStores.PlantModule, ...                           % store containing phases
                'HarvestEdible_P2P', ...                                    % p2p processor name
                [tInput.sCultureName, '.Culture_HarvestEdible_P2P'], ...    % first phase and exme
                'BiomassEdible.BiomassEdible_HarvestEdible_P2P', ...        % second phase and exme
                '');                                                        % substance to extract
            
            % harvest inedible biomass
            tutorials.LunarGreenhouseMMEC.cultures.CultureHarvest(...
                oParent.toStores.PlantModule, ...                           % store containing phases
                'HarvestInedible_P2P', ...                                  % p2p processor name
                [tInput.sCultureName, '.Culture_HarvestInedible_P2P'], ...  % first phase and exme
                'BiomassInedible.BiomassInedible_HarvestInedible_P2P', ...  % second phase and exme
                '');                                                        % substance to extract
            
            %% Create biomass conversion manipulator
            
            % TODO: path correct? or can do better?
            tutorials.LunarGreenhouseMMEC.cultures.ConvertBiomass(eval(['oParent.toStores.PlantModule.toPhases.' tInput.sCultureName]), 'CultureConversion_Manip');
        end
    end
end