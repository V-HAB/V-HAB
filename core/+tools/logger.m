classdef logger < event.source
    %LOGGER Summary of this class goes here
    %   Detailed explanation goes here
    
    
    properties (GetAccess = public, Constant)
        MESSAGE = 1;
        INFO    = 2;
        NOTICE  = 3;
        WARN    = 4;
        ERROR   = 5;
        
        IDX_TO_CHAR = [ 'M', 'I', 'N', 'W', 'E' ];
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Logging globally off?
        bOff = true;
        
        % Create stack for each call?
        bCreateStack = false;
        
        % Collect instead of .trigger?
        bCollect = false;
        
        
        tCollection = struct('oObj', {}, 'iLevel', {}, 'iVerbosity', {}, 'sIdentifier', {}, 'sMessage', {}, 'cParams', {});
        
        
        % Manually manage bind/trigger stuff. When a 'client' binds to the
        % logger, a filter callback can be provided. This callback could
        % e.g. map the object sending the log message to a simulation
        % container and accordingly filter out all messages from objects
        % not belonging to a specific simulation container.
        % The result of this process is cached by UUID, so the filter
        % callback is only executed once for each object
        %NOTE for now, only ONE 'client' can handle messages from an object
        %     meaning that the search is stopped as soon as one filter
        %     callback returned true (end to start, i.e. later added
        %     callbacks take precedence).
        chCallbacks = {};
        chFilters   = {};
        coHandlers  = {};
        
        tiUuidsToCallback = struct();
    end
    
    
    
    methods
        function output(this, oObj, iLevel, iVerbosity, sIdentifier, sMessage, cParams)
            % Globally off? Don't do nothing!
            if this.bOff, return; end;
            
            
            % Objects are mapped to callbacks - if no mapping, don't do
            % anything. Objs register on logger in base constructor, so the
            % entry on tiUuidsToCallback must exist!
            %TODO throw if empty?
            if isempty(this.tiUuidsToCallback.(oObj.sUUID))
                return;
            end
            
            hCallBack = this.tiUuidsToCallback.(oObj.sUUID);
            
            % Get caller method name from stack
            tStack   = dbstack(2);
            csMethod = strsplit(tStack(1).name, '.');
            
            tPayload = struct(...
                'oObj',         oObj, ...
                'iLevel',       iLevel, ...
                'iVerbosity',   iVerbosity, ...
                'sMethod',      csMethod{2}, ...
                'sIdentifier',  sIdentifier, ...
                'sMessage',     sMessage, ...
                'tStack',       [], ...
                'cParams',      { cParams } ...
            );
            
            
            if this.bCreateStack
                tPayload.tStack = dbstack(2, '-completenames');
            end
            
            if this.bCollect
                this.tCollection(end + 1) = tPayload;
            else
                hCallBack(tPayload);
            end
        end
        
        
        function flush(this)
            if isempty(this), return; end;
            
            this.bOff = true;
            
            this.chCallbacks = {};
            this.chFilters   = {};
            this.coHandlers  = {};
            
            this.tiUuidsToCallback  = struct();
            
            this.bCollect    = false;
            this.tCollection = struct('oObj', {}, 'iLevel', {}, 'iVerbosity', {}, 'sIdentifier', {}, 'sMessage', {}, 'cParams', {});
        end
        
        
        function iId = bind(this, hCallBack, hFilterFct, oHandlerObj)
            this.chCallbacks{end + 1} = hCallBack;
            this.chFilters{end + 1}   = hFilterFct;
            this.coHandlers{end + 1}  = oHandlerObj;
            
            iId = length(this.chCallbacks);
        end
        
        function unbind(this, iId)
            this.chCallbacks(iId) = [];
            this.chFilters(iId)   = [];
            this.coHandlers(iId)  = [];
        end
        
        
        function add(this, oObj)
            % No callback - obj known but messages will never be logged.
            %TODO what if callback added AFTER object? On .bind, check all
            %     already existing objs?
            this.tiUuidsToCallback.(oObj.sUUID) = [];
            
            %TODO include default logger, if non matches ... output where? 
            %     oLogger (i.e. `this`) object attribute?
            for iC = length(this.chCallbacks):-1:1
                if ~this.chFilters{iC}(oObj)
                    continue;
                end
                
                this.tiUuidsToCallback.(oObj.sUUID) = this.chCallbacks{iC};
                
                %fprintf('Adding %s (%s) to handler %s (sim infra created: %s)\n', ...
                %    oObj.sEntity, oObj.sUUID, this.coHandlers{iC}.sUUID, this.coHandlers{iC}.oSimulationInfrastructure.sCreated);
                
                break;
            end
        end
        
        
        function this = setOutputState(this, bOutput)
            this.bOff = ~bOutput;
        end
        
        function this = toggleOutputState(this)
            this.bOff = ~this.bOff;
        end
        
        function this = setCreateStack(this, bCreateStack)
            this.bCreateStack = ~~bCreateStack;
        end
        
        function this = toggleCreateStack(this)
            this.bCreateStack = ~this.bCreateStack;
        end
        
        
        
        %TODO setCollect on true directly in sim infra/vhab.exec, then when
        %     console_out has initialized -> set to false and process all
        %     queued messages!
        function setCollect(this, bCollect)
            if this.bCollect && ~bCollect
                % Was on collect, now set to false --> flush queue!
                
                for iMsg = 1:length(this.tCollection)
                    tPayload = this.tCollection(iMsg);
                    oObj     = tPayload.oObj;
                    
                    if ~isempty(this.tiUuidsToCallback.(oObj.sUUID))
                        this.tiUuidsToCallback.(oObj.sUUID)(tPayload);
                    end
                end
                
                this.tCollection = struct('oObj', {}, 'iLevel', {}, 'iVerbosity', {}, 'sIdentifier', {}, 'sMessage', {}, 'cParams', {});
            end
            
            
            this.bCollect = bCollect;
        end
    end
    
end

