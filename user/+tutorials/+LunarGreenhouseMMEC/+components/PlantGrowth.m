function [oCulture] ...
    = PlantGrowth(oCulture)
    % This function contains all necessary calculations for plant growth
    % according to the MMEC model.
    % TODO: using PLANTPARAMETERS.xyz as placeholder until matter table
    % layout stuff has been decided

    % hourly oxygen production [g m^-2 h^-1]
    % HOP = HCG * CUE_24 ^-1 * OPF * MW_O2
    fHOP = fHCG * PLANTPARAMETERS.CUE24 * fOPF * oCulture.oMT.ttxMatter.fMolarMass(oMT.tiN2I.O2);
    
    % hourly oxygen consumption [g m^-2 h^-1]
    % HOC = HCG * I^-1 * (1 - CUE_24) * CUE_24^-1 * OPF * MW_O2 * H * 24^-1
    fHOC = ;
    
    % hourly transpiration rate [g m^-2 h^-1]
    % TODO: model from saad, do later
    fHTR = ;
    
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
    
    % hourly water consumption [g m^-2 h^-1]
    % HWC = HTR + HOP + HCO2P + HWCGR - HOC - HCO2C - HNC (Eq. 16)
    fHWC = fHTR + fHOP + fHCO2P + fHWCGR - fHOC - fHCO2C - fHNC;
end

