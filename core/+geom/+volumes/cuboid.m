classdef cuboid < geom.volume
    %Calculates volume of a cuboid
    
    
    properties (SetAccess = protected, GetAccess = public)
        %Length, width and height of cuboid in [m]
        fLength;
        fWidth;
        fHeight;
    end
    
    methods
        function this = cuboid(fLength , fWidth , fHeight)
            this@geom.volume(@geom.volumes.cuboid.calcVolume, fLength , fWidth , fHeight);
        end
    end
    
    methods (Static = true)
        function fVol = calcVolume(fLength , fWidth , fHeight )
            fVol = fLength * fWidth * fHeight ;     %[m^3]
        end
    end
end

