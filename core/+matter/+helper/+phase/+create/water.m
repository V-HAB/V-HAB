function [ cParams, sDefaultPhase ] = water(oStore, fVolume, fTemperature, fPressure)
%helper to create a water phase
%
% Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 293.15 K
%   fPressure       - Pressure in Pa - default 28300 Pa

% Check input arguments, set default
%TODO for fTemperature, rRH, fPress -> key/value pairs?
if nargin < 3, fTemperature = 293.15; end;
if nargin < 4, fPressure    = 28300; end;


%%Density calculation for water

fDensity = oStore.oMT.findProperty('H2O', 'Density', ...
    'Pressure', fPressure, 'Temperature', fTemperature, ...
    'liquid');

%%

fMass = fDensity * fVolume;

% Matter composition
tfMass = struct(...
    'H2O', fMass ...
);

% Create cParams for a whole matter.phases.liquid standard phase. If user does
% not want to use all of them, can just use
% matter.phases.liquid(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature fPressure};

% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.liquid';

end
