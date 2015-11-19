function [ cParams, sDefaultPhase ] = air_custom(oStore, fVolume, trMasses, fTemperature, rRH, fPressure)
%AIR helper to create an air matter phase.
%   If just volume given, created to suit the ICAO International Standard
%   Atmosphere of 101325 Pa, 15[C] and 0% relative humidity, see:
%   http://en.wikipedia.org/wiki/International_Standard_Atmosphere
%
% air Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 273.15 K
%   rRH             - Relative humidity - ratio (default 0, max 1)
%   fPressure       - Pressure in Pa - default 101325 Pa

% Molar mass (air, constant, using value calculated by the matter class):
fMolarMassAir = 0.029088; % [kg/mol]

% Values from @matter.table
fRm           = oStore.oMT.Const.fUniversalGas;                 % ideal gas constant [J/K]
fMolarMassH2O = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.H2O);   % molar mass of water [kg/mol]

% Check input arguments, set default
%TODO for fTemperature, rRH, fPress -> key/value pairs?
if nargin < 4 || isempty(fTemperature), fTemperature = 273.15; end;
if nargin < 5 || isempty(rRH),          rRH          = 0;      end;
if nargin < 6 || isempty(fPressure),    fPressure    = 101325; end;

% Calculation of the saturation vapour pressure
% by using the MAGNUS Formula(validity: -45[C] <= T <= 60[C], for
% water); Formula is only correct for pure steam, not the mixture
% of air and water; enhancement factors can be used by a
% Poynting-Correction (pressure and temperature dependent); the values of the enhancement factors are in
% the range of 1+- 10^-3; thus they are neglected.
%Source: Important new Values of the Physical Constants of 1986, Vapour
% Pressure Formulations based on ITS-90, and Psychrometer Formulae. In: Z. Meteorol.
% 40, 5, S. 340-344, (1990)

fSaturationVapourPressure = 6.11213 * exp(17.62 * (fTemperature-273.15) / (243.12 + (fTemperature-273.15))) * 100; 

% calculate vapour pressure [Pa]
fVapourPressure = rRH * fSaturationVapourPressure; 

% calculate mass fraction of H2O in air
fMassFractionH2O = fMolarMassH2O / fMolarMassAir * fVapourPressure / (fPressure - fVapourPressure);

% calculate molar fraction of H2O in air
fMolarFractionH2O = fMassFractionH2O / fMolarMassH2O * fMolarMassAir; 

% calculate total mass
% p V = m / M * R_m * T  <=>  m = p * V * M / (R_m * T)
fMassGes = fPressure * fVolume * (fMolarFractionH2O * fMolarMassH2O + (1 - fMolarFractionH2O) * fMolarMassAir) / (fRm * fTemperature); 
% calculate dry air mass
fMass    = fMassGes * (1 - fMassFractionH2O); 


% Defaults, if not set
if ~isstruct(trMasses), trMasses = struct(); end;

if ~isfield(trMasses, 'O2'),  trMasses.O2  = 0.23135; end;
if ~isfield(trMasses, 'Ar'),  trMasses.Ar  = 0.01288; end;
if ~isfield(trMasses, 'CO2'), trMasses.CO2 = 0.00058; end;

% N2 takes remaining fraction
trMasses.N2 = 1 - trMasses.O2 - trMasses.Ar - trMasses.CO2;

% Matter composition
tfMass = struct(...
    'N2',  trMasses.N2  * fMass, ...
    'O2',  trMasses.O2  * fMass, ...
    'Ar',  trMasses.Ar  * fMass, ...
    'CO2', trMasses.CO2 * fMass ...
);
tfMass.H2O = fMassGes * fMassFractionH2O; %calculate H2O mass

% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';



end
