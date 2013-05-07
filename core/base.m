classdef base < handle
    %BASE Base handle obj class
    %   Sets uuid, meta class, type usw
    %
    %NOTE prefixes:
    %   i = integer, f = float, r = ratio (percent), s = string, b = bool
    %   a = array, m = matrix, c = cell, t = struct
    %   o = object, h = handle (file, graphics, ...), p = map
    %
    %   Awesome when mixed, e.g. taiSomething would be a struct, with each
    %   field holding an array of integers.
    %   For a struct with non-uniform values, the key should contain the
    %   prefix, e.g. tSomething and then tSomething.fVal, tSomething.sName
    %   (the tSomething could also be named txSomething - more clear).
    %   Struct-hierarchy e.g. ttxMatter - each field of main struct
    %   contains another struct (or several?), with mixed values (the x
    %   specifically says mixed values, could be omitted since in this
    %   example (from @matter.table), the values are containing the prefix,
    %   e.g. fMolmass).
    %
    %TODO
    %   - inf
    
    
    %% Static methods - helpers etc %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods (Static = true)
        function sUUID = randomUUID(bStructable)
            % Create a 16byte number "Universally Unique IDentifier" (UUID)
            % represented by 32 hexadecimal digits) that can be used as an 
            % unique identifier for any kind of object, element, etc.
            % If bStructable is false, the UUID contains hyphens and may 
            % begin with a number; if true (default), a UUID starting with 
            % a number is discarded and a new one is created before 
            % returning, and the hyphens are removed (therefore the UUID 
            % can be used as a key in a struct).
            %
            %NOTE: "practically unique", not "guaranteed unique" (see 
            %      Wikipedia), but since 32 hexadecimal digits result in 
            %      16^32 possible UUIDs, one can be reasonably confident 
            %      that the id is unique!
            %
            % http://en.wikipedia.org/wiki/Universally_unique_identifier
            % http://docs.oracle.com/javase/6/docs/api/java/util/UUID.html


            if nargin < 1, bStructable = true; end;


            if bStructable
                sUUID = '1';
                oGen  = java.util.UUID.randomUUID();

                % If the first character of the UUID is a number, generate a new one!
                while ~isnan(str2double(sUUID(1)))
                    sUUID = char(oGen.randomUUID().toString());
                end

                sUUID = strrep(sUUID, '-', '');
            else
                sUUID = char(java.util.UUID.randomUUID().toString());
            end
            
        end
    end
    
    
    
    %% Props and methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (SetAccess = private, GetAccess = public)
        % Reference to meta class and package/class path
        oMeta;
        sBase;
    end
    
    properties (GetAccess = public, SetAccess = private)
        % Unique id for object instance, class name
        sUUID;
        sEntity;
    end
    
    methods
        function this = base()
            this.oMeta   = metaclass(this);
            this.sEntity = this.oMeta.Name;
            
            this.sUUID = base.randomUUID();
            this.sBase = [ strrep(this.sEntity, '.', '/') '/' this.sUUID ];
        end
    end
    
    methods (Access = protected)
        function throw(this, sIdent, sMsg, varargin)
            % Wrapper for throwing errors - includes path to the class
            
            error([ strrep(this.sBase, '/', ':') ':' sIdent ], sMsg, varargin{:});
        end
        
        function warn(this, sIdent, sMsg, varargin)
            % See throw
            
            warning([ strrep(this.sBase, '/', ':') ':' sIdent ], sMsg, varargin{:});
        end
    end
end

