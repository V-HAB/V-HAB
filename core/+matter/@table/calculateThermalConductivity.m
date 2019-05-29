function fLambda = calculateThermalConductivity(this, varargin)
%CALCULATECONDUCTIVITY Calculates the conductivity of the matter in a phase or flow
%   Calculates the conductivity of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance conductivity at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and pressure can be passed as third
%   and fourth parameters, respectively.
%
%   Examples: fLambda = calculateThermalConductivity(oFlow);
%             fLambda = calculateThermalConductivity(oPhase);
%             fLambda = calculateThermalConductivity(sType, afMass, fTemperature, afPartialPressures);
%
% calculateConductivity returns
%  fLambda - conductivity of matter in current state in W/mK

[fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, ~, ~, ~] = getNecessaryParameters(this, varargin{:});
   
% If no mass is given the dynamic viscosity will be zero, so no need to do
% the rest of the calculation.
if sum(arPartialMass) == 0
    fLambda = 0;
    return;
end

% Find the indices of all substances that are in the flow
afLambda = zeros(1, length(aiIndices));

% Go through all substances that have mass and get the conductivity of each. 
for iI = 1:length(aiIndices)
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Thermal Conductivity';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = afPP(aiIndices(iI));
    tParameters.bUseIsobaricData = true;
    
    % Now we can call the findProperty() method.
    afLambda(iI) = this.findProperty(tParameters);
end

fLambda = sum(afLambda .* arPartialMass(aiIndices));

% If none of the substances has a valid dynamic viscosity an error is thrown.
if fLambda < 0 || isnan(fLambda)
    keyboard();
    this.throw('calculateConductivity','Error in conductivity calculation!');
    
end

end

