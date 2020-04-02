function [ oCulture ] =  PlantGrowth( oCulture, fSimTime)

    % gets some required parameters for the calculation from the culture
    % object
    fDensityAtmosphere              = oCulture.oAtmosphere.fDensity;
    fPressureAtmosphere             = oCulture.oAtmosphere.fMass * oCulture.oAtmosphere.fMassToPressure;
    fRelativeHumidityAtmosphere     = oCulture.oAtmosphere.rRelHumidity;
    fHeatCapacityAtmosphere         = oCulture.oAtmosphere.oCapacity.fSpecificHeatCapacity;
    fCO2                            = oCulture.fCO2;
    
    % calculate density of liquid H2O, required for transpiration
    tH2O.sSubstance         = 'H2O';
    tH2O.sProperty          = 'Density';
    tH2O.sFirstDepName      = 'Pressure';
    tH2O.fFirstDepValue     = oCulture.oAtmosphere.fPressure;
    tH2O.sSecondDepName     = 'Temperature';
    tH2O.fSecondDepValue    = oCulture.oAtmosphere.fTemperature;
    tH2O.sPhaseType         = 'liquid';

    fDensityH2O = oCulture.oMT.findProperty(tH2O);
    
    % growth if current generation does not exceed maximum 
    if oCulture.iInternalGeneration <= oCulture.txInput.iConsecutiveGenerations
        % growth if time since planting is lower than harvest time
        if (oCulture.fInternalTime < oCulture.txInput.fHarvestTime * 86400) && (oCulture.iState == 1)

            % calculate internal time (time since planting) for the
            % current culture
            oCulture.fInternalTime = fSimTime - oCulture.fSowTime;

            % check if CO2 level is within model boundary, get MMEC
            % flow and growth rates
            if (fCO2 >= 330) && (fCO2 <= 1300)

                % get the 8 parameters via MMEC and FAO model equations
                [ oCulture ] = ...
                    components.matter.PlantModuleV2.CalculateMMECRates(...
                        oCulture, ...                       % current culture object
                        fPressureAtmosphere, ...            % atmosphere pressure
                        fDensityAtmosphere, ...             % atmosphere density
                        fRelativeHumidityAtmosphere, ...    % atmosphere relative humidity
                        fHeatCapacityAtmosphere, ...        % atmosphere heat capacity
                        fDensityH2O, ...                    % density of liquid water under atmosphere conditions
                        fCO2);                              % atmosphere CO2 concentration in ppm

            % out of boundary, but not too much. assume proper growth
            % still, using maximum value
            elseif (fCO2 > 1300) 
               % get the 8 parameters via MMEC and FAO model equations
                [ oCulture ] = ...
                    components.matter.PlantModuleV2.CalculateMMECRates(...
                        oCulture, ...                               % current culture object
                        fPressureAtmosphere, ...                    % atmosphere pressure
                        fDensityAtmosphere, ...                     % atmosphere density
                        fRelativeHumidityAtmosphere, ...            % atmosphere relative humidity
                        fHeatCapacityAtmosphere, ...                % atmosphere heat capacity
                        fDensityH2O, ...                            % density of liquid water under atmosphere conditions
                        oCulture.txPlantParameters.fCO2_Ref_Max);   % maximum CO2 concentration in ppm

            % out of boundary, but not too much. assume proper growth
            % still, using minimum value
            elseif (fCO2 < 330) && (fCO2 > 150)
                % get the 8 parameters via MMEC and FAO model equations
                [ oCulture ] = ...
                    components.matter.PlantModuleV2.CalculateMMECRates(...
                        oCulture, ...                               % current culture object
                        fPressureAtmosphere, ...                    % atmosphere pressure
                        fDensityAtmosphere, ...                     % atmosphere density
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
            oCulture.tfGasExchangeRates.fO2ExchangeRate         = (oCulture.tfMMECRates.fOP - oCulture.tfMMECRates.fOC)     * oCulture.txInput.fGrowthArea;
            oCulture.tfGasExchangeRates.fCO2ExchangeRate        = (oCulture.tfMMECRates.fCO2P - oCulture.tfMMECRates.fCO2C) * oCulture.txInput.fGrowthArea;
            oCulture.tfGasExchangeRates.fTranspirationRate      = oCulture.tfMMECRates.fTR                                  * oCulture.txInput.fGrowthArea;

            oCulture.fWaterConsumptionRate                      = oCulture.tfMMECRates.fWC                                  * oCulture.txInput.fGrowthArea;
            oCulture.fNutrientConsumptionRate                   = oCulture.tfMMECRates.fNC                                  * oCulture.txInput.fGrowthArea;


            %% Biomass Growth               
            % If internaltime of considered culture's growth cycle
            % exceeds tE (time at onset of edible biomass)
            if oCulture.fInternalTime >= oCulture.txPlantParameters.fT_E * 86400
                % Mass balance of biomass uptake when exceeding tE
                % TODO: JUST GROWTH RATES! actual growth happens 
                % inside the plant module exec() function

                oCulture.tfBiomassGrowthRates.fGrowthRateEdible     = (oCulture.tfMMECRates.fCGR * oCulture.txInput.fGrowthArea * oCulture.txPlantParameters.fXFRT) * (oCulture.txPlantParameters.fFBWF_Edible + 1);
                oCulture.tfBiomassGrowthRates.fGrowthRateInedible   = (oCulture.tfMMECRates.fCGR * oCulture.txInput.fGrowthArea * (1 - oCulture.txPlantParameters.fXFRT)) * (oCulture.txPlantParameters.fFBWF_Inedible + 1);

                % If tE is not exceeded yet, only inedible biomass is created 
                % (and therefore contributes to the total crop biomass (TCB) solely)
            else
                % Mass balance of biomass uptake before tE
                oCulture.tfBiomassGrowthRates.fGrowthRateEdible = 0;  
                % In this case only inedible mass is generated anyway
                % so we can just use the wet crop growth rate
                % calculated in the MEC function directly
                oCulture.tfBiomassGrowthRates.fGrowthRateInedible = (oCulture.tfMMECRates.fWCGR * oCulture.txInput.fGrowthArea);                                       
            end   

            if any(isnan(oCulture.tfBiomassGrowthRates.fGrowthRateEdible)) || any(isnan(oCulture.tfBiomassGrowthRates.fGrowthRateInedible))
                keyboard()
            end

            % Function needed in order to be able to verify plant
            % module vs data stated in the BVAD


            % add Edible and Inedible Wet Biomass to Water Consumption
            % Rate in Order to close mass balance! (WCGR in MMEC Modell
            % substracted since it is assumed to be wrong)!
            oCulture.fWaterConsumptionRate =  oCulture.fWaterConsumptionRate  + oCulture.tfBiomassGrowthRates.fGrowthRateEdible + oCulture.tfBiomassGrowthRates.fGrowthRateInedible ;

            %components.matter.PlantModuleV2.functions.Plant_Module_Verification(oCulture);


        % harvest time reached -> change state to harvest   
        else
            % if first time entering this section (= growth state until
            % now), to only change state once
            if oCulture.iState == 1
                % set culture state to harvest
                oCulture.iState = 2;

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
            else

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

        end
    end
    
    % For debugging, if the mass balance is no longer correct
    if oCulture.fWaterConsumptionRate > 0
        fBalance = oCulture.tfGasExchangeRates.fO2ExchangeRate + oCulture.tfGasExchangeRates.fCO2ExchangeRate + oCulture.tfGasExchangeRates.fTranspirationRate + ...
         (oCulture.tfBiomassGrowthRates.fGrowthRateInedible + oCulture.tfBiomassGrowthRates.fGrowthRateEdible) ...
         - (oCulture.fWaterConsumptionRate + oCulture.fNutrientConsumptionRate);

        if abs(fBalance) > 1e-10
            keyboard()
        end
    end
end