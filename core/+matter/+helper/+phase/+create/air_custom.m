function [ cParams, sDefaultPhase ] = air_custom(~, fVolume, trMasses, fTemperature, rRH, fPressure)
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

% Molecular mass (air, constant, from:
% http://www.engineeringtoolbox.com/molecular-mass-air-d_679.html)
% fMolMassAir = 28.97;    % [g/mol]
% Not exactly true since some trace gases are missing here. Updated from 
% the mol mass calculated by the matter class - fits better
fMolMassAir = 29.088;     % [g/mol]

% Values from @matter.table
fRm         = 8.314472;
fMolMassH2O = 18;
fRw = 461.9151; %sezifische Gaskonstante Wasser [J/(kg*K)]
% Check input arguments, set default
%TODO for fTemp, rRH, fPress -> key/value pairs?
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
fVapourPressure=rRH*fSaturationVapourPressure; % calculate vapour pressure [Pa]
fMassFractionH2O=fMolMassH2O/fMolMassAir*fVapourPressure/(fPressure-fVapourPressure);% calculate mass fraction of H2O in air
fMolarFractionH2O=fMassFractionH2O/fMolMassH2O*fMolMassAir; % calculate molar fraction of H2O in air

% p V = m / M * R_m * T -> mol mass in g/mol so divide p*V=n*R*T;

fMassGes = (fPressure) * fVolume * ((fMolarFractionH2O*fMolMassH2O+(1-fMolarFractionH2O)*fMolMassAir) / 1000) / fRm / fTemperature; %calculate total mass
fMass=fMassGes*(1-fMassFractionH2O); % calculate dry air mass


% Defaults, if not set
if ~isstruct(trMasses), trMasses = struct(); end;

if ~isfield(trMasses, 'O2'), trMasses.O2  = 0.23135; end;
if ~isfield(trMasses, 'Ar'), trMasses.Ar  = 0.01288; end;
if ~isfield(trMasses, 'Ar'), trMasses.CO2 = 0.00058; end;

% N2 takes remaining fraction
trMasses.N2 = 1 - trMasses.O2 - trMasses.Ar - trMasses.CO2;

% Matter composition
tfMass = struct(...
    'N2',  trMasses.N2  * fMass, ...
    'O2',  trMasses.O2  * fMass, ...
    'Ar',  trMasses.Ar  * fMass, ...
    'CO2', trMasses.CO2 * fMass ...
);
tfMass.H2O=fMassGes*fMassFractionH2O; %calculate H2O mass

% Check relative humidity - add?
% See http://en.wikipedia.org/wiki/Vapor_pressure
% if rRH > 0
%     fSatPressure = 6.11213 * exp(17.62 * fTemperature / (243.12 + fTemperature)) * 100;
%     
%     % Pressure to absolute mass - pV = nRT -> p is saturation pressure
%     tfMass.H2O = fSatPressure * (fMolMassH2O / 1000) / fRm / fTemperature * fVolume;
% end


% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';



end