classdef solid < matter.procs.exme
    %SOLID An EXME that interfaces with a solid phase
    %   The main purpose of this class is to provide the method
    %   getPortProperties() which returns the pressure and temperature of
    %   the attached phase. 
    
    methods
        function this = solid(oPhase, sName)
            %% solid exme class constructor
            % only calls the parent class constructor, nothing special
            %
            % Required Inputs:
            % oPhase:   the phase the exme is attached to
            % sName:    the name of the processor
            this@matter.procs.exme(oPhase, sName);
        end
        
        function [ fExMePressure, fExMeTemperature ] = getExMeProperties(this)
            %% gas getExMeProperties
            % Returns the exme properties of the phase, as gravity driven
            % flow is not implemented for gases
            %
            % Outputs:
            % fExMePressure:    Pressure of the Mass passing through this ExMe in Pa
            % fExMeTemperature: Temperature of the Mass passing through this ExMe in K
            fExMePressure       = this.oPhase.fPressure;
            fExMeTemperature    = this.oPhase.fTemperature;
        end
    end
end

