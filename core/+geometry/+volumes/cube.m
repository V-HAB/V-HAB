classdef cube < geometry.volumes.cuboid
    %CUBRE Represents a cube
    
    properties (SetAccess = protected, GetAccess = public)
        fLength;
    end
    
    methods
        function this = cube(fLength)
            this@geometry.volumes.cuboid(fLength, fLength, fLength);
            
            this.fLength = fLength;
        end
    end
end

