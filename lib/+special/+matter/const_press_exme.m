classdef const_press_exme < matter.procs.exmes.gas
    
    
    properties
        fPortPressure = 0;
    end
    
    
    methods
        function this = const_press_exme(oPhase, sName, fPortPressure)
            this@matter.procs.exmes.gas(oPhase, sName);
            
            this.fPortPressure = fPortPressure;
        end
        
        
        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            fPortPressure    = this.fPortPressure; %this.oPhase.fMassToPressure * this.oPhase.fMass;
            fPortTemperature = this.oPhase.fTemp;
        end
    end
end

