classdef timer < base
    %TIMER Timer object. Provides similar interface as events.source.
    %   Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public)
        % Minimum time step, no individual time steps shorter than this one
        % possible.
        % @type float
        fMinimumTimeStep = 1e-8;  % [s]
        
        
        % "Accuracy" of simulation - min time step. Use as
        % precision for rounding.
        % @type int
        iPrecision = 7;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Current time
        % @type float
        fTime = 0;
        
        % Current tick
        % @type int
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
            
        end


        function setMinStep(this, fMinStep)
            this.fMinimumTimeStep = fMinStep;
            this.iPrecision       = floor(log10(1 / this.fMinimumTimeStep)) - 1;
            this.fTime            = -1 * this.fMinimumTimeStep;
        end
        
        
        function go(this)
            % Run the timer
            
            this.bRun = true;
            
            % If this is the initial run (fTime is zero), call ALL
            % callbacks!
%             if this.fTime == 0
%                 cellfun(@(cb) cb(this), this.cCallBacks);
%             end
            
            % Normal step
            this.run();
        end
        
        function step(this)
            
            % If this is the initial run (fTime is zero), call ALL
            % callbacks!
%             if this.fTime == 0
%                 cellfun(@(cb) cb(this), this.cCallBacks);
%             end
            
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
                    if ~isfield(tPayload, csFields{iF}), continue; end;
                    
                    tPayloadDef.(csFields{iF}) = tPayload.(csFields{iF});
                end
            else
                % At least some info?
                try %#ok<TRYNC>
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
            if nargin >= 3, this.afTimeStep(iIdx) = fTimeStep;
            else            this.afTimeStep(iIdx) = this.fMinimumTimeStep;
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
        
        
        function bindPostTick(this, hCB, iPriority)
            if nargin < 3 || isempty(iPriority), iPriority = 0; end;
            
            iPriority = iPriority + 4;
            
            %this.chPostTick{end + 1} = hCB;
            this.aiPostTickMax(iPriority) = this.aiPostTickMax(iPriority) + 1;
            this.chPostTick{iPriority, this.aiPostTickMax(iPriority)} = hCB;
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
            %abExec = (this.afLastExec + this.afTimeStep) <= (this.fTime + fThisStep - this.fMinimumTimeStep);
            aiExec  = find(abExec);
            
            % Execute callbacks
            for iE = 1:length(aiExec)
                this.cCallBacks{aiExec(iE)}(this);
                
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
            
            
            % Update last execution time - see above, abExec is logical, so
            % this works, don't need find!
            this.afLastExec(abExec) = this.fTime;
            
            
            this.out(1, 1, 'post-tick', 'Running post-tick tasks!');
            this.out(1, 2, 'post-tick-num', 'Amount of cbs: %i\t', { this.aiPostTickMax });
            
            % Just to make sure - prio 2 could attach postTick to prio -1
            while any(this.aiPostTickMax ~= 0)
                % Prios from -3, -2, -1, 0, 1, 2, 3
                for iP = 1:7
                    % Post-tick stack
                    iPostTick = 1;

                    % iPostTickMax can change in interation!
                    while iPostTick <= this.aiPostTickMax(iP)
                        % Executing the first item in the stack, represented by the
                        % first item in the cell array
                        this.chPostTick{iP, iPostTick}();

                        iPostTick = iPostTick + 1;
                    end

                    this.aiPostTickMax(iP) = 0;
                end
            end
            
            % check for bRun -> if true, execute this.step() again!
            if this.bRun
                this.run();
            end
            
        end
        
        function setTimeStep(this, iCB, fTimeStep, bResetLastExecuted)
            % Set time step for a specific call back. Protected method, is
            % returned upon .bind!
            
            
            
            % Find dependent timed callbacks (when timer executes)
            %this.abDependent = this.afTimeStep == -1;
            this.abDependent(iCB) = (fTimeStep == -1);
            
            
            if ~isempty(fTimeStep) % && fTimeStep ~= 0
                if fTimeStep < 0, fTimeStep = 0; end;
                
                this.afTimeStep(iCB) = fTimeStep;
            else
                %TODO could be 
                this.afTimeStep(iCB) = 0;%this.fTimeStep;
            end
            
            
            
            % If bResetLastExecuted is true, the time the registered call-
            % back was last executed will be updated to the current time.
            if nargin >= 4 && ~isempty(bResetLastExecuted) && bResetLastExecuted && (this.afLastExec(iCB) ~= this.fTime)
                
                this.afLastExec(iCB) = this.fTime;
            end
        end
    end
end

