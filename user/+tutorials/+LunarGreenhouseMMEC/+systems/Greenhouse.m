classdef Greenhouse < vsys
    % This class represents the setup of the lunar greenhouse prototype
    % described in ICES-2014-167: "Poly-Culture Food Production and Air 
    % Revitalization Mass and Energy Balances Measured in a Semi-Closed 
    % Lunar Greenhouse Prototype (LGH)", R. Lane Patterson et al.
    
    properties
    end
    
    methods
        function this = Greenhouse(oParent, sName)
            this@vsys(oParent, sName);
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
        end
    end
end