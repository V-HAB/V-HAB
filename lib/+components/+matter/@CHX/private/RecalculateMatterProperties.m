function [ tInput ] = RecalculateMatterProperties( oMT, tInput, iFluid, tFluid)
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
if iFluid == 2
    tInput.fDynamicViscosityFilm        = oMT.calculateDynamicViscosity('liquid', arVapor, fSurfaceTemperatureInitialization);	% Dynamic Visc Film [kg/(m*s)]
    tInput.fDensityFilm                 = oMT.calculateDensity('liquid', arVapor, fSurfaceTemperatureInitialization);				% Density Film [kg/m^3]
    tInput.fSpecificHeatCapacityFilm    = oMT.calculateSpecificHeatCapacity('liquid', arVapor, fSurfaceTemperatureInitialization);			% Specific Heat Capacity Film [J/(kg*K)]
    tInput.fThermalConductivityFilm     = oMT.calculateThermalConductivity('liquid', arVapor, fSurfaceTemperatureInitialization);	% Thermal Conductivity Film [W/(m*K)]
    tInput.fSpecificHeatCapacityCoolant = oMT.calculateSpecificHeatCapacity('liquid', afPressureCoolant, tInput.fTemperatureCoolant, afPressureCoolant);
    if tInput.fDynamicViscosityFilm == 0
        % Assume dynamic viscosity of water if we currently have no film,
        % to prevent errors in the reynolds calculation
        tInput.fDynamicViscosityFilm        = 8.9e-4;
        tInput.fDensityFilm                 = 998;
        tInput.fSpecificHeatCapacityFilm    = 4184;
        tInput.fThermalConductivityFilm     = 0.6;
        tInput.fSpecificHeatCapacityCoolant = 4184;
    end
    [~, tInput.tDimensionlessQuantitiesCoolant] = functions.calculateHeatTransferCoefficient.convectionFlatGap(tInput.fHeight_2 * 2, tInput.fBroadness, tFluid.fFlowSpeed_Fluid,...
                tFluid.fDynamic_Viscosity, tFluid.fDensity, tFluid.fThermal_Conductivity, tFluid.fSpecificHeatCapacity, 1);
            
else
%% Matter Properties of gas
    tInput.fDensityGas                  = oMT.calculateDensity('gas', tInput.arPartialMassesGas, tInput.fTemperatureGas, afPartialPressures);
    tInput.fDynamicViscosityGas         = oMT.calculateDynamicViscosity('gas', tInput.arPartialMassesGas, tInput.fTemperatureGas, afPartialPressures);
    tInput.fKinematicViscosityGas       = tInput.fDynamicViscosityGas / tInput.fDensityGas;		% nu = eta/rho
    tInput.fSpecificHeatCapacityGas     = oMT.calculateSpecificHeatCapacity('gas', tInput.arPartialMassesGas, tInput.fTemperatureGas, afPartialPressures);
    tInput.fThermalConductivityGas      = oMT.calculateThermalConductivity('gas', tInput.arPartialMassesGas, tInput.fTemperatureGas, afPartialPressures);
    tInput.fMolarFractionGas            = 1 - tInput.fMolarFractionVapor;		% Mole Fraction Inertgas [mol/mol]
    
    DiffCoeff_Gas = Bin_diff_coeff(tInput.Vapor, tInput.Inertgas, tInput.fTemperatureGas, tInput.fPressureGas);
    
    [~, tInput.tDimensionlessQuantitiesGas] = functions.calculateHeatTransferCoefficient.convectionFlatGap(tInput.fHeight_1 * 2, tInput.fLength, tFluid.fFlowSpeed_Fluid,...
                tFluid.fDynamic_Viscosity, tFluid.fDensity, tFluid.fThermal_Conductivity, tFluid.fSpecificHeatCapacity, 1);
    
    % No this is not a typo, the Sherwood number can be calculated using the
    % same equations as the nusselt number, by just using Sc instead of Pr. See
    % the VDI heat atlas section which is mentioned in the function!
    tInput.tDimensionlessQuantitiesGas.fSc = tInput.fKinematicViscosityGas / DiffCoeff_Gas;		
    tInput.tDimensionlessQuantitiesGas.fSh = functions.calculateHeatTransferCoefficient.calculateNusseltFlatGap(tInput.tDimensionlessQuantitiesGas.fRe, tInput.tDimensionlessQuantitiesGas.fSc, tInput.fHeight_1 * 2, tInput.fLength, 1);

    tInput.tDimensionlessQuantitiesGas.beta_Gas_0 = tInput.tDimensionlessQuantitiesGas.fSh * DiffCoeff_Gas / tInput.fHeight_1 * 2;												% Mass transfer coefficient gas mixture [m/s], (2.45)

            
end
end