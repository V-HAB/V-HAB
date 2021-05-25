function [aiLogIndices, aiVirtualLogIndices] = findLogIndices(oLogger, csLogVariableNames)
%% findLogIndices 
% this function can be used to find the indices inside the logger for the
% provided labels. 
%
% oLogger:              Reference to the logger object which contains the
%                       log values
% csLogVariableNames:   Cell Array input containing the labels as strings.
%                       The output Indices will be in the same order as
%                       this cell array
aiLogIndices            = nan(1, length(csLogVariableNames));
aiVirtualLogIndices     = nan(1, length(csLogVariableNames));

for iLabel = 1:length(csLogVariableNames)
    sLabel = csLogVariableNames{iLabel};
    % If the user defined the labels with " we just remove them as they are
    % not saved this way in the logger
    sLabel(regexp(sLabel,'"')) = [];
    
    for iLog = 1:length(oLogger.tLogValues)
        if strcmp(oLogger.tLogValues(iLog).sLabel, sLabel)
            aiLogIndices(iLabel) = iLog;
        end
    end
    if isnan(aiLogIndices(iLabel))
        for iLog = 1:length(oLogger.tVirtualValues)
            if strcmp(oLogger.tVirtualValues(iLog).sLabel, sLabel)
                aiVirtualLogIndices(iLabel) = iLog;
            end
        end
    end
end
end

