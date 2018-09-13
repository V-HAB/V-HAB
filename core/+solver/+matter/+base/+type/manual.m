classdef manual < handle
    %MANUAL manual setting of the flowrate
    % Solvers of this type do not actually calculate the flowrate based on
    % physical principles, but instead are provided a flowrate which is
    % then set to the branch. This allows the user to implement constant
    % flowrates easily but also enables user specific calculations, or even
    % user defined solvers. This is also used as framework for the multi
    % branch solvers
    
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

