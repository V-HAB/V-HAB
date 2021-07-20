function fCurrentNH3gas = NH3_Outgassing(fCurrentTemp, fCurrentOHminus, fCurrentNH3, fCurrentNH4, fCurrent_CO2_gas, fH_cc_CO2)
% This function calculates the current NH3 gas concentration in the gas phase above a solution
% at ambient pressure in the presence of CO2 gas (unit for all concentrations: mol/L).
% The empirical calculation is based on the current temperature, ammonia and
% ammonium concentrations in the solution, concentration of OH_minus in the solution and the
% concentration of CO2 in the gas phase, which depends on CO2 solubility in the solution.
% For this reason, the effect of CO2 solubility needs to be calculated first.
% Source: Hales and Drewes 1979: "solubilty of ammonia in water at low
% concentrations", in Atmospheric Environment Vol 13, pp. 1133-1147

% current total ammonia and ammonium concentration in the solution in mol/L
fCurrentTotalAmmonia = fCurrentNH3 + fCurrentNH4;

% empirical dimensionless Henry solubility of ammonia without the effect of CO2 concentration
fH_cc_NH3 = 10^( -1.694 + ( 1477.7 / fCurrentTemp ));

% empirical solubility parameters
fP = 10^( 28.068 - ( 5937.7 / fCurrentTemp ));
fQ = 10^( 25.266 - ( 6417.8 / fCurrentTemp ));

% ion product of water at 25°C, which for this calculation is estimated to
% be constant
fK_W = 1e-14;

% calculation of ammonia dissociation constant K_diss_NH3 in water with 
% empirical equilibrium constant K_a 
fK_a = 10^( -0.09018 - ( 2729.92 / fCurrentTemp ));

fK_diss_NH3 = fK_W / fK_a;

% calculate the current concentration of NH3 in the gas phase above the
% solution in mol/L
fCurrentNH3gas = ( fCurrentTotalAmmonia / fH_cc_NH3 ) * ( fH_cc_NH3 * fH_cc_CO2 * fCurrent_CO2_gas * fQ + 1 ) ...
                        / ( fH_cc_CO2 * fCurrent_CO2_gas * fP + ( (fK_diss_NH3 / fCurrentOHminus ) + 1 ));

end