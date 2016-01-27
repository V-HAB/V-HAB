classdef Create_Biomass_IMPROVED < matter.manips.substance.flow
    
    properties
        % cell array containing data about all grown cultures
        cxCultures;
        
        % tPlantParameters with adjusted growth times in minutes 
        tPlantParametersAdjusted;
        
        % parent system reference
        oParent;
        
        % time conversion factors for calculating
        fDaysToMinutes = 24 * 60;           % [min/d]
        fHourlyRatesToSeconds = 1 / 3600;   % [s/h]
        
        % array containing biomass generated ready to be harvested
        afBiomass;
    end
    
    methods
        function this = Create_Biomass_IMPROVED(oParent, sName, oPhase)
            % call superconstructor
            this@matter.manips.substance.flow(sName, oPhase);
            
            % set parent system reference
            this.oParent = oParent;
            
            % get tPlantParameters from parent system to adjust
            % TODO: find out about the strange 60s factor, WHY??
            this.tPlantParametersAdjusted = oParent.tPlantParameters;
            
            % buffer variable to get culture names, fieldnames() returns a 
            % full cell array of strings, so needed for proper indexing
            csCultureName = fieldnames(oParent.tPlantData.PlantEng);
            
            % transforming and assigning reference growth times to minutes
            for i = 1:size(this.tPlantParametersAdjusted, 2)
                this.tPlantParametersAdjusted(i).tM_nominal     = this.tPlantParametersAdjusted(i).tM_nominal * 24 * 60;  % [min]
                this.tPlantParametersAdjusted(i).tQ             = this.tPlantParametersAdjusted(i).tQ * 24 * 60;          % [min]
                this.tPlantParametersAdjusted(i).tE             = this.tPlantParametersAdjusted(i).tE * 24 * 60;          % [min]
            end
            
            % initialize cxCultures cell array, has three sections:
            % "PlantData", "Growth" and "Harvest"
            for i = 1:length(this.csCultureName)
                % each grown culture gets an internal index number and its
                % name specified in the *.mat file
                this.cxCultures{i, 1}.CultureNumber = i;
                this.cxCultures{i, 1}.CultureName = csCultureName{i};
                
                %% PlantData
                
                % create cell array containing specified plant data in its
                % "PlantData" section
                this.cxCulture{i, 1}.PlantData = eval(['this.tPlantData.' this.csCultureName{x} '.EngData']);
                
                % transforming harvest time to minutes
                this.cxCulture{i, 1}.PlantData.harv_time = this.cxCulture{i, 1}.PlantData.harv_time * this.fDaysToMinutes;
                
                % if no photoperiod is specified and no global lighting
                % conditions are set, photoperiod receives its nominal
                % reference values listed in PlantParameters.m
                if isempty(this.cxCulture{i, 1}.PlantData.H) && (bGlobalPlantLighing == 0)
                    this.cxCulture{i, 1}.PlantData.H    = this.tPlantParametersAdjusted(this.cxCulture{i, 1}.PlantData.plant_type).H0;
                end
                
                % if no photosynthetic photon flux is specified and no
                % global lighting conditions are set, PPF receives its
                % nominal reference values listed in PlantParameters.m
                if isempty(this.cxCulture{i, 1}.PlantData.PPF) && (bGlobalPlantLighing == 0)
                    this.cxCulture{i, 1}.PlantData.PPF  = this.tPlantParametersAdjusted(this.cxCulture{i, 1}.PlantData.plant_type).PPF_ref(2);
                end
                
                %% Growth
                
                % adding growth parameters to cxCultures in its "Growth"
                % section and initializing them                           
                
                % internal culture time, counting from planting
                this.cxCultures{i, 1}.Growth.InternalTime           = 0;    % [?]
                
                % internal generation count, increases with each replanting
                this.cxCultures{i, 1}.Growth.InternalGeneration     = 1;    % [-]
                
                % convert emerge time to minutes
                this.cxCultures{i, 1}.Growth.emerge_time = this.cxCultures{i, 1}.Growth.emerge_time * this.fDaysToMinutes;  % [min]
                
                % total crop biomass (wet)
                this.cxCultures{i, 1}.Growth.TCB                    = 0;    % [kg]
                
                % total edible biomass (wet)
                this.cxCultures{i, 1}.Growth.TEB                    = 0;    % [kg]
                
                % O2 gas exchange rate with atmosphere
                this.cxCultures{i, 1}.Growth.O2Exchange             = 0;    % [kg/s]
                
                % CO2 gas exchange rate with atmosphere
                this.cxCultures{i, 1}.Growth.CO2Exchange            = 0;    % [kg/s]
                
                % H2O gas exchange rate with atmosphere
                this.cxCultures{i, 1}.Growth.H2OExchange            = 0;    % [kg/s]
                
                %
                this.cxCultures{i, 1}.Growth.CUE_24                 = 0;
                
                %
                this.cxCultures{i, 1}.Growth.A                      = 0;
                
                %
                this.cxCultures{i, 1}.Growth.P_net                  = 0;
                
                % canopy quantum yield
                this.cxCultures{i, 1}.Growth.CQY                    = 0;    % [-]
                
                %
                this.cxCultures{i, 1}.Growth.CO2AssimilationFactor  = 1;    % [-]
                
                % time without water supply
                this.cxCultures{i, 1}.Growth.TimeWithoutH2O         = 0;    % [?]
                
                %% Harvest
                
                % adding harvest parameters to cxCultures in its "Harvest"
                % section and initializing them

                % accumulating biomass is tracked, will be extracted when 
                % harvest time is reached
                this.cxCultures{i, 1}.Harvest.EdibleDryBiomass      = 0;    % [kg]
                this.cxCultures{i, 1}.Harvest.EdibleWetBiomass      = 0;    % [kg]
                this.cxCultures{i, 1}.Harvest.InedibleDryBiomass    = 0;    % [kg]
                this.cxCultures{i, 1}.Harvest.InedibleWetBiomass    = 0;    % [kg]
            end
        end
        
        function update(this)
            % The update only will be conducted every minute!
            % Necessary for proper "integration"
            % TODO: FIND OUT WHY!!!!
            if mod(this.oTimer.fTime, 60)~= 0;
                return;
            end
        end
    end
end
    
    