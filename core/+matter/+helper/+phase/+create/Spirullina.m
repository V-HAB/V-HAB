function [ cParams, sDefaultPhase ] = Spirullina(oStore, fVolume, fTemperature, rRH, fPressure)
%SPIRULLINA Detailed explanation here

% Values from @matter.table
fRm           = oStore.oMT.Const.fUniversalGas;                 % ideal gas constant [J/K]
fMolarMassCO2 = oStore.oMT.afMolarMass(oStore.oMT.tiN2I.CO2);   % molar mass of CO2 [kg/mol]


% Check input arguments, set default
%TODO for fTemperature, rRH, fPress -> key/value pairs?
if nargin < 3, fTemperature = 273.15; end;
if nargin < 4, rRH          = 0;      end;
if nargin < 5, fPressure    = 101325; end;

% p V = m / M * R_m * T  <=>  m = p * V * M / (R_m * T)
fMass = fPressure * fVolume * fMolarMassCO2 / (fRm * fTemperature);

% Matter composition
tfMass = struct('Spirullina', fMass * 1);

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
sDefaultPhase = 'matter.phases.liquid';


end
