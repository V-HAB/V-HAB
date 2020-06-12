function addButtons(oFigure)
%ADDBUTTONS Summary of this function goes here
%   Detailed explanation goes here

aoAxes = findobj(oFigure,'type','axes');

iNumberOfPlots = length(aoAxes);

ciPositions = cell(iNumberOfPlots, 2);
for iAxes = 1:iNumberOfPlots
    ciPositions{iAxes,1} = aoAxes(iAxes).Position(1);
    ciPositions{iAxes,2} = aoAxes(iAxes).Position(2);
end

iColumns = numel(unique([ciPositions{:,1}]));
iRows    = numel(unique([ciPositions{:,2}]));

%% Undock subplots panel or save button

% If the user has defined a large figure with many plots, it may be
% necessary or desired to save one individual plot as a figure or image
% file, instead of the entire giant figure. To do this, we will provide
% the user with a small grid of buttons in the bottom left corner of
% the figure with which each individual plot can be undocked into its
% own separate figure, where it can be processed further.  The code in
% this section creates this grid of buttons.

% If there is only one plot in the figure, we just create a small save
% button in the bottom left corner.
if iNumberOfPlots == 1
    oSaveButton = uicontrol(oFigure,'String','Save','FontSize',10,'Position',[ 0 0 50 30]);
    oSaveButton.Callback = @tools.postprocessing.plotter.helper.saveFigureAs;
else
    % There are at least two plots in this figure, so we'll create our
    % little grid of buttons.
    
    % First we create the panel that will house the buttons.
    fPanelYSize = 0.12;
    fPanelXSize = 0.065;
    oPanel = uipanel('Title','Undock Subplots','FontSize',10,'Position',[ 0 0 fPanelXSize fPanelYSize]);
    
    % Since the user may want to save the entire figure to a file, we
    % create a save button above the panel.
    oSaveButton = uicontrol(oFigure,'String','Save Figure','FontSize',10,'Units','normalized','Position',[ 0 fPanelYSize + 0.03 fPanelXSize 0.03]);
    oSaveButton.Callback = @tools.postprocessing.plotter.helper.saveFigureAs;
    
    oButton = uicontrol(oFigure,'String','Toggle Legends','FontSize',10,'Units','normalized','Position',[ 0 fPanelYSize fPanelXSize 0.03]);
    oButton.Callback = @tools.postprocessing.plotter.helper.toggleLegends;
    
    % Doing some math so we get nicely proportioned buttons. The basic
    % idea behind all of it is that the panel is arbitrarily divided
    % into 16 equal units and the button sizes and the gaps between
    % them are sized accordingly. First we set the outer dimensions of
    % the buttons.
    fButtonYSize = (14 - (iRows    - 1)) / iRows    / 16;
    fButtonXSize = (14 - (iColumns - 1)) / iColumns / 16;
    
    % The buttons shall be 1/16th of the panel width and heigth apart,
    % so when calculating the spaceing between the button center
    % coordinates we have to add that to the button size.
    fHorizontalSpaceing = fButtonXSize + 1/16;
    fVerticalSpaceing   = fButtonYSize + 1/16;
    
    % Creating the horizontal coordinates
    afHorizontal = ( 0:fHorizontalSpaceing:1 ) - fButtonXSize;
    afHorizontal = afHorizontal(2:end);
    
    % Creating the vertical coordinates, we need to flip that array
    % because the MATLAB coordinate system has its origin in the bottom
    % left corner, but when arranging the buttons in the same position
    % as the plots, the first button is in the top left corner of the
    % panel.
    afVertical = ( 0:fVerticalSpaceing:1 ) - fButtonYSize;
    afVertical = afVertical(2:end);
    afVertical = fliplr(afVertical);
    
    
    % Initializing some variables. The coButtons cell will contain
    % references to each button object. These will be used later on to
    % attach a plot specific callback function to each button.
    coButtons = cell(iRows,iColumns);
    
    % Initializing a subplot counter
    iSubPlotCounter = 1;
    
    % Creating the array of buttons according to the number of subplots
    % there are and labling them with simple numbers.
    for iI = 1:iRows
        for iJ = 1:iColumns
            % Since it can be the case, that some of the entries in
            % coPlots are empty, we need to check if there are plots
            % left to create buttons for.
            if iSubPlotCounter <= iNumberOfPlots
                % Creating a button with a single number as its label.
                oButton = uicontrol(oPanel,'String',sprintf('%i', iSubPlotCounter));
                
                % Positioning and sizing the button according to the
                % coordinates we calculated above. These are in
                % relative coordinates, so we first have to set the
                % button units to 'normalized'.
                oButton.Units = 'normalized';
                oButton.Position = [afHorizontal(iJ) afVertical(iI) fButtonXSize fButtonYSize];
                
                oButton.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, aoAxes(iNumberOfPlots+1-iSubPlotCounter), legend};
                
                % Adding a reference to the button we just created to
                % the coButtons cell.
                coButtons{iI, iJ} = oButton;
                
                % Incrementing the plot counter.
                iSubPlotCounter = iSubPlotCounter + 1;
            end
        end
    end
end

%% Keyboard Control
% The following code exists solely to enable the user to control the
% undock subplot callback buttons via the keyboard. To make this
% functionality feel native on all platforms, Windows and Unix
% environments will use keyboard shortcuts using the 'Control' key as
% the main modifier, while macOS uses 'Command'. Similarly, Windows and
% Unix use 'alt' and macOS uses 'option'. The keyboard shortcuts are as
% follows:
%
% Command/Control + [1-0] -> Undocks plots 1 to 10
% Command/Control + alt/option [1-0] -> Undocks plots 11 to 20
% Command/Control + alt/option + shift [1-0] -> Undocks plots 21 to 30
%
% Hopefully no one will have more than thirty plots in a figure.

% Saving a handle to the save button callback to the figure properties
% so we can call it from the KeyPressFcn.
oFigure.UserData.hSaveButton = oSaveButton.Callback;

% Undocking subplots only makes sense if there are any subplots, so we
% enclose all of this in an if-condition.

if iNumberOfPlots > 1
    % First we need to save a reference to all buttons in the UserData
    % struct of the figure so we can access their callbacks later.
    oFigure.UserData.coButtons = coButtons;
    
    % Because MATLAB numbers columns and rows differently than the
    % buttons are actually displayed, we need to create the
    % miButtonIndexes matrix that links the numbers on the buttons to
    % the actual array indexes. First we get the current size of the
    % plot. Note that size actually outputs the results in the reverse
    % order, rows then columns. This is necessary so we can later
    % transpose the matrix and get the dimensions we have in the button
    % array.
    [iFakeColumns, iFakeRows] = size(oFigure.UserData.coButtons);
    
    % Creating a matrix of zeros with the appropriate dimensions.
    oFigure.UserData.miButtonIndexes = zeros([iFakeRows, iFakeColumns]);
    
    % We now fill the matrix in the order of the linear indexes.
    for iI = 1:(iRows*iColumns)
        oFigure.UserData.miButtonIndexes(iI) = iI;
    end
    
    % Last step is the transposition.
    oFigure.UserData.miButtonIndexes = oFigure.UserData.miButtonIndexes';
    
end

% Now we need to assign the key press function to this figure.
oFigure.KeyPressFcn = @KeyPressFunction;

    function KeyPressFunction(oFigure, oKeyData)
        %KEYPRESSFUNCTION Enables keyboard control of undock subplot buttons
        % We need to catch all sorts of stray inputs, so we enclose this entire
        % function in a try-catch-block. That way we can just throw errors to
        % silently abort.
        try
            % Getting the number key the user pressed.
            iKey = str2double(oKeyData.Key);
            
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
                    error('Just pressed the command or control key.');
                end
                
                % 'Command' and 'control' are the main modifiers, so this
                % if-condition catches the case where only 'shift' or 'alt' is
                % pressed.
                if ~any(strcmp(oKeyData.Modifier, sPlatformModifier))
                    error('Command or control not pressed.');
                end
                
                % We now switch the number of modifiers being pressed because
                % that drives the number range we want to address. We control
                % the range by setting iOffset, which is then added to the
                % value of the number key being pressed. Due to the differences
                % between macOS and Windows and Linux we have to make some
                % additional checks here regarding the order in which the
                % modifiers are present in the Modifier struct.
                switch iNumberOfModifiers
                    case 1
                        if strcmp(oKeyData.Modifier, sPlatformModifier)
                            iOffset = 0;
                        end
                    case 2
                        if ismac()
                            if strcmp(oKeyData.Modifier{1},'alt') && ...
                                    strcmp(oKeyData.Modifier{2},sPlatformModifier)
                                iOffset = 10;
                            end
                        else
                            if strcmp(oKeyData.Modifier{1},sPlatformModifier) && ...
                                    strcmp(oKeyData.Modifier{2},'alt')
                                iOffset = 10;
                            end
                        end
                        
                        % Catch the case where we're actually trying to save
                        % the figure and not undock anything.
                        if strcmp(oKeyData.Modifier{1},'shift') && ...
                                strcmp(oKeyData.Modifier{2},sPlatformModifier) && ...
                                strcmp(oKeyData.Key,'s')
                            oFigure.UserData.hSaveButton(NaN, NaN);
                            return;
                        end
                    case 3
                        if ismac()
                            if strcmp(oKeyData.Modifier{1},'shift') && ...
                                    strcmp(oKeyData.Modifier{2},'alt') && ...
                                    strcmp(oKeyData.Modifier{3},sPlatformModifier)
                                iOffset = 20;
                            end
                        else
                            if strcmp(oKeyData.Modifier{1},'shift') && ...
                                    strcmp(oKeyData.Modifier{2},sPlatformModifier) && ...
                                    strcmp(oKeyData.Modifier{3},'alt')
                                iOffset = 20;
                            end
                        end
                    otherwise
                        % For now, if any more modifier buttons are pressed, we
                        % abort.
                        error('Something went wrong.');
                end
                
                % If the pressed key is zero, we add ten to its value.
                if iKey == 0
                    iKey = 10;
                end
                
                % Adding the offset to the key.
                iKey = iKey + iOffset;
                
                % Getting the linear index of the plot the user wants to undock
                % using our miButtonIndexes link matrix.
                iActualIndex = oFigure.UserData.miButtonIndexes == iKey;
                
                % The Callback property of the uicontrol object is actually a
                % cell in our case, containing the callback itself, as well as
                % a reference to the plot object and its legend object. We need
                % to extract those and pass them as arguments to the actual
                % function call.
                cCallBackData = oFigure.UserData.coButtons{iActualIndex}.Callback;
                
                % Actually calling the callback. Since this is a uicontrol
                % callback, the function expects references to the parent
                % figure and the button object as the first two arguments.
                % These are not used in the undockSuplot() function, so we just
                % pass in NaNs.
                cCallBackData{1}(NaN, NaN, cCallBackData{2}, cCallBackData{3});
                
            end
        catch
            % We want this to fail silently if there are inadvertent button
            % presses, so we don't put anything in here.
        end
    end

end

