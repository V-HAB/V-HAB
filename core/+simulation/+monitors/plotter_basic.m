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
            
            % For easier reading we get a reference to the logger object of
            % this plotter. 
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            if ischar(cxPlotValues)
                this.throw('definePlot', 'You have entered the plot value (%s) as a character array. It must be a cell. Enclose your string with curly brackets.', cxPlotValues);
            end
            
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
            if iNumberOfUnits > 2 && nargin == 4 && ~(isfield(tPlotOptions, 'csUnitOverride'))
                this.throw('definePlot',['The plot you have defined (%s) contains more than two units. \n',...
                                         'You can either reduce the number of units to two, or include \n',...
                                         'a field ''csUnitOverride'' in the tPlotOptions struct that \n',...
                                         'contains the unit(s) you wish to use.'],...
                                         sTitle);
            else
                tPlotOptions.iNumberOfUnits = iNumberOfUnits;
                tPlotOptions.csUniqueUnits  = csUniqueUnits;
            end
            
            % Now we just return the plot object, containing all of the
            % necessary information.
            oPlot = simulation.monitors.plot(sTitle, aiIndexes, tPlotOptions);
        end
        
        function defineFigure(this, coPlots, sTitle, tFigureOptions)
            % This method creates an entry in the coFigures cell property
            % containing an object with all information necessary to create
            % a complete MATLAB figure. 
            
            % For better identification of the individual figures within
            % the struct, we want to set a title. This title can either be
            % set using the second input parameter, or as a field within
            % the tFigureOptions struct. 
            if nargin > 3
                if isfield(tFigureOptions, 'sTitle') || isempty(sTitle)
                    sTitle = tFigureOptions.sTitle;
                end
            else
                tFigureOptions = struct();
            end
            
            csExistingFigureNames = this.getFigureNames();
            if any(strcmp(csExistingFigureNames, sTitle))
                this.throw('defineFigure', 'The figure title you have selected (%s) is the title of an existing figure. Please use a different name.', sTitle);
            end
            
            % We already have all we need, so we can add another entry to
            % the coFigures cell. 
            this.coFigures{end+1} = simulation.monitors.figure(sTitle, coPlots, tFigureOptions);
           
        end
        
        function removeFigure(this, sTitle)
            csFigureNames = this.getFigureNames();
            
            abFoundFigures = strcmp(csFigureNames, sTitle);
            if any(abFoundFigures)
                this.coFigures(abFoundFigures) = [];
            end
            
            fprintf('Removed figure: %s.\n', sTitle);
        end
        
        function csFigureNames = getFigureNames(this)
            iNumberOfFigures = length(this.coFigures);
            csFigureNames = cell(iNumberOfFigures, 1);
            for iI = 1:iNumberOfFigures
                csFigureNames{iI} = this.coFigures{iI}.sTitle;
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
                
                
                %% Undock subplots panel
                % Creating a panel for the buttons to undock the individual
                % plots into separate figures for export.
                fPanelYSize = 0.12;
                fPanelXSize = 0.065;
                oPanel = uipanel('Title','Undock Subplots','FontSize',10,'Position',[ 0 0 fPanelXSize fPanelYSize]);
                
                % Doing some math so we get nicely proportioned buttons.
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
                
                % Creating the array of buttons according to the number of
                % subplots there are and labling them with simple numbers.
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
                
                % We may need to use the handles to the individual plots
                % later on, so we create a cell to hold them. After it is
                % filled, we write it to the UserData property of the
                % figure. 
                coAxesHandles = cell(iNumberOfPlots,1);
                
                %% Creating the individual plots
                % Loop through the individual subplots, exluding the time
                % plot, if it is in the same figure
                for iPlot = 1:(iNumberOfPlots - sif(bTimePlot && ~bTimePlotExtraFigure, 1, 0))
                    % Creating the subplot
                    hHandle = subplot(iRows, iColumns, iPlot);
                    
                    % See if we need two y axes
                    if this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions.iNumberOfUnits > 1
                        bTwoYAxes = true;
                    else
                        bTwoYAxes = false;
                    end
                    
                    % Create plots with only left y axes
                    if bTwoYAxes == false
                        % Getting the result data from the logger object
                        [ mfData, tLogProps ] = oLogger.get(this.coFigures{iFigure}.coPlots{iPlot}.aiIndexes);
                        
                        % Getting the Y label from the logger object
                        sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                        
                        % If the user selected to change the unit of time
                        % by which this plot is created, we have to adjust
                        % the afTime array. 
                        [ afTime, sTimeUnit ] = this.adjustTime(oLogger.afTime, this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions);
                        
                        % Now we can actually create the plot with all of the
                        % information we have gathered so far.
                        this.generatePlot(hHandle, afTime, mfData, tLogProps, sLabelY, sTimeUnit);
                        
                        % Setting the title of the plot
                        title(hHandle, this.coFigures{iFigure}.coPlots{iPlot}.sTitle);
                    else
                        % Create plots with left and right y axes
                        
                        % See if there is a field 'csUnitOverride', if yes,
                        % this means there are at least three units
                        % present. 
                        if isfield(this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions, 'csUnitOverride')
                            csUnitOverride = this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions.csUnitOverride;
                            if length(csUnitOverride) > 1
                                csLeftUnits  = csUnitOverride{1};
                                csRightUnits = csUnitOverride{2};
                                if length(csUnitOverride) > 2
                                    this.throw('plot','Your csUnitOverride cell contains too many values. It should only contain two cells with the units for the left and right y axes.');
                                end
                            else
                                switch csUnitOverride
                                    case 'all left'
                                        csLeftUnits  = this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions.csUniqueUnits;
                                        csRightUnits = {};
                                        
                                    case 'all right'
                                        csLeftUnits  = {};
                                        csRightUnits = this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions.csUniqueUnits;
                                        
                                    case 'even split'
                                        this.throw('plot','The ''even split'' option for the csUnitOverride setting has not yet been implemented.');
                                        
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
                            csLeftUnits  = this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions.csUniqueUnits{1};
                            csRightUnits = this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions.csUniqueUnits{2};
                        end
                        
                        aiIndexes = this.coFigures{iFigure}.coPlots{iPlot}.aiIndexes;
                        [ ~, tLogProps ] = oLogger.get(aiIndexes);
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
                        [ mfData, tLogProps ] = oLogger.get(aiLeftIndexes);
                        
                        % If the user selected to change the unit of time
                        % by which this plot is created, we have to adjust
                        % the afTime array. 
                        [ afTime, sTimeUnit ] = this.adjustTime(oLogger.afTime, this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions);
                        
                        % Getting the Y label from the logger object
                        sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                        
                        % Actually creating the plot with all of the
                        % information we have gathered so far.
                        this.generatePlot(hHandle, afTime, mfData, tLogProps, sLabelY, sTimeUnit);
                        
                        % Setting the title of the plot
                        title(hHandle, this.coFigures{iFigure}.coPlots{iPlot}.sTitle);
                        
                        if any(abRightIndexes)
                            % Getting the result data from the logger object
                            [ mfData, tLogProps ] = oLogger.get(aiRightIndexes);
                            
                            % Getting the Y label from the logger object
                            sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                            
                            % Actually creating the plot with all of the
                            % information we have gathered so far.
                            this.generateRightYAxisPlot(afTime, mfData, tLogProps, sLabelY);
                        end
                    end
                    
                    % Setting the callback to undock this subplot to the
                    % appropriate button.
                    coButtons{iPlot}.Callback = {@simulation.helper.plotter_basic.undockSubPlot, hHandle, legend};
                    
                    % Setting the entry in the handles cell. 
                    coAxesHandles{iPlot} = hHandle;
                    
                    %% Process the individual plot options
                    
                    % Process the line options struct, if there is one. 
                    if isfield(this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions, 'tLineOptions')
                        for iI = 1:length(hHandle.Children)
                            this.parseObjectOptions(hHandle.Children(iI), this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions.tLineOptions(iI));
                        end
                    end
                    
                    % Process all of our custom plot options.
                    % bLegend
                    if isfield(this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions, 'bLegend') && this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions.bLegend == false
                        hHandle.Legend.Visible = 'off';
                    end
                    
                    % tRightYAxesOptions
                    if isfield(this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions, 'tRightYAxesOptions')
                        yyaxis('right');
                        oAxes = gca;
                        this.parseObjectOptions(oAxes, this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions.tRightYAxesOptions);
                        yyaxis('left');
                    end
                    
                    % Process all of the items in tPlotOptions that
                    % actually correspond to properties of the axes object.
                    this.parseObjectOptions(hHandle, this.coFigures{iFigure}.coPlots{iPlot}.tPlotOptions);
                end
                
                %% Process the individual figure options
                
                set(oFigure, 'name', this.coFigures{iFigure}.sTitle);
                
                % If time plot is on, create it here. If the time plot gets
                % an extra figure, give it the name of the current figure
                % plus some post-fix. 
                if bTimePlot
                    if bTimePlotExtraFigure
                        oTimePlotFigure = figure();
                        plot(1:length(oLogger.afTime), oLogger.afTime);
                        grid(gca, 'minor');
                        xlabel('Ticks');
                        ylabel('Time in s');
                        title('Evolution of Simulation Time vs. Simulation Ticks');
                        set(oTimePlotFigure, 'name', [ 'Time Plot for ' this.oSimulationInfrastructure.sName ' - (' this.oSimulationInfrastructure.sCreated ')' ]');
                        set(groot, 'CurrentFigure', oFigure);
                    else
                        % Creating the subplot
                        hHandle = subplot(iRows, iColumns, iPlot+1);
                        
                        % Filling the subplot with the graph and modifying its
                        % properties.
                        hold(hHandle, 'on');
                        grid(hHandle, 'minor');
                        plot(1:length(oLogger.afTime), oLogger.afTime);
                        xlabel('Ticks');
                        ylabel('Time in s');
                        title(hHandle, 'Evolution of Simulation Time vs. Simulation Ticks');
                        legend('hide')
                        
                        % Setting the callback to undock this subplot to the
                        % appropriate button.
                        coButtons{iPlot+1}.Callback = {@simulation.helper.plotter_basic.undockSubPlot, hHandle, legend};
                        
                        % Setting the entry in the handles cell.
                        coAxesHandles{end + 1} = hHandle; %#ok<AGROW>
                        
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
            sTitle = [ this.oSimulationInfrastructure.sName ' - (' this.oSimulationInfrastructure.sCreated ')' ];
            this.coFigures{end+1} = simulation.monitors.figure(sTitle, coPlots, tFigureOptions);
        end
        
        
    end
    
    
    methods (Static)
        function sLabel = getLabel(poUnitsToLabels, tLogProps)
            pbLabels = containers.Map();
            
            for iP = 1:length(tLogProps)
                if poUnitsToLabels.isKey(tLogProps(iP).sUnit) && ~isempty(poUnitsToLabels(tLogProps(iP).sUnit))
                    pbLabels([ poUnitsToLabels(tLogProps(iP).sUnit) ' [' tLogProps(iP).sUnit ']' ]) = true;
                elseif ~strcmp(tLogProps(iP).sUnit,'-')
                    error('Unknown unit ''%s''. Please edit the poExpressionToUnit and poUnitsToLabels properties of logger_basic.m to include it.', tLogProps(iP).sUnit);
                end
            end
            
            sLabel = strjoin(pbLabels.keys(), ' / ');
        end
        
        
        function generatePlot(hHandle, afTime, mfData, tLogProps, sLabelY, sTimeUnit)
            
            hold(hHandle, 'on');
            grid(hHandle, 'minor');
            
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

