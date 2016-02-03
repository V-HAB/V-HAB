function [ fHarvestedEdibleWet, fHarvestedInedibleWet ] = ...
    Process_PlantGrowthParameters_IMPROVED(cxCulture, oAtmosphereReference, fTime, fTemperatureLight, fTemperatureDark, fWaterAvailable, fRelativeHumidityLight, fRelativeHumidityDark, fPressureAtmosphere, fCO2, fPPF, fH, fDensityH2O)

    % Harvested biomass variables are always zero except when harvested,
    % then they are assigned according masses to be returned to the
    % manipulator
    fHarvestedEdibleWet = 0;
    fHarvestedInedibleWet = 0;
    
    % check if culture is allowed to grow
    if cxCulture.Growth.InternalGeneration <= cxCulture.PlantData.ConsecutiveGenerations
        % check if simulation reached planting time
        if fTime >= cxCulture.Growth.EmergeTime
            % harvest time not yet reached -> plants grow
            if cxCulture.Growth.InternalTime < cxCulture.PlantData.HarvestTime
                % internal plant time from planting to harvest
                cxCulture.Growth.InternalTime = fTime - (cxCulture.Growth.InternalGeneration - 1) * cxCulture.PlantData.HarvestTime - cxCulture.Growth.EmergeTime;
                
                % check if CO2 concentration is within the limits for the
                % MEC model (330 - 1300 ppm)
                if fCO2 > 330 && fCO2 < 1300
                    % time after canopy closure, required for 
                    % Calculate_PlantGrowthRates function call
                    fT_A = [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * cxCulture.PlantData.Matrix_T_A * [1/fPPF; 1; fPPF; fPPF^2; fPPF^3];
                    
                    [ fHOP_Net, ...     % net hourly oxygen production      % [g/m^2h]
                    fHCC_Net, ...       % net hourly carbon consumption     % [g/m^2h]
                    fHCGR, ...          % hourly crop growth rate           % [g/m^2h]
                    fHTR, ...           % hourly transpiration rate         % [g/m^2h]
                    fHWC ] ...          % hourly water consumption          % [g/m^2h]
                        = components.PlantModule.Process_PlantGrowthRates(...
                            cxCulture, ...                  % current culture data
                            oAtmosphereReference, ...       % reference to atmosphere phase
                            fTime, ...                      % passed total simulation time                  [s]
                            fT_A, ...                       % time after canopy closure                     [s]
                            fTemperatureLight, ...          % atmosphere temperature light period           [°C]
                            fTemperatureDark, ...           % atmosphere temperature dark period            [°C]
                            fWaterAvailable, ...            % water mass available                          [kg]
                            fRelativeHumidityLight, ...     % atmosphere humidity light period              [-]
                            fRelativeHumidityDark, ...      % atmosphere humidity dark period               [-]
                            fPressureAtmosphere, ...        % atmosphere total pressure                     [Pa]
                            fCO2, ...                       % atmosphere CO2 concentration                  [µmol/mol]
                            fPPF, ...                       % photosynthetic photon flux, plant lighting    [µmol/m^2s]
                            fH, ...                         % photoperiod                                   [h/d]
                            fDensityH2O);                   % liquid water density                          [kg/m^3]
                    
                else
                    
                end
            % harvest time reached -> plants are harvested
            else
                
            end
        end
    end
end