classdef timer < base
    %TIMER Timer object. Provides similar interface as events.source.
    %   Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public)
        % Master/Global time step, all other time steps have to be longer
        % than that - however not a 'real' multiple of that.
        % Fixed, can't be changed
        fTimeStep = 1;  % [s]
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Current time
        fTime = 0;
        
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
    end
    
    methods
        function this = timer(fTimeStep, fStart)
            % Global time step?
            if nargin >= 1 && ~isempty(fTimeStep)
                this.fTimeStep = fTimeStep;
            end
            
            if nargin >= 2 && ~isempty(fStart)
                this.fStart = fStart;
                this.fTime  = fStart;
            else
                % Set time to -1 * time step -> first step is init!
                this.fTime = -1 * this.fTimeStep;
            end
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
        
        
        function [ setTimeStep unbind ] = bind(this, callBack, fTimeStep)
            % Bind a callback
            
            % Get index for new callback
            iIdx = length(this.afTimeStep) + 1;
            
            % Callback and last execution time
            this.cCallBacks{iIdx} = callBack;
            this.afLastExec(iIdx) = -inf; % preset with -inf -> always execute in first exec!
            
            % Time step - provided or use the global
            if nargin >= 3, this.afTimeStep(iIdx) = fTimeStep;
            else            this.afTimeStep(iIdx) = this.fTimeStep;
            end
            
            % Return the callbacks - protected methods, wrapped so that the
            % parameter for the callback to adjust is always properly set
            setTimeStep = @(fTimeStep) this.setTimeStep(iIdx, fTimeStep);
            unbind      = @()          this.unbind(iIdx);
            
            
            % Find dependent timed callbacks (when timer executes)
            this.abDependent = this.afTimeStep == -1;
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
            %keyboard();
            % Get time step. Normally, this.fTimeStep, but if no afTimeStep
            % is zero, then get min(afTimeStep) if > fTimeStep
            % Find only of NOT dependent callbacks
            fSysMinStep = min(this.afTimeStep(~this.abDependent));
            
            %TODO wrong! Need to check every system's last execution + time
            %     step and if that is lt curr time + sys min step!!
            %   -> sys with longer time step could need execution before
            %      the system with the shortest time step, if the first
            %      system was not executed in a while!
            if fSysMinStep > this.fTimeStep
                fTimeStep = fSysMinStep;
                
            else
                fTimeStep = this.fTimeStep;
            end
            
            %disp(fTimeStep);
            
            
            % Set new time
            this.fTime = this.fTime + fTimeStep;
            
            % Find all cb's indices whose last exec + time step <= fTime
            % Dependent systems have -1 as time step - therefore this
            % should ALWAYS be true!
            abExec = this.afLastExec + this.afTimeStep <= this.fTime;
            
            % Execute found cbs
            % The indexing type for the cell only works if the array is of
            % real logical / boolean type!
            cellfun(@(cb) cb(this), this.cCallBacks(abExec));
            
            % Update last execution time - see above, abExec is logical, so
            % this works, don't need find!
            this.afLastExec(abExec) = this.fTime;
            
            % check for bRun -> if true, execute this.step() again!
            if this.bRun
                this.run();
            end
        end
        
        function setTimeStep(this, iCB, fTimeStep)
            % Set time step for a specific call back. Protected method, is
            % returned upon .bind!
            
            if ~isempty(fTimeStep) && fTimeStep ~= 0
                this.afTimeStep(iCB) = fTimeStep;
            else
                this.afTimeStep(iCB) = this.fTimeStep;
            end
            
            
            % Find dependent timed callbacks (when timer executes)
            this.abDependent = this.afTimeStep == -1;
        end
    end
end

