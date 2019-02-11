classdef (Abstract) root < sys
    %ROOT Root system of a V-HAB Simulation
    %   Every system object needs a parent, except for this one. The root
    %   system is the top level system in a V-HAB simulation and its
    %   oParent property points to itself. Other than that its like any
    %   other system. To achieve this this class overloads the setParent()
    %   method of the sys class. 
    
    properties
        % The root system has no properties
    end
    
    methods
        function this = root(sName)
            % Calling the parent constructor and passing empty as the
            % parent object reference. That would break the setParent()
            % method in the sys class, that is why we overload it below. 
            this@sys([], sName);
            
            % Setting the root reference to ourselves
            this.oRoot = this;
            
        end
        
        function setParent(this, ~)
            % Not really adding a parent, haw-haw!
            this.oParent = this;
        end
        
    end
    
end