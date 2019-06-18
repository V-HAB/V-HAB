classdef (Abstract) continous < matter.manips.volume
    % a flow volume manipulator changes the volume with a change rate in
    % m^3/s. Different from the substance manipulator the seperation
    % into stationary and flow manips for volumes has nothing to do with
    % flow phases but is purely used to describe manipulators which
    % describe volume change rates (flow) or change the volume by fixed
    % values (stationary)
    
    properties (SetAccess = private, GetAccess = public) 
        % Since these properties should be set through the update function
        % of this class for all child classes, the properties are private
        
        % This property describes the volume change in m^3/s and is used in
        % the update function of the phase to recalculate the volume.
        fVolumeChangeRate = 0; % [m^3/s]
        
        % The current volume change related time step of this manipulator
        % which enforces a phase update
        fTimeStep;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % A property to limit the maximum volume change before a phase
        % update is triggered
        rMaxVolumeChange = 0.1;
    end
        
    % to easier discern between volume manipulators that provide change
    % rates and volume manipulators that directly change the volume a
    % boolean flag is introduced to identify these two options. Since the
    % type is defined by inherting from this parent class, the property is
    % constant and cannot be changed.
    properties (Constant)
        % Identifies this manipualtor as a flow volume manipulator
        bStationaryVolumeProcessor = false;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % function handle registered at the timer object that allows this
        % manip to set a time step, which is then enforced by the timer
        setTimeStep;
    end
    
    methods
        function this = continous(sName, oPhase, sRequiredType)
            if nargin < 3, sRequiredType = []; end
            
            this@matter.manips.volume(sName, oPhase, sRequiredType);
        end
        
        function detachManip(this)
            % Since the volume manipulator additionally has function
            % handles specific for the phase to which it is connected we
            % must overload the detachManip function of matter.manips with
            % this function. The original function is still executed, as
            % all of these operations are necessary as well but
            % additionally the handles in the properties hSetVolume and
            % hSetPressure are set to empty here
            detachManip@matter.manips.volume();
            
            % set the setTimeStep function to empty
            this.setTimeStep = [];
            % The events do not have to be reset, as this is done anyway i
            % the general matter.manip detachManip function
            
        end
            
        function reattachManip(this, oPhase)
            % Since the volume manipulator additionally has function
            % handles specific for the phase to which it is connected we
            % must overload the attachManip function of matter.manips with
            % this function. The original function is still executed, as
            % all of these operations are necessary as well but
            % additionally the handles in the properties hSetVolume and
            % hSetPressure are set to the new phase. The necessary inputs
            % are:
            % oPhase:   a phase object which fullfills the required phase
            %           condition of the manip specified in the
            %           sRequiredType property.
            reattachManip@matter.manips.volume(this, oPhase);
            
            % We bind the registerUpdate function of the connected phase to
            % this manip to allow us to set a volume change dependent time
            % step
            this.setTimeStep = this.oTimer.bind(@(~) this.oPhase.registerUpdate(), 0, struct(...
                'sMethod', 'update', ...
                'sDescription', 'The .registerUpdate method of the phase of this volume manipulator', ...
                'oSrcObj', this ...
            ));
        
            % if the phase is updated we want to reset the last time at
            % which the time step for this manip was set, as then the
            % pressure for the changed volume is recalculated
            this.oPhase.bind('update_post', @(~) this.resetTimeStep());
        end
        
    end
    
    methods (Access = protected)
        function update(this, fVolumeChangeRate)
            % This update function can be overloaded by the derived
            % children, which can then access this function to set the
            % volume change rate by using
            % update@matter.manips.volume.flow(fVolumeChangeRate);
            % Note that the phase update is executed after the update of
            % volume manipulators in the post tick logic, therefore the
            % volume change will already affect the phase, and then the
            % phase update will calculate the new pressure for the phase.
            % If that is not the intended behavior (e.g. if the user also
            % wants to handle the pressure recalculation) this subfunction
            % can be overloaded where this does not occur. In that case the
            % update@matter.manips.volume(fVolume, fPressure) function must
            % be called to be consistent
            
            % Before we set the new parameter for the volume change rate,
            % we first have to perform the volume change operation from the
            % current flow rate. For this purpose we first calculate the
            % elapsed time since the last update.
            fElapsedTime = this.oTimer.fTime - this.fLastExec;
            if fElapsedTime > 0
                % and multiply it with the previous volume change
                fVolumeChange = this.fVolumeChangeRate * fElapsedTime; %[m^3]
                % The new volume can be calculated by adding the volume change
                % to the current phase volume
                fNewPhaseVolume = this.oPhase.fVolume + fVolumeChange;

                update@matter.manips.volume(this, fNewPhaseVolume);
            end
            this.fVolumeChangeRate = fVolumeChangeRate;
            
            % However, changing the volume also changes the pressure.
            % Therefore we bind a seperate time step for this manipulator
            % which calls a function to update the phase if the the volume
            % change exceeds the specified limit
            this.fTimeStep = abs((this.rMaxVolumeChange * this.oPhase.fVolume) / this.fVolumeChangeRate);
            this.setTimeStep(this.fTimeStep);
        end
        
        function resetTimeStep(this)
            % If the phase is updated because of other calculations we want
            % to reset the last time at which the time step of this manip
            % was set as well. Therefore this function is bound to the
            % phase post_update trigger and resets the current time step
            % with the flag true to also reset the last time this timestep
            % was set
            this.setTimeStep(this.fTimeStep, true);
        end
    end
end