classdef transistor < electrical.component
    %TRANSISTOR
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    methods
        function this = transistor(oCircuit, sName)
            this@electrical.component(oCircuit, sName);

            
        end
        
        
        function seal(this, oBranch)
            
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            this.oBranch = oBranch;
            this.bSealed = true;
        end
        
        function update(this)
            
        end
    end
    
end

