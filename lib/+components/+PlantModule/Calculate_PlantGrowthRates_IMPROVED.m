function [ fHOP_Net, fHCC_Net, fHCGR, fHTR, fHWC ] = ...
    Calculate_PlantGrowthParameters_IMPROVED(cxCulture, oAtmosphereReference, fTime, fT_A, fTemperatureLight, fTemperatureDark, fWaterAvailable, fRelativeHumidityLight, fRelativeHumidityDark, fPressureAtmosphere, fCO2, fPPF, fH, fDensityH2O)

    % determine if culture is currently in light or dark period
    if mod(fTime, 86400) < (fH * 3600)
        bI = 1;     % yes if light      
    else
        bI = 0;     % no if dark    
    end
    
    % Conversion factor of PAR to solar radiation[-]
    fPARSol = 0.45;

    % planck constant (h) in [J/s]
    fPlanckConstant = 6.626 * 10^-34; 
    
    % speed of light in [m/s]
    fLightSpeed = 2.998 * 10^8;
    
    % Avogrado constant in [TEILCHEN * mol^-1]
    fAvogadro = matter.table.Const.fAvogadro;
    
    % Avarege wavelenght in [m] (of visible light???)
    fAverageWaveLength = 535 * 10^-9;
    
    % Energy of a photon?   [J]
    fPhotonEnergy = fPlanckConstant * fLightSpeed / fAverageWaveLength;
    
    % Energy per mol PAR in [MJ/mol] (why MJ?)
    fPhotonEnergyMolar = fPhotonEnergy * fAvogadro * 10^-6;
    
    % A_Max: maximum fraction of incident irradiance absorbed by the canopy
    fA_Max = 0.93;
    
    % Calculation of fraction of incident irradiance absorbed by the canopy
    if fTime < fT_A
        fA = fA_max * (fTime/fT_A) ^ components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).N; %[-]
    else
        fA = fA_max; 
    end
    
    % calculate maximum canopy quantum yield [µmol Carbon Fixed/µmol Absorbed PPF]
    fCQY_Max = [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).Matrix_CQY * [1/fPPF; 1; fPPF; fPPF^2; fPPF^3]; 
    
    % calculate actual canopy quantum yield [µmol Carbon Fixed/µmol Absorbed PPF]
    if (cxCulture.PlantData.PlantSpecies == 2) || (cxCulture.PlantData.PlantSpecies == 6) || (fTime <= components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_Q)
        fCQY     = fCQY_Max; 
    elseif (components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_Q <= fTime) && (fTime <= components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_M)
        fCQY     = fCQY_Max - (fCQY_Max - components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).CQY_Min) * (fTime - components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_Q) / (components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_M - components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_Q); 
    else
        fCQY     = 0; 
    end
    
    % 24-hour carbon use efficiency
    if components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).Legume == 1
        if fTime <= components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_Q
            fCUE_24 = components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).CUE_Max; 
        elseif (components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_Q <= fTime) && (fTime <= components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_M)
            fCUE_24 = components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).CUE_Max - (components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).CUE_Max - components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).CUE_Min) * (fTime - components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_Q) / (components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_M - components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).T_Q); 
        end
    else
        fCUE_24 = components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).CUE_Max; 
    end
    
    % update culture cell array
    cxCulture.Growth.CUE_24 = fCUE_24; 
    
    % Hourly Carbon Gain (HCG) [mol_carbon/m^2/h]
    fHCG = 0.0036 * fCUE_24 * fA * fCQY * fPPF * bI;  
    
    % get molar masses from matter table
    fMolarMassC     = matter.table.ttxMatter.C.fMolarMass;
    fMolarMassO2    = matter.table.ttxMatter.O2.fMolarMass;
    fMolarMassCO2   = matter.table.ttxMatter.CO2.fMolarMass;
    fMolarMassH2O   = matter.table.ttxMatter.H2O.fMolarMass;
    
    % Hourly crop growth rate on a dry basis
    fHCGR_Dry = fHCG * fMolarMassC / components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).BCF;  % [kg/m^2/h]
    
    % Hourly crop growth rate on a wet basis
    fHCGR_Wet = HCGR_Dry / components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).WBF;   % [kg/m^2/h]
    
    % Hourly Oxygen Production (HOP)
    fHOP = fHCG / fCUE_24 * components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).OPF * fMolarMassO2;   % [kg/m^2/h]
    
    % Hourly Oxygen Consumption (HOC)
    fHOC = 0.0036 * fCUE_24 * fA * fCQY * fPPF * (1 - fCUE_24) / fCUE_24 * components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).OPF * fMolarMassO2 * fH / 24; % [kg/m^2/h]
    
    % Hourly Net Oxygen Production
    fHOP_Net = fHOP - fHOC;   % [kg/m^2/h]
    
    
end