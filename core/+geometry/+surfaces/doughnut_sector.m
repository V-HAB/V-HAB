classdef doughnut_sector < geometry.surface
    %CIRCLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = doughnut_sector(oVolume, sRadiusInnerDim, sRadiusOuterDim, sAngleDim, trVector)
            
            this@geometry.surface(oVolume, { sRadiusInnerDim, sRadiusOuterDim sAngleDim }, trVector, []);
        end
        
        
        function this = calculateProperties(this)
            fRadiusInner = this.afDimensions(1);
            fRadiusOuter = this.afDimensions(2);
            fAngle       = this.afDimensions(3);
            fThickness   = fRadiusOuter - fRadiusInner;
            
            if fAngle == 2 * pi
                fThickness = 0;
            end
            
            
            fAreaInner = pi * fRadiusInner ^ 2 * fAngle / (2 * pi);
            fAreaOuter = pi * fRadiusOuter ^ 2 * fAngle / (2 * pi);
            
            fCircInner = 2 * pi * fRadiusInner * fAngle / (2 * pi);
            fCircOuter = 2 * pi * fRadiusOuter * fAngle / (2 * pi);
            
            this.fArea = fAreaOuter - fAreaInner;
            this.fCircumference = fCircInner + fCircOuter + 2 * fThickness;
        end
    end
    
end

