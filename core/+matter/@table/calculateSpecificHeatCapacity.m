function fSpecificHeatCapacity = calculateSpecificHeatCapacity(this, varargin) %sMatterState, afMasses, fTemperature, fPressure)
%CALCULATESPECIFICHEATCAPACITY Calculate the specific heat capacity of a mixture
%    Calculates the specific heat capacity by adding the single substance
%    capacities weighted with their mass fraction. Can use either a phase
%    object as input parameter, or the phase type (sType) and the masses
%    array (afMasses). Optionally, temperature and pressure can be passed
%    as third and fourth parameters,
%    respectively.
%
%   Examples: fSpecificHeatCapacity = calculateSpecificHeatCapacity(oFlow);
%             fSpecificHeatCapacity = calculateSpecificHeatCapacity(oPhase);
%             fSpecificHeatCapacity = calculateSpecificHeatCapacity(sType, afMass, fTemperature, afPartialPressures);
%
% calculateHeatCapacity returns
%  fSpecificHeatCapacity  - specific, isobaric heat capacity of mix in J/kgK?

[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, ~, ~] = getNecessaryParameters(this, varargin{:});

% If no mass is given the heat capacity will be zero, so no need to do the
% rest of the calculation.
if sum(arPartialMass) == 0
    fSpecificHeatCapacity = 0;
    return;
end

% Make sure there is no NaN in the mass vector.
assert(~any(isnan(arPartialMass)), 'Invalid entries in mass vector.');

% Find substances with a mass bigger than zero and count the results.
% This helps in getting only the needed data from the matter table.
iNumIndices = length(aiIndices);

% Initialize a new array filled with zeros. Then iterate through all
% indexed substances and get their specific heat capacity.
afCp = zeros(iNumIndices, 1);

for iI = 1:iNumIndices
    % Creating the input struct for the findProperty() method
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Heat Capacity';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = afPartialPressures(aiIndices(iI));
    tParameters.bUseIsobaricData = true;
    
    % Now we can call the findProperty() method.
    afCp(iI) = this.findProperty(tParameters);
end

% Make sure there is no NaN in the specific heat capacity vector.
assert(~any(isnan(afCp)), 'Invalid entries in specific heat capacity vector.');

%DEBUG
assert(isequal(size(afCp), size(arPartialMass(aiIndices)')), 'Vectors must be of same length but one transposed.');

% Multiply the specific heat capacities with the mass fractions. The
% result of the matrix multiplication is the specific heat capacity of
% the mixture.
fSpecificHeatCapacity = arPartialMass(aiIndices) * afCp;

% Make sure the heat capacity value is valid.
assert(~isnan(fSpecificHeatCapacity) && fSpecificHeatCapacity >= 0, ...
    'Invalid heat capacity: %f', fSpecificHeatCapacity);

% "Most physical systems exhibit a positive heat capacity. However,
% there are some systems for which the heat capacity is negative. These
% are inhomogeneous systems which do not meet the strict definition of
% thermodynamic equilibrium.
% A more extreme version of this occurs with black holes. According to
% black hole thermodynamics, the more mass and energy a black hole
% absorbs, the colder it becomes. In contrast, if it is a net emitter
% of energy, through Hawking radiation, it will become hotter and
% hotter until it boils away."
%     -- http://en.wikipedia.org/wiki/Heat_capacity
%        (Retrieved: 2015-05-27 23:48 CEST)
end
