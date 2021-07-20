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
    
    % Saving a handle to the save button to the figure properties
    % so we can call it from the KeyPressFcn.
    hFigure.UserData.oSaveButton = oButton;
    
    % Now we need to assign the key press function to this figure.
    hFigure.KeyPressFcn = @KeyPressFunction;
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

function KeyPressFunction(oFigure, oKeyData)
    %KEYPRESSFUNCTION Enables keyboard control of the save button
    % By pressing control/command - shift - s the user can trigger the
    % custom save dialog.
    
    % We need to catch all sorts of stray inputs, so we enclose this entire
    % function in a try-catch-block. That way we can just throw errors to
    % silently abort. 
    try
        % We only need to do anything here if the user pressed a modifier
        % key combination. 
        if ~isempty(oKeyData.Modifier)
            
            % To account for the Mac using 'command' instead of 'control',
            % we create a string containing the platform-specific modifier.
            % Interestingly, MATLAB displays 'alt' on Macs as well, even
            % though 'option' is pressed, so we don't need to worry about
            % that. 
            if ismac()
                sPlatformModifier = 'command';
            else
                sPlatformModifier = 'control';
            end
            
            % Getting the total number of modifier keys being pressed. We
            % need this to catch some unwanted inputs.
            iNumberOfModifiers = length(oKeyData.Modifier);
            
            % This if-condition catches the case where the user hit only
            % the 'command' or 'control' key and nothing else.
            if isempty(oKeyData.Character) && strcmp(oKeyData.Key, '0') && iNumberOfModifiers == 1
                error('Plotter:WillNotDisplay','Just pressed the command or control key.');
            end
            
            % 'Command' and 'control' are the main modifiers, so this
            % if-condition catches the case where only 'shift' or 'alt' is
            % pressed.
            if ~any(strcmp(oKeyData.Modifier, sPlatformModifier))
                error('Plotter:WillNotDisplay','Command or control not pressed.');
            end
            
            % We're looking only for a two modifier press, so we don't have
            % to do anything if it's more or less than two. 
            if iNumberOfModifiers == 2
                % Making sure the modifiers are correct and the 's' button
                % is also pressed.
                if strcmp(oKeyData.Modifier{1},'shift') && ...
                   strcmp(oKeyData.Modifier{2},sPlatformModifier) && ...
                   strcmp(oKeyData.Key,'s')
                    % Executing the button callback.
                    oFigure.UserData.oSaveButton.Callback(oFigure.UserData.oSaveButton, NaN);
                end
            end
        end
    catch %#ok<CTCH>
        % We want this to fail silently if there are inadvertent button
        % presses, so we don't put anything in here.
    end
end
    

