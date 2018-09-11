function [ cParams, sDefaultPhase ] = Flowphase(oStore, fVolume, fTemperature, rRH, fPressure)
%FLOWPHASE
%   TODO: figure out what this does and why we need this
%
% Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 273.15 K
%   rRH             - Relative humidity - ratio (default 0, max 1)
%   fPressure       - Pressure in Pa - default 101325 Pa

% Values from @matter.table
fRm           = oStore.oMT.Const.fUniversalGas;                 % ideal gas constant [J/K]
fMolarMassH2O = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.H2O);   % molar mass of water [kg/mol]

% Check input arguments, set default
%TODO for fTemperature, rRH, fPress -> key/value pairs?
if nargin < 3, fTemperature = 273.15; end
if nargin < 4, rRH          = 0;      end
if nargin < 5, fPressure    = 101325; end

% p V = m / M * R_m * T  <=>  m = p * V * M / (R_m * T)
fMass = fPressure * fVolume * fMolarMassH2O / (fRm * fTemperature);

% Matter composition
tfMass = struct(...
    'H2O',  0.5 * fMass, ...
    'CO2',  0.25 * fMass, ...
    'O2',  0.25 * fMass ...
);

% Check relative humidity - add?
% See http://en.wikipedia.org/wiki/Vapor_pressure
if rRH > 0
    fSatPressure = this.oMT.calculateVaporPressure(fTemperature, 'H2O');
    
    % Pressure to absolute mass - pV = nRT -> p is saturation pressure
    tfMass.H2O = fSatPressure * fMolarMassH2O / fRm / fTemperature * fVolume;
end


% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';



end
