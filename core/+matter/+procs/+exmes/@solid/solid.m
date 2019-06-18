classdef solid < matter.procs.exme
    %SOLID An EXME that interfaces with a solid phase
    %   The main purpose of this class is to provide the method
    %   getPortProperties() which returns the pressure and temperature of
    %   the attached phase. 
    
    methods
        function this = solid(oPhase, sName)
            this@matter.procs.exme(oPhase, sName);
        end
        
        function [ fExMePressure, fExMeTemperature ] = getPortProperties(this)
            
            fExMePressure       = this.oPhase.fPressure;
            fExMeTemperature    = this.oPhase.fTemperature;
        end
    end
end

