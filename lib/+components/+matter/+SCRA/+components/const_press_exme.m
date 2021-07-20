classdef const_press_exme < matter.procs.exmes.gas
    properties
        fPortPressure;
    end
    
    methods
        function this = const_press_exme(oPhase, sName, fPortPressure)
            this@matter.procs.exmes.gas(oPhase, sName);
            this.fPortPressure = fPortPressure;
        end
        
        function [ fExMePressure, fExMeTemperature ] = getExMeProperties(this)
            fExMePressure = this.fPortPressure;
            fExMeTemperature = this.oPhase.fTemperature;
        end
    end
end
