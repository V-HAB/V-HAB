function fJouleThomson = calculateJouleThomson(this, varargin)
%CALCULATEJOULETHOMSON Calculates the Joule-Thomson coefficient of the matter in a phase or flow
%   Calculates the Joule-Thomson coefficient of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance viscosities at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and pressure can be passed as third
%   and fourth parameters, respectively.
%
%   Examples: fJouleThomson = calculateJouleThomson(oFlow);
%             fJouleThomson = calculateJouleThomson(oPhase);
%             fJouleThomson = calculateJouleThomson(sType, afMass, fTemperature, afPartialPressures);
%
% calculateDynamicViscosity returns
%  fJouleThomson - Joule-Thomson coefficient in K/Pa

[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, ~, ~] = getNecessaryParameters(this, varargin{:});

% here decesion on when other calculations should be used could be placed
% (see calculateDensity function for example)

fJouleThomson = calculateProperty(this, 'Joule Thomson', fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures);


end

