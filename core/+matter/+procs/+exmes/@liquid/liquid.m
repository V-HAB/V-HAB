classdef liquid < matter.procs.exme
    
    methods
        function this = liquid(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end
        
        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            %TODO the liquid phase should not contain fPressure, instead
            %     the EXME has to calculate this based on geometry of the 
            %     store, phase density, gravity and the port position.
            fPortPressure    = this.oPhase.fPressure;
            
            fPortTemperature = this.oPhase.fTemp;
        end
    end
end

