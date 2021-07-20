function fDissolvedMoles  = Calcite_Solubility(fCurrentTemp, fMolesCaCO3, fVolume)
% This function calculates the theoretical number of moles of CO3 and Ca produced 
% by dissolution of CaCO3 in water. The empirical calculation depends on the water 
% temperature in K.
% Source: L. NIEL PLUMMER and EURYBIADES BUSENBERG: "The solubilities of calcite, 
% aragonite and vaterite in CO2-H2O solutions between 0 and 9O°C, 
% and an evaluation of the aqueous model for the system CaC03-CO2-H20", 
% in Geochimica et Cosmochimica Acta Vol. 46. pp. 1011-1040, 1981

% The log value for the equilibrium constant K_C of the reaction CaCO3 + H2O 
% --> Ca(2+) + CO3(-)
flogK_C = - 171.9065 - (0.077993 * fCurrentTemp) + (2839.319 / fCurrentTemp) + ...
                (71.595 * log10(fCurrentTemp)); 
            
% The resulting equilibrium constant K_C
fK_C = 10^(flogK_C);

% The concentration of calcite in the water volume in mol/L
fConcentrationCaCO3 = fMolesCaCO3 / fVolume;

% The concentration of dissolved CO3 in the water volume in mol/L
fConcentrationCO3 = sqrt(fK_C * fConcentrationCaCO3);

% The resulting number of moles of dissolved CO3 in mol (equal to the number 
% of dissolved moles of calcium and dissociated calcite)
fDissolvedMoles = fConcentrationCO3 * fVolume;

end