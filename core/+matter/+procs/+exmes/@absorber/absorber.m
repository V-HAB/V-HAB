classdef absorber < matter.procs.exme
    %ABSORBER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = absorber(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end
        
        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            
            % Updated - uses the mass change rate as well. Faster ...?
            %fMassSinceUpdate = this.oPhase.fCurrentTotalMassInOut * (this.oPhase.oStore.oTimer.fTime - this.oPhase.fLastMassUpdate);
            
            
            fPortPressure    = [];
            %fPortPressure    = this.oPhase.fMassToPressure * (this.oPhase.fMass);
            
            fPortTemperature = this.oPhase.fTemperature;
            
        end
        
        
    end
    
end

