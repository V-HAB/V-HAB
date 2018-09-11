function [ cParams, sDefaultPhase ] = MarsOneAtmosphere(oStore, fVolume, fTemperature, rRH, fPressure)
%MARSONEATMOSPHERE Summary of this function goes here
%   Detailed explanation goes here

    % atmosphere Parameters:
    %   fVolume         - Volume in SI m3
    %   fTemperature    - Temperature in K - default 288.15 K
    %   rRH             - Relative humidity - ratio (default 0, max 1)
    %   fPressure       - Pressure in Pa - default 101325 Pa

    % Molar mass of dry air in the Mars One Specification of:
    %   Individual:                                     Totals:
    %
    %   20  kPa O2                                      O2:  28.43 %  
    %
    %   507  Pa CO2 (max value)                         CO2:  0.72 %
    %
    %   60% of the rest is Nitrogen
    % -> (70300 Pa - ppO2 - ppCO2) * 0.6 = 29894 Pa     N2:  42.51 %
    %
    %   40% of the rest is Argon
    % -> (70300 Pa - ppO2 - ppCO2) * 0.4 = 19929 Pa     Ar:  28.34 %
    
    fVolumeFractionO2  = 0.2843;
    fVolumeFractionCO2 = 0.0072;
    fVolumeFractionN2  = 0.4251;
    fVolumeFractionAr  = 0.2834;
    
    
    fMolarMassAir = 0.0320083; % [kg/mol]
    
    % Values from @matter.table
    fUniversalGasConstant = matter.table.Const.fUniversalGas;
    fMolarMassH2O         = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.H2O);

    % Check input arguments, set default
    %TODO for fTemp, rRH, fPress -> key/value pairs?
    if nargin < 3 || isempty(fTemperature), fTemperature = 291.15; end
    if nargin < 4 || isempty(rRH),          rRH          = 0.43;   end
    if nargin < 5 || isempty(fPressure),    fPressure    = 70330;  end

    if rRH
        % Calculation of the saturation vapour pressure
        fSaturationVapourPressure = this.oMT.calculateVaporPressure(fTemperature, 'H2O');
    
        % calculate vapour pressure [Pa]
        fVapourPressure = rRH * fSaturationVapourPressure; 
    
        % calculate mass fraction of H2O in air
        fMassFractionH2O = fMolarMassH2O / fMolarMassAir * fVapourPressure / (fPressure - fVapourPressure);
        % calculate molar fraction of H2O in air
        fMolarFractionH2O = fMassFractionH2O / fMolarMassH2O * fMolarMassAir; 
    
        % calculate total mass
        % p V = m / M * R_m * T  <=>  m = p * V * M / (R_m * T)
        fTotalMass = fPressure * fVolume * (fMolarFractionH2O * fMolarMassH2O + (1 - fMolarFractionH2O) * fMolarMassAir) / (fUniversalGasConstant * fTemperature); 
    
        % calculate dry air mass
        fDryAirMass = fTotalMass * (1 - fMassFractionH2O); 
    
    else
        fDryAirMass = fPressure * fVolume * fMolarMassAir / fUniversalGasConstant / fTemperature;
    
        % Need to set this to zero in case of dry air
        fTotalMass = 0;
        fMassFractionH2O = 0;
    end
    
    % Getting the molar masses for the four substances
    fMolarMassN2  = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.N2);
    fMolarMassO2  = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.O2);
    fMolarMassAr  = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.Ar);
    fMolarMassCO2 = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.CO2);
    
    % Calculating the mass fractions
    fMassFractionN2  = fMolarMassN2  / fMolarMassAir * fVolumeFractionN2;
    fMassFractionO2  = fMolarMassO2  / fMolarMassAir * fVolumeFractionO2;
    fMassFractionAr  = fMolarMassAr  / fMolarMassAir * fVolumeFractionAr;
    fMassFractionCO2 = fMolarMassCO2 / fMolarMassAir * fVolumeFractionCO2;
    
    
    % Matter composition
    tfMass = struct(...
        'N2',  fMassFractionN2  * fDryAirMass, ...
        'O2',  fMassFractionO2  * fDryAirMass, ...
        'Ar',  fMassFractionAr  * fDryAirMass, ...
        'CO2', fMassFractionCO2 * fDryAirMass ...
        );
    tfMass.H2O = fTotalMass * fMassFractionH2O; %calculate H2O mass if present

    % Create cParams for a whole matter.phases.gas standard phase. If user does
    % not want to use all of them, can just use
    % matter.phases.gas(oMT.create('air'){1:2}, ...)
    cParams = { tfMass fVolume fTemperature };


    % Default class - required for automatic construction of phase. Helper re-
    % turns the default phase that could be constructed with this set of params
    sDefaultPhase = 'matter.phases.gas';
end

