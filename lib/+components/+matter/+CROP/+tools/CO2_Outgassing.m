function [fCO2_gas_concentration, fH_cc_CO2] = CO2_Outgassing(fCurrentTemp, fPartialPressureCO2)
% This function calculates the theoretical CO2 gas concentration in the gas phase above a solution
% at ambient pressure. The second function output represents the
% dimensionless Henry solubility, which can be used for NH3 outgassing
% calculation.  
% Source: R. Sander: Compilation of Henry's law constants (version 4.0) for
% water as solvent (2015), pp. 4399-4402, pp. 4488

% reference Henry constant for CO2 at 298,15 K in [mol/(m3*Pa)]
fH_cp_CO2_reference = 3.3e-4;

% factor which is influenced by the enthalpy of dissolution of CO2
fEnthalpyFactor_CO2 = 2400;

% calculate current temperature dependent Henry Constant in [mol/(m3*Pa)]
fH_cp_CO2 = fH_cp_CO2_reference * exp( fEnthalpyFactor_CO2 * ( ( 1 / fCurrentTemp ) - ( 1 / 298.15 ))); 
     
% calculate the solubility concentration of CO2 in the solution in mol/L
fSolubilityCO2 = 0.001 * fPartialPressureCO2 * fH_cp_CO2;

% calculation of the dimensionless Henry solubility
% gas constant in J/(mol*K)
fR = 8.314;

fH_cc_CO2 = ( fR * fCurrentTemp ) * fH_cp_CO2;

% calculation of the gas concentration above the solution in mol/L
fCO2_gas_concentration = fSolubilityCO2 / fH_cc_CO2;

end