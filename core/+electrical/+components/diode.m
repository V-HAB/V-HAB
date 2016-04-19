classdef diode < electrical.component
    %DIODE
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    methods
        function this = diode(oCircuit, sName)
            this@electrical.component(oCircuit, sName);
            
            
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

