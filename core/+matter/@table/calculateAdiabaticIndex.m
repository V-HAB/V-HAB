function fAdiabaticIndex = calculateAdiabaticIndex(this, varargin)
%CALCULATEADIABATICINDEX Calculates the adiabatic index matter
%   Calculates the density of the matter inside a phase or the matter
%   flowing through the flow object or matter with the provided properties.
%   The adiabatic indexs is defined as the ratio between the isobaric and
%   isochoric specific heat capacities of a gas. 
%
%   Examples: fAdiabaticIndex = calculateAdiabaticIndex(oFlow);
%             fAdiabaticIndex = calculateAdiabaticIndex(oPhase);
%             fAdiabaticIndex = calculateAdiabaticIndex(sType, xfMass, fTemperature, afPartialPressures);
%
% calculateAdiabaticIndex returns
%  fAdiabaticIndex - adiabatic index of the gas

% Getting the parameters for the calculation
[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, ~, ~, ~] = getNecessaryParameters(this, varargin{:});

% First we get the isobaric heat capacity
bUseIsoBaricData = true;
fIsobaricSpecificHeatCapacity = calculateProperty(this, 'Heat Capacity', fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, bUseIsoBaricData);

% Now we get the isochoric heat capacity
bUseIsoBaricData = false;
fIsochoricSpecificHeatCapacity = calculateProperty(this, 'Heat Capacity', fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, bUseIsoBaricData);

% And finally we can calulate the adiabatic index by simple divison.
fAdiabaticIndex = fIsobaricSpecificHeatCapacity / fIsochoricSpecificHeatCapacity;

end

