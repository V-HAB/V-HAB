classdef const_temp_press_exme < matter.procs.exmes.gas
    %class to set the exme processor to a constant pressure. Use this class
    %just for gases!
    
    properties
        fPortPressure = 0;          %[Pa]
        fPortTemperature = 0;       %[K]
    end
    
    
    methods
        function this = const_temp_press_exme(oPhase, sName, fPortPressure, fPortTemp)
            this@matter.procs.exmes.gas(oPhase, sName);
            
            this.fPortPressure = fPortPressure;
            this.fPortTemperature = fPortTemp;
        end
        
        
        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            %Assign the port pressure with the default value and the
            %port temperature with the temperature of the attached matter
            %store
            fPortPressure    = this.fPortPressure;
            fPortTemperature = this.fPortTemperature;
        end
    end
end

