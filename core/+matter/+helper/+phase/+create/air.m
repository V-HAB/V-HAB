function [ cParams, sDefaultPhase ] = air(~, fVolume, fTemperature, rRH, fPressure)
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

% Molecular mass of dry air
fMolMassAir = 28.9586;     % [g/mol]

% Values from @matter.table
fRm         = 8.314472;  % ideal gas constant [J/K]
fMolMassH2O = 18.015275; % molar mass of water [g/mol]
fRw         = 461.9151;  % specific gas constant of water [J/(kg*K)]

% Check input arguments, set default
%TODO for fTemp, rRH, fPress -> key/value pairs?
if nargin < 3 || isempty(fTemperature), fTemperature = matter.table.Standard.Temperature; end;
if nargin < 4 || isempty(rRH),          rRH          = 0;      end;
if nargin < 5 || isempty(fPressure),    fPressure    = matter.table.Standard.Pressure; end;

if rRH
    % Calculation of the saturation vapour pressure
    % by using the MAGNUS Formula(validity: -45degC <= T <= 60degC, for
    % water); Formula is only correct for pure steam, not the mixture
    % of air and water; enhancement factors can be used by a
    % Poynting-Correction (pressure and temperature dependent); the values of the enhancement factors are in
    % the range of 1+- 10^-3; thus they are neglected.
    %Source: Important new Values of the Physical Constants of 1986, Vapour
    % Pressure Formulations based on ITS-90, and Psychrometer Formulae. In: Z. Meteorol.
    % 40, 5, S. 340-344, (1990)
    
    fSaturationVapourPressure = 6.11213 * exp(17.62 * (fTemperature-273.15) / (243.12 + (fTemperature-273.15))) * 100;
    
    % calculate vapour pressure [Pa]
    fVapourPressure=rRH*fSaturationVapourPressure; 
    
    % calculate mass fraction of H2O in air
    fMassFractionH2O=fMolMassH2O/fMolMassAir*fVapourPressure/(fPressure-fVapourPressure);
    
    % calculate molar fraction of H2O in air
    fMolarFractionH2O=fMassFractionH2O/fMolMassH2O*fMolMassAir; 
    
    % p V = m / M * R_m * T -> mol mass in g/mol so divide p*V=n*R*T;
    
    %calculate total mass
    fMassGes = (fPressure) * fVolume * ((fMolarFractionH2O*fMolMassH2O+(1-fMolarFractionH2O)*fMolMassAir) / 1000) / fRm / fTemperature; 
    
    % calculate dry air mass
    fMass=fMassGes*(1-fMassFractionH2O); 
    
else
    fMass = fPressure * fVolume * (fMolMassAir / 1000) / fRm / fTemperature;
    
    % Need to set this to zero in case of dry air
    fMassGes = 0;
    fMassFractionH2O = 0;
end
% Matter composition
tfMass = struct(...
    'N2',  0.75518 * fMass, ...
    'O2',  0.23135 * fMass, ...
    'Ar',  0.01288 * fMass, ...
    'CO2', 0.00058 * fMass ...
    );
tfMass.H2O=fMassGes*fMassFractionH2O; %calculate H2O mass if present

% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';



end