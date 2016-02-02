function [ fHarvestedEdibleWet, fHarvestedInedibleWet ] = ...
    Process_PlantGrowthParameters_IMPROVED(cxCulture, fTime, fTemperatureLight, fTemperatureDark, fWaterAvailable, fRelativeHumidityLight, fRelativeHumidityDark, fPressureAtmosphere, fCO2ppm, fPPF, fH, fDensityH2O)

    % Harvested biomass variables are always zero except when harvested,
    % then they are assigned according masses to be returned to the
    % manipulator
    fHarvestedEdibleWet = 0;
    fHarvestedInedibleWet = 0;
    
    % check if culture is allowed to grow
    if cxCulture.Growth.InternalGeneration <= cxCulture.PlantData.AmountOfConsecutiveGenerations
        % check if simulation reached planting time
        if fTime >= cxCulture.Growth.emerge_time
            % harvest time not yet reached -> plants grow
            if cxCulture.Growth.InternalTime < cxCulture.PlantData.harv_time
                % internal plant time from planting to harvest
                cxCulture.Growth.InternalTime = fTime - (cxCulture.Growth.InternalGeneration - 1) * cxCulture.PlantData.harv_time - cxCulture.Growth.emerge_time;
                
                % check if CO2 concentration is within the limits for the
                % MEC model (330 - 1300 ppm)
                if fCO2ppm > 330 && fCO2ppm < 1300
                    % time after emergence? (irritating comments), required
                    % for Calculate_PlantGrowthRates function call
                    tA = [1/CO2 1 CO2 CO2^2 CO2^3] * cxCulture.PlantData.matrix_tA * [1/PPF; 1; PPF; PPF^2; PPF^3];
                    
                    
                else
                    
                end
            % harvest time reached -> plants are harvested
            else
                
            end
        end
    end
end