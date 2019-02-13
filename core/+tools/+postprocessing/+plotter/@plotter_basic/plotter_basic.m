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
            
            % The user may have selected to filter the results being
            % displayed here. To do that, a field in the tPlotOptions
            % struct must be called 'tFilter' and itself contain a struct
            % with the proper information on which logging properties
            % should be filtered out. The filter will be applied in the
            % next step using the find() method of the logger, please see
            % logger.m for more details. 
            % Checking if there is a filter at all.
            if isfield(tPlotOptions, 'tFilter')
                % Checking if there is a struct present and setting it.
                if isstruct(tPlotOptions.tFilter)
                    tFilter = tPlotOptions.tFilter;
                else
                    % Telling the user something went wrong.
                    error('The filter you have provided (%s) needs to be a struct.');
                end
            else
                % If there is no filter, we can just pass in empty. 
                tFilter = [];
            end
            
            % Internally, the identifier for each log item is its index in
            % the logger's data struct. The user-facing API, however,
            % allows using not just the indexes, but also the strings that
            % represent the names and lables of each log item. Here we are
            % calling the find() method on the logger to translate all
            % items in cxPlotValues into indexes. 
            % If the user defined any filters to be applied to the plot
            % values, they will also be applied within the find() method.
            aiIndexes = oLogger.find(cxPlotValues, tFilter);
            
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
            [ iNumberOfUnits, csUniqueUnits ] = this.getNumberOfUnits(oLogger, aiIndexes);
            
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
            
            if isfield(tFigureOptions, 'bArrangePlotsInSquare') && tFigureOptions.bArrangePlotsInSquare == true
                
                iPlots  = length(coPlots);
                iGrid   = ceil(sqrt(iPlots));
                
                % Rows of grid - can we reduce?
                iGridRows = iGrid;
                iGridCols = iGrid;
                
                while (iGridCols - 1) * iGridRows >= iPlots
                    iGridCols = iGridCols - 1;
                end
                
                coPlotsReArranged = cell(iGridRows,iGridCols);
                for iI = 1:numel(coPlots)
                    coPlotsReArranged{iI} = coPlots{iI};
                end
                
                coPlots = coPlotsReArranged;
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
            % and is used to create a default plot with all unique values
            % grouped by unit.
            
            % For easier reading we get a reference to the logger object of
            % this plotter. 
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            % Getting all of the expressions and units for each log value
            csValues = [{oLogger.tLogValues.sExpression};...
                        {oLogger.tLogValues.sUnit}];
                    
            % In order to group the log items together in a way that makes
            % sense, we group them by their expression. So we need to find
            % the unique expression values.
            [csExpressions, abUnique, ~] = unique(csValues(1,:));
            
            % With the unique expressions we can also determine their units
            csUnits = csValues(2, abUnique);
            
            % To create the titles for each plot, we get the lables for the
            % units from the logger.
            csTitles = values(oLogger.poUnitsToLabels, csUnits);
            
            % The lables are singular, e.g. 'Mass', 'Voltage', etc. To make
            % the titles nicer, we pluralize those words. 
            for iI = 1:length(csTitles)
                switch csTitles{iI}(end)
                    case 'y'
                        csTitles{iI}(end:end+2) = 'ies';
                    case 's'
                        csTitles{iI}(end+1:end+2) = 'es';
                    otherwise
                        csTitles{iI}(end+1) = 's';
                end
            end
            
            % Initializing the plots cell, a plot counter and the plot
            % options struct.
            iNumberOfPlots = length(abUnique);
            coPlots = cell(iNumberOfPlots,1);
            
            tPlotOptions = struct();
            
            % We will be only using one unit in each plot
            tPlotOptions.iNumberOfUnits = 1;
            
            % Now we're going through all units and creating a plot for
            % each one of them.
            for iI = 1:length(csUnits)
                % Using the logger's find() method we get the indexes for
                % all values with the same unit.
                tFilter = struct('sExpression', csExpressions{iI});
                aiIndexes = oLogger.find([], tFilter);
                
                % Checking if we found anything
                if ~isempty(aiIndexes)
                    % Now we can create the plot object and write it to the
                    % coPlots cell.
                    tPlotOptions.csUniqueUnits  = csUnits{iI};
                    coPlots{iI} = this.definePlot(tools.convertArrayToCell(aiIndexes), csTitles{iI}, tPlotOptions);
                    
                end
            end
            
            % Finally we create one figure object, turn on the time plot
            % and write it to the coFigures property of this plotter. 
            tFigureOptions = struct('bTimePlot', true, 'bArrangePlotsInSquare', true);
            sName = [ this.oSimulationInfrastructure.sName ' - (' this.oSimulationInfrastructure.sCreated ')' ];
            this.defineFigure(coPlots, sName, tFigureOptions);
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
                    error('Unknown unit ''%s''. Please edit the poExpressionToUnit and poUnitsToLabels properties of logger.m to include it.', tLogProps(iP).sUnit);
                end
            end
            
            % Now we join all of the unique, non-empty items in the labels
            % cell using a forward slash to separate them.
            sLabel = strjoin(unique(csLabels(~cellfun(@isempty, csLabels))), ' / ');
        end
        
         function [ iNumberOfUnits, csUniqueUnits ] = getNumberOfUnits(oLogger, aiIndexes)
            %GETNUMBEROFUNITS Returns information on the units of the provided items
            % This function determines the number of units in a single plot
            % and returns the value as an integer as well as a cell
            % containing all units. 
            
            % Initializing a cell that can hold all of the unit strings.
            csUnits = cell(length(aiIndexes),1);
            
            % Going through each of the indexes being queried and getting
            % the information
            for iI = 1:length(aiIndexes)
                % For easier reading we get the current index into a local
                % variable.
                iIndex = aiIndexes(iI);
                
                % If the index is smaller than zero, this indicates that we
                % are dealing with a virtual value; one that was not logged
                % directly, but calculated from other logged values. We
                % have to get the units from somewhere else then. 
                if iIndex < 0
                    csUnits{iI} = oLogger.tVirtualValues(-1 * iIndex).sUnit;
                else
                    csUnits{iI} = oLogger.tLogValues(iIndex).sUnit;
                end
            end
            
            % Now we can just get the number of unique entries in the cell
            % and we have what we came for!
            csUniqueUnits  = unique(csUnits);
            iNumberOfUnits = length(csUniqueUnits);
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

