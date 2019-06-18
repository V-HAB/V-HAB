classdef incompressibleMedium < matter.manips.volume.step
    
    properties (Constant)
        % Identifies this manipualtor as a stationary volume manipulator
        bCompressible = false;
    end
    
    methods
        function this = incompressibleMedium(sName, oPhase)
            this@matter.manips.volume.step(sName, oPhase);
            
            % bind the update function to the update of the connected
            % phase, as an update signifies a sufficiently large change in
            % mass of the incompressible phase to necessitate a volume
            % recalculation
        end
    end
    methods (Access = protected)
        function update(this, fNewVolume, fNewPressure)
            % The incompressible manip cannot calculate changes by
            % itself, but receives the calculated changes from a
            % compressible manip within the same store. While it may seem
            % strange that an incompressible Medium is handed in a new
            % volume parameter, that does make sense because the volume can
            % change because of mass changes for the incompressible phase.
            % Also the phase is not handled as completly incompressible,
            % but rather as incompressible in comparison to other phases.
            % The density is still calculated by the matter table for the
            % current conditions allowing some degree of compression
            if nargin > 1
                update@matter.manips.volume(this, fNewVolume, fNewPressure);
            end
        end
    end
end