classdef compressibleMedium < matter.manips.volume.stationary
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    methods
        function this = compressibleMedium(sName, oPhase)
            this@matter.manips.volume.stationary(sName, oPhase);
            
            this.bindEvents();
        end
        
        function update(this, ~)
            
            update@matter.manips.volume(fVolume, fPressure);
            
        end
            
        function reattachManip(this, oPhase)
            % Since the compressibleMedium manipulator must bind certain
            % update events to the phase and other manipulators we must
            % overload the attachManip function of
            % matter.manips.volume.stationary with this function. The
            % original function is still executed, as all of these
            % operations are necessary as well but additionally required
            % triggers are set. Note that on detaching the manip all event
            % triggers are deleted anyway, and therfore that function must
            % not be overloaded. The necessary inputs are:
            % oPhase:   a phase object which fullfills the required phase
            %           condition of the manip specified in the
            %           sRequiredType property.
            reattachManip@matter.manip.volume(oPhase);
           
            this.bindEvents();
        end
    end
    
    methods (Access = private)
        % this function is only used to prevent having this definition
        % twice in the code, as it needs to be executed in the constructor
        % and in the reattachManip function. It is therefore an internal
        % function and should not be used by any subclass
        function bindEvents(this)
            % bind the update function to the update of the connected
            % phase, as changes in the compressible phase result in
            % pressure changes which makes a recalculation necessary
            this.oPhase.bind('update_post', @this.update);
        end
    end
end