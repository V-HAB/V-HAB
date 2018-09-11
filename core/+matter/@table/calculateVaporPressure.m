function fVaporPressure = calculateVaporPressure(~, fTemperature, sSubstance)
%CALCULATEVAPORPRESSURE Calculates the vapor pressure for a given substance
%at a given temperature
% The vapor pressure over temperature is required for the calculation of
% condensation in the heat exchanger. The vapor pressure returned in case
% the substance is liquid for any pressure is 0 and if it is a gas for any
% pressure it is inf.
    
% First it is necessary to decide for which substance the vapor pressure
% should be calculated

AntoineData = matter.data.AntoineParameters.(sSubstance);

mfLimits = [AntoineData.Range(:).mfLimits];

if fTemperature < mfLimits(1)
    % For temperature below the limits the substance is liquid and the
    % vapor pressure is 0
    fVaporPressure = 0;

elseif fTemperature > mfLimits(end)
    % For temperature above the limits the substance is gaseous and the
    % vapor pressure is inf
    fVaporPressure = inf;
else
    for iRange = 1:length(AntoineData.Range)
        if (fTemperature >= AntoineData.Range(iRange).mfLimits(1)) &&...
                (fTemperature <= AntoineData.Range(iRange).mfLimits(2))
            % In between the limits the respective antoine parameters from the
            % NIST chemistry webbook for the respective substance are used
            fA = AntoineData.Range(iRange).fA;
            fB = AntoineData.Range(iRange).fB;
            fC = AntoineData.Range(iRange).fC;

            % Antoine Equation, taken from http://webbook.nist.gov
            fVaporPressure = (10^(fA -(fB/(fTemperature+fC))))*10^5;
            return
        end
    end
end
end

