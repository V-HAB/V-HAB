classdef inductor < electrical.component
    %INDUCTOR
    
    properties (SetAccess = private, GetAccess = public)
        fInductance;
    end
    
    methods
        function this = inductor(oCircuit, sName, fInductance)
            this@electrical.component(oCircuit, sName);
            this.fInductance = fInductance;
            
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

