classdef linear < thermal.conductor
    %LINEAR A linear conductor between two capacities
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
        fConductivity; % Thermal conductivity of connection in [W/K].
        oVsys;
    end
    
    methods
        
        function this = linear(oVsys, oLeftCapacity, oRightCapacity, fConductivity, sIdentifier)
            % Create a linear conductor instance, derive a name and store
            % the (initial) conductivity value.
            
            if nargin < 5
                sIdentifier = ['linear_dynamic:', oLeftCapacity.sName, '+', oRightCapacity.sName];
            end
            this@thermal.conductor(sIdentifier, oLeftCapacity, oRightCapacity);
            
            % Store conductivity.
            this.fConductivity = fConductivity;
            this.oVsys = oVsys;
            
        end
        
        function setConductivity(this, fConductivity)
            % Store conductivity.
            this.fConductivity = fConductivity;
            
            this.oVsys.taint();
        end
        
    end
    
end

