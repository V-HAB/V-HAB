function [ cParams, sDefaultPhase ] = liquid(oStore, fVolume, trMassRatios, fTemperature, fPressure)
%helper to create a water phase
%
% Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 293.15 K
%   fPressure       - Pressure in Pa - default 28300 Pa

% Check input arguments, set default
%TODO for fTemperature, rRH, fPress -> key/value pairs?
if nargin < 3, fTemperature = 293.15; end
if nargin < 4, fPressure    = 28300; end

mrMassRatios = zeros(1, oStore.oMT.iSubstances);
csSubstances = fieldnames(trMassRatios);

% from the struct we create the mass ratio vector
for iSubstance = 1:length(csSubstances)
    mrMassRatios(oStore.oMT.tiN2I.(csSubstances{iSubstance})) = trMassRatios.(csSubstances{iSubstance});
end

% Now we calculate the overall density using the mass ratio struct as input
% for the calculate function
afPressures = ones(1, oStore.oMT.iSubstances) .* fPressure;
fDensity = oStore.oMT.calculateDensity('liquid', mrMassRatios, fTemperature, afPressures);

% Using this density we can calculate the overall mass that should be in
% the phase
fMass = fDensity * fVolume;

% And using that overall mass and the provided mass ratios we can calculate
% the partial masses for the different substances

tfMass = struct();
for iSubstance = 1:length(csSubstances)
    tfMass.(csSubstances{iSubstance}) = fMass * trMassRatios.(csSubstances{iSubstance});
end

% Create cParams for a whole matter.phases.liquid standard phase. If user does
% not want to use all of them, can just use
cParams = { tfMass fTemperature fPressure};

% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.liquid';

end
