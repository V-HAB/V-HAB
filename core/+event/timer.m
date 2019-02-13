classdef timer < base
    %TIMER The timer handles all timing operations within V-HAB. It
    % contains the logic to decide when the next update should occur and
    % handles post tick updates! 
    
    % Thou shall not have any other timers beside me... There can only be
    % one timer object, so the SetAccess for all properties is private. 
    properties (SetAccess = private, GetAccess = public)
        % Minimum time step, no individual time steps shorter than this one
        % possible.
        fMinimumTimeStep = 1e-8;  % [s]
        
        % "Accuracy" of simulation - represent the number of digits after
        % the decimal sign which are considered valid in the simulation
        % itself. For example for the value of 20 all values smaller than
        % 10^-20 will be rounded to zero
        iPrecision = 20;
    
        % Current time
        fTime = 0;
        
        % Current tick
        iTick = -1;
        
        % Start time
        fStart = 0;
        
        % Callbacks - cell array with all callbacks
        cCallBacks = {};
        
        % Time steps for callbacks
        afTimeSteps = [];
        
        % Last execution time for each callback
        afLastExec = [];
        
        % Optional payload for each callback
        ctPayload = {};
        
        % Time steps == -1 --> execute when timer executes, NOT in global
        % time step (0 would mean global timestep, leading to the timer
        % being required to execute every global TS. If -1, and the
        % smallest TS of any other sys is larger then global TS, timer
        % executes the larger TSs).
        abDependent = [];
        
        % This structs orders the different post tick functions (like phase
        % massupdate and update) into a specific execution order (just as
        % it is written here from top to bottom). There are four groups of
        % post ticks, matter, electrical, thermal and post_physics (which
        % contains the time step calculations). Each group contains
        % multiple post tick levels defining the order of execution within
        % the post tick group. The functions containing the calculations
        % that should be executed are bound as function handles to the
        % corresponding post tick level cell array when a post tick is
        % registered. This only occurs once, therefore the struct contains
        % all post ticks in the simulation, regardless if they are executed
        % in this tick or not. In order to decide which post ticks are
        % executed a struct with the same structure containing boolean
        % values is used. Additionally to the levels shown here a pre_ and
        % post_ level for each of the levels is generated during timer
        % definition, allowing the user to bind specific functions to be
        % executed either before or after a specific calculation
        txPostTicks = struct('matter', struct(...
                                'store_update', cell.empty(),...
                                'phase_massupdate', cell.empty(),...
                                'phase_update', cell.empty(),...
                                'solver', cell.empty(),...
                                'P2Ps', cell.empty(),...
                                'manips', cell.empty(),...
                                'multibranch_solver', cell.empty(),...
                                'residual_solver', cell.empty()),...
                             ...
                             'electrical', struct(...
                                'circuits', cell.empty()),...
                             ...
                             'thermal', struct(...
                                'capacity_temperatureupdate', cell.empty(),...
                                'capacity_update', cell.empty(),...
                                'solver', cell.empty(),...
                                'heatsources', cell.empty(),...
                                'multibranch_solver', cell.empty(),...
                                'residual_solver', cell.empty()),...
                             ...
                             'post_physics', struct(...
                                'timestep', cell.empty()));
                         
        
        % The fieldnames of the post tick groups from the txPostTick struct
        % are stored in this property to allow looping through them with
        % for loops. 
        csPostTickGroups;
        
        % This struct has the post tick groups as fields, and each field
        % contains a cell array with the fieldnames of the corresponding
        % post tick levels (again to enable for loops)
        tcsPostTickLevel;
        
        % These two properties can be used to translate the first two
        % indices from one of the three dimensional arrays (chPostTicks and
        % mbPostTickControl) into the corresponding post tick group and
        % level. For example the entries chPostTicks{2,3,:} are from the
        % second post tick group (electrical) and the third post tick level
        % (in this case post_circuit). Remember that for each level defined
        % in the struct above a pre_ and post_ level is added!
        
        % This struct contains the post tick groups as fieldnames and the
        % value of each field corresponds to the execution order of that
        % group. So if a group has the value 3 in this property it means
        % that it is the third post tick group that is executed
        tiPostTickGroup;
        
        % This struct again has the post tick groups as fieldnames and each
        % group has the post tick levels as further field. Each level then
        % contains the execution order of the corresponding level. If a
        % post tick level has an value of 10 here it means that it is the
        % tenth post tick level that is calculated in this group
        tiPostTickLevel;
        
        % For faster calculations the verbose struct txPostTicks is
        % internally translated into a three dimensional cell array. The
        % first dimension represents the post tick groups with the indices
        % corresponding to the values from the tiPostTickGroup struct. The
        % second dimension represents the post tick levels with the indices
        % corresponding to the values from the tiPostTickLevel struct. Then
        % the same handle vector as in txPostTicks with identical indices
        % is the third dimension.
        chPostTicks;
        
        % mbPostTickControl is a three dimensional boolean array. The first
        % dimension represents the post tick groups with the indices
        % corresponding to the values from the tiPostTickGroup struct. The
        % second dimension represents the post tick levels with the indices
        % corresponding to the values from the tiPostTickLevel struct. The
        % indices of the boolean vector correspond to the indices from the
        % respective cell array in txPostTick (or chPostTicks) and if the
        % boolean value is true the function from the corresponding cell
        % will be executed during the post tick calculation. As for
        % txPostTick the entries of the vector are only added once during
        % the registration of a post tick and after that only the values
        % changes
        mbPostTickControl;
        
        % In order to decide whether a newly bound post tick is from an
        % earlier group and level as the one we are currently execution
        % these two properties store the corresponding number from
        % tiPostTickGroup and tiPostTickLevel for the currently executing
        % group and level.
        iCurrentPostTickGroup = 0;
        iCurrentPostTickLevel = 0;
        
        % Also for faster operation, the corresponding number of post tick
        % levels for each post tick group index from tiPostTickGroup is
        % stored here
        aiNumberOfPostTickLevel;
        
    end
    
    methods
        function this = timer(fMinimumTimeStep, fStart)
            % Parsing the minimum timestep input argument, if it is given
            if nargin >= 1 && ~isempty(fMinimumTimeStep)
                this.fMinimumTimeStep = fMinimumTimeStep;
            end
            
            % Parsing the start time input argument, if it is given
            if nargin >= 2 && ~isempty(fStart)
                this.fStart = fStart;
                this.fTime  = fStart;
            else
                % Set time to -1 * time step -> first step is for initialization
                this.fTime = -1 * this.fMinimumTimeStep;
            end
            
            % Getting the field names of the post tick entries
            csBasicPostTickGroups = fieldnames(this.txPostTicks);
            
            % Initializing some local variables for later use
            iPostTickGroups = length(csBasicPostTickGroups);
            iPostTickLevels = 0;
            
            % We want a nicely ordered struct where the order of the fields
            % also represents the execution order in V-HAB, for that
            % purpose we create a new struct with the same order of the
            % property txPostTicks but add a pre_ and post_ field for every
            % defined post tick. This results in the correctly structured
            % post tick struct, where the order of the fieldnames also
            % defines the execution order within V-HAB (group from top to
            % bottom, each groups ticks are executed before the next group
            % is executed)
            for iPostTickGroup = 1:iPostTickGroups
                csPostTicks = fieldnames(this.txPostTicks.(csBasicPostTickGroups{iPostTickGroup}));
                
                this.tiPostTickGroup.(csBasicPostTickGroups{iPostTickGroup}) = iPostTickGroup;
                for iPostTick = 1:length(csPostTicks)
                    txPostTicksFull.(csBasicPostTickGroups{iPostTickGroup}).(['pre_', csPostTicks{iPostTick}])  = cell.empty();
                    txPostTicksFull.(csBasicPostTickGroups{iPostTickGroup}).(csPostTicks{iPostTick})            = cell.empty();
                    txPostTicksFull.(csBasicPostTickGroups{iPostTickGroup}).(['post_', csPostTicks{iPostTick}]) = cell.empty();
                end
                % Now we can store the fieldnames of both levels of the
                % structs in the properties to make looping trough them
                % easier and faster
                csFullLevels = fieldnames(txPostTicksFull.(csBasicPostTickGroups{iPostTickGroup}));
                this.tcsPostTickLevel.(csBasicPostTickGroups{iPostTickGroup}) = csFullLevels;
                
                this.aiNumberOfPostTickLevel(iPostTickGroup) = length(csFullLevels);
                
                for iPostTickLevelFull = 1:length(csFullLevels)
                    if iPostTickLevels < iPostTickLevelFull
                        iPostTickLevels = iPostTickLevelFull;
                    end
                    this.tiPostTickLevel.(csBasicPostTickGroups{iPostTickGroup}).(csFullLevels{iPostTickLevelFull}) = iPostTickLevelFull;
                end
            end
            
            % And finally the newly created complete structs are set as the
            % new properties, where mbPostTickControl and csPostTickGroups
            % are not structs, but a matrix and a cell that are more
            % perfomant to use when actually executing the callbacks. 
            this.txPostTicks = txPostTicksFull;
            this.mbPostTickControl = logical.empty(iPostTickGroups,iPostTickLevels,0);
            this.csPostTickGroups = fieldnames(this.txPostTicks);
        end

        function setMinStep(this, fMinStep)
            %SETMINSTEP Sets the minimum time step of the solver
            this.fMinimumTimeStep = fMinStep;
            this.fTime            = -1 * this.fMinimumTimeStep;
        end
        
        function setSimulationPrecision(this, iPrecision)
            %SETSIMULATIONPRECISION Allows the user to set the overall precision of the V-HAB Simulation
            % All flowrates smaller than the precision (regardless of
            % matter, thermal or electrical domain) will be rounded to
            % zero. The precision represent the number of digits after the
            % decimal sign which are considered valid in the simulation
            % itself. For example for the value of 20 all values smaller
            % than 10^-20 will be rounded to zero
            this.iPrecision = iPrecision;
        end
        
        function [ hSetTimeStep, hUnbind ] = bind(this, hCallBack, fTimeStep, tInputPayload)
            %BIND Registers a callback with the timer object to be executed
            %   The provided hCallBack handle will be executed at the given
            %   fTimeStep. The tInputPayload struct is mainly for debugging
            %   purposes, its content will be used to provide input for the
            %   out() method in the base class. 
            
            % Initializing a local variable for the payload with the
            % allowed struct fields, the first three should always be
            % provided, though. 
            tPayload = struct('oSrcObj', [], 'sMethod', [], 'sDescription', [], 'cAdditional', {{}});
            
            % Check if a payload was provided and if it is a struct.
            if nargin >= 4 && isstruct(tInputPayload)
                % Getting a struct with the allowed field names
                csPayloadFields = fieldnames(tPayload);
                
                % Looping through all allowed fields of the payload
                for iField = 1:length(csPayloadFields)
                    
                    % If the field doesn't exist in the provided input
                    % payload, we skip ahead to the next possible field.
                    if ~isfield(tInputPayload, csPayloadFields{iField})
                        continue
                    end
                    
                    % The field exists, so we copy its contents to the
                    % actual payload struct.
                    tPayload.(csPayloadFields{iField}) = tInputPayload.(csPayloadFields{iField});
                end
            else
                % No payload was provided or it was not a struct, so we try
                % to get at least the source object by polling the 'this'
                % variable in the caller object.
                try %#ok No catch block because what would we do?
                    tPayload.oSrcObj = evalin('caller', 'this');
                end
                
                % The callback must be provided, so we'll always have that.
                tPayload.sMethod = func2str(hCallBack);
            end
            
            % Get index for new callback
            iIdx = length(this.afTimeSteps) + 1;
            
            % Add the callback to the cCallBacks property
            this.cCallBacks{iIdx} = hCallBack;
            
            % Setting the afLastExec property for this specific callback.
            % Is initialized with -inf so it is always executed during the
            % first step after binding. After that first step, the last
            % execution time will be logged here. 
            this.afLastExec(iIdx) = -inf;
            
            % Adding the per-callback payload struct to the appropriate
            % property
            this.ctPayload{iIdx}  = tPayload;
            
            % Setting the time step for this callback using either the one
            % the caller provided or the minimum time step.
            if nargin >= 3 
                this.afTimeSteps(iIdx) = fTimeStep;
            else
                this.afTimeSteps(iIdx) = this.fMinimumTimeStep;
            end
            
            % Return the callbacks - protected methods, wrapped so that the
            % parameter for the callback to adjust is always properly set
            hSetTimeStep = @(fTimeStep, bReset) this.setTimeStep(iIdx, fTimeStep, nargin >= 2 && bReset);
            
            % Set the unbind callback as the return variabel
            hUnbind = @() this.unbind(iIdx);
            
            
            % Update the property that lists the dependent timed callbacks,
            % these always execute when the timer executes.
            this.abDependent = this.afTimeSteps == -1;
        end
        
        function hSetPostTick = registerPostTick(this, hCallBackFunctionHandle, sPostTickGroup, sPostTickLevel)
            %REGISTERPOSTTICK Registers a post tick function handle
            % This function must be used to initialy register all post tick
            % updates at the timer. This enables the usage of a (mostly)
            % static cell array for the post tick and a boolean vector for
            % the different levels to decide what must be updated in this
            % tick, which should improve performance. The required inputs
            % of the function are:
            %
            % hCallBackFunctionHandle: Function handle of the callback,
            % provided e.g. with the syntax @this.update
            %
            % sPostTickGroup: Specifies the post tick group in which the
            % corresponding post tick level is located. E.g. 'matter'
            %
            % sPostTickLevel: Specifies the post tick update level e.g. 
            % post_phase_update for a post tick update after the phase
            % update function
            
            % Adding the function handle to the struct of post ticks
            this.txPostTicks.(sPostTickGroup).(sPostTickLevel){end+1} = hCallBackFunctionHandle;
            
            % The following three indexs represent the indexes of the
            % corresponding cell/boolean array in txPostTicks and
            % tbPostTickControl. The value must remain unchanged for the
            % entire simulation as it is the link between the specific
            % function binding the post tick and the timer. Therefore the
            % indexes are directly set as input value for the
            % bindPostTick() method below, allowing the caller to simply
            % use the created function handle without inputs thus ensuring
            % the correct values are used.
            iPostTickNumber = length(this.txPostTicks.(sPostTickGroup).(sPostTickLevel));
            iPostTickGroup = this.tiPostTickGroup.(sPostTickGroup);
            iPostTickLevel = this.tiPostTickLevel.(sPostTickGroup).(sPostTickLevel);
            
            % Addin the callback to the cell property
            this.chPostTicks{iPostTickGroup, iPostTickLevel, iPostTickNumber} = hCallBackFunctionHandle;
            
            % Initializing the appropriate item in the mbPostTickControl matrix
            % with a logical false, so it is not executed at first. 
            this.mbPostTickControl(iPostTickGroup, iPostTickLevel, iPostTickNumber) = false;
            
            % To allow the user to easily set the post tick that was
            % registered we return a function handle which already contains
            % the necessary input variables for this specific post tick
            hSetPostTick = @() this.bindPostTick(iPostTickGroup, iPostTickLevel, iPostTickNumber);
        end
        
        function bindPostTick(this, iPostTickGroup, iPostTickLevel, iPostTickNumber)
            %BINDPOSTTICK Activates a specific post tick callback
            % This function is used to bind a post tick update for the
            % calling object and the corresponding post tick group and post
            % tick level. This only works if the post tick was registered
            % at the timer beforehand using the registerPostTick function
            % of the timer! The input parameters are defined as follows:
            %
            % iPostTickGroup: Specifies the post tick group in which the
            % corresponding post tick level is located. E.g. for the post
            % tick group matter the index must be this.tiPostTickGroups.matter
            %
            % iPostTickLevel: Specifies the post tick update level e.g. 
            % for the level post_phase_update the index must be 
            % this.tiPostTickGroups.matter.post_phase_update 
            %
            % iPostTickNumber: During registration of the post tick, the
            % timer provides an output parameter for the index in the cell
            % and boolean array to which the post tick was bound. That
            % number should be stored in a property of the calling object
            % and provided to this function call
            
            % Here we only have to set the boolean value to true! Note we
            % do not require any checks if this should be done or not,
            % because they likely take about as much time as just setting
            % the value to true and setting it true mutliply times does not
            % break anything. Note that any calculation put in here takes
            % abnormally long to calculate because of the context changes!
            this.mbPostTickControl(iPostTickGroup, iPostTickLevel, iPostTickNumber) = true;
        end
    
        function unbind(this, iCB)
            %UNBIND Unbinds a callback 
            % iCB is the index in the according properties storing the
            % callbacks
            
            this.cCallBacks(iCB)  = [];
            this.afTimeStep(iCB)  = [];
            this.abDependent(iCB) = [];
            this.afLastExec(iCB)  = [];
            this.ctPayload(iCB)   = [];

        end
    end
    
    
    % The setTimeStep() method should only be accessible to the timer
    % itself, so we set the access to private.
    methods (Access = private)
    
        function setTimeStep(this, iCB, fTimeStep, bResetLastExecuted)
            % Set time step for a specific call back. Protected method, is
            % returned upon .bind!
            
            % Find dependent timed callbacks (when timer executes)
            this.abDependent(iCB) = (fTimeStep == -1);
            
            
            if ~isempty(fTimeStep)
                if fTimeStep < 0, fTimeStep = 0; end
                
                this.afTimeSteps(iCB) = fTimeStep;
            else
                this.afTimeSteps(iCB) = 0;
            end
            
            % If bResetLastExecuted is true, the time the registered call-
            % back was last executed will be updated to the current time.
            if nargin >= 4 && ~isempty(bResetLastExecuted) && bResetLastExecuted && (this.afLastExec(iCB) ~= this.fTime)
                
                this.afLastExec(iCB) = this.fTime;
            end
        end
        
    end
    
    
    % Only the simulation.infrastructore object is allowed to call the
    % tick() method, so we restrict the access here. 
    methods (Access = {?simulation.infrastructure})
        
        function tick(this)
            % Advance the timer one (global) time step
            
            % If time is -1 the min. time step - first tick, advance to zero
            %if this.fTime == (-1 * this.fTimeStep)
            %TODO throw out here. Include in solvers themselves.
            if this.fTime <= (10 * this.fMinimumTimeStep)
                fThisStep = this.fMinimumTimeStep;
            else
                % Determine next time step. Calculate last execution time plus
                % current time step for every system that is not dependent,
                % i.e. that has a 'real' time step set, not -1 which means that
                % it is executed every timer tick.
                fNextExecutionTime = min((this.afLastExec(~this.abDependent) + this.afTimeSteps(~this.abDependent)));
                
                % fNextExecutionTime is an absolute time, so subtract the
                % current time to get the time step for this tick
                fThisStep = fNextExecutionTime - this.fTime;
            end
            
            % Calculated step smaller than the min. time step?
            %TODO if one system has a time step of 0, the above calculation
            %      with last exec/time step would be unnecessary, in that
            %      case, directly set this.fTimeStep as fThisStep!
            if fThisStep < this.fMinimumTimeStep
                fThisStep = this.fMinimumTimeStep;
            end
            
            % Set new time
            this.fTime = this.fTime + fThisStep;
            this.iTick = this.iTick + 1;
            
            % Find all cb's indices whose last exec + time step <= fTime
            % Dependent systems have -1 as time step - therefore this
            % should always be true!
            abExec = (this.afLastExec + this.afTimeSteps) <= this.fTime;
            aiExec  = find(abExec);
            
            %% Execute callbacks
            % Executes all components that registered a time step with the
            % timer that must be executed at the current time
            for iE = 1:length(aiExec)
                this.cCallBacks{aiExec(iE)}(this);
                
                if ~base.oLog.bOff
                    tPayload = this.ctPayload{aiExec(iE)};

                    this.out(1, 1, 'exec', 'Exec callback %i: %s', { aiExec(iE) func2str(this.cCallBacks{aiExec(iE)}) });

                    if isempty(tPayload.oSrcObj)
                        this.out(1, 2, 'run', 'Payload - Method Name: %s, Bind Decsription: %s', { tPayload.sMethod, tPayload.sDescription });
                    else
                        this.out(1, 2, 'payload', '** Payload **');
                        this.out(1, 2, 'payload', 'Method Name: %s', { tPayload.sMethod });
                        this.out(1, 2, 'payload', 'Source Obj Entity %s', { tPayload.oSrcObj.sEntity });
                        this.out(1, 3, 'payload', 'Src Obj UUID %s', { tPayload.oSrcObj.sUUID });
                        this.out(1, 3, 'payload', 'Bind Description: "%s"', { tPayload.sDescription });
                    end
                end
            end
            
            
            % Update last execution time - see above, abExec is logical, so
            % this works, don't need find!
            this.afLastExec(abExec) = this.fTime;
            
            
            if ~base.oLog.bOff
                this.out(1, 1, 'post-tick', 'Running post-tick tasks!');
                this.out(1, 2, 'post-tick-num', 'Amount of cbs: %i\t', { this.aiPostTickMax });
            end
            
            %% Execute Post Ticks
            % For information on execution order view the description of
            % the txPostTick property!
            % Now we go through the post ticks and execute the registered
            % post ticks in the correct order.
            
            % A while loop is used because it is possible that during a
            % post tick calculation earlier post ticks are bound again. In
            % that case the while loop iterates through the post tick
            % executiong until no post ticks to be executed remain.
            bExecutePostTicks = true;
            while bExecutePostTicks
                % Now we loop through the groups, except for the last
                % (post_physics) group. We do not want to execute that
                % during the while loop as it would be possible that the
                % time step calculation is executed and after it flowrates
                % change (which would not be considered then till the next
                % execution)
                for iPostTickGroup = 1:length(this.csPostTickGroups)-1
                    % Set the property for which post tick group is
                    % currently beeing executed
                    this.iCurrentPostTickGroup = iPostTickGroup;
                    
                    % get the post tick level names
                    iTotalLevel = this.aiNumberOfPostTickLevel(iPostTickGroup);
                    
                    % now loop through the levels of the current group
                    for iPostTickLevel = 1:iTotalLevel

                        this.iCurrentPostTickLevel = iPostTickLevel;

                        % To allow post ticks of the same level to be added on
                        % the fly while we are executing this level, we use a
                        % while loop to execute the post ticks till all are
                        % executed. Note that it is necessary here to
                        % access the property directly as its contents can
                        % change during the while loop (a new value beeing
                        % set to true for example). For the same reason we
                        % have to get the abExecutePostTicks in each
                        % iteration of the loop
                        while any(this.mbPostTickControl(iPostTickGroup, iPostTickLevel, :))
                            abExecutePostTicks = this.mbPostTickControl(iPostTickGroup, iPostTickLevel, :);

                            % Now we store the cell array containing the
                            % function handles for easier access
                            chCurrentPostTicks = this.chPostTicks(iPostTickGroup, iPostTickLevel,:);

                            % And get the indices that should be executed
                            % in this tick
                            aiPostTicksToExecute = find(abExecutePostTicks);
                            % Then we can loop through all of these indices
                            % (only the once that should be executed) and
                            % call their functions
                            for iIndex = 1:sum(abExecutePostTicks)
                                iPostTick = aiPostTicksToExecute(iIndex);
                                % We set the post tick control for this post
                                % tick to false, before we execute the post
                                % tick, to allow rebinding of other post ticks
                                % in the level during the execution of the
                                % level
                                chCurrentPostTicks{iPostTick}();
                                % The booelans are set to false after the
                                % calculation to prevent the currently
                                % executing post tick from binding an
                                % update directly again
                                this.mbPostTickControl(iPostTickGroup, iPostTickLevel, iPostTick) = false;
                            end
                        end
                    end
                end
                
                % Now we check the boolean matrix except for the last post
                % tick group (which is the post physics group) if any new
                % post ticks where set during execution of the previous
                % ones, and if that is the case we iterate the post tick
                % calculations
                bExecutePostTicks = any(any(any(this.mbPostTickControl(1:end-1,:,:))));
            end
            
            %% TIme Step post physics calculation
            %To ensure that the time step calculation is only performed
            %once at the end of the post tick calculation it is perfomed
            %outside of the while loop
            iPostTickGroup = this.tiPostTickGroup.post_physics;
            this.iCurrentPostTickGroup = iPostTickGroup;
            iTotalLevel = this.aiNumberOfPostTickLevel(iPostTickGroup);

            for iPostTickLevel = 1:iTotalLevel

                this.iCurrentPostTickLevel = iPostTickLevel;

                % To allow post ticks of the same level to be added on
                % the fly while we are executing this level, we use a
                % while loop to execute the post ticks till all are
                % executed
                while any(this.mbPostTickControl(iPostTickGroup, iPostTickLevel, :))
                    abExecutePostTicks = this.mbPostTickControl(iPostTickGroup, iPostTickLevel, :);

                    chCurrentPostTicks = this.chPostTicks(iPostTickGroup, iPostTickLevel,:);

                    aiPostTicksToExecute = find(abExecutePostTicks);
                    for iIndex = 1:sum(abExecutePostTicks)
                        iPostTick = aiPostTicksToExecute(iIndex);
                        % We set the post tick control for this post
                        % tick to false, before we execute the post
                        % tick, to allow rebinding of other post ticks
                        % in the level during the execution of the
                        % level
                        chCurrentPostTicks{iPostTick}();
                        this.mbPostTickControl(iPostTickGroup, iPostTickLevel, iPostTick) = false;
                    end
                end
            end

            % after the post ticks are finished executing the current group
            % and level is set to 0 again to indicate that no post ticks
            % are currently executing
            this.iCurrentPostTickGroup = 0;
            this.iCurrentPostTickLevel = 0;
        end
    end
end