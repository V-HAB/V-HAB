classdef const_press_exme_liquid < matter.procs.exmes.liquid
    properties
        fPortPressure;
    end
    
    methods
        function this = const_press_exme_liquid(oPhase, sName, fPortPressure)
            this@matter.procs.exmes.liquid(oPhase, sName);
            this.fPortPressure = fPortPressure;
        end
        
        function [ fExMePressure, fExMeTemperature ] = getExMeProperties(this)
            fExMePressure = this.fPortPressure;
            fExMeTemperature = this.oPhase.fTemperature;
        end
    end
end

