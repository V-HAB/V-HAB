classdef constantVoltageSource < electrical.store
    %CONSTANTVOLTAGESOURCE Simple model of a constant voltage source
    %   The purpose of this simple model is to make it easy and fast for
    %   users to create models of circuit diagrams containing voltage
    %   sources like power outlets or batteries.
    
    properties
        % Constant voltage of this source
        fVoltage;
        
        % Type of electrical component, can be either 'AC' or 'DC'
        sType;
        
    end
    
    methods
        function this = constantVoltageSource(oCircuit, sName, sType, fVoltage)
            % Calling the parent constructor
            this@electrical.store(oCircuit, sName);
            
            % Setting the type and voltage properties according to the
            % input arguments
            this.sType    = sType;
            this.fVoltage = fVoltage;
            
            % Setting the voltage on the positive terminal to the provided
            % voltage and the negative terminal to zero. 
            this.oPositiveTerminal.setVoltage(fVoltage);
            this.oNegativeTerminal.setVoltage(0);
            
        end
        
        function update(this)
            update@electrical.store(this);
        end
        
    end
    
end

