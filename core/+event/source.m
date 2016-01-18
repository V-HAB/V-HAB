classdef source < base % < hobj
    %EVENTS blah ...
    %
    %TODO
    %   - return obj when binding, just delete(obj) removes event bind?
    %   - clean of all stuff like time or ticks or anything specific -
    %     should be done with derived class or so
    %   - possibility to change the event object?
    %   - check each callback on registration with nargout(callBack), store
    %     the return. Then throw out the try/catch below!
    
    properties (Access = private)
        iCounter = 0;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Structure holing all the callbacks and related data for events
        % Simply stored by id, the value is a cell holding the data like
        % the callback, the token, filter 
        cCallbacks = {};
        
        % Structure holding the available event types and the assigned
        % callbacks.
        % First dimension of struct defined type (dots replaced by
        % underscores), second is id of callback (prefixed by "id_")
        % Value is an array holding the filter data! The key also
        % identifies the cell index for that callback!
        ttaEvents = struct();
        
        % Filter callbacks
        tcFilters = struct();
    end
    
    methods
        function this = source()
        end
        
        % sType refers to event name, possibly hierachical (e.g.
        % schedule.exercise.bicycle); must not contain underscores
        function [ this, iId ] = bind(this, sType, callBack, aiFilters, tStorage)
            % Default filter - just empty array
            if nargin < 4, aiFilters = []; end;
            
            % Default storage data - empty struct
            if nargin < 5, tStorage = struct(); end;
            
            % Replace dots with underscores
            sPath = strrep(sType, '.', '_');
            
            % Create struct for callback if it doesn't exist yet
            if ~isfield(this.ttaEvents, sPath), this.ttaEvents.(sPath) = struct(); end;
            
            
            % Now check - if callback is a string, it should identify an
            % already existing callback and therefore use that!
            if isnumeric(callBack)
                %iId = str2num(callBack(4:end));
                iId = callBack;
                
                if size(this.cCallbacks, 1) >= iId && ~isempty(this.cCallbacks{iC, 1})
                    sId = [ 'id_' num2str(iId) ];
                else
                    iId = [];
                    return;
                end
            else
                % Increase counter and use for callback
                this.iCounter = this.iCounter + 1;
                iId           = this.iCounter;
                sId           = [ 'id_' num2str(this.iCounter) ];
                sToken        = [ 'token_' num2str(round(rand()*1E8)) ];
                
                % Central storage for callbacks, containing the tStorage
                % etc - if a callback is reassigned, the tStorage can't be
                % written again, just the aiFilters!
                %keyboard();
                this.cCallbacks(this.iCounter, :) = { callBack sToken tStorage };
            end
            
            % Set callback with its id, and the filter array as value; 
            % reference to cCallbacks by key (sId)
            this.ttaEvents.(sPath).(sId) = aiFilters;
        end
        
        function setFilter(this, sPath, filterCb, setFilterCb, aiDefaultFilters)
            % Add to according path - overwrite existing
            % In .trigger, always for sCurrentPath (!), check if filter -
            % else check parents for next filter ...
            % When calling filterCbs callback - check if aiFilters isempty,
            % if yes, don't even execute
            % Set setFilter as callback for Event obj, can set aiFilters in
            % Event object, which is afterwards set in Events - setFilter
            % can accept different types of params, depending on filter, but
            % see e.g. interval/timeout filter - two values!

            sPath = strrep(sPath, '.', '_');

            if nargin < 3
                this.tcFilters = rmfield(this.tcFilters, sPath);
            else
                if nargin < 4, setFilterCb = []; end;
                if nargin < 5, aiDefaultFilters = []; end;

                this.tcFilters.(sPath) = { filterCb setFilterCb aiDefaultFilters };
            end
        end
        
        
        % REMOVE callback
%         function unbind(this, sToken)
%             if isfield(this.tTokens, sToken)
%                 this.ttaEvents.(this.tTokens.(sToken){1}) = rmfield(this.ttaEvents.(this.tTokens.(sToken){1}), this.tTokens.(sToken){2});
%                 
%                 this.tTokens = rmfield(this.tTokens, sToken);
%             end
%         end
        % IMPORTANT: just removes the REFERENCE to a callBack - not the
        %    callback itself - might be referenced somewhere else as well
        function unbind(this, sType, iId)
            % Replace dots with underscores
            sPath = strrep(sType, '.', '_');
            sId   = [ 'id_' num2str(iId) ];
            
            if isfield(this.ttaEvents, sPath) && isfield(this.ttaEvents.(sPath), sId)
                this.ttaEvents.(sPath) = rmfield(this.ttaEvents.(sPath), sId);
            end
        end
    end
    
    methods (Access = protected)
        %CU uh! if e.g. tick.eat, and setTimeout, only executed while still
        %   on tick.eat - so at least a detick event, or something? JO!
        %   Then it is setTimeout OR detick!
        function tReturn = trigger(this, sType, tData)
            %global oSim;
            
            if nargin < 3, tData = []; end;
            
            % dbstack - get caller's function name and set for event obj?
            
            % create EventObj, set type, data and caller (this)
            %TODO instead of iTick, add an attribute cProps, read attr
            %     names from that and get the according values from this.
            %     Write on tData.tCaller or something? Or add to tStorage?
            oEvent   = event.event(sType, this, tData);%oSim.iTick, tData);
            sPath    = '';
            sRest    = sType;
            tReturn  = struct();
            %iTick    = oSim.iTick;
            sSep     = '';
            cFilter  = [];
            cFilters = {};
            
            while ~isempty(sRest)
                [ sPart sRest ] = strtok(sRest, '.');
                
                sPath = [ sPath sSep sPart ];
                sSep  = '_';
                cPathes = {};
                
                %CU check if sPart equals *
                % if no - check isfield ttaEvents sPath, add to cell
                % if yes - find all matching - add all to cell
                %          DELETE sRest
                
                % Execute EVERY callback that is on that and lower levels
                if strcmp(sPart, '*')
                    sRest = '';
                    cTree = fieldnames(this.ttaEvents);
                    cMtch = strfind(cTree(:, 1), sPath(1:(length(sPath) - 1)));%[ sPath sSep ]);
                    iC      = 1;
                    
                    for iI = 1:size(cTree, 1)
                        if cMtch{iI, 1} == 1
                            cPathes{iC, 1} = cTree{iI, 1};
                            iC             = iC + 1;
                        end
                    end
                    
                    % See following loop - if all these pathes are
                    % processed, somehow the filters have to be maintained.
                    % Because parent filters have to be inherited to
                    % children, that chain has to be preserved, but when
                    % jumping back to a higher level, the filter on that
                    % according level has to be used - therefore first sort
                    % the cell with the pathes ... (**cPathes**)
                    cPathes = sort(cPathes);
                    
                % Normal - just add the current path to the cell of pathes
                % to execute (if it exists)
                elseif isfield(this.ttaEvents, sPath)
                    cPathes = { sPath };
                end
                
                
                % Check - even if path is empty, maybe a filter assigned?
                % If yes, set for that level for the lower levels to use!
                if size(cPathes, 1) == 0 && ~strcmp(sPart, '*')
                    sCurrentType = strrep(sPath, '_', '.');
                    
                    % Set new filter
                    if isfield(this.tcFilters, sCurrentType) && ~isempty(this.tcFilters.(sCurrentType){1})
                        cFilters{size(strfind(sPath, '_'), 2) + 1, 1} = this.tcFilters.(sCurrentType);
                        
                    % Set the one already set by parent ... maybe cool
                    % stuff ;)
                    else
                        cFilters{size(strfind(sPath, '_'), 2) + 1, 1} = cFilter;
                    end
                end
                
                
                % Loop all found pathes (in case of * mode several ...)
                %if isfield(this.ttaEvents, sPath)
                for iC = 1:size(cPathes, 1)
                    sPath  = cPathes{iC, 1};
                    csIds  = fieldnames(this.ttaEvents.(sPath));
                    iDepth = size(strfind(sPath, '_'), 2) + 1;
                    
                    % Current type - types are with . instead of _
                    oEvent.sCurrentType = strrep(sPath, '_', '.');
                    
                    % (**cPathes**) ... and then, it is first checked if
                    % a filter for the current path exists, and if not, the
                    % parent's is used - identified by iDepth. So if the
                    % previous loop was on a lower level, the parent of
                    % that level was used, now we jump "up" in the cPathes
                    % cell since iDepth is now smaller than before - and we
                    % get the filter which is set for that new parent.
                    % If that parent itself had no filter, its parent
                    % filter was set for it earlier, so it's present, yay!
                    
                    % Check if a filter is assigned to current level
                    if isfield(this.tcFilters, oEvent.sCurrentType) && ~isempty(this.tcFilters.(oEvent.sCurrentType){1})
                        cFilter = this.tcFilters.(oEvent.sCurrentType);
                    
                    % Nope, so get parent filter - except we are on level
                    % 1, then there is no parent - cFilter stays empty ...
                    elseif iDepth > 1
                        cFilter = cFilters{iDepth - 1, 1};
                    end
                    
                    % Now write the filter to the current level - Matlab is
                    % smart enough to NOT create a new instance of cFilter
                    % in storage, so that's ok ... 
                    cFilters{iDepth, 1} = cFilter;
                    
                    
                    for iI = 1:size(csIds, 1)
                        sId       = csIds{iI};
                        iId       = str2double(sId(4:end));
                        callBack  = this.cCallbacks{iId, 1};
                        sToken    = this.cCallbacks{iId, 2};
                        tStorage  = this.cCallbacks{iId, 3};
                        
                        aiFilters = this.ttaEvents.(sPath).(sId);
                        
                        bExec     = true;
                        
                        if ~isempty(cFilter) && ~isempty(cFilter{3}) && size(aiFilters, 2) < size(cFilter{3}, 2)
                            % merge aiFilters with aiDefaultFilters!
                            % Check above done every tick then ... stupid?
                            
                            for iC = (size(aiFilters, 1) + 2):size(cFilter{3}, 2)
                                aiFilters(iC) = cFilter{3}(iC);
                            end
                        end
                        
                        
                        % Set event data for current callback
                        oEvent.sToken      = sToken;
                        oEvent.sId         = sId;
                        oEvent.tStorage    = tStorage;
                        oEvent.aiFilters   = aiFilters;
                        
                        if ~isempty(cFilter)
                            if ~isempty(cFilter{2})
                                oEvent.modifyFilterCb = cFilter{2};
                            end
                            
                            bExec = cFilter{1}(oEvent);
                        end
                        
                        
                        % If callback should be executed - set token and do
                        if bExec
                            % Execute callback - first try with return
                            try
                                xTmp = callBack(oEvent);
                                
                                if ~isempty(xTmp), tReturn.(sId) = xTmp; end;
                            
                            % Ok, that didn't work, so now without return
                            % STUPID MATLAB!
                            %catch
                            %    callBack(oEvent);
                            %end
                            catch oErr
                                % If error is not 'Too many output 
                                % arguments' or 'undefined func', throw!
                                
                                % Starting with MATLAB Prerelease 2015b the
                                % error identifier for 'Too many output
                                % arguments changed from 'MATLAB:maxlhs' to
                                % 'MATLAB:TooManyOutputs'
                                if verLessThan('MATLAB', '8.6')
                                    sErrorIdentifier = 'MATLAB:maxlhs';
                                else
                                    sErrorIdentifier = 'MATLAB:TooManyOutputs';
                                end
                                
                                if ~strcmp(oErr.identifier, sErrorIdentifier) && ~strcmp(oErr.identifier, 'MATLAB:UndefinedFunction')
                                    rethrow(oErr);
                                else
                                    callBack(oEvent);
                                end
                            end
                        end
                        
                        % Write back storage and filters (could have also
                        % been changed by filter callback, so always write)
                        this.ttaEvents.(sPath).(sId) = oEvent.aiFilters;
                        this.cCallbacks{iId, 3}      = oEvent.tStorage;
                        
                        % Reset oEvent
                        oEvent.sToken         = [];
                        oEvent.sId            = [];
                        oEvent.tStorage       = struct();
                        oEvent.aiFilters      = [];
                        oEvent.modifyFilterCb = [];
                    end
                    
                    oEvent.sCurrentType = '';
                end
            end
        end
    end
end