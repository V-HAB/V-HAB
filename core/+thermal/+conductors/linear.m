classdef linear < thermal.conductor
    %LINEAR A linear conductor between two capacities
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
        fConductivity; % Thermal conductivity of connection in [W/K].
        
    end
    
    methods
        
        function this = linear(oLeft, oRight, fConductivity, sIdentifier)
            % Create a linear conductor instance, derive a name and store
            % the (initial) conductivity value.
            
            if nargin < 4
                sIdentifier = ['linear:', oLeft.sName, '+', oRight.sName];
            end
            this@thermal.conductor(sIdentifier, oLeft, oRight);
            
            % Store conductivity.
            this.fConductivity = fConductivity;
            
        end
        
    end
    
end

