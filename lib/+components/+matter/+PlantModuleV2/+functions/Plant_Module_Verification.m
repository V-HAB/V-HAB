function [oCulture] = Plant_Module_Verification(oCulture,fGrowthRateEdible,fGrowthRateInedible)

i = int32(oCulture.i);

oCulture.mfOxygenProduction(1,i) = oCulture.tfGasExchangeRates.fO2ExchangeRate/oCulture.txInput.fGrowthArea;
oCulture.mfCarbonDioxideUptake(1,i) = oCulture.tfGasExchangeRates.fCO2ExchangeRate/oCulture.txInput.fGrowthArea;
oCulture.mfWaterTranspiration(1,i) = oCulture.tfGasExchangeRates.fTranspirationRate/oCulture.txInput.fGrowthArea;

oCulture.mfTotalBioMass(1,i) = (oCulture.tfBiomassGrowthRates.fGrowthRateInedible + oCulture.tfBiomassGrowthRates.fGrowthRateEdible)/oCulture.txInput.fGrowthArea;
oCulture.mfInedibleMass(1,i) = oCulture.tfBiomassGrowthRates.fGrowthRateInedible/oCulture.txInput.fGrowthArea;
oCulture.mfEdibleMass(1,i) = oCulture.tfBiomassGrowthRates.fGrowthRateEdible/oCulture.txInput.fGrowthArea;


% oCulture.mfEdibleMassDryBasis(1,i) = fGrowthRateEdible;
% oCulture.mfInedibleMassDryBasis(1,i) = fGrowthRateInedible;


oCulture.i = oCulture.i + 1;

end