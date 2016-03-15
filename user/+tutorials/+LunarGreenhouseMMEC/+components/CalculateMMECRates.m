function [ oCulture ] ...
    = CalculateMMECRates(...
        oCulture, fInternalTime, fDensityAtmosphere, fTemperatureAtmosphere, fRelativeHumidityAtmosphere, fHeatCapacityAtmosphere, fDensityH2O, fCO2)
    
    %% WARNING!! -- FILE CONTENT NOT IN SI UNITS!!! %%%%%%%%%%%%%%%%%%%%%%%
    
    
    % This function contains all necessary calculations for plant growth
    % according to the MMEC model. source for numbered equations: 
    % "Advances in Space Research 50 (2012) 941–951"
    % TODO: using PLANTPARAMETERS.xyz as placeholder until matter table
    % layout stuff has been decided
    
    % 8 target parameters to be calculated (in no particular order)
    % HWC ..... Hourly Water Consumption            [g m^-2 h^-1]
    % HTR ..... Hourly Transpiration Rate           [g m^-2 h^-1]
    % HOC ..... Hourly Oxygen Consumption           [g m^-2 h^-1]
    % HOP ..... Hourly Oxygen Prodcution            [g m^-2 h^-1]
    % HCO2C ... Hourly Carbon dioxide Consumption   [g m^-2 h^-1]
    % HCO2P ... Hourly Carbon dioxide Production    [g m^-2 h^-1]
    % HNC ..... Hourly Nutrient Consumption         [g m^-2 h^-1]
    % HWCGR ... Hourly Wet Crop Growth Rate         [g m^-2 h^-1]

    %% Calculate 6 Out Of 8 Target Parameters
    
    % determine if it is day or night for the current culture
    % TODO: improve later after system is running as it is one (the?)
    % reason photoperiod is linked to planting time and not a more general
    % setting
    if mod(fInternalTime, 1440) < (oCulture.txInput.fH * 60)
        bI = 1;
    else
        bI = 0;
    end
    
    % calculate 24-hour carbon use efficiency (CUE_24)
    % CUE_24 constant for non-legumes, different for legumes
    if oCulture.txPlantParameters.bLegume == 1
        % before time of onset of canopy senescence
        if fInternalTime <= oCulture.txPlantParameters.fT_Q
            fCUE_24 = oCulture.txPlantParameters.fCUE_Max;
            % after time of onset of canopy senescence but before time of
            % crop maturity
        elseif oCulture.txPlantParameters.fT_Q < fInternalTime <= oCulture.txPlantParameters.fT_M
            fCUE_24 = oCulture.txPlantParameters.fCUE_Max - (oCulture.txPlantParameters.fCUE_Max - oCulture.txPlantParameters.fCUE_Min) * (fInternalTime - oCulture.txPlantParameters.fT_Q) * (oCulture.txPlantParameters.fT_M - oCulture.txPlantParameters.fT_Q)^-1;
        end
    % CUE_24 constant for non-legumes
    else
        fCUE_24 = oCulture.txPlantParameters.fCUE_Max;
    end
    
    % calculate effective photosynthetic photon flux density (PPFD_E) 
    % [µmol m^-2 s-^1]
    fPPFD_E = oCulture.txInput.fPPFD * (fH * oCulture.txPlantParameters.fH_0^-1);
    
    % calculate time of canopy closure (T_A)
    % calculate maximum canopy qunatum yield (CQY_Max)
    % [µmol_Carbon.Fixed * µmol_Absorbed.PPFD)^-1]
    % source: "Advances in Space Research 34 (2004) 1528–1538"
    fT_A = ...
        [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * ...             % row vector for CO2
        oCulture.txPlantParameters.mfMatrix_T_A * ...   % coefficient matrix
        [1/fPPFD_E; 1; fPPFD_E; fPPFD_E^2; fPPFD_E^3];  % column vector for PPFD
    
    % calculate fraction of PPFD absorbed by canopy (A)
    % before time of canopy closure
    if fInternalTime < fT_A
        fA = oCulture.txPlantParameters.fA_Max * (fInternalTime / fT_A)^oCulture.txPlantParameters.fN;
    % after time of canopy closure
    elseif fInternalTime >= fT_A
        fA = oCulture.txPlantParameters.fA_Max;
    end
    
    % calculate maximum canopy qunatum yield (CQY_Max)
    % [µmol_Carbon.Fixed * µmol_Absorbed.PPFD)^-1]
    % source: "Advances in Space Research 34 (2004) 1528–1538"
    fCQY_Max = ...
        [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * ...                 % row vector for CO2
        oCulture.txPlantParameters.mfMatrix_CQY_Max * ...   % coefficient matrix
        [1/oCulture.txInput.fPPFD; 1; oCulture.txInput.fPPFD; oCulture.txInput.fPPFD^2; oCulture.txInput.fPPFD^3]; % column vector for PPFD
    
    % calculate canopy quantum yield (CQY) 
    % [µmol_Carbon.Fixed * µmol_Absorbed.PPFD)^-1] 
    % CQY description: canopy gross photosynthesis divided by absorbed PAR
    % before time of onset of canopy senescence
    if fInternalTime <= oCulture.txPlantParameters.fT_Q
        fCQY = fCQY_Max;
    % after time of onset of canopy senescence but before time of
     % crop maturity    
    elseif oCulture.txPlantParameters.fT_Q < fInternalTime <= oCulture.txPlantParameters.fT_M
        fCQY = fCQY_Max - (fCQY_Max - oCulture.txPlantParameters.fCQY_Min) * (fInternalTime - oCulture.txPlantParameters.fT_Q) * (oCulture.txPlantParameters.fT_M - oCulture.txPlantParameters.fT_Q)^-1;
    end
    
    % hourly carbon gain [mol_Carbon m^-2 h^-1]
    % HCG = alpha * CUE_24 * A * CQY * PPFD * I (Eq. 2)
    fHCG = oCulture.txPlantParameters.fAlpha * oCulture.txPlantParameters.fCUE_24 * fA * fCQY * oCulture.txInput.fPPFD * bI;
    
    % hourly crop growth rate (dry) [g m^-2 h^-1]
    % HCGR = HCG * MW_C * BCF^-1 (Eq. 6)
    fHCGR = fHCG * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.C) * oCulture.txPlantParameters.fBCF;
    
    % hourly wet crop growth rate [g m^-2 h^-1]
    % HWCGR = HCGR * (1 - WBF)^-1 (Eq. 7)
    % if T_E exceeded -> use total water fraction, if not only inedible
    % biomass is produced -> water fraction = 0.9 (BVAD 2015, table 4.98)
    if fInternalTime >= oCulture.txPlantParameters.fT_E
        fHWCGR = fHCGR * (1 - oCulture.txPlantParameters.fWBF_Total)^-1;
    else
        fHWCGR = fHCGR * (1 - 0.9)^-1;
    end
    
    % hourly oxygen production [g m^-2 h^-1]
    % HOP = HCG * CUE_24 ^-1 * OPF * MW_O2 (Eq. 8)
    fHOP = fHCG * fCUE_24 * oCulture.txPlantParameters.fOPF * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.O2);
    
    % hourly oxygen consumption [g m^-2 h^-1]
    % HOC = HCG * I^-1 * (1 - CUE_24) * CUE_24^-1 * OPF * MW_O2 * H * 24^-1
    % (Eq. 9)
    fHOC = (oCulture.txPlantParameters.fAlpha * fCUE_24 * fA * fCQY * oCulture.txInput.fPPFD) * (1 - fCUE_24) * fCUE_24^-1 * oCulture.txPlantParameters.fOPF * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.O2) * oCulture.txInput.fH * 24^-1;

    % hourly CO2 consumption [g m^-2 h^-1]
    % HCO2C = HOP * MW_CO2 * MW_O2^-1 (Eq. 14)
    fHCO2C = fHOP * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.CO2) * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.O2) ^-1;
    
    % hourly CO2 production [g m^-2 h^-1]
    % HCO2P = HOC * MW_CO2 * MW_O2^-1 (Eq. 15)
    fHCO2P = fHOC * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.CO2) * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.O2) ^-1;
    
    % hourly plant macronutirent uptake [g m^-2 h^-1]
    % HNC = HCGR * DRY_fr * NC_fr (Eq. 15.5, has no number, but is listed 
    % between Eq. 15 and Eq. 16))
    fHNC = fHCGR * oCulture.txPlantParameters.fDRY_Fraction * oCulture.txPlantParameters.fNC_Fraction; 
    
    %% Calculate Plant Transpiration
    
    % TODO: All transpiration equations taken directly from old
    % Calculate_PlantGrowthRates.m as it was done by Daniel Saad and is not
    % part of the (M)MEC model. need later to double check everything after
    % having more knowledge about this transpiration model.
    
    % Transpiration Model is based on the FAO Model 
    % (Penman-Montheith Equation)
    
    % Vapor Pressure for Light and Dark Phases (kept both, probably just
    % need the one if referencing from atmsophere. check again later
    fVaporPressureLight = 0.6108 * exp(17.27 * fTemperatureAtmosphere / (fTemperatureAtmosphere + 237.3)); 
    fVaporPressureDark = 0.6108 * exp(17.27 * fTemperatureAtmosphere / (fTemperatureAtmosphere + 237.3));

    fE_S = (fVaporPressureLight + fVaporPressureDark) / 2 * 1000;

    fE_A = fE_S * fRelativeHumidityAtmosphere; %%% relative humidity consant factor in closed environemnts ! simplified equation
        
        
    % P_net: net canopy photosynthesis [µmol_Carbon m^2 s]
    fP_Net = fA * fCQY * fPPFD;                  
        
    % Rate of change of saturation specific humidity with air temperature in [Pa K^-1]
    fD = 1000 * 4098 * 0.6108 * exp(17.27 * fTemperatureAtmosphere / ( fTemperatureAtmosphere + 237.3 )) / (( fTemperatureAtmosphere + 237)^2); 

    % Volumetric latent heat of vaporization in [MJ kg^-1]
    fL_V = 2.45 * 10^6;

    % Psychometric constant in [Pa K^-1]
    fGamma = 0.665 * 10^-3 * fPressureAtmosphere;

    % Netsolar irradiance in [W m^-2]
    fR_Net = (fPPFD / fPARSOL) * fE_M; 

    % stomatal conductance in [m^2 s mol^-1]
    fG_S = 8.2 * fRelativeHumidityAtmosphere * (fP_Net / fCO2);

    % crop height of grass in [m]
    fGrassHeight = 0.12;

    % Leaf Area Index [-]
    fLAI = 24 * fGrassHeight;

    % Leaf Area Active Index [-]
    fLAI_Active = 0.5 * fLAI;

    % bulk stomatal resistance[s m^-1]
    fR_1 = 1 / (0.025 * fG_S);

    % bulk surface resistance [s m^-1]
    fR_S = fR_1 / fLAI_Active; 

    % soil heat flux in [W m^-2]
    fSoilHeatFlux = 0;
    
    % wind speed in [m s^-1]
    fU = 1.5; 

    % aerodynamic resistance [m s^-1]
    fR_A =  208 / fU;
    
    % Penman-Monteith equation ET_0 in [liter m^-2 s^-1]
    % Atmsophere density from referneced atmosphere
    a = fD * (fR_Net - fSoilHeatFlux) + fDensityAtmosphere * fHeatCapacityAtmosphere * (fE_S - fE_A) / fR_A;
    b = (fD + fGamma * (1 + fR_S / fR_A)) * fL_V;

    fET_0 = a/b; 
    
    % Crop Coefficient development during plant growth
    if fInternalTime < fT_A  
        fKC = fKC_Mid * (fInternalTime / fT_A) ^ oCulture.txPlantParameters.fN;
    elseif (fT_A <= fInternalTime) && (fInternalTime <= oCulture.txPlantParameters.fT_Q)   
        fKC = oCulture.txPlantParameters.fKC_Mid;
    else   
        fKC = oCulture.txPlantParameters.fKC_Mid + ((fInternalTime - oCulture.txPlantParameters.fT_Q) / (oCulture.txPlantParameters.fT_M - oCulture.txPlantParameters.fT_Q)) * (oCulture.txPlantParameters.fKC_Late - oCulture.txPlantParameters.fKC_Mid);
    end
    
    % final Water volume evapotranspiration ET_c in [liter m^-2 s^-1]
    fET_C = fKC * fET_0;
    
    % hourly transpiration rate [g m^-2 h^-1]
    % TODO: model from saad, do last
    fHTR = fET_C * 3600 * fDensityH2O;
    
    %% Calculate Water Consumption
    
    % HWC is calculated last as it is used to close the mass balance
    
    % hourly water consumption [g m^-2 h^-1]
    % HWC = HTR + HOP + HCO2P + HWCGR - HOC - HCO2C - HNC (Eq. 16)
    fHWC = fHTR + fHOP + fHCO2P + fHWCGR - fHOC - fHCO2C - fHNC;
    
    %% Write Transfer Parameter
    
    % attach calculated plant consumsption and production rates to culture 
    % object, further handling on the upper level and convert to SI units
    oCulture.tfMMECRates.fWC    = fHWC      * (1000 * 3600)^-1;
    oCulture.tfMMECRates.fTR    = fHTR      * (1000 * 3600)^-1;
    oCulture.tfMMECRates.fOC    = fHOC      * (1000 * 3600)^-1;
    oCulture.tfMMECRates.fOP    = fHOP      * (1000 * 3600)^-1;
    oCulture.tfMMECRates.fCO2C  = fHCO2C    * (1000 * 3600)^-1;
    oCulture.tfMMECRates.fCO2P  = fHCO2P    * (1000 * 3600)^-1;
    oCulture.tfMMECRates.fNC    = fHNC      * (1000 * 3600)^-1;
    
    % growth rate on dry basis because edible and inedible biomass parts
    % have different water contents
    oCulture.tfMMECRates.fCGR   = fHCGR     * (1000 * 3600)^-1;
end

