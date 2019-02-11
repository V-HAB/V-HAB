classdef (Abstract) timed < sys
    %TIMED Adds timing related properties and methods to derived classes
    %   This class is abstract and one of the parent classes of the vsys
    %   class, one of the most important classes in all of V-HAB. This
    %   class provides two important parts to every vsys: the oTimer
    %   property and the associated setTimeStep() method as well as the
    %   exec() method.
    %   The exec() method can either be called with the parent system by
    %   attaching itself to the parent's exec() call or it can attach
    %   itseld to the timer object by using the setTimeStep() method to set
    %   a fixed interval of execution. The setTimeStep() method can also be
    %   used to adjust that interval at any time during the simulation.
    
    properties (SetAccess = protected, GetAccess = public)
       % Reference to timer object
       oTimer;
       
       % Current time step
       fTimeStep;
       
       % Time the exec() method was last executed
       fLastExec     = -1;
       
       % The last interval between exec() method executions
       fLastTimeStep = 0;
    end
    
    % These properties are used to access the system's timer settings, so
    % we only want the instantiated object itself to be able to access
    % them. Therfore their SetAccess is private and their GetAccess is
    % protected.
    properties (SetAccess = private, GetAccess = protected)
        % Function handle to the timer's set time step method for this
        % specific system object.
        hSetTimeStepCB;
        
        % Function handle to the timer's unbind method for this specific
        % system object.
        hUnbindTimerCB;
        
        % Function handle to the parent's unbind method for this specific
        % object.
        hUnbindParentCB;
    end
    
    methods
        function this = timed(oParent, sName, fTimeStep)
            % Calling the parent class constructor
            this@sys(oParent, sName);
            
            % Setting the timer property
            this.oTimer = oParent.oTimer;
            
            % if a time step is provided, we call our own setTimeStep()
            % method with that time step as the input argument. If it is
            % not given, we call setTimeStep() without an input argument,
            % which will lead to this system being executed every tick. 
            if nargin >= 3 && ~isempty(fTimeStep)
                this.setTimeStep(fTimeStep);
            else
                this.setTimeStep();
            end
        end
    end
    
    
    methods (Access = protected)
        function exec(this, ~)
            %EXEC Executes the actions that are required in a system. 
            % This method should contain things like the control logic of a
            % valve switching system. 
            
            % Calculating how long it has been since the last execution.
            % This value is sometimes needed for timing calculations.
            this.fLastTimeStep = this.oTimer.fTime - this.fLastExec;
            
            % Triggering the exec event so other objects can bind itself to
            % it.
            this.trigger('exec', this.oTimer.fTime);
            
            % Setting the last execution time to the current time. 
            this.fLastExec = this.oTimer.fTime;
        end
        
        function setTimeStep(this, xTimeStep)
            % Sets the time step for this system. If the provided time step
            % is numeric and greater than zero, this time step will be
            % registered with the timer object. If the time step is zero or
            % smaller, the global minimum time step will be used. One
            % exception here is -1. If the time step has this value, the
            % system will register as a dependent system with the timer
            % object, meaning it will be executed during every tick.
            % Finally, if the time step is logical false, it will bind
            % itself to the exec event of its parent system.
            %
            % To summarize:
            % -Inf < time step <  -1    --> minimum time step
            %        time step == -1    --> execute every tick
            %   -1 < time step <=  0    --> minimum time step
            %    0 < time step <  Inf   --> given time step used
            %        time step == false --> execute with parent
            %
            % NOTE: The top level system should never bind itself to its
            % parent because that is the root system object. The root
            % system object is never executed, so if the top level system
            % attaches itself there, it will also never be executed.
            
            % If no time step value is provided we set it to -1. That will
            % bind it to the timer as a dependent system. 
            if nargin < 2 || isempty(xTimeStep)
                xTimeStep = -1; 
            end
            
            % Setting the time step property
            this.fTimeStep = xTimeStep;
            
            % If the time step is logical false we link the exec() method
            % to its parent.
            if islogical(xTimeStep) && ~xTimeStep
                % If we were registered with the timer before, we need to
                % unbind from it first. 
                if ~isempty(this.hUnbindTimerCB)
                    % Executing the unbind callback
                    this.hUnbindTimerCB();
                    
                    % Deleting the saved callbacks to set the time step and
                    % unbind from the timer. These are anonymous function
                    % handles specific to this object and its index within
                    % the timer object, so they cannot be re-used. 
                    this.hUnbindTimerCB = [];
                    this.hSetTimeStepCB = [];
                end
                
                % Now we bind our exec() method to our parent, but only if
                % we haven't done so before. 
                if isempty(this.hUnbindParentCB)
                    [ ~, this.hUnbindParentCB ] = this.oParent.bind('exec', @this.exec);
                end
            else
                % The provided time step is numeric, so we have to deal
                % with the timer object.
                
                % If we were previously bound to our parent, we need to
                % unbind first. 
                if ~isempty(this.hUnbindParentCB)
                    % Executing the unbind callback
                    this.hUnbindParentCB();
                    
                    % Deleting the saved unbind callback.
                    this.hUnbindParentCB = [];
                end
                
                % Checking if we are already registered with the timer. If
                % we are, we can just use the callback saved in the
                % hUnbindTimerCB property.
                if isempty(this.hUnbindTimerCB)
                    % Binding the exec method to the timer with the
                    % provided time step and saving the returned callbacks.
                    [ this.hSetTimeStepCB, this.hUnbindTimerCB ] = this.oTimer.bind(@this.exec, xTimeStep, struct(...
                        'sMethod', 'exec', ...
                        'sDescription', 'The .exec method of a timed system', ...
                        'oSrcObj', this ...
                    ));
                else
                    % We had already registerd with the timer, so we can
                    % just use the saved callback to update the timestep. 
                    this.hSetTimeStepCB(xTimeStep);
                end
                
                % If time step is 0, it means we registered on the global
                % minimum time step, so we overwrite the zero we saved
                % previously.
                if this.fTimeStep == 0
                    this.fTimeStep = this.oTimer.fMinimumTimeStep; 
                end
            end
        end
    end
end