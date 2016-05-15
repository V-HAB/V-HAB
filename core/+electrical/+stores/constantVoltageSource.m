classdef constantVoltageSource < electrical.store
    %CONSTANTVOLTAGESOURCE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        fVoltage;
        sType;
        
    end
    
    methods
        function this = constantVoltageSource(oCircuit, sName, sType, fVoltage)
            this@electrical.store(oCircuit, sName);
            
            this.sType    = sType;
            this.fVoltage = fVoltage;
            
            this.oPositiveTerminal.setVoltage(fVoltage);
            this.oNegativeTerminal.setVoltage(0);
            
        end
        
    end
    
end

