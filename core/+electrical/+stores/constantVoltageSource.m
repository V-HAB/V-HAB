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
            
        end
        
    end
    
end

