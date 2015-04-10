function [ cParams, sDefaultPhase ] = N2Atmosphere(~, fVolume, fTemperature, rRH, fPressure)
%SUITATMOSPHERE helper to create a matter phase with a standard space suit
%   atmosphere using 100% oxygen.
%   If just volume given, created as a 100% oxygen atmosphere at 29647 Pa, 
%   20°C and 0% relative humidity.
%
% SuitVolume Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 293.15 K
%   rRH             - Relative humidity - ratio (default 0, max 1)
%   fPressure       - Pressure in Pa - default 29647 Pa

% Values from @matter.table
fRm         = 8.314472;
% fMolMassH2O = 18;
% fMolMassO2  = 32;
% fMolMassCO2 = 44;
fMolMassN2  = 28;

% Check input arguments, set default
%TODO for fTemp, rRH, fPress -> key/value pairs?
if nargin < 3, fTemperature = 293.15; end;
if nargin < 4, rRH          = 0;      end;
if nargin < 5, fPressure    = 28300; end;

% p V = m / M * R_m * T -> mol mass in g/mol so divide
fMass = fPressure * fVolume * (fMolMassN2 / 1000) / fRm / fTemperature;

% Matter composition
tfMass = struct(...
    'N2',  fMass * 0.999, ...
    'CO2', fMass * 0.001 ...
);

% Check relative humidity - add? For now its just zero.
% See http://en.wikipedia.org/wiki/Vapor_pressure
% http://de.wikipedia.org/wiki/Ambrose-Walton-Methode
if rRH > 0
    tfMass.H2O = 0;
end


% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';



end