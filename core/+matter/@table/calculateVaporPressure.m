function fVaporPressure = calculateVaporPressure(this, fTemperature, sSubstance)
%CALCULATEVAPORPRESSURE Calculates the vapor pressure for a given substance
%at a given temperature
% The vapor pressure over temperature is required for the calculation of
% condensation in the heat exchanger. The vapor pressure returned in case
% the substance is liquid for any pressure is 0 and if it is a gas for any
% pressure it is inf.
    
% Getting the Antoine parameters for the selected substance
tAntoineParameters = this.ttxMatter.(sSubstance).tAntoineParameters;

% Extracting the limits from the range
mfLimits = [tAntoineParameters.Range.mfLimits];

% Now we need to check where the current temperature lies relative to the
% range limits.
if fTemperature < mfLimits(1)
    % For temperature below the limits the substance is liquid and the
    % vapor pressure is 0
    fVaporPressure = 0;

elseif fTemperature > mfLimits(end)
    % For temperature above the limits the substance is gaseous and the
    % vapor pressure is inf
    fVaporPressure = inf;
else
    for iRange = 1:length(tAntoineParameters.Range)
        if (fTemperature >= tAntoineParameters.Range(iRange).mfLimits(1)) &&...
                (fTemperature <= tAntoineParameters.Range(iRange).mfLimits(2))
            % In between the limits the respective antoine parameters from the
            % NIST chemistry webbook for the respective substance are used
            fA = tAntoineParameters.Range(iRange).fA;
            fB = tAntoineParameters.Range(iRange).fB;
            fC = tAntoineParameters.Range(iRange).fC;

            % Antoine Equation, taken from http://webbook.nist.gov
            fVaporPressure = (10^(fA -(fB/(fTemperature+fC))))*10^5;
            return
        end
    end
end
end

