classdef mixture < matter.procs.exme
    %MIXTURE An EXME that interfaces with a mixture phase
    %   The main purpose of this class is to provide the method
    %   getPortProperties() which returns the pressure and temperature of
    %   the attached phase. 
    
    properties
    end
    
    methods
        function this = mixture(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end
        
        function [ fExMePressure, fExMeTemperature ] = getExMeProperties(this)
            
            % Updated - uses the mass change rate as well. Faster ...?
%             fMassSinceUpdate = this.oPhase.fCurrentTotalMassInOut * (this.oPhase.oStore.oTimer.fTime - this.oPhase.fLastMassUpdate);
            
            fExMePressure    = this.oPhase.fPressure;
            
            fExMeTemperature = this.oPhase.fTemperature;
            
        end
        
        
    end
    
end

