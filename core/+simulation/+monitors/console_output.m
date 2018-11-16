classdef console_output < simulation.monitor
    %CONSOLE_OUTPUT supports the debugging features of V-HAB. The user can
    % set output levels:
    % 1 (MESSAGE), 2 (INFO), 3 (NOTICE), 4 (WARN) and 5 (ERROR)
    %
    % To decide how much information the console_output should provide.
    
    
    properties (SetAccess = protected, GetAccess = public)
        iMajorReportingInterval = 100;
        iMinorReportingInterval = 10;
        
        % We need this to calculate the delta time between command window outputs.
        fLastTickDisp = 0;
        
        
    end
    
    
    
    % Log/DEbug stuff
    properties (SetAccess = protected, GetAccess = public)
        % Filter messages from objs by obj type
        csTypes = {};
        
        % Filter messages by identifier
        csIdentifiers = {};
        
        % Filter messages by method
        csMethods = {};
        
        % Filter by UUIDs
        csUuids = {};
        
        
        % Filter by paths
        csPaths = {};
        
        
        % Only messages with a level GREATER or EQUAL to this one are
        % printed
        iMinLevel = 1;
        
        % Only LOWER or EQUAL are printed
        iMaxVerbosity = 1;
        
        % Uuid of object that was the last one to debug something!
        sLastOutObjectUuid;
        
        
        % Local setting for objs, by UUID
        ttObjSettings = struct();
        
        
        % If necessary, rootline paths are generated and stored here
        tsObjUidsToRootlinePath = struct();
        
        % While true, add all objs to the list of 'our' objs!
        bInitializing = true;
        
        
        % Only output tick/time if progressed
        iLastTick = -1;
    end
    
    
    properties (SetAccess = protected, GetAccess = public, Transient)
        % Just so don't need length(csTypes)
        %iTypes = 0;
    end
    
    properties (SetAccess = protected, GetAccess = protected)
        oLogger;
        iLogBindId;
    end
    
    
    methods
        function this = console_output(oSimulationInfrastructure, iMajorReportingInterval, iMinorReportingInterval)
            %this@simulation.monitor(oSimulationInfrastructure, struct('tick_post', 'logData', 'init_post', 'init'));
            this@simulation.monitor(oSimulationInfrastructure, { 'init_post', 'tick_post', 'pause', 'finish', 'run' });
            
            if nargin >= 2 && ~isempty(iMajorReportingInterval)
                this.iMajorReportingInterval = iMajorReportingInterval;
            end
            
            if nargin >= 3 && ~isempty(iMinorReportingInterval)
                this.iMinorReportingInterval = iMinorReportingInterval;
            end
            
            
            
            % Register on logger / debugger
            [ this.oLogger, this.iLogBindId ] = base.signal('log', @this.printOutput, @this.filterObjByRootlineToSimContainer, this);
        end
        
        
        function delete(this)
            this.oLogger.unbind(this.iLogBindId);
        end
        
        
        function this = setReportingInterval(this, iTicks, iMinorTicks)
            % Set the interval in which the tick and the sim time are
            % reported to the console.
            
            if ~isempty(iTicks)
                
                if mod(iTicks, 1) ~= 0, error('Ticks needs to be integer.'); end
                
                this.iMajorReportingInterval = iTicks;
            end
            
            if (nargin >= 3) && ~isempty(iMinorTicks)
                
                if mod(iMinorTicks, 1) ~= 0, error('Minor ticks needs to be integer.'); end
                
                if mod(iTicks / iMinorTicks, 1) ~= 0
                    error('Minor tick needs to be a whole-number divisor of major tick (e.g. 25 vs. 100, 10 vs. 100)');
                end
                
                this.iMinorReportingInterval = iMinorTicks;
            else
                this.iMinorReportingInterval = 0;
            end
        end
        
        % Switch debugging output off.
        function this = setLogOff(this)
            this.oLogger.setOutputState(false);
        end
        
        % Globally activate the debugging output. This should only be done when
        % currently debugging, as it slows down the simulation.
        function this = setLogOn(this)
            this.oLogger.setOutputState(true);
        end
        
        % When printing a debug message, include the stack output?
        function this = toggleShowStack(this)
            this.oLogger.toggleCreateStack();
        end
        
        % Debug outputs are mapped to a level, see base.m:
        % 1 (MESSAGE), 2 (INFO), 3 (NOTICE), 4 (WARN) and 5 (ERROR)
        % Only output messages above the level set here.
        function this = setLevel(this, iLevel)
            % Parameters:
            %   iLevel  Only messages above this level are printed.
            
            this.iMinLevel = iLevel;
        end
        
        % Verbosity of the debug messages. Each message can set a verbosity, 
        % defining the amount of data printed. The higher the level, the more
        % information is printed.
        function this = setVerbosity(this, iVerbosity)
            % Parameters:
            %   iVerbosity  The higher the number, the more information is printed.
            
            
            this.iMaxVerbosity = iVerbosity;
        end
        
        
        % Local options for obj
%         function setObjThresholds(this, oObj, iLevel, iVerbosity)
%             % if iLevel empty - remove entry!
%             
%             if ischar(oObj)
%                 sUuid = oObj;
%             else
%                 sUuid = oObj.sUUID;
%             end
%             
%             
%             this.ttObjSettings.(sUuid) = struct('iLevel', iLevel, 'iVerbosity', iVerbosity);
%         end
        %TODO setTypeThresholds? I.e. sType (isa!), iLevel, iVerbosity?
        %       -> print all messages from matter.phase etc?
        % --> JUST use sEntity field, NOT isa! Then use same test as for
        % sIdentifier, jut with tPayload.oObj.sEntity
        
        
        
        
        
        
        % Types filters
        function this = resetTypesFilters(this)
            % Resets all type filters, see addTypeToFilter
            
            this.csTypes = {};
            %this.iTypes  = 0;
        end
        
        
        function this = addTypeToFilter(this, sType)
            % If debug messages are active, filter the printed messages depending
            % on the type of the object that generated the message.
            %
            % If no filter is set, all messages printed. Several filters can be
            % set to print messages from different object types.
            %
            % Parameters:
            %   sType   Only print debug messages of objects of this type (isaa
            %           check, e.g. type = 'matter.phase' also prints messages 
            %           an object of a derived class)
            
            if ~any(strcmp(this.csTypes, sType))
                %this.iTypes  = this.iTypes + 1;
                %this.csTypes{this.iTypes} = sType;
                this.csTypes{end + 1} = sType;
            end
        end
        
        function this = removeTypeFromFilter(this, sType)
            % Removes a type filters, see addTypeToFilter
            
            iIdx = find(strcmp(this.csTypes, sType));
            
            if ~isempty(iIdx)
                %this.iTypes  = this.iTypes - 1;
                this.csTypes(iIdx) = [];
            end
        end
        
        
        % Identifiers filters
        function this = resetIdentFilters(this)
            % See addIdentFilter; reset all filters.
            
            this.csIdentifiers = {};
        end
        
        function this = addIdentFilter(this, sIdentifier)
            % If debug messages are active, filter the printed messages depending
            % on the ident string passed together with the debug data.
            %
            % If no ident filter is added, all are printed. Several filters can 
            % be added, defined by the sIdentifier paramter.
            %
            % Can be chained, e.g.
            % oO.addIdentFilter('first').addIdentFilter('second')
            
            if ~any(strcmp(this.csIdentifiers, sIdentifier))
                this.csIdentifiers{end + 1} = sIdentifier;
            end
        end
        
        function this = removeIdentFilter(this, sIdentifier)
            % See addIdentFilter; reset filters for ident string sIdentifier.
            
            iIdx = find(strcmp(this.csIdentifiers, sIdentifier));
            
            if ~isempty(iIdx)
                this.csIdentifiers(iIdx) = [];
            end
        end
        
        
        % Method filters
        function this = resetMethodFilters(this)
            % See addMethodFilter; remove all filters.
            
            this.csMethods = {};
        end
        
        function this = addMethodFilter(this, sMethod)
            % If debug messages are active, filter the printed messages depending
            % on the method in which this debug message was generated.
            %
            % If no method filter is added, all messages are printed. Several 
            % filters can be added, defined by the sMethod paramter.
            %
            % Can be chained, e.g.
            % oO.addIdentFilter('first').addIdentFilter('second')
            
            if ~any(strcmp(this.csMethods, sMethod))
                this.csMethods{end + 1} = sMethod;
            end
        end
        
        function this = removeMethodFilter(this, sMethod)
            % See addMethodFilter; remove method filters for method sMethod
            
            iIdx = find(strcmp(this.csMethods, sMethod));
            
            if ~isempty(iIdx)
                this.csMethods(iIdx) = [];
            end
        end
        
        
        
        
        % Uuid filters
        function this = resetUuidFilters(this)
            % See addUuidFilter
            
            this.csUuids = {};
        end
        
        function this = addUuidFilter(this, sUuid)
            % See addTypeToFilter, but here, filtered by object UUIDs.
            
            if ~any(strcmp(this.csUuids, sUuid))
                this.csUuids{end + 1} = sUuid;
            end
        end
        
        function this = removeUuidFilter(this, sUuid)
            % See addUuidFilter
            
            iIdx = find(strcmp(this.csUuids, sUuid));
            
            if ~isempty(iIdx)
                this.csUuids(iIdx) = [];
            end
        end
        
        
        % Path filters
        function this = resetPathsFilters(this)
            % See resetPathsFilters
            
            this.csPaths = {};
        end
        
        function this = addPathToFilter(this, sPath)
            % See addTypeToFilter, but here, filtered by the objects path.
            % Path is generated automatically for known objects like vsys, store,
            % phase etc.
            %
            %TODO documented somewhere, link here!
            
            sPath = simulation.helper.paths.convertShorthandToFullPath(sPath);
            
            if ~any(strcmp(this.csPaths, sPath))
                this.csPaths{end + 1} = sPath;
            end
        end
        
        function this = removePathFromFilter(this, sPath)
            % See resetPathsFilters
            
            iIdx = find(strcmp(this.csPaths, sPath));
            
            if ~isempty(iIdx)
                this.csPaths(iIdx) = [];
            end
        end
    end
    
    %% Stuff for logging (not obj dumping, but LOG/DEBUG/... messages!)
    methods (Access = protected)
        
        function printOutput(this, tPayload)
            %TODO
            %   * values this.iLevel, iVerbose
            %   * obj values this.tUuidsToOpts.(oObjs.sUUID) - iLevel/iVerb
            %   * additionally globally filter by ISA and identifier!
            
            
            % Don't filter by identifier if empty - even if filters active,
            % always shown.
            if ~isempty(this.csIdentifiers) && ~isempty(tPayload.sIdentifier)
                if ~any(strcmp(this.csIdentifiers, tPayload.sIdentifier))
                    return;
                end
            end
            
            
            if ~isempty(this.csMethods)
                if ~any(strcmp(this.csMethods, tPayload.sMethod))
                    return;
                end
            end
            
            
            if ~isempty(this.csUuids)
                if ~any(strcmp(this.csUuids, tPayload.oObj.sUUID))
                    return;
                end
            end
            
            
            
            %TODO filter by ISA? (i.e. also parent classes included in
            %     check).
            if ~isempty(this.csTypes)
                if ~any(strcmp(this.csTypes, tPayload.oObj.sEntity))
                    return;
                end
            end
            
            
%             if this.iTypes > 0
%                 bFound = false;
%                 
%                 for iT = 1:this.iTypes
%                     if isa(tPayload.oObj, this.csTypes{iT})
%                         bFound = true;
%                         
%                         break;
%                     end
%                 end
%                 
%                 if ~bFound, return; end;
%             end


            
            
            % Filter by rootline path?
            if ~isempty(this.csPaths)
                if ~isfield(this.tsObjUidsToRootlinePath, tPayload.oObj.sUUID)
                    [ ~, sPath ] = simulation.helper.paths.getObjRootline(tPayload.oObj);
                    
                    this.tsObjUidsToRootlinePath.(tPayload.oObj.sUUID) = sPath;
                else
                    sPath = this.tsObjUidsToRootlinePath.(tPayload.oObj.sUUID);
                end
                
                iPathLen = length(sPath);
                bMatched = false;
                
                for iP = 1:length(this.csPaths)
                    sFilterPath    = this.csPaths{iP};
                    iFilterPathLen = length(sFilterPath);
                    
                    if iPathLen >= iFilterPathLen && strcmp(sFilterPath(1:iFilterPathLen), sPath(1:iFilterPathLen))
                        bMatched = true;
                    end
                end
                
                if ~bMatched
                    return;
                end
            end
            
            
            
            %CHECK local level/verbosity levelsfor specific Objs by UUID?
            %      need that? probably not, filtering can be done via ident
            %      or obj uuid or obj entity ...?
            if this.iMinLevel > tPayload.iLevel || this.iMaxVerbosity < tPayload.iVerbosity
                return;
            end
            
            
            %%%%%%%% Print output! %%%%%%%%
            
            
            oTimer = this.oSimulationInfrastructure.oSimulationContainer.oTimer;
            
            if oTimer.iTick > this.iLastTick
                fprintf('\n- - - - - - - - tick: %i / time: %.16fs - - - - - - - -\n', oTimer.iTick, oTimer.fTime);
                
                this.iLastTick = oTimer.iTick;
                this.sLastOutObjectUuid = '';
            end
            
            %TODO flag bOutputUuids --> store last tPayload.oObj.sUUID on
            %     this.sLastOutObjectUuid --> if curr obj uuid and that are
            %     not equal, output: '===> OBJ UUID: [uuid]' and possible
            %     try sName, sTitle, sLabel, s...?
            %       -> v-hab specific code here, so we can directly have
            %       some helper that generates e.g. matter.phae, f2f, ...
            %       names (including vsys/store/phase, or vsys/branch/f2f
            %       names)
            %     => optionally output whole path of obj? We do have that
            %        functionality for default classes ... which every
            %        object should somehow inherit from ...
            %
            %   ALSO - same for identifier - only output if not the same
            %          obj / not the same identifier
            %
            %   ALSO - output oObj.sEntity! Also only once as long as
            %          obj/ident are the same!
            %
            % PATH, ENTITIY, UUID optionally output
            % GROUP if same obj uuid, ident several times (store last uuid,
            %     last ident)
            
            sFullUuid   = [ tPayload.oObj.sUUID '.' tPayload.sMethod ];
            bContinuing = strcmp(sFullUuid, this.sLastOutObjectUuid);
            
            if bContinuing
                sTemp   = sprintf('[%s][%s]', tPayload.oObj.sEntity, tPayload.sMethod);
                sIndent = repmat(' ', 1, length(sTemp));
                
                fprintf('%s[%i]', sIndent, tPayload.iLevel);
            else
                fprintf('[%s][%s][%i]', tPayload.oObj.sEntity, tPayload.sMethod, tPayload.iLevel);
            end
            
            if ~isempty(tPayload.sIdentifier)
                fprintf('[%s]', tPayload.sIdentifier);
            end
            
            sVerbosityIndent = repmat('. ', 1, tPayload.iVerbosity);
            
            %fprintf([ sVerbosityIndent(2:end) tPayload.sMessage '\n' ], tPayload.cParams{:});
            fprintf(sVerbosityIndent(2:end));
            fprintf(tPayload.sMessage, tPayload.cParams{:});
            fprintf('\n');
            
            if this.oLogger.bCreateStack
                fprintf('     STACK');
                fprintf(' <- %s', tPayload.tStack(:).name);
                fprintf('\n\n');
            end
            
            
            this.sLastOutObjectUuid = sFullUuid;
        end
        
        
        %TODO very v-hab specific - move to vhab.simulation.monitors.*?
        function bOurs = filterObjByRootlineToSimContainer(this, oObj)
            % During init, matter structure not yet created, but we know it
            % belongs to 'our' sim.
            if this.bInitializing == true
                bOurs = this.bInitializing;
                return;
            end
            
            % After init - check matter hierarchy
            oSimInfra  = this.oSimulationInfrastructure;
            oSimCont   = oSimInfra.oSimulationContainer;
            coRootline = simulation.helper.paths.getObjRootline(oObj);
            
            bOurs = (length(coRootline) >= 1) && (coRootline{1} == oSimCont);
        end
        
        function this = onInitPost(this, ~)
            this.bInitializing = false;
        end
        
        
        function this = onRun(this, ~)
            % ASSIGN STUFF IN BASE!
            %   -> struct/obj with shorthands for systems, stores etc - log
            %   on/off, level etc.
            %assignin('base', 'oOut', 'TODO: should be struct or so, with fct handles to objs, set log on/off etc, local vars, ...!');
        end
        
        
    end
    
    %% Stuff for console out (balance, sim info, ...)
    methods (Access = protected)
        function this = onPause(this, ~)
            disp('');
            disp('------------------------------------------------------------------------');
            disp('SIMULATION PAUSED');
            disp('------------------------------------------------------------------------');
        end
        
        
        function this = onFinish(this, ~)
            % The '.'s from the minor tick don't end with a newline, so
            % explicitly display one. Will lead to an extra, unneeded new-
            % line for cases where the simulation did exactly stop after a
            % major tick display.
            disp('');
            
            oSimInfra = this.oSimulationInfrastructure;
            oTimer    = oSimInfra.oSimulationContainer.oTimer;
            
            fprintf('Simulation completed!\n\n');
            
            fprintf('+------------------------------ SIMULATION STATISTICS ------------------------------+\n');
            fprintf('Sim Time:      %i [s] in %i ticks\n', oTimer.fTime, oTimer.iTick);
            fprintf('Sim Runtime:   %.2f [s], from that for monitors (e.g. logging) %.2f [s]\n', oSimInfra.fRuntimeTick + oSimInfra.fRuntimeOther, oSimInfra.fRuntimeOther);
            fprintf('Sim factor:    %.4f [-] (ratio)\n', oSimInfra.fSimFactor);
            fprintf('Avg Time/Tick: %.4f [s]\n', oTimer.fTime / oTimer.iTick);
            fprintf('+-----------------------------------------------------------------------------------+\n\n');

        end
        
        
        function onTickPost(this, ~)
            
            oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            
            % Minor tick?
            if (this.iMinorReportingInterval > 0) && (mod(oSim.oTimer.iTick, this.iMinorReportingInterval) == 0) && (oSim.oTimer.fTime > 0)
                % Major tick -> remove printed minor tick characters
                if (mod(oSim.oTimer.iTick, this.iMajorReportingInterval) == 0)
                    %fprintf('\n');
                    
                    % Removed - not really able to handle e.g. other log
                    % messages from other code.
                    %TODO as soon as debug class exists, could be handled 
                    %     through that (used instead of disp/fprintf)
                    %iDeleteChars = 1 * ceil(this.iMajorReportingInterval / this.iMinorReportingInterval) - 1;
                    %fprintf(repmat('\b', 1, iDeleteChars));
                else
                    %fprintf('%f\t', oSim.oTimer.fTime);
                    
                    fprintf('\b .\n');
                end
            end
            
            if mod(oSim.oTimer.iTick, this.iMajorReportingInterval) == 0
                %TODO store last tick disp fTime on some containers.Map!
                %disp([ num2str(oSim.oTimer.iTick) ' (' num2str(oRoot.oData.oTimer.fTime - fLastTickDisp) 's)' ]);
                %fLastTickDisp = oRoot.oData.oTimer.fTime;
                
                fDeltaTime = oSim.oTimer.fTime - this.fLastTickDisp;
                this.fLastTickDisp = oSim.oTimer.fTime;
                
                %disp([ num2str(oSim.oTimer.iTick), ' (', num2str(oSim.oTimer.fTime), 's) (Delta Time ', num2str(fDeltaTime), 's)']);
                
                sFloat = [ '%.' num2str(7) 'f' ];
                
                fprintf([ '%i\t(' sFloat 's)\t(Tick Delta ' sFloat 's)\n' ], oSim.oTimer.iTick, oSim.oTimer.fTime, fDeltaTime);
            end
        end
        
    end
end

