function [  ] = ...
    PlantGrowth(...
        oCulture, fDensityAtmosphere, fTemperatureAtmosphere, fRelativeHumidityAtmosphere, fHeatCapacityAtmosphere, fDensityH2O, fCO2)

    % get the 8 parameters via MMEC and FAO model equations
    [ oCulture ] = ...
        tutorials.LunarGreenhouseMMEC.components.CalculateMMECRates(...
            oCulture, ...                   % current culture object
            fDensityAtmosphere, ...                     % atmosphere density
            fTemperatureAtmosphere, ...                 % atmosphere temperature
            fRelativeHumidityAtmosphere, ...            % atmosphere relative humidity
            fHeatCapacityAtmosphere, ...                % atmosphere heat capacity
            fDensityH2O, ...                            % density of liquid water under atmosphere conditions
            fCO2);                                      % CO2 concentration in ppm
        
    %
    if fSimTime >= oCulture.txInput.fEmergeTime
        % growth if current generation does not exceed maximum 
        if oCulture.iInternalGeneration <= oCulture.txInput.iConsecutiveGenerations
            % growth if time since planting is lower than harvest time
            if oCulture.fInternalTime < oCulture.txInput.fHarvestTime
                % check if CO2 level is within model boundary, get MMEC
                % flow and growth rates
                if (fCO2 >= 330) && (fCO2 <= 1300)
                    
                    % get the 8 parameters via MMEC and FAO model equations
                    [ oCulture ] = ...
                        tutorials.LunarGreenhouseMMEC.components.CalculateMMECRates(...
                            oCulture, ...                       % current culture object
                            fDensityAtmosphere, ...             % atmosphere density
                            fTemperatureAtmosphere, ...         % atmosphere temperature
                            fRelativeHumidityAtmosphere, ...    % atmosphere relative humidity
                            fHeatCapacityAtmosphere, ...        % atmosphere heat capacity
                            fDensityH2O, ...                    % density of liquid water under atmosphere conditions
                            fCO2);                              % atmosphere CO2 concentration in ppm
                
                % out of boundary, but not too much. assume proper growth
                % still, using maximum value
                elseif (fCO2 > 1300) && (fCO2 < 3000)
                   % get the 8 parameters via MMEC and FAO model equations
                    [ oCulture ] = ...
                        tutorials.LunarGreenhouseMMEC.components.CalculateMMECRates(...
                            oCulture, ...                               % current culture object
                            fDensityAtmosphere, ...                     % atmosphere density
                            fTemperatureAtmosphere, ...                 % atmosphere temperature
                            fRelativeHumidityAtmosphere, ...            % atmosphere relative humidity
                            fHeatCapacityAtmosphere, ...                % atmosphere heat capacity
                            fDensityH2O, ...                            % density of liquid water under atmosphere conditions
                            oCulture.txPlantParameters.fCO2_Ref_Max);   % maximum CO2 concentration in ppm
                        
                % out of boundary, but not too much. assume proper growth
                % still, using minimum value
                elseif (fCO2 < 330) && (fCO2 > 150)
                    % get the 8 parameters via MMEC and FAO model equations
                    [ oCulture ] = ...
                        tutorials.LunarGreenhouseMMEC.components.CalculateMMECRates(...
                            oCulture, ...                               % current culture object
                            fDensityAtmosphere, ...                     % atmosphere density
                            fTemperatureAtmosphere, ...                 % atmosphere temperature
                            fRelativeHumidityAtmosphere, ...            % atmosphere relative humidity
                            fHeatCapacityAtmosphere, ...                % atmosphere heat capacity
                            fDensityH2O, ...                            % density of liquid water under atmosphere conditions
                            oCulture.txPlantParameters.fCO2_Ref_Min);   % minimum CO2 concentration in ppm
                
                % too far out of boundary
                else
                    % set all MMEC rates to zero
                    % TODO: need proper safety mode, flowrates = 0 does not
                    % prevent prevent plant time from increasing and so on
                    oCulture.tfMMECRates = 0;
                end
                
                %% Calculate Culture Mass Transfer Rates
                
                %
                oCulture.tfGasExchangeRates.fO2ExchangeRate = ;
                oCulture.tfGasExchangeRates.fCO2ExchangeRate = ;
                oCulture.tfGasExchangeRates.fTranspirationRate = ;
                
                %
                oCulture.fWaterConsumptionRate = ;
                
                %
                oCulture.fNutrientConsumptionRate = ;
                
                %
                oCulture.tfBiomassGrowthRates.fGrowthRateEdible = ;
                oCulture.tfBiomassGrowthRates.fGrowthRateInedible = ;
            end
        end
    end
end

