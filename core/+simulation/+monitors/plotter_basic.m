classdef plotter_basic < simulation.monitor
    %PLOTTER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    
    properties (SetAccess = public, GetAccess = public)
        rPadding = 0.03;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Name of log monitor
        sLogger = 'oLogger';
        
        tPlots = struct('sTitle', {}, 'aiIdx', {}, 'mbPosition', {}, 'sSubtitle', {});
        
        tPlotsByName;
    end
    
    methods
        function this = plotter_basic(oSimulationInfrastructure, sLogger)
            %TODO register on pause, finish, show hints/help?
            this@simulation.monitor(oSimulationInfrastructure);%, { 'finish', 'pause' });
            
            if nargin >= 2 && ~isempty(sLogger)
                this.sLogger = sLogger;
            end
        end
        
        
        
        %% Methods to define plots
        
        function definePlotByName(this, cNames, sTitle, yLabel, sTimeUnit, mbPosition)
            % The cNames input should be a cell(array) containing the
            % custom names for all log parameters that should be put into
            % this plot
            %
            % The sTitle input will define the title of the figure and also
            % define which plots are put into which figure if subplots are
            % used. If you want to have multiple plots in the same figure,
            % use the same title for all the plots that should go into the
            % same figure. The position of the plots has to be defined by
            % the mbPosition input (more information below)
            %
            % yLabel defines the label of the y-axis
            %
            % sTimeUnit defines the unit used for the time. The possible
            % inputs currently are: 's', 'min', 'h', 'd', 'weeks'
            
            % In this function only the struct with the necessary function to
            % perform the plotting is defined, the plotting itself is
            % performed in the plot command
            this.tPlotsByName(end+1).sTitle = sTitle;
            this.tPlotsByName(end).cNames = cNames;
            this.tPlotsByName(end).yLabel = yLabel;
            this.tPlotsByName(end).sTimeUnit = sTimeUnit;
            if nargin > 5
                this.tPlotsByName(end).mbPosition = mbPosition;
            end
            
        end
        
        
        function definePlot(this, xReference, sTitle, mbPosition, sSubtitle)
            % This function is used to define the individual plots that are
            % created when using the oLastSimObj.plot command. The
            % following inputs can be used for it:
            %
            % xReference: For this field three possible inputs exist:
            %  1)   Cell: can be a one dimensional cell array containing
            %             the Labels (custom names) as specified by the
            %             user for all values that shall be plotted into
            %             this plot. Can use mbPosition to define a subplot
            %             position.
            %             Alternativly can be a three dimensional cell
            %             array, where the first two dimensions define the
            %             matrix of subplots used for the overall figure
            %             and the third dimension contains the strings with
            %             the labels to the log values for the respective
            %             subplot. For example a cell(2,3,5) would create a
            %             subplot matrix:
            %                               0 | 0 | 0
            %                               0 | 0 | 0
            %             and the entry {2,3,:} would contain all values
            %             that are supposed to go into the subplot in row
            %             two column 3
            %
            %  2) Struct: generic use case that can be used to define which
            %             property of the log should be filtered after with
            %             the fieldnames of the struct, and defining the
            %             values that will be plotted with the field
            %             values. For example 
            %             xReference.sLabel = {'Label 1', 'Label 2'} 
            %             will filter for labels and plot 'Label 1' and 'Label 2'
            %             Possible fieldnames are:
            %             sLabel, sUnit, sObjectPath, sExpression, sName,
            %             sObjUuid, iIndex
            %
            %             Alternativly provide a fieldname called
            %             xDataReference to set the xDataReference For
            %             units it can also just be a string (TO DO: scjo,
            %             explain correct usage of xDataReference!)
            %
            %  3) String: if a string is provided directly it should
            %             reference a unit and will plot all values that
            %             have this unit
            % 
            % sTitle:   string that defines the title for the figure. If only
            %           one overall figure is used, it is the title of the subplot
            %
            %
            % Optional Inputs for subplot functionality:
            % mbPosition:   boolean matrix that has the intended size
            %               and shape of the subplots for the overall
            %               figure (as specified by sTitle) and contains
            %               one true for the location of this subplot. For
            %               example this matrix:
            %                       0 | 0 | 0 | 0
            %                       0 | 1 | 0 | 0
            %               Will result in a figure with 4 columns and 2
            %               rows of subplots and the plot define with this
            %               specific matrix will be in the second row in
            %               the second column
            %
            % sSubtitle:    can be used to define titles for the individual
            %               subplots that will be displayed in the figure
            
            if isfield (xReference, 'xDataReference')
                xDataReference = xReference.xDataReference;
            else
                xDataReference = false;
            end
            
            if nargin < 4
                mbPosition = [];
                sSubtitle  = [];
            elseif nargin < 5
                sSubtitle  = [];
            end
            
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            if isstruct(xDataReference)
                xDataReference = simulation.monitors.plotter_basic.getIndicesFromStruct(xDataReference);
            end
            
            if isempty(xDataReference)
                this.warn('plotter_basic', 'There are no %s to plot. Subplot will not be added to figure.', sTitle);
                return;
            
            % xDataReference false --> .find() below gets all values!
            elseif islogical(xDataReference) && (xDataReference == false)
                xDataReference = [];
                
            end
            
            tFilter = struct();
            
            if nargin >= 3 && ~isempty(xReference)
                if isstruct(xReference)
                    % generic case: a struct was supplied where the field
                    % name specifies after which field of the log struct is
                    % filtered (for example label or unit)
                    tFilter = xReference;
                elseif iscell(xReference)
                    % case plot by name, where a cell array containing the
                    % strings for the log values that shall be ploted are
                    % contained
                    tFilter.sLabel = xReference;
                else
                    % if it is neither a struct nor a cell, it should be a
                    % string containing the unit which should be ploted
                    % (e.g. 'K')
                    tFilter.sUnit = xReference;
                end
            end
            
            csFields = fieldnames(tFilter);
            for iField = 1:length(csFields)
                % TO DO: Can there be more than one field to the filter
                % struct? like mixing unit filter and label filter? And
                % does the subplot logic using a three dimensional cell
                % still have to work for that?
                
                mfFieldSize = size(tFilter.(csFields{iField}));
                csFilter = tFilter.(csFields{iField});
                
                if length(mfFieldSize) == 3
                    % In this case the field contains the information about
                    % the subplot position for the individual components
                    % and we have to create the mbPosition value and make
                    % individual plots out of this information
                    
                    iPlots = mfFieldSize(1) * mfFieldSize(2);
                    mbPosition = false(mfFieldSize(1) , mfFieldSize(2));
                    
                    for iPlot = 1:iPlots
                        % decides the position of the subplot based on the
                        % first two sizes of the cell array
                        iRow    = ceil(iPlot / mfFieldSize(2));
                        iColumn = iPlot - (mfFieldSize(2) * (iRow - 1));
                        
                        % sets the current position of the subplot to true
                        mbPosition(iRow,iColumn) = true;
                        
                        % uses only the part of the filter that defines the
                        % current subplot for a partial fitler struct
                        tFilterPart.(csFields{iField}) = csFilter(iRow,iColumn,:);
                        
                        % gets the indices of the log values (referencing
                        % to mfLog in the oLogger object) for the current
                        % subplot
                        aiIdx = oLogger.find(xDataReference, tFilterPart);
                        
                        % if it is not empty add a new plot, if it is give
                        % a warning
                        if ~isempty(aiIdx)
                            this.tPlots(end + 1) = struct('sTitle', sTitle, 'aiIdx', aiIdx, 'mbPosition', mbPosition, 'sSubtitle', sSubtitle);
                        else
                            this.warn('plotter_basic', 'There are no %s to plot. Subplot will not be added to figure.', sTitle);
                        end
                        
                        % set all position to 0 again to prepare for the
                        % next subplot
                        mbPosition = false(mfFieldSize(1) , mfFieldSize(2));
                    end
                    
                else
                    
                    aiIdx = oLogger.find(xDataReference, tFilter);

                    % We only add a plot if there will actually be anything to
                    % plot. If there isn't, we tell the user. 
                    if ~isempty(aiIdx)
                        this.tPlots(end + 1) = struct('sTitle', sTitle, 'aiIdx', aiIdx, 'mbPosition', mbPosition, 'sSubtitle', sSubtitle);
                    else
                        this.warn('plotter_basic', 'There are no %s to plot. Subplot will not be added to figure.', sTitle);
                    end

                end
            end
            
        end
        
        
        
        
        %% Default plot method
        function plot(this, tParameters)
            % The plot command can be provided with a struct containing
            % several parameters as fields. The field names have to be as
            % follows in order to work:
            %
            % .bLegend:     can be true or false, deciding if the legend
            %               (description for each line) should be included
            % .bTimePlotOn: can be true or false decides wether the
            %               simulation time over tick plot will be displayed
            % .bPlotToolsOn: can be true or false, decides if the plots 
            %               will be opened with or without plot tools active
            % .bSinglePlot: can be true or false, for true all defined
            %               plots will be put into a single figure
            % .sTimeUnit:   string that contains the unit that should be
            %               used for the time axis (x axis). Can be:
            %               's', 'min, 'h', 'd', 'weeks'
            bLegendOn    = true;
            bTimePlotOn  = true;
            bPlotToolsOn = false;
            bSinglePlot  = false;
            sTimeUnit    = 's';
            if nargin > 1 
                if isfield(tParameters, 'bLegendOn')
                    bLegendOn = tParameters.bLegendOn;
                end
                if isfield(tParameters, 'bTimePlotOn')
                    bTimePlotOn = tParameters.bTimePlotOn;
                end
                if isfield(tParameters, 'bPlotToolsOn')
                    bPlotToolsOn = tParameters.bPlotToolsOn;
                end
                
                if isfield(tParameters, 'bSinglePlot')
                    bSinglePlot = tParameters.bSinglePlot;
                end
                if isfield(tParameters, 'sTimeUnit')
                    sTimeUnit = tParameters.sTimeUnit;
                end
            end
            
            oInfra  = this.oSimulationInfrastructure;
            iPlots  = length(this.tPlots) + sif(bTimePlotOn,1,0);
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);

            if bSinglePlot
                %% Code for using a single figure to plot everything
                % Ignores any subplot information of the individual plots!
                
                % TO DO: Action Item scjo, comment and finish functionality
                % (include sTimeUnit), or should we just remove this? I
                % mean I do not know a case where it actually makes sense
                % to use only one figure
                oFigure = figure();
                iGrid   = ceil(sqrt(iPlots));
                
                % Rows of grid - can we reduce?
                iGridRows = iGrid;
                iGridCols = iGrid;

                %while iGridCols * (iGridRows - 1) >= iPlots
                %    iGridRows = iGridRows - 1;
                %end
                while (iGridCols - 1) * iGridRows >= iPlots
                    iGridCols = iGridCols - 1;
                end


                coHandles = {};

                for iP = 1:length(this.tPlots)
                    %hHandle = subplot(iGridRows, iGridCols, iP);
                    hHandle = simulation.helper.plotter_basic.subaxis(iGridRows, iGridCols, iP, 'Spacing', 0.05, 'Padding', this.rPadding, 'Margin', 0.05);

                    [ mfData, tLogProps ] = oLogger.get(this.tPlots(iP).aiIdx);

                    %TODO ... well, differently ;)
                    sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);

                    this.generatePlot(hHandle, oLogger.afTime, mfData, tLogProps, sLabelY);

                    title(hHandle, this.tPlots(iP).sTitle);

                    if ~bLegendOn
                        legend('hide');
                    end


                    coHandles{end + 1} = hHandle;
                end

                if bTimePlotOn
                    %hHandle = subplot(iGridRows, iGridCols, iP + 1);
                    hHandle = simulation.helper.plotter_basic.subaxis(iGridRows, iGridCols, iP + 1, 'Spacing', 0.05, 'Padding', this.rPadding, 'Margin', 0.05);


                    hold(hHandle, 'on');
                    grid(hHandle, 'minor');
                    plot(1:length(oLogger.afTime), oLogger.afTime);
                    xlabel('Ticks');
                    ylabel('Time in s');
                    title(hHandle, 'Evolution of Simulation Time vs. Simulation Ticks');

                    coHandles{end + 1} = hHandle;
                end

                set(oFigure, 'name', [ oInfra.sName ' - (' oInfra.sCreated ')' ]);

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

                drawnow;


                if bPlotToolsOn
                    plottools(oFigure, 'on');
                else
                    % Maximize figure
                    set(gcf, 'units','normalized','OuterPosition', [0 0 1 1]);
                end

                oFigure.UserData = struct('coAxesHandles', { coHandles });
            else
                %% Code used if several figures should be used to plot the data
                
                % Now the log values and plots are correctly asscociated and
                % the actual plotting can start. 

                % In order to allow multiple plots to be set as subplots for
                % one figure it is necessary to store all figures in a cell
                % array to allow later reacces to them
                csFigures = cell(0,0);

                % Then we loop through all plots that are defined in this way
                for iPlot = 1:length(this.tPlots)

                    % First we get the data and the log properties for each
                    % plot
                    [ mfData, tLogProps ] = oLogger.get(this.tPlots(iPlot).aiIdx);

                    % For each plot a title of the figure is specified and if
                    % multiple plots are used as subplots the title also serves
                    % as identifier into which figure they should be plotted.
                    % This loop checks if the figure for this plot already
                    % exists
                    bFoundFigure = false;
                    for iFigure = 1:length(csFigures)
                        if strcmp(csFigures{iFigure}.Name, this.tPlots(iPlot).sTitle)
                            % and if it does exist we set the already existing
                            % figure as current figure
                            set(0, 'currentfigure', csFigures{iFigure});
                            bFoundFigure = true;
                            break
                        end
                    end

                    % If the figure was not found a new figure has to be
                    % created and stored in the cell array
                    if ~bFoundFigure
                        csFigures{end+1} = figure('name', this.tPlots(iPlot).sTitle);
                        set(0, 'currentfigure', csFigures{end});
                    end

                    % Now we check if the figure is intended as subplot. The
                    % subplot position is defined by mbPosition which has only
                    % one boolean true at the intended position of the plot.
                    % For example the matrix:
                    % 0 0 0
                    % 0 1 0
                    % 0 0 0
                    % would define the subplot in the middle of a 3x3 field of
                    % subplots
                    if isfield(this.tPlots(iPlot), 'mbPosition') && ~isempty(this.tPlots(iPlot).mbPosition)
                        % The boolean matrix has to be translated into the
                        % required inputs for the subplot command, which is the
                        % total row and line number and the number of the
                        % subplot (which are counted from the top left to right
                        % in each row and then from top to bottom for several
                        % rows)
                        [iNumberRows, iNumberColumns] = size(this.tPlots(iPlot).mbPosition);
                        [iRow, iColumn] = find(this.tPlots(iPlot).mbPosition);
                        iPlotNumber = ((iRow - 1)*iNumberColumns) + iColumn;
                        subplot(iNumberRows,iNumberColumns,iPlotNumber)
                    end
                    grid on
                    hold on
                    % In order to allow the user to define the desired time
                    % output the actual plotting checks for the sTimeUnit
                    % string and transforms the log (which is always in
                    % seconds) into the desired time unit and sets the correct
                    % legend entry
                    switch sTimeUnit
                        case 's'
                            plot((oLogger.afTime), mfData)
                            xlabel('Time in s')
                        case 'min'
                            plot((oLogger.afTime./60), mfData)
                            xlabel('Time in min')
                        case 'h'
                            plot((oLogger.afTime./3600), mfData)
                            xlabel('Time in h')
                        case 'd'
                            plot((oLogger.afTime./86400), mfData)
                            xlabel('Time in d')
                        case 'weeks'
                            plot((oLogger.afTime./604800), mfData)
                            xlabel('Time in weeks')
                    end
                    
                    sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                    ylabel( sLabelY );
                    
                    csLegend = {};
                    for iP = 1:length(tLogProps)
                        csLegend{end + 1} = [ tLogProps(iP).sLabel ];
                    end
                    legend(csLegend);
                    
                    if ~bLegendOn
                        legend('hide');
                    end
                    
                    % Maximize figure
                    set(gcf, 'units','normalized','OuterPosition', [0 0 1 1]);
                end
                
                if bTimePlotOn
                    figure('name', 'Timeplot');
                    plot(1:length(oLogger.afTime), oLogger.afTime);
                    grid on;
                    xlabel('Ticks');
                    ylabel('Time in s');
                end
                
                if bPlotToolsOn
                    for iFigure = 1:length(csFigures)
                        plottools(csFigures{iFigure}, 'on');
                    end
                end
            end
        end
        function MathematicOperationOnLog(this, csLogVariables, hFunction, sNewLogName, sUnit)
            %% Function used to perform mathematical operations on logged values and store them as new derived log value
            % 
            % WILL NOT BE ABLE TO PLOT THESE VALUES AT THE MOMENT!! WAITING
            % FOR SCJO TO EXPLAIN EXISTING LOGIC, then this will likely be
            % removed. Otherwise I have to think about a way to implement
            % this so it works with the exisiting ploting logic.
            %
            % Requires a function input to describe the desired operation,
            % and a cell array to describe the log variables in the order
            % they should be used in the function. For examples please view
            % the CDRA tutorial
            
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            cmfArgument = cell(length(csLogVariables),1);
            
            % First it is necessary to finde the log values from the
            % variables used in the operation and store them in the
            % argument cell array (a cell array was necessary because it is 
            % used as function input) 
            for iIndex = 1:length(oLogger.tLogValues)
                for iLogVariable = 1:length(csLogVariables)
                    if strcmp('Time', csLogVariables{iLogVariable})
                        % use the time as argument
                        mfArgument = oLogger.afTime';
                        cmfArgument{iLogVariable} = mfArgument;
                        
                    elseif strcmp('TimeStep', csLogVariables{iLogVariable})
                        % use time step as argument
                        mfArgument = zeros(length(oLogger.afTime),1);
                        mfArgument(2:end) = (oLogger.afTime(2:end) - oLogger.afTime(1:end-1))';
                    	cmfArgument{iLogVariable} = mfArgument;
                        
                    elseif strcmp(oLogger.tLogValues(iIndex).sLabel, csLogVariables{iLogVariable})

                       % Stores the logged values for the plot and name
                       % in the struct
                       mfArgument = oLogger.mfLog(:,iIndex);

                       % remove NaNs from the log
                       mfArgument(isnan(mfArgument)) = [];
                       
                       cmfArgument{iLogVariable} = mfArgument;
                    end
                end
            end
            
            for iIndex = 1:length(oLogger.tDerivedLogValues)
                for iLogVariable = 1:length(csLogVariables)
                    if strcmp(oLogger.tDerivedLogValues(iIndex).sLabel, csLogVariables{iLogVariable})

                       % Stores the logged values for the plot and name
                       % in the struct
                       mfArgument = oLogger.mfDerivedLog(:,iIndex);

                       % remove NaNs from the log
                       mfArgument(isnan(mfArgument)) = [];
                       
                       cmfArgument{iLogVariable} = mfArgument;
                    end
                end
            end
            
            % In order to ensure that these logs are the same length as the
            % "normal" logs, a vector with nans of the same length as the
            % "normal" logs is created
            mfLogValue = nan(length(oLogger.mfLog(:,1)),1);
            % Now only the values that actual have a number are overwritten
            % with values, the rest remains as nans
            mfLogValue(1:length(mfArgument)) = hFunction(cmfArgument{:});
            
            % Since this is the plotter it is not possible to add the value
            % from here. Instead a function of the logger is called to
            % store the new log value, together with a name and a unit in
            % the tDerivedLogValues struct and the mfDerivedLog matrix of
            % the logger
            oLogger.add_mfLogValue(sNewLogName, mfLogValue, sUnit)
        end
        
        function clearPlots(this)
            this.tPlots = struct('sTitle', {}, 'aiIdx', {});
        end
    end
    
    
    methods (Static)
        function sLabel = getLabel(poUnitsToLabels, tLogProps)
            pbLabels = containers.Map();
            
            for iP = 1:length(tLogProps)
                if poUnitsToLabels.isKey(tLogProps(iP).sUnit) && ~isempty(poUnitsToLabels(tLogProps(iP).sUnit))
                    pbLabels([ poUnitsToLabels(tLogProps(iP).sUnit) ' [' tLogProps(iP).sUnit ']' ]) = true;
                end
            end
            
            sLabel = strjoin(pbLabels.keys(), ' / ');
        end
        
        
        function generatePlot(hHandle, afTime, mfData, tLogProps, sLabelY)
            %TODO
            % * y-axis - if all units the same, plot unit there, else plot
            %   in legend!
            
            hold(hHandle, 'on');
            grid(hHandle, 'minor');
            
            csLegend = {};
            
            for iP = 1:length(tLogProps)
                csLegend{end + 1} = [ tLogProps(iP).sLabel ' [' tLogProps(iP).sUnit ']' ];
            end
            
            plot(afTime, mfData);
            legend(csLegend, 'Interpreter', 'none');
            
            ylabel(sLabelY);
            xlabel('Time in s');
            
            %%% Default Code END
        end
        
        
        
        function aiIdx = getIndicesFromStruct(tData)
            csKeys = fieldnames(tData);
            aiIdx  = [];
            
            for iK = 1:length(csKeys)
                sKey = csKeys{iK};
                
                if isstruct(tData.(sKey))
                    aiIdx = [ aiIdx simulation.monitors.plotter_basic.getIndicesFromStruct(tData.(sKey)) ];
                else
                    aiIdx(end + 1) = tData.(sKey);
                end
            end
        end
    end
end

