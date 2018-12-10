classdef resistor < electrical.component
    %RESISTOR Simple model of an electrical resisor
    %   The purpose of this simple model is to make it easy and fast for
    %   users to create models of circuit diagrams containing resistors,
    %   without taking into account more complex aspects as dependencies on
    %   voltage, current or temperature. 
    
    
    properties (SetAccess = private, GetAccess = public)
        % Resistance in [Ohm]
        fResistance;
        
        % Current in [A]
        fCurrent;
        
        % Power in [W]
        fPower;
        
        % Voltage drop across the resistor in [V]
        fVoltageDrop;
    end
    
    methods
        function this = resistor(oCircuit, sName, fResistance)
            % Calling the parent constructor
            this@electrical.component(oCircuit, sName);
            
            % Setting the resistance property according to the input
            % parameter
            this.fResistance = fResistance;
            
        end
        
        function seal(this, oBranch)
            %SEAL Seals this resistor so nothing can be changed later on
            
            % Check if we're already sealed
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            % Setting the branch property, this is needed for the
            % calculations in update().
            this.oBranch = oBranch;
            
            % Setting the sealed property to true.
            this.bSealed = true;
        end
        
        function update(this)
            %UPDATE Calculates the voltage drop and power across this resistor
            
            % Get the current current (haha) from the branch, see what the
            % voltage drop across this resistor is and then calculate the
            % dissipated power. We can use the absolute current since a
            % resistor doesn't care in which direction the current is
            % flowing.
            
            this.fCurrent = abs(this.oBranch.fCurrent);
            
            this.fVoltageDrop = this.fResistance * this.fCurrent;
            
            this.fPower = this.fCurrent * this.fVoltageDrop;
        end
    end
    
end

