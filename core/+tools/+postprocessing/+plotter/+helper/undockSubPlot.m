function undockSubPlot( ~, ~, oSubPlot, oLegend )
    %UNDOCKSUBPLOT Undocks a subplot from the main figure. 
    %   When this callback for the pushbutton in the main figure is
    %   executed, it creates a new figure with just the subplot.
    %   Additionally it creates a new button that provides the
    %   functionality to save the figure with customizations from the user.
    %   This functionality is provided by the saveFigureAs function. 
    
    % Creating the new figure
    hFigure = figure();
    % Setting the title of the figure according to the subplot that was
    % passed as an argument. 
    hFigure.Name = oSubPlot.Title.String;
    
    % We will want to restore the legend's position, if there is one. But 
    % as soon as the subplot is transferred to the new figure, this value
    % will change, that's why the legend handle is an input argument.
    if ~isempty(oLegend) && isvalid(oLegend)
        % There is a legend, so we save its position, in normalized units,
        % to the UserData struct of the new figure.
        oLegend.Units = 'normalized';
        hFigure.UserData.OldLegendPosition = oLegend.Position;
    else
        % No legend, no data.
        hFigure.UserData.OldLegendPosition = [];
    end
    
    % To restore the subplot back to the original figure, we need its
    % handle, which we also store in the UserData struct.
    hFigure.UserData.hOld_Parent = oSubPlot.Parent;
    
    % The final thing we need to save is the outer position of the subplot,
    % also known as an axes object, in the original figure. Again, this is
    % saved to the UserData struct of the new figure. 
    hFigure.UserData.OldAxesPosition = oSubPlot.OuterPosition;
    
    % Now we can finally make the move of the subplot into the new figure. 
    oSubPlot.Parent = hFigure;
    
    % The position in the new figure will be the same, small one than in
    % the original figure, so we just expand the subplot to fill the entire
    % figure. 
    oSubPlot.OuterPosition = [ 0 0 1 1 ];
    
    % The actual restoring is being done in the callback of the delete
    % function, which we set here. 
    hFigure.DeleteFcn = @restoreFigure;
    
    % The main purpose of undocking an individual subplot, besides getting
    % a better look at it in full screen mode, is to save the figure to a
    % file. For this we create a small button in the bottom left corner of
    % the figure and set its callback.
    oButton = uicontrol(hFigure,'String','Save','FontSize',10,'Position',[ 0 0 50 30]);
    oButton.Callback = @tools.postprocessing.plotter.helper.saveFigureAs;
end

function restoreFigure(~, ~)
    % This function restores the subplot back to the original figure and
    % deletes the one we created for the individual viewing. 
    
    % First we get the handle of the figure. 
    hFigure  = gcbo;
    
    % Next we need to find the index of the legend, so we know which item
    % in the Children array of the figure we need to get.
    for iI = 1:length(hFigure.Children)
        if strcmp(hFigure.Children(iI).Type,'legend')
            iLegendIndex = iI;
            break;
        else
            iLegendIndex = 0;
        end
    end
    
    % If there is a legend at all, we restore it to its original position
    % by using the position data that was saved in the UserData struct.
    if iLegendIndex ~= 0
        hFigure.Children(iLegendIndex).Position = hFigure.UserData.OldLegendPosition;
    end
    
    % Next we get the handle of the axes object that is our subplot.
    oSubPlot = gca;
    
    % Just as we did with the legend, we restore it to its original
    % position by using the position data that was saved in the UserData
    % struct.
    oSubPlot.OuterPosition = hFigure.UserData.OldAxesPosition;
    
    % And finally, we move the subplot back to its old parent for a happy
    % family reunion. UNLESS, the parent has been deleted in the mean time,
    % in which case we just delete ourselves... 
    if isvalid(hFigure.UserData.hOld_Parent)
        oSubPlot.Parent = hFigure.UserData.hOld_Parent;
    end
end

