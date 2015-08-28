function [ cParams sDefaultPhase ] = Flowphase(~, fVolume, fTemperature, rRH, fPressure)
%AIR helper to create an air matter phase.
%   If just volume given, created to suit the ICAO International Standard
%   Atmosphere of 101325 Pa, 15°C and 0% relative humidity, see:
%   http://en.wikipedia.org/wiki/International_Standard_Atmosphere
%
% air Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 273.15 K
%   rRH             - Relative humidity - ratio (default 0, max 1)
%   fPressure       - Pressure in Pa - default 101325 Pa

% Molecular mass (air, constant, from:
% http://www.engineeringtoolbox.com/molecular-mass-air-d_679.html)
fMolMassAir = 28.97;    % [g/mol]
% Not exactly true since some trace gases are missing here. Updated from 
% the mol mass calculated by the matter class - fits better
fMolMassAir = 29.088;

% Values from @matter.table
fRm         = 8.314472;
fMolMassH2O = 18;
fMolMassCO2 = 44;
fMolMassO2 = 32;
% Check input arguments, set default
%TODO for fTemperature, rRH, fPress -> key/value pairs?
if nargin < 3, fTemperature = 273.15; end;
if nargin < 4, rRH          = 0;      end;
if nargin < 5, fPressure    = 101325; end;

% p V = m / M * R_m * T -> mol mass in g/mol so divide
fMass = fPressure * fVolume * (fMolMassH2O / 1000) / fRm / fTemperature;

% Matter composition
tfMass = struct(...
    'H2O',  0.5 * fMass, ...
    'CO2',  0.25 * fMass, ...
    'O2',  0.25 * fMass ...
);

% Check relative humidity - add?
% See http://en.wikipedia.org/wiki/Vapor_pressure
if rRH > 0
    fSatPressure = 6.11213 * exp(17.62 * fTemperature / (243.12 + fTemperature)) * 100;
    
    % Pressure to absolute mass - pV = nRT -> p is saturation pressure
    tfMass.H2O = fSatPressure * (fMolMassH2O / 1000) / fRm / fTemperature * fVolume;
end


% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';



end