function fProperty = calculateProperty(this, sProperty, fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, bUseIsobaricData)
%CALCULATEPROPERTY Calculates requested matter property
% Internal function of the matter table used to generalize identical code
% between the different calculateXXX functions of the matter table.
% Receives the property it is supposed to calculate as String input and the
% outputs of getNecessaryParameters except for the last two which are only
% used to speed up intermediate decision making in the calculateXXX
% function

% If no mass is given the heat capacity will be zero, so no need to do the
% rest of the calculation.
if sum(arPartialMass) == 0
    fProperty = 0;
    return;
end

% Make sure there is no NaN in the mass vector.
if any(isnan(arPartialMass))
    error('Invalid entries in mass vector.');
end

% Find substances with a mass bigger than zero and count the results.
% This helps in getting only the needed data from the matter table.
iNumIndices = length(aiIndices);

% Initialize a new array filled with zeros. Then iterate through all
% indexed substances and get their specific heat capacity.
afProperty = zeros(iNumIndices, 1);

for iI = 1:iNumIndices
    % Creating the input struct for the findProperty() method
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = sProperty;
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = csPhase{round(aiPhase(aiIndices(iI)), 0)};
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = afPartialPressures(aiIndices(iI));
    tParameters.bUseIsobaricData = bUseIsobaricData;
    
    % Now we can call the findProperty() method.
    try
        afProperty(iI) = this.findProperty(tParameters);
    catch sMsg
        % Since only for mixtures the phases were actually determined, if
        % an error occured first check if a phase change is currently
        % happening and throw a corresponding error if that is the case
        iPhase = this.determinePhase(tParameters.sSubstance, fTemperature, afPartialPressures(aiIndices(iI)));

        if mod(iPhase,1) ~= 0
            afProperty(iI) = this.findClosestValidMatterEntry(tParameters);
        else
            rethrow(sMsg)
        end
    end
end

% Make sure there is no NaN in the property vector.
if any(isnan(afProperty))
    error('Invalid entries in specific heat capacity vector.')
end

%DEBUG
if ~isequal(size(afProperty), size(arPartialMass(aiIndices)'))
    error('Vectors must be of same length but one transposed.');
end

% Multiply the specific heat capacities with the mass fractions. The
% result of the matrix multiplication is the specific heat capacity of
% the mixture.
fProperty = (arPartialMass(aiIndices)./sum(arPartialMass(aiIndices))) * afProperty;

% Make sure the property value is valid.
if isnan(fProperty) && fProperty >= 0
    error('Invalid %s: %f', sProperty, fProperty);
end
end
