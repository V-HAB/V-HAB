function [ fHarvestedEdibleDry, fHarvestedEdibleWet, fHarvestedInedibleDry, fHarvestedInedibleWet ] = ...
    Process_PlantGrowthParameters_IMPROVED(cxCulture, oAtmosphereReference, fTime, fTemperatureLight, fTemperatureDark, fWaterAvailable, fRelativeHumidityLight, fRelativeHumidityDark, fPressureAtmosphere, fCO2, fPPF, fH, fDensityH2O)

    % Harvested biomass variables are always zero except when harvested,
    % then they are assigned according masses to be returned to the
    % manipulator
    fHarvestedEdibleDry = 0;
    fHarvestedEdibleWet = 0;
    fHarvestedInedibleDry = 0;
    fHarvestedInedibleWet = 0;
    
    %
    fHourlyRatesToSeconds = 1 / 3600;   % [s/h]
    fDaysToSeconds = 24 * 3600;         % [s/d]
    
    % check if culture is allowed to grow
    if cxCulture.Growth.InternalGeneration <= cxCulture.PlantData.ConsecutiveGenerations
        % check if simulation reached planting time
        if fTime >= cxCulture.PlantData.EmergeTime
            % harvest time not yet reached -> plants grow
            if cxCulture.Growth.InternalTime < cxCulture.PlantData.HarvestTime
                % internal plant time from planting to harvest
                cxCulture.Growth.InternalTime = fTime - (cxCulture.Growth.InternalGeneration - 1) * cxCulture.PlantData.HarvestTime - cxCulture.PlantData.EmergeTime;
                
                % check if CO2 concentration is within the limits for the
                % MEC model (330 - 1300 ppm)
                if (fCO2 > 330) && (fCO2 < 1300)
                    % time after canopy closure, required for 
                    % Calculate_PlantGrowthRates function call
                    fT_A = [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).Matrix_T_A * [1/fPPF; 1; fPPF; fPPF^2; fPPF^3];
                    
                    [ fHOP_Net, ...     % net hourly oxygen production      % [g/m^2h]
                    fHCC_Net, ...       % net hourly carbon consumption     % [g/m^2h]
                    fHCGR_Dry, ...      % hourly crop growth rate           % [g/m^2h]
                    fHTR, ...           % hourly transpiration rate         % [g/m^2h]
                    fHWC ] ...          % hourly water consumption          % [g/m^2h]
                        = components.PlantModule.Calculate_PlantGrowthRates_IMPROVED(...
                            cxCulture, ...                  % current culture data
                            oAtmosphereReference, ...       % reference to atmosphere phase
                            fTime, ...                      % passed total simulation time                  [s]
                            fT_A, ...                       % time after canopy closure                     [s]
                            fTemperatureLight, ...          % atmosphere temperature light period           [°C]
                            fTemperatureDark, ...           % atmosphere temperature dark period            [°C]
                            fRelativeHumidityLight, ...     % atmosphere humidity light period              [-]
                            fRelativeHumidityDark, ...      % atmosphere humidity dark period               [-]
                            fPressureAtmosphere, ...        % atmosphere total pressure                     [Pa]
                            fCO2, ...                       % atmosphere CO2 concentration                  [µmol/mol]
                            fPPF, ...                       % photosynthetic photon flux, plant lighting    [µmol/m^2s]
                            fH, ...                         % photoperiod                                   [h/d]
                            fDensityH2O);                   % liquid water density                          [kg/m^3]
                    
                    % Fresh basis water factor (FBWF) 
                    % - HCGR is the DRY biomass uptake. So with this factor the fluid uptake is estimated
                    %  From plant parameters: FBWF = WBF/(1-WBF),  % [kg_fluid/kg_dry]  (WBF =  water biomass fraction)
                    %  -This fractions are valid for calculating EDIBLE biomass fluid uptake

                    switch cxCulture.PlantData.PlantSpecies
                        case 'Drybean'
                            fFBWF_Edible = 10/90;       % [kg_fluid/kg_dry]
                        case 'Lettuce'
                            fFBWF_Edible = 95/5;        % [kg_fluid/kg_dry]
                        case 'Peanut' 
                            fFBWF_Edible = 5.6/94.4;    % [kg_fluid/kg_dry]
                        case 'Rice'
                            fFBWF_Edible = 12/88;       % [kg_fluid/kg_dry]
                        case 'Soybean'
                            fFBWF_Edible = 10/90;       % [kg_fluid/kg_dry]
                        case 'Sweetpotato'
                            fFBWF_Edible = 71/29;       % [kg_fluid/kg_dry]
                        case 'Tomato'
                            fFBWF_Edible = 94/6;        % [kg_fluid/kg_dry]
                        case 'Wheat'
                            fFBWF_Edible = 12/88;       % [kg_fluid/kg_dry]
                        case 'Whitepotato'
                            fFBWF_Edible = 80/20;       % [kg_fluid/kg_dry]
                    end
                    
                    %  -Inedible biomass water content (WBF) is always assumed to be 90%
                    %   (Source: Baseline values and assumptions document (BVAD). Table 4.98)
                    %   -> so the FBWF factor for INEDIBLE fluid biomass would be 90%/10% = 9                            
                    fFBWF_Inedible = 90/10;             % [kg_fluid/kg_dry]
                    
                    % water_exchange: water vapor transpired from the
                    % plant, factor 1000 to get kg
                    cxCulture.Growth.H2OExchange = fHTR / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea; % [kg/s]

                    % WaterNeed --> HWC [g/m^2/d], factor 1000 to get kg
                    cxCulture.Growth.WaterNeed = fHWC / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea;  % [kg/s]

                    % TODO: needs to be reworked, maybe can make it use the
                    % current timestep to make timestep independent
                    % As long as water is available, conduct growth calculations
                    if (fWaterAvailable > cxCulture.Growth.WaterNeed) && (cxCulture.Growth.TimeWithoutH2O <= fDaysToSeconds)
                        % if tE is exceeded, edible biomass is produced as
                        % well as inedible biomass
                        if cxCulture.Growth.InternalTime > components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_E
                            
                            %
                            cxCulture.Harvest.EdibleDryBiomass = ...
                                cxCulture.Harvest.EdibleDryBiomass + ...
                                components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).XFRT * fHCGR_Dry / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea;                              
                            cxCulture.Harvest.EdibleWetBiomass = ...
                                cxCulture.Harvest.EdibleWetBiomass + ...
                                fFBWF_Edible * components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).XFRT * fHCGR_Dry / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea;                  
                            cxCulture.Harvest.InedibleDryBiomass = ...
                                cxCulture.Harvest.InedibleDryBiomass + ...
                                (fHCGR_Dry - (components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).XFRT * fHCGR_Dry)) / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea;                  
                            cxCulture.Harvest.InedibleWetBiomass = ...
                                cxCulture.Harvest.InedibleWetBiomass + ...
                                fFBWF_Inedible * (fHCGR_Dry - (components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).XFRT * fHCGR_Dry)) / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea;   
                            
                            % Log Total Crop Biomass
                            cxCulture.Growth.TCB = ...
                                cxCulture.Harvest.EdibleDryBiomass + ...
                                cxCulture.Harvest.EdibleWetBiomass + ...
                                cxCulture.Harvest.InedibleDryBiomass + ...
                                cxCulture.Harvest.InedibleWetBiomass;
                            
                            % Log Total Edible Biomass
                            cxCulture.Growth.TEB = ...
                                cxCulture.Harvest.EdibleDryBiomass + ...
                                cxCulture.Harvest.EdibleWetBiomass;
                            
                        % If tE is not exceeded yet, only inedible biomass is created 
                        % (and therefore contributes to the total crop biomass (TCB) solely)    
                        else

                            % 
                            cxCulture.Harvest.EdibleDryBiomass = 0;                                                                                    
                            cxCulture.Harvest.EdibleWetBiomass = 0;                                                                                   
                            cxCulture.Harvest.InedibleDryBiomass = ...
                                cxCulture.Harvest.InedibleDryBiomass + ...
                                fHCGR_Dry / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea;                
                            cxCulture.Harvest.InedibleWetBiomass = ...
                                cxCulture.Harvest.InedibleWetBiomass + ...
                                fFBWF_Inedible *(fHCGR_Dry / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea);   
                            
                            % Log Total Crop Biomass, only inedible
                            % biomass is produced
                            cxCulture.Growth.TCB = ...
                                cxCulture.Harvest.InedibleDryBiomass + ...
                                cxCulture.Harvest.InedibleWetBiomass;
                        end

                        % O2 Exchange per grown culture in [kg/s]
                        cxCulture.Growth.O2Exchange = fHOP_Net / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea;  

                        % CO2 Exchange per grown culture in [kg/s]
                        cxCulture.Growth.CO2Exchange = fHCC_Net / 1000 * fHourlyRatesToSeconds * cxCulture.PlantData.GrowthArea;  
                         
                    % Not enough water available for plant growth.
                    % TODO: Needs to be reworked!!!
                    % just carried over to see what has been tried to be
                    % done
                    else
                        % Attempt has been to reduce the growth and
                        % exchange rates slowely by water deficiency 
                        
                        % not enough water available, deliver message and
                        % return
                        disp('Not Enough Water');
                        return;

                        %% Old Code, needs to be reworked
                        
%                         aoPlants.state.t_without_H2O = aoPlants.state.t_without_H2O + 1;
%                         if  aoPlants.state.t_without_H2O == 1
%                             aoPlants.state.TCB_constant = aoPlants.state.TCB; % [kg]
%                             aoPlants.state.TEB_constant = aoPlants.state.TEB; % [kg]
%                         end
%                         
%                         if aoPlants.state.t_without_H2O <= 4 * aoPlants.FactorDaysToMinutes;
%                             Without_H2O_fct     = 1 - (aoPlants.state.t_without_H2O / (aoPlants.FactorDaysToMinutes * 4));
%                             if WaterAvailable - (WaterNeed * Without_H2O_fct) <=0
%                                 Without_H2O_fct = 0;
%                             end
%                         else
%                             Without_H2O_fct = 0;
%                         end
%                             WaterNeed                       = WaterNeed * Without_H2O_fct;                      % [kg/s]
%                             aoPlants.state.A                = aoPlants.state.A * Without_H2O_fct;               % [min]
%                             aoPlants.state.CUE_24           = aoPlants.state.CUE_24 * Without_H2O_fct;          % [-]
%                             aoPlants.state.TCB              = aoPlants.state.TCB_constant + (HCGR * Without_H2O_fct * aoPlants.state.extension / 60); % [kg]
%                             aoPlants.state.TEB              = aoPlants.state.TEB_constant + (HCGR * Without_H2O_fct * aoPlants.state.extension / 60); % [kg]
%                             aoPlants.state.O2_exchange      = aoPlants.state.O2_exchange * Without_H2O_fct;     % [kg/s]
%                             aoPlants.state.CO2_exchange     = aoPlants.state.CO2_exchange * Without_H2O_fct;    % [kg/s]
%                             aoPlants.state.water_exchange   = aoPlants.state.water_exchange * Without_H2O_fct;  % [kg/s]
%                             aoPlants.state.P_net            = aoPlants.state.P_net * Without_H2O_fct;           % [µmol_carbon/m^2/s]
%                             aoPlants.state.CQY              = aoPlants.state.CQY * Without_H2O_fct;             % [mumol Carbon Fixed/mumol Absorbed PPF]
                    end
                    
                % check if model limits of CO2 concentration are exceeded, 
                % position of this check is awkward and only  sets 
                % flowrates to zero, it doesn't prevent formation of
                % biomass
                % TODO: reposition and make it to prevent everything
                else
                    %% Old Code, needs to be reworked
                    
%                     if CO2_Measured > 1300
%                          disp('Warning: CO2ppm > 1300 /n');
%                         aoPlants.state.O2_exchange      = 0;    % [kg/s]
%                         aoPlants.state.CO2_exchange     = 0;    % [kg/s]
%                         aoPlants.state.water_exchange   = 0;    % [kg/s]
%                     end
% 
%                     if CO2_Measured < 330
%                        disp('Warning: CO2ppm < 330 /n');
%                         aoPlants.state.O2_exchange      = 0;    % [kg/s]
%                         aoPlants.state.CO2_exchange     = 0;    % [kg/s]
%                         aoPlants.state.water_exchange   = 0;    % [kg/s]
%                     end
                end
                
            % harvest time reached -> plants are harvested
            else
                disp('Harvesting:'); 
                
                % reset growth handling parameters
                cxCulture.Growth.A                  = 0;    % [-]
                cxCulture.Growth.CUE_24             = 0;    % [-]
                cxCulture.Growth.TCB                = 0;    % [kg]
                cxCulture.Growth.TEB                = 0;    % [kg]
                cxCulture.Growth.O2Exchange         = 0;    % [kg/s]
                cxCulture.Growth.CO2Exchange        = 0;    % [kg/s]
                cxCulture.Growth.H2OExchange        = 0;    % [kg/s]
                cxCulture.Growth.WaterNeed          = 0;    % [kg/s]
                cxCulture.Growth.InternalTime       = 0;    % [min]
                cxCulture.Growth.P_net              = 0;    % [µmol_carbon/m^2/s]
                cxCulture.Growth.CQY                = 0;    % [µmol Carbon Fixed/µmol Absorbed PPF]
                cxCulture.Growth.TimeWithoutH2O     = 0;    % [-]

                % current values of accumulated biomass are returned to the
                % manipulator signaling something has been harvested.
                % Harvest parameters are reset to zero afterwards to allow
                % for new growth
                fHarvestedEdibleDry     = cxCulture.Harvest.EdibleDryBiomass;       % [kg]
                fHarvestedEdibleWet     = cxCulture.Harvest.EdibleWetBiomass;       % [kg]
                fHarvestedInedibleDry   = cxCulture.Harvest.InedibleDryBiomass;     % [kg]
                fHarvestedInedibleWet   = cxCulture.Harvest.InedibleWetBiomass;     % [kg]
                
                % Displaying harvest information
                disp(['Culture name: ' num2str(cxCulture.CultureName) '  -  Culture internal index number: ' num2str(cxCulture.CultureNumber)] );
                disp(['Culture internal generation: '       num2str(cxCulture.Growth.InternalGeneration)]);
                disp(['Edible dry biomass harvested: '      num2str(fHarvestedEdibleDry)]);
                disp(['Edible wet biomass harvested: '      num2str(fHarvestedEdibleWet)]);
                disp(['Inedible dry biomass harvested: '    num2str(fHarvestedInedibleDry)]);
                disp(['Inedible wet biomass harvested: '    num2str(fHarvestedInedibleWet)]);
                
                % reset for next growth cycle
                cxCulture.Harvest.EdibleDryBiomass      = 0;    % [kg]
                cxCulture.Harvest.EdibleWetBiomass      = 0;    % [kg]
                cxCulture.Harvest.InedibleDryBiomass    = 0;    % [kg] 
                cxCulture.Harvest.InedibleWetBiomass    = 0;    % [kg]

                % increase internal generation count (+1)
                cxCulture.Growth.InternalGeneration = cxCulture.Growth.InternalGeneration + 1; % [-]
            end
        end
    end
end