function [ cParams, sDefaultPhase ] = water(system, fVolume, fTemperature, fPressure)
%helper to create a water phase
%
% Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 293.15 K
%   rRH             - Relative humidity - ratio (default 0, max 1)
%   fPressure       - Pressure in Pa - default 29647 Pa

% Values from @matter.table
% fRm         = 8.314472;
% fMolMassH2O = 18;
% fMolMassO2  = 32;
% fMolMassCO2 = 44;
% fMolMassN2  = 28;

% Check input arguments, set default
%TODO for fTemperature, rRH, fPress -> key/value pairs?
if nargin < 3, fTemperature = 293.15; end;
%if nargin < 4, rRH          = 0;      end;
if nargin < 4, fPressure    = 28300; end;


%%Density calculation for water

fDensity = system.oMT.findProperty('H2O','fDensity','Pressure',fPressure,'Temperature',(fTemperature-273.15),'liquid');

%%


fMass = fDensity*fVolume;

% Matter composition
tfMass = struct(...
    'H2O', fMass ...
);



%TO DO: Check was only taken from N2Atmosphere
% Create cParams for a whole matter.phases.liquid standard phase. If user does
% not want to use all of them, can just use
% matter.phases.liquid(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature fPressure};


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.liquid';



end