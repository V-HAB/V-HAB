classdef base < handle
    %BASE Base handle obj class
    %   Sets uuid, meta class, type usw
    %
    %NOTE prefixes:
    %   i = integer, f = float, r = ratio (percent), s = string, b = bool
    %   a = array, m = matrix, c = cell, t = struct
    %   o = object, h = handle (file, graphics, function, ...), p = map
    %   x = mixed / undef
    %
    %   "Awesome" when mixed, e.g. taiSomething would be a struct, with 
    %   each field holding an array of integers.
    %   For a struct with non-uniform values, the key should contain the
    %   prefix, e.g. tSomething and then tSomething.fVal, tSomething.sName
    %   (the tSomething could also be named txSomething - more clear).
    %   Struct-hierarchy e.g. ttxMatter - each field of main struct
    %   contains another struct (or several?), with mixed values (the x
    %   specifically says mixed values, could be omitted since in this
    %   example (from @matter.table), the values are containing the prefix,
    %   e.g. fMolarMass).
    %
    %TODO (branch/feature logging, nevermind)
    %   - inf (done at the moment in vhab - replaced with 'null')
    %
    %   1) dump, uri download, event reg, socket, cmd exchange console node
    %       -> each as own module in tools.base.* (later some URI)
    %       -> .base cfg which are used and configuration for them (e.g.
    %          dump frequency & data to append, socket port, event listen-
    %          ers (e.g. call 'dump' on 'tick.post' on objs class 'timer')
    %   2) add @uri, @version (timer fTime) on dump (also cfg-able in .base)?
    %       prefix 'localhost' (or '127.0.0.1') on dump, so it can be replaced in vhab.m by actual host?
    %   3) check - print 'pause?' -> pause(0.1) -> node writes cmd to cons?
    
    
    %% Static methods/attrs - helpers etc %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Section covers stuff needed for logging - ignore!
    properties (GetAccess = private, Constant)
        % Handle object -> exactly one instance created as soon as the base
        % class becomes available within the Matlab path. Contains infos
        % about the different classes, etc.
        % Also used to handle serialization, stores references to all
        % created objects of all classes derived from base.
        pDumper = containers.Map({ 'bSerialize', 'coSerializers', 'poSerializers', 'aiSerializers', 'csSerialized' }, { false, {}, containers.Map(), 0, {} });
        
        
    end
    
    
    properties (GetAccess = public, Constant)
        % Registered loggers
        oLog = tools.logger();
        
        
        % Attributes for socket connection
        %NOTE not used right now, dumps directly to console / stdout
        %sHost = '127.0.0.1';
        %iPort = 65433;
        
        %TODO
        %   - constructor -> check this.oCO.rxCfg(this.sBase)
        %       --> with doc(), MetaClass etc create Schema (see old .js /
        %       XML / genMetaDef) --> @type, @default etc
        %       --> base a mixin, .serialized() sealed --> aoAllObjs.serialize()?
    end
    
    methods (Static = true)
        function randomUUID(~)
            %RANDOMUUID [removed, use |tools.getPseudoUUID()| instead]
            this.throw('base::randomUUID', '|base.randomUUID()| has been removed. Use |tools.getPseudoUUID()| instead.');
        end
    end
    
 % Section covers stuff needed for logging - ignore!
    methods (Static = true)
        
        function activateSerializers()
            pDumper = base.pDumper;
            
            pDumper('bSerialize') = true;
        end
        
        function flush()
            pDumper = base.pDumper;
            aiSerializers = pDumper('aiSerializers');
            coSerializers = pDumper('coSerializers');
            poSerializers = pDumper('poSerializers');
            
            %poSerializers.remove(poSerializers.keys());
            %return;
            
            for iS = aiSerializers
                if iS < 1, continue; end;
                
                %delete(coSerializers{iS});
                coSerializers{iS}.flush();
                delete(coSerializers{iS});
            end
            
            %poSerializers.remove(poSerializers.keys());
            
            
            
            base.oLog.flush();
            %delete(base.oLog);
        end
        
        
        function sJSON = dump()
            % Past/future - dump to socket; right now - just return!
            
            %return;
            
            pDumper = base.pDumper;
            aiSerializers = pDumper('aiSerializers');
            coSerializers = pDumper('coSerializers');
            csSerialized  = pDumper('csSerialized');
            
            for iS = aiSerializers
                coSerializers{iS}.serialize();
                
                csSerialized{iS} = [ coSerializers{iS}.csSerialized{:} ];
            end
            
            pDumper('csSerialized') = csSerialized;
            
            %dd = int8([ '<' tools.JSON.dump(cSerialized) '>' ]);
            %dd = tools.JSON.dump(cSerialized);
            sJSON = [ csSerialized{:} ];
            sJSON = [ '{' sJSON(1:(end - 1)) '}' ];
            %disp([ '{' sS(1:(end - 1)) '}' ]);
            
            
            
            %if isempty(base.oCO.oSocket), base.createSocket(); end;
            
            %tools.net.jtcp('write', base.oCO.oSocket, int8([ '<' tools.JSON.dump(ptObjs) '>' ]))
        end
        
        
        function oObj = getObj(sUrl)
            sBaseUrl     = sUrl(1:(find(sUrl == '/', 1, 'last' ) - 1));
            sPath        = sBaseUrl((find(sBaseUrl == '/', 1, 'first') + 1):end);
            sId          = sUrl((find(sUrl == '/', 1, 'last') + 1):end);
            pDumper      = base.pDumper;
            pSerializers = pDumper('poSerializers');
            oObj         = [];
            sPath        = strrep(sPath, '/', '.');
            
            if pSerializers.isKey(sPath)
                oSer = pSerializers(sPath);
                iIdx = find(strcmp({ oSer.aoObjects.sURL }, sUrl((find(sUrl == '/', 1, 'first')):end)));
                
                if ~isempty(iIdx)
                    oObj = oSer.aoObjects(iIdx(1));
                end
            end
        end
        
        
        % Kind of 'static' events (i.e. bound to the class, not the object)
        function [ oObj, iId ] = signal(sSignal, varargin)
            oObj = '';
            iId  = [];
            
            if strcmp(sSignal, 'log')
                iId = base.oLog.bind(varargin{:});
                
                oObj = base.oLog;
            end
        end
    end
    
    
    methods (Static = true, Access = private)
        
        function createSocket(this)
            % If socket's not initialized, create one
            %TODO check if still exists? connection lost or so?
%             if isempty(base.oCO.oSocket)
%                 base.oCO.oSocket = this.net.jtcp('request', base.sHost, base.iPort, 'serialize', false);
%             end
        end
    end
    
    
    
    %% Attributes and constructor %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (SetAccess = private, GetAccess = public)
        % Reference to meta class and package/class path
        oMeta;
        sURL;
        
        % Unique id for object instance, class name
        sUUID;
        sEntity;
    end
    
    
    methods
        function this = base()
            
            %NOTE for e.g. vsys, base constructor called several times, as
            %     every parent class does eventually call the base
            %     constructor. So if oMeta, sEntity, sUUID already set -
            %     don't do anything in here.
            if ~isempty(this.sUUID)
                return;
            end
            
            
            %TODO should only do that once, probably? Or Matlab smart enough to only create the metaclass instance once?
            %      remove oMeta, sEntity and sURL, just leave uuid? Wouldn't be needed anyways (type checks done with isa() etc ...) and just store in dumper/vhab static class?
            this.oMeta   = metaclass(this);
            this.sEntity = this.oMeta.Name;
            
            this.sUUID = tools.getPseudoUUID();
            
            % URL - used as identification for logging
            %CHECK prefix something like localhost?
            this.sURL = [ '/' strrep(this.sEntity, '.', '/') '/' this.sUUID ];
            
            
            
            
            % Adding this object to the logger
            if ~isa(this, 'tools.logger')
                base.oLog.add(this);
            end
            
            
            
            
            % Matlab sometime acts weird when accessing static attributes that are handle objects ...
            % This way it normally works (see last two lines of method)
            pDumper = this.pDumper;
            
            % Should we initialize the serializer?
            if ~pDumper('bSerialize'), return; end;
            
            poSerializers = pDumper('poSerializers');
            coSerializers = pDumper('coSerializers');
            
            if ~poSerializers.isKey(this.sEntity)
                % New serializer for this class
                poSerializers(this.sEntity) = tools.serializer(this.oMeta);
                coSerializers{end + 1}      = poSerializers(this.sEntity);
            end
            
            oSerializer = poSerializers(this.sEntity);
            oSerializer.addObj(this);
            
            
            pDumper('coSerializers') = coSerializers;
            pDumper('aiSerializers') = 1:length(coSerializers);
            
            
        end
        
        function tObj = serialize(this)
            % Serialize object, returns a struct with the serialized object
            % attributes. If an object attribute contains another object
            % that is derived from 'base', replaced by sURL.
            %tObj = base.oCO.poSerializers(this.sEntity).serialize(this);
        end
        
%         function delete(this)
%             poObjects     = this.poObjects;
%             poObjects.remove(this.sUUID);
%         end
        
    end
    
    methods (Access = protected)
        %% LOG/DEBG HANDLING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function this = out(this, varargin)
            % This function can be used to output debug/log info. The
            % minimal function call is:
            % this.out('Some debug message');
            % 
            % Optionally, an identifier and sprintf parameters can be
            % provided:
            % this.out('section-identifier', 'Some %s (%i)', { 'asd', 1 });
            %
            % Two parameters exist to determine the log level and verbosity
            % of the message. Default log levels are 1 (MESSAGE), 2 (INFO),
            % 3 (NOTICE), 4 (WARN) and 5 (ERROR).
            % Independently of the log level, the verbosity describes how
            % much information was passed, for example:
            % this.out(4, 1, 'inputs', 'Param X out of bounds');
            % this.out(4, 2, 'inputs', 'Additional info, e.g. limits for param X, current value, ...');
            % this.out(4, 2, 'inputs', 'Other relevant variables, e.g. if param X based on those.');
            % this.out(4, 3, 'inputs', 'Even more ...');
            % 
            % Using the methods in the console_output simulation monitor,
            % the minimum level for a message to be displayed, and the
            % maximum verbosity can be set. Both values do not have an
            % upper limit, i.e. one could call this.out(100, 'my msg') and 
            % set oLastSimObj.toMonitors.oConsoleOutput.setLevel(100);
            %
            % For any log messages to be shown, logging has to be activated
            % with oLastSimObj.toMonitors.oConsoleOutput.setLogOn(). If the
            % parameters generated for this.out are more complex, i.e.
            % consume time, the global logging flag can be checked:
            % if ~base.oLog.bOff, (... prepare params and call .out() ...)
            %
            % The console output monitor contains various methods to filter
            % the logging output:
            % 
            %   oOut = oLastSimObj.toMonitors.oConsoleOutput;
            %   
            %   % Filter by method name (where the .out() happened)
            %   oOut.addMethodFilter('massupdate')
            %   
            %   % First string param to .out (myMethod in example above)
            %   oOut.addIdentFilter('inputs')
            %   
            %   % Filter by sEntity object value (e.g. matter.phases.gas)
            %   oOut.addTypeToFilter('matter.phases.gas');
            %
            %   % Others: addPathToFilter -> by obj path, addUuidFilter
            %   
            %   % Reset -> oOut.reset*Filters
            %   %   * = Uuid, Paths, Types, Ident
            % 
            % For each filter, several values can be set. If none set,
            % filter not active.
            %
            % Finally, the stack for each log call can be shown/hidden:
            %   oOut.toggleShowStack();
            
            
            % Flag to globally switch off logging!
            if base.oLog.bOff, return; end;
            
            
            % varargin:
            % [iLevel, [iVerbosity, ]][sIdentifier, ]sMessage[, cParams]
            
            % Minimal call = just sMessage!
            
            iElem     = 1;
            iElemsMax = nargin - 1;
            
            % iLevel and iVerbosity are optional. Therefore check first two
            % elems of varargin for numeric types.
            if isnumeric(varargin{iElem})
                iLevel = varargin{iElem};
                iElem  = iElem + 1;
                
                % If iLevel was provided, there HAS to be another elem in
                % varargin - at least sMessage!
                if isnumeric(varargin{iElem})
                    iVerbosity = varargin{iElem};
                    iElem      = iElem + 1;
                else
                    iVerbosity = 1;
                end
            else
                iLevel     = 1;
                iVerbosity = 1;
            end
            
            
            
            % Now check if current AND next elem are strings - if yes,
            % thats sIdentifier and sMessage. Else, that'd be sMessage and
            % cParams!
            if iElemsMax >= (iElem + 1) && ischar(varargin{iElem}) && ischar(varargin{iElem + 1})
                sIdentifier = varargin{iElem};
                sMessage    = varargin{iElem + 1};
                iElem       = iElem + 2;
            else
                sIdentifier = '';
                sMessage    = varargin{iElem};
                iElem       = iElem + 1;
            end
            
            
            if iElemsMax >= iElem && iscell(varargin{iElem})
                cParams = varargin{iElem};
            else
                cParams = {};
            end
            
            
            % All params collected, pass to logger which triggers an event.
            base.oLog.output(this, iLevel, iVerbosity, sIdentifier, sMessage, cParams);
        end
        
        
        %% ERROR HANDLING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function throw(this, sIdent, sMsg, varargin)
            % Wrapper for throwing errors - includes path to the class
            
            error([ strrep(this.sURL(2:end), '/', ':') ':' sIdent ], sMsg, varargin{:});
        end
        
        function warn(this, sIdent, sMsg, varargin)
            % See throw
            
            warning([ strrep(this.sURL(2:end), '/', ':') ':' sIdent ], sMsg, varargin{:});
        end
    end
end
