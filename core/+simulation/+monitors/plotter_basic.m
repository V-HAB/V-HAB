classdef plotter_basic < simulation.monitor
    %PLOTTER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Name of log monitor
        sLogger = 'oLogger';
    end
    
    methods
        function this = plotter_basic(oSimulationInfrastructure, sLogger)
            %TODO register on pause, finish, show hints/help?
            this@simulation.monitor(oSimulationInfrastructure);%, { 'finish', 'pause' });
            
            if nargin >= 2 && ~isempty(sLogger)
                this.sLogger = sLogger;
            end
        end
        
        
        
        function definePlot(this, xDataReference)
            this.definePlotWithFilter(xDataReference);
        end
        
        function definePlotAllWithFilter(this, sFilter)
            this.definePlotWithFilter([], sFilter);
        end
        
        function definePlotWithFilter(this, xDataReference, sFilter)
            oLogger = this.oSimulationInfrastructure.toMonitors.(this.sLogger);
            
            if isstruct(xDataReference)
                xDataReference = simulation.monitors.logger_basic.getIndicesFromStruct(xDataReference);
            end
            
            
            % Filter is by unit
            tFilter = struct();
            
            if nargin >= 3 && ~isempty(sFilter)
                tFilter.sUnit = sFilter;
            end
            
            
            [ mfLogData, tLogProps ] = oLogger.get(xDataReference, tFilter);
            
            
            disp('=========================== PLOT =====================');
            disp(xDataReference);
            disp(sFilter);
            
            for iS = 1:length(tLogProps)
                disp('---------');
                disp(tLogProps(iS));
            end
        end
        
    end
    
    
    methods (Static)
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

