classdef surface < geometry.node & event.source
    %TODO vector + normal not sufficient? Also, vector right now not
    %     sufficiently defined, e.g. see hollow_cylinder_sector.
    %     -> vector along the curved x axis for distance from surface
    %        to the center of the node mainly used because of thermal
    %     -> generally - curved plane, how to define that?
    %     -> each volume has several surfaces - calcualte lines of inter-
    %        section between planes?
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Normal of surface plane, no unit
        afNormal;
        
        % Vector center of volume -> center of surface as ratios of the
        % dimensions defined in oVolume.tfDimensions
        trVector = struct();
        
        % Shape
        sShape; % default shape?
        afShapePath; % path to define shape?
        
        oVolume; % parent volume.
        
        
        % Dimensions (X, Y)
        % This can be just the 'bounding box' for more complex shapes, e.g.
        % a circle or path or so.
        afDimensions;
        %TODO mostly set by parent volume object, if that e.g. changes -->
        %     also update the surface values here ...?
        
        % Mapping from parent volume afDimensions to the dimensions here.
        csDimensionMapping = {};
        
        
        fArea;
        fCircumference;
        
        % X/Y/Z, generated from tfVetor / oVolume.tfDimensions
        afVector = nan(1, 3);
    end
    
    
    methods
        function this = surface(oVolume, csDimensionMapping, trVector, afNormal)
            %TODO vector + normal not enough to define position of surface!
            %
            this.oVolume  = oVolume;
            this.trVector = trVector; %TODO check if 3 elems for x/y/z!
            this.afNormal = afNormal;
            
            this.afDimensions       = nan(1, length(csDimensionMapping));
            this.csDimensionMapping = csDimensionMapping;
            
            this.oVolume.bind('set.tfDimensions', @this.updateDimensions);
            
            this.updateDimensions();
        end
    end
    
    
    methods (Abstract = true)
        this = calculateProperties(this)
    end
    
    
    methods (Access = protected)
        function updateDimensions(this)
            % Note: 
            for iD = 1:length(this.afDimensions)
                this.afDimensions(iD) = this.oVolume.tfDimensions.(this.csDimensionMapping{iD});
            end
            
            
            % Calculate vector
            csDims = fieldnames(this.trVector);
            
            %TODO check - length should be 3 for x/y/z
            
            for iD = 1:length(csDims)
                this.afVector(iD) = this.trVector.(csDims{iD}) * this.oVolume.tfDimensions.(csDims{iD});
            end
            
            
            
            this.calculateProperties();
            
            this.trigger('update');
        end
    end
    
end

