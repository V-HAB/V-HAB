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
        
        % Time steps == -1 --> execute when timer executes, NOT in global
        % time step (0 would mean global timestep, leading to the timer
        % being required to execute every global TS. If -1, and the
        % smallest TS of any other sys is larger then global TS, timer
        % executes the larger TSs).
        abDependent = [];
        
        
        % Post-tick stack: after systems are executed, all callbacks on
        % this cell are executed and immediately removed.
        chPostTick = {};
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
        
        
        function [ setTimeStep, unbind ] = bind(this, callBack, fTimeStep)
            % Bind a callback
            
            % Get index for new callback
            iIdx = length(this.afTimeStep) + 1;
            
            % Callback and last execution time
            this.cCallBacks{iIdx} = callBack;
            this.afLastExec(iIdx) = -inf; % preset with -inf -> always execute in first exec!
            
            % Time step - provided or use the global
            if nargin >= 3, this.afTimeStep(iIdx) = fTimeStep;
            else            this.afTimeStep(iIdx) = this.fMinimumTimeStep;
            end
            
            % Return the callbacks - protected methods, wrapped so that the
            % parameter for the callback to adjust is always properly set
            setTimeStep = @(fTimeStep) this.setTimeStep(iIdx, fTimeStep);
            unbind      = @()          this.unbind(iIdx);
            
            
            % Find dependent timed callbacks (when timer executes)
            this.abDependent = this.afTimeStep == -1;
        end
        
        
        function bindPostTick(this, hCB)
            this.chPostTick{end + 1} = hCB;
        end
    end
    
    
    methods (Access = protected)
        function unbind(this, iCB)
            % Unbind a callback - iCB is the index in the according
            % attributes storing the callbacks
            
            this.cCallBacks(iCB) = [];
            this.afTimeStep(iCB) = [];
            this.afLastExec(iCB) = [];
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
%                 disp('Setting minimum time step.');
%                 keyboard();
                fThisStep = this.fMinimumTimeStep;
            end
            
            % Set new time
            this.fTime = this.fTime + fThisStep;
            this.iTick = this.iTick + 1;
            
            % Find all cb's indices whose last exec + time step <= fTime
            % Dependent systems have -1 as time step - therefore this
            % should always be true!
            %abExec = this.afLastExec + this.afTimeStep <= this.fTime;
            %TODO Add an extensive explanation here on why the expression
            % that is being compared here is exactly this:
            % 'this.fTime + fThisStep - this.fMinimumTimeStep'
            % Explain what this does to the abExec array. 
            abExec = (this.afLastExec + this.afTimeStep) <= (this.fTime + fThisStep - this.fMinimumTimeStep);
%             sString = '%i';
%             for iI=1:length(abExec)-1
%                 sString = strcat(sString,' %i');
%             end
%             sString = strcat(sString,'\n');
%             fprintf(sString,abExec);
            
            % Execute found cbs
            % The indexing type for the cell only works if the array is of
            % real logical / boolean type!
            cellfun(@(cb) cb(this), this.cCallBacks(abExec));
            
            % Update last execution time - see above, abExec is logical, so
            % this works, don't need find!
            this.afLastExec(abExec) = this.fTime;
            
            
            % Post-tick stack
            while ~isempty(this.chPostTick)
                % Executing the first item in the stack, represented by the
                % first item in the cell array
                this.chPostTick{1}();
                
                % Removing the item we just executed
                this.chPostTick(1) = [];
            end
            
            % check for bRun -> if true, execute this.step() again!
            if this.bRun
                this.run();
            end
            
%             fNextExecutionTime = min((this.afLastExec(~this.abDependent) + this.afTimeStep(~this.abDependent)));
%             if fNextExecutionTime == this.fTime
%                 fprintf('\b, Time: %.10f, Tick: %i\n',this.fTime, this.iTick);
% %                 keyboard();
%             end
        end
        
        function setTimeStep(this, iCB, fTimeStep)
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
            
        end
    end
end

