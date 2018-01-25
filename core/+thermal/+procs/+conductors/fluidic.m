classdef fluidic < thermal.procs.conductor
    %FLUIDIC A fluidic conductor transporting heat to downstream node
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
        fConductivity = 0; % Thermal conductivity of connection in [W/K].
        
    end
    
    methods
        
        function this = fluidic(oContainer, sName)
            % Create a fluidic conductor instance
             
            this@thermal.procs.conductor(oContainer, sName);
            
            
        end
                
    end
    
end

