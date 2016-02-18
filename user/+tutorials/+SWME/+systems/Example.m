classdef Example < vsys
%EXAMPLE Add a proper description here

    properties
        toManualBranches = struct();
        
        fPipeLength   = 0.5;
        fPipeDiameter = 0.0254/2;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName);
            
            % Instatiating the RCA
            components.SWME(this, 'SWME');
            
        end
        
        function createMatterStructure(this)
            
            createMatterStructure@vsys(this);
            
        end
        
        function createSolverStructure(this)
            
            createSolverStructure@vsys(this);
            
        end
        
    end
    
    
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
        
    end
end

