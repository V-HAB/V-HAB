classdef volume < geometry.node
    %VOLUME Represents a volume
    % Volume geometric node - has fVolume/setVolume and sends event!
    % Calculating volumes can either be done trough overloading the
    % setVolume method or by providing a function handle to calculate the
    % volume.
    
    properties (SetAccess = protected, GetAccess = public)
        % Volume
        fVolume = 0;
        
        % Named dimensions, used in surfaces to calculate area etc. For a
        % hollow cylinder, the properties here would NOT be the diameter,
        % bounding box or so, but for example the inner, outer circum-
        % ference etc., to enable the surfaces to calculate their areas.
        % Dimensions are threfore not 'elementar' or 'basic' but just some
        % value helping to describe the geometry of the volume.
        tfDimensions = struct();
        
        toSurfaces = struct();
        
        %TODO
        % Now: normals + vector for each surface
        % Could/Should be: just vector; then connect sides / edges of
        %                  surfaces to each other -> calculate normal?
        %
        % Also: tfDimensions misleading as name?
        % Change calculateVolume logic, see surfaces? Can dimensions be
        %        changed and properly be updated right now?
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Function handle to be executed on setVolume
        calcVolume;
    end
    
    methods
        function this = volume(calcVolume, varargin)
            % Directly used - just set volume. Callback can be provided on
            % construction or in child classes to calculate the volume
            % differently. Child classes can also completely overload the
            % method setVolume.
            
            if nargin >= 1
                % Calc volume is not a function handle -> volume itself!
                if ~isa(calcVolume, 'function_handle')
                    this.fVolume = calcVolume;
                else
                    this.calcVolume = calcVolume;
                    
                    this.setVolume(varargin{:});
                end
            end
        end
        
        function setVolume(this, varargin)
            % If overloaded in child class, still needs to call setVolume
            % here to actually set the value to the fVolume var!
            % If callback set, varargin passed to function. If empty, first
            % varargin field set to fVolume.
            
            if nargin == 0, return; end;
            
            if ~isempty(this.calcVolume)
                this.fVolume = this.calcVolume(varargin{:});
                
            else this.fVolume = varargin{1};
            end
            
            this.trigger('set.fVolume', this.fVolume);
        end
        
        
        function set.tfDimensions(this, tfDimensions)
            this.tfDimensions = tfDimensions;
            
            this.trigger('set.tfDimensions', this.tfDimensions);
        end
    end
    
end

