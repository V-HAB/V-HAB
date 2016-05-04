function [ oCulture ] = ...
    PlantGrowth(...
        oCulture, fSimTime, fPressureAtmosphere, fDensityAtmosphere, fTemperatureAtmosphere, fRelativeHumidityAtmosphere, fHeatCapacityAtmosphere, fDensityH2O, fCO2)

%     % get the 8 parameters via MMEC and FAO model equations
%     [ oCulture ] = ...                                  % return culture object
%         tutorials.GreenhouseV2.components.CalculateMMECRates(...
%             oCulture, ...                               % current culture object
%             fPressureAtmosphere, ...                    % atmosphere pressure
%             fDensityAtmosphere, ...                     % atmosphere density
%             fTemperatureAtmosphere, ...                 % atmosphere temperature
%             fRelativeHumidityAtmosphere, ...            % atmosphere relative humidity
%             fHeatCapacityAtmosphere, ...                % atmosphere heat capacity
%             fDensityH2O, ...                            % density of liquid water under atmosphere conditions
%             fCO2);                                      % CO2 concentration in ppm
        
    % time of first emergence reached
    if fSimTime >= oCulture.txInput.fEmergeTime
        % if first time entering this section (= fallow state until now), 
        % to only change state once
        if oCulture.iState == 4
            % set culture state to growth
            oCulture.iState = 1;
        end
        
        % growth if current generation does not exceed maximum 
        if oCulture.iInternalGeneration <= oCulture.txInput.iConsecutiveGenerations
            % growth if time since planting is lower than harvest time
            if (oCulture.fInternalTime < oCulture.txInput.fHarvestTime) && (oCulture.iState == 1)
                
                % calculate internal time (time since planting) for the
                % current culture
                if oCulture.fInternalTime ~= 0    
                    oCulture.fInternalTime = fSimTime - (oCulture.iInternalGeneration - 1) * oCulture.txInput.fHarvestTime - oCulture.txInput.fEmergeTime;
                else
                    oCulture.fInternalTime = fSimTime - (oCulture.iInternalGeneration - 1) * oCulture.txInput.fHarvestTime;                            
                end
                
%                 % calculate passed time in current lighting condition
%                 if oCulture.fLighTime ~= 0
%                     oCulture.fLightTime =
%                 else
%                     oCulture.fLightTime =
%                 end
                
                % check if CO2 level is within model boundary, get MMEC
                % flow and growth rates
                if (fCO2 >= 330) && (fCO2 <= 1300)
                    
                    % get the 8 parameters via MMEC and FAO model equations
                    [ oCulture ] = ...
                        tutorials.GreenhouseV2.components.CalculateMMECRates(...
                            oCulture, ...                       % current culture object
                            fPressureAtmosphere, ...            % atmosphere pressure
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
                        tutorials.GreenhouseV2.components.CalculateMMECRates(...
                            oCulture, ...                               % current culture object
                            fPressureAtmosphere, ...                    % atmosphere pressure
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
                        tutorials.GreenhouseV2.components.CalculateMMECRates(...
                            oCulture, ...                               % current culture object
                            fPressureAtmosphere, ...                    % atmosphere pressure
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
                    oCulture.tfMMECRates.fWC = 0;
                    oCulture.tfMMECRates.fTR = 0;
                    oCulture.tfMMECRates.fOC = 0;
                    oCulture.tfMMECRates.fOP = 0;
                    oCulture.tfMMECRates.fCO2C = 0;
                    oCulture.tfMMECRates.fCO2P = 0;
                    oCulture.tfMMECRates.fNC = 0;
                    oCulture.tfMMECRates.fCGR = 0;
                end
                
                %% Calculate Culture Mass Transfer Rates
                
                % positive flowrate for plants -> atmosphere (default P2P
                % direction)
                oCulture.tfGasExchangeRates.fO2ExchangeRate = (oCulture.tfMMECRates.fOP - oCulture.tfMMECRates.fOC) * oCulture.txInput.fGrowthArea;
                oCulture.tfGasExchangeRates.fCO2ExchangeRate = (oCulture.tfMMECRates.fCO2P - oCulture.tfMMECRates.fCO2C) * oCulture.txInput.fGrowthArea;
                oCulture.tfGasExchangeRates.fTranspirationRate = oCulture.tfMMECRates.fTR * oCulture.txInput.fGrowthArea;
                
                oCulture.fWaterConsumptionRate = oCulture.tfMMECRates.fWC * oCulture.txInput.fGrowthArea;
                
                oCulture.fNutrientConsumptionRate = oCulture.tfMMECRates.fNC * oCulture.txInput.fGrowthArea;
                
                %% Biomass Growth
                
                % If internaltime of considered culture's growth cycle
                % exceeds tE (time at onset of edible biomass)
                if oCulture.fInternalTime > oCulture.txPlantParameters.fT_E  
                    % Mass balance of biomass uptake when exceeding tE
                    % TODO: JUST GROWTH RATES! actual growth happens 
                    % inside the plant module exec() function
                    oCulture.tfBiomassGrowthRates.fGrowthRateEdible = ...
                        oCulture.tfMMECRates.fCGR * oCulture.txPlantParameters.fXFRT * oCulture.txInput.fGrowthArea + ...                                                % edible dry part
                        oCulture.tfMMECRates.fCGR * oCulture.txPlantParameters.fXFRT * oCulture.txInput.fGrowthArea * oCulture.txPlantParameters.fFBWF_Edible;           % edible water part
                        
                    oCulture.tfBiomassGrowthRates.fGrowthRateInedible = ...
                        oCulture.tfMMECRates.fCGR * (1 - oCulture.txPlantParameters.fXFRT) * oCulture.txInput.fGrowthArea + ...                                          % inedible dry part
                        oCulture.tfMMECRates.fCGR * (1 - oCulture.txPlantParameters.fXFRT) * oCulture.txInput.fGrowthArea * oCulture.txPlantParameters.fFBWF_Inedible;    % inedible water part
                      
                    % If tE is not exceeded yet, only inedible biomass is created 
                    % (and therefore contributes to the total crop biomass (TCB) solely)
                else
                    % Mass balance of biomass uptake before tE
                    oCulture.tfBiomassGrowthRates.fGrowthRateEdible = 0;                                                                                    
                        
                    oCulture.tfBiomassGrowthRates.fGrowthRateInedible = ...
                        oCulture.tfMMECRates.fCGR * oCulture.txInput.fGrowthArea + ...                                          % inedible dry part
                        oCulture.tfMMECRates.fCGR * oCulture.txInput.fGrowthArea * oCulture.txPlantParameters.fFBWF_Inedible;   % inedible water part
                end   
            
            % harvest time reached -> change state to harvest   
            else
                % if first time entering this section (= growth state until
                % now), to only change state once
                if oCulture.iState == 1
                    % set culture state to harvest
                    oCulture.iState = 2;
                    
                    % plants stop everything during harvest! this is to
                    % properly empty the culture phase and to prevent
                    % screwing up the mass balance.
                    % TODO: maybe gradually scale down later (e.g. one
                    % third harvested -> everything on 2 thirds
                    % effectiveness). Need to apply properly to everything
                    % to maintain mass balance as well as find a solution
                    % to still empty the phase completely if something
                    % grows during harvest.
                    
                    % get fieldnames for loop
                    csFieldNames = fieldnames(oCulture.tfMMECRates);
                    
                    % set all entries of tfMMECRates to zero
                    for iI = 1:length(csFieldNames)
                        oCulture.tfMMECRates.(csFieldNames{iI}) = 0;
                    end
                    
                    % set the resulting flow rates to zero too, small
                    % structs so no loops
                    oCulture.fWaterConsumptionRate = 0;
                    oCulture.fNutrientConsumptionRate = 0;
                    
                    oCulture.tfGasExchangeRates.fO2ExchangeRate = 0;
                    oCulture.tfGasExchangeRates.fCO2ExchangeRate = 0;
                    oCulture.tfGasExchangeRates.fTranspirationRate = 0;
                    
                    oCulture.tfBiomassGrowthRates.fGrowthRateEdible = 0;
                    oCulture.tfBiomassGrowthRates.fGrowthRateInedible = 0;
                end
                
                % TODO: something else needed to stop plant growth/exchange
            end
        end
    end
end