function [ fHOP_Net, fHCC_Net, fHCGR_Dry, fHTR, fHWC ] = ...
    Calculate_PlantGrowthRates_IMPROVED(cxCulture, oAtmosphereReference, fTime, fT_A, fTemperatureLight, fTemperatureDark, fRelativeHumidityLight, fRelativeHumidityDark, fPressureAtmosphere, fCO2, fPPF, fH, fDensityH2O)

    % determine if culture is currently in light or dark period
    if mod(fTime, 86400) < (fH * 3600)
        bI = 1;     % yes if light
        fRelativeHumidity = fRelativeHumidityLight;
    else
        bI = 0;     % no if dark
        fRelativeHumidity = fRelativeHumidityDark;
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
        fA = fA_Max * (fTime/fT_A) ^ components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).N; %[-]
    else
        fA = fA_Max; 
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
    
    % calculate 24-hour carbon use efficiency
    % currently legume is set to 0 for all species in PlantParameters.m, so
    % CUE_24 will always be assigned the maximum value CUE_Max. still have
    % to find out why legume has been assumed to be zero
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
    
    % Vapor Pressure for Light and Dark Phases
    fVaporPressureLight= 0.6108 * exp( 17.27 * fTemperatureLight / ( fTemperatureLight + 237.3 )); 
    fVaporPressureDark = 0.6108 * exp( 17.27 * fTemperatureDark  / ( fTemperatureDark  + 237.3 ));

    %
    e_s = (fVaporPressureLight + fVaporPressureDark) / 2 * 1000;

    %
    e_a = e_s * fRelativeHumidity; %%% relative humidity consant factor in closed environemnts ! simplified equation (what?!?)
    
    
    % P_net: net canopy photosynthesis 
    fP_net = fA * fCQY * fPPF;                  %[µmol_carbon/m^2/s]
    
    % Rate of change of saturation specific humidity with air temperature in [Pa/K]
    d = 1000 * 4098 * 0.6108 * exp( 17.27 * fTemperatureLight / ( fTemperatureLight + 237.3 )) / (( fTemperatureLight + 237)^2);
    
    % Volumetric latent heat of vaporization in [MJ/kg]
    fL_v = 2.45 * 10^6;
    
    % Psychometric constant in [Pa/K]
    fGamma = 0.665 * (10^-3) * fPressureAtmosphere;

    % Netsolar irradiance in [Wm^-2]
    fRadiance_Net = (fPPF / fPARSol) * fPhotonEnergyMolar; 

    % stomatal conductance in [m^(2)smol^-1]
    gS = 8.2 * fRelativeHumidity * (fP_net / fCO2);

    % crop height of grass in [m]
    fHeight = 0.12;

    % Leaf Area Index [-],
    % where does 24 come from? needs to be [1/m]
    fLAI = 24 * fHeight;
    
    % Leaf Area Active Index [-]
    fLAI_Active = 0.5 * fLAI;

    % bulk stomatal resistance[sm^-1]
    fStomatalResistance = 1 / (0.025 * gS);

    % bulk surface resistance [sm^-1]
    fSurfaceResistance = fStomatalResistance / fLAI_Active; 

    % soil heat flux in [Wm^-2]
    % why zero???
    fSoilHeatFlux = 0; 

    % wind speed in [m/s]
    fWindSpeed = 1.5; 

    % aerodynamic resistance[sm^-1]
    fAerodynamicResistance =  208 / fWindSpeed; 

    % dry air density [kg/m^3],
    % static, true for which specific air conditions???
    % needs to be dynamic from atmosphere
    fDryAirDensity = 1.2922;
    
    % PENMAN-Monteith equation ET_0 in [Lm^-2s^-1]
    a = d * (fRadiance_Net - fSoilHeatFlux) + fDryAirDensity * oAtmosphereReference.fSpecificIsobaricHeatCapacity * (e_s - e_a) / fAerodynamicResistance;
    b = (d + fGamma * (1 + fSurfaceResistance / fAerodynamicResistance)) * fL_v;

    fET_0 = a / b; 

    % Crop Coefficient development during plant growth
    if fTime < fT_A
        fKC = components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).KC_Mid * (fTime / fT_A) ^ components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).N;
    elseif (fT_A <= fTime) && (fTime <= fT_Q)
        fKC = components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).KC_Mid;
    else
        fKC = components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).KC_Mid + ((fTime - fT_Q) / (fT_M - fT_Q)) * (components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).KC_Late - components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).KC_Mid);
    end
    
    % Final Water volume evapotranspiration ET_c in [liters/m^2s]
    fET_C = fKC * fET_0;

    % Conversion to hourly transpiration rate
    fHTR = fET_C * 3600 * fDensityH2O; % [g/m^2/h]

    % Hourly CO2 consumption rate
    fHCO2C = fHOP * fMolarMassCO2 / fMolarMassO2;       %[g/m^2/h]
    % Hourly CO2 production rate
    fHCO2P = fHOC * fMolarMassCO2 / fMolarMassO2;       %[g/m^2/h]
    
    % Daily CO2 net consumption rate
    fHCC_Net = fHCO2C - fHCO2P;    %[g/m^2/h]
        
    % Hourly plant macrontutrients uptake 
    fHNC = fHCGR_Dry * components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).DBF * components.PlantModule.PlantParameters_IMPROVED(cxCulture.PlantData.PlantSpecies).NC_Fraction;  %[g/m^2/h]
    
    % Water balance
    % Hourly Water Consumption 
    fHWC = fHTR + fHOP + fHCO2P + fHCGR_Wet - fHOC - fHCO2C - fHNC;  % [g_water/m^2/h]
end