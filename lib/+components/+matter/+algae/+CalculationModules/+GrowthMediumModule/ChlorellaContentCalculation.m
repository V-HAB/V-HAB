function fChlorellaMass = ChlorellaContentCalculation(oSystem)
%CHLORELLACONTENTCALCULATION determines the initial chlorella mass in the
%system by taking the celldensitry(t=o) value from the grwoth rate
%calculation and multiplying that wiht the total medium volume. 

%% get parameters for this calculation
fInitialBiomassConcentration = oSystem.oGrowthRateCalculationModule.fInitialBiomassConcentration;  %[kg/m3]
fMediumVolume = oSystem.oParent.fGrowthVolume;                                      %[m3]  

fChlorellaMass = fInitialBiomassConcentration * fMediumVolume; %[kg]

end

