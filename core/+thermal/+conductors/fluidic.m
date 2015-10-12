classdef fluidic < thermal.conductor
    %FLUIDIC A fluidic conductor transporting heat to downstream node
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
        fConductivity; % Thermal conductivity of connection in [W/K].
        
    end
    
    methods
        
        function this = fluidic(oUpstream, oDownstream, fConductivity, sIdentifier)
            % Create a fluidic conductor instance, derive a name and store
            % the (initial) conductivity value.
            
            if nargin < 4
                sIdentifier = ['fluidic:', oUpstream.sName, '+', oDownstream.sName];
            end
            this@thermal.conductor(sIdentifier, oUpstream, oDownstream);
            
            % Store conductivity.
            this.fConductivity = fConductivity;
            
        end
                
    end
    
end

