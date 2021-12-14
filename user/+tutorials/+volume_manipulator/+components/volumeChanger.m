classdef volumeChanger < matter.manips.volume.continous
    %VOLUMECHANGER Changes the volume of a phase
    % A simple volume manipulator that compresses the volume of the phase
    % to which it is added. It inherites from the base class
    % matter.manips.volume.continous, the other available base class is 
    % matter.manips.volume.step. The difference between these two classes
    % is, that the continous manip uses a volume change rate per second,
    % while the step manip uses an absolute volume by which the phase
    % volume instantly changes.
    properties (SetAccess = protected, GetAccess = public)
        
    end
    methods
        function this = volumeChanger(sName, oPhase)
            this@matter.manips.volume.continous(sName, oPhase);
        end
    end
    
    methods (Access = protected)
        function update(this)
            % Compresses the volume of the phase by 1% per 10 seconds
            fVolumeChangeRate = -(this.oPhase.fVolume / 100) / 10;
            
            update@matter.manips.volume.continous(this, fVolumeChangeRate);
        end
    end
end