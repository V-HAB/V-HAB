function tbPostTickControl = verbosePostTicks(oTimer)
    %VERBOSEPOSTTICKS Helper to make the post tick boolean matrix human-readable
    % This function translates the 3 dimensional boolean array
    % mbPostTickControl which controls post tick execution into a more
    % verbose struct where indexing with the post tick group names and
    % levels is possible and each post tick level only contains as many
    % post ticks as are actually bound to it (which is not possible in the
    % array)
    for iGroup = 1:length(oTimer.csPostTickGroups)
        csLevel = oTimer.tcsPostTickLevel.(oTimer.csPostTickGroups{iGroup});
        for iLevel = 1:length(csLevel)
            cxPostTicks = oTimer.txPostTicks.(oTimer.csPostTickGroups{iGroup}).(csLevel{iLevel});
            if ~isempty(cxPostTicks)
                mbControl = oTimer.cabPostTickControl{iGroup, iLevel};
            else
                mbControl = logical.empty();
            end
            tbPostTickControl.(oTimer.csPostTickGroups{iGroup}).(csLevel{iLevel}) = mbControl;
        end
    end
end
