classdef console_output < simulation.monitor
    %LOGGER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    
    
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
        
        % Filter by UUIDs
        csUuids = {};
        
        
        % Filter by paths
        csPaths = {};
        
        
        % Only messages with a level GREATER or EQUAL to this one are
        % printed
        iMinLevel = 1;
        
        % Only LOWER or EQUAL are printed
        iMaxVerbosity = 1;
        
        
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
        oLog;
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
            [ this.oLog, this.iLogBindId ] = base.signal('log', @this.printOutput, @this.filterObjByRootlineToSimContainer, this);
        end
        
        
        function delete(this)
            this.oLog.unbind(this.iLogBindId);
        end
        
        
        function setLogOff(this)
            this.oLog.setOutputState(false);
        end
        
        function setLogOn(this)
            this.oLog.setOutputState(true);
        end
        
        
        function this = setReportingInterval(this, iTicks, iMinorTicks)
            % Set the interval in which the tick and the sim time are
            % reported to the console.
            
            if ~isempty(iTicks)
                
                if mod(iTicks, 1) ~= 0, error('Ticks needs to be integer.'); end;
                
                this.iMajorReportingInterval = iTicks;
            end
            
            if (nargin >= 3) && ~isempty(iMinorTicks)
                
                if mod(iMinorTicks, 1) ~= 0, error('Minor ticks needs to be integer.'); end;
                
                if mod(iTicks / iMinorTicks, 1) ~= 0
                    error('Minor tick needs to be a whole-number divisor of major tick (e.g. 25 vs. 100, 10 vs. 100)');
                end
                
                this.iMinorReportingInterval = iMinorTicks;
            else
                this.iMinorReportingInterval = 0;
            end
        end
        
        
        
        
        function this = setLevel(this, iLevel)
            this.iMinLevel = iLevel;
        end
        
        function this = setVerbosity(this, iVerbosity)
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
            this.csTypes = {};
            %this.iTypes  = 0;
        end
        
        function this = addTypeToFilter(this, sType)
            if ~any(strcmp(this.csTypes, sType))
                %this.iTypes  = this.iTypes + 1;
                %this.csTypes{this.iTypes} = sType;
                this.csTypes{end + 1} = sType;
            end
        end
        
        function this = removeTypeFromFilter(this, sType)
            iIdx = find(strcmp(this.csTypes, sType));
            
            if ~isempty(iIdx)
                %this.iTypes  = this.iTypes - 1;
                this.csTypes(iIdx) = [];
            end
        end
        
        
        % Identifiers filters
        function this = resetIdentFilters(this)
            this.csIdentifiers = {};
        end
        
        function this = addIdentFilter(this, sIdentifier)
            if ~any(strcmp(this.csIdentifiers, sIdentifier))
                this.csIdentifiers{end + 1} = sIdentifier;
            end
        end
        
        function this = removeIdentFilter(this, sIdentifier)
            iIdx = find(strcmp(this.csIdentifiers, sIdentifier));
            
            if ~isempty(iIdx)
                this.csIdentifiers(iIdx) = [];
            end
        end
        
        
        
        % Uuid filters
        function this = resetUuidFilters(this)
            this.csUuids = {};
        end
        
        function this = addUuidFilter(this, sUuid)
            if ~any(strcmp(this.csUuids, sUuid))
                this.csUuids{end + 1} = sUuid;
            end
        end
        
        function this = removeUuidFilter(this, sUuid)
            iIdx = find(strcmp(this.csUuids, sUuid));
            
            if ~isempty(iIdx)
                this.csUuids(iIdx) = [];
            end
        end
        
        
        % Path filters
        function this = resetPathsFilters(this)
            this.csPaths = {};
        end
        
        function this = addPathToFilter(this, sPath)
            sPath = simulation.helper.paths.convertShorthandToFullPath(sPath);
            
            if ~any(strcmp(this.csPaths, sPath))
                this.csPaths{end + 1} = sPath;
            end
        end
        
        function this = removePathFromFilter(this, sPath)
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
            
            
            if ~isempty(this.csIdentifiers)
                if ~any(strcmp(this.csIdentifiers, tPayload.sIdentifier))
                    return;
                end
            end
            
            if ~isempty(this.csTypes)
                if ~any(strcmp(this.csTypes, tPayload.oObj.sEntity))
                    return;
                end
            end
            
            if ~isempty(this.csUuids)
                if ~any(strcmp(this.csUuids, tPayload.oObj.sUUID))
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
            
            
            
            %TODO FILTER BY this.iMinLevel and this.iMaxVerbosity
            %       as well as this.ttUuidCfg.iMinLevel / iMaxVerbosity
            %   vs. tPayload.iLevel / iVerbosity
            if this.iMinLevel > tPayload.iLevel || this.iMaxVerbosity < tPayload.iVerbosity
                return;
            end
            
            
            %TODO remember last output? of oObj the same - GROUP outputs?
            %   E.g. output obj UUID, type, sIDENT, iLevel/iVerbosity etc
            %   once as 'headline'?
            
            %TODO possibility to provide some way/config so name of
            %   object can be plotted? For phases, this would mean the 
            %   vsys, store and phase names! Separete from sIDentifier,
            %   that should be more for stuff like method name!
            
            
            
            oTimer = this.oSimulationInfrastructure.oSimulationContainer.oTimer;
            
            if oTimer.iTick > this.iLastTick
                fprintf('\n- - - - - - - - tick: %i / time: %fs - - - - - - - -\n', oTimer.iTick, oTimer.fTime);
                
                this.iLastTick = oTimer.iTick;
            end
            
            
            
            fprintf('[%i/%i]', tPayload.iLevel, tPayload.iVerbosity);
            
            if ~isempty(tPayload.sIdentifier)
                fprintf('[%s]', tPayload.sIdentifier);
            end
            
            
            if ~isempty(tPayload.sIdentifier)
                fprintf(['\t' tPayload.sMessage '\n' ], tPayload.cParams{:});
            end
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
            
% %             disp('------------------------------------------------------------------------');
% %             disp('SIMULATION FINISHED - STATS!');
% %             disp('------------------------------------------------------------------------');
            
            
            
            oSimInfra = this.oSimulationInfrastructure;
            oTimer    = oSimInfra.oSimulationContainer.oTimer;
            
            disp('------------------------------------------------------------------------');
            disp([ 'Sim Time:     ' num2str(oTimer.fTime) 's in ' num2str(oTimer.iTick) ' ticks' ]);
            disp([ 'Sim Runtime:  ' num2str(oSimInfra.fRuntimeTick + oSimInfra.fRuntimeOther) 's, from that for monitors (e.g. logging): ' num2str(oSimInfra.fRuntimeOther) 's' ]);
            disp([ 'Sim factor:   ' num2str(oSimInfra.fSimFactor) ' [-] (ratio)' ]);
            disp([ 'Avg Time/Tick:' num2str(oTimer.fTime / oTimer.iTick) ' [s]' ]);
            %disp([ 'Mass lost:    to be re-implemented' ]);
% %             disp([ 'Mass lost:    ' num2str(sum(this.mfLostMass(end, :))) 'kg' ]);
% %             disp([ 'Mass balance: ' num2str(sum(this.mfTotalMass(1, :)) - sum(this.mfTotalMass(end, :))) 'kg' ]);
%             disp([ 'Minimum Time Step * Total Sim Time: ' num2str(oTimer.fMinimumTimeStep * oTimer.fTime) ]);
%             disp([ 'Minimum Time Step * Total Ticks:    ' num2str(oTimer.fMinimumTimeStep * oTimer.iTick) ]);
            disp('------------------------------------------------------------------------');

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
                
                sFloat = [ '%.' num2str(oSim.oTimer.iPrecision) 'f' ];
                
                fprintf([ '%i\t(' sFloat 's)\t(Tick Delta ' sFloat 's)\n' ], oSim.oTimer.iTick, oSim.oTimer.fTime, fDeltaTime);
            end
        end
        
    end
end

