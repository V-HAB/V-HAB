classdef manual < handle
    %MANUAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        bActive = false;
        updateProperties;
    end
    
    methods
        function this = manual(bActive, updateMethod)
            % Active component? Needs function handle to update the delta 
            % temperature
            if nargin > 0 && bActive
                this.bActive          = bActive;
                this.updateProperties = updateMethod;
            end
        end
        
        
        function update(this)
            %TODO Insert something here that can update the fHeatFlow
            %property of the f2f-processors.
            
        end
    end
end

