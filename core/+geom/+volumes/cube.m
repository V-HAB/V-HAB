classdef cube < geom.volume
    %CUBRE Represents a cube
    
    properties (SetAccess = protected, GetAccess = public)
        fLength;
    end
    
    methods
        function this = cube(fLength)
            this@geom.volume(@geom.volumes.cube.calcVolume, fLength);
        end
    end
    
    methods (Static = true)
        function fVol = calcVolume(fLength)
            fVol = fLength^3;
        end
    end
end

