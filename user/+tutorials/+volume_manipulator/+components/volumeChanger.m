classdef volumeChanger < matter.manips.volume.flow
    % a simple volume manipulator which compresses the volume of the phase
    % to which it is added
    properties (SetAccess = protected, GetAccess = public)
        
    end
    methods
        function this = volumeChanger(sName, oPhase)
            this@matter.manips.volume.flow(sName, oPhase);
        end
        
        function update(this)
            % Compresses the volume of the phase by 1% per 10 seconds
            fVolumeChangeRate = -(this.oPhase.fVolume / 100) / 10;
            
            update@matter.manips.volume.flow(this, fVolumeChangeRate);
        end
    end
end