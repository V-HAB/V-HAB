classdef timer < base
    %TIMER The timer handles all timing operations within V-HAB. It
    % contains the logic to decide when the next update should occur and
    % handles post tick updates! 
    
    properties (SetAccess = private, GetAccess = public)
        % Minimum time step, no individual time steps shorter than this one
        % possible.
        fMinimumTimeStep = 1e-8;  % [s]
        
        
        % "Accuracy" of simulation - min time step. Use as
        % precision for rounding.
        iPrecision = 7;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Current time
        fTime = 0;
        
        % Current tick
        iTick = -1;
        
        % Start time
        fStart = 0;
        
        % Timer active?
        bRun = false;
        
        % Callbacks - cell array with all callbacks
        cCallBacks = {};
        
        % Time steps for callbacks
        afTimeStep = [];
        
        % Last execution time for each callback
        afLastExec = [];
        
        % Optional payload for each callback.
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
                         
        % This variable has the same structure as the txPostTickControl
        % property. Here each level does not contain a cell array but
        % instead a boolean vector. The indices of the boolean vector
        % correspond to the indices from the respective cell array in
        % txPostTick and if the boolean value is true the function from the
        % corresponding cell will be executed during the post tick
        % calculation. As for txPostTick the entries of the vector are only
        % added once during the registration of a post tick and after that
        % only the values changes
        tbPostTickControl;
        
        % The fieldnames of the post tick groups from the txPostTick struct
        % are stored in this property to allow looping through them with
        % for loops
        csPostTickGroups;
        % This struct has the post tick groups as fields, and each field
        % contains a cell array with the fieldnames of the corresponding
        % post tick levels (again to enable for loops)
        tcsPostTickLevel;
        
        % this struct contains the post tick groups as fieldnames and the
        % value of each field corresponds to the execution order of that
        % group. So if a group has the value 3 in this property it means
        % that it is the third post tick group that is executed
        tiPostTickGroup;
        % this struct again has the post tick groups as fieldnames and each
        % group has the post tick levels as further field. Each level then
        % contains the execution order of the corresponding level. If a
        % post tick level has an value of 10 here it means that it is the
        % tenth post tick level that is calculated in this group
        tiPostTickLevel;
        
        % in order to decide whether a newly bound post tick is from an
        % earlier group and level as the one we are currently execution
        % these two properties store the corresponding number from
        % tiPostTickGroup and tiPostTickLevel for the currently executing
        % group and level.
        iCurrentPostTickGroup = 0;
        iCurrentPostTickLevel = 0;
    end
    
    methods
        function this = timer(fTimeStep, fStart)
            % Global time step? Default value passed on by simulation.m is
            % 1e-8 seconds
            if nargin >= 1 && ~isempty(fTimeStep)
                this.fMinimumTimeStep = fTimeStep;
            end
            
            if nargin >= 2 && ~isempty(fStart)
                this.fStart = fStart;
                this.fTime  = fStart;
            else
                % Set time to -1 * time step -> first step is init!
                this.fTime = -1 * this.fMinimumTimeStep;
            end
            
            % Precision of simulation. We derive this from the time step
            % and make it 2 orders of magnitude smaller than the timestep
            % in seconds. 
            this.iPrecision = floor(log10(1 / this.fMinimumTimeStep)) - 1;
            
            csBasicPostTickGroups = fieldnames(this.txPostTicks);
            
            iPostTickGroups = length(csBasicPostTickGroups);
            % we want a nicely ordered struct where the order of the fields
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
                    
                    % We also want a post tick control struct that has the
                    % same field structure as the txPostTick struct,
                    % therefore we simply create this here in parallel to
                    % ensure identical structure
                    tbPostTickControlFull.(csBasicPostTickGroups{iPostTickGroup}).(['pre_', csPostTicks{iPostTick}])  = logical.empty();
                    tbPostTickControlFull.(csBasicPostTickGroups{iPostTickGroup}).(csPostTicks{iPostTick})            = logical.empty();
                    tbPostTickControlFull.(csBasicPostTickGroups{iPostTickGroup}).(['post_', csPostTicks{iPostTick}]) = logical.empty();
                end
                % now we can store the fieldnames of both levels of the
                % structs in the properties to make looping trough them
                % easier and faster
                csFullLevels = fieldnames(tbPostTickControlFull.(csBasicPostTickGroups{iPostTickGroup}));
                this.tcsPostTickLevel.(csBasicPostTickGroups{iPostTickGroup}) = csFullLevels;
                
                for iPostTickFull = 1:length(csFullLevels)
                    this.tiPostTickLevel.(csBasicPostTickGroups{iPostTickGroup}).(csFullLevels{iPostTickFull}) = iPostTickFull;
                end
            end
            % And finally the newly created complete structs are set as the
            % new properties
            this.txPostTicks = txPostTicksFull;
            this.tbPostTickControl = tbPostTickControlFull;
            this.csPostTickGroups = fieldnames(this.txPostTicks);
        end


        function setMinStep(this, fMinStep)
            this.fMinimumTimeStep = fMinStep;
            this.iPrecision       = floor(log10(1 / this.fMinimumTimeStep)) - 1;
            this.fTime            = -1 * this.fMinimumTimeStep;
        end
        
        
        function go(this)
            % Run the timer
            
            this.bRun = true;
            
            % Normal step
            this.run();
        end
        
        function step(this)
            % Normal step
            this.run();
        end
        
        function stop(this)
            % Pause / stop the timer - current step is however completely
            % finished and all callbacks executed
            
            this.bRun = false;
        end
        
        
        function [ setTimeStep, unbind ] = bind(this, callBack, fTimeStep, tPayload)
            % Bind a callback
            
            % Payload?
            tPayloadDef = struct('oSrcObj', [], 'sMethod', [], 'sDescription', [], 'cAdditional', {{}});
            
            if nargin >= 4 && isstruct(tPayload)
                csFields = fieldnames(tPayloadDef);
                
                for iF = 1:length(csFields)
                    if ~isfield(tPayload, csFields{iF}), continue; end
                    
                    tPayloadDef.(csFields{iF}) = tPayload.(csFields{iF});
                end
            else
                % At least some info?
                try %#ok
                    tPayloadDef.oSrcObj = evalin('caller', 'this');
                end
                
                tPayloadDef.sMethod = func2str(callBack);
            end
            
            
            % Get index for new callback
            iIdx = length(this.afTimeStep) + 1;
            
            % Callback and last execution time
            this.cCallBacks{iIdx} = callBack;
            this.afLastExec(iIdx) = -inf; % preset with -inf -> always execute in first exec!
            this.ctPayload{iIdx}  = tPayloadDef;
            
            % Time step - provided or use the global
            if nargin >= 3 
                this.afTimeStep(iIdx) = fTimeStep;
            else
                this.afTimeStep(iIdx) = this.fMinimumTimeStep;
            end
            
            % Return the callbacks - protected methods, wrapped so that the
            % parameter for the callback to adjust is always properly set
            %setTimeStep = @(fTimeStep) this.setTimeStep(iIdx, fTimeStep);
            %setTimeStep = @(varargin) this.setTimeStep(iIdx, varargin{:});
            setTimeStep = @(fTimeStep, bReset) this.setTimeStep(iIdx, fTimeStep, nargin >= 2 && bReset);
            
            unbind      = @()          this.unbind(iIdx);
            
            
            % Find dependent timed callbacks (when timer executes)
            this.abDependent = this.afTimeStep == -1;
        end
        
        function hSetPostTick = registerPostTick(this, hCallBackFunctionHandle, sPostTickGroup, sPostTickLevel)
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
            this.txPostTicks.(sPostTickGroup).(sPostTickLevel){end+1} = hCallBackFunctionHandle;
            
            % This index represents the index of the corresponding
            % cell/boolean array in txPostTicks/tbPostTickControl. The
            % value must be unchanged for the whole simulation as it is the
            % link between the specific function binding the post tick and
            % the timer. Therefore the index is directly set as input value
            % for the setPostTick function allowing the caller to simply
            % use that function without inputs thus ensuring the correct
            % values are used.
            iPostTickNumber = length(this.txPostTicks.(sPostTickGroup).(sPostTickLevel));
            
            this.tbPostTickControl.(sPostTickGroup).(sPostTickLevel)(iPostTickNumber) = false;
            
            % To allow the user to easily set the post tick that was
            % registered we return a function handle which already contains
            % the necessary input variables for this specific post tick
            hSetPostTick = @() this.bindPostTick(iPostTickNumber, sPostTickGroup, sPostTickLevel);
        end
        
        function bindPostTick(this, iPostTickNumber, sPostTickGroup, sPostTickLevel)
            % this function is used to bind a post tick update for the
            % calling object and the corresponding post tick group and post
            % tick level. This only works if the post tick was registered
            % at the timer beforehand using the registerPostTick function
            % of the timer! The input parameters are defined as follows:
            %
            % iPostTickNumber: During registration of the post tick, the
            % timer provides an output parameter for the index in the cell
            % and boolean array to which the post tick was bound. That
            % number should be stored in a property of the calling object
            % and provided to this function call
            %
            % sPostTickGroup: Specifies the post tick group in which the
            % corresponding post tick level is located. E.g. 'matter'
            %
            % sPostTickLevel: Specifies the post tick update level e.g. 
            % post_phase_update for a post tick update after the phase
            % update function
            
            % here we only have to set the boolean value to true! Note we
            % do not require any checks if this should be done or not,
            % because they likely take about as much time as just setting
            % the value to true and setting it true mutliply times does not
            % break anything. Note that any calculation put in here takes
            % abnormally long to calculate because of the context changes!
            this.tbPostTickControl.(sPostTickGroup).(sPostTickLevel)(iPostTickNumber) = true;
            
        end
    end
    
    
    methods (Access = protected)
        function unbind(this, iCB)
            % Unbind a callback - iCB is the index in the according
            % attributes storing the callbacks
            
            this.cCallBacks(iCB) = [];
            this.afTimeStep(iCB) = [];
            this.afLastExec(iCB) = [];
            this.ctPayload(iCB)  = [];
        end
        
        function run(this)
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
                fNextExecutionTime = min((this.afLastExec(~this.abDependent) + this.afTimeStep(~this.abDependent)));
                
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
            abExec = (this.afLastExec + this.afTimeStep) <= this.fTime;
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
                    csLevel = this.tcsPostTickLevel.(this.csPostTickGroups{iPostTickGroup});

                    % now loop through the levels of the current group
                    for iPostTickLevel = 1:length(csLevel)

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
                        while any(this.tbPostTickControl.(this.csPostTickGroups{iPostTickGroup}).(csLevel{iPostTickLevel}))
                            abExecutePostTicks = this.tbPostTickControl.(this.csPostTickGroups{iPostTickGroup}).(csLevel{iPostTickLevel});

                            % Now we store the cell array containing the
                            % function handles for easier access
                            chPostTicks = this.txPostTicks.(this.csPostTickGroups{iPostTickGroup}).(csLevel{iPostTickLevel});

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
                                chPostTicks{iPostTick}();
                                % The booelans are set to false after the
                                % calculation to prevent the currently
                                % executing post tick from binding an
                                % update directly again
                                this.tbPostTickControl.(this.csPostTickGroups{iPostTickGroup}).(csLevel{iPostTickLevel})(iPostTick) = false;
                            end
                        end
                    end
                end
                
                % Now we initially assume that all post ticks have been
                % executed and then loop through the tbPostTickControl
                % struct to check if that is true
                bExecutePostTicks = false;
                % now we check if during the post ticks new post ticks were
                % bound and if that is true, execute them:
                for iPostTickGroup = 1:length(this.csPostTickGroups)-1
                    this.iCurrentPostTickGroup = iPostTickGroup;

                    csLevel = this.tcsPostTickLevel.(this.csPostTickGroups{iPostTickGroup});

                    for iPostTickLevel = 1:length(csLevel)
                        if any(this.tbPostTickControl.(this.csPostTickGroups{iPostTickGroup}).(csLevel{iPostTickLevel}))
                            % If any post tick was found that should be
                            % executed we can abort the loop as we will
                            % have to recalculate the while loop anyway
                            bExecutePostTicks = true;
                            break
                        end
                    end
                    
                    if bExecutePostTicks
                        break
                    end
                end
            end
            
            %% TIme Step post physics calculation
            %To ensure that the time step calculation is only performed
            %once at the end of the post tick calculation it is perfomed
            %outside of the while loop
            this.iCurrentPostTickGroup = this.tiPostTickGroup.post_physics;

            csLevel = this.tcsPostTickLevel.post_physics;

            for iPostTickLevel = 1:length(csLevel)

                this.iCurrentPostTickLevel = iPostTickLevel;

                % To allow post ticks of the same level to be added on
                % the fly while we are executing this level, we use a
                % while loop to execute the post ticks till all are
                % executed
                while any(this.tbPostTickControl.post_physics.(csLevel{iPostTickLevel}))
                    abExecutePostTicks = this.tbPostTickControl.post_physics.(csLevel{iPostTickLevel});

                    chPostTicks = this.txPostTicks.post_physics.(csLevel{iPostTickLevel});

                    aiPostTicksToExecute = find(abExecutePostTicks);
                    for iIndex = 1:sum(abExecutePostTicks)
                        iPostTick = aiPostTicksToExecute(iIndex);
                        % We set the post tick control for this post
                        % tick to false, before we execute the post
                        % tick, to allow rebinding of other post ticks
                        % in the level during the execution of the
                        % level
                        chPostTicks{iPostTick}();
                        this.tbPostTickControl.post_physics.(csLevel{iPostTickLevel})(iPostTick) = false;
                        this.mbGlobalPostTickControl(this.tiPostTickGroup.post_physics, iPostTickLevel, iPostTick) = false;
                    end
                end
            end

            % after the post ticks are finished executing the current group
            % and level is set to 0 again to indicate that no post ticks
            % are currently executing
            this.iCurrentPostTickGroup = 0;
            this.iCurrentPostTickLevel = 0;
            
            % check for bRun -> if true, execute this.step() again!
            if this.bRun
                this.run();
            end
            
        end
        
        function setTimeStep(this, iCB, fTimeStep, bResetLastExecuted)
            % Set time step for a specific call back. Protected method, is
            % returned upon .bind!
            
            % Find dependent timed callbacks (when timer executes)
            this.abDependent(iCB) = (fTimeStep == -1);
            
            
            if ~isempty(fTimeStep)
                if fTimeStep < 0, fTimeStep = 0; end
                
                this.afTimeStep(iCB) = fTimeStep;
            else
                this.afTimeStep(iCB) = 0;
            end
            
            % If bResetLastExecuted is true, the time the registered call-
            % back was last executed will be updated to the current time.
            if nargin >= 4 && ~isempty(bResetLastExecuted) && bResetLastExecuted && (this.afLastExec(iCB) ~= this.fTime)
                
                this.afLastExec(iCB) = this.fTime;
            end
        end
    end
end