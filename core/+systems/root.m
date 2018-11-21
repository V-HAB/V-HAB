classdef root < sys
    %ROOT Root system of a V-HAB Simulation
    %   Every system object needs a parent, except for this one. The root
    %   system is the top level system in a V-HAB simulation and its
    %   oParent property points to itself. Other than that its like any
    %   other system. 
    
    properties
        
    end
    
    methods
        function this = root(sId)
            this@sys([], sId);
            
            % Setting the root reference to ourselves
            this.oRoot = this;
            
        end
        
        function setParent(this, ~)
            % Not really adding a parent, haw-haw!
            this.oParent = this;
        end
        
    end
    
end