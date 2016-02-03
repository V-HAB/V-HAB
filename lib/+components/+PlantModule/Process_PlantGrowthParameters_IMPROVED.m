function [ fHarvestedEdibleWet, fHarvestedInedibleWet ] = ...
    Process_PlantGrowthParameters_IMPROVED(cxCulture, fTime, fTemperatureLight, fTemperatureDark, fWaterAvailable, fRelativeHumidityLight, fRelativeHumidityDark, fPressureAtmosphere, fCO2, fPPF, fH, fDensityH2O)

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
                    T_A = [1/CO2 1 CO2 CO2^2 CO2^3] * cxCulture.PlantData.Matrix_T_A * [1/PPF; 1; PPF; PPF^2; PPF^3];
                    
                    
                else
                    
                end
            % harvest time reached -> plants are harvested
            else
                
            end
        end
    end
end