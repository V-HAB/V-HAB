classdef solid < matter.procs.exme
    
    methods
        function this = solid(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end
        
        function [ fPortTemperature ] = getPortProperties(this)
            
            fPortTemperature = this.oPhase.fTemp;
        end
    end
end

