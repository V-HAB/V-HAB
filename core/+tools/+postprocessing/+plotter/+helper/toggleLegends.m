function toggleLegends(hButton, ~)
%TOGGLELEGENDS Toggles all legends in a multi-plot figure
%   This function is to be activated as a callback from a UI button in a
%   figure with multiple plots and therefore multiple legends. MATLAB
%   doesn't offer a way to toggle all of them at the same time, so we
%   create this functionality here. 
%   It finds all the child objects of the parent figure that are of the
%   type 'Legend' and switches the state. 

% Getting the handle of the parent figure
hFigure = hButton.Parent;

% Finding all the legend objects
aoLegends = findobj(hFigure, 'Type', 'Legend');

% The toggle is string based, so now we get the current status as a string.
csCurrentStatus = {aoLegends.Visible};

% Getting the new status using cellfun and the toggleStatus() function
% defined below.
csNewStatus = cellfun(@(cCell) toggleStatus(cCell), csCurrentStatus, 'UniformOutput', false);

% Now we can loop through all legend objects and set their new state.
for iLegend = 1:length(aoLegends)
    aoLegends(iLegend).Visible = csNewStatus{iLegend};
end

end

function sNew = toggleStatus(sOld)
    if strcmp(sOld, 'on')
        sNew = 'off';
    else
        sNew = 'on';
    end
end
