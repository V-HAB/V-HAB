classdef cuboid < geometry.volume
    %Calculates volume of a cuboid
    
    
    properties (SetAccess = protected, GetAccess = public)
        %Length, width and height of cuboid in [m]
        fWidth;
        fHeight;
        fDepth;
    end
    
    methods
        function this = cuboid(fWidth , fHeight, fDepth)
            this@geometry.volume(@geometry.volumes.cuboid.calcVolume, fWidth , fHeight, fDepth);
            
            
            
            % With is x, height is y, depth is z!
            this.tfDimensions.width  = fWidth;
            this.tfDimensions.height = fHeight;
            this.tfDimensions.depth  = fDepth;
            
            % Create surfaces (squares)
            % Center of cube is <0,0,0>
            %
            % Coordinate system:
            %
            %  y
            %  ^    ^ z
            %  |   /
            %  |  /
            %  | /
            %  |/
            %  +--------> x
            % 
            %
            %
            cSurfaces = {
                % 1st: vector in % of dimensions to center of surface. The
                %      three indices re
                % 2nd: normal of surface
                % 3rd: width / height of surface
                %
                %
                % Surface 1 is in x/y plane, positive z
                % Center of this surface is on the z axis (i.e. x/y eq 0),
                % translated 50% of the length (depth)
                [ 0, 0,  0.5 ], [ 0, 0, 1 ], 'width', 'height';
                [ 0, 0, -0.5 ], [ 0, 0, 1 ], 'width', 'height';
                
                [ 0,  0.5, 0 ], [ 0, 1, 0 ], 'width', 'depth';
                [ 0, -0.5, 0 ], [ 0, 1, 0 ], 'width', 'depth';
                
                [  0.5, 0, 0 ], [ 1, 0, 0 ], 'height', 'depth';
                [ -0.5, 0, 0 ], [ 1, 0, 0 ], 'height', 'depth';
            };
            
            
            for iS = 1:size(cSurfaces, 1)
                arVector = cSurfaces{iS, 1};
                trVector = struct('width', arVector(1), 'height', arVector(2), 'depth', arVector(3));
                
                
                csDims = { 'x', 'y', 'z' };
                aiZero = find(arVector == 0);
                
                if arVector(arVector ~= 0) > 0
                    sDir = 'pos';
                else
                    sDir = 'neg';
                end
                sName = sprintf('surface_%s_%s_%s', csDims{aiZero(1)}, csDims{aiZero(2)}, sDir);
                
                this.toSurfaces.(sName) = geometry.surfaces.rectangle(...
                    this, cSurfaces{iS, 3}, cSurfaces{iS, 4}, ...
                    trVector, cSurfaces{iS, 2} ...   % relative vectors and normal of plane
                );
            end
        
            %TODO create helpers for stuff like that? Also e.g. translate
            %     vectors, so cube could e.g. be built with 0/0/0 in the
            %     bottom left corner.
        end
        
        
        
        function draw(this)
            
            figure();
            axes();
            hold('on');
            grid('on');
            
            csSurfaces = fieldnames(this.toSurfaces);
            
            
            csDims = fieldnames(this.tfDimensions);
            %%%tsDims = struct('width', 'x', 'height', 'y', 'depth', 'z');
            
            for iS = 1:length(csSurfaces)
                % For the two dimensions of the current surface
                aaiSigns = [ 1, 1; 1, -1; -1, -1; -1, 1; 1, 1 ] * 0.49;
                oSurface = this.toSurfaces.(csSurfaces{iS});
                aaaPlot  = nan(3, size(aaiSigns, 1));
                
                
                % Dimensions in which the plane extends.
                %TODO should be a more general way to do that! Multiply
                %     something with the normal vector or so.
                %TODO wait, not properly defined ... what about rotation,
                %     how do we
                aiDims = find(oSurface.afNormal == 0);
                
                for iP = 1:size(aaiSigns, 1)
                    afDims = oSurface.afVector;
                    
                    %%%afVector = [
                    %%%    aaiSigns(iP, 1) * oSurface.afDimensions(1);
                    %%%    aaiSigns(iP, 2) * oSurface.afDimensions(2);
                    %%%    0
                    %%%];
                    %%%afDirectedVector = cross(afVector', oSurface.afNormal);
                    
                    
                    afDims(aiDims(1)) = this.tfDimensions.(csDims{aiDims(1)}) * aaiSigns(iP, 1);% * sif(iS >= 5, 0.95, 1);
                    afDims(aiDims(2)) = this.tfDimensions.(csDims{aiDims(2)}) * aaiSigns(iP, 2);% * sif(iS >= 5, 0.95, 1);
                    
                    
                    aaaPlot(1, iP) = afDims(1);
                    aaaPlot(2, iP) = afDims(2);
                    aaaPlot(3, iP) = afDims(3);
                    
                    %%%aaaPlot(1, iP) = oSurface.afVector(1) + afDirectedVector(1);
                    %%%aaaPlot(2, iP) = oSurface.afVector(2) + afDirectedVector(2);
                    %%%aaaPlot(3, iP) = oSurface.afVector(3) + afDirectedVector(3);
                end
                
                plot3(aaaPlot(1, :), aaaPlot(2, :), aaaPlot(3, :), 'linewidth', 4);
            end
            
            
            view(25, 25);
            axis('equal');
            xlabel('x');
            ylabel('y');
            zlabel('z');
        end
    end
    
    methods (Static = true)
        function fVol = calcVolume(fLength , fWidth , fHeight )
            fVol = fLength * fWidth * fHeight ;     %[m^3]
        end
    end
end

