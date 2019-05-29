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

% If no mass is given the viscosity will be zero, so no need to do the rest
% of the calculation.
if sum(arPartialMass) == 0
    fEta = 0;
    return;
end

% Find the indices of all substances that are in the flow
afEta = zeros(1, length(aiIndices));

for iI = 1:length(aiIndices)
    % Generating the paramter struct that findProperty() requires.
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Dynamic Viscosity';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = afPartialPressures(aiIndices(iI));
    tParameters.bUseIsobaricData = true;
    
    % Now we can call the findProperty() method.
    afEta(iI) = this.findProperty(tParameters);
end

fEta = sum(afEta .* arPartialMass(aiIndices));

% If none of the substances has a valid dynamic viscosity an error is thrown.
if fEta < 0 || isnan(fEta)
    keyboard();
    this.throw('calculateDynamicViscosity','Error in dynamic viscosity calculation!');
    
end

end

