classdef plotter_basic < simulation.monitor
    %PLOTTER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    
    properties (SetAccess = public, GetAccess = public)
        rPadding = 0.03;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Name of log monitor
        sLogger = 'oLogger';
        
        tPlots = struct('sTitle', {}, 'aiIdx', {});
        
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
        
        function definePlot(this, xDataReference, sTitle)
            this.definePlotWithFilter(xDataReference, [], sTitle);
            
            
        end
        
        
        function definePlotAllWithFilter(this, sFilter, sTitle)
            % xDataReference false --> get all values!
            this.definePlotWithFilter(false, sFilter, sTitle);
        end
        
        
        function definePlotWithFilter(this, xDataReference, sFilter, sTitle)
            % xDataReference can be either integer array or (recursive)
            % struct with integers.
            
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
            
            % Filter is by unit
            tFilter = struct();
            
            if nargin >= 3 && ~isempty(sFilter)
                if isstruct(sFilter)
                    tFilter = sFilter;
                else
                    tFilter.sUnit = sFilter;
                end
            end
            
            
            aiIdx = oLogger.find(xDataReference, tFilter);
            
            % We only add a plot if there will actually be anything to
            % plot. If there isn't, we tell the user. 
            if ~isempty(aiIdx)
                this.tPlots(end + 1) = struct('sTitle', sTitle, 'aiIdx', aiIdx);
            else
                this.warn('plotter_basic', 'There are no %s to plot. Subplot will not be added to figure.', sTitle);
            end
            
            
            return;
            
            [ mfLogData, tLogProps ] = oLogger.get(xDataReference, tFilter);
            
            
            disp('=========================== PLOT =====================');
            disp(xDataReference);
            disp(sFilter);
            
            for iS = 1:length(tLogProps)
                disp('---------');
                disp(tLogProps(iS));
            end
        end
        
        
        
        
        %% Default plot method
        function plot(this, tParameters)
            
            bLegendOn    = true;
            bTimePlotOn  = true;
            bPlotToolsOn = false;
            
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
            end
            
            oInfra  = this.oSimulationInfrastructure;
            oFigure = figure();
            iPlots  = length(this.tPlots) + sif(bTimePlotOn,1,0);
            iGrid   = ceil(sqrt(iPlots));
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
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
            
            
        end
        function MathematicOperationOnLog(this, csLogVariables, hFunction, sNewLogName, sUnit)
            %% Function used to perform mathematical operations on logged values and store them as new derived log value
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
        function plotByName(this, ~)
            %% Plot by Name
            % This function can be used to create plots by specifying the
            % names of the log variables that should be used in the
            % individual plot. These have to be defined in the setup file
            % by using the definePlotByName function from this file. For
            % information on the inputs and usage of the Plot By Name
            % functionalty please view the comments of that function
            
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            %% Associating log values and plots
            % In order to create the plots it is first necessary to find
            % the log values and asscociate them with the correct plots.
            % This is performed by looping over all log entries, plots, and
            % names of variables that should be plotted for each plot to
            % get the correct mfLog entries. This might be inefficient, but
            % I currently have no idea how to make this more performant and
            % since it is only executed once during plotting and not during
            % the simulation itself, this should be fine
            
            for iPlot = 1:length(this.tPlotsByName)
                this.tPlotsByName(iPlot).mLogData = [];
            end
            for iIndex = 1:length(oLogger.tLogValues)
                for iPlot = 1:length(this.tPlotsByName)
                    for iName = 1:length(this.tPlotsByName(iPlot).cNames) 
                        if strcmp(oLogger.tLogValues(iIndex).sLabel, this.tPlotsByName(iPlot).cNames{iName})

                           % Stores the logged values for the plot and name
                           % in the struct
                           mfLog = oLogger.mfLog(:,iIndex);

                           % remove NaNs from the log
                           mfLog(isnan(mfLog)) = [];
                            
                           % associate the log values with the correct
                           % plot
                           this.tPlotsByName(iPlot).mLogData(:,iName) = mfLog;
                        end
                    end
                end
            end
            
            % Since derived logs (that were generated from normal log
            % values through mathematical operations) were introduced a
            % second loop is necessary to check if the desired value is
            % a derived log
            for iIndex = 1:length(oLogger.tDerivedLogValues)
                for iPlot = 1:length(this.tPlotsByName)
                    for iName = 1:length(this.tPlotsByName(iPlot).cNames) 
                        if strcmp(oLogger.tDerivedLogValues(iIndex).sLabel, this.tPlotsByName(iPlot).cNames{iName})

                           % Stores the logged values for the plot and name
                           % in the struct
                           mfLog = oLogger.mfDerivedLog(:,iIndex);

                           % remove NaNs from the log
                           mfLog(isnan(mfLog)) = [];
                            
                           % associate the log values with the correct
                           % plot
                           this.tPlotsByName(iPlot).mLogData(:,iName) = mfLog;
                        end
                    end
                end
            end
            
            %% Plotting
            % Now the log values and plots are correctly asscociated and
            % the actual plotting can start. 
            
            % In order to allow multiple plots to be set as subplots for
            % one figure it is necessary to store all figures in a cell
            % array to allow later reacces to them
            csFigures = cell(0,0);
            
            % Then we loop through all plots that are defined in this way
            for iPlot = 1:length(this.tPlotsByName)
                
                % For each plot a title of the figure is specified and if
                % multiple plots are used as subplots the title also serves
                % as identifier into which figure they should be plotted.
                % This loop checks if the figure for this loop already
                % exists
                bFoundFigure = false;
                for iFigure = 1:length(csFigures)
                    if strcmp(csFigures{iFigure}.Name, this.tPlotsByName(iPlot).sTitle)
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
                    csFigures{end+1} = figure('name', this.tPlotsByName(iPlot).sTitle);
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
                if isfield(this.tPlotsByName(iPlot), 'mbPosition') && ~isempty(this.tPlotsByName(iPlot).mbPosition)
                    % The boolean matrix has to be translated into the
                    % required inputs for the subplot command, which is the
                    % total row and line number and the number of the
                    % subplot (which are counted from the top left to right
                    % in each row and then from top to bottom for several
                    % rows)
                    [iNumberRows, iNumberColumns] = size(this.tPlotsByName(iPlot).mbPosition);
                    [iRow, iColumn] = find(this.tPlotsByName(iPlot).mbPosition);
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
                for iName = 1:length(this.tPlotsByName(iPlot).cNames) 
                    switch this.tPlotsByName(iPlot).sTimeUnit
                        case 's'
                            plot((oLogger.afTime), this.tPlotsByName(iPlot).mLogData(:,iName))
                            xlabel('Time in s')
                        case 'min'
                            plot((oLogger.afTime./60), this.tPlotsByName(iPlot).mLogData(:,iName))
                            xlabel('Time in min')
                        case 'h'
                            plot((oLogger.afTime./3600), this.tPlotsByName(iPlot).mLogData(:,iName))
                            xlabel('Time in h')
                        case 'd'
                            plot((oLogger.afTime./86400), this.tPlotsByName(iPlot).mLogData(:,iName))
                            xlabel('Time in d')
                        case 'weeks'
                            plot((oLogger.afTime./604800), this.tPlotsByName(iPlot).mLogData(:,iName))
                            xlabel('Time in weeks')
                    end
                end
                ylabel( this.tPlotsByName(iPlot).yLabel)
                legend(this.tPlotsByName(iPlot).cNames)
                % Maximize figure
                set(gcf, 'units','normalized','OuterPosition', [0 0 1 1]);
            end
            
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

