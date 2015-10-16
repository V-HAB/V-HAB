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
            this.definePlotWithFilter([], sFilter, sTitle);
        end
        
        
        function definePlotWithFilter(this, xDataReference, sFilter, sTitle)
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            if isstruct(xDataReference)
                xDataReference = simulation.monitors.logger_basic.getIndicesFromStruct(xDataReference);
            end
            
            
            % Filter is by unit
            tFilter = struct();
            
            if nargin >= 3 && ~isempty(sFilter)
                tFilter.sUnit = sFilter;
            end
            
            
            aiIdx = oLogger.find(xDataReference, tFilter);
            
            this.tPlots(end + 1) = struct('sTitle', sTitle, 'aiIdx', aiIdx);
            
            
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
        function plot(this)
            oInfra  = this.oSimulationInfrastructure;
            iFig    = figure();
            iPlots  = length(this.tPlots) + 1;
            iGrid   = ceil(sqrt(iPlots));
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            
            % Rows of grid - can we reduce?
            iGridRows = iGrid;
            
            while iGrid * (iGridRows - 1) >= iPlots
                iGridRows = iGridRows - 1;
            end
            
            
            for iP = 1:length(this.tPlots)
                hHandle = subplot(iGridRows, iGrid, iP);
                
                [ mfData, tLogProps ] = oLogger.get(this.tPlots(iP).aiIdx);
                
                %TODO ... well, differently ;)
                sLabelY = this.getLabel(oLogger.poUnitsToLabels, tLogProps);
                
                this.generatePlot(hHandle, oLogger.afTime, mfData, tLogProps, sLabelY);
                
                title(hHandle, this.tPlots(iP).sTitle);
            end
            
            
            hHandle = subplot(iGridRows, iGrid, iP + 1);
            this.generatePlot(hHandle, 1:length(oLogger.afTime), oLogger.afTime, struct('sLabel', 'Time', 'sUnit', 's'), 'Time Steps');
            
            
            set(iFig, 'name', [ oInfra.sName ' - (' oInfra.sCreated ')' ]);
            % Maximize figure ...?
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
        
        
        
        function getIndicesFromStruct(tData)
            csKeys = fieldnames(tData);
            aiIdx  = [];
            
            for iK = 1:length(csKeys)
                sKey = csKeys{iK};
                
                if isstruct(tData.(sKey))
                    aiIdx = [ aiIdx simulation.monitors.logger_basic.getIndicesFromStruct(tData.(sKey)) ];
                else
                    aiIdx(end + 1) = tData.(sKey);
                end
            end
        end
    end
end

