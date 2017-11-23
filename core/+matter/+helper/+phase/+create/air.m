function [ cParams, sDefaultPhase ] = air(oStore, fVolume, fTemperature, rRH, fPressure)
%AIR helper to create an air matter phase.
%   If just volume given, created to suit the ICAO International Standard
%   Atmosphere of 101325 Pa, 15degC and 0% relative humidity, see:
%   http://en.wikipedia.org/wiki/International_Standard_Atmosphere
%
% air Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 288.15 K
%   rRH             - Relative humidity - ratio (default 0, max 1)
%   fPressure       - Pressure in Pa - default 101325 Pa

% Molar mass (air, constant, using value calculated by the matter class):
fMolarMassAir = 0.029088; % [kg/mol]

% Values from @matter.table
fRm           = oStore.oMT.Const.fUniversalGas;                 % ideal gas constant [J/K]
fMolarMassH2O = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.H2O);   % molar mass of water [kg/mol]
%fRw           = oStore.oMT.ttxMatter.H2O.fSpecificGasConstant;  % specific gas constant of water [J/(kg*K)]

% Check input arguments, set default
%TODO for fTemperature, rRH, fPress -> key/value pairs?
if nargin < 3 || isempty(fTemperature), fTemperature = matter.table.Standard.Temperature; end;
if nargin < 4 || isempty(rRH),          rRH          = 0;      end;
if nargin < 5 || isempty(fPressure),    fPressure    = matter.table.Standard.Pressure; end;

if rRH
    % Calculation of the saturation vapour pressure
    fSaturationVapourPressure = oStore.oMT.calculateVaporPressure(fTemperature, 'H2O');
    
    % calculate vapour pressure [Pa]
    fVapourPressure = rRH * fSaturationVapourPressure; 
    
    % calculate mass fraction of H2O in air
    fMassFractionH2O = fMolarMassH2O / fMolarMassAir * fVapourPressure / (fPressure - fVapourPressure);
    
    % calculate molar fraction of H2O in air
    fMolarFractionH2O = fMassFractionH2O / fMolarMassH2O * fMolarMassAir; 
    
    % calculate total mass
    % p V = m / M * R_m * T  <=>  m = p * V * M / (R_m * T)
    fTotalMass = fPressure * fVolume * (fMolarFractionH2O * fMolarMassH2O + (1 - fMolarFractionH2O) * fMolarMassAir) / (fRm * fTemperature); 
    
    % calculate dry air mass
    fDryAirMass = fTotalMass * (1 - fMassFractionH2O); 
    
else
    fDryAirMass = fPressure * fVolume * fMolarMassAir / fRm / fTemperature;
    
    % Need to set this to zero in case of dry air
    fTotalMass = 0;
    fMassFractionH2O = 0;
end
% Matter composition
tfMass = struct(...
    'N2',  0.75518 * fDryAirMass, ...
    'O2',  0.23135 * fDryAirMass, ...
    'Ar',  0.01288 * fDryAirMass, ...
    'CO2', 0.00058 * fDryAirMass ...
    );

%calculate H2O mass if present
tfMass.H2O = fTotalMass * fMassFractionH2O; 

% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';



end
