function plot(this)
%PLOT Default plotting method
% This is the main method of this class. When called it produces the MATLAB
% figures and axes objects as defined by the user using the definePlot()
% and defineFigure() methods.

% If the coFigures property is empty, we generate a default plot with the
% createDefaultPlot() method. This is implemented to enable new users to
% quickly see their simulation results without having to mess around with
% all of the plotting tools.
if isempty(this.coFigures)
    this.createDefaultPlot();
end

% We'll need access to all of the logged data, of course, so to make the
% code more readable we'll create a local variable with a reference to the
% logger object here.
oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);

% The logger has the option to periodically dump simulation data into mat
% files to keep the memory usage down and to provide save points during
% long simulations. Before we do anything, we need to check if this has
% been done and if the data has been re-loaded into the simulation object.
% The data has already been re-loaded if the first entry in the afTime
% array is zero. 
if oLogger.bDumpToMat && oLogger.afTime(1) ~= 0
    oLogger.readFromMat();
end

% In case we are running a simulation using the parallel pool, we need to
% create an array of empty graphics objects so we can later save the
% figures to a file. Without this there would be no way to access the
% figure objects after the plot() method has finished executing.
if this.oSimulationInfrastructure.bParallelExecution
    aoFigures = gobjects(length(this.coFigures),1);
end

% Now we loop through each item in the coFigures cell and create an
% individual figure for each of them.
for iFigure = 1:length(this.coFigures)
    % Before we start, we need to get some info for the current figure.
    
    % Getting the number of rows and columns in the figure
    [ iRows, iColumns ] = size(this.coFigures{iFigure}.coPlots);
    
    % Getting the overall number of plots in the figure. This is different
    % from multiplying the iRows and iColumns variables we created above,
    % because some items in the coPlots cell may be empty. So the
    % iNumberOfPlots variables is the number of non-empty entries in
    % coPlots.
    iNumberOfPlots = numel(find(~cellfun(@isempty, this.coFigures{iFigure}.coPlots)));
    
    % The user may have selected to show the time vs. ticks plot in this
    % figure. If there are multiple plots in this figure, we need to check
    % if we can add the time plot to the figure without interfering with
    % the order of plots the user has defined. We do this by checking, if
    % there is an empty spot on the grid of figures. If that is the case,
    % we can just put it there. If there is no empty spot, we will create
    % an extra figure, just containing the time plot. To keep track of this
    % information, we create the bTimePlot and bTimePlotExtraFigure boolean
    % variables and set them accordingly.
    if isfield(this.coFigures{iFigure}.tFigureOptions, 'bTimePlot') && this.coFigures{iFigure}.tFigureOptions.bTimePlot == true
        bTimePlot = true;
        if (iRows * iColumns == iNumberOfPlots)
            bTimePlotExtraFigure = true;
        else
            bTimePlotExtraFigure = false;
            
            % If we can add the time plot to the empty spot in the figure,
            % we need to increase the number of plots by one so a button to
            % undock it is created.
            iNumberOfPlots = iNumberOfPlots + 1;
        end
    else
        bTimePlot = false;
    end
    
    % Now we can create the actual MATLAB figure object.
    oFigure = figure();
    
    
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
                    
                    % Adding a reference to the button we just created to
                    % the coButtons cell.
                    coButtons{iI, iJ} = oButton;
                    
                    % Incrementing the plot counter.
                    iSubPlotCounter = iSubPlotCounter + 1;
                end
            end
        end
    end
    
    % We may need to use the handles to the individual plots later on, so
    % we create a cell to hold them. After it is filled, we write it to the
    % UserData property of the figure.
    coAxesHandles = cell(iNumberOfPlots,1);
    
    %% Creating the individual plots
    % Loop through the individual subplots. If the time plot is in the same
    % figure as the 'regular' plots, we need to decrease the number of
    % plots by one, because the time plot is not contained in coPlots and
    % that would lead to an 'index exceeds matrix dimensions' error.
    iPlot = 0;
    for iRow = 1:iRows
        for iColumn = 1:iColumns
            iPlot = iPlot + 1;
            if isempty(this.coFigures{iFigure}.coPlots{iRow, iColumn})
                % Loop can reach empty plots first and in this case has to
                % skip one iteration until the maximum
                continue
            end
            
            % Creating the empty subplot
            oPlot = subplot(iRows, iColumns, iPlot);
            
            % For better code readability, we create a local variable for
            % the plot options struct.
            tPlotOptions = this.coFigures{iFigure}.coPlots{iRow, iColumn}.tPlotOptions;
            
            % There are some options the user may want to set on all plots within a
            % figure. These can be put into the tFigureOptions struct into the
            % tGlobalPlotOptions struct. If it exists, we add it to this plot here.
            if isfield(this.coFigures{iFigure}.tFigureOptions, 'tGlobalPlotOptions')
                tPlotOptions = tools.mergeStructs(tPlotOptions, this.coFigures{iFigure}.tFigureOptions.tGlobalPlotOptions);
            end
            
            % Before we get started filling the plot with data, we need to
            % do some checks of the plot options to set some variables
            % accordingly.
            
            % Checking if there is more than one unit in the plot data. In
            % this case we will create two separate y axes.
            if tPlotOptions.iNumberOfUnits > 1
                bTwoYAxes = true;
            else
                bTwoYAxes = false;
            end
            
            % Checking if this is a plot with an alternate x axis instead
            % of time
            if isfield(tPlotOptions, 'iAlternativeXAxisIndex')
                bAlternativeXAxis = true;
            else
                bAlternativeXAxis = false;
            end
            
            % We now have some combination of parameters. The default and
            % most commonly used is a plot of values over time
            % (bAlternativeXAxis == false) that have the same unit
            % (bTwoYAxes == false).
            if bTwoYAxes == false && bAlternativeXAxis == false
                % Getting the result data from the logger object
                [ mfData, afTime, tLogProps ] = oLogger.get(this.coFigures{iFigure}.coPlots{iRow, iColumn}.aiIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                
                % Getting the Y label from the logger object
                if isfield(tPlotOptions, 'YLabel')
                    sLabelY = tPlotOptions.YLabel;
                else
                    sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                end
                
                % If the user selected to change the unit of time by which
                % this plot is created, we have to adjust the afTime array.
                [ afTime, sTimeUnit ] = this.adjustTime(afTime, tPlotOptions);
                
                % Now we can actually create the plot with all of the
                % information we have gathered so far.
                this.generatePlot(oPlot, afTime, mfData, tLogProps, sLabelY, sTimeUnit);
                
                % Setting the title of the plot
                title(oPlot, this.coFigures{iFigure}.coPlots{iRow, iColumn}.sTitle);
                
            elseif bTwoYAxes == true && bAlternativeXAxis == false
                % This creates a plot of values over time
                % (bAlternativeXAxis == false), but with two separate y
                % axes (bTwoYAxes == true).
                
                % See if there is a field 'csUnitOverride', if yes, this
                % means there are at least three units present.
                if isfield(tPlotOptions, 'csUnitOverride')
                    % To make the code more readable, we create a shortcut
                    % here.
                    csUnitOverride = tPlotOptions.csUnitOverride;
                    
                    % If there are exactly two items in the csUnitOverride
                    % cell, they contain cells of strings for the units on
                    % the right and left sides.
                    if length(csUnitOverride) == 2
                        csLeftUnits  = csUnitOverride{1};
                        csRightUnits = csUnitOverride{2};
                    elseif length(csUnitOverride) == 1
                        % If there is only one entry in the cell, one of
                        % the shortcuts shown below is shown.
                        switch csUnitOverride{1}
                            % For now, there is only one option, but more
                            % might be added in the future. If changes are
                            % made here, they also have to be made in the
                            % definePlot() method.
                            case 'all left'
                                % This shortcut forces all units to be
                                % displayed on the left side of the plot.
                                csLeftUnits  = tPlotOptions.csUniqueUnits;
                                csRightUnits = {};
                                
                            otherwise
                                % Just in case something slipped by
                                % earlier.
                                this.throw('plot','The value you have entered for csUnitOverride is illegal. This should have been caught in the definePlot() method, though...');
                        end
                    else
                        % The csUnitOverride should not have more than
                        % three items, but if it still does or if it is
                        % empty for some reason, we catch it here.
                        this.throw('plot', 'Something is wrong with the csUnitOverride cell.');
                    end
                else
                    % csUnitOverride is not set, so there are only two
                    % units. We saved those in the csUniqueUnits cell, so
                    % we can just use them from there.
                    csLeftUnits  = tPlotOptions.csUniqueUnits{1};
                    csRightUnits = tPlotOptions.csUniqueUnits{2};
                end
                
                % Now we have all of the units business figured out, we
                % need to split up the indexes accordingly so we can get
                % the actual data from the logger.
                
                % First we get all indexes into an array.
                aiIndexes = this.coFigures{iFigure}.coPlots{iRow, iColumn}.aiIndexes;
                
                % The units for each log item are stored in the tLogValues
                % struct of the logger, so we use the logger's get() method
                % to extract those values.
                [ ~, ~, tLogProps ] = oLogger.get(aiIndexes);
                
                % Calculating the number of items
                iNumberOfLogItems = length(tLogProps);
                
                % We'll need some boolean arrays later, so we initialize
                % them here.
                abLeftIndexes  = false(iNumberOfLogItems, 1);
                abRightIndexes = false(iNumberOfLogItems, 1);
                
                % Now we're going through each of the log items and
                % checking which side it goes onto. We save the result to
                % the boolean arrays.
                for iI = 1:iNumberOfLogItems
                    abLeftIndexes(iI)  = any(strcmp(csLeftUnits,  tLogProps(iI).sUnit));
                    abRightIndexes(iI) = any(strcmp(csRightUnits, tLogProps(iI).sUnit));
                end
                
                % Now we can create index arrays for both sides.
                aiLeftIndexes  = aiIndexes(abLeftIndexes);
                aiRightIndexes = aiIndexes(abRightIndexes);
                
                % Getting the result data for the left side from the logger
                % object.
                [ mfData, afTime, tLogProps ] = oLogger.get(aiLeftIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                
                % If the user selected to change the unit of time by which
                % this plot is created, we have to adjust the afTime array.
                [ afTime, sTimeUnit ] = this.adjustTime(afTime, tPlotOptions);
                
                % Getting the Y label for the right side from the logger
                % object
                if isfield(tPlotOptions, 'yLabel')
                    sLabelY = tPlotOptions.yLabel;
                else
                    sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                end
                
                % Actually creating the plot with all of the information we
                % have gathered so far.
                this.generatePlot(oPlot, afTime, mfData, tLogProps, sLabelY, sTimeUnit);
                
                % Setting the title of the plot
                title(oPlot, this.coFigures{iFigure}.coPlots{iRow, iColumn}.sTitle);
                
                % If there are any items we want to plot onto the right
                % side, we do it now. The reason we have this if-condition
                % here is that csUnitOverride could have been used to force
                % all units to the left side. Please note that there MUST
                % be at least one unit on the left.
                if any(abRightIndexes)
                    % Getting the result data for the right side from the
                    % logger object
                    [ mfData, afTime, tLogProps ] = oLogger.get(aiRightIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                    
                    % Getting the Y label for the right side from the
                    % logger object
                    if isfield(tPlotOptions, 'yLabel')
                        sLabelY = tPlotOptions.yLabel;
                    else
                        sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                    end
                    
                    % If the user selected to change the unit of time by which
                    % this plot is created, we have to adjust the afTime array.
                    [ afTime, ~ ] = this.adjustTime(afTime, tPlotOptions);

                    % Using a specialized version of the generatePlot()
                    % method we used for the left side, we can now create
                    % the remaining traces and the y axis on the right
                    % side.
                    this.generateRightYAxisPlot(afTime, mfData, tLogProps, sLabelY);
                end
                
            elseif bAlternativeXAxis == true
                % The user has selected to plot one value against a value
                % other than time.
                
                % Getting the y axis data
                [ mfYData, ~, tYLogProps ] = oLogger.get(this.coFigures{iFigure}.coPlots{iRow, iColumn}.aiIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                
                % Getting the Y label from the logger object
                if isfield(tPlotOptions, 'yLabel')
                    sLabelY = tPlotOptions.yLabel;
                else
                    sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                end
                
                % Getting the x axis data
                [ afXData, ~, tXLogProps ] = oLogger.get(tPlotOptions.iAlternativeXAxisIndex, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                
                % Getting the X label from the logger object
                sLabelX = this.getLabel(oLogger.poUnitsToLabels, tXLogProps);
                
                % Using a specialized version of the generatePlot() method
                % we used for the left side, we can now create the plot.
                this.generatePlotWithAlternativeXAxis(oPlot, afXData, mfYData, tYLogProps, sLabelY, sLabelX);
                
                % Setting the title of the plot
                title(oPlot, this.coFigures{iFigure}.coPlots{iRow, iColumn}.sTitle);
            end
            
            % Setting the callback to undock this subplot to the
            % appropriate button, but only if there is more than one plot
            % in this figure. If there is only one plot, we have already
            % created a save button.
            if iNumberOfPlots > 1
                coButtons{iRow, iColumn}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, legend};
            end
            
            % Setting the entry in the handles cell.
            coAxesHandles{iPlot} = oPlot;
            
            %% Process the individual plot options
            
            % Process the line options struct, if there is one.
            if isfield(this.coFigures{iFigure}.coPlots{iRow, iColumn}.tPlotOptions, 'tLineOptions')
                % This is a little more complex because we want to have
                % nice names and labels for all the things, but in the log
                % structs we need names and labels that can be used as
                % field names, i.e. without spaces and special characters.
                % This means we have two pieces of information we need to
                % extract first, before we can start processing: The
                % display names, which MATLAB uses to identify a line, and
                % the log names, which we used in the logger to identify
                % individual plots.
                
                % First we get the number of log items in this plot.
                iNumberOfItems = length(this.coFigures{iFigure}.coPlots{iRow, iColumn}.aiIndexes);
                
                % Now we can initialize our two cells.
                csDisplayNames = cell(iNumberOfItems, 1);
                csLogItemNames = cell(iNumberOfItems, 1);
                
                % Now we can extract the log item names as they are in the
                % tLogValues and tVirtualValues structs in the logger.
                for iI = 1:iNumberOfItems
                    % Getting the current item's index
                    iIndex = this.coFigures{iFigure}.coPlots{iRow, iColumn}.aiIndexes(iI);
                    
                    % We need to check, if this is a virtual value or a
                    % "real" one and then we can get the label, unit and
                    % name of the item.
                    if iIndex > 0
                        sLabel = oLogger.tLogValues(iIndex).sLabel;
                        sUnit  = oLogger.tLogValues(iIndex).sUnit;
                        
                        csLogItemNames{iI} = oLogger.tLogValues(iIndex).sName;
                    else
                        sLabel = oLogger.tVirtualValues(iIndex * (-1)).sLabel;
                        sUnit  = oLogger.tVirtualValues(iIndex * (-1)).sUnit;
                        
                        csLogItemNames{iI} = oLogger.tVirtualValues(iIndex * (-1)).sName;
                    end
                    
                    csDisplayNames{iI} = [sLabel,' [',sUnit,']'];
                end
                
                % Now that we have all the information we need, we can go
                % ahead and actually make the modifications to the plot.
                % Going through all lines in the plot.
                for iI = 1:length(oPlot.Children)
                    % Now we through the individual log items in our
                    % csDisplayNames cell to match them to the child
                    % objects of the plot object.
                    for iJ = 1:iNumberOfItems
                        if strcmp(oPlot.Children(iI).DisplayName, csDisplayNames{iJ})
                            % We have a match, now we check if there are
                            % line options for that item.
                            if isfield(tPlotOptions.tLineOptions, csLogItemNames{iJ})
                                % There are options, so we parse the object
                                % options from our tLineOptions struct.
                                this.parseObjectOptions(oPlot.Children(iI), tPlotOptions.tLineOptions.(csLogItemNames{iJ}));
                                
                                % There can only be one match, so there is
                                % no reason to continue this loop.
                                break;
                            end
                        end
                    end
                end
                
                % Since the oPlot.Children array only returns the child
                % objects of the left y axis, we need to do the same thing
                % we just did on the right y axis, if there is one.
                %QUESTION How do you make this better, how do you
                %re-use the code I already programmed above?
                if bTwoYAxes
                    yyaxis('right');
                    for iI = 1:length(oPlot.Children)
                        for iJ = 1:iNumberOfItems
                            if strcmp(oPlot.Children(iI).DisplayName, csDisplayNames{iJ})
                                if isfield(tPlotOptions.tLineOptions, csLogItemNames{iJ})
                                    this.parseObjectOptions(oPlot.Children(iI), tPlotOptions.tLineOptions.(csLogItemNames{iJ}));
                                    break;
                                end
                            end
                        end
                    end
                    yyaxis('left');
                end
            end
            
            
            % Process all of our custom plot options. bLegend
            if isfield(tPlotOptions, 'bLegend') && tPlotOptions.bLegend == false
                oPlot.Legend.Visible = 'off';
                
                % Since we run the tPlotOptions struct through the
                % parseObjectOptions() method later, we need to remove this
                % field from the tPlotOptions struct so it is not processed
                % twice.
                tPlotOptions = rmfield(tPlotOptions, 'bLegend');
            end
            
            % tRightYAxesOptions
            if isfield(tPlotOptions, 'tRightYAxesOptions')
                yyaxis('right');
                oAxes = gca;
                this.parseObjectOptions(oAxes, tPlotOptions.tRightYAxesOptions);
                yyaxis('left');
                
                % Since we run the tPlotOptions struct through the
                % parseObjectOptions() method later, we need to remove this
                % field from the tPlotOptions struct so it is not processed
                % twice.
                tPlotOptions = rmfield(tPlotOptions, 'tRightYAxesOptions');
            end
            
            % Process all of the items in tPlotOptions that actually
            % correspond to properties of the axes object.
            this.parseObjectOptions(oPlot, tPlotOptions);
        end
    end
    
    %% Process the individual figure options
    
    set(oFigure, 'name', this.coFigures{iFigure}.sName);
    
    % If time plot is on, create it here.
    if bTimePlot
        % Before we start, we have to check if the user selected to plot
        % with a different tick interval than 1. A different time interval
        % doesn't make sense for this plot, so we don't check for it.
        if strcmp(tPlotOptions.sIntervalMode, 'Tick') && tPlotOptions.fInterval > 1
            aiTicks = 1:iTickInterval:length(oLogger.afTime);
            afTime = oLogger.afTime(aiTicks);
        else
            aiTicks = 1:1:length(oLogger.afTime);
            afTime = oLogger.afTime;
        end
        
        % We need to do things a bit differently if there is an extra
        % figure for the time plot or not.
        if bTimePlotExtraFigure
            % Creating the new figure
            oTimePlotFigure = figure();
            
            % Plotting
            plot(aiTicks, afTime);
            
            % Graphics settings
            grid(gca, 'minor');
            xlabel('Ticks');
            ylabel('Time in s');
            title('Evolution of Simulation Time vs. Simulation Ticks');
            set(oTimePlotFigure, 'name', [ 'Time Plot for ' this.oSimulationInfrastructure.sName ' - (' this.oSimulationInfrastructure.sCreated ')' ]');
            
            oSaveButton = uicontrol(oTimePlotFigure,'String','Save','FontSize',10,'Position',[ 0 0 50 30]);
            oSaveButton.Callback = @tools.postprocessing.plotter.helper.saveFigureAs;
            
            % Since some later command may assume that the current figure
            % is still the main figure with all the plots, we set the
            % 'CurrentFigure' property of the graphics root object back to
            % that one.
            set(groot, 'CurrentFigure', oFigure);
        else
            % Creating the subplot
            oPlot = subplot(iRows, iColumns, iNumberOfPlots);
            
            % Filling the subplot with the graph and modifying its
            % properties.
            hold(oPlot, 'on');
            grid(oPlot, 'minor');
            plot(aiTicks, afTime);
            xlabel('Ticks');
            ylabel('Time in s');
            title(oPlot, 'Evolution of Simulation Time vs. Simulation Ticks');
            
            % Setting the callback to undock this subplot to the
            % appropriate button.
            iLastPlot = find(~cellfun(@(cCell) isempty(cCell), coButtons(iRows,:)), 1, 'last');
            coButtons{iRows, iLastPlot}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};
            
            % Setting the entry in the handles cell. 
            coAxesHandles{end} = oPlot;
            
        end
        
    end
    
    % Process all of the items in tFigureOptions that actually correspond
    % to properties of the figure object.
    this.parseObjectOptions(oFigure, this.coFigures{iFigure}.tFigureOptions);
    
    
    % On Macs, the default screen resolution is 72 ppi. Since MATLAB 2015b,
    % this can no longer be changed by the user. On Windows this number is
    % 96 ppi. The reason this is done in the first place is to make the
    % fonts larger for better screen viewing. So now we have to do the
    % workaround of setting the figure's font size higher. Default is 8 (or
    % 10?), we want it to be at 12.
    if ismac
        aoAxes  = findall(oFigure, 'Type', 'axes');
        for iI = 1:length(aoAxes)
            set(aoAxes(iI),'FontSize',12);
        end
    end
    
    % In order for the change in font size to take effect, we need to call
    % the drawnow method.
    drawnow();
    
    % Maximize the figure window to fill the whole screen.
    set(oFigure, 'WindowState', 'maximized');
    
    % If the user selected to turn on the plot tools, we turn them on now.
    % They are off by default. 
    if isfield(this.coFigures{iFigure}.tFigureOptions, 'bPlotTools') && this.coFigures{iFigure}.tFigureOptions.bPlotTools == true
        plottools(oFigure, 'on');
    end
    
    % Finally we write the coHandles cell to the UserData struct of the
    % figure in case we need to use them later.
    oFigure.UserData = struct('coAxesHandles', { coAxesHandles });
    
    % In case we are running a simulation using the parallel pool, we need
    % to save the figures to the aoFigures array. 
    if this.oSimulationInfrastructure.bParallelExecution
        aoFigures(iFigure) = oFigure;
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
    
end

% % In case we are running a simulation using the parallel pool, we need to
% % assign the aoFigures array in the base workspace so the parallel worker
% % can save them into a file. Without this there would be no way to access
% % the figure objects after the plot() method has finished executing. 
% if this.oSimulationInfrastructure.bParallelExecution
%     assignin('base','aoFigures',aoFigures);
% end

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