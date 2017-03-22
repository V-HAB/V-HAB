classdef plotter_basic < simulation.monitor
    %PLOTTER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    
    properties (SetAccess = public, GetAccess = public)
        rPadding = 0.03;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Name of log monitor
        sLogger = 'oLogger';
        
        tPlots = struct('sTitle', {}, 'aiIdx', {}, 'txCustom', {}, 'csFunctions', {});
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
        
        function definePlot(this, xReference, sTitle, txCustom)
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
            %             two column three
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
            %
            % txCustom:    can be used to customize the plot. Has to be a
            %              struct with the fieldnames that shall be
            %              customized and the fieldvalues that shall be
            %              used for the customization. Possible field names
            %              are:
            %              - mbPosition: boolean matrix that has the intended 
            %                size and shape of the subplots for the overall
            %                figure (as specified by sTitle) and contains
            %                one true for the location of this subplot. For
            %                example this matrix:
            %                       0 | 0 | 0 | 0
            %                       0 | 1 | 0 | 0
            %               Will result in a figure with 4 columns and 2
            %               rows of subplots and the plot define with this
            %               specific matrix will be in the second row in
            %               the second column
            %
            %              - sXLabel / sYLabel: Set a custom label for the axis
            %              - sTitle: Set a custom title displayed above the
            %                figure or subplot
            %              - csLineStyle: Specify the linestyle for the plot
            %                see help plot for possible entries. If you
            %                have more than one line simply specify the
            %                style for each line as a string in one cell
            %                value. The first cell will be used for the
            %                first plot value
            %              - csLegend: Define cell array containing custom
            %                legend entries for your plot. First entry is
            %                used for first plot value
            %              - miXTicks/ miYTicks: Define the ticks on the Axis by
            %                providing a matrix with the value for each tick
            %              - mfXLimits/ mfYLimits: Define the limits on the Axis by
            %                providing a matrix with the start and end value
            %
            % Additional functionalities:
            %
            % It is also possible to define plot values including
            % calculations. For example the following code,
            % csNames = {'Relative Humidity Cabin * 100'};
            % oPlot.definePlot(csNames, 'Relative Humidity Habitat');
            % will multiply the log value with the label 'Relative Humidity
            % Cabin' with 100 to get the humidity value from 0-1 to 0-100
            % Another Example:
            % csNames = {'- 1 * ( CDRA CO2 Inlet Flow 1 + CDRA CO2 Inlet Flow 2 )', 'CDRA CO2 Outlet Flow 1 + CDRA CO2 Outlet Flow 2'};
            % oPlot.definePlot(csNames,  'CDRA CO2 Flowrates');
            % Here two indepent values are calculate, one adds the two
            % inlet flows and multiplies them with -1 resulting in a plot
            % of the total inlet flow. The second entry of th csNames cell
            % array adds the two outlet flows resulting in a total outlet
            % flow. There are no limitations to this functionality
            % regarding number of possible log values to be used in the
            % calculations. The limitations currently are that you can only
            % define one subplot after the other (using mbPosition) and
            % that there has to be one space between each Symbol (+-*/^) and
            % each number and each Log Value!
            
            if isfield (xReference, 'xDataReference')
                xDataReference = xReference.xDataReference;
            else
                xDataReference = false;
            end
            
            if nargin < 4
                txCustom  = [];
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
                
                if ~iscell(tFilter.(csFields{iField}))
                    csFilter{1} = tFilter.(csFields{iField});
                else
                    csFilter = tFilter.(csFields{iField});
                end
                
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
                        
                        txCustom.mbPosition = mbPosition;
                        
                        % if it is not empty add a new plot, if it is give
                        % a warning
                        if ~isempty(aiIdx)
                            this.tPlots(end + 1) = struct('sTitle', sTitle, 'aiIdx', aiIdx, 'txCustom', txCustom, 'csFunctions', []);
                        else
                            this.warn('plotter_basic', 'There are no %s to plot. Subplot will not be added to figure.', sTitle);
                        end
                        
                        % set all position to 0 again to prepare for the
                        % next subplot
                        mbPosition = false(mfFieldSize(1) , mfFieldSize(2));
                    end
                    
                else
                    % NOTE Calculations on plots will not work for subplot
                    % cell assignments

                    % it is possible to use calculations with logged variables
                    % by using the label for two variables and a calculation
                    % sign in between (with one space before the sign and one
                    % space after the sign)
                    csFunctions = cell(1,length(csFilter));
                    csFilterNew = cell(1,length(csFilter));
                    for iFilter = 1:length(csFilter)
                        % gets the sign positions for the current filter field
                        miSubtractions      = regexp(csFilter{iFilter}, '-');
                        miAdditions         = regexp(csFilter{iFilter}, '+');
                        miMultiplications   = regexp(csFilter{iFilter}, '*');
                        miDivisions         = regexp(csFilter{iFilter}, '/');
                        miParenthesisOpen   = regexp(csFilter{iFilter}, '(');
                        miParenthesisClose  = regexp(csFilter{iFilter}, ')');

                        % puts all sign positions into one variable and orders
                        % it from lowest to highest position
                        miSigns = miSubtractions;
                        miSigns(end+1 : end+(length(miAdditions)))          = miAdditions;
                        miSigns(end+1 : end+(length(miMultiplications)))    = miMultiplications;
                        miSigns(end+1 : end+(length(miDivisions)))          = miDivisions;
                        miSigns(end+1 : end+(length(miParenthesisOpen)))  	= miParenthesisOpen;
                        miSigns(end+1 : end+(length(miParenthesisClose)))  	= miParenthesisClose;
                        miSigns = sort(miSigns);

                        % if there are signs gets the signs and seperate the
                        % string into several substrings containing the actual
                        % labels
                        if ~isempty(miSigns)

                            sString = csFilter{iFilter};

                            csStrings = cell(length(miSigns),1);

                            if length(miSigns) == 1
                                csStrings{1} = sString(1 : (miSigns(1) -2));
                                csStrings{1+1} = sString((miSigns(1) +2) : end);
                            else
                                for iSign = 1:length(miSigns)
                                    if iSign == 1
                                        csStrings{iSign} = sString(1:(miSigns(iSign) -2));
                                    elseif iSign == length(miSigns)
                                        csStrings{iSign} = sString((miSigns(iSign-1) +2) : (miSigns(iSign) -2));
                                        csStrings{iSign+1} = sString((miSigns(iSign) +2) : end);
                                    else
                                        csStrings{iSign} = sString((miSigns(iSign-1) +2) : (miSigns(iSign) -2));
                                    end
                                end
                            end
                            % store the signs for each filter
                            csFunctions{iFilter} = sString(miSigns);
                            
                            % check the strings for numbers or empty
                            % strings
                            mbRemove = false(length(csStrings),1);
                            
                            iAddedDigits = 0;
                            iVariable    = 1;
                            for iString = 1:length(csStrings)
                                csStringForCheck = strrep(csStrings{iString},'.','');
                                if isempty(csStringForCheck)
                                    % this variable is set to true for all
                                    % fields that do not contain log
                                    % variables!
                                    mbRemove(iString) = true;
                                elseif isstrprop(csStringForCheck,'digit')
                                    % this variable is set to true for all
                                    % fields that do not contain log
                                    % variables!
                                    mbRemove(iString) = true;
                                    
                                    % constant numbers used in the
                                    % calculation are added to the csSigns
                                    % cell array in between the signs where
                                    % they are located
                                    A = csFunctions{iFilter}(1:iString+iAddedDigits-1);
                                    B = csStrings{iString};
                                    C = csFunctions{iFilter}(iString+iAddedDigits:end);
                                    
                                    csFunctions{iFilter} = [A,B,C];
                                    
                                    % if multiply constant numbers are used
                                    % we have to track the added digits!
                                    iAddedDigits = iAddedDigits + length(csStrings{iString});
                                else
                                    % in this case the location actually
                                    % uses a log value as variable, in this
                                    % case an x is added to indicate this
                                    
                                    A = csFunctions{iFilter}(1:iString+iAddedDigits-1);
                                    B = [' x', num2str(iVariable), ' '];
                                    C = csFunctions{iFilter}(iString+iAddedDigits:end);
                                    
                                    csFunctions{iFilter} = [A,B,C];
                                    
                                    % if multiply constant numbers are used
                                    % we have to track the added digits!
                                    iAddedDigits = iAddedDigits + length([' x', num2str(iVariable), ' ']);
                                    iVariable    = iVariable + 1;
                                end
                            end
                            % and store the actual labels for each filter
                            csFilterNew{iFilter} = csStrings(~mbRemove);

                        else
                            % if no calculations is used the new filter is the
                            % same as the old and the signs are empty
                            csFunctions{iFilter} = 'x1';
                            csFilterNew{iFilter} = csFilter{iFilter};
                        end
                    end
                    % now order the seperated new filter fields into one new
                    % cell array that can be used to get the log values!
                    iCell = 1;
                    csFilter = cell(1,length(csFilterNew)*length(csFilterNew));
                    for iFilter = 1:length(csFilterNew)
                        for iNewFilter = 1:length(csFilterNew{iFilter})
                            try
                                csFilter{iCell} = csFilterNew{iFilter}{iNewFilter};
                            catch
                                csFilter{iCell} = csFilterNew{iFilter};
                            end
                            iCell = iCell + 1;
                        end
                    end
                    % now we can set the seperated fields into the filter
                    % struct
                    if strcmp(csFields{iField}, 'sLabel')
                        tFilter.(csFields{iField}) = csFilter;
                    end

                    % the sign cell array will be added to the tPlot struct to
                    % perform the calculations during the actual plotting!
                    aiIdx = oLogger.find(xDataReference, tFilter);

                    % We only add a plot if there will actually be anything to
                    % plot. If there isn't, we tell the user. 
                    if ~isempty(aiIdx)
                        this.tPlots(end + 1) = struct('sTitle', sTitle, 'aiIdx', aiIdx, 'txCustom', txCustom, 'csFunctions', []);
                        % before we add the functions to the plot struct we
                        % remove all empty fields
                        mbRemoveFunction = false(1,length(csFunctions));
                        for iFunction = 1:length(csFunctions)
                            if isempty(csFunctions{iFunction})
                                mbRemoveFunction(iFunction) = true;
                            end
                        end
                        if strcmp(csFields{iField}, 'sLabel')
                            this.tPlots(end).csFunctions = csFunctions(~mbRemoveFunction);
                        end
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
                    
                    % Then we check if any calculations have to be
                    % performed on the values and create a new data matrix
                    % in case any calculations are performed
                    iCurrentLog = 1;
                    iCalculations = length(this.tPlots(iPlot).csFunctions);
                    if iCalculations > 0
                        
                        mfDataNew = zeros(length(mfData),iCalculations);
                        
                        iDataVariable = 1;
                        % loop through the calculations (defined by the
                        % number of entries in the csSigns cell array for
                        % this plot)
                        for iCalculation = 1:iCalculations

                            sFunction = this.tPlots(iPlot).csFunctions{iCalculation};
                            
                            % the first step is to perform the calculation
                            % is to find out how many variables exist
                            iVariables = sum(sFunction == 'x');
                            csVariables = cell(1,iVariables);
                            cmfData     = cell(1,iVariables);
                            
                            for iVariable = 1:iVariables
                                if iVariable == 1
                                    csVariables{iVariable} = ['x',num2str(iVariable)];
                                else
                                    csVariables{iVariable} = [',x',num2str(iVariable)];
                                end
                                cmfData{iVariable}     = mfData(:,iDataVariable);
                                
                                iDataVariable = iDataVariable + 1;
                            end
                            
                            % we have to replace the multiplication and
                            % division operators with the element wise
                            % operators
                            sFunction = strrep(sFunction,'*','.*');
                            sFunction = strrep(sFunction,'/','./');
                            sFunction = strrep(sFunction,'^','.^');
                            
                            % Since inline function is supposed to be
                            % removed we use the anonymus function, where
                            % the completed handle has to be created as one
                            % string
                            str = ['@(',csVariables{:},') ',sFunction];
                            
                            % now transform this string into a function
                            % handle that can be used to calculate the new
                            % log values
                            hFunction = str2func(str);

                            mfDataNew(:,iCalculation) = hFunction(cmfData{:});
                            
                            % now we try to find a good description for the
                            % value (taken from the common words of all log
                            % values!)
                            splitphrases_cell = cell(iVariables,1);
                            
                            % loop through the variables in this calculation
                            for iVariable = 1:iVariables
                                
                                % split the label for this calculation 
                                splitphrases_cell{iVariable}    = regexp(tLogProps(iCurrentLog).sLabel, '\s+', 'split');
                                
                                iCurrentLog = iCurrentLog + 1;
                            end
                            
                            mbCommonWords = true(1,length(splitphrases_cell{1}));
                            for iPhrase = 1:(length(splitphrases_cell)-1)

                                mbCommon = strcmp(splitphrases_cell{iPhrase}, splitphrases_cell{iPhrase+1});

                                mbCommonWords = ((mbCommonWords + mbCommon) == 2);

                            end

                            tLogProps(iCalculation).sLabel = strjoin(splitphrases_cell{1}(mbCommonWords));

                        end
                        tLogProps(iCalculations+1:end) = [];
                        mfData = mfDataNew;
                    end
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
                    
                    csLineStyle = [];
                    % Now we chech the txCustom struct for any
                    % customization options that the user defined that have
                    % to be done before the plot
                    if ~isempty(this.tPlots(iPlot).txCustom)
                        csCustomFields = fieldnames(this.tPlots(iPlot).txCustom);
                        
                        for iCustomField = 1:length(csCustomFields)
                            switch csCustomFields{iCustomField}
                                % Now we check if the figure is intended as subplot. The
                                % subplot position is defined by mbPosition which has only
                                % one boolean true at the intended position of the plot.
                                % For example the matrix:
                                % 0 0 0
                                % 0 1 0
                                % 0 0 0
                                % would define the subplot in the middle of a 3x3 field of
                                % subplots
                                case 'mbPosition'
                                    if ~isempty(this.tPlots(iPlot).txCustom.mbPosition)
                                        % The boolean matrix has to be translated into the
                                        % required inputs for the subplot command, which is the
                                        % total row and line number and the number of the
                                        % subplot (which are counted from the top left to right
                                        % in each row and then from top to bottom for several
                                        % rows)
                                        [iNumberRows, iNumberColumns] = size(this.tPlots(iPlot).txCustom.mbPosition);
                                        [iRow, iColumn] = find(this.tPlots(iPlot).txCustom.mbPosition);
                                        iPlotNumber = ((iRow - 1)*iNumberColumns) + iColumn;
                                        subplot(iNumberRows,iNumberColumns,iPlotNumber)
                                    end
                                    
                                case 'csLineStyle'
                                    if ~isempty(this.tPlots(iPlot).txCustom.csLineStyle)
                                        csLineStyle = this.tPlots(iPlot).txCustom.csLineStyle;
                                    end
                            end
                        end
                    end
                    
                    % In order to allow the user to define the desired time
                    % output the actual plotting checks for the sTimeUnit
                    % string and transforms the log (which is always in
                    % seconds) into the desired time unit and sets the correct
                    % legend entry
                    switch sTimeUnit
                        case 's'
                            iDivider = 1;
                        case 'min'
                            iDivider = 60;
                        case 'h'
                            iDivider = 3600;
                        case 'd'
                            iDivider = 86400;
                        case 'weeks'
                            iDivider = 604800;
                    end
                    
                    if ~isempty(csLineStyle)
                        for iLineStyle = 1:length(csLineStyle)
                            plot((oLogger.afTime./iDivider), mfData(:,iLineStyle), csLineStyle{iLineStyle})
                            grid on
                            hold on
                        end
                        miSize = size(mfData);
                        if length(csLineStyle) < miSize(2)
                            plot((oLogger.afTime./iDivider), mfData(iLineStyle+1:end));
                            grid on
                            hold on
                        end
                    else
                        plot((oLogger.afTime./iDivider), mfData)
                        grid on
                        hold on
                    end
                    
                    % First we set the standard values for the fields:
                    sLabelX = ['Time in ', sTimeUnit];
                   	sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                    csLegend = {};
                    for iP = 1:length(tLogProps)
                        csLegend{end + 1} = [ tLogProps(iP).sLabel ];
                    end
                    % Now we chech the txCustom struct for any
                    % customization options that the user defined that have
                    % to be done after the plot
                    if ~isempty(this.tPlots(iPlot).txCustom)
                        csCustomFields = fieldnames(this.tPlots(iPlot).txCustom);
                        
                        for iCustomField = 1:length(csCustomFields)
                            switch csCustomFields{iCustomField}
                                case 'sXLabel'
                                    if ~isempty(this.tPlots(iPlot).txCustom.sYLabel)
                                        sLabelX = this.tPlots(iPlot).txCustom.sXLabel;
                                    end
                                case 'sYLabel'
                                    if ~isempty(this.tPlots(iPlot).txCustom.sYLabel)
                                        sLabelY = this.tPlots(iPlot).txCustom.sYLabel;
                                    end
                                case 'sTitle'
                                    if ~isempty(this.tPlots(iPlot).txCustom.sTitle)
                                        title(this.tPlots(iPlot).txCustom.sTitle);
                                    end
                                case 'csLegend'
                                    if ~isempty(this.tPlots(iPlot).txCustom.csLegend)
                                        csLegend = this.tPlots(iPlot).txCustom.csLegend;
                                    end
                                case 'miXTicks'
                                    if ~isempty(this.tPlots(iPlot).txCustom.miXTicks)
                                        xticks( this.tPlots(iPlot).txCustom.miXTicks );
                                    end
                                case 'miYTicks'
                                    if ~isempty(this.tPlots(iPlot).txCustom.miYTicks)
                                        yticks( this.tPlots(iPlot).txCustom.miYTicks );
                                    end
                                case 'mfXLimits'
                                    if ~isempty(this.tPlots(iPlot).txCustom.mfXLimits)
                                        xlim( this.tPlots(iPlot).txCustom.mfXLimits );
                                    end
                                case 'mfYLimits'
                                    if ~isempty(this.tPlots(iPlot).txCustom.mfYLimits)
                                        ylim( this.tPlots(iPlot).txCustom.mfYLimits );
                                    end
                            end
                        end
                    end
                    
                    xlabel( sLabelX );
                    ylabel( sLabelY );
                    
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

