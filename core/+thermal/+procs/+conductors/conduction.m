classdef conduction < thermal.procs.conductor
    % creates a conductor for conduction of heat through a material (e.g.
    % metal)
    
    properties (SetAccess = protected)
        
        fConductivity; % Thermal conductivity of connection in [W/K].
        
        bRadiative  = false;
        bConvective = false;
        bConductive = true;
    end
    
    methods
        
        function this = conduction(oContainer, sName, fConductivity)
           
            
            this@thermal.procs.conductor(oContainer, sName);
            
            % Store conductivity.
            this.fConductivity = fConductivity;
            
        end
        
        function update(this, ~)
            % TO DO: implement material dependcy updates here?
        end 
    end
    
end

