classdef hollow_cylinder_sector < geometry.volume
    %Cylinder Represents a cylinder
    
    properties (SetAccess = protected, GetAccess = public)
    end
    
    methods
        function this = hollow_cylinder_sector(fRadiusInner, fRadiusOuter, fLength, fAngle)
            if (nargin < 4) || isempty(fAngle)
                fAngle = 2 * pi;
            end
            
            this@geometry.volume(@geometry.volumes.hollow_cylinder_sector.calcVolume, fRadiusInner, fRadiusOuter, fLength, fAngle);
            
            this.tfDimensions.radius_inner = fRadiusInner;
            this.tfDimensions.radius_outer = fRadiusOuter;
            this.tfDimensions.length       = fLength;
            this.tfDimensions.angle        = fAngle;
            
            % ANGLE --> rad! i.e. percentage = fAngle / (2*pi)
            
            
            % Calculate inner, outer surface length (curved!)
            this.tfDimensions.outer_circumference = 2 * pi * fRadiusOuter * fAngle / (2 * pi);
            this.tfDimensions.inner_circumference = 2 * pi * fRadiusInner * fAngle / (2 * pi);
            
            this.tfDimensions.mean_circumference = (this.tfDimensions.outer_circumference + this.tfDimensions.inner_circumference) / 2;
            this.tfDimensions.thickness = fRadiusOuter - fRadiusInner;
            
            
            
            
            
            %%%TODO vector, normals - to according position!
            % right now, vector e.g. for tangential (if anlge set) is
            % curved itself, y/z is zero, x = mean circumference
            
            % The large, curved planes
            if fRadiusInner == 0
                this.toSurfaces.length_circ_outer = geometry.surfaces.rectangle(this, 'length', 'outer_circumference', struct('mean_circumference', 0, 'thickness',  1, 'length', 0), []);
            else
                this.toSurfaces.length_circ_outer = geometry.surfaces.rectangle(this, 'length', 'outer_circumference', struct('mean_circumference', 0, 'thickness',  0.5, 'length', 0), []);
                this.toSurfaces.length_circ_inner = geometry.surfaces.rectangle(this, 'length', 'inner_circumference', struct('mean_circumference', 0, 'thickness', -0.5, 'length', 0), []);
            end
            
            % The ends of the cylinder
            this.toSurfaces.thick_circ_pos = geometry.surfaces.doughnut_sector(this, 'radius_inner', 'radius_outer', 'angle', struct('mean_circumference', 0, 'thickness', 0.5, 'length',  0.5));
            this.toSurfaces.thick_circ_neg = geometry.surfaces.doughnut_sector(this, 'radius_inner', 'radius_outer', 'angle', struct('mean_circumference', 0, 'thickness', 0.5, 'length',  0.5));
            
            
            
            % Only if not a full cirlce!
            if fAngle == 2 * pi
                return;
            end
            
            %TODO calc mean circumference (mean_radius * 2pi * angle/2pi)
            this.toSurfaces.thick_length_pos = geometry.surfaces.rectangle(this, 'thickness', 'length', struct('mean_circumference',  0.5, 'thickness', 0, 'length', 0), []);
            this.toSurfaces.thick_length_neg = geometry.surfaces.rectangle(this, 'thickness', 'length', struct('mean_circumference', -0.5, 'thickness', 0, 'length', 0), []);
        end
    end
    
    methods (Static = true)
        function fVol = calcVolume(fRadiusInner, fRadiusOuter, fLength, fAngle)
            fInnerVol = pi * fRadiusInner ^ 2 * fLength;
            fOuterVol = pi * fRadiusOuter ^ 2 * fLength;
            
            fVol = (fOuterVol - fInnerVol) * fAngle / (2 * pi);     %[m^3]
        end
    end
end

