function [ cParams, sDefaultPhase ] = N2Atmosphere(oStore, fVolume, fTemperature, rRH, fPressure)
%N2ATMOSPHERE helper to create a matter phase with a space suit test
%   atmosphere using 99.9% nitrogen and 0.1% carbon dioxide. If just volume
%   given, created as a 99.9% nitrogen atmosphere at 28900 Pa, 20°C and 0%
%   relative humidity.
%
% SuitVolume Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 293.15 K
%   rRH             - Relative humidity - ratio (default 0, max 1)
%   fPressure       - Pressure in Pa - default 28900 Pa

% Values from @matter.table
% ideal gas constant [J/K]
fRm = oStore.oMT.Const.fUniversalGas; 

% Molecular mass of water in [kg/mol]
fMolarMassH2O = oStore.oMT.ttxMatter.H2O.fMolarMass; 

% Molecular mass of nitrogen in [kg/mol]
fMolarMassN2 = oStore.oMT.ttxMatter.N2.fMolarMass; 

% Check input arguments, set default
if nargin < 3 || isempty(fTemperature), fTemperature = matter.table.Standard.Temperature; end
if nargin < 4 || isempty(rRH),          rRH          = 0; end
if nargin < 5 || isempty(fPressure),    fPressure    = 28900; end

if rRH
    % Calculation of the saturation vapour pressure
    fSaturationVapourPressure = oStore.oMT.calculateVaporPressure(fTemperature, 'H2O');
    
    % calculate vapour pressure [Pa]
    fVapourPressure = rRH*fSaturationVapourPressure; 
    
    % calculate mass fraction of H2O in air
    fMassFractionH2O = fMolarMassH2O / fMolarMassN2 * fVapourPressure / (fPressure - fVapourPressure);
    
    % calculate molar fraction of H2O in air
    fMolarFractionH2O = fMassFractionH2O / fMolarMassH2O * fMolarMassN2; 
    
    % p V = m / M * R_m * T -> mol mass in g/mol so divide p*V=n*R*T;
    
    %calculate total mass
    fMassGes = (fPressure) * fVolume * ((fMolarFractionH2O * fMolarMassH2O + (1 - fMolarFractionH2O) * fMolarMassN2)) / fRm / fTemperature; 
    
    % calculate dry air mass
    fMass = fMassGes * (1 - fMassFractionH2O); 
    
else
    fMass = fPressure * fVolume * fMolarMassN2 / fRm / fTemperature;
    
    % Need to set this to zero in case of dry gas
    fMassGes = 0;
    fMassFractionH2O = 0;
end
% Matter composition
tfMass = struct(...
    'N2',  0.95 * fMass, ...
    'CO2', 0.05 * fMass ...
    );
% Calculate H2O mass if present 
tfMass.H2O = fMassGes * fMassFractionH2O; 

% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';



end