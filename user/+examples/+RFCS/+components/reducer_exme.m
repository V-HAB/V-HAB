classdef reducer_exme < matter.procs.exmes.gas
    
    
    properties
        fPortPressure = 0;
        fPressure_max=0;
    end
    
    
    methods
        function this = reducer_exme(oPhase, sName, fPressure_max)
            this@matter.procs.exmes.gas(oPhase, sName);
            this.fPressure_max = fPressure_max;
        end
        
        
        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            
            temp=this.oPhase.fPressure;
            if this.fPressure_max<temp
                this.fPortPressure = this.fPressure_max;
                fPortPressure=this.fPortPressure;
            else
                this.fPortPressure = temp;
                fPortPressure=temp;
            end
            
            fPortTemperature = this.oPhase.fTemperature;
        end
    end
end

