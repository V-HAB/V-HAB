classdef (Abstract) volume < matter.manip
    % Manipulator for volumes. Allows the model to change the volume (and
    % correspondingly the pressure) of a phase. This is only the base class
    % which is used to provide a common parent class for all volume
    % manipulators. More definitions are made within the subclass
    % matter.manips.volume.flow and matter.manips.volume.stationary. This
    % class already implements all necessary functions to allow a volume
    % change
    
    properties (SetAccess = private, GetAccess = public)
        % Access to setting the set handles is private because they must be
        % defined in the attachManip or detachManip function of this class
        % for consistency reasons. Dervied child classes that overload
        % these functions must still executed the function of this class
        % for that reason!
        
        % A function handle which contains the private function setProperty
        % of phase.m with fVolume as property which can be set
        hSetVolume;
        
        % A function handle which contains the private function setProperty
        % of phase.m with fPressure as property which can be set
        hSetPressure;
        
        % The time at which the update function of this manip was last
        % executed
        fLastExec = 0; % [s]
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % see description of the abstract property on the manip class for a
        % description of this property and its access rights
        hBindPostTickUpdate;
    end
    
    methods
        function this = volume(sName, oPhase, sRequiredType)
            if nargin < 3, sRequiredType = []; end
            
            this@matter.manip(sName, oPhase, sRequiredType);
            
            this.hBindPostTickUpdate = this.oTimer.registerPostTick(@this.update, 'matter', 'volumeManips');
            
            % now we use the subfunction to set the corresponding handles
            % this.setHandles();
        end
        
        function detachManip(this)
            % Since the volume manipulator additionally has function
            % handles specific for the phase to which it is connected we
            % must overload the detachManip function of matter.manips with
            % this function. The original function is still executed, as
            % all of these operations are necessary as well but
            % additionally the handles in the properties hSetVolume and
            % hSetPressure are set to empty here
            detachManip@matter.manip();
            
            this.hSetVolume     = [];
            this.hSetPressure   = [];
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
            reattachManip@matter.manip(this, oPhase);
            
            % The reattachManip function of the parent class matter.manip
            % performs the check whether this.oPhase is empty and then sets
            % the property this.oPhase to the input oPhase of this
            % function. Therefore we can access the property oPhase here
            % and use it to bind the setVolume and setPressure functions
            this.hSetVolume     = this.oPhase.bindSetProperty('fVolume');
            this.hSetPressure   = this.oPhase.bindSetProperty('fPressure');
        end
    end
    
    methods (Access = protected)
        function update(this, fVolume, fPressure)
            %% Update
            % INTERNAL FUNCTION! Is executed within the post tick and
            % should therefore not be executed directly. Note that this
            % function is used to set the volume and optionally the
            % pressure, but only because the non abstract child class must
            % implement an update method which calculates the values and
            % then uses the superclass update methods to set them!
            % Execution of the update can be registered using the
            % registerUpdate function of matter.manip
            %
            % This update function can be used to set the volume of the
            % asscociated phase. Optionally the pressure can be set as
            % well. Overloaded by the derived children, which can then
            % access this function to set the volume and pressure by using
            % update@matter.manips.volume(this, fVolume, fPressure);
            %
            % Required Inputs:
            % fVolume:      a Volume in m^3 by which the volume of the
            %               asscociated phase should be changed
            %
            % Optional Inputs:
            % fPressure:    a Pressure in Pa by which the pressure of the
            %               attached phase should be changed. Can be set if
            %               necessary, otherwise the new pressure is
            %               calculated by the matter.phase update function
            
            this.hSetVolume(fVolume);
            % Only overwrite the pressure if it was provided as parameter
            if nargin > 2
                this.hSetPressure(fPressure);
            end
            
            this.fLastExec = this.oTimer.fTime;
        end
    end
end