classdef radiative < thermal.conductor
    %RADIATIVE A radiative conductor transferring heat through thermal radiation
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
        fConductivity; % Thermal conductivity of connection in [W/K^4].
        
    end
    
    methods
        
        function this = radiative(oLeft, oRight, fConductivity, sIdentifier)
            % Create a radiative conductor instance, derive a name and
            % store the (initial) conductivity value.
            
            if nargin < 4
                sIdentifier = ['radiative:', oLeft.sName, '+', oRight.sName];
            end
            this@thermal.conductor(sIdentifier, oLeft, oRight);
            
            % Store conductivity.
            this.fConductivity = fConductivity;
            
        end
                
    end
    
end

