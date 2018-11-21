classdef FilterStore < matter.store
    
    
    properties (SetAccess = private, GetAccess = public)
       
    end
    
    
    methods
        function this = FilterStore(oContainer, sName, fVolume, bIsIncompressible, tGeometryParams)
            
            if nargin < 3
                fVolume = 1;
            end
            if nargin < 4
                bIsIncompressible = 1;
            end
            if nargin < 5
                tGeometryParams = struct();
            end
            
            this@matter.store(oContainer, sName, fVolume, bIsIncompressible, tGeometryParams);
            
        end
    end
    %% Internal methods for handling of table, phases, f2f procs %%%%%%%%%%
    methods (Access = protected)
        function setVolume(~)
            % DO NOTHING, especially do not overwrite the volume for the
            % gas phases!
        end
        
    end
    
end

