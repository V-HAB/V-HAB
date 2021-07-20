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



% Defaults, if not set
if ~isstruct(trMasses), trMasses = struct(); end

if ~isfield(trMasses, 'O2'),  trMasses.O2  = 0.23135; end
if ~isfield(trMasses, 'Ar'),  trMasses.Ar  = 0.01288; end
if ~isfield(trMasses, 'CO2'), trMasses.CO2 = 0.00058; end

% Values from @matter.table
fRm           = oStore.oMT.Const.fUniversalGas;                 % ideal gas constant [J/K]
fMolarMassH2O = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.H2O);   % molar mass of water [kg/mol]

% Check input arguments, set default
%TODO for fTemperature, rRH, fPress -> key/value pairs?
if nargin < 4 || isempty(fTemperature), fTemperature = 273.15; end
if nargin < 5 || isempty(rRH),          rRH          = 0;      end
if nargin < 6 || isempty(fPressure),    fPressure    = 101325; end

trMasses.N2 = 1 - trMasses.O2 - trMasses.Ar - trMasses.CO2;

% Molar mass - use matter table to calculate using pseudo masses - do not
% know the absolute values yet, but molar mass just depends on relative
% weights of the substances!
afPseudoMasses = zeros(1, oStore.oMT.iSubstances);
csFields = fieldnames(trMasses);

for iS = 1:length(csFields)
    afPseudoMasses(oStore.oMT.tiN2I.(csFields{iS})) = trMasses.(csFields{iS});
end

fMolarMass = oStore.oMT.calculateMolarMass(afPseudoMasses); %0.029088; % [kg/mol]

% Calculation of the saturation vapour pressure
fSaturationVapourPressure = oStore.oMT.calculateVaporPressure(fTemperature, 'H2O');

% calculate vapour pressure [Pa]
fVapourPressure = rRH * fSaturationVapourPressure; 

fMolarMassNew = inf;
iCounter = 0;

while abs(fMolarMass - fMolarMassNew) > 1e-8 && iCounter < 500
    fMolarMass = fMolarMassNew;
    % calculate mass fraction of H2O in air
    trMasses.H2O = fMolarMassH2O / fMolarMass * fVapourPressure / (fPressure - fVapourPressure);

    % N2 takes remaining fraction
    trMasses.N2 = 1 - trMasses.O2 - trMasses.Ar - trMasses.CO2 - trMasses.H2O;

    % Molar mass - use matter table to calculate using pseudo masses - do not
    % know the absolute values yet, but molar mass just depends on relative
    % weights of the substances!
    afPseudoMasses = zeros(1, oStore.oMT.iSubstances);
    csFields = fieldnames(trMasses);

    for iS = 1:length(csFields)
        afPseudoMasses(oStore.oMT.tiN2I.(csFields{iS})) = trMasses.(csFields{iS});
    end

    fMolarMassNew = oStore.oMT.calculateMolarMass(afPseudoMasses); %0.029088; % [kg/mol]
    iCounter = iCounter + 1;
end

% calculate total mass
% p V = m / M * R_m * T  <=>  m = p * V * M / (R_m * T)
fMassGes = fPressure * fVolume * fMolarMass / (fRm * fTemperature); 
% calculate dry air mass
fMass    = fMassGes * (1 - trMasses.H2O); 

% Matter composition
tfMass = struct(...
    'N2',  trMasses.N2  * fMass, ...
    'O2',  trMasses.O2  * fMass, ...
    'Ar',  trMasses.Ar  * fMass, ...
    'CO2', trMasses.CO2 * fMass, ...
    'H2O', trMasses.H2O * fMass ...
);

% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };

% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';

end
