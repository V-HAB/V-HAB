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
        
        
        % Post-tick stack: after systems are executed, all callbacks on
        % this cell are executed and immediately removed.
        % Preallocating 100 slots, assuming that should be sufficient most
        % of the time. If more callbacks are added in one tick, that means
        % that the first time that might be slower because Matlab needs to
        % extend the cell, the following times - quick again.
        chPostTick = cell(7, 100);
        
        aiPostTickMax = [ 0, 0, 0, 0, 0, 0, 0 ];
        
        iCurrentPostTickExecuting = 0;
        
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
                         
        tbPostTickControl;
        csPostTickGroups;
        
        tiPostTickGroup;
        tiPostTickLevel;
        
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
                    
                    tbPostTickControlFull.(csBasicPostTickGroups{iPostTickGroup}).(['pre_', csPostTicks{iPostTick}])  = logical.empty();
                    tbPostTickControlFull.(csBasicPostTickGroups{iPostTickGroup}).(csPostTicks{iPostTick})            = logical.empty();
                    tbPostTickControlFull.(csBasicPostTickGroups{iPostTickGroup}).(['post_', csPostTicks{iPostTick}]) = logical.empty();
                    
                    this.tiPostTickLevel.(csBasicPostTickGroups{iPostTickGroup}).(csPostTicks{iPostTick}) = iPostTick;
                end
            end
            
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
            % the value to true
            %
            % If the post tick is bound while we are currently executing
            % post ticks, we check if the post tick is from an earlier
            % group. (e.g. massupdate bound during solver stuff). In that
            % case the post tick is executed directly instead of binding
            % the boolean
            if this.iCurrentPostTickGroup < this.tiPostTickGroup.(sPostTickGroup)
                % Post tick is from a later post tick group and level
                this.tbPostTickControl.(sPostTickGroup).(sPostTickLevel)(iPostTickNumber) = true;
            elseif this.iCurrentPostTickGroup == this.tiPostTickGroup.(sPostTickGroup)
                if this.iCurrentPostTickLevel > this.tiPostTickLevel.(sPostTickGroup).(sPostTickLevel)
                    % Post tick is from an earlier post tick group and level
                    this.txPostTicks.(sPostTickGroup).(sPostTickLevel){iPostTickNumber}();
                else
                    % Post tick is from a later post tick group and level
                    this.tbPostTickControl.(sPostTickGroup).(sPostTickLevel)(iPostTickNumber) = true;
                end
            else
                % Post tick is from a later post tick group and level
                this.txPostTicks.(sPostTickGroup).(sPostTickLevel){iPostTickNumber}();
            end
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
            
            % Now we go through the post ticks and execute the registered
            % post ticks.
            for iPostTickGroup = 1:length(this.csPostTickGroups)
                this.iCurrentPostTickGroup = iPostTickGroup;
                
                csLevel = fieldnames(this.txPostTicks.(this.csPostTickGroups{iPostTickGroup}));
                
                for iPostTickLevel = 1:length(csLevel)
                    
                    this.iCurrentPostTickLevel = iPostTickLevel;

                    % To allow post ticks of the same level to be added on
                    % the fly while we are executing this level, we use a
                    % while loop to execute the post ticks till all are
                    % executed
                    while any(this.tbPostTickControl.(this.csPostTickGroups{iPostTickGroup}).(csLevel{iPostTickLevel}))
                        abExecutePostTicks = this.tbPostTickControl.(this.csPostTickGroups{iPostTickGroup}).(csLevel{iPostTickLevel});

                        chPostTicks = this.txPostTicks.(this.csPostTickGroups{iPostTickGroup}).(csLevel{iPostTickLevel});

                        aiPostTicksToExecute = find(abExecutePostTicks);
                        for iIndex = 1:sum(abExecutePostTicks)
                            iPostTick = aiPostTicksToExecute(iIndex);
                            % We set the post tick control for this post
                            % tick to false, before we execute the post
                            % tick, to allow rebinding of other post ticks
                            % in the level during the execution of the
                            % level
                            this.tbPostTickControl.(this.csPostTickGroups{iPostTickGroup}).(csLevel{iPostTickLevel})(iPostTick) = false;
                            chPostTicks{iPostTick}();
                        end
                    end
                end
            end
            
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

