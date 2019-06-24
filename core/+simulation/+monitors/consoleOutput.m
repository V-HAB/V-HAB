classdef consoleOutput < simulation.monitor
    %CONSOLEOUTPUT Defines what is output as text in the command window during a simulation
    %   This monitor is responsible for the dotted lines that appear in the
    %   command window during a simulation run, as well as the summary
    %   output that is provided when a simulation is paused or finished. 
    %   Additionally it supports the debugging features of V-HAB. Using the 
    %   setLevel() method the user can set the following output levels:
    %   
    %   1 (MESSAGE), 2 (INFO), 3 (NOTICE), 4 (WARN) and 5 (ERROR)
    %   
    %   These levels determine what type of information is output to the
    %   command window during a simulation. Additionally, the user can
    %   define a level of verbosity that determines how wordy and extensive
    %   the output is. Here 1 is the lowest verbosity and there are no
    %   upper limits. Finally, the debugging output can also be filtered by
    %   type (e.g. only output messages from objects that derive from
    %   'matter.phase.gas'), by a user-defined identifier, by method, by
    %   object UUID and object path.
    %   
    %   The use of this debugging interface is  further detailed in
    %   the method description of the out() method in the core/base class.
    
    properties (SetAccess = protected, GetAccess = public)
        %% General Properties
        
        % Interval in ticks after which a new line is added to the command
        % window output containing the current time, tick and delta time
        % since the last major interval.
        iMajorReportingInterval = 100;
        
        % Interval in ticks after which an additional dot character '.' is
        % added to the end of the last line in the command window. 
        iMinorReportingInterval = 10;
        
        % We need this to calculate the delta time between command window
        % outputs.
        fLastTickDisp = 0;
        
        %% Properties specific to the debug output
        
        % Cell of strings containing the object types by which the
        % debugging output shall be filtered.
        csTypes = {};
        
        % Cell of strings containing the identifiers by which the debugging
        % output shall be filtered.
        csIdentifiers = {};
        
        % Cell of strings containing the method names by which the
        % debugging output shall be filtered.
        csMethods = {};
        
        % Cell of strings containing the UUIDs by which the
        % debugging output shall be filtered.
        csUuids = {};
        
        % Cell of strings containing the paths by which the
        % debugging output shall be filtered.
        csPaths = {};
        
        % Minimum reporting level. Can be 1 through 5. Only messages with a
        % level GREATER or EQUAL to this one are printed.
        iMinLevel = 1;
        
        % Maximum verbosity level. Only LOWER or EQUAL are printed
        iMaxVerbosity = 1;
        
        % UUID of object that was the last one to debug something!
        sLastOutObjectUuid;
        
        % Local output setting for objs, by UUID
        ttObjSettings = struct();
        
        % If necessary, rootline paths are generated and stored here
        tsObjUidsToRootlinePath = struct();
        
        % While true, add all objs to the list of 'our' objs!
        bInitializing = true;
        
        % Integer that stores the last tick at which the output was
        % performed. This is to ensure that we only output something if the
        % simulation has progressed at least one tick.
        iLastTick = -1;
    end
    
    % These properties should not be accessed via the consoleOutput class,
    % so their GetAccess is protected. 
    properties (SetAccess = protected, GetAccess = protected)
        % Reference to the debugOutput object of this simulation
        oDebugOutput;
        
        % Integer capturing the ID under which this monitor is bound to the
        % debugOutput object. This information is required to delete the
        % monitor, if necessary. 
        iDebugBindId;
    end
    
    
    methods
        function this = consoleOutput(oSimulationInfrastructure, iMajorReportingInterval, iMinorReportingInterval)
            % Calling the parent constructor
            this@simulation.monitor(oSimulationInfrastructure, { 'init_post', 'step_post', 'pause', 'finish', 'run' });
            
            % If it is provided by the user, we set the major reporting
            % interval.
            if nargin >= 2 && ~isempty(iMajorReportingInterval)
                this.iMajorReportingInterval = iMajorReportingInterval;
            end
            
            % If it is provided by the user, we set the minor reporting
            % interval.
            if nargin >= 3 && ~isempty(iMinorReportingInterval)
                this.iMinorReportingInterval = iMinorReportingInterval;
            end
            
            % Registering this object on the debugger
            this.iDebugBindId = base.oDebug.bind(@this.printOutput, @this.filterObjByRootlineToSimContainer, this);
            
            % Setting the oDebugOutput property so we can access it from the
            % methods in this class. 
            this.oDebugOutput = base.oDebug;
        end
        
        function this = setReportingInterval(this, iMajorTicks, iMinorTicks)
            % Sets the intervals for the major and minor reporting in the command window
            
            % Check if its empty or non-integer, if it checks out, set it.
            if ~isempty(iMajorTicks)
                if mod(iMajorTicks, 1) ~= 0, error('Ticks needs to be integer.'); end
                this.iMajorReportingInterval = iMajorTicks;
            end
            
            % Similar checks for the minor interval with the additional
            % check to see if the minor interval is smaller and an integer
            % divisor of the major interval. 
            if (nargin >= 3) && ~isempty(iMinorTicks)
                
                if mod(iMinorTicks, 1) ~= 0, error('Minor ticks needs to be integer.'); end
                
                if mod(iMajorTicks / iMinorTicks, 1) ~= 0
                    error('Minor tick needs to be a whole-number divisor of major tick (e.g. 25 vs. 100, 10 vs. 100)');
                end
                
                this.iMinorReportingInterval = iMinorTicks;
            else
                % If the above checks fail we just set it to zero, that way
                % nothing is output.
                this.iMinorReportingInterval = 0;
            end
        end
    end
    
    %% Methods regarding the standard console output (not debugging)
    methods (Access = protected)
        
        function this = onInitPost(this, ~)
            % This is called after simulation initialization is complete
            % and just sets our bInitializing property to false.
            this.bInitializing = false;
        end
        
        function this = onPause(this, ~)
            % Prints simulation statistics when the simulation is pause.
            
            % Printing a nice visual boundary
            fprintf('+-----------------------------------------------------------------------------------+\n');
            fprintf('+-------------------------------- SIMULATION PAUSED --------------------------------+\n');
            fprintf('+-----------------------------------------------------------------------------------+\n\n');
            
            % Actually printing the statistics
            this.printSimulationStatistics();
        end
        
        
        function this = onFinish(this, ~)
            % Prints simulation statistics once the simulation is completed
            
            % The '.'s from the minor tick don't end with a newline, so
            % explicitly display one. Will lead to an extra, unneeded new-
            % line for cases where the simulation did exactly stop after a
            % major tick display.
            disp('');
            
            fprintf('Simulation completed!\n\n');
            
            this.printSimulationStatistics();
            
        end
        
        function printSimulationStatistics(this)
            % Gathers information from the simulation object and prints it
            
            % Getting a local reference to the simulation infrastructure
            % and timer objects to make the code more legible.
            oSimInfra = this.oSimulationInfrastructure;
            oTimer    = oSimInfra.oSimulationContainer.oTimer;
            
            % Actually printing the statistics.
            fprintf('+------------------------------ SIMULATION STATISTICS ------------------------------+\n');
            fprintf('Sim Time:      %i [s] in %i ticks\n', oTimer.fTime, oTimer.iTick);
            fprintf('Sim Runtime:   %.2f [s], from that for monitors (e.g. logging) %.2f [s]\n', oSimInfra.fRuntimeTick + oSimInfra.fRuntimeOther, oSimInfra.fRuntimeOther);
            fprintf('Sim factor:    %.4f [-] (ratio)\n', oSimInfra.fSimFactor);
            fprintf('Avg Time/Tick: %.4f [s]\n', oTimer.fTime / oTimer.iTick);
            fprintf('+-----------------------------------------------------------------------------------+\n\n');
            
        end
        
        
        function onStepPost(this, ~)
            % Prints something to the console during the simulation 
            % This method prints text to the console during simulations to
            % give the user reassurance that the simulation is still
            % running and also to provide information on the speed of
            % progress. The user can define major and minor reporting
            % intervals. By default, the minor interval is 10 ticks and the
            % major interval is 100 ticks. 
            
            % First we get a reference to the simulation container to make
            % the code more legible.
            oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            
            % Now we check if a minor reporting interval has been set and
            % if we are at one of the intervals. We also need to check if
            % the current time is larger than zero since we don't want to
            % print anything at or before the start of the simulation.
            if (this.iMinorReportingInterval > 0) && (mod(oSim.oTimer.iTick, this.iMinorReportingInterval) == 0) && (oSim.oTimer.fTime > 0)
                % We are at a minor reporting interval, but since the major
                % interval has to be an integer multiple of the minor
                % interval, we need to check if we are not also at a major
                % interval. 
                if (mod(oSim.oTimer.iTick, this.iMajorReportingInterval) ~= 0)
                    % We are at a minor interval and not at a major
                    % interval, so we can go ahead an print. Other parts of
                    % V-HAB may want to also print something in the command
                    % window during a simulation. These outputs should be
                    % placed at the beginning of a line. So for our output
                    % here, we include a newline character in the end.
                    % However, if there is no output in between calls of
                    % this method, then we would be stacking the dot
                    % characters vertically, rather than horizontally,
                    % which is desired. So we first need to go back to the
                    % previous line and for that reason the backspace
                    % character is also included. 
                    fprintf('\b .\n');
                end
            end
            
            % Now we check if we are at a major reporting interval
            if mod(oSim.oTimer.iTick, this.iMajorReportingInterval) == 0
                % We are, so now we gather some information and then
                % display it in the console.
                
                % First we calculate the simulated ime that has passed
                % since the last major report.
                fDeltaTime = oSim.oTimer.fTime - this.fLastTickDisp;
                
                % We save the current time for the next call of this
                % method.
                this.fLastTickDisp = oSim.oTimer.fTime;
                
                % In order to play around with the precision at which the
                % times are presented, we create a string variable for the
                % output format string.
                sFloat = [ '%.' num2str(7) 'f' ];
                
                % And now we can finally print the report. It includes the
                % current tick, the current time and how much time has
                % passed since the last report. 
                if this.oSimulationInfrastructure.bParallelExecution
                    fprintf([ '%i\t(' sFloat 's)\t(Tick Delta ' sFloat 's)\t(Simulation: %s)\n' ], oSim.oTimer.iTick, oSim.oTimer.fTime, fDeltaTime, this.oSimulationInfrastructure.sName);
                else
                    fprintf([ '%i\t(' sFloat 's)\t(Tick Delta ' sFloat 's)\n' ], oSim.oTimer.iTick, oSim.oTimer.fTime, fDeltaTime);
                end
            end
        end
        
    end
    
    methods
        %% Global methods for the debugging output
        
        function delete(this)
            % Deletes this output object from the debugger. 
            this.oDebugOutput.unbind(this.iDebugBindId);
        end
        
        function this = setDebugOff(this)
            % Turns the debugging output off
            this.oDebugOutput.setOutputState(false);
        end
        
        function this = setDebugOn(this)
            % Globally activates the debugging output. 
            % This should only be done when currently debugging, as it
            % slows down the simulation.
            this.oDebugOutput.setOutputState(true);
        end
        
        function this = toggleShowStack(this)
            % When printing a debug message, include the stack output?
            this.oDebugOutput.toggleCreateStack();
        end
        
        function this = setLevel(this, iLevel)
            % Set the minimum reporting level for the debugging output
            this.iMinLevel = iLevel;
        end
        
        function this = setVerbosity(this, iVerbosity)
            % Set the verbosity of the debug messages
            this.iMaxVerbosity = iVerbosity;
        end
        
        %% Methods to add filters to the debugging output
        
        function this = addTypeFilter(this, sType)
            % Sets a filter so only debug messages of a certain type are output
            % 
            % If debug messages are active, filter the printed messages
            % depending on the type of the object that generated the
            % message.
            %
            % If no filter is set, all messages printed. Several filters
            % can be set to print messages from different object types.
            %
            % Parameters:
            %   sType   Only print debug messages of objects of this type 
            %           (isaa check, e.g. type = 'matter.phase' also prints
            %           messages an object of a derived class)
            
            if ~any(strcmp(this.csTypes, sType))
                this.csTypes{end + 1} = sType;
            end
        end
        
        function this = addIdentFilter(this, sIdentifier)
            % Sets a filter so only debug messages with a certain identifier are output
            % If debug messages are active, filter the printed messages
            % depending on the ident string passed together with the debug
            % data.
            %
            % If no ident filter is added, all are printed. Several filters
            % can be added, defined by the sIdentifier paramter.
            %
            % Can be chained, e.g.
            % oO.addIdentFilter('first').addIdentFilter('second')
            
            if ~any(strcmp(this.csIdentifiers, sIdentifier))
                this.csIdentifiers{end + 1} = sIdentifier;
            end
        end
        
        function this = addMethodFilter(this, sMethod)
            % Sets a filter so only debug messages from a certain method are output
            % If debug messages are active, filter the printed messages
            % depending on the method in which this debug message was
            % generated.
            %
            % If no method filter is added, all messages are printed.
            % Several filters can be added, defined by the sMethod
            % paramter.
            %
            % Can be chained, e.g.
            % oO.addIdentFilter('first').addIdentFilter('second')
            
            if ~any(strcmp(this.csMethods, sMethod))
                this.csMethods{end + 1} = sMethod;
            end
        end
        
        function this = addUuidFilter(this, sUuid)
            % Sets a filter so only debug messages from a certain object are output
            % The object is specified by the provided UUID
            
            if ~any(strcmp(this.csUuids, sUuid))
                this.csUuids{end + 1} = sUuid;
            end
        end
        
        function this = addPathFilter(this, sPath)
            % Sets a filter so only debug messages from a certain object
            % are output When applying the filter in the printOutput()
            % method of this class, the object is specified by the provided
            % UUID. The path is generated automatically for known objects like
            % vsys, store, phase etc. See
            % simulation.helper.paths.getObjRootline
            % 
            % NOTE: This method allows the user to add paths that lead to
            %       children of objects that are already being filtered.
            %       For example a path to a store could be added,
            %       ('Example.toStores.Tank_1') as well as a path to one of
            %       its phases
            %       ('Example.toStores.Tank_1.toPhases.Phase_1'). The
            %       deciding factor here is the position of the string
            %       within the csPaths cell property of this class. The
            %       filter that has been added last will be applied.
            %       Additionally, the way this filter is set up, it will
            %       let through all messages from the object given in the
            %       path, but also all messages from its children. So for
            %       the example where the path is
            %       'Example.toStores.Tank_1', the debugger will output not
            %       just messages from this store, but also from its
            %       phases, because the first 23 characters match the path
            %       'Example.toStores.Tank_1.toPhases.Phase_1' The deciding
            %       factor here is the length of the path string that is
            %       stored in the csPaths property of this object. If this
            %       is not the desired behavior, if only the messages from
            %       one specific object is required, the user must use the
            %       UUID filter.
            
            % In case the path was provided in shorthand we expand it to
            % the full path.
            sPath = simulation.helper.paths.convertShorthandToFullPath(sPath);
            
            % Adding the filter
            if ~any(strcmp(this.csPaths, sPath))
                this.csPaths{end + 1} = sPath;
            end
        end
        
        %% Methods to remove filters from the debugging output
        
        function this = removeTypeFilter(this, sType)
            % Removes a type filter
            
            % Finding the index of the filter to be removed in the csTypes
            % cell property
            iIdx = find(strcmp(this.csTypes, sType));
            
            % If we found one, we can delete it. 
            if ~isempty(iIdx)
                this.csTypes(iIdx) = [];
            end
        end
        
        function this = removeIdentFilter(this, sIdentifier)
            % Removes an identifier filter
            
            % Finding the index of the filter to be removed in the
            % csIndentifiers cell property
            iIdx = find(strcmp(this.csIdentifiers, sIdentifier));
            
            % If we found one, we can delete it. 
            if ~isempty(iIdx)
                this.csIdentifiers(iIdx) = [];
            end
        end
        
        function this = removeMethodFilter(this, sMethod)
            % Removes a method filter
            
            % Finding the index of the filter to be removed in the
            % csMethods cell property
            iIdx = find(strcmp(this.csMethods, sMethod));
            
            % If we found one, we can delete it. 
            if ~isempty(iIdx)
                this.csMethods(iIdx) = [];
            end
        end
        
        function this = removeUuidFilter(this, sUuid)
            % Removes a UUID filter
            
            % Finding the index of the filter to be removed in the csUuids
            % cell property
            iIdx = find(strcmp(this.csUuids, sUuid));
            
            % If we found one, we can delete it. 
            if ~isempty(iIdx)
                this.csUuids(iIdx) = [];
            end
        end
        
        function this = removePathFilter(this, sPath)
            % Removes a path filter
            
            % Finding the index of the filter to be removed in the csPaths
            % cell property
            iIdx = find(strcmp(this.csPaths, sPath));
            
            % If we found one, we can delete it. 
            if ~isempty(iIdx)
                this.csPaths(iIdx) = [];
            end
        end
        
        %% Methods to reset filters of the debugging output
        
        function this = resetTypesFilters(this)
            % Resets all type filters
            this.csTypes = {};
        end
        
        function this = resetIdentFilters(this)
            % Resets all indentifier filters
            this.csIdentifiers = {};
        end
        
        function this = resetMethodFilters(this)
            % Resets all method filters
            this.csMethods = {};
        end
        
        function this = resetUuidFilters(this)
            % Resets all UUID filters
            this.csUuids = {};
        end
        
        function this = resetPathFilters(this)
            % Resets all path filters
            this.csPaths = {};
        end
        
    end
    
    %CHECK Why is this method protected?
    methods (Access = protected)
        
        function printOutput(this, tPayload)
            % Prints the debugging output to the console
            
            % First we check all of our filters. If there are active
            % filters then we compare the payload to the filter to see if
            % this message should be displayed or not. The process is a
            % little bit backwards, we are filtering in, not out. So all
            % messages arrive here, but if there are active filters, we
            % only let the ones through that we want to see. If there are
            % no filters set, all messages are displayed. 
            % The way we determine if there are active filters is by
            % checking if the appropriate properties of this object are
            % empty or not. Empty means no filters active. 
            
            % In order to have multiple kinds of filters present at the
            % same time, we need a bunch of booleans that we use after
            % we're done checking out what kind of message we have been
            % given.
            bTypeFilterPresent       = false;
            bIdentifierFilterPresent = false;
            bUUIDFilterPresent       = false;
            bMethodFilterPresent     = false;
            bPathFilterPresent       = false;
            bTypeFilterActive        = false;
            bIdentifierFilterActive  = false;
            bUUIDFilterActive        = false;
            bMethodFilterActive      = false;
            bPathFilterActive        = false;
            
            % Checking if there are type filters
            if ~isempty(this.csTypes)
                bTypeFilterPresent = true;
                % Checking if the current message is from one of the
                % filtered object types.
                if any(strcmp(this.csTypes, tPayload.oObj.sEntity))
                    % It's on the list, so we set active to true.
                    bTypeFilterActive = true;
                end
                
                
            end
            
            % Checking if there are identifier filters. Since the
            % identifier is optional, we also have to check if there is an
            % identifier given
            if ~isempty(this.csIdentifiers) && ~isempty(tPayload.sIdentifier)
                bIdentifierFilterPresent = true;
                % Checking if the current message carries one of the
                % identifiers we are filtering out.
                if any(strcmp(this.csIdentifiers, tPayload.sIdentifier))
                    % It's on the list, so we set active to true.
                    bIdentifierFilterActive = true;
                end
            end
            
            % Checking if there are UUID filters
            if ~isempty(this.csUuids)
                bUUIDFilterPresent = true;
                % Checking if the current message is from one of the
                % objects, identified by UUID, that we are filtering out
                if any(strcmp(this.csUuids, tPayload.oObj.sUUID))
                    % It's on the list, so we set active to true.
                    bUUIDFilterActive = true;
                end
            end
            
            % Checking if there are method filters
            if ~isempty(this.csMethods)
                bMethodFilterPresent = true;
                % Checking if the current message is from one of the
                % methods we are filtering out.
                if any(strcmp(this.csMethods, tPayload.sMethod))
                    % It's on the list, so we set active to true.
                    bMethodFilterActive = true;
                end
            end
            
            % Checking if there are path filters
            if ~isempty(this.csPaths)
                bPathFilterPresent = true;
                
                % The tPayload input argument to this function does not
                % explicitly contain the path to the object the message is
                % originating from. We therefore have to extract the path
                % from the object itself using the getObjRootline() helper
                % method. Since this function may be called very frequently
                % during debugging, we try to save some computational
                % resources by saving the path in the
                % tsObjUidsToRootlinePath property of this class. 
                
                % So we first check if the object already has been saved
                if ~isfield(this.tsObjUidsToRootlinePath, tPayload.oObj.sUUID)
                    % The object has not yet been saved, so we call the
                    % helper and get a path.
                    [ ~, sPath ] = simulation.helper.paths.getObjRootline(tPayload.oObj);
                    
                    % Now we save the path to the tsObjUidsToRootlinePath
                    % struct property where its key will be the UUID.
                    this.tsObjUidsToRootlinePath.(tPayload.oObj.sUUID) = sPath;
                else
                    % The object has been saved previously, so we can
                    % extract its path from this object's
                    % tsObjUidsToRootlinePath property.
                    sPath = this.tsObjUidsToRootlinePath.(tPayload.oObj.sUUID);
                end
                
                % The way this filter is set up, it will let through all
                % messages from the object given in the path, but also all
                % messages from its children. So for example if the path is
                % 'Example.toStores.Tank_1', the debugger will output not
                % just messages from this store, but also from its phases.
                % An example path would be
                % 'Example.toStores.Tank_1.toPhases.Phase_1'
                % The deciding factor here is the length of the path string
                % that is stored in the csPaths property of this object. 
                % If this is not the desired behavior, if only the messages
                % from one specific object is required, the user must use
                % the UUID filter. 
                
                % Getting the length of the path of the current message's
                % originator
                iPathLen = length(sPath);
                
                % Initializing a boolean variable that will indicate if we
                % found a matching filter entry or not.
                bMatched = false;
                
                % Going through all of the stored path filters
                for iPath = 1:length(this.csPaths)
                    % Getting the current filter and determining its length
                    sFilterPath    = this.csPaths{iPath};
                    iFilterPathLen = length(sFilterPath);
                    
                    % If the path string is shorter than the path string in
                    % the filter, then they cannot match. If the path
                    % string is equal or longer than the path string in the
                    % filter, then they can match, so we check for that. 
                    % Note that there is no 'break' after the match is
                    % confirmed. That means if there is a more or less
                    % specific path filter in the csPaths property (see the
                    % example above using a store and its phases) then the
                    % filter that was last added is the one that will be
                    % applied. 
                    if iPathLen >= iFilterPathLen && strcmp(sFilterPath(1:iFilterPathLen), sPath(1:iFilterPathLen))
                        bMatched = true;
                    end
                end
                
                if bMatched
                    % It's on the list, so we set active to true.
                    bPathFilterActive = true;
                end
            end
            
            % Building two arrays we can check against
            abPresentFilters = [ bTypeFilterPresent, bIdentifierFilterPresent, bUUIDFilterPresent, bMethodFilterPresent, bPathFilterPresent ];
            abActiveFilters  = [ bTypeFilterActive,  bIdentifierFilterActive,  bUUIDFilterActive,  bMethodFilterActive,  bPathFilterActive  ];
            
            % Unless there are present and active filters, we return.
            if ~any(abPresentFilters & abActiveFilters)
                return;
            end
            
            % Alright now that the filters have been dealt with, we have to
            % check if we are supposed to display this message at all based
            % on the globally set output levels and verbosity settings.
            if this.iMinLevel > tPayload.iLevel || this.iMaxVerbosity < tPayload.iVerbosity
                % The message is below the current output level or above
                % the current verbosity level, so we do nothing
                return;
            end
            
            % FINALLY! All checks have been passed and we are ready to
            % display the message. 
            
            % First we get a reference to the timer object to increase the
            % legibility of the code.
            oTimer = this.oSimulationInfrastructure.oSimulationContainer.oTimer;
            
            % If this is the first output message being displayed during
            % this tick, we output some information on the tick and time so
            % the user can pinpoint exactly when this message was
            % triggered. The following messages will of course have been
            % triggered during the same tick.
            if oTimer.iTick > this.iLastTick
                fprintf('\n- - - - - - - - tick: %i / time: %.16fs - - - - - - - -\n', oTimer.iTick, oTimer.fTime);
                
                % Saving the last tick this was output
                this.iLastTick = oTimer.iTick;
                
                % Resetting the last object UUID string property.
                % Explanation see below.
                this.sLastOutObjectUuid = '';
            end
            
            % Since multiple messages can be produced in the same tick by
            % the same object just with different levels and verbosities,
            % we need to check if this is the first message from an
            % individual method or one of the following ones. So first we
            % get the full UUID string consisting of the object's UUID and
            % the method name.
            sFullUuid   = [ tPayload.oObj.sUUID '.' tPayload.sMethod ];
            
            % Now we compare this UUID string with the one that is saved in
            % the sLastOutObjectUuid property of this object.
            bContinuing = strcmp(sFullUuid, this.sLastOutObjectUuid);
            
            if bContinuing
                % We are continuing to print messages from a specific
                % object's method, so we insert some whitespace to align
                % the following message with the previous one, because we
                % will not print the entity and method information again.
                sTemp   = sprintf('[%s][%s]', tPayload.oObj.sEntity, tPayload.sMethod);
                sIndent = repmat(' ', 1, length(sTemp));
                
                % Printing the whitespace
                fprintf('%s[%i]', sIndent, tPayload.iLevel);
            else
                % This is the first message from the object's method so we
                % print the entire header.
                fprintf('[%s][%s][%i]', tPayload.oObj.sEntity, tPayload.sMethod, tPayload.iLevel);
            end
            
            % If an identifier is given in the payload, we print it. 
            if ~isempty(tPayload.sIdentifier)
                fprintf('[%s]', tPayload.sIdentifier);
            end
            
            % Depending on the verbosity level we add some dot characters
            % for indentation. That makes it visually more clear at which
            % level the message is.
            fprintf(repmat('. ', 1, tPayload.iVerbosity));
            
            % Printing the actual message. 
            fprintf(tPayload.sMessage, tPayload.cParams{:});
            
            % And adding a new line character. 
            fprintf('\n');
            
            % If the user selected to also have the stack of the message
            % provider be printed, we do it here. 
            if this.oDebugOutput.bCreateStack
                fprintf('     STACK');
                fprintf(' <- %s', tPayload.tStack(:).name);
                fprintf('\n\n');
            end
            
            % Now that we are done, we set the sLastOutObjectUuid property
            % of the consoleOutput object to the UUID of the message
            % provider so we know the next time this message is called, if
            % it is a continuation of messages from the same object or a
            % message from a different object. 
            this.sLastOutObjectUuid = sFullUuid;
        end
        
        function bOurs = filterObjByRootlineToSimContainer(this, oObj)
            % Makes sure the object belongs to the correct simulation container
            % I don't really understand why this is necessary, but
            % apparently there was concern that the objects that call the
            % out() method could be from different simulation containers.
            % Perhaps when they are running in parallel? In any case, we
            % look at the calling object's rootline and compare it to 'our'
            % simulation container. 
            
            % During initialization, the matter structure not yet created,
            % so we can't run the getObjRootline() helper, but we know it
            % belongs to 'our' sim. (Why do we know? I have no idea...)
            if this.bInitializing == true
                bOurs = this.bInitializing;
                return;
            end
            
            % Getting the rootline from the calling object 
            coRootline = simulation.helper.paths.getObjRootline(oObj);
            
            % If there is a root line at all and the first item is equal to
            % our simulation container, then we return true. 
            bOurs = (length(coRootline) >= 1) && (coRootline{1} == this.oSimulationInfrastructure.oSimulationContainer);
        end
    end
    
    
end

