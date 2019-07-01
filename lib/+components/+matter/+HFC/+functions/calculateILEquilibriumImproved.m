function [fEquilibriumCO2Pressure,fHenrysConstant] = calculateILEquilibriumImproved(oLumen, oShell, tEquilibriumCurveFits, fShellDensity)
% calculateILEquilibriumImproved calculates the equilibrium loading of CO2
% in the IL based on the temperature of the IL and amount of CO2 already
% in the IL (xCO2). A future iteration may also include the effect of 
% water content in the IL.
%
% output of equilibrium partial pressure of CO2 [Pa] in the gas above the IL
% oLumen = gas phase; oShell = IL phase
%
% Correlates gas pressure of the "solute" gas with how much can be absorbed
% into the solvent (equilibrium concentration) based on Vapor Liquid 
% Equilibrium curves. The VLE curves are fit based on data from 
% Stevanovic et al. (2012) using a simple exponential curve fit of the
% form:  y = a*exp(b*x). Separate curves are presented at different 
% temperatures, and intermediate temperature values of equilibrium 
% concentrations are interpolated LINEARLY. 

afFitCoefficientA = tEquilibriumCurveFits.afFitCoefficients(:,1);
afFitCoefficientB = tEquilibriumCurveFits.afFitCoefficients(:,2);
afTemperatureData = tEquilibriumCurveFits.afTemperatureData;

afShellMolarRatios = (oShell.arPartialMass ./ oShell.oMT.afMolarMass)/sum(oShell.arPartialMass ./ oShell.oMT.afMolarMass);
afLumenMolarRatios = (oLumen.arPartialMass ./ oLumen.oMT.afMolarMass)/sum(oLumen.arPartialMass ./ oLumen.oMT.afMolarMass);
fMolFractionCO2LookUp = afShellMolarRatios(oShell.oMT.tiN2I.CO2);
if isnan(fMolFractionCO2LookUp)
    fMolFractionCO2LookUp = 0;
end
fMolFractionCO2Lumen = afLumenMolarRatios(oLumen.oMT.tiN2I.CO2);
fPressure = oLumen.fPressure;
fTemperatureLookUp = oLumen.fTemperature;
fMinTemp = min(afTemperatureData);
fMaxTemp = max(afTemperatureData);

if fTemperatureLookUp <= fMinTemp
    fTemperatureLookUp = fMinTemp;
%     warning('IL temperature is out of the range necessary for accurately calculating CO2 equilibrium pressure!')

elseif fTemperatureLookUp >= fMaxTemp
    fTemperatureLookUp = fMaxTemp;
%     warning('IL temperature is out of the range necessary for accurately calculating CO2 equilibrium pressure!')
end

[~, closestIndex] = min(abs(afTemperatureData - fTemperatureLookUp));
deltaDirection = afTemperatureData(closestIndex) - fTemperatureLookUp;
if deltaDirection < 0
    lowerIndex = closestIndex;
    upperIndex = closestIndex + 1;        
elseif deltaDirection > 0
    upperIndex = closestIndex;
    lowerIndex = closestIndex - 1;
elseif deltaDirection == 0
    lowerIndex = 1;
    upperIndex = 1;
end

p1 = afFitCoefficientA(lowerIndex) * exp(afFitCoefficientB(lowerIndex) * fMolFractionCO2LookUp);
p2 = afFitCoefficientA(upperIndex) * exp(afFitCoefficientB(upperIndex) * fMolFractionCO2LookUp);
T1 = afTemperatureData(lowerIndex);
T2 = afTemperatureData(upperIndex);

if p1 == p2
    fEquilibriumCO2Pressure = p1;
else
    fEquilibriumCO2Pressure = p1 + (p2 - p1)/(T2-T1)*(fTemperatureLookUp - T1);
end

if fMolFractionCO2LookUp == 0
    fHenrysConstant = 2200;
else
    fHenrysConstant = fEquilibriumCO2Pressure ./ (fMolFractionCO2LookUp .* (fShellDensity./oShell.fMolarMass) .* oShell.oMT.Const.fUniversalGas .* fTemperatureLookUp);
end


end