classdef rectangle < geometry.surface
    
    properties
    end
    
    methods
        function this = rectangle(oVolume, sDimensionWidth, sDimensionHeight, trVector, afNormal)
            % sDim is the name of the volume dimension representing the
            % diameter of the circle!
            %
            
            this@geometry.surface(oVolume, { sDimensionWidth, sDimensionHeight }, trVector, afNormal);
        end
        
        
        function this = calculateProperties(this)
            this.fArea          = this.afDimensions(1) * this.afDimensions(2);
            this.fCircumference = 2 * sum(this.afDimensions);
        end
    end
    
end

