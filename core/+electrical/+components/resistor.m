classdef resistor < electrical.component
    %RESISTOR
    
    properties (SetAccess = private, GetAccess = public)
        fResistance;
        fCurrent;
        fPower;
        fVoltageDrop;
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
        
        function update(this)
            % Get left and right flows, see what the voltage drop across
            % this resistor is, what the current is and then calculate the
            % dissipated power here. We can use the absolute current since
            % a resistor doesn't care in which direction the current is
            % flowing.
            this.fCurrent = abs(this.oBranch.fCurrent);
            
            this.fVoltageDrop = this.fResistance * this.fCurrent;
            
            this.fPower = this.fCurrent * this.fVoltageDrop;
        end
    end
    
end

