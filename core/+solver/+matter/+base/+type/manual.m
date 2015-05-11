classdef manual < handle
    %MANUAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        bActive = false;
        update;
    end
    
    methods
        function this = manual(bActive, updateMethod)
            % Active component? Needs function handle to update the delta 
            % temperature
            if nargin > 0 && bActive
                this.bActive          = bActive;
                this.update = updateMethod;
            end
        end
    end
end

