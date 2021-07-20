function PlantGrowth( this, fSimTime)

    % gets some required parameters for the calculation from the culture
    % object
    fDensityAtmosphere              = this.oAtmosphere.fDensity;
    fPressureAtmosphere             = this.oAtmosphere.fMass * this.oAtmosphere.fMassToPressure;
    fRelativeHumidityAtmosphere     = this.oAtmosphere.rRelHumidity;
    % Limit relative humidity to prevent unrealistic cases
    if fRelativeHumidityAtmosphere > 1
        fRelativeHumidityAtmosphere = 1;
    end
    fHeatCapacityAtmosphere         = this.oAtmosphere.oCapacity.fSpecificHeatCapacity;
    fCO2                            = this.fCO2;
    
    % calculate density of liquid H2O, required for transpiration
    tH2O.sSubstance         = 'H2O';
    tH2O.sProperty          = 'Density';
    tH2O.sFirstDepName      = 'Pressure';
    tH2O.fFirstDepValue     = this.oAtmosphere.fPressure;
    tH2O.sSecondDepName     = 'Temperature';
    tH2O.fSecondDepValue    = this.oAtmosphere.fTemperature;
    tH2O.sPhaseType         = 'liquid';

    fDensityH2O = this.oMT.findProperty(tH2O);
    
    % growth if current generation does not exceed maximum 
    if this.iInternalGeneration <= this.txInput.iConsecutiveGenerations
        % growth if time since planting is lower than harvest time
        if (this.fInternalTime < this.txInput.fHarvestTime * 86400) && (this.iState == 1)

            % calculate internal time (time since planting) for the
            % current culture
            this.fInternalTime = fSimTime - this.fSowTime;

            % check if CO2 level is within model boundary, get MMEC
            % flow and growth rates
            if (fCO2 >= 330) && (fCO2 <= 1300)

                % get the 8 parameters via MMEC and FAO model equations
                this.tfMMECRates = this.CalculateMMECRates(...
                        this.fInternalTime,...              % Internal time for the MMEC calculation of the plant culture
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
               this.tfMMECRates = this.CalculateMMECRates(...
                        this.fInternalTime,...                      % Internal time for the MMEC calculation of the plant culture
                        fPressureAtmosphere, ...                    % atmosphere pressure
                        fDensityAtmosphere, ...                     % atmosphere density
                        fRelativeHumidityAtmosphere, ...            % atmosphere relative humidity
                        fHeatCapacityAtmosphere, ...                % atmosphere heat capacity
                        fDensityH2O, ...                            % density of liquid water under atmosphere conditions
                        this.txPlantParameters.fCO2_Ref_Max);   % maximum CO2 concentration in ppm

            % out of boundary, but not too much. assume proper growth
            % still, using minimum value
            elseif (fCO2 < 330) && (fCO2 > 150)
                % get the 8 parameters via MMEC and FAO model equations
                this.tfMMECRates = this.CalculateMMECRates(...
                        this.fInternalTime,...                      % Internal time for the MMEC calculation of the plant culture
                        fPressureAtmosphere, ...                    % atmosphere pressure
                        fDensityAtmosphere, ...                     % atmosphere density
                        fRelativeHumidityAtmosphere, ...            % atmosphere relative humidity
                        fHeatCapacityAtmosphere, ...                % atmosphere heat capacity
                        fDensityH2O, ...                            % density of liquid water under atmosphere conditions
                        this.txPlantParameters.fCO2_Ref_Min);   % minimum CO2 concentration in ppm

            % too far out of boundary
            else
                % set all MMEC rates to zero
                % TODO: need proper safety mode, flowrates = 0 does not
                % prevent prevent plant time from increasing and so on
                this.tfMMECRates.fWC = 0;
                this.tfMMECRates.fTR = 0;
                this.tfMMECRates.fOC = 0;
                this.tfMMECRates.fOP = 0;
                this.tfMMECRates.fCO2C = 0;
                this.tfMMECRates.fCO2P = 0;
                this.tfMMECRates.fNC = 0;
                this.tfMMECRates.fCGR = 0;
            end

            %% Calculate Culture Mass Transfer Rates

            % positive flowrate for plants -> atmosphere (default P2P
            % direction)
            this.tfGasExchangeRates.fO2ExchangeRate         = (this.tfMMECRates.fOP - this.tfMMECRates.fOC)     * this.txInput.fGrowthArea;
            this.tfGasExchangeRates.fCO2ExchangeRate        = (this.tfMMECRates.fCO2P - this.tfMMECRates.fCO2C) * this.txInput.fGrowthArea;
            this.tfGasExchangeRates.fTranspirationRate      = this.tfMMECRates.fTR                          	* this.txInput.fGrowthArea;

            this.fWaterConsumptionRate                      = this.tfMMECRates.fWC                          	* this.txInput.fGrowthArea;
            this.fNutrientConsumptionRate                   = this.tfMMECRates.fNC                           	* this.txInput.fGrowthArea;


            %% Biomass Growth               
            % If internaltime of considered culture's growth cycle
            % exceeds tE (time at onset of edible biomass)
            if this.fInternalTime >= this.txPlantParameters.fT_E * 86400
                % Mass balance of biomass uptake when exceeding tE
                % TODO: JUST GROWTH RATES! actual growth happens 
                % inside the plant module exec() function

                this.tfBiomassGrowthRates.fGrowthRateEdible     = (this.tfMMECRates.fCGR * this.txInput.fGrowthArea *       this.txPlantParameters.fXFRT)   * (this.txPlantParameters.fFBWF_Edible + 1);
                this.tfBiomassGrowthRates.fGrowthRateInedible   = (this.tfMMECRates.fCGR * this.txInput.fGrowthArea * (1 -  this.txPlantParameters.fXFRT))  * (this.txPlantParameters.fFBWF_Inedible + 1);

                % If tE is not exceeded yet, only inedible biomass is created 
                % (and therefore contributes to the total crop biomass (TCB) solely)
            else
                % Mass balance of biomass uptake before tE
                this.tfBiomassGrowthRates.fGrowthRateEdible = 0;  
                % In this case only inedible mass is generated anyway
                % so we can just use the wet crop growth rate
                % calculated in the MEC function directly
                this.tfBiomassGrowthRates.fGrowthRateInedible = (this.tfMMECRates.fWCGR * this.txInput.fGrowthArea);                                       
            end   

            if any(isnan(this.tfBiomassGrowthRates.fGrowthRateEdible)) || any(isnan(this.tfBiomassGrowthRates.fGrowthRateInedible))
                keyboard()
            end

            % Function needed in order to be able to verify plant
            % module vs data stated in the BVAD


            % add Edible and Inedible Wet Biomass to Water Consumption
            % Rate in Order to close mass balance! (WCGR in MMEC Modell
            % substracted since it is assumed to be wrong)!
            this.fWaterConsumptionRate =  this.fWaterConsumptionRate  + this.tfBiomassGrowthRates.fGrowthRateEdible + this.tfBiomassGrowthRates.fGrowthRateInedible ;

            %components.matter.PlantModule.functions.Plant_Module_Verification(this);


        % harvest time reached -> change state to harvest   
        else
            % if first time entering this section (= growth state until
            % now), to only change state once
            if this.iState == 1
                % set culture state to harvest
                this.iState = 2;

                % get fieldnames for loop
                csFieldNames = fieldnames(this.tfMMECRates);

                % set all entries of tfMMECRates to zero
                for iI = 1:length(csFieldNames)
                    this.tfMMECRates.(csFieldNames{iI}) = 0;
                end

                % set the resulting flow rates to zero too, small
                % structs so no loops
                this.fWaterConsumptionRate = 0;
                this.fNutrientConsumptionRate = 0;

                this.tfGasExchangeRates.fO2ExchangeRate = 0;
                this.tfGasExchangeRates.fCO2ExchangeRate = 0;
                this.tfGasExchangeRates.fTranspirationRate = 0;

                this.tfBiomassGrowthRates.fGrowthRateEdible = 0;
                this.tfBiomassGrowthRates.fGrowthRateInedible = 0;
            else

                % set the resulting flow rates to zero too, small
                % structs so no loops
                this.fWaterConsumptionRate = 0;
                this.fNutrientConsumptionRate = 0;

                this.tfGasExchangeRates.fO2ExchangeRate = 0;
                this.tfGasExchangeRates.fCO2ExchangeRate = 0;
                this.tfGasExchangeRates.fTranspirationRate = 0;

                this.tfBiomassGrowthRates.fGrowthRateEdible = 0;
                this.tfBiomassGrowthRates.fGrowthRateInedible = 0;
            end

        end
    end
    
    %% Nutrient Uptake Mechanism Based on Michaelis Menten Kinetic
    oPlantPhase = this.toStores.Plant_Culture.toPhases.Plants;

    % Calculating critical flowrate for the total uptake rate into the storage

    % create parameter to check if growth status that changes calculation is reached 
    fPlantYield_equivalent = (oPlantPhase.fMass / this.txInput.fGrowthArea) * this.txPlantParameters.fDRY_Fraction; % [kg_dryweight/m²]

    % Michaelis-Parameter K_m (parameter range 0.045-3 mol/m³, just took a medium value for tomatoes)
    fK_m = 0.2; % [mol/m³]
    % For I_max some more wild guesses, assuming that it is reached at a solution concentration of 1mM (= 1 mol/m³)
    fI_max = 1.25e-4;% [mol s^-1 kg_dryweight^-1)] original value from MA of Alexandra Nikic was 1.25e-6
    
    if this.toBranches.WaterSupply_In.fFlowRate == 0 && this.toBranches.WaterSupply_In.oHandler.fRequestedFlowRate ~= 0
        fWaterFlow = -this.toBranches.WaterSupply_In.oHandler.fRequestedFlowRate;
        rNO3        = this.toBranches.WaterSupply_In.coExmes{2}.oPhase.arPartialMass(this.oMT.tiN2I.NO3);
        fDensity    = this.toBranches.WaterSupply_In.coExmes{2}.oPhase.fDensity;
    else
        fWaterFlow  = -this.toBranches.WaterSupply_In.fFlowRate;
        rNO3        = this.toBranches.WaterSupply_In.aoFlows(1).arPartialMass(this.oMT.tiN2I.NO3);
        fDensity    = this.toBranches.WaterSupply_In.aoFlows(1).getDensity;
    end
    fNO3Flow = fWaterFlow * rNO3;

    fSolutionNO3MolarFlow = fNO3Flow / this.oMT.afMolarMass(this.oMT.tiN2I.NO3);

    % converting the nitrate concentration to mol/m³
    if fWaterFlow == 0
        fSolutionConcentration_NO3 = 0;
    else
        fSolutionConcentration_NO3 = (fSolutionNO3MolarFlow/(fWaterFlow/ fDensity));
    end
    
    % C_min abolished here because it was rendered unimportant. Values for
    % nitrate range from 0.05 mM (= 0.05 mol/m³) to under 0.001 mM (= 0.001 mol/m³)
    fMolarUptakeStorage_NO3 = (fI_max * fSolutionConcentration_NO3)/(fK_m + fSolutionConcentration_NO3);
    fMassUptakeStorage_NO3 = fMolarUptakeStorage_NO3 * this.oMT.afMolarMass(this.oMT.tiN2I.NO3) * ((oPlantPhase.fMass * this.txPlantParameters.fDRY_Fraction) + 1e-3); % add a small (1e-3) dry mass otherwise it will limit growth initially

    % Calculating critical flowrate for the total uptake rate into the structure
    if fPlantYield_equivalent < this.fYieldTreshhold               % for a young crop
        fMassUptakeStructure_NO3 = this.fCropCoeff_a_red * (this.tfMMECRates.fCGR/3600) * this.txInput.fGrowthArea; % [kgN/s]
    elseif fPlantYield_equivalent >= this.fYieldTreshhold          % for an older crop
        fMassUptakeStructure_NO3 = this.fCropCoeff_a_red * (1 - this.fCropCoeff_b_red) * ((oPlantPhase.fMass * this.txPlantParameters.fDRY_Fraction)^(-this.fCropCoeff_b_total)) * (this.tfMMECRates.fCGR/3600) * this.txInput.fGrowthArea; % [kgN/s]
    end

    % The above equation only reflects the Michaelis Menten Kinetic, now we
    % include the limitation of the storage mass for the plant:
    afPlantMass =  this.oMT.resolveCompoundMass(this.toStores.Plant_Culture.toPhases.Plants.afMass, this.toStores.Plant_Culture.toPhases.Plants.arCompoundMass);

    % Only estimated edible consumption
    fMolarFlowProteins = this.rGlobalGrowthLimitationFactor * this.tfBiomassGrowthRates.fGrowthRateEdible * this.oMT.ttxMatter.(this.oMT.csI2N{this.iEdibleBiomass}).trBaseComposition.C3H7NO2 / this.oMT.afMolarMass(this.oMT.tiN2I.C3H7NO2);
    % Since proteins have one nitrate and NO3 has one nitrate, the
    % molar uptake must be identical:
    fEdibleUptakeNO3 = fMolarFlowProteins * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);
        
    fTotalConsumptionNO3 = fEdibleUptakeNO3 + fMassUptakeStructure_NO3;
    
    % We assume the protein in edible plant mass to be the molar
    % equivalent to nitrate
    fMaxStorageMass     = 1.6 * afPlantMass(this.oMT.tiN2I.NO3);
    fCurrentStorageMass = this.toStores.Plant_Culture.toPhases.StorageNitrate.fMass;
    if fMaxStorageMass ~= 0 && fCurrentStorageMass ~= 0
    
        % Now we only limit the portion of the uptake which would actually
        % increase the stored nitrate, not the one required for edible
        % production
        if fMassUptakeStorage_NO3 > (fEdibleUptakeNO3 + fMassUptakeStructure_NO3)
            if fMaxStorageMass < fCurrentStorageMass
                % minimum uptake is the required structural nitrate
                fMassUptakeStorage_NO3 = fMassUptakeStructure_NO3 + fEdibleUptakeNO3;
            else
                fActualStorageUptake = fMassUptakeStorage_NO3 - fEdibleUptakeNO3 - fMassUptakeStructure_NO3;

                % Limit the mass increase of the nitrate storage to prevent
                % overshooting the max storage
                if (fActualStorageUptake * this.fTimeStep + fCurrentStorageMass) > fMaxStorageMass
                    fActualStorageUptake = (fMaxStorageMass - fCurrentStorageMass) / this.fTimeStep;
                end
                
                rUptakeFactor = ((fMaxStorageMass - fCurrentStorageMass)/fMaxStorageMass)^0.33;
                fMassUptakeStorage_NO3 = (rUptakeFactor * fActualStorageUptake) + fEdibleUptakeNO3 + fMassUptakeStructure_NO3;
            end
        end
    end

    % If the uptake rate is higher than the available nutrient flow in
    % the nutrient supply branch, we limit the uptake rate to the
    % available nutrients.
    if fMassUptakeStorage_NO3 > fNO3Flow
        fMassUptakeStorage_NO3 = fNO3Flow;
    end
    
    this.tfUptakeRate_Storage.NO3 = fMassUptakeStorage_NO3;

    % Now we check if the storage uptake is >= than the required structural
    % uptake. If that is the case the plant can grow nominally. If that is
    % not the case we must check the storage mass of the nutrient for
    % further
    rGrowthRatio = 1;
    if fTotalConsumptionNO3 > fMassUptakeStorage_NO3
        % TO DO: Include minimum storage value
        fMinimumStorage_NO3 = 0;
        fEffectiveNutrientStorage_NO3 = this.toStores.Plant_Culture.toPhases.StorageNitrate.afMass(this.oMT.tiN2I.NO3) - fMinimumStorage_NO3;

        if fEffectiveNutrientStorage_NO3 > 0
            fEffectiveNutrientConsumption_NO3 = fTotalConsumptionNO3 - fMassUptakeStorage_NO3;
            fMaximumMassNutrientConsumption_NO3 = fEffectiveNutrientConsumption_NO3 * this.fTimeStep;

            % If the storage is still sufficiently large we do not have to
            % change anything. However in case that the consumption exceeds
            % the current storage capacity we must reduce the growth rate
            % accordingly
            if fEffectiveNutrientStorage_NO3 < fMaximumMassNutrientConsumption_NO3
                rGrowthRatio = fEffectiveNutrientStorage_NO3/fMaximumMassNutrientConsumption_NO3;
            end
        else
            % The storage is already used up an the plant can only grow as
            % much as the current uptake rate allows
            rGrowthRatio = fMassUptakeStorage_NO3/fTotalConsumptionNO3;
        end
    end
    
    fMassUptakeStructure_NO3 = rGrowthRatio * fMassUptakeStructure_NO3;
    
    this.tfUptakeRate_Structure.NO3 = fMassUptakeStructure_NO3;
    
    % We store the values of uninhibited growth for the biomass
    this.tfUnlimitedfBiomassGrowthRates = this.tfBiomassGrowthRates;
    
    % Now we first adjust the transpiration rate, and the water
    % consumption. But since the water consumption also inclued water that
    % becomes biomass we must adjust it by just the same amount as the
    % transpiration
    fTranspirationDifference = this.tfGasExchangeRates.fTranspirationRate - this.rGlobalGrowthLimitationFactor * this.tfGasExchangeRates.fTranspirationRate;
    this.tfGasExchangeRates.fTranspirationRate = this.tfGasExchangeRates.fTranspirationRate - fTranspirationDifference;
    this.fWaterConsumptionRate                 = this.fWaterConsumptionRate - fTranspirationDifference;
    
    % Adjust flowrates:
    this.tfGasExchangeRates.fO2ExchangeRate         = rGrowthRatio 	* this.rGlobalGrowthLimitationFactor * this.tfGasExchangeRates.fO2ExchangeRate;
    this.tfGasExchangeRates.fCO2ExchangeRate        = rGrowthRatio	* this.rGlobalGrowthLimitationFactor * this.tfGasExchangeRates.fCO2ExchangeRate;
    this.tfGasExchangeRates.fTranspirationRate      = rGrowthRatio 	* this.rGlobalGrowthLimitationFactor * this.tfGasExchangeRates.fTranspirationRate;
    this.fWaterConsumptionRate                      = rGrowthRatio 	* this.rGlobalGrowthLimitationFactor * this.fWaterConsumptionRate;
    this.fNutrientConsumptionRate                   = rGrowthRatio 	* this.rGlobalGrowthLimitationFactor * this.fNutrientConsumptionRate;
    
    this.tfBiomassGrowthRates.fGrowthRateEdible     = rGrowthRatio	* this.rGlobalGrowthLimitationFactor * this.tfBiomassGrowthRates.fGrowthRateEdible;
    this.tfBiomassGrowthRates.fGrowthRateInedible   = rGrowthRatio	* this.rGlobalGrowthLimitationFactor * this.tfBiomassGrowthRates.fGrowthRateInedible;
    
    
    % Now we check how much of the nitrate is taken up by the
    % edible biomass:
    fMolarFlowProteins = this.tfBiomassGrowthRates.fGrowthRateEdible * this.oMT.ttxMatter.(this.oMT.csI2N{this.iEdibleBiomass}).trBaseComposition.C3H7NO2 / this.oMT.afMolarMass(this.oMT.tiN2I.C3H7NO2);
    % Since proteins have one nitrate and NO3 has one nitrate, the
    % molar uptake must be identical:
    fEdibleUptakeNO3 = fMolarFlowProteins * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);
    
    this.tfUptakeRate_Structure.fEdibleUptakeNO3 = fEdibleUptakeNO3;
    
    this.tfUptakeRate_Structure.NO3_Total = this.tfUptakeRate_Structure.NO3 + this.tfUptakeRate_Structure.fEdibleUptakeNO3;
    
    % Since we combine the MEC model with a new model for nutrient uptake,
    % we have to adjust the biomass growth rate by removing the MEC
    % nutrient growth rate:
    fDifferenceMassFlow = this.tfUptakeRate_Structure.NO3 - this.fNutrientConsumptionRate;
    if (this.tfBiomassGrowthRates.fGrowthRateInedible + fDifferenceMassFlow) < 0
        if this.tfBiomassGrowthRates.fGrowthRateInedible == 0
            this.tfBiomassGrowthRates.fGrowthRateEdible = this.tfBiomassGrowthRates.fGrowthRateEdible + fDifferenceMassFlow;
        else
            fTotalGrowthRate = this.tfBiomassGrowthRates.fGrowthRateEdible + this.tfBiomassGrowthRates.fGrowthRateInedible;
            
            this.tfBiomassGrowthRates.fGrowthRateEdible     = this.tfBiomassGrowthRates.fGrowthRateEdible   + fDifferenceMassFlow * this.tfBiomassGrowthRates.fGrowthRateEdible   / fTotalGrowthRate;
            this.tfBiomassGrowthRates.fGrowthRateInedible   = this.tfBiomassGrowthRates.fGrowthRateInedible + fDifferenceMassFlow * this.tfBiomassGrowthRates.fGrowthRateInedible / fTotalGrowthRate;
        end
    else
        this.tfBiomassGrowthRates.fGrowthRateInedible   = this.tfBiomassGrowthRates.fGrowthRateInedible + fDifferenceMassFlow;
    end
    
    this.fNutrientConsumptionRate = this.tfUptakeRate_Structure.NO3;
    
    if fCurrentStorageMass >= fMaxStorageMass
        if fNO3Flow > this.tfUptakeRate_Structure.NO3_Total
            this.tfUptakeRate_Storage.NO3 = this.tfUptakeRate_Structure.NO3_Total;
        else
            this.tfUptakeRate_Storage.NO3 = fNO3Flow;
        end
    end
    
    % For debugging, if the mass balance is no longer correct
    if this.fWaterConsumptionRate > 0
        fBalance = this.tfGasExchangeRates.fO2ExchangeRate + this.tfGasExchangeRates.fCO2ExchangeRate + this.tfGasExchangeRates.fTranspirationRate + ...
         (this.tfBiomassGrowthRates.fGrowthRateInedible + this.tfBiomassGrowthRates.fGrowthRateEdible) ...
         - (this.fWaterConsumptionRate + this.fNutrientConsumptionRate);

        if abs(fBalance) > 1e-8
            keyboard()
        end
    end
end