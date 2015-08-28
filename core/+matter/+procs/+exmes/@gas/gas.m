classdef gas < matter.procs.exme

    methods

        function this = gas(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end

        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)

            % Updated - uses the mass change rate as well. Faster ...?
            fMassSinceUpdate = this.oPhase.fCurrentTotalMassInOut * (this.oPhase.oStore.oTimer.fTime - this.oPhase.fLastMassUpdate);

            fPortPressure    = this.oPhase.fMassToPressure * (this.oPhase.fMass + fMassSinceUpdate);
            fPortTemperature = this.oPhase.fTemperature;

        end

    end

end

