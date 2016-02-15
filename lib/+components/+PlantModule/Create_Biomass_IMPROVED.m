classdef Create_Biomass_IMPROVED < matter.manips.substance.flow
    
    properties
        % cell array containing data about all grown cultures
        cxCultures;
        
        % tPlantParameters with adjusted growth times in minutes 
        tPlantParametersAdjusted;
        
        % parent system reference
        oParent;
        
        %
        fO2Exchange = 0;
        
        %
        fCO2Exchange = 0;
        
        %
        fH2OExchange = 0;
        
        %
        fWaterNeed = 0;
        
        % LOG
        fO2ProducedTotal = 0;
        % LOG
        CO2ConsumedTotal = 0;
        % LOG
        H2OTranspiredTotal = 0;
        % LOG
        WaterConsumedTotal = 0;
        
        % system time before the current timestep
        fLastUpdate = 0;
        
        % time conversion factors for calculating
        % TODO: are they REALLY needed?
        fDaysToMinutes = 24 * 60;           % [min/d]
        fHourlyRatesToSeconds = 1 / 3600;   % [s/h]
        
        % TODO: finish after first iteration of rework is completed, for
        % now just using afPartials from old CreateBiomass.m
        %%%%%%%%%%%%%%%
%         % array containing biomass generated ready to be harvested,
%         % inserted into plants phase by the manipulator
%         afBiomass;
%         
%         % array containing plant gas exchange with atmosphere flowrates
%         % used by the manipulator, kept separated from produced biomass for 
%         % ease of reading
%         afGasExchange;
%         
%         %
%         miIndexer;
        
        afPartials;
        %%%%%%%%%%%%%%%
    end
    
    methods
        function this = Create_Biomass_IMPROVED(oParent, sName, oPhase)
            % call superconstructor
            this@matter.manips.substance.flow(sName, oPhase);
            
            % set parent system reference
            this.oParent = oParent;
            
            % TODO: finish after redoing PlantParameters.m, for now using
            % afPartials from old CreateBiomass.m
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%             % initialize biomass array, wet edible and inedible biomass for
%             % all species available in PlantParameters.m (currently 9).
%             for i=1:length(this.oParent.tPlantParameters.name)
%                 this.miIndexer(i, 1) = x;
%             end
            
            this.afPartials = zeros(1, this.oPhase.oMT.iSubstances);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % TODO: trying to go with seconds for now, no idea if it
            % works
%             % get tPlantParameters from parent system to adjust
%             % TODO: find out about the strange 60s factor, WHY??
%             this.tPlantParametersAdjusted = oParent.tPlantParameters;
            
            % buffer variable to get culture names, fieldnames() returns a 
            % full cell array of strings, so needed for proper indexing
            csCultureName = fieldnames(oParent.tPlantData.PlantEng);
            
            % TODO: trying to go with seconds for now, no idea if it
            % works
%             % transforming and assigning reference growth times to minutes
%             for i = 1:size(this.tPlantParametersAdjusted, 2)
%                 this.tPlantParametersAdjusted(i).T_M_Nominal     = this.tPlantParametersAdjusted(i).T_M_Nominal * 24 * 60;  % [min]
%                 this.tPlantParametersAdjusted(i).T_Q             = this.tPlantParametersAdjusted(i).T_Q * 24 * 60;          % [min]
%                 this.tPlantParametersAdjusted(i).T_E             = this.tPlantParametersAdjusted(i).T_E * 24 * 60;          % [min]
%             end
            
            % initialize cxCultures cell array, has four main sections:
            % "PlantData", "PlantParameters", "Growth" and "Harvest"
            for i = 1:length(csCultureName)
                % each grown culture gets an internal index number and its
                % name specified in the *.mat file
                this.cxCultures{i, 1}.CultureNumber = i;
                this.cxCultures{i, 1}.CultureName = csCultureName{i};
                
                %% PlantData
                
                % get plant data from the parent system to apply to the
                % "PlantData" section in cxCultures. 
                % Theoretically the whole process of reading the *.mat file
                % could be done here instead of the plant module but then
                % it would be necessary to apply changes to this file as
                % well (namely the path to the *.mat file) so it was
                % decided to use a not strictly necessary property in the 
                % parent system so only one file (the plant module itself)
                % needs to be alterated when implementing the plant module
                % as a subsystem
                this.cxCultures{i, 1}.PlantData = eval(['this.oParent.tPlantData.PlantData.' csCultureName{i}]);
                
                % TODO: trying to go with seconds for now, no idea if it
                % works
%                 % transforming harvest time to minutes
%                 this.cxCulture{i, 1}.PlantData.harv_time = this.cxCulture{i, 1}.PlantData.harv_time * this.fDaysToMinutes;
                
                % if no photoperiod is specified and no global lighting
                % conditions are set, photoperiod receives its nominal
                % reference values listed in PlantParameters.m
                if isempty(this.cxCultures{i, 1}.PlantData.H) && (bGlobalPlantLighing == 0)
                    this.cxCultures{i, 1}.PlantData.H    = this.tPlantParametersAdjusted(this.cxCulture{i, 1}.PlantData.PlantSpecies).H_Nominal;
                end
                
                % if no photosynthetic photon flux is specified and no
                % global lighting conditions are set, PPF receives its
                % nominal reference values listed in PlantParameters.m
                if isempty(this.cxCultures{i, 1}.PlantData.PPF) && (bGlobalPlantLighing == 0)
                    this.cxCultures{i, 1}.PlantData.PPF  = this.tPlantParametersAdjusted(this.cxCultures{i, 1}.PlantData.PlantSpecies).PPF_Nominal;
                end
                
                %% PlantParameters
                
                % write plant parameters from PlantParameters.m into cell
                % array
                this.cxCultures{i, 1}.PlantParameters = components.PlantModule.PlantParameters_IMPROVED(this.cxCultures{i, 1}.PlantData.PlantSpecies);
                
                %% Growth
                
                % adding growth parameters to cxCultures in its "Growth"
                % section and initializing them                           
                
                % internal culture time, counting from planting
                this.cxCultures{i, 1}.Growth.InternalTime           = 0;    % [s]
                
                % internal generation count, increases with each replanting
                this.cxCultures{i, 1}.Growth.InternalGeneration     = 1;    % [-]
                
                % TODO: trying to go with seconds for now, no idea if it
                % works
%                 % convert emerge time to minutes
%                 this.cxCultures{i, 1}.Growth.EmergeTime = this.cxCultures{i, 1}.Growth.EmergeTime * this.fDaysToMinutes;  % [min]
                
                % Total Crop Biomass (wet)
                this.cxCultures{i, 1}.Growth.TCB                    = 0;    % [kg]
                
                % Total Edible Biomass (wet)
                this.cxCultures{i, 1}.Growth.TEB                    = 0;    % [kg]
                
                % O2 gas exchange rate with atmosphere
                this.cxCultures{i, 1}.Growth.O2Exchange             = 0;    % [kg/s]
                
                % CO2 gas exchange rate with atmosphere
                this.cxCultures{i, 1}.Growth.CO2Exchange            = 0;    % [kg/s]
                
                % H2O gas exchange rate with atmosphere
                this.cxCultures{i, 1}.Growth.H2OExchange            = 0;    % [kg/s]
                
                % Water required for growth
                this.cxCultures{i, 1}.Growth.WaterNeed              = 0;    % [kg/s] 
                
                % 24-h Carbon Use Efficiency
                this.cxCultures{i, 1}.Growth.CUE_24                 = 0;
                
                % Fraction of irradiance absorbed by the canopy
                this.cxCultures{i, 1}.Growth.A                      = 0;
                
                % Canopy Net Photosynthesis
                this.cxCultures{i, 1}.Growth.P_Net                  = 0;
                
                % Canopy Quantum Yield
                this.cxCultures{i, 1}.Growth.CQY                    = 0;    % [-]
                
                % ????
                this.cxCultures{i, 1}.Growth.CO2AssimilationFactor  = 1;    % [-]
                
                % time without water supply
                this.cxCultures{i, 1}.Growth.TimeWithoutH2O         = 0;    % [s]
                
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
            % skip the first tick, V-HAB has some issues there, safety
            % measure. Can be deleted if no more issues
            if this.oTimer.iTick == 0
                return;
            end
            
            % The update only will be conducted every minute!
            % Necessary for proper "integration"
            % TODO: FIND OUT WHY!!!!
            if mod(this.oTimer.fTime, 60)~= 0;
                return;
            end
            
            % get density of liquid water, required for calculating plant 
            % transpiration
            tH2O.sSubstance = 'H2O';
            tH2O.sProperty = 'Density';
            tH2O.sFirstDepName = 'Pressure';
            tH2O.fFirstDepValue = this.oParent.fPressureAtmosphere;
            tH2O.sSecondDepName = 'Temperature';
            tH2O.fSecondDepValue = this.oParent.fTemperatureLight;
            tH2O.sPhaseType = 'liquid';
            
            fDensityH2O = this.oMT.findProperty(tH2O);
            
            % loop over all plant cultures to call the processing function
            % for each 
            % TODO: make it a parfor loop, but those things are nasty not
            % accepting structs etc., need to learn more about parfor,
            % doing regular for-loop for now, but definitely want to make
            % it parfor in the future!!! 
            aiIndex = size(this.cxCultures);
            
            for iI = 1:aiIndex(1)
                % calculate plant growth, harvested biomass is returned as
                % biomass in cxCultures is overwritten to zero after 
                % harvest by called function
                [ fHarvestedEdibleDry, ...      % [kg]
                fHarvestedEdibleWet, ...        % [kg]
                fHarvestedInedibleDry, ...      % [kg]
                fHarvestedInedibleWet ] ...     % [kg]
                    = components.PlantModule.Process_PlantGrowthParameters_IMPROVED(...
                        this.cxCultures{iI}, ...                    % Culture in question
                        this.oParent.oAtmosphereReference, ...      % Reference to atmosphere phase
                        this.oTimer.fTime, ...                      % Passed total simulated time               [s]     (was in minutes)
                        this.oParent.fTemperatureLight, ...         % Atmosphere temperature light period       [°C]
                        this.oParent.fTemperatureDark, ...          % Atmosphere temperature dark period        [°C]
                        this.oParent.fWaterAvailable, ...           % Water mass available                      [kg]
                        this.oParent.fRelativeHumidityLight, ...    % Relative humidity light period            [-]
                        this.oParent.fRelativeHumidityDark, ...     % Relative humidity dark period             [-]
                        this.oParent.fPressureAtmosphere, ...       % Atmosphere Total Pressure                 [Pa]
                        this.oParent.fCO2, ...                      % CO2 concentration                         [µmol/mol]
                        this.oParent.fPPF, ...                      % Photosynthetic photon flux                [µmol/m^2s]
                        this.oParent.fH, ...                        % Photoperiod                               [h/d]
                        fDensityH2O);                               % Liquid water density (for transpiration)  [kg/m^3] 
                
%                 % if something has been harvested, add to the according
%                 % species in the biomass array
%                 if afHarvested(iI) ~=0
                    % TODO: maybe there is a better method than using
                    % switch?
                    switch this.cxCultures{iI}.PlantData.PlantSpecies
                        % Drybean
                        case 1
                            this.afPartials(tiN2I.DrybeanEdibleDry, iI)     = this.afPartials(tiN2I.DrybeanEdibleDry, iI)       + fHarvestedEdibleDry;
                            this.afPartials(tiN2I.DrybeanEdibleFluid, iI)   = this.afPartials(tiN2I.DrybeanEdibleFluid, iI)     + fHarvestedEdibleWet;
                            this.afPartials(tiN2I.DrybeanInedibleDry, iI)   = this.afPartials(tiN2I.DrybeanInedibleDry, iI)     + fHarvestedInedibleDry;
                            this.afPartials(tiN2I.DrybeanInedibleFluid, iI) = this.afPartials(tiN2I.DrybeanInedibleFluid, iI)   + fHarvestedInedibleWet;
                            
                        % Lettuce
                        case 2
                            this.afPartials(tiN2I.LettuceEdibleDry, iI)     = this.afPartials(tiN2I.LettuceEdibleDry, iI)       + fHarvestedEdibleDry;
                            this.afPartials(tiN2I.LettuceEdibleFluid, iI)   = this.afPartials(tiN2I.LettuceEdibleFluid, iI)     + fHarvestedEdibleWet;
                            this.afPartials(tiN2I.LettuceInedibleDry, iI)   = this.afPartials(tiN2I.LettuceInedibleDry, iI)     + fHarvestedInedibleDry;
                            this.afPartials(tiN2I.LettuceInedibleFluid, iI) = this.afPartials(tiN2I.LettuceInedibleFluid, iI)   + fHarvestedInedibleWet;
                            
                        % Peanut
                        case 3
                            this.afPartials(tiN2I.PeanutEdibleDry, iI)      = this.afPartials(tiN2I.PeanutEdibleDry, iI)        + fHarvestedEdibleDry;
                            this.afPartials(tiN2I.PeanutEdibleFluid, iI)    = this.afPartials(tiN2I.PeanutEdibleFluid, iI)      + fHarvestedEdibleWet;
                            this.afPartials(tiN2I.PeanutInedibleDry, iI)    = this.afPartials(tiN2I.PeanutInedibleDry, iI)      + fHarvestedInedibleDry;
                            this.afPartials(tiN2I.PeanutInedibleFluid, iI)  = this.afPartials(tiN2I.PeanutInedibleFluid, iI)    + fHarvestedInedibleWet;
                            
                        % Rice
                        case 4
                            this.afPartials(tiN2I.RiceEdibleDry, iI)        = this.afPartials(tiN2I.RiceEdibleDry, iI)          + fHarvestedEdibleDry;
                            this.afPartials(tiN2I.RiceEdibleFluid, iI)      = this.afPartials(tiN2I.RiceEdibleFluid, iI)        + fHarvestedEdibleWet;
                            this.afPartials(tiN2I.RiceInedibleDry, iI)      = this.afPartials(tiN2I.RiceInedibleDry, iI)        + fHarvestedInedibleDry;
                            this.afPartials(tiN2I.RiceInedibleFluid, iI)    = this.afPartials(tiN2I.RiceInedibleFluid, iI)      + fHarvestedInedibleWet;
                            
                        % Soybean
                        case 5
                            this.afPartials(tiN2I.SoybeanEdibleDry, iI)     = this.afPartials(tiN2I.SoybeanEdibleDry, iI)       + fHarvestedEdibleDry;
                            this.afPartials(tiN2I.SoybeanEdibleFluid, iI)   = this.afPartials(tiN2I.SoybeanEdibleFluid, iI)     + fHarvestedEdibleWet;
                            this.afPartials(tiN2I.SoybeanInedibleDry, iI)   = this.afPartials(tiN2I.SoybeanInedibleDry, iI)     + fHarvestedInedibleDry;
                            this.afPartials(tiN2I.SoybeanInedibleFluid, iI) = this.afPartials(tiN2I.SoybeanInedibleFluid, iI)   + fHarvestedInedibleWet;
                            
                        % Sweet Potato
                        case 6
                            this.afPartials(tiN2I.SweetpotatoEdibleDry, iI)         = this.afPartials(tiN2I.SweetpotatoEdibleDry, iI)       + fHarvestedEdibleDry;
                            this.afPartials(tiN2I.SweetpotatoEdibleFluid, iI)       = this.afPartials(tiN2I.SweetpotatoEdibleFluid, iI)     + fHarvestedEdibleWet;
                            this.afPartials(tiN2I.SweetpotatotInedibleDry, iI)      = this.afPartials(tiN2I.SweetpotatotInedibleDry, iI)    + fHarvestedInedibleDry;
                            this.afPartials(tiN2I.SweetpotatotInedibleFluid, iI)    = this.afPartials(tiN2I.SweetpotatotInedibleFluid, iI)  + fHarvestedInedibleWet;
                           
                        % Tomato
                        case 7
                            this.afPartials(tiN2I.TomatoEdibleDry, iI)      = this.afPartials(tiN2I.TomatoEdibleDry, iI)        + fHarvestedEdibleDry;
                            this.afPartials(tiN2I.TomatoEdibleFluid, iI)    = this.afPartials(tiN2I.TomatoEdibleFluid, iI)      + fHarvestedEdibleWet;
                            this.afPartials(tiN2I.TomatoInedibleDry, iI)    = this.afPartials(tiN2I.TomatoInedibleDry, iI)      + fHarvestedInedibleDry;
                            this.afPartials(tiN2I.TomatoInedibleFluid, iI)  = this.afPartials(tiN2I.TomatoInedibleFluid, iI)    + fHarvestedInedibleWet;
                            
                        % Wheat
                        case 8
                            this.afPartials(tiN2I.WheatEdibleDry, iI)       = this.afPartials(tiN2I.WheatEdibleDry, iI)     + fHarvestedEdibleDry;
                            this.afPartials(tiN2I.WheatEdibleFluid, iI)     = this.afPartials(tiN2I.WheatEdibleFluid, iI)   + fHarvestedEdibleWet;
                            this.afPartials(tiN2I.WheatInedibleDry, iI)     = this.afPartials(tiN2I.WheatInedibleDry, iI)   + fHarvestedInedibleDry;
                            this.afPartials(tiN2I.WheatInedibleFluid, iI)   = this.afPartials(tiN2I.WheatInedibleFluid, iI) + fHarvestedInedibleWet;
                            
                        % White Potato
                        case 9
                            this.afPartials(tiN2I.WhitepotatoEdibleDry, iI)     = this.afPartials(tiN2I.WhitepotatoEdibleDry, iI)       + fHarvestedEdibleDry;
                            this.afPartials(tiN2I.WhitepotatoEdibleFluid, iI)   = this.afPartials(tiN2I.WhitepotatoEdibleFluid, iI)     + fHarvestedEdibleWet;
                            this.afPartials(tiN2I.WhitepotatoInedibleDry, iI)   = this.afPartials(tiN2I.WhitepotatoInedibleDry, iI)     + fHarvestedInedibleDry;
                            this.afPartials(tiN2I.WhitepotatoInedibleFluid, iI) = this.afPartials(tiN2I.WhitepotatoInedibleFluid, iI)   + fHarvestedInedibleWet;
                    end
                    
                    % Log total values for O2, CO2 and H2O gas exchange and
                    % water consumption
                    this.fO2ProducedTotal       = this.fO2ProducedTotal     + this.cxCultures{iI}.Growth.O2Exchange;
                    this.CO2ConsumedTotal       = this.CO2ConsumedTotal     + this.cxCultures{iI}.Growth.CO2Exchange;
                    this.H2OTranspiredTotal     = this.H2OTranspiredTotal   + this.cxCultures{iI}.Growth.H2OExchange;
                    this.WaterConsumedTotal     = this.WaterConsumedTotal   + this.cxCultures{iI}.Growth.WaterNeed;
                    
                    % set flowrates for manipulator to exchange with
                    % atmosphere (sum over all culture specific flowrates).
                    % CO2 flowrate is negative because it is pulled from
                    % the atmosphere, not inserted. 
                    this.fO2Exchange = this.fO2Exchange + this.cxCultures{iI}.Growth.O2Exchange;
                    this.fCO2Exchange = this.fCO2Exchange + (-1) * this.cxCultures{iI}.Growth.CO2Exchange;
                    this.fH2OExchange = this.fH2OExchange + this.cxCultures{iI}.Growth.H2OExchange;
                    this.fWaterNeed = this.fWaterNeed + this.cxCultures{iI}.Growth.WaterNeed;
%                 end
            end
            
            % convert flowrates to mass (multiplay with 60 since the
            % manipulator is called every minute)
            this.afPartials(1, this.oMT.tiN2I.O2)    = this.fO2Exchange * 60;
            this.afPartials(1, this.oMT.tiN2I.CO2)   = this.fCO2Exchange * 60;
            this.afPartials(1, this.oMT.tiN2I.H2O)   = (this.fH2OExchange - this.fWaterNeed) * 60;
                  
            % get current timestep
            fTimeStep = this.oTimer.fTime - this.fLastUpdate;
                    
            % this is where mass enters the plants phase?? yep
            % divide by current timestep to get kg/s flowrates into plants 
            % phase until next manipulator update
            afPartialFlows = this.afPartials ./ fTimeStep;
                    
            % write remember current time for next timestep
            % calculation
            this.fLastUpdate = this.oTimer.fTime;
                   
            % update the manipulator with the current flowrates
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
end
    
    