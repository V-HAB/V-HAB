%% Function definition for all the nice saving stuff.
function saveFigureAs(hButton,~)
    % This function asks the user for a save name, path and file format and
    % additional information and then exports the figure using those
    % settings.
    
    % The first thing we need to do is to present the user with a "Save as"
    % dialog box where the file name, location and file type is selected.
    % MATLAB has a method for that called uiputfile, which provides the
    % basic functionality. It can be expected, that this has to be done
    % many times in a row, in the same location and with the same file
    % type, so we will want to preserve as many of these settings as
    % possible. Unfortunately, MATLAB doesn't do that automatically, so we
    % have to implement this functionality here.
    %
    % The way we will do this is by creating some global variables. That
    % way the information is only saved until MATLAB quits. 
    
    % First we'll get the folder path. If we've run this function before,
    % we've saved the previous path, so the user doesn't have to click all
    % over the place all the time.
    global sPreviousPath
    if ~ischar(sPreviousPath) || ~exist(sPreviousPath, 'dir')
        sPreviousPath = [];
    end
    
    % Next is the file type. This is a little more tricky. The pre-selected
    % file type in the uiputfile dialog cannot be directly specified, it is
    % always the first item in the cell of file types. So to pre-select a
    % file type for the user, we always have to re-arrange the cell before
    % calling uiputfile. Since uiputfile only returns the selected file
    % type as an index, we have to so some index matching to preserve the
    % information.
    
    % First we create a fixed cell with the file types that we'll use as a
    % reference.
    csFixedFileTypes = {'*.fig','MATLAB-Figure';'*.pdf','PDF';'*.png','PNG';'*.jpg','JPEG';'*.svg','SVG';'*.emf','EMF'};
    
    % Now we instantiate the global variable with the index of the
    % previously selected format in the reference. 
    global iPreviousFormat
    
    % If the variable is empty, we have not run before, so we'll just use
    % the reference list. 
    if isempty(iPreviousFormat)
        csTypeList = csFixedFileTypes;
        csTypeList(1:end,3) = num2cell(1:length(csFixedFileTypes));
    else
        % We have run before, so we can now create a new list of file types
        % where the previous one is the first item and is thus pre-selected
        % in the uiputfile dialog box.
        
        % First we create a new, empty cell. 
        csTypeList = cell(length(csFixedFileTypes),3);
        
        % We set the first item in the cell to the data of the previously
        % selected format. Note that we are adding a third column here with
        % the index to preserve the information.
        csTypeList(1,1:3) = {csFixedFileTypes{iPreviousFormat,:}, iPreviousFormat};
        
        % Now we fill the rest of the array with the remaining format
        % options. To do this, we need a counter for the cell array index
        % that starts at 2, because the first item is already set.
        iCounter = 2;
        for iI = 1:length(csFixedFileTypes)
            % Since we are looping through ALL format options here, we need
            % to check, that we don't add the pre-selected one again. 
            if iI ~= iPreviousFormat
                csTypeList(iCounter,1:3) = {csFixedFileTypes{iI,:}, iI};
                iCounter = iCounter + 1;
            end
        end
    end
    
    % Now we finally have all the information required to call the
    % uiputfile method with our pre-selected values.
    [sFileName, sFilePath, iFilterIndex] = uiputfile(csTypeList(:,1:2),'Save as',sPreviousPath);
    
    % Saving the path for next time.
    sPreviousPath = sFilePath;
    
    % Saving the file type for next time
    iPreviousFormat = csTypeList{iFilterIndex, 3};
    
    % Going through the iFilterIndex possibilities to determine the file
    % type, since we need to do things differently for all four types. If
    % the user hit 'cancel', iFilterIndex is zero, so we just return. 
    if iFilterIndex == 0
        return;
    else
        bFig = false;
        switch csTypeList{iFilterIndex, 3}
            case 1
                bFig = true;
            case 2
                sFormat = '-dpdf';
            case 3
                sFormat = '-dpng';
            case 4
                sFormat = '-djpeg';
            case 5
                sFormat = '-dsvg';
            case 6
                sFormat = '-dmeta';
            otherwise
                error('Something went wrong the FilterIndex has an illegal value.');
        end
    end
    
    % We need a handle to the figure, so we can just use the parent of the
    % button that called this function.
    hFigure = hButton.Parent;
    
    % If the user chose to save the figure as a MATLAB .fig file, we don't
    % have to do a lot, so we'll get it out of the way first.
    if bFig == true
        % If there are handles to other figures in the UserData struct of a
        % figure that is being saved as a .fig file, then MATLAB, for some
        % weird reason, will save those figures as well into one giant
        % file. We don't want that of course. So we save the handles to a
        % temporary struct and then delete the UserData struct from the
        % figure.
        tUserData = hFigure.UserData;
        hFigure.UserData = struct();
        
        % Since this figure may be opened separately at a later point in
        % time, the delete function will also no longer be required. So we
        % delete that as well. But not before saving!
        hDeleteFcn = hFigure.DeleteFcn;
        hFigure.DeleteFcn = '';
        
        % Now we can actually save the figure file.
        savefig(hFigure, [sFilePath,sFileName],'compact');
        
        % After saving, we restore the UserData struct and the delete
        % function.
        hFigure.UserData = tUserData;
        hFigure.DeleteFcn = hDeleteFcn;
        
        % We're done saving, so we can return.
        return;
    end
    
    % Using a separate function we now present the user with a dialog
    % through which additional parameters can be entered. In case the user
    % closes this window with out clicking on the "Done" button, an error
    % will be thrown due to missing output argument assignments. We catch
    % this by aborting the entire save function. 
    try
        [ fFigureWidth, fFigureHeight, sFontName, fFontSize, ...
          bTitleOn, bMainGrid, bMinorGrid, bAutoAdjustXAxis, ...
          bAutoAdjustYAxis ] = settingsDialog();
    catch
        return;
    end
    
    
    % Okay, now we have everything that we need. In order to produce nice
    % image files, we need to do some magic with the figure properties
    % here.
    
    % First, we need to set the figure itself to the size that we want our
    % image to be. For that we first change the units to centimeters, save
    % the current size of the figure and then set our desired value.
    hFigure.Units = 'centimeters';
    afOldFigurePosition = hFigure.Position;
    hFigure.Position(3:4) = [fFigureWidth fFigureHeight];
    
    % The PaperSize property determines the acutal size of the image that
    % we will later produce. It is currently set to some default value,
    % most likely A4 or US letter format. We want the image to be the same
    % size as the window we're seeing on the screen, so we simply set the
    % PaperSize equal to the actual size.
    hFigure.PaperSize = hFigure.Position(3:4);
    
    % Alright, now we have to change the fonts and font sizes. We don't
    % want to mess up the plot, so we'll save the current values so we can
    % restore them after saving.
    
    % Getting the number of graphics objects in the figure so we can loop
    % through all of them.
    iChildren = length(hFigure.Children);
    
    % Initializing an array and a struct in which we can save the font size
    % and font information.
    aiFontSizes = zeros(iChildren,1);
    csFonts = cell(iChildren,1);
    
    % We need to change a property of the axes objects before modifying
    % the font size. To do this, we need to find out, which one of the
    % children are axes objects.
    abAxesIndexes = false(iChildren, 1);
    for iI = 1:iChildren
        if strcmp(hFigure.Children(iI).Type,'axes')
            abAxesIndexes(iI) = true;
        end
    end
    
    % Calculating the number of axes objects and getting their indexes in
    % the Children array of he figure object. 
    iNumberOfAxes = sum(abAxesIndexes);
    aiAxesIndexes = find(abAxesIndexes);
    
    % Initializing some arrays and cells so we can save the current
    % information for later. This will enable us to return the figure back
    % to its original state. 
    aiLabelFontSizeMultiplier = zeros(iNumberOfAxes, 1);
    cafOldXLimits = cell(iNumberOfAxes, 1);
    cafOldYLimits = cell(iNumberOfAxes, 1);
    
    for iAxes = 1:iNumberOfAxes
        % We're saving everything to restore it later, first thing is the
        % font multiplier. We always want it to be 1. 
        aiLabelFontSizeMultiplier(iAxes) = hFigure.Children(aiAxesIndexes(iAxes)).LabelFontSizeMultiplier;
        hFigure.Children(aiAxesIndexes(iAxes)).LabelFontSizeMultiplier = 1;
    end
    
    % Now we can go through all objects in the figure, save their
    % properties and then change them.
    for iI = 1:iChildren
        % Font sizes
        aiFontSizes(iI) = hFigure.Children(iI).FontSize;
        hFigure.Children(iI).FontSize = fFontSize;
        
        % Fonts
        csFonts{iI} = hFigure.Children(iI).FontName;
        hFigure.Children(iI).FontName = sFontName;
    end
    
    % The following code only needs to be performed if there is only one
    % plot in the figure, it resizes it to fill out the figure better.
    
    if iNumberOfAxes == 1
    
        % We want to make sure, that the axes really fill out the figure so
        % now we'll change the size of the plot. Since we want to restore
        % the size later, we save it first.
        afOldAxesPosition = hFigure.Children(aiAxesIndexes(iAxes)).Position;
        
        %TODO Insert a check here if there are two y axes. If so, the
        %position values set below need to be different, so the right side
        %axis labels are not cut off.
        
        hFigure.Children(aiAxesIndexes(iAxes)).Units = 'centimeters';
        hFigure.Children(aiAxesIndexes(iAxes)).Position = [ 1.3 1 fFigureWidth-1.7 fFigureHeight-1.5];
        hFigure.Children(aiAxesIndexes(iAxes)).Units = 'normalized';
        
    end
    
    for iAxes = 1:iNumberOfAxes
        % Toggling the title off or off if the user wants to
        if ~bTitleOn && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).Title.Visible,'on')
            bOldTitleState = true;
            hFigure.Children(aiAxesIndexes(iAxes)).Title.Visible = 'off';
        elseif bTitleOn && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).Title.Visible,'off')
            bOldTitleState = false;
            hFigure.Children(aiAxesIndexes(iAxes)).bOldTitleState = 'on';
        end
    
        % Check the boolean grid variables to see if the user wants them on
        % or off for this figure. Depending on this variable and the
        % current state, we do the change. We save the state in a boolean
        % variable so we can reset after saving.
        
        % Main Grid
        if ~bMainGrid && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).YGrid,'on')
            bYMainGrid = true;
            hFigure.Children(aiAxesIndexes(iAxes)).YGrid = 'off';
        elseif bMainGrid && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).YGrid,'off')
            bYMainGrid = false;
            hFigure.Children(aiAxesIndexes(iAxes)).YGrid = 'on';
        end
        
        if ~bMainGrid && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).XGrid,'on')
            bXMainGrid = true;
            hFigure.Children(aiAxesIndexes(iAxes)).XGrid = 'off';
        elseif bMainGrid && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).XGrid,'off')
            bXMainGrid = false;
            hFigure.Children(aiAxesIndexes(iAxes)).XGrid = 'on';
        end
        
        % Minor Grid
        if bMinorGrid == 0 && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).YMinorGrid,'on')
            bYMinorGrid = true;
            hFigure.Children(aiAxesIndexes(iAxes)).YMinorGrid = 'off';
        elseif bMinorGrid && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).YMinorGrid,'off')
            bYMinorGrid = false;
            hFigure.Children(aiAxesIndexes(iAxes)).YMinorGrid = 'on';
        end
        
        if ~bMinorGrid && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).XMinorGrid,'on')
            bXMinorGrid = true;
            hFigure.Children(aiAxesIndexes(iAxes)).XMinorGrid = 'off';
        elseif bMinorGrid && strcmp(hFigure.Children(aiAxesIndexes(iAxes)).XMinorGrid,'off')
            bXMinorGrid = false;
            hFigure.Children(aiAxesIndexes(iAxes)).XMinorGrid = 'on';
        end
        
        % The user may have elected to auto-adjust the axes limits, so we
        % save the old limits and set the mode to auto.
        cafOldXLimits{iAxes} = hFigure.Children(aiAxesIndexes(iAxes)).XLim;
        cafOldYLimits{iAxes} = hFigure.Children(aiAxesIndexes(iAxes)).YLim;
        
        if bAutoAdjustXAxis
            hFigure.Children(aiAxesIndexes(iAxes)).XLimMode = 'auto';
        end
        if bAutoAdjustYAxis
            hFigure.Children(aiAxesIndexes(iAxes)).YLimMode = 'auto';
        end
        
    end
    
    % If this figure was created with the undock subplot panel, as is the
    % default in V-HAB, then we need to hide this panel, otherwise it will
    % be visible in the image. 
    % Looping throuhg all children of the figure until we find an object of
    % the right class and with the right name.
    for iI = 1:length(hFigure.Children)
        if isa(hFigure.Children(iI), 'matlab.ui.container.Panel') && ...
           strcmp(hFigure.Children(iI).Title, 'Undock Subplots')
            % Found it! Now we can turn its visibility off and save its
            % index for later. We also save a boolean variable to trigger
            % the visibility setting later. 
            hFigure.Children(iI).Visible = 'off';
            iUndockSubplotsPanelIndex = iI;
            bUndockSubplotPanelPresent = true;
            
            % There can only be one panel with this name in the figure, so
            % no need to carry on looping through the children.
            break;
        else
            bUndockSubplotPanelPresent = false;
        end
    end
    
    % With all these changes, the legend, if there is one, may have moved
    % in front of the  plots. There may also be other adjustmenst the user
    % would like to make, now that the figure is shown in the actual
    % configuration that will be saved. So we'll give the user the
    % opportunitiy to move or remove it here. The script will continue,
    % once the user clicks the OK button in the message box.
    hMessageBox = msgbox('If you wish, you can make any kind of adjustment to the figure now before saving.');
    waitfor(hMessageBox);
    
    % Now we finally have everything set just the way we like it, so we can
    % go ahead and save the file.
    switch csTypeList{iFilterIndex, 3}
        case {2,5,6}
            %TODO Suppress the "figure is too large" warning for PDFs. 
            % This is the PDF, SVG and EMF case. We chose the '-painters'
            % renderer here, because that produces a vector file. In some
            % cases, this may lead to significantly smaller file sizes.
            print('-painters','-noui',[sFilePath,sFileName],sFormat);
        case {3,4}
            % This is the case for JPEG and PNG. They use the same format.
            print('-r600','-noui',[sFilePath,sFileName],sFormat);
        otherwise
            error('Something went wrong the FilterIndex has an illegal value.');
    end
    
    % Okay, all done saving, now we can clean everything up again.
    
    % First we restore the fonts multiplier.
    for iAxes = 1:iNumberOfAxes
        hFigure.Children(aiAxesIndexes(iAxes)).LabelFontSizeMultiplier = aiLabelFontSizeMultiplier(iAxes);
    end
    
    % Now for the fonts and font sizes.
    for iI = 1:iChildren
        hFigure.Children(iI).FontSize = aiFontSizes(iI);
        hFigure.Children(iI).FontName = csFonts{iI};
    end
    
    % Restoring the old axes positions, if there is only one plot,
    % otherwise we haven't changed them in the first place. 
    if iNumberOfAxes == 1
        hFigure.Children(aiAxesIndexes(iAxes)).Position = afOldAxesPosition;
        hFigure.Children(aiAxesIndexes(iAxes)).OuterPosition = [ 0 0 1 1 ];
    end
    
    
    for iAxes = 1:iNumberOfAxes
        % Resetting the title to its original state.
        if exist('bOldTitleState','var') && bOldTitleState
            hFigure.Children(aiAxesIndexes(iAxes)).Title.Visible = 'on';
        elseif exist('bOldTitleState','var') && bOldTitleState == 0
            hFigure.Children(aiAxesIndexes(iAxes)).Title.Visible = 'off';
        end
    
        % Restoring the old axes limits
        hFigure.Children(aiAxesIndexes(iAxes)).XLim = cafOldXLimits{iAxes};
        hFigure.Children(aiAxesIndexes(iAxes)).YLim = cafOldYLimits{iAxes};
        
        
        % Restoring the old grid settings
        if exist('bYMainGrid','var') && bYMainGrid
            hFigure.Children(aiAxesIndexes(iAxes)).YGrid = 'on';
        elseif exist('bYMainGrid','var') && bYMainGrid == 0
            hFigure.Children(aiAxesIndexes(iAxes)).YGrid = 'off';
        end
        
        if exist('bXMainGrid','var') && bXMainGrid
            hFigure.Children(aiAxesIndexes(iAxes)).XGrid = 'on';
        elseif exist('bXMainGrid','var') && bXMainGrid == 0
            hFigure.Children(aiAxesIndexes(iAxes)).XGrid = 'off';
        end
        
        if exist('bYMinorGrid','var') && bYMinorGrid
            hFigure.Children(aiAxesIndexes(iAxes)).YMinorGrid = 'on';
        elseif exist('bYMinorGrid','var') && bYMinorGrid == 0
            hFigure.Children(aiAxesIndexes(iAxes)).YMinorGrid = 'off';
        end
        
        if exist('bXMinorGrid','var') && bXMinorGrid
            hFigure.Children(aiAxesIndexes(iAxes)).XMinorGrid = 'on';
        elseif exist('bXMinorGrid','var') && bXMinorGrid == 0
            hFigure.Children(aiAxesIndexes(iAxes)).XMinorGrid = 'off';
        end
    end
    
    % Restoring the figure to its original size.
    hFigure.Position = afOldFigurePosition;
    
    % Making the undock subplot panel visible again.
    if bUndockSubplotPanelPresent
        hFigure.Children(iUndockSubplotsPanelIndex).Visible = 'on';
    end
    
end


function [ fFigureWidth, fFigureHeight, sFontName, fFontSize, ...
           bTitleOn, bMainGrid, bMinorGrid, bAutoAdjustXAxis, ...
           bAutoAdjustYAxis ] = settingsDialog()
    % This function creates a user dialog box and fills it with previously
    % saved values, if they are available. Otherwise it will use default
    % values.
    
    % Setting the dimensions of the window we will use for the dialog box.
    iWindowHeight = 450;
    iWindowWidth  = 330;
    
    % Calculating the position values so the dialog box is centered on the
    % screen.
    oGraphicsRoot = groot;
    afScreenSize  = oGraphicsRoot.ScreenSize(3:4);
    iHorizontalWindowPosition = floor((afScreenSize(1)-iWindowWidth)/2);
    iVerticalWindowPosition   = floor((afScreenSize(2)-iWindowHeight)/2);
    
    % Actually creating the dialog box
    oDialog = dialog('Position',[iHorizontalWindowPosition iVerticalWindowPosition iWindowWidth iWindowHeight],'Name','Image Settings');
    
    % We are saving the values that were last used in global variables. We
    % initialize all of them here.
    global fFigureWidth_Preset  fFigureHeight_Preset sFontName_Preset ...
           fFontSize_Preset bTitleOn_Preset bMainGrid_Preset ...
           bMinorGrid_Preset bAutoAdjustXAxis_Preset bAutoAdjustYAxis_Preset
    
    % This variable defines the height of the different lines in the
    % window.
    iLineHeight = 20;   
    
    %% Figure Width
    % For weird reasons, MATLAB always calculates the vertical position
    % from the bottom. That was confusing to me, so I'm calculating this in
    % reverse and always subtracting from the previous vertical position
    % variable. Here, since it is the first line, I'm subtracting from the
    % window dimensions.
    iVerticalPosition = iWindowHeight - 50;
    
    % Creating a text label
    uicontrol('Parent',oDialog,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','right',...
              'Position',[20 iVerticalPosition 100 iLineHeight],...
              'String','Image Width');
    
    % Creating a text entry field
    oDialog.UserData.oFigureWidth = uicontrol('Parent',oDialog,...
              'Style','edit',...
              'FontSize',12,...
              'Position',[130 iVerticalPosition 50 iLineHeight]);
    
    % If there is a previous value we use it, otherwise we set the default.
    if ~isempty(fFigureWidth_Preset)
        oDialog.UserData.oFigureWidth.String = fFigureWidth_Preset;
    else
        oDialog.UserData.oFigureWidth.String = '16';
    end
    
    % Creating a text label for the unit
    uicontrol('Parent',oDialog,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','left',...
              'Position',[190 iVerticalPosition 50 iLineHeight],...
              'String','[cm]');
    
    %% Figure Height
    % Getting the new vertical position by subtracting the line height
    % twice, that way we have one line height separation between two
    % entries.
    iVerticalPosition = iVerticalPosition - iLineHeight * 2;
    
    % Creating a text label
    uicontrol('Parent',oDialog,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','right',...
              'Position',[20 iVerticalPosition 100 iLineHeight],...
              'String','Image Height');
    
    % Creating a text entry field
    oDialog.UserData.oFigureHeight = uicontrol('Parent',oDialog,...
              'Style','edit',...
              'FontSize',12,...
              'Position',[130 iVerticalPosition 50 iLineHeight]);
          
    % If there is a previous value we use it, otherwise we set the default.
    if ~isempty(fFigureHeight_Preset)
        oDialog.UserData.oFigureHeight.String = fFigureHeight_Preset;
    else
        oDialog.UserData.oFigureHeight.String = '10';
    end
    
    % Creating a text label for the unit
    uicontrol('Parent',oDialog,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','left',...
              'Position',[190 iVerticalPosition 50 iLineHeight],...
              'String','[cm]');
    
    %% Font Name
    % Getting the new vertical position by subtracting the line height
    % twice, that way we have one line height separation between two
    % entries.
    iVerticalPosition = iVerticalPosition - iLineHeight * 2;
    
    % Creating a text label
    uicontrol('Parent',oDialog,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','right',...
              'Position',[20 iVerticalPosition 100 iLineHeight],...
              'String','Font Name');
    
    % Creating a drop down menu (called popup in MATLAB) that is filled
    % with all the installed fonts on the system.
    oDialog.UserData.oFontSelector = uicontrol('Parent',oDialog,...
              'Style','popup',...
              'FontSize',12,...
              'Position',[125 iVerticalPosition 150 iLineHeight],...
              'String',listfonts);
    
    % If there is a previous value we use it, otherwise we set the default.
    if ~isempty(sFontName_Preset)
        oDialog.UserData.oFontSelector.Value = find(strcmp(listfonts, sFontName_Preset));
    else
        oDialog.UserData.oFontSelector.Value = find(strcmp(listfonts, 'Arial'));
    end
    
    %% Font Size
    % Getting the new vertical position by subtracting the line height
    % twice, that way we have one line height separation between two
    % entries.
    iVerticalPosition = iVerticalPosition - iLineHeight * 2;
    
    % Creating a text label
    uicontrol('Parent',oDialog,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','right',...
              'Position',[20 iVerticalPosition 100 iLineHeight],...
              'String','Font Size');
    
    % Creating a text entry field
    oDialog.UserData.oFontSize = uicontrol('Parent',oDialog,...
              'Style','edit',...
              'FontSize',12,...
              'Position',[130 iVerticalPosition 50 iLineHeight]);
          
    % If there is a previous value we use it, otherwise we set the default.
    if ~isempty(fFontSize_Preset)
        oDialog.UserData.oFontSize.String = fFontSize_Preset;
    else
        oDialog.UserData.oFontSize.String = '8';
    end
    
    % Creating a text label for the unit
    uicontrol('Parent',oDialog,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','left',...
              'Position',[190 iVerticalPosition 50 iLineHeight],...
              'String','[Pt]');
    
          
    %% Title On
    % Getting the new vertical position by subtracting the line height
    % twice, that way we have one line height separation between two
    % entries.
    iVerticalPosition = iVerticalPosition - iLineHeight * 2;
    
    % Creating a text label
    uicontrol('Parent',oDialog,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','right',...
              'Position',[20 iVerticalPosition 100 iLineHeight],...
              'String','Title On');
    
    % Creating a checkbox
    oDialog.UserData.oTitleOn = uicontrol('Parent',oDialog,...
              'Style','checkbox',...
              'Position',[145 iVerticalPosition 50 iLineHeight]);
          
    % If there is a previous value we use it, otherwise we set the default.
    if ~isempty(bTitleOn_Preset)
        oDialog.UserData.oTitleOn.Value = bTitleOn_Preset;
    else
        oDialog.UserData.oTitleOn.Value = false;
    end
    
    %% Grid Settings
    % Getting the new vertical position by subtracting the line height
    % four times. This is more than for the other items because we are
    % creating a uipanel here, which has to be larger.
    iVerticalPosition = iVerticalPosition - iLineHeight * 4;
    
    % Creating the panel
    oPanel = uipanel(oDialog, 'Title','Grid Settings',...
                     'Units','pixels',...
                     'Position',[40 iVerticalPosition 250 65]);
                 
    % Creating a text label
    uicontrol('Parent',oPanel,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','right',...
              'Units','pixels',...
              'Position',[0 20 75 iLineHeight],...
              'String','Main Grid');
    
    % Creating a checkbox
    oDialog.UserData.oMainGrid = uicontrol('Parent',oPanel,...
              'Style','checkbox',...
              'Units','pixels',...
              'Position',[80 20 50 iLineHeight]);
          
    % If there is a previous value we use it, otherwise we set the default.
    if ~isempty(bMainGrid_Preset)
        oDialog.UserData.oMainGrid.Value = bMainGrid_Preset;
    else
        oDialog.UserData.oMainGrid.Value = true;
    end           
    
    % Creating a text label
    uicontrol('Parent',oPanel,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','right',...
              'Units','pixels',...
              'Position',[100 20 75 iLineHeight],...
              'String','Minor Grid');
    
    % Creating a checkbox
    oDialog.UserData.oMinorGrid = uicontrol('Parent',oPanel,...
              'Style','checkbox',...
              'Units','pixels',...
              'Position',[180 20 50 iLineHeight]);
          
    % If there is a previous value we use it, otherwise we set the default.
    if ~isempty(bMinorGrid_Preset)
        oDialog.UserData.oMinorGrid.Value = bMinorGrid_Preset;
    else
        oDialog.UserData.oMinorGrid.Value = false;
    end    
    
    %% Axis Auto Adjust Settings
    % Getting the new vertical position by subtracting the line height
    % four times. This is more than for the other items because we are
    % creating a uipanel here, which has to be larger.
    iVerticalPosition = iVerticalPosition - iLineHeight * 4;
    
    % Creating the panel
    oPanel = uipanel(oDialog, 'Title','Axis Auto Adjust Settings',...
                     'Units','pixels',...
                     'Position',[40 iVerticalPosition 250 65]);
                 
    % Creating a text label
    uicontrol('Parent',oPanel,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','right',...
              'Units','pixels',...
              'Position',[0 20 75 iLineHeight],...
              'String','X Axis');
    
    % Creating a checkbox
    oDialog.UserData.oAutoAdjustXAxis = uicontrol('Parent',oPanel,...
              'Style','checkbox',...
              'Units','pixels',...
              'Position',[80 20 50 iLineHeight]);
          
    % If there is a previous value we use it, otherwise we set the default.
    if ~isempty(bAutoAdjustXAxis_Preset)
        oDialog.UserData.oAutoAdjustXAxis.Value = bAutoAdjustXAxis_Preset;
    else
        oDialog.UserData.oAutoAdjustXAxis.Value = true;
    end           
    
    % Creating a text label
    uicontrol('Parent',oPanel,...
              'Style','text',...
              'FontSize',12,...
              'HorizontalAlignment','right',...
              'Units','pixels',...
              'Position',[100 20 75 iLineHeight],...
              'String','Y Axis');
    
    % Creating a checkbox
    oDialog.UserData.oAutoAdjustYAxis = uicontrol('Parent',oPanel,...
              'Style','checkbox',...
              'Units','pixels',...
              'Position',[180 20 50 iLineHeight]);
          
    % If there is a previous value we use it, otherwise we set the default.
    if ~isempty(bAutoAdjustYAxis_Preset)
        oDialog.UserData.oAutoAdjustYAxis.Value = bAutoAdjustYAxis_Preset;
    else
        oDialog.UserData.oAutoAdjustYAxis.Value = false;
    end    
    
    %% Done Button
    % Getting the new vertical position by subtracting the line height two
    % and a half times. This is a little different that the other entries
    % due to the size of the button.
    iVerticalPosition = iVerticalPosition - iLineHeight * 2.5;
    
    % Creating the button
    uicontrol('Parent',oDialog,...
              'Position',[50 iVerticalPosition 70 30],...
              'String','Done',...
              'FontSize',12,...
              'Callback',@finish);
    
    %% Wait for d to close before running to completion
    uiwait(oDialog);
    
    function finish(oButton, ~)
        % This function is called when the "Done" button is pressed. It
        % writes all of the variables to the output parameters of the
        % dialog function and saves the current values into the global
        % variables in case the function is called again. 
        
        % To shorten the following lines of code, we create a local
        % variable for the UserData struct of the figure. 
        tUserData = oButton.Parent.UserData;
        
        fFigureWidth = str2double(tUserData.oFigureWidth.String);
        fFigureWidth_Preset = fFigureWidth;
        
        fFigureHeight = str2double(tUserData.oFigureHeight.String);
        fFigureHeight_Preset = fFigureHeight;
        
        sFontName = char(tUserData.oFontSelector.String(tUserData.oFontSelector.Value));
        sFontName_Preset = sFontName;
        
        fFontSize = str2double(tUserData.oFontSize.String);
        fFontSize_Preset = fFontSize;
        
        bTitleOn = tUserData.oTitleOn.Value;
        bTitleOn_Preset = bTitleOn;
        
        bMainGrid = tUserData.oMainGrid.Value;
        bMainGrid_Preset = bMainGrid;
        
        bMinorGrid = tUserData.oMinorGrid.Value;
        bMinorGrid_Preset = bMinorGrid;
        
        bAutoAdjustXAxis = tUserData.oAutoAdjustXAxis.Value;
        bAutoAdjustXAxis_Preset = bAutoAdjustXAxis;
        
        bAutoAdjustYAxis = tUserData.oAutoAdjustYAxis.Value;
        bAutoAdjustYAxis_Preset = bAutoAdjustYAxis;
        
        % Now we can delete the figure and return to the main function.
        delete(gcf);
    end
        
end