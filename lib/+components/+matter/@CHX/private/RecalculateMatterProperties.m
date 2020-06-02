function [ tInput ] = RecalculateMatterProperties( oMT, tInput )
%% RecalculateMatterProperties
% Function used in the CHX to recalculate all required matter properties if
% necessary

% First we define some of the required inputs
fSurfaceTemperatureInitialization   = ( tInput.fTemperatureGas + tInput.fTemperatureCoolant) / 2;
afMolarMass                         = (tInput.arPartialMassesGas ./ oMT.afMolarMass);
afPartialPressures                  = tInput.fPressureGas .* afMolarMass/sum(afMolarMass);

arVapor = zeros(1,oMT.iSubstances);
arVapor(oMT.tiN2I.(tInput.Vapor))   = afPartialPressures(oMT.tiN2I.(tInput.Vapor));
afPressureCoolant                   = oMT.calculatePartialPressures(tInput.oFlowCoolant);

%% Matter Properties of coolant
tInput.fDynamicViscosityFilm        = oMT.calculateDynamicViscosity('liquid', arVapor, fSurfaceTemperatureInitialization);	% Dynamic Visc Film [kg/(m*s)]
tInput.fDensityFilm                 = oMT.calculateDensity('liquid', arVapor, fSurfaceTemperatureInitialization);				% Density Film [kg/m^3]
tInput.fSpecificHeatCapacityFilm    = oMT.calculateSpecificHeatCapacity('liquid', arVapor, fSurfaceTemperatureInitialization);			% Specific Heat Capacity Film [J/(kg*K)]
tInput.fThermalConductivityFilm     = oMT.calculateThermalConductivity('liquid', arVapor, fSurfaceTemperatureInitialization);	% Thermal Conductivity Film [W/(m*K)]
tInput.fSpecificHeatCapacityCoolant = oMT.calculateSpecificHeatCapacity('liquid', afPressureCoolant, tInput.fTemperatureCoolant, afPressureCoolant);

%% Matter Properties of gas
tInput.fDensityGas                  = oMT.calculateDensity('gas', tInput.arPartialMassesGas, tInput.fTemperatureGas, afPartialPressures);
tInput.fDynamicViscosityGas         = oMT.calculateDynamicViscosity('gas', tInput.arPartialMassesGas, tInput.fTemperatureGas, afPartialPressures);
tInput.fKinematicViscosityGas       = tInput.fDynamicViscosityGas / tInput.fDensityGas;		% nu = eta/rho
tInput.fSpecificHeatCapacityGas     = oMT.calculateSpecificHeatCapacity('gas', tInput.arPartialMassesGas, tInput.fTemperatureGas, afPartialPressures);
tInput.fThermalConductivityGas      = oMT.calculateThermalConductivity('gas', tInput.arPartialMassesGas, tInput.fTemperatureGas, afPartialPressures);
tInput.fMolarFractionGas            = 1 - tInput.fMolarFractionVapor;		% Mole Fraction Inertgas [mol/mol]
end