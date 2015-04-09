classdef gas < matter.procs.exme
    
    methods
        function this = gas(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end
        
        
        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            fPortPressure    = this.oPhase.fMassToPressure * this.oPhase.fMass;
            fPortTemperature = this.oPhase.fTemp;
        end
    end
end

