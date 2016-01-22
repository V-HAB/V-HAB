classdef solid < matter.procs.exme
    
    methods
        function this = solid(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end
        
        function [ fStandardPressure, fPortTemperature ] = getPortProperties(this)
            
            fStandardPressure = this.oMT.Standard.Pressure;
            fPortTemperature = this.oPhase.fTemperature;
        end
    end
end

