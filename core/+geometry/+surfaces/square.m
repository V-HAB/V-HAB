classdef square < geometry.surfaces.rectangle
    
    properties (SetAccess = protected, GetAccess = public)
        fSize;
    end
    
    methods
        function this = square(oVolume, sDimensionLength, trVector, afNormal)
            % sDim is the name of the volume dimension representing the
            % diameter of the circle!
            %
            
            this@geometry.surfaces.rectangle(oVolume, sDimensionLength, sDimensionLength, trVector, afNormal);
            
            this.fSize = this.afDimensions(1);
        end
        
        
        function this = calculateProperties(this)
            this.fArea          = this.afDimensions(1) ^ 2;
            this.fCircumference = 4 * this.afDimensions;
        end
    end
    
end

