classdef gas < matter.procs.exme
    %GAS An EXME that interfaces with a gaseous phase
    %   The main purpose of this class is to provide the method
    %   getPortProperties() which returns the pressure and temperature of
    %   the attached phase.
    
    methods

        function this = gas(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end

        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            fPortTemperature = this.oPhase.fTemperature;
            
            % Updated - uses the mass change rate as well. Faster ...?
            fMassSinceUpdate = this.oPhase.fCurrentTotalMassInOut * (this.oPhase.oStore.oTimer.fTime - this.oPhase.fLastMassUpdate);

            
            fPortPressure = this.oPhase.fMassToPressure * (this.oPhase.fMass + fMassSinceUpdate);
            
        end

    end

end

