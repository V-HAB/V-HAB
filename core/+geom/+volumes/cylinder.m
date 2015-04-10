classdef cylinder < geom.volume
    %Cylinder Represents a cylinder
    
    properties (SetAccess = protected, GetAccess = public)
        fDiameter;
        fHeight;
    end
    
    methods
        function this = cylinder(fDiameter, fHeight)
            if nargin >= 1
                this.setVolume(fDiameter, fHeight);
            end
        end
    end
    
    methods
        function this = setVolume(this, fDiameter, fHeight)
            this.fDiameter = fDiameter;
            this.fHeight   = fHeight;
            
            fVol = pi * (fDiameter / 2)^2 * fHeight;
            
            setVolume@geom.volume(this, fVol);
        end
    end
end

