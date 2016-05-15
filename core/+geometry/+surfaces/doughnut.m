classdef doughnut < geometry.surface
    %CIRCLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = doughnut(oVolume, sRadiusInnerDim, sRadiusOuterDim)
            % sDim is the name of the volume dimension representing the
            % diameter of the circle!
            %
            % Only ONE dimension mapping! Two separate radii --> ellipse!
            % (wow, that's actually correct:
            % http://dictionary.reference.com/browse/radii)
            
            % sDimensionName is on FIRST index, i.e. written to afDims(1)
            this@geometry.surface(oVolume, { sRadiusInnerDim, sRadiusOuterDim });
        end
        
        
        function this = calculateProperties(this)
            fRadiusInner = this.afDimensions(1);
            fRadiusOuter = this.afDimensions(2);
            fThickness   = fRadiusOuter - fRadiusInner;
            
            fAreaInner = pi * fRadiusInner ^ 2;
            fAreaOuter = pi * fRadiusOuter ^ 2;
            
            fCircInner = 2 * pi * fRadiusInner;
            fCircOuter = 2 * pi * fRadiusOuter;
            
            this.fAreaInner = fAreaOuter - fAreaInner;
            this.fCircumference = fCircInner + fCircOuter;
        end
    end
    
end

