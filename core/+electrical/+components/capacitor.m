classdef capacitor < electrical.component
    %CAPACITOR
    
    properties (SetAccess = private, GetAccess = public)
        fCapacity;
    end
    
    methods
        function this = capacitor(oCircuit, sName, fCapacity)
            this@electrical.component(oCircuit, sName);
            this.fCapacity = fCapacity;
            
        end
        
        
        function seal(this, oBranch)
            
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            this.oBranch = oBranch;
            this.bSealed = true;
        end
    end
    
end

