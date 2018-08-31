classdef serializer < handle
%SERIALIZER serializes Matlab objects
%
%TODO
%   - need to be able to export definitions (see old db logging test, JSON)
%     including types, parent classes, functions etc (like JSON-schema for the class)
%   - make sure the meta/class inherits from base
%
%TODO conversions
%   - float/int: ifempty -> ...? undefined? null? []? ""?
%   - @matrix -> replace mat2str with more efficient ... something. Possible
%     to define dimensions (or just n/m?) -> speedup (customized sprintf?)?
%   - @cell -> one type, easy. Different types -> each time manual search.
%   - @struct -> completely variable, fixed keys, fixed all possible to
%     configure -> speedups if e.g. fixed (only once) or fixed keys (cache
%     the keys).
%   - string -> "unsafe" version where ", \n and \r are replaced/escaped?
%     Also for cell strings, structs etc ...
%
% SpeedUp:
%   - bUpdate for each obj, lookup this.aoObjs([this.aoObjs.bUpdate]) should be fast?
%   	-> don't dump each obj!
%   - possible to define that attr doesn't change (aoFlows, aoStores, ...)
%   - fixed size vectors etc > can be parsed with one call instead of loop?
%   - put validation functions directly in EVALd string?
%   - no ifempty() in numeric stuff, replace 'zeros(1,0)' afterwards?
%   - for some stuff like floats, group - get from all objects at once?
%   - optimize objects themselves, e.g. iPhases dependent on aoPhases, so
%     put in transient block, same as csProcsP2P etc


    properties (SetAccess = protected, GetAccess = public)
        oMeta;
        
        % Serialized JSON strings
        csSerialized = {};
        
        csAttrs = {};
        tFields = struct();
        
        aoObjects;
        aiObjects;
        
        % Func callback, created with evaluate
        doSerialization;
    end
    
    methods
        function this = serializer(oMeta)
            
            if nargin < 1, return; end
            
            % String provided? Class path!
            if ischar(oMeta)
                oMeta = metaclass(oMeta);
            end
            
            this.oMeta = oMeta;
            %keyboard();
            this.generateSerialization();
            
            
            % Create serialization callback code
            sSep = '';
            csKeys = fieldnames(this.tFields);
            %sEval = '@(oObj) this.writeStruct(struct(';
            sEval = '@(oObj) [';
            
            % For each attribute, code to dump that attribute in a JSON format is crated
            for iI = 1:length(csKeys)
                %sEval = [ sEval sSep '''' csKeys{iI} ''', ' this.tSerialized.(csKeys{iI}) ];
                sEval = strcat(sEval, ' ''', sSep, '"', csKeys{iI}, '":'' ', this.tFields.(csKeys{iI}));
                sSep  = ',';
                
                this.csAttrs{end + 1} = csKeys{iI};
            end
            
            %sEval = [ sEval '))' ];
            sEval = [ sEval ']' ];
            
            % Evaulate code, which is an anonymous function - can now be called w/o any eval etc.
            this.doSerialization = eval(sEval);
            
            %if ~isempty(this.csAttrs), keyboard(); end;
            
%             disp('----');
%             disp(this.oMeta.Name);
%             disp(this.csAttrs);
        end
        
        function addObj(this, oObj)
            if isempty(this.aoObjects)
                this.aoObjects = oObj;
            else
                this.aoObjects(end + 1) = oObj;
            end
            
            this.aiObjects = 1:length(this.aoObjects);
            
            this.csSerialized = cell(length(this.aoObjects), 1);
        end
        
        
        function flush(this)
            this.aoObjects    = [];
            this.aiObjects    = 0;
            this.csSerialized = {};
        end
        
        
        function serialize(this)
            if isempty(this.csAttrs), return; end
            
%             iO = 0;
%             for bU = ([ this.aoObjects.bUpdate ] == true)
%                 iO = iO + 1;
%                 if ~bU, continue; end;
            for iO = this.aiObjects
                this.csSerialized{iO} = [ '"' this.aoObjects(iO).sURL '":{' this.doSerialization(this.aoObjects(iO)) '},' ];
                %[ '"' this.aoObjects(iO).sURL '":{' this.doSerialization(this.aoObjects(iO)) '},' ];
                %dd = this.aoObjects(iO);
                %this.csSerialized{iO} = [ '"' this.aoObjects(iO).sURL '":{' '},' ];
            end
            
        end
    end
    
    %% Create serialization callbacks for the class %%%%%%%%%%%%%%%%%%%%%%%
    methods (Access = private)
        function generateSerialization(this, oMeta)
            % Go through superclasses, call generateSerialization for all
            % superclasses and then parse this class itself
            
            if nargin < 2, oMeta = this.oMeta; end
            
            % Superclasses
            for iI = 1:length(oMeta.SuperclassList)
                if strcmp(oMeta.SuperclassList(iI).Name, 'base'), break; end

                this.generateSerialization(oMeta.SuperclassList(iI));
            end
            
            
            % Properties
            for iI = 1:length(oMeta.PropertyList)
                if (oMeta.PropertyList(iI).DefiningClass == oMeta) && strcmp(oMeta.PropertyList(iI).GetAccess, 'public')   % ~strcmp(oMeta.PropertyList(iI).GetAccess, 'private')
                    this.attributeSerialization(oMeta.PropertyList(iI));
                end
            end
        end
        
        
        function attributeSerialization(this, oProperty)
            % Get doc of attribute, check @type - create serialization
            % function handle
            %TODO check @default and others, include on schema export?
            
            sClass = this.oMeta.Name;
            sName  = oProperty.Name;
            
            % Replace e.g. 'sDumpName' with 'dump_name'
            sDumpName = regexprep(regexprep(sName, '([A-Z])', '_${lower($1)}'), '^[a-z]*_', '');
            
            
            % Use the combined class and attribute name to get the help
            % string produced by Matlab - i.e. the comment right before the
            % attribute containing the configuration
            sDoc    = help([ sClass '.' sName ]);
            csLines = regexp(sDoc, '\n', 'split');
            sType   = [];
            sTypes  = [];
            
            %TODO use regexp!
            for iL = 1:length(csLines)
                sLine = strtrim(csLines{iL});
                
                if (length(sLine) > 6) && strcmp(sLine(1:6), '@types')
                    sTypes = strtrim(sLine(8:end));
                    
                elseif (length(sLine) > 5) && strcmp(sLine(1:5), '@type')
                    sType = strtrim(sLine(7:end));
                end
            end
            
            
            % Create the callback code that dumps the attribute value
            if strcmp(sType, 'object')
                this.tFields.(sDumpName) = [ '''"'' oObj.' sName '.sURL ''"''' ];
                
            elseif strcmp(sType, 'float')
                %this.tFields.(sDumpName) = [ 'this.getNumber(oObj.' sName ')' ];
                this.tFields.(sDumpName) = [ 'sprintf(''%f'', oObj.' sName ')' ];
                
            %TODO-OKT14 should be 'integer'! also support boolean!
            elseif strcmp(sType, 'int')
                this.tFields.(sDumpName) = [ 'sprintf(''%i'', oObj.' sName ')' ];
                
            elseif strcmp(sType, 'array')
                if strcmp(sTypes, 'int')
                    %this.tFields.(sDumpName) = [ 'this.getVectorNumeric(oObj.' sName ')' ];
                    this.tFields.(sDumpName) = [ 'strrep([ ''['' strrep(strrep(sprintf('';%i;'', oObj.' sName '), '';;'', '',''), '';'', '''') '']'' ], ''[,]'', ''[]'')' ];
                
                elseif strcmp(sTypes, 'float')
                    this.tFields.(sDumpName) = [ 'strrep([ ''['' strrep(strrep(sprintf('';%f;'', oObj.' sName '), '';;'', '',''), '';'', '''') '']'' ], ''[,]'', ''[]'')' ];
                
                elseif strcmp(sTypes, 'object')
                    %this.tFields.(sName) = [ 'this.getVectorObjects(oObj.' sName ')' ];
                    %TODO weird, if oObj.(sName) empty (no elements in
                    %     array), sprintf returns ;" ...?
                    this.tFields.(sDumpName) = [ 'strrep(strrep([ ''['' strrep(strrep(sprintf('';"%s";'', oObj.' sName '.sURL), '';;'', '',''), '';'', '''') '']'' ], ''[""]'', ''[]''), ''["]'', ''[]'')' ];
                else
                    error('Unknown array types');
                end
                
            
            %TODO structs - if types == obj etc -> fine!
            %     else ==> nothing yet? i.e. if txSomeStruct ...
            elseif strcmp(sType, 'struct')
                %TODO case one - fixed keys etc
                if strcmp(sTypes, 'object')
                    this.tFields.(sDumpName) = [ 'this.serializeStructValues(structfun(@(oStructObj) oStructObj.sURL, oObj.' sName ', ''UniformOutput'', false))' ];
                
                %TODO case two - just serialize to strings ...
                elseif strcmp(sTypes, 'float')
                    this.tFields.(sDumpName) = [ 'this.serializeStructValues(oObj.' sName ', ''%f'')' ];
                
                elseif strcmp(sTypes, 'int')
                    this.tFields.(sDumpName) = [ 'this.serializeStructValues(oObj.' sName ', ''%i'')' ];
                
                else
                    this.tFields.(sDumpName) = [ 'this.serializeStructValues(oObj.' sName ')' ];
                end
                
                
            elseif strcmp(sType, 'cell')
                if strcmp(sTypes, 'string')
                    this.tFields.(sDumpName) = [ 'strrep([ ''['' strrep(strrep(sprintf('';"%s";'', oObj.' sName '{:}), '';;'', '',''), '';'', '''') '']'' ], ''["]'', ''[]'')' ];
                
                elseif strcmp(sTypes, 'int')
                    this.tFields.(sDumpName) = [ 'strrep([ ''['' strrep(strrep(sprintf('';%i;'', oObj.' sName '{:}), '';;'', '',''), '';'', '''') '']'' ], ''[,]'', ''[]'')' ];
                
                elseif strcmp(sTypes, 'float')
                    this.tFields.(sDumpName) = [ 'strrep([ ''['' strrep(strrep(sprintf('';%f;'', oObj.' sName '{:}), '';;'', '',''), '';'', '''') '']'' ], ''[,]'', ''[]'')' ];
                
                elseif strcmp(sTypes, 'object')
                    %this.tFields.(sName) = [ 'this.getVectorObjects(oObj.' sName ')' ];
                    %TODO eigene methode hier (statisch, private access)
                    %this.tFields.(sName) = [ '[ ''['' strrep(strrep(sprintf(''%s'', cell2mat(cellfun(@(oObjTmp) [ '';"'' oObjTmp.sURL ''";'' ], { oObj.' sName '{:} }, ''UniformOutput'', false))), '';;'', '',''), '';'', '''') '']'' ]' ];
                    this.tFields.(sDumpName) = [ '[ ''['' strrep(strrep(sprintf(''%s'', cell2mat(cellfun(@this.getObjUriForCell, { oObj.' sName '{:} }, ''UniformOutput'', false))), '';;'', '',''), '';'', '''') '']'' ]' ];
                    
                else
                    error('Unknown array types');
                end
                
            %TODO string - atm no escaping - no \n, no " assumed!
            elseif strcmp(sType, 'string') % ~isempty(sType)
                %this.tFields.(sName) = [ 'this.getString(oObj.' sName ')' ];
                %this.tFields.(sName) = [ '''"'' strrep(strrep(strrep(oObj.' sName ', ''"'', ''\"''), tools.serializer.sNewLine, ''\n''), tools.serializer.sReturn, '''') ''"''' ];
                this.tFields.(sDumpName) = [ '''"'' oObj.' sName ' ''"''' ];
                
            elseif ~isempty(sType)
                error('Unknown type');
            end
        end
    end
    
    
    %% Static / Constant properties for serialization stuff %%%%%%%%%%%%%%%
    properties (GetAccess = protected, Constant)
        sNewLine = newline;
        sReturn  = sprintf('\r');
    end
    
    methods (Static = true, Access = protected)
        function sUrl = getObjUriForCell(oTmpObj)
            if ~isempty(oTmpObj)
                sUrl = oTmpObj.sURL;
            else
                sUrl = '';
            end
            
            
            sUrl = [ ';"' sUrl '";' ];
        end
        
        
        function sStruct = serializeStructValues(txStruct, sType)
            %TODO just converts to strings right now ... implement e.g.
            %     float, int, ... structs. For heterogeneous structs,
            %     enforce fixed keys --> parse once in first .dump?
            %     Variable keys only possible for fixed @types?
            %     Use value class for structs with fixed keys ...?
            
            if nargin < 2, sType = '"%s"'; end
            
            cxData  = [ fieldnames(txStruct), struct2cell(txStruct) ]';
            %sStruct = strrep([ '{' sprintf('"%s":"%s",', cxData{:}) '}' ], '{"}', '{}');
            sStruct = sprintf([ '"%s":' sType ',' ], cxData{:});
            sStruct = [ '{' sStruct(1:(end - 1)) '}' ];
        end
    end
    
    
    %% Static methods for serialization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods (Static = true, Access = public)
        function sS = getString(sS)
            
            sS = [ '"' strrep(strrep(strrep(sS, '"', '\"'), tools.serializer.sNewLine, '\n'), tools.serializer.sReturn, '') '"' ];
        end
        
        function sS = getNumber(fS)
            % Scalar!
            
            sS = [ '"' num2str(fS) '"' ];
        end
        
        function sS = getVectorNumeric(axVector)
            % Convert numeric vector to JSON array
            % @type array; @types int, float
            %
            %TODO if col vector, do actually convert to e.g.
            %       [ [1], [2], ...] instead of [1,2,...] ?
            
            if isempty(axVector)
                sS = '[]';
            else
                sS = [ '[' strrep(strrep(sprintf(';%f;', axVector), ';;', ','), ';', '') ']' ];
            end
        end
        function sS = getVectorObjects(aoVector)
            % Convert object vector to JSON array with URLs
            % @type array; @types int, object
            %
            
            if isempty(aoVector)
                sS = '[]';
            else
                sS = [ '"' strjoin({ aoVector.sURL }, '","') '"' ];
            end
        end
        
        function sS = getMatrixNumeric(mxS)
            % Convert matrix with numeric values to an according JSON
            % representation
            % @type matrix; @types int, float
            %
            %TODO char matrix? (@type matrix, @types string)
            
            if isempty(mxS)
                sS = '[]';
            else
                sS = [ '[' strrep(strrep(mat2str(mxS), ';', '],['), ' ', ',') ']' ];
            end
        end
        
        function sS = getMatrixChar(mcMatrix)
            % Convert matrix with char/string values to an according JSON
            % representation
            % @type matrix; @types string
            
            % mat2str wraps ' around chars, might have a '' for escaped '
            % in matrix. So replace "" with ' afterwards.
            if isempty(mcMatrix)
                sS = '[]';
            else
                sS = [ '[' strrep(strrep(strrep(strrep(mat2str(mcMatrix), ';', '],['), ' ', ','), '''', '"'), '""', '''') ']' ];
            end
        end
        
        
        function sS = getCell(cxCell)
            % Convert cell to string representation using JSON arrays. Puts
            % quotes around all elements no matter the content.
            
            %sS = [ '"' mat2str(mxS) '"' ];
        end
        
%         function serialized = serializeFctObj(oObj, sAttr)
%             
%         end
%         
%         function serializeDef = serializeFctDef(oObj, sAttr)
%             
%         end
    end
end

