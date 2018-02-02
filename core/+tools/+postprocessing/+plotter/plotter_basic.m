classdef plotter_basic < base
    %PLOTTER_BASIC Default plotter class for V-HAB simulations
    %   The object instantiated from this class contains a cell of objects
    %   that are used to create user-defined figures using data from the
    %   simulation logger. 
    %   The class provides the following three main methods: definePlot(),
    %   defineFigure() and plot(). There are some additional helper methods
    %   to make the code more readable and efficient. 
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Name of the logger object from which this plotter will take its
        % data.
        sLogger = 'oLogger';
        
        % A cell of objects representing the individual figures to be
        % created by this plotter.
        coFigures = cell.empty(1,0);
        
        oSimulationInfrastructure;
    end
    
    methods
        function this = plotter_basic(oSimulationInfrastructure, sLogger)
            % Constructor method for this class.
            
            this.oSimulationInfrastructure = oSimulationInfrastructure;
            
            % If the name of the logger object is provided here, we write
            % it to the object's properties, otherwise it will have to be
            % added later. 
            if nargin >= 2 && ~isempty(sLogger)
                this.sLogger = sLogger;
            end
        end
        
        function oPlot = definePlot(this, cxPlotValues, sTitle, tPlotOptions)
            % This method returns an object containing all information
            % necessary to generate a single plot, which corresponds to an
            % axes object in MATLAB. 
            %
            % definePlot() requires the following input arguments:
            % - cxPlotValues    This is a cell array containing all items
            %                   that are to be plotted. The items can be
            %                   referenced by name, label or index.
            %                   Reference types can be mixed. 
            % - sTitle          The title of the plot as string. This is
            %                   mandatory since the title is used to
            %                   identify the plot being created in all user
            %                   dialogs. 
            %
            % definePlot() accepts the following optional arguments:
            % - tPlotOptions    This is a struct with which the user can
            %                   modify most aspects of the plot. For a full
            %                   description of the possible fields that can
            %                   be contained in tPlotOptions, please refer
            %                   to the plot.m class file. 
            
            % Before we do anything, we check if the input values have been
            % passed on correctly. One thing that is easily forgotten are
            % the curly brackets around a single string, if that is what is
            % passed in with cxPlotValues. 
            if ischar(cxPlotValues)
                this.throw('definePlot', 'Error in the definition of plot ''%s''. You have entered the plot value (%s) as a character array. It must be a cell. Enclose your string with curly brackets (''{...}'').', sTitle, cxPlotValues);
            end
            
            % Since it can be populated with default values here, we create
            % an empty tPlotOptions struct if it is not passed in.
            if nargin < 4
                tPlotOptions = struct();
            end
            
            % For easier reading we get a reference to the logger object of
            % this plotter. 
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            % Internally, the identifier for each log item is its index in
            % the logger's data struct. The user-facing API, however,
            % allows using not just the indexes, but also the strings that
            % represent the names and lables of each log item. Here we are
            % calling the find() method on the logger to translate all
            % items in cxPlotValues into indexes. 
            aiIndexes = oLogger.find(cxPlotValues);
            
            % A plot can only have two y axes, one on the left and one on
            % the right. If cxPlotValues contains values in one or two
            % units, then one is displayed on the left axis and the other
            % on the right automatically. If cxPlotValues contains values
            % in more than two units, it needs to be defined, which values
            % and units are displayed on each axis. By default, all values
            % are displayed on a dimensionless y axis on the left side. The
            % user can, however, define the csUnitOverride field in the
            % tPlotOptions struct, where each axis can be defined
            % individually. 
            
            % Getting the number of units and their strings from the logger
            % object
            [ iNumberOfUnits, csUniqueUnits ] = oLogger.getNumberOfUnits(aiIndexes);
            
            % If the number of units is larger than two and nothing else is
            % defined, we will set the csUnitOverride cell to the default
            % option ('all left) and create an entry in the tPlotOptions
            % struct for the dimensionless '[-]' label of that axis. This
            % also means that for all plotting purposes, there is only one
            % unit, so we have to set that field accordingly as well.
            % Otherwise we just save the number of units for later.
            % Note that we're also checking the sAlternativeXAxisValue
            % flield here, since that will also add another separate unit.
            if iNumberOfUnits > 2 && ~(isfield(tPlotOptions, 'csUnitOverride')) && ~(isfield(tPlotOptions, 'sAlternativeXAxisValue'))
                tPlotOptions.csUnitOverride = {'all left'};
                tPlotOptions.YLabel = '[-]';
                tPlotOptions.iNumberOfUnits = 1;
                
                % This is pretty weird, so we'll tell the user what's going
                % on. 
                this.warn('definePlot',['During the creation of plot "%s", you have chosen to plot values with three or more units. ', ...
                                        'The plot will have a dimensionless y axis for all plotted values. If you wish to change this, ', ...
                                        'please define the csUnitOverride cell as described in tools/+posprocessing/+plotter/plot.m.'], sTitle);
            else
                tPlotOptions.iNumberOfUnits = iNumberOfUnits;
                tPlotOptions.csUniqueUnits  = csUniqueUnits;
            end
            
            % If the csUnitOverride field is set, we have to check if it
            % has the correct format.  
            if isfield(tPlotOptions, 'csUnitOverride') 
                % Checking if there are more than two items in it, can only
                % be one for the left y axis and one for the right.
                if length(tPlotOptions.csUnitOverride) > 2
                    this.throw('definePlot','Error in the definition of plot ''%s''. Your csUnitOverride cell contains too many values. It should only contain two cells with the units for the left and right y axes.', sTitle);
                end
                
                % Checking if the single item that can be provided is one
                % of the allowed options and is in a cell.  
                if length(tPlotOptions.csUnitOverride) == 1 
                    if ischar(tPlotOptions.csUnitOverride)
                        this.throw('definePlot', 'Error in the definition of plot ''%s''. You have entered the value of csUnitOverride (%s) as a character array. It must be a cell. Enclose your string with two curly brackets (''{{...}}'').', sTitle, tPlotOptions.csUnitOverride);
                    end
                    
                    % For now, there is only one option, but more might be
                    % added in the future. If changes are made here, they
                    % also have to be made in the plot() method.
                    if ~any(strcmp({'all left'}, tPlotOptions.csUnitOverride))
                        this.throw('definePlot','Error in the definition of plot ''%s''. Your csUnitOverride cell contains an illegal value (%s). It can only be ''all left'' or ''all right''.', sTitle, tPlotOptions.csUnitOverride);
                    end
                end
                
                % The way the plot() method is set up, there must be at
                % least one unit on the left side. So we check for that
                % here as well.
                if isempty(tPlotOptions.csUnitOverride{1})
                    this.throw('definePlot', 'Error in the definition of plot ''%s''. You must have at least one unit on the left side defined in the csUnitOverride cell.', sTitle);
                end
            end
            
            % In case the user wants to plot a log value against another
            % log value instead of time, as is the default, the 
            % sAlternativeXAxisValue field in tPlotOptions will be set. If
            % that is the case, we get its log index here as well. 
            if isfield(tPlotOptions, 'sAlternativeXAxisValue')
                tPlotOptions.iAlternativeXAxisIndex = oLogger.find({tPlotOptions.sAlternativeXAxisValue});
            end
            
            % By default, the data from all simulation ticks is displayed
            % in each figure. The user can select a different interval of
            % ticks or a time interval at which the data will be displayed
            % by setting either the iTickInterval or fTimeInterval field in
            % the tPlotOptions struct. The information given there is
            % parsed in the following.
            
            % First we get the entries in the tPlotOptions struct, if they
            % exist.
            bTick = isfield(tPlotOptions, 'iTickInterval');
            bTime = isfield(tPlotOptions, 'fTimeInterval');
            
            % Now we decide what to do.
            switch (bTick + bTime)
                case 0
                    % Both fields are not set, so we go to the default: all
                    % ticks are shown.
                    tPlotOptions.sIntervalMode = 'Tick';
                    tPlotOptions.fInterval = 1;
                case 1
                    % Depending if the tick or time field was set, we set
                    % the sIntervalMode and fInterval parameters. When
                    % we're done we remove the initial interval fields to
                    % avoid confusion.
                    if bTick
                        tPlotOptions.sIntervalMode = 'Tick';
                        tPlotOptions.fInterval = tPlotOptions.iTickInterval;
                        tPlotOptions = rmfield(tPlotOptions, 'iTickInterval');
                    end
                    
                    if bTime
                        tPlotOptions.sIntervalMode = 'Time';
                        tPlotOptions.fInterval = tPlotOptions.fTimeInterval;
                        tPlotOptions = rmfield(tPlotOptions, 'fTimeInterval');
                    end
                    
                case 2
                    % The user has set both fields, so we let him or her
                    % know that that is illegal.
                    this.throw('plot', 'In the definition of plot ''%s'' you have set both the iTickInterval and fTimeInterval parameters. You can only set one of them.', sTitle);
            end
            
            %TEMPORARY Until the functionality is implemented in the plot()
            % method we need to throw this error. 
            if isfield(tPlotOptions, 'iAlternativeXAxisIndex') && iNumberOfUnits > 2
                this.throw('definePlot', 'Error in the definition of plot ''%s''. It is currently not supported to plot two values with different units against a third value other than time.', sTitle);
            end
            
            % Now we just return the plot object, containing all of the
            % necessary information.
            oPlot = tools.postprocessing.plotter.plot(sTitle, aiIndexes, tPlotOptions);
        end
        
        function defineFigure(this, coPlots, sName, tFigureOptions)
            % This method creates an entry in the coFigures cell property
            % containing an object with all information necessary to create
            % a complete MATLAB figure. 
            %
            % defineFigure() requires the following input arguments:
            % - coPlots         This is a cell array containing plot
            %                   objects as created by the definePlot()
            %                   method of this class. The arrangement of
            %                   the plot objects within the cell
            %                   corresponds to the arrangement of the
            %                   subplots within the figure. For example, a
            %                   2x2 cell array with four plots, will then
            %                   create a 2x2 plot grid. 
            % - sName           The name of the figure as string. This is
            %                   mandatory since the name is used to uniqely
            %                   identify the figure being created. An error
            %                   is thrown if a figure with the same name
            %                   already exists.
            %
            % defineFigure() accepts the following optional arguments:
            % - tFigureOptions  This is a struct with which the user can
            %                   modify most aspects of the figure. For a
            %                   full description of the possible fields
            %                   that can be contained in tPlotOptions,
            %                   please refer to the figure.m class file.
            
            % Figures are identified by their name. So first we need to
            % check if there isn't another figure with the same name. 
            csExistingFigureNames = this.getFigureNames();
            if any(strcmp(csExistingFigureNames, sName))
                this.throw('defineFigure', 'The figure name you have selected (%s) is the name of an existing figure. Please use a different name.', sName);
            end
            
            % If the user didn't provide a struct with figure options or
            % the struct is empty, we create an empty one because it is a
            % required input parameter for the figure class. 
            if nargin < 4 || isempty(tFigureOptions)
                tFigureOptions = struct();
            end
            
            % We now have all we need, so we can add another entry to the
            % coFigures cell.
            this.coFigures{end+1} = tools.postprocessing.plotter.figure(sName, coPlots, tFigureOptions);
           
        end
        
        function removeFigure(this, sName)
            % This method removes a figure from the coFigures cell
            
            % First we need to get the names of all figures.
            csFigureNames = this.getFigureNames();
            
            % Creating a boolean array by comparing the sName input
            % argument with all figure names. The resulting array should
            % only have one true item, since we check for duplicate names
            % during the figure creation in the defineFigure() method.
            abFoundFigures = strcmp(csFigureNames, sName);
            
            % If we found a figure to remove, we delete this entry in the
            % coFigures cell. Otherwise we notify the user, that we
            % couldn't delete anything. 
            if any(abFoundFigures)
                this.coFigures(abFoundFigures) = [];
                fprintf('Removed figure: %s.\n', sName);
            else
                fprintf('Could not find a figure "%s".\n', sName);
            end
            
            
        end
        
        function csFigureNames = getFigureNames(this)
            % This is a helper method that returns a cell containing the
            % names of all figures defined by this plotter. 
            
            % First we get the number of figures in the coFigures property.
            iNumberOfFigures = length(this.coFigures);
            
            % Initializing an empty cell
            csFigureNames = cell(iNumberOfFigures, 1);
            
            % Going through all items in coFigures and extracting the name.
            for iI = 1:iNumberOfFigures
                csFigureNames{iI} = this.coFigures{iI}.sName;
            end
        end
        
        %% Default plot method
        
        function plot(this)
            % This is the main method of this class. When called it
            % produces the MATLAB figures and axes objects as defined by
            % the user using the definePlot() and defineFigure() methods. 
            
            % If the coFigures property is empty, we generate a default
            % plot with the createDefaultPlot() method. This is implemented
            % to enable new users to quickly see their simulation results
            % without having to mess around with all of the plotting tools.
            if isempty(this.coFigures)
                this.createDefaultPlot();
            end
            
            % We'll need access to all of the logged data, of course, so to
            % make the code more readable we'll create a local variable
            % with a reference to the logger object here. 
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            % Now we loop through each item in the coFigures cell and
            % create an individual figure for each of them.
            for iFigure = 1:length(this.coFigures)
                % Before we start, we need to get some info for the current
                % figure.
                
                % Getting the number of rows and columns in the figure
                [ iRows, iColumns ] = size(this.coFigures{iFigure}.coPlots);
                
                % Getting the overall number of plots in the figure. This
                % is different from multiplying the iRows and iColumns
                % variables we created above, because some items in the
                % coPlots cell may be empty. So the iNumberOfPlots
                % variables is the number of non-empty entries in coPlots. 
                iNumberOfPlots  = numel(find(~cellfun(@isempty, this.coFigures{iFigure}.coPlots)));
                
                % The user may have selected to show the time vs. ticks
                % plot in this figure. If there are multiple plots in this
                % figure, we need to check if we can add the time plot to
                % the figure without interfering with the order of plots
                % the user has defined. We do this by checking, if there is
                % an empty spot on the grid of figures. If that is the
                % case, we can just put it there. If there is no empty
                % spot, we will create an extra figure, just containing the
                % time plot. To keep track of this information, we create
                % the bTimePlot and bTimePlotExtraFigure boolean variables
                % and set them accordingly. 
                if isfield(this.coFigures{iFigure}.tFigureOptions, 'bTimePlot') && this.coFigures{iFigure}.tFigureOptions.bTimePlot == true
                    bTimePlot = true;
                    if (iRows * iColumns == iNumberOfPlots)
                        bTimePlotExtraFigure = true;
                    else
                        bTimePlotExtraFigure = false;
                        
                        % If we can add the time plot to the empty spot in
                        % the figure, we need to increase the number of
                        % plots by one so a button to undock it is created.
                        iNumberOfPlots = iNumberOfPlots + 1;
                    end
                else
                    bTimePlot = false;
                end
                
                % Now we can create the actual MATLAB figure object. 
                oFigure = figure();
                
                
                %% Undock subplots panel or save button
                
                % If the user has defined a large figure with many plots,
                % it may be necessary or desired to save one individual
                % plot as a figure or image file, instead of the entire
                % giant figure. To do this, we will provide the user with a
                % small grid of buttons in the bottom left corner of the
                % figure with which each individual plot can be undocked
                % into its own separate figure, where it can be processed
                % further.  The code in this section creates this grid of
                % buttons. 
                
                % If there is only one plot in the figure, we just create a
                % small save button in the bottom left corner.
                if iNumberOfPlots == 1
                    oButton = uicontrol(oFigure,'String','Save','FontSize',10,'Position',[ 0 0 50 30]);
                    oButton.Callback = @simulation.helper.plotter_basic.saveFigureAs;
                else
                    % There are at least two plots in this figure, so we'll
                    % create our little grid of buttons. 
                    
                    % First we create the panel that will house the
                    % buttons.
                    fPanelYSize = 0.12;
                    fPanelXSize = 0.065;
                    oPanel = uipanel('Title','Undock Subplots','FontSize',10,'Position',[ 0 0 fPanelXSize fPanelYSize]);
                    
                    % Since the user may want to save the entire figure to
                    % a file, we create a save button above the panel.
                    oButton = uicontrol(oFigure,'String','Save Figure','FontSize',10,'Units','normalized','Position',[ 0 fPanelYSize fPanelXSize 0.03]);
                    oButton.Callback = @simulation.helper.plotter_basic.saveFigureAs;
                    
                    % Doing some math so we get nicely proportioned
                    % buttons. The basic idea behind all of it is that the
                    % panel is arbitrarily divided into 16 equal units and
                    % the button sizes and the gaps between them are sized
                    % accordingly. 
                    % First we set the outer dimensions of the buttons.
                    fButtonYSize = (14 - (iRows    - 1)) / iRows    / 16;
                    fButtonXSize = (14 - (iColumns - 1)) / iColumns / 16;
                    
                    % The buttons shall be 1/16th of the panel width and
                    % heigth apart, so when calculating the spaceing
                    % between the button center coordinates we have to add
                    % that to the button size. 
                    fHorizontalSpaceing = fButtonXSize + 1/16;
                    fVerticalSpaceing   = fButtonYSize + 1/16;
                    
                    % Creating the horizontal coordinates
                    afHorizontal = ( 0:fHorizontalSpaceing:1 ) - fButtonXSize;
                    afHorizontal = afHorizontal(2:end);
                    
                    % Creating the vertical coordinates, we need to flip
                    % that array because the MATLAB coordinate system has
                    % its origin in the bottom left corner, but when
                    % arranging the buttons in the same position as the
                    % plots, the first button is in the top left corner of
                    % the panel. 
                    afVertical = ( 0:fVerticalSpaceing:1 ) - fButtonYSize;
                    afVertical = afVertical(2:end);
                    afVertical = fliplr(afVertical);
                    
                    
                    % Initializing some variables. The coButtons cell will
                    % contain references to each button object. These will
                    % be used later on to attach a plot specific callback
                    % function to each button.
                    coButtons = cell(iNumberOfPlots,1);
                    iSubPlotCounter = 1;
                    
                    % Creating the array of buttons according to the number
                    % of subplots there are and labling them with simple
                    % numbers.
                    for iI = 1:iRows
                        for iJ = 1:iColumns
                            % Since it can be the case, that some of the
                            % entries in coPlots are empty, we need to
                            % check if there are plots left to create
                            % buttons for.
                            if iSubPlotCounter <= iNumberOfPlots
                                % Creating a button with a single number as
                                % its label. 
                                oButton = uicontrol(oPanel,'String',sprintf('%i', iSubPlotCounter));
                                
                                % Positioning and sizing the button
                                % according to the coordinates we
                                % calculated above. These are in relative
                                % coordinates, so we first have to set the
                                % button units to 'normalized'. 
                                oButton.Units = 'normalized';
                                oButton.Position = [afHorizontal(iJ) afVertical(iI) fButtonXSize fButtonYSize];
                                
                                % Adding a reference to the button we just
                                % created to the coButtons cell.
                                coButtons{iSubPlotCounter} = oButton;
                                
                                % Incrementing the plot counter. 
                                iSubPlotCounter = iSubPlotCounter + 1;
                            end
                        end
                    end
                end
                
                % We may need to use the handles to the individual plots
                % later on, so we create a cell to hold them. After it is
                % filled, we write it to the UserData property of the
                % figure.
                coAxesHandles = cell(iNumberOfPlots,1);
                
                %% Creating the individual plots
                % Loop through the individual subplots. If the time plot is
                % in the same figure as the 'regular' plots, we need to
                % decrease the number of plots by one, because the time
                % plot is not contained in coPlots and that would lead to
                % an 'index exceeds matrix dimensions' error.
                for iPlot = 1:(iNumberOfPlots - sif(bTimePlot && ~bTimePlotExtraFigure, 1, 0))
                    % Creating the empty subplot
                    oPlot = subplot(iRows, iColumns, iPlot);
                    
                    % For better code readability, we create a local
                    % variable for the plot options struct.
                    tPlotOptions = this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions;
                    
                    % Before we get started filling the plot with data, we
                    % need to do some checks of the plot options to set
                    % some variables accordingly. 
                    
                    % Checking if there is more than one unit in the plot
                    % data. In this case we will create two separate y
                    % axes.
                    if tPlotOptions.iNumberOfUnits > 1
                        bTwoYAxes = true;
                    else
                        bTwoYAxes = false;
                    end
                    
                    % Checking if this is a plot with an alternate x axis
                    % instead of time
                    if isfield(tPlotOptions, 'iAlternativeXAxisIndex')
                        bAlternativeXAxis = true;
                    else
                        bAlternativeXAxis = false;
                    end
                    
                    % We now have some combination of parameters. The
                    % default and most commonly used is a plot of values
                    % over time (bAlternativeXAxis == false) that have the
                    % same unit (bTwoYAxes == false).
                    if bTwoYAxes == false && bAlternativeXAxis == false
                        % Getting the result data from the logger object
                        [ mfData, afTime, tLogProps ] = oLogger.get(this.coFigures{iFigure}.coPlots{iPlot}.aiIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                        
                        % Getting the Y label from the logger object
                        sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                        
                        % If the user selected to change the unit of time
                        % by which this plot is created, we have to adjust
                        % the afTime array. 
                        [ afTime, sTimeUnit ] = this.adjustTime(afTime, tPlotOptions);
                        
                        % Now we can actually create the plot with all of the
                        % information we have gathered so far.
                        this.generatePlot(oPlot, afTime, mfData, tLogProps, sLabelY, sTimeUnit);
                        
                        % Setting the title of the plot
                        title(oPlot, this.coFigures{iFigure}.coPlots{iPlot}.sTitle);
                        
                    elseif bTwoYAxes == true && bAlternativeXAxis == false
                        % This creates a plot of values over time
                        % (bAlternativeXAxis == false), but with two
                        % separate y axes (bTwoYAxes == true). 
                        
                        % See if there is a field 'csUnitOverride', if yes,
                        % this means there are at least three units
                        % present. 
                        if isfield(tPlotOptions, 'csUnitOverride')
                            % To make the code more readable, we create a
                            % shortcut here.
                            csUnitOverride = tPlotOptions.csUnitOverride;
                            
                            % If there are exactly two items in the
                            % csUnitOverride cell, they contain cells of
                            % strings for the units on the right and left
                            % sides. 
                            if length(csUnitOverride) == 2
                                csLeftUnits  = csUnitOverride{1};
                                csRightUnits = csUnitOverride{2};
                            elseif length(csUnitOverride) == 1
                                % If there is only one entry in the cell,
                                % one of the shortcuts shown below is
                                % shown. 
                                switch csUnitOverride{1}
                                    % For now, there is only one option,
                                    % but more might be added in the
                                    % future. If changes are made here,
                                    % they also have to be made in the
                                    % definePlot() method.
                                    case 'all left'
                                        % This shortcut forces all units to
                                        % be displayed on the left side of
                                        % the plot.
                                        csLeftUnits  = tPlotOptions.csUniqueUnits;
                                        csRightUnits = {};
                                    
                                    otherwise
                                        % Just in case something slipped by
                                        % earlier. 
                                        this.throw('plot','The value you have entered for csUnitOverride is illegal. This should have been caught in the definePlot() method, though...');
                                end
                            else
                                % The csUnitOverride should not have more
                                % than three items, but if it still does or
                                % if it is empty for some reason, we catch
                                % it here. 
                                this.throw('plot', 'Something is wrong with the csUnitOverride cell.');
                            end
                        else
                            % csUnitOverride is not set, so there are only
                            % two units. We saved those in the
                            % csUniqueUnits cell, so we can just use them
                            % from there. 
                            csLeftUnits  = tPlotOptions.csUniqueUnits{1};
                            csRightUnits = tPlotOptions.csUniqueUnits{2};
                        end
                        
                        % Now we have all of the units business figured
                        % out, we need to split up the indexes accordingly
                        % so we can get the actual data from the logger. 
                        
                        % First we get all indexes into an array.
                        aiIndexes = this.coFigures{iFigure}.coPlots{iPlot}.aiIndexes;
                        
                        % The units for each log item are stored in the
                        % tLogValues struct of the logger, so we use the
                        % logger's get() method to extract those values.
                        [ ~, ~, tLogProps ] = oLogger.get(aiIndexes);
                        
                        % Calculating the number of items
                        iNumberOfLogItems = length(tLogProps);
                        
                        % We'll need some boolean arrays later, so we
                        % initialize them here. 
                        abLeftIndexes  = false(iNumberOfLogItems, 1);
                        abRightIndexes = false(iNumberOfLogItems, 1);
                        
                        % Now we're going through each of the log items and
                        % checking which side it goes onto. We save the
                        % result to the boolean arrays. 
                        for iI = 1:iNumberOfLogItems
                            abLeftIndexes(iI)  = any(strcmp(csLeftUnits,  tLogProps(iI).sUnit));
                            abRightIndexes(iI) = any(strcmp(csRightUnits, tLogProps(iI).sUnit));
                        end
                        
                        % Now we can create index arrays for both sides. 
                        aiLeftIndexes  = aiIndexes(abLeftIndexes);
                        aiRightIndexes = aiIndexes(abRightIndexes);
                        
                        % Getting the result data for the left side from
                        % the logger object. 
                        [ mfData, afTime, tLogProps ] = oLogger.get(aiLeftIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                        
                        % If the user selected to change the unit of time
                        % by which this plot is created, we have to adjust
                        % the afTime array. 
                        [ afTime, sTimeUnit ] = this.adjustTime(afTime, tPlotOptions);
                        
                        % Getting the Y label for the right side from the
                        % logger object
                        sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                        
                        % Actually creating the plot with all of the
                        % information we have gathered so far.
                        this.generatePlot(oPlot, afTime, mfData, tLogProps, sLabelY, sTimeUnit);
                        
                        % Setting the title of the plot
                        title(oPlot, this.coFigures{iFigure}.coPlots{iPlot}.sTitle);
                        
                        % If there are any items we want to plot onto the
                        % right side, we do it now. The reason we have this
                        % if-condition here is that csUnitOverride could
                        % have been used to force all units to the left
                        % side. Please note that there MUST be at least one
                        % unit on the left. 
                        if any(abRightIndexes)
                            % Getting the result data for the right side
                            % from the logger object
                            [ mfData, afTime, tLogProps ] = oLogger.get(aiRightIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                            
                            % Getting the Y label for the right side from
                            % the logger object
                            sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                            
                            % Using a specialized version of the
                            % generatePlot() method we used for the left
                            % side, we can now create the remaining traces
                            % and the y axis on the right side. 
                            this.generateRightYAxisPlot(afTime, mfData, tLogProps, sLabelY);
                        end
                        
                    elseif bAlternativeXAxis == true
                        % The user has selected to plot one value against a
                        % value other than time. 
                        
                        % Getting the y axis data
                        [ mfYData, ~, tYLogProps ] = oLogger.get(this.coFigures{iFigure}.coPlots{iPlot}.aiIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                        
                        % Getting the Y label from the logger object
                        sLabelY = this.getLabel(oLogger.poUnitsToLabels, tYLogProps);
                        
                        % Getting the x axis data
                        [ afXData, ~, tXLogProps ] = oLogger.get(tPlotOptions.iAlternativeXAxisIndex, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                        
                        % Getting the X label from the logger object
                        sLabelX = this.getLabel(oLogger.poUnitsToLabels, tXLogProps);
                        
                        % Using a specialized version of the
                        % generatePlot() method we used for the left side,
                        % we can now create the plot.
                        this.generatePlotWithAlternativeXAxis(oPlot, afXData, mfYData, tYLogProps, sLabelY, sLabelX);
                        
                        % Setting the title of the plot
                        title(oPlot, this.coFigures{iFigure}.coPlots{iPlot}.sTitle);
                    end
                    
                    % Setting the callback to undock this subplot to the
                    % appropriate button, but only if there is more than
                    % one plot in this figure. If there is only one plot,
                    % we have already created a save button.
                    if iNumberOfPlots > 1
                        coButtons{iPlot}.Callback = {@simulation.helper.plotter_basic.undockSubPlot, oPlot, legend};
                    end
                    
                    % Setting the entry in the handles cell. 
                    coAxesHandles{iPlot} = oPlot;
                    
                    %% Process the individual plot options
                    
                    % Process the line options struct, if there is one. 
                    if isfield(this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions, 'tLineOptions')
                        % This is a little more complex because we want to
                        % have nice names and labels for all the things,
                        % but in the log structs we need names and labels
                        % that can be used as field names, i.e. without
                        % spaces and special characters. This means we have
                        % two pieces of information we need to extract
                        % first, before we can start processing: The
                        % display names, which MATLAB uses to identify a
                        % line, and the log names, which we used in the
                        % logger to identify individual plots. 
                        
                        % First we get the number of log items in this
                        % plot.
                        iNumberOfItems = length(this.coFigures{iFigure}.coPlots{iPlot}.aiIndexes);
                        
                        % Now we can initialize our two cells. 
                        csDisplayNames = cell(iNumberOfItems, 1);
                        csLogItemNames = cell(iNumberOfItems, 1);
                        
                        % Now we can extract the log item names as they are
                        % in the tLogValues and tVirtualValues structs in
                        % the logger.
                        for iI = 1:iNumberOfItems
                            % Getting the current item's index
                            iIndex = this.coFigures{iFigure}.coPlots{iPlot}.aiIndexes(iI);
                            
                            % We need to check, if this is a virtual value
                            % or a "real" one and then we can get the
                            % label, unit and name of the item. 
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
                            
                        % Now that we have all the information we need, we
                        % can go ahead and actually make the modifications
                        % to the plot. 
                        % Going through all lines in the plot.
                        for iI = 1:length(oPlot.Children)
                            % Now we through the individual log items in
                            % our csDisplayNames cell to match them to the
                            % child objects of the plot object.
                            for iJ = 1:iNumberOfItems
                                if strcmp(oPlot.Children(iI).DisplayName, csDisplayNames{iJ})
                                    % We have a match, now we check if
                                    % there are line options for that item.
                                    if isfield(tPlotOptions.tLineOptions, csLogItemNames{iJ})
                                        % There are options, so we parse
                                        % the object options from our
                                        % tLineOptions struct. 
                                        this.parseObjectOptions(oPlot.Children(iI), tPlotOptions.tLineOptions.(csLogItemNames{iJ}));
                                        
                                        % There can only be one match, so
                                        % there is no reason to continue
                                        % this loop. 
                                        break;
                                    end
                                end
                            end
                        end
                        
                        % Since the oPlot.Children array only returns the
                        % child objects of the left y axis, we need to do
                        % the same thing we just did on the right y axis,
                        % if there is one. 
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
                    
                    % Process all of our custom plot options.
                    % bLegend
                    if isfield(tPlotOptions, 'bLegend') && tPlotOptions.bLegend == false
                        oPlot.Legend.Visible = 'off';
                        
                        % Since we run the tPlotOptions struct through the
                        % parseObjectOptions() method later, we need to
                        % remove this field from the tPlotOptions struct so
                        % it is not processed twice.
                        tPlotOptions = rmfield(tPlotOptions, 'bLegend');
                    end
                    
                    % tRightYAxesOptions
                    if isfield(tPlotOptions, 'tRightYAxesOptions')
                        yyaxis('right');
                        oAxes = gca;
                        this.parseObjectOptions(oAxes, tPlotOptions.tRightYAxesOptions);
                        yyaxis('left');
                        
                        % Since we run the tPlotOptions struct through the
                        % parseObjectOptions() method later, we need to
                        % remove this field from the tPlotOptions struct so
                        % it is not processed twice.
                        tPlotOptions = rmfield(tPlotOptions, 'tRightYAxesOptions');
                    end
                    
                    % Process all of the items in tPlotOptions that
                    % actually correspond to properties of the axes object.
                    this.parseObjectOptions(oPlot, tPlotOptions);
                end
                
                %% Process the individual figure options
                
                set(oFigure, 'name', this.coFigures{iFigure}.sName);
                
                % If time plot is on, create it here. 
                if bTimePlot
                    % Before we start, we have to check if the user
                    % selected to plot with a different tick interval than
                    % 1. A different time interval doesn't make sense for
                    % this plot, so we don't check for it.
                    if strcmp(tPlotOptions.sIntervalMode, 'Tick') && tPlotOptions.fInterval > 1
                        aiTicks = 1:iTickInterval:length(oLogger.afTime);
                        afTime = oLogger.afTime(aiTicks);
                    else
                        aiTicks = 1:1:length(oLogger.afTime);
                        afTime = oLogger.afTime;
                    end
                    
                    % We need to do things a bit differently if there is an
                    % extra figure for the time plot or not. 
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
                        
                        % Since some later commandy may assume that the
                        % current figure is still the main figure with all
                        % the plots, we set the 'CurrentFigure' property of
                        % the graphics root object back to that one. 
                        set(groot, 'CurrentFigure', oFigure);
                    else
                        % Creating the subplot
                        oPlot = subplot(iRows, iColumns, iPlot+1);
                        
                        % Filling the subplot with the graph and modifying its
                        % properties.
                        hold(oPlot, 'on');
                        grid(oPlot, 'minor');
                        plot(aiTicks, afTime);
                        xlabel('Ticks');
                        ylabel('Time in s');
                        title(oPlot, 'Evolution of Simulation Time vs. Simulation Ticks');
                        legend('hide')
                        
                        % Setting the callback to undock this subplot to the
                        % appropriate button.
                        coButtons{iPlot+1}.Callback = {@simulation.helper.plotter_basic.undockSubPlot, oPlot, legend};
                        
                        % Setting the entry in the handles cell.
                        % MATLAB will give us a warning here, saying that
                        % the array is growing each iteration. While that
                        % is true, it always only grows by one. So we
                        % ignore that warning on this line. 
                        coAxesHandles{end + 1} = oPlot; %#ok<AGROW>
                        
                    end
                    
                end
                
                % Process all of the items in tFigureOptions that
                % actually correspond to properties of the figure object.
                this.parseObjectOptions(oFigure, this.coFigures{iFigure}.tFigureOptions);
                
                
                % On Macs, the default screen resolution is 72 ppi. Since 
                % MATLAB 2015b, this can no longer be changed by the user. On 
                % Windows this number is 96 ppi. The reason this is done in the 
                % first place is to make the fonts larger for better screen 
                % viewing. So now we have to do the workaround of setting the 
                % figure's font size higher. Default is 8 (or 10?), we want it
                % to be at 12.
                if ismac
                    aoAxes  = findall(oFigure, 'Type', 'axes');
                    for iI = 1:length(aoAxes)
                        set(aoAxes(iI),'FontSize',12);
                    end
                end
                
                % In order for the change in font size to take effect, we
                % need to call the drawnow method. 
                drawnow();

                % If the user selected to turn on the plot tools, we turn
                % them on now. They are off by default. Turing on the plot
                % tools will automatically maximize the figure. If plot
                % tools are not turned on, we have to maximize it manually.
                if isfield(this.coFigures{iFigure}.tFigureOptions, 'bPlotTools') && this.coFigures{iFigure}.tFigureOptions.bPlotTools == true
                    plottools(oFigure, 'on');
                else
                    % Maximize figure
                    set(oFigure, 'units','normalized','OuterPosition', [0 0 1 1]);
                end
                
                % Finally we write the coHandles cell to the UserData
                % struct of the figure in case we need to use them later. 
                oFigure.UserData = struct('coAxesHandles', { coAxesHandles });
                
            end
        end
        
        function [ afTime, sTimeUnit ] = adjustTime(this, afTime, tPlotOptions)
            % The user may have set the unit of time to something else than
            % seconds. If so we have to make some adjustments here. We then
            % return the modified afTime array and a string that can be
            % used in the x axis label. 
            if isfield(tPlotOptions, 'sTimeUnit')
                switch tPlotOptions.sTimeUnit
                    case 'seconds'
                        sTimeUnit = 's';
                    case 'minutes'
                        sTimeUnit = 'min';
                        afTime = afTime ./ 60;
                    case 'hours'
                        sTimeUnit = 'h';
                        afTime = afTime ./ 3600;
                    case 'days'
                        sTimeUnit = 'days';
                        afTime = afTime ./ 86400;
                    case 'weeks'
                        sTimeUnit = 'weeks';
                        afTime = afTime ./ 604800;
                    case 'years'
                        sTimeUnit = 'years';
                        afTime = afTime ./ 31536000; % Value calculated using 365 days.
                    otherwise
                        this.throw('plot', 'The unit of time you have selected is illegal. This string can only be: seconds, minutes, hours, days, weeks or years.');
                end
            else
                sTimeUnit = 's';
            end
        end
        
        function createDefaultPlot(this)
            % If the user did not create any figures, this method is called
            % and is used to create a default plot with some general
            % values grouped by unit. 
            
            % For easier reading we get a reference to the logger object of
            % this plotter. 
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            % Defining the units of the items we want to plot and the
            % according plot titles. 
            csUnits  = {'kg', 'kg/s', 'Pa', 'K'};
            csTitles = {'Masses', 'Flow Rates', 'Pressures', 'Temperatures'};
            
            % Initializing the plots cell and the plot options struct.
            coPlots = cell(3,2);
            tPlotOptions = struct();
            
            % We will be only using one unit in each plot
            tPlotOptions.iNumberOfUnits = 1;
            
            % Now we're going through all units and creating a plot for
            % each one of them.
            for iI = 1:length(csUnits)
                % Using the logger's find() method we get the indexes for
                % all values with the same unit.
                tFilter = struct('sUnit', csUnits{iI});
                aiIndexes = oLogger.find([], tFilter);
                
                % Now we can create the plot object and write it to the
                % coPlots cell.
                tPlotOptions.csUniqueUnits  = csUnits{iI};
                coPlots{iI} = tools.postprocessing.plotter.plot(csTitles{iI}, aiIndexes, tPlotOptions);
            end
            
            % Finally we create one figure object, turn on the time plot
            % and write it to the coFigures property of this plotter. 
            tFigureOptions = struct('bTimePlot', true);
            sName = [ this.oSimulationInfrastructure.sName ' - (' this.oSimulationInfrastructure.sCreated ')' ];
            this.coFigures{end+1} = tools.postprocessing.plotter.figure(sName, coPlots, tFigureOptions);
        end
        
        
    end
    
    
    methods (Static)
        function sLabel = getLabel(poUnitsToLabels, tLogProps)
            % This method returns a string containing one or more lables
            % for the axes of a plot. The input parameters are a map of
            % units to lables that is currently located in the logger class
            % and the tLogProps struct, which is among the return variables
            % of the logger's get() method. 
            
            % Creating an empty cell for the labels we are going to use
            csLabels = cell(length(tLogProps), 1);
            
            % Going throuhg all log items 
            for iP = 1:length(tLogProps)
                % If there is a key for the current item's unit in the map
                % linking units to lables and it is not empty, then we
                % create a new entry in the labels cell that looks nice and
                % has the format <Label> [<Unit>]
                if poUnitsToLabels.isKey(tLogProps(iP).sUnit) && ~isempty(poUnitsToLabels(tLogProps(iP).sUnit))
                    csLabels{iP} = [ poUnitsToLabels(tLogProps(iP).sUnit) ' [' tLogProps(iP).sUnit ']' ];
                elseif strcmp(tLogProps(iP).sUnit,'-')
                    % The only exeption is the "no unit" unit '-'.
                    csLabels{iP} = '[-]';
                else
                    % If there is no entry in the units to labels map we
                    % throw an error. 
                    error('Unknown unit ''%s''. Please edit the poExpressionToUnit and poUnitsToLabels properties of logger_basic.m to include it.', tLogProps(iP).sUnit);
                end
            end
            
            % Now we join all of the unique, non-empty items in the labels
            % cell using a forward slash to separate them.
            sLabel = strjoin(unique(csLabels(~cellfun(@isempty, csLabels))), ' / ');
        end
        
        function generatePlot(oPlot, afTime, mfData, tLogProps, sLabelY, sTimeUnit)
            % This method generates the actual visible plots within the
            % current MATLAB axes object. The input parameters are used to
            % define some of the axes object's appearance. 
            
            % We set hold to 'on' so all following actions are applied to
            % the current axes object.
            hold(oPlot, 'on');
            
            % Turning on the minor grid. This is a default value that can
            % be changed using the tPlotOptions struct when defining the
            % plot using the definePlot() method of this plotter.
            grid(oPlot, 'minor');
            
            % Initializing a cell for the legend entries.
            csLegend = cell(length(tLogProps),1);
            
            % Looping through the properties of each log item and
            % extracting the information for the legend entry. 
            for iP = 1:length(tLogProps)
                csLegend{iP} = [ tLogProps(iP).sLabel ' [' tLogProps(iP).sUnit ']' ];
            end
            
            % Now we create the actual plots using the provided time array
            % and data matrix.
            plot(afTime, mfData);
            
            % Activating the legend.
            legend(csLegend, 'Interpreter', 'none');
            
            % Setting the label of the y axis to the provided value. 
            ylabel(sLabelY);
            
            % Setting the label of the x axis using the provided string to
            % describe the unit of time we are using here. 
            xlabel(['Time in ',sTimeUnit]);
        
        end
        
        function generateRightYAxisPlot(afTime, mfData, tLogProps, sLabelY)
            % This method creates a separate y axis on the right side of
            % the current plot and plots the data associated to the right
            % side. 
            
            % Getting the number of items to plot.
            iNumberOfItems = length(tLogProps);
            
            % We will need to append the legend with the additional entries
            % on the right y axis, so first we get the old legend.
            csOldLegend = get(legend, 'String');
            
            % Allocating additional cell items for the new legend entries.
            csNewLegend = [ csOldLegend, cell(1,iNumberOfItems)];
            
            % Looping through the properties of each log item and
            % extracting the information for the legend entry.
            for iP = 1:iNumberOfItems
                csNewLegend{length(csOldLegend)+iP} = [ tLogProps(iP).sLabel ' [' tLogProps(iP).sUnit ']' ];
            end
            
            % We now shift the MATLAB current axis to the right side.
            yyaxis('right');
            
            % Now we create the actual plots using the provided time array
            % and data matrix.
            plot(afTime, mfData);
            
            % Setting the new legend by overwriting the old one using the
            % csNewLegend cell we created here. 
            legend(csNewLegend, 'Interpreter', 'none');
            
            % For some reason the default color of the right axis is red,
            % so we set it to black here. This is a default value that can
            % be changed using the tPlotOptions struct in the definePlot()
            % method of this plotter. 
            set(gca, 'YColor', [0 0 0]);
            
            % Setting the label of the y axis on the right side to the
            % provided value.
            ylabel(sLabelY);
            
            % Since following actions may assume that the current axis is
            % the left one, we set it back to it's default value. 
            yyaxis('left');
        
        end
        
        function generatePlotWithAlternativeXAxis(oPlot, afXData, mfYData, tLogProps, sLabelY, sLabelX)
            % This method is used to create a plot of one or more variables
            % against another variable that is not time. The input
            % arguments therefore inlcude the array of data to be used for
            % the x axis and a full label string. 
            
            % We set hold to 'on' so all following actions are applied to
            % the current axes object.
            hold(oPlot, 'on');
            
            % Turning on the minor grid. This is a default value that can
            % be changed using the tPlotOptions struct when defining the
            % plot using the definePlot() method of this plotter.
            grid(oPlot, 'minor');
            
            % Initializing a cell for the legend entries.
            csLegend = cell(length(tLogProps),1);
            
            % Looping through the properties of each log item and
            % extracting the information for the legend entry. 
            for iP = 1:length(tLogProps)
                csLegend{iP} = [ tLogProps(iP).sLabel ' [' tLogProps(iP).sUnit ']' ];
            end
            
            % Now we create the actual plots using the provided data array
            % for the x axis and the provided data matrix for the y axis.
            plot(afXData, mfYData);
            
            % Activating the legend.
            legend(csLegend, 'Interpreter', 'none');
            
            % Setting the label of the y axis to the provided value. 
            ylabel(sLabelY);
            
            % Setting the label of the x axis to the provided value. 
            xlabel(sLabelX);
        
        end
        
        function parseObjectOptions(oObject, tOptions)
            % This method is used to set the properties of MATLAB graphics
            % objects to values specified in a struct. 
            
            % First we get the names of the properties we want to set from
            % the field names of the struct. 
            csOptions = fieldnames(tOptions);
            
            % The field names should have been using the naming convention
            % of V-HAB, with lower case letters indicating the data type (s
            % for strings, f for floats and so on). The properties of
            % MATLAB objects do not follow this naming convention of
            % course, so we use a regular expression to strip the lower
            % case letters from the beginning of each string in the
            % csOptions cell.
            csObjectOptions = cellfun(@(x) x(regexp(x,'[A-Z]'):end), csOptions, 'UniformOutput', false);
            
            % Now we can loop through all entries in the cell and set the
            % properties.
            for iI = 1:length(csOptions)
                % Of course, we only try to do anything if the currently
                % selected string is the name of a property of the object
                % we are manipulating.
                if isprop(oObject,csObjectOptions{iI})
                    % Some labels and titles are not simple strings or
                    % character arrays, they are objects of the class
                    % matlab.graphics.primitive.Text. These objects have a
                    % property called string. To make it easier on the
                    % user, these cases are caught here and the property
                    % value can just be given as a string. 
                    if isa(oObject.(csObjectOptions{iI}),'matlab.graphics.primitive.Text') && ischar(tOptions.(csOptions{iI}))
                        oObject.(csObjectOptions{iI}).String = tOptions.(csOptions{iI});
                    else
                        % In every other case, when the object being
                        % manipulated is not a
                        % matlab.graphics.primitive.Text, we can just set
                        % the property directly. 
                        oObject.(csObjectOptions{iI}) = tOptions.(csOptions{iI});
                    end
                end
            end
        end
        
    end
end

