classdef volumeChanger < matter.manips.volume.continous
    % a simple volume manipulator which compresses the volume of the phase
    % to which it is added
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