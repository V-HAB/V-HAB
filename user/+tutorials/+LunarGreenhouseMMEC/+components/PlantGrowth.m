function [oCulture] ...
    = PlantGrowth(oCulture)
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
    if mod(fInternalTime, 1440) < fH * 60
        bI = 1;
    else
        bI = 0;
    end
    
    % calculate 24-hour carbon use efficiency (CUE_24)
    % CUE_24 constant for non-legumes, different for legumes
    if PLANTPARAMETERS.legume == 1
        % before time of onset of canopy senescence
        if fInternalTime <= PLANTPARAMETERS.T_Q
            fCUE_24 = PLANTPARAMETERS.CUE_Max;
            % after time of onset of canopy senescence but before time of
            % crop maturity
        elseif PLANTPARAMETERS.T_Q < fInternalTime <= PLANTPARAMETERS.T_M
            fCUE_24 = PLANTPARAMETERS.CUE_Max - (PLANTPARAMETERS.CUE_Max - PLANTPARAMETERS.CUE_Min) * (fInternalTime - PLANTPARAMETERS.T_Q) * (PLANTPARAMETERS.T_M - PLANTPARAMETERS.T_Q)^-1;
        end
    % CUE_24 constant for non-legumes
    else
        fCUE_24 = PLANTPARAMETERS.CUE_Max;
    end
    
    % calculate effective photosynthetic photon flux density (PPFD_E) 
    % [µmol m^-2 s-^1]
    fPPFD_E = fPPFD * (fH * PLANTPARAMETERS.H_0^-1);
    
    % calculate time of canopy closure (T_A)
    % calculate maximum canopy qunatum yield (CQY_Max)
    % [µmol_Carbon.Fixed * µmol_Absorbed.PPFD)^-1]
    % source: "Advances in Space Research 34 (2004) 1528–1538"
    fT_A = ...
        [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * ...             % row vector for CO2
        PLANTPARAMETERS.Matrix_T_A * ...                % coefficient matrix
        [1/fPPFD_E; 1; fPPFD_E; fPPFD_E^2; fPPFD_E^3];  % column vector for PPFD
    
    % calculate fraction of PPFD absorbed by canopy (A)
    % before time of canopy closure
    if fInternalTime < fT_A
        fA = PLANTPARAMETERS.A_Max * (fInternalTime / fT_A)^PLANTPARAMETERS.N;
    % after time of canopy closure
    elseif fInternalTime >= fT_A
        fA = PLANTPARAMETERS.A_Max;
    end
    
    % calculate maximum canopy qunatum yield (CQY_Max)
    % [µmol_Carbon.Fixed * µmol_Absorbed.PPFD)^-1]
    % source: "Advances in Space Research 34 (2004) 1528–1538"
    fCQY_Max = ...
        [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * ...     % row vector for CO2
        PLANTPARAMETERS.Matrix_CQY_Max * ...    % coefficient matrix
        [1/fPPFD; 1; fPPFD; fPPFD^2; fPPFD^3];  % column vector for PPFD
    
    % calculate canopy quantum yield (CQY) 
    % [µmol_Carbon.Fixed * µmol_Absorbed.PPFD)^-1] 
    % CQY description: canopy gross photosynthesis divided by absorbed PAR
    % before time of onset of canopy senescence
    if fInternalTime <= PLANTPARAMETERS.T_Q
        fCQY = fCQY_Max;
    % after time of onset of canopy senescence but before time of
     % crop maturity    
    elseif PLANTPARAMETERS.T_Q < fInternalTime <= PLANTPARAMETERS.T_M
        fCQY = fCQY_Max - (fCQY_Max - PLANTPARAMETERS.CQY_Min) * (fInternalTime - PLANTPARAMETERS.T_Q) * (PLANTPARAMETERS.T_M - PLANTPARAMETERS.T_Q)^-1;
    end
    
    % hourly carbon gain [mol_Carbon m^-2 h^-1]
    % HCG = alpha * CUE_24 * A * CQY * PPFD * I (Eq. 2)
    fHCG = PLANTPARAMETERS.Alpha * PLANTPARAMETERS.CUE_24 * fA * fCQY * fPPFD * bI;
    
    % hourly crop growth rate (dry) [g m^-2 h^-1]
    % HCGR = HCG * MW_C * BCF^-1 (Eq. 6)
    fHCGR = fHCG * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.C) * PLANTPARAMETERS.BCF;
    
    % hourly wet crop growth rate [g m^-2 h^-1]
    % HWCGR = HCGR * (1 - WBF)^-1 (Eq. 7)
    fHWCGR = fHCGR * (1 - PLANTPARAMETERS.WBF)^-1;
    
    % hourly oxygen production [g m^-2 h^-1]
    % HOP = HCG * CUE_24 ^-1 * OPF * MW_O2 (Eq. 8)
    fHOP = fHCG * fCUE_24 * PLANTPARAMETERS.OPF * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.O2);
    
    % hourly oxygen consumption [g m^-2 h^-1]
    % HOC = HCG * I^-1 * (1 - CUE_24) * CUE_24^-1 * OPF * MW_O2 * H * 24^-1
    % (Eq. 9)
    fHOC = (fAlpha * fCUE_24 * fA * fCQY * fPPFD) * (1 - fCUE_24) * fCUE_24^-1 * PLANTPARAMETERS.OPF * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.O2) * fH * 24^-1;

    % hourly CO2 consumption [g m^-2 h^-1]
    % HCO2C = HOP * MW_CO2 * MW_O2^-1 (Eq. 14)
    fHCO2C = fHOP * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.CO2) * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.O2) ^-1;
    
    % hourly CO2 production [g m^-2 h^-1]
    % HCO2P = HOC * MW_CO2 * MW_O2^-1 (Eq. 15)
    fHCO2P = fHOC * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.CO2) * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.O2) ^-1;
    
    % hourly plant macronutirent uptake [g m^-2 h^-1]
    % HNC = HCGR * DRY_fr * NC_fr (Eq. 15.5, has no number, but is listed 
    % between Eq. 15 and Eq. 16))
    fHNC = fHCGR * PLANTPARAMETERS.DRYfr * PLANTPARAMETERS.NCfr; 
    
    %% Calculate Plant Transpiration
    
    % Transpiration Model is based on the FAO Model 
    % (Penman-Montheith Equation)
    
    % hourly transpiration rate [g m^-2 h^-1]
    % TODO: model from saad, do last
    fHTR = ;
    
    %% Calculate Water Consumption
    
    % HWC is calculated last as it is used to close the mass balance
    
    % hourly water consumption [g m^-2 h^-1]
    % HWC = HTR + HOP + HCO2P + HWCGR - HOC - HCO2C - HNC (Eq. 16)
    fHWC = fHTR + fHOP + fHCO2P + fHWCGR - fHOC - fHCO2C - fHNC;
    
    %% Write Transfer Parameter
    
    % attach calculated plant consumsption and production rates to culture 
    % object, further handling on the upper level 
    oCulture.HWC    = fHWC;
    oCulture.HTR    = fHTR;
    oCulture.HOC    = fHOC;
    oCulture.HOP    = fHOP;
    oCulture.HCO2C  = fHCO2C;
    oCulture.HCO2P  = fHCO2P;
    oCulture.HNC    = fHNC;
    oCulture.HWCGR  = fHWCGR;
end

