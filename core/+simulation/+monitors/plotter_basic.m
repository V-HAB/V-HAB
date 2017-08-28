classdef plotter_basic < simulation.monitor
    %PLOTTER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    
    properties (SetAccess = public, GetAccess = public)
        rPadding = 0.03;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Name of log monitor
        sLogger = 'oLogger';
        
        coFigures = cell.empty(1,0);
    end
    
    methods
        function this = plotter_basic(oSimulationInfrastructure, sLogger)
            
            this@simulation.monitor(oSimulationInfrastructure);
            
            if nargin >= 2 && ~isempty(sLogger)
                this.sLogger = sLogger;
            end
        end
        
        function oPlot = definePlot(this, cxPlotValues, sTitle, tPlotOptions)
            % This method returns an object containing all information
            % necessary to generate a single plot, which corresponds to an
            % axes object in MATLAB. 
            
            if ischar(cxPlotValues)
                this.throw('definePlot', 'Error in the definition of plot ''%s''. You have entered the plot value (%s) as a character array. It must be a cell. Enclose your string with curly brackets (''{...}'').', sTitle, cxPlotValues);
            end
            
            if nargin < 4
                tPlotOptions = struct();
            end
            
            % For easier reading we get a reference to the logger object of
            % this plotter. 
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            % Get indexes of each item in cxPlotValues 
            aiIndexes = oLogger.find(cxPlotValues);
            
            % A plot can only have two y axes, one on the left and one on
            % the right. If cxPlotValues contains values in one or two
            % units, then one is displayed on the left axis and the other
            % on the right automatically. If cxPlotValues contains values
            % in more than two units, it needs to be defined, which values
            % and units are displayed on each axis. The following code gets
            % the number of units and if it is larger than two, throws an
            % error prompting the user to define the csUnitOverride field
            % in the tPlotOptions struct, unless it is already defined, of
            % course. 
            
            % Getting the result data from the logger object
            [ iNumberOfUnits, csUniqueUnits ] = oLogger.getNumberOfUnits(aiIndexes);
            
            % If it turns out the number of units is larger than two and
            % the csUnitOverride field is not defined, we throw an error,
            % otherwise we just save the number of units for later. 
            if iNumberOfUnits > 2 && ~(isfield(tPlotOptions, 'csUnitOverride')) && ~(isfield(tPlotOptions, 'sAlternativeXAxisValue'))
                this.throw('definePlot',['The plot you have defined (%s) contains more than two units. \n',...
                                         'You can either reduce the number of units to two, or include \n',...
                                         'a field ''csUnitOverride'' in the tPlotOptions struct that \n',...
                                         'contains the unit(s) you wish to use.'],...
                                         sTitle);
            else
                tPlotOptions.iNumberOfUnits = iNumberOfUnits;
                tPlotOptions.csUniqueUnits  = csUniqueUnits;
            end
            
            if isfield(tPlotOptions, 'csUnitOverride') 
                if length(tPlotOptions.csUnitOverride) > 2
                    this.throw('definePlot','Error in the definition of plot ''%s''. Your csUnitOverride cell contains too many values. It should only contain two cells with the units for the left and right y axes.', sTitle);
                end
                
                if length(tPlotOptions.csUnitOverride) == 1 
                    if ischar(tPlotOptions.csUnitOverride)
                        this.throw('definePlot', 'Error in the definition of plot ''%s''. You have entered the value of csUnitOverride (%s) as a character array. It must be a cell. Enclose your string with two curly brackets (''{{...}}'').', sTitle, tPlotOptions.csUnitOverride);
                    end
                    
                    if ~any(strcmp({'all left'}, tPlotOptions.csUnitOverride))
                        this.throw('definePlot','Error in the definition of plot ''%s''. Your csUnitOverride cell contains an illegal value (%s). It can only be ''all left'' or ''all right''.', sTitle, tPlotOptions.csUnitOverride);
                    end
                end
                
                if isempty(tPlotOptions.csUnitOverride{1})
                    this.throw('definePlot', 'Error in the definition of plot ''%s''. You must have at least one unit on the left side defined in the csUnitOverride cell.', sTitle);
                end
            end
            
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
            oPlot = simulation.monitors.plot(sTitle, aiIndexes, tPlotOptions);
        end
        
        function defineFigure(this, coPlots, sName, tFigureOptions)
            % This method creates an entry in the coFigures cell property
            % containing an object with all information necessary to create
            % a complete MATLAB figure. 
            
            % Figures are identified by their name. So first we need to
            % check if there isn't another figure with the same name. 
            csExistingFigureNames = this.getFigureNames();
            if any(strcmp(csExistingFigureNames, sName))
                this.throw('defineFigure', 'The figure name you have selected (%s) is the name of an existing figure. Please use a different name.', sName);
            end
            
            if nargin < 4 || isempty(tFigureOptions)
                tFigureOptions = struct();
            end
            
            % We now have all we need, so we can add another entry to the
            % coFigures cell.
            this.coFigures{end+1} = simulation.monitors.figure(sName, coPlots, tFigureOptions);
           
        end
        
        function removeFigure(this, sName)
            csFigureNames = this.getFigureNames();
            
            abFoundFigures = strcmp(csFigureNames, sName);
            if any(abFoundFigures)
                this.coFigures(abFoundFigures) = [];
            end
            
            fprintf('Removed figure: %s.\n', sTitle);
        end
        
        function csFigureNames = getFigureNames(this)
            iNumberOfFigures = length(this.coFigures);
            csFigureNames = cell(iNumberOfFigures, 1);
            for iI = 1:iNumberOfFigures
                csFigureNames{iI} = this.coFigures{iI}.sName;
            end
        end
        
        %% Default plot method
        
        function plot(this)
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
            
            % Now we have a filled tFigures struct so we can loop through
            % figures and create them. 
            for iFigure = 1:length(this.coFigures)
                % Before we start, we need to get some info for the current
                % figure.
                
                % Getting the number of rows and columns in the figure
                [ iRows, iColumns ] = size(this.coFigures{iFigure}.coPlots);
                
                % Getting the overall number of plots in the figure
                iNumberOfPlots  = numel(find(~cellfun(@isempty, this.coFigures{iFigure}.coPlots)));
                
                % The user may have selected to show the time vs. ticks
                % plot in this figure. If there are multiple plots in this
                % figure, we need to check if we can add the time plot to
                % the figure without interfering with the order of plots
                % the user has defined. We do this by checking, if there is
                % an empty spot on the grid of figures. If that is the
                % case, we can just put it there. If there is no empty
                % spot, we will create an extra figure, just containing the
                % time plot. 
                if isfield(this.coFigures{iFigure}.tFigureOptions, 'bTimePlot') && this.coFigures{iFigure}.tFigureOptions.bTimePlot == true
                    bTimePlot = true;
                    if (iRows * iColumns == iNumberOfPlots)
                        bTimePlotExtraFigure = true;
                    else
                        bTimePlotExtraFigure = false;
                        
                        % If we can add the time plot to the empty spot in
                        % the figure, we need to increase the number of
                        % plots by one. 
                        iNumberOfPlots = iNumberOfPlots + 1;
                    end
                else
                    bTimePlot = false;
                end
                
                % The last thing we need to do before we can start is creat
                % the figure that will contain all subplots.
                oFigure = figure();
                
                
                %% Undock subplots panel or save button
                
                if iNumberOfPlots == 1
                    oButton = uicontrol(oFigure,'String','Save','FontSize',10,'Position',[ 0 0 50 30]);
                    oButton.Callback = @simulation.helper.plotter_basic.saveFigureAs;
                else
                    % Creating a panel for the buttons to undock the
                    % individual plots into separate figures for export.
                    fPanelYSize = 0.12;
                    fPanelXSize = 0.065;
                    oPanel = uipanel('Title','Undock Subplots','FontSize',10,'Position',[ 0 0 fPanelXSize fPanelYSize]);
                    
                    % Doing some math so we get nicely proportioned
                    % buttons.
                    fButtonYSize = (14 - (iRows    - 1)) / iRows    / 16;
                    fButtonXSize = (14 - (iColumns - 1)) / iColumns / 16;
                    fHorizontalSpaceing = fButtonXSize + 1/16;
                    fVerticalSpaceing   = fButtonYSize + 1/16;
                    afHorizontal = ( 0:fHorizontalSpaceing:1 ) - fButtonXSize;
                    afHorizontal = afHorizontal(2:end);
                    afVertical = ( 0:fVerticalSpaceing:1 ) - fButtonYSize;
                    afVertical = afVertical(2:end);
                    afVertical = fliplr(afVertical);
                    
                    
                    % Initializing some variables
                    coButtons = cell(iNumberOfPlots,1);
                    iSubPlotCounter = 1;
                    
                    % Creating the array of buttons according to the number
                    % of subplots there are and labling them with simple
                    % numbers.
                    for iI = 1:iRows
                        for iJ = 1:iColumns
                            if iSubPlotCounter <= iNumberOfPlots
                                oButton = uicontrol(oPanel,'String',sprintf('%i', iSubPlotCounter));
                                oButton.Units = 'normalized';
                                oButton.Position = [afHorizontal(iJ) afVertical(iI) fButtonXSize fButtonYSize];
                                coButtons{iSubPlotCounter} = oButton;
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
                % Loop through the individual subplots, exluding the time
                % plot, if it is in the same figure
                for iPlot = 1:(iNumberOfPlots - sif(bTimePlot && ~bTimePlotExtraFigure, 1, 0))
                    % Creating the empty subplot
                    oPlot = subplot(iRows, iColumns, iPlot);
                    
                    % For better code readability, we create a local
                    % variable for the plot options struct.
                    tPlotOptions = this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions;
                    
                    % See if we need two y axes
                    if tPlotOptions.iNumberOfUnits > 1
                        bTwoYAxes = true;
                    else
                        bTwoYAxes = false;
                    end
                    
                    % See if this is a plot with an alternate x axis
                    % instead of time
                    if isfield(tPlotOptions, 'iAlternativeXAxisIndex')
                        bAlternativeXAxis = true;
                    else
                        bAlternativeXAxis = false;
                    end
                    
                    % Create plots with only left y axes
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
                        % Create plots with left and right y axes
                        
                        % See if there is a field 'csUnitOverride', if yes,
                        % this means there are at least three units
                        % present. 
                        if isfield(tPlotOptions, 'csUnitOverride')
                            csUnitOverride = tPlotOptions.csUnitOverride;
                            if length(csUnitOverride) == 2
                                csLeftUnits  = csUnitOverride{1};
                                csRightUnits = csUnitOverride{2};
                            elseif length(csUnitOverride) == 1
                                switch csUnitOverride{1}
                                    case 'all left'
                                        csLeftUnits  = tPlotOptions.csUniqueUnits;
                                        csRightUnits = {};
                                    
                                    otherwise
                                        this.throw('plot','The value you have entered for csUnitOverride is illegal. Please check plotter_basic.m for all options for this setting.');
                                end
                            end
                        else
                            % There are only two units present and
                            % csUnitOverride is not set, so there are only
                            % two units. We saved those in the
                            % csUniqueUnits cell, so we can just use them
                            % from there. 
                            csLeftUnits  = tPlotOptions.csUniqueUnits{1};
                            csRightUnits = tPlotOptions.csUniqueUnits{2};
                        end
                        
                        aiIndexes = this.coFigures{iFigure}.coPlots{iPlot}.aiIndexes;
                        [ ~, ~, tLogProps ] = oLogger.get(aiIndexes);
                        iNumberOfLogItems = length(tLogProps);
                        abLeftIndexes  = false(iNumberOfLogItems, 1);
                        abRightIndexes = false(iNumberOfLogItems, 1);
                        for iI = 1:iNumberOfLogItems
                            abLeftIndexes(iI)  = any(strcmp(csLeftUnits,  tLogProps(iI).sUnit));
                            abRightIndexes(iI) = any(strcmp(csRightUnits, tLogProps(iI).sUnit));
                        end
                        
                        aiLeftIndexes  = aiIndexes(abLeftIndexes);
                        aiRightIndexes = aiIndexes(abRightIndexes);
                        
                        % Getting the result data from the logger object
                        [ mfData, afTime, tLogProps ] = oLogger.get(aiLeftIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                        
                        % If the user selected to change the unit of time
                        % by which this plot is created, we have to adjust
                        % the afTime array. 
                        [ afTime, sTimeUnit ] = this.adjustTime(afTime, tPlotOptions);
                        
                        % Getting the Y label from the logger object
                        sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                        
                        % Actually creating the plot with all of the
                        % information we have gathered so far.
                        this.generatePlot(oPlot, afTime, mfData, tLogProps, sLabelY, sTimeUnit);
                        
                        % Setting the title of the plot
                        title(oPlot, this.coFigures{iFigure}.coPlots{iPlot}.sTitle);
                        
                        if any(abRightIndexes)
                            % Getting the result data from the logger object
                            [ mfData, afTime, tLogProps ] = oLogger.get(aiRightIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                            
                            % Getting the Y label from the logger object
                            sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                            
                            % Actually creating the plot with all of the
                            % information we have gathered so far.
                            this.generateRightYAxisPlot(afTime, mfData, tLogProps, sLabelY);
                        end
                        
                    elseif bAlternativeXAxis == true
                        % Getting the y axis data
                        [ mfYData, ~, tYLogProps ] = oLogger.get(this.coFigures{iFigure}.coPlots{iPlot}.aiIndexes, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                        
                        % Getting the Y label from the logger object
                        sLabelY = this.getLabel(oLogger.poUnitsToLabels, tYLogProps);
                        
                        % Getting the x axis data
                        [ afXData, ~, tXLogProps ] = oLogger.get(tPlotOptions.iAlternativeXAxisIndex, tPlotOptions.sIntervalMode, tPlotOptions.fInterval);
                        
                        % Getting the X label from the logger object
                        sLabelX = this.getLabel(oLogger.poUnitsToLabels, tXLogProps);
                        
                        % Now we can actually create the plot with all of the
                        % information we have gathered so far.
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
                        for iI = 1:length(oPlot.Children)
                            this.parseObjectOptions(oPlot.Children(iI), tPlotOptions.tLineOptions(iI));
                        end
                    end
                    
                    % Process all of our custom plot options.
                    % bLegend
                    if isfield(tPlotOptions, 'bLegend') && tPlotOptions.bLegend == false
                        oPlot.Legend.Visible = 'off';
                    end
                    
                    % tRightYAxesOptions
                    if isfield(tPlotOptions, 'tRightYAxesOptions')
                        yyaxis('right');
                        oAxes = gca;
                        this.parseObjectOptions(oAxes, tPlotOptions.tRightYAxesOptions);
                        yyaxis('left');
                    end
                    
                    % Process all of the items in tPlotOptions that
                    % actually correspond to properties of the axes object.
                    this.parseObjectOptions(oPlot, tPlotOptions);
                end
                
                %% Process the individual figure options
                
                set(oFigure, 'name', this.coFigures{iFigure}.sName);
                
                % If time plot is on, create it here. If the time plot gets
                % an extra figure, give it the name of the current figure
                % plus some post-fix. 
                if bTimePlot
                    if strcmp(tPlotOptions.sIntervalMode, 'Tick') && tPlotOptions.fInterval > 1
                        aiTicks = 1:iTickInterval:length(oLogger.afTime);
                        afTime = oLogger.afTime(aiTicks);
                    else
                        aiTicks = 1:1:length(oLogger.afTime);
                        afTime = oLogger.afTime;
                    end
                    
                    if bTimePlotExtraFigure
                        oTimePlotFigure = figure();
                        plot(aiTicks, afTime);
                        grid(gca, 'minor');
                        xlabel('Ticks');
                        ylabel('Time in s');
                        title('Evolution of Simulation Time vs. Simulation Ticks');
                        set(oTimePlotFigure, 'name', [ 'Time Plot for ' this.oSimulationInfrastructure.sName ' - (' this.oSimulationInfrastructure.sCreated ')' ]');
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
            % seconds. If so we have to make some adjustments here.
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
            % For easier reading we get a reference to the logger object of
            % this plotter. 
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            csUnits  = {'kg', 'kg/s', 'Pa', 'K'};
            csTitles = {'Masses', 'Flow Rates', 'Pressures', 'Temperatures'};
            coPlots = cell(3,2);
            
            tPlotOptions = struct();
            tPlotOptions.iNumberOfUnits = 1;
            
            for iI = 1:length(csUnits)
                tFilter = struct('sUnit', csUnits{iI});
                aiIndexes = oLogger.find([], tFilter);
                tPlotOptions.csUniqueUnits  = csUnits{iI};
                coPlots{iI} = simulation.monitors.plot(csTitles{iI}, aiIndexes, tPlotOptions);
            end
            
            tFigureOptions = struct('bTimePlot', true);
            sName = [ this.oSimulationInfrastructure.sName ' - (' this.oSimulationInfrastructure.sCreated ')' ];
            this.coFigures{end+1} = simulation.monitors.figure(sName, coPlots, tFigureOptions);
        end
        
        
    end
    
    
    methods (Static)
        function sLabel = getLabel(poUnitsToLabels, tLogProps)
            
            csLabels = cell(length(tLogProps), 1);
            
            for iP = 1:length(tLogProps)
                if poUnitsToLabels.isKey(tLogProps(iP).sUnit) && ~isempty(poUnitsToLabels(tLogProps(iP).sUnit))
                    csLabels{iP} = [ poUnitsToLabels(tLogProps(iP).sUnit) ' [' tLogProps(iP).sUnit ']' ];
                elseif ~strcmp(tLogProps(iP).sUnit,'-')
                    error('Unknown unit ''%s''. Please edit the poExpressionToUnit and poUnitsToLabels properties of logger_basic.m to include it.', tLogProps(iP).sUnit);
                end
            end
            
            sLabel = strjoin(unique(csLabels(~cellfun(@isempty, csLabels))), ' / ');
        end
        
        
        function generatePlot(oPlot, afTime, mfData, tLogProps, sLabelY, sTimeUnit)
            hold(oPlot, 'on');
            
            grid(oPlot, 'minor');
            
            csLegend = cell(length(tLogProps),1);
            
            for iP = 1:length(tLogProps)
                csLegend{iP} = [ tLogProps(iP).sLabel ' [' tLogProps(iP).sUnit ']' ];
            end
            
            plot(afTime, mfData);
            legend(csLegend, 'Interpreter', 'none');
            
            ylabel(sLabelY);
            xlabel(['Time in ',sTimeUnit]);
        
        end
        
        function generateRightYAxisPlot(afTime, mfData, tLogProps, sLabelY)
            
            iNumberOfItems = length(tLogProps);
            
            csOldLegend = get(legend, 'String');
            
            csNewLegend = [ csOldLegend, cell(iNumberOfItems,1)];
            
            
            for iP = 1:iNumberOfItems
                csNewLegend{length(csOldLegend)+iP} = [ tLogProps(iP).sLabel ' [' tLogProps(iP).sUnit ']' ];
            end
            
            yyaxis('right');
            
            plot(afTime, mfData);
            legend(csNewLegend, 'Interpreter', 'none');
            set(gca, 'YColor', [0 0 0]);
            
            ylabel(sLabelY);
            
            yyaxis('left');
        
        end
        
        function generatePlotWithAlternativeXAxis(oPlot, afXData, mfYData, tLogProps, sLabelY, sLabelX)
            
            hold(oPlot, 'on');
            
            grid(oPlot, 'minor');
            csLegend = cell(length(tLogProps),1);
            
            for iP = 1:length(tLogProps)
                csLegend{iP} = [ tLogProps(iP).sLabel ' [' tLogProps(iP).sUnit ']' ];
            end
            
            plot(afXData, mfYData);
            legend(csLegend, 'Interpreter', 'none');
            
            ylabel(sLabelY);
            xlabel(sLabelX);
        
        end
        
        function parseObjectOptions(oObject, tOptions)
            csOptions = fieldnames(tOptions);
            csObjectOptions = cellfun(@(x) x(regexp(x,'[A-Z]'):end), csOptions, 'UniformOutput', false);
            
            for iI = 1:length(csOptions)
                if isprop(oObject,csObjectOptions{iI})
                    if isa(oObject.(csObjectOptions{iI}),'matlab.graphics.primitive.Text') && ischar(tOptions.(csOptions{iI}))
                        oObject.(csObjectOptions{iI}).String = tOptions.(csOptions{iI});
                    else
                        oObject.(csObjectOptions{iI}) = tOptions.(csOptions{iI});
                    end
                end
            end
        end
        
    end
end

