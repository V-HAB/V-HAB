classdef circle < geometry.surface
    %CIRCLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = circle(oVolume, sDimensionName)
            % sDim is the name of the volume dimension representing the
            % diameter of the circle!
            %
            % Only ONE dimension mapping! Two separate radii --> ellipse!
            % (wow, that's actually correct:
            % http://dictionary.reference.com/browse/radii)
            
            % sDimensionName is on FIRST index, i.e. written to afDims(1)
            this@geometry.surface(oVolume, { sDimensionName });
        end
        
        
        function this = calculateProperties(this)
            fRadius = this.afDimensions(1) / 2;
            
            this.fArea          = pi * fRadius ^ 2;
            this.fCircumference = 2 * pi * fRadius;
        end
    end
    
end

