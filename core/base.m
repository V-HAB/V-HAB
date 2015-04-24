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
    %   e.g. fMolMass).
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
                %delete(coSerializers{iS});
                coSerializers{iS}.flush();
            end
            
            %poSerializers.remove(poSerializers.keys());
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
            %TODO should only do that once, probably? Or Matlab smart enough to only create the metaclass instance once?
            %      remove oMeta, sEntity and sURL, just leave uuid? Wouldn't be needed anyways (type checks done with isa() etc ...) and just store in dumper/vhab static class?
            this.oMeta   = metaclass(this);
            this.sEntity = this.oMeta.Name;
            
            this.sUUID = tools.getPseudoUUID();
            
            % URL - used as identification for logging
            %CHECK prefix something like localhost?
            this.sURL = [ '/' strrep(this.sEntity, '.', '/') '/' this.sUUID ];
            
            
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
        
        function delete(this)
%             poObjects     = this.poObjects;
%             poObjects.remove(this.sUUID);
        end
    end
    
    
    
    
    
    
    %% ERROR HANDLING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods (Access = protected)
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
