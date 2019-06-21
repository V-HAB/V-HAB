classdef gas < matter.procs.exme
    %GAS An EXME that interfaces with a gaseous phase
    %   The main purpose of this class is to provide the method
    %   getPortProperties() which returns the pressure and temperature of
    %   the attached phase.
    
    methods

        function this = gas(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end

        function [ fExMePressure, fExMeTemperature ] = getExMeProperties(this)
            fExMeTemperature = this.oPhase.fTemperature;
            
            fExMePressure = this.oPhase.fPressure;
            
        end
    end
end

