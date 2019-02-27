classdef base < handle
    %BASE Base handle object class 
    %   All other classes in V-HAB inherit from base or a subclass of base.
    
    properties (SetAccess = private, GetAccess = public)
        % Reference to meta class
        oMeta;
        
        % Reference to package/class path
        sURL;
        
        % Unique id for object instance
        sUUID;
        
        % Class name
        sEntity;
    end
    
    properties (GetAccess = public, Constant)
        % Registered debugger
        oDebug = tools.debugOutput();
    end
    
    methods
        function this = base()
            % For e.g. vsys, the base constructor is called several times,
            % as every parent class does eventually call the base
            % constructor. So if sUUID is already set - don't do anything
            % in here.
            if ~isempty(this.sUUID)
                return;
            end
            
            % Creating the metaclass object
            this.oMeta   = metaclass(this);
            
            % Setting the sEntity string to the class name
            this.sEntity = this.oMeta.Name;
            
            % Generating the Universally Unique Identifier (UUID)
            this.sUUID = tools.getPseudoUUID();
            
            % URL - used as identification for logging
            this.sURL = [ '/' strrep(this.sEntity, '.', '/') '/' this.sUUID ];
            
            % Adding this object to the logger
            if ~isa(this, 'tools.debugOutput')
                base.oDebug.add(this);
            end
        end
        
    end
    
    methods (Access = protected)
        
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
            % Using the methods in the consoleOutput simulation monitor,
            % the minimum level for a message to be displayed, and the
            % maximum verbosity can be set. Both values do not have an
            % upper limit, i.e. one could call this.out(100, 'my msg') and 
            % set oLastSimObj.toMonitors.oConsoleOutput.setLevel(100);
            %
            % For any log messages to be shown, logging has to be activated
            % with oLastSimObj.toMonitors.oConsoleOutput.setLogOn(). If the
            % parameters generated for this.out are more complex, i.e.
            % consume time, the global logging flag can be checked:
            % if ~base.oDebug.bOff, (... prepare params and call .out() ...)
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
            if base.oDebug.bOff, return; end
            
            
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
            base.oDebug.output(this, iLevel, iVerbosity, sIdentifier, sMessage, cParams);
        end
        
        function throw(this, sIdent, sMsg, varargin)
            % Wrapper for throwing errors - includes path to the class
            error([ strrep(this.sURL(2:end), '/', ':') ':' sIdent ], sMsg, varargin{:});
        end
        
        function warn(this, sIdent, sMsg, varargin)
            % See throw
            warning([ strrep(this.sURL(2:end), '/', ':') ':' sIdent ], sMsg, varargin{:});
        end
    end
    
    methods (Static)
        function flush()
            base.oDebug.flush();
        end
    end
    
end
