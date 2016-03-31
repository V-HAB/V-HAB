classdef resistor < electrical.component
    %RESISTOR
    
    properties (SetAccess = private, GetAccess = public)
        fResistance;
    end
    
    methods
        function this = resistor(oCircuit, sName, fResistance)
            this@electrical.component(oCircuit, sName);
            this.fResistance = fResistance;
            
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

