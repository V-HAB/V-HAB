classdef timed < sys
    %TIMED Method exec called either with parent or in regular intervals
    %   Can attach the .exec() method to the parent's exec method
    %   execution, or set a fixed interval for calling the exec method. The
    %   setTimestep method can be used to adjust that interval at any time
    %   in the simulation.
    %
    %NOTE make sure the .exec() method here is called to trigger 'exec' or
    %     trigger that event manually in child class.
    
    properties (SetAccess = protected, GetAccess = public)
       % Reference to timer object
       % @type object
       oTimer;
       
       % Current time step
       % @type float
       fTimeStep;
       
       fLastExec     = -1;
       fLastTimeStep = 0;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        setTimeStepCB;
        unbindCB;
        
        iBindIndex;
    end
    
    methods
        function this = timed(oParent, sName, xTimer, fTimeStep)
            this@sys(oParent, sName);
            
            % Get timer from payload data or directly provided ...
            %if ischar(xTimer), this.oTimer = this.oData.(xTimer);
            %else               this.oTimer = xTimer;
            %end
            this.oTimer = oParent.oTimer;
            
            if nargin >= 4 && ~isempty(fTimeStep)
                this.setTimeStep(fTimeStep);
            else
                % Set execution with each tick!
                this.setTimeStep();
                %this.fTimeStep = this.oTimer.fMinimumTimeStep;
            end
        end
    end
    
    
    methods (Access = protected)
        function exec(this, ~)
            % Specifically don't call the sys exec - we do trigger event
            % here with time provided!
            %TODO need to extend that logic. Problably need pre/post exec
            %     triggers? Should child systems call the parent exec
            %     method before or after they actually execute?
            
            this.fLastTimeStep = this.oTimer.fTime - this.fLastExec;
            
            this.trigger('exec', this.oTimer.fTime);
            
            this.fLastExec = this.oTimer.fTime;
        end
        
        function setTimeStep(this, fTimeStep)
            % Sets the time step for fTimeStep > 0. If fTimeStep not
            % provided or 0, global time step. If logical false, link to 
            % parent! If -1, dependent (each timer exec).
            
            % No fTimeStep provided?
            if nargin < 2 || isempty(fTimeStep), fTimeStep = -1; end
            
            % Set as obj property/attribute
            this.fTimeStep = fTimeStep;
            
            % If logical false - link to parent
            %if fTimeStep == -1
            if islogical(fTimeStep) && ~fTimeStep
                % Unregister with timer if we're registered!
                if ~isempty(this.unbindCB)
                    this.unbindCB();
                    
                    this.unbindCB      = [];
                    this.setTimeStepCB = [];
                end
                
                % Need to register on parent
                if isempty(this.iBindIndex)
                    this.iBindIndex = this.oParent.bind('exec', @this.exec);
                end
            else
                if ~isempty(this.iBindIndex)
                    this.oParent.unbind(this.iBindIndex);
                    this.iBindIndex = [];
                end
                
                % Not yet registered on timer?
                if isempty(this.unbindCB)
                    [ this.setTimeStepCB, this.unbindCB ] = this.oTimer.bind(@this.exec, fTimeStep, struct(...
                        'sMethod', 'exec', ...
                        'sDescription', 'The .exec method of a timed system', ...
                        'oSrcObj', this ...
                    ));
                    
                % Set new time step
                else
                    this.setTimeStepCB(fTimeStep);
                end
                
                % If time step is 0, means we registered on the global time
                % step -> write to this sys
                if this.fTimeStep == 0, this.fTimeStep = this.oTimer.fMinimumTimeStep; end
            end
        end
    end
end

