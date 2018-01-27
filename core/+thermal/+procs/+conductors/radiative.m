classdef radiative < thermal.procs.conductor
    %RADIATIVE A radiative conductor transferring heat through thermal radiation
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
        fConductivity; % Thermal conductivity of connection in [W/K^4].
        
        bRadiative  = true;
        bConvective = false;
        bConductive = false;
    end
    
    methods
        
        function this = radiative(oContainer, sName, fConductivity)
            % Create a radiative conductor instance, derive a name and
            % store the (initial) conductivity value.
            
            this@thermal.procs.conductor(oContainer, sName);
            
            % Store conductivity.
            this.fConductivity = fConductivity;
            
        end
               
        function update(this, ~)
            % TO DO: implement material dependcy updates here?
        end 
    end
    
end

