function fThermalConductivity = calculateThermalConductivity(this, varargin)
%CALCULATECONDUCTIVITY Calculates the conductivity of the matter in a phase or flow
%   Calculates the conductivity of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance conductivity at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and pressure can be passed as third
%   and fourth parameters, respectively.
%
%   Examples: fThermalConductivity = calculateThermalConductivity(oFlow);
%             fThermalConductivity = calculateThermalConductivity(oPhase);
%             fThermalConductivity = calculateThermalConductivity(sType, afMass, fTemperature, afPartialPressures);
%
% calculateConductivity returns
%  fThermalConductivity - conductivity of matter in current state in W/mK


[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, ~, ~] = getNecessaryParameters(this, varargin{:});

% here decesion on when other calculations should be used could be placed
% (see calculateDensity function for example)

fThermalConductivity = calculateProperty(this, 'Thermal Conductivity', fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures);
end

