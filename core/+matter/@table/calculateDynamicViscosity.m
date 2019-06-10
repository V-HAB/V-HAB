function fEta = calculateDynamicViscosity(this, varargin)
%CALCULATEDYNAMICVISCOSITY Calculates the dynamic viscosity of the matter in a phase or flow
%   Calculates the dynamic viscosity of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance viscosities at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and pressure can be passed as third
%   and fourth parameters, respectively.
%
%   Examples: fEta = calculateDynamicViscosity(oFlow);
%             fEta = calculateDynamicViscosity(oPhase);
%             fEta = calculateDynamicViscosity(sType, afMass, fTemperature, afPartialPressures);
%
% calculateDynamicViscosity returns
%  fEta - dynamic viscosity of matter in current state in kg/ms

[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, ~, ~] = getNecessaryParameters(this, varargin{:});

% here decesion on when other calculations should be used could be placed
% (see calculateDensity function for example)

fEta = calculateProperty(this, 'Dynamic Viscosity', fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures);


end

