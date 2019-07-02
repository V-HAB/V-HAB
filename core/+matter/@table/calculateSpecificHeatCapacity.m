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

[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, ~, ~, bUseIsobaricData] = getNecessaryParameters(this, varargin{:});

% here decesion on when other calculations should be used could be placed
% (see calculateDensity function for example)

fSpecificHeatCapacity = calculateProperty(this, 'Heat Capacity', fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, bUseIsobaricData);

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
