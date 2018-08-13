classdef infinite_convective_conductor < thermal.procs.conductors.convective
    % a general conductor for convective heat transfer, this does not work
    % on its own, you have to create a child class of this and implement
    % the function updateHeatTransferCoefficient for it. As this is very
    % dependant on the use case it cannot be defined generally (to do,
    % create some lib components for most used cases)
    
    properties (SetAccess = protected)
        
    end
    
    methods
        
        function this = infinite_convective_conductor(oContainer, sName, oMassBranch)
            % Create a convective conductor instance
             
            this@thermal.procs.conductors.convective(oContainer, sName, 1, oMassBranch, 1);
            
            
        end
        
        function updateHeatTransferCoefficient(~)
            % nothing to update here, because the conductor uses infinite
            % conductivity at all times
        end
            
    end
    
end

