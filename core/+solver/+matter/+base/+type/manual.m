classdef manual < handle
    %MANUAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        oProc; 
        
        bActive           = false;
        fDeltaTemperature = 0;
        
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
        
        
        function updateDeltaTemperature(this)
            this.fDeltaTemperature = this.updateProperties();
            
        end
    end
end

