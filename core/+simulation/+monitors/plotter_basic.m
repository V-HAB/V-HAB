classdef plotter_basic < simulation.monitor
    %PLOTTER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Name of log monitor
        sLogger = 'oLogger';
        
        tPlots = struct('sTitle', {}, 'aiIdx', {});
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
            oInfra  = this.oSimulationInfrastructure;
            oFigure = figure();
            iPlots  = length(this.tPlots) + 1;
            iGrid   = ceil(sqrt(iPlots));
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            bLegendOn = true;
            
            if nargin > 1 && isfield(tParameters, 'bLegendOn')
                bLegendOn = tParameters.bLegendOn;
            end
            
            
            % Rows of grid - can we reduce?
            iGridRows = iGrid;
            iGridCols = iGrid;
            
            %while iGridCols * (iGridRows - 1) >= iPlots
            %    iGridRows = iGridRows - 1;
            %end
            while (iGridCols - 1) * iGridRows >= iPlots
                iGridCols = iGridCols - 1;
            end
            
            
            for iP = 1:length(this.tPlots)
                hHandle = subplot(iGridRows, iGridCols, iP);
                
                [ mfData, tLogProps ] = oLogger.get(this.tPlots(iP).aiIdx);
                
                %TODO ... well, differently ;)
                sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                
                this.generatePlot(hHandle, oLogger.afTime, mfData, tLogProps, sLabelY);
                
                title(hHandle, this.tPlots(iP).sTitle);
                
                if ~bLegendOn
                    legend('hide');
                end
            end
            
            
            hHandle = subplot(iGridRows, iGridCols, iP + 1);
            hold(hHandle, 'on');
            grid(hHandle, 'minor');
            plot(1:length(oLogger.afTime), oLogger.afTime);
            xlabel('Ticks');
            ylabel('Time in s');
            title(hHandle, 'Evolution of Simulation Time vs. Simulation Ticks');
            
            
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
            
            % Maximize figure
            set(gcf, 'units','normalized','OuterPosition', [0 0 1 1]);
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

