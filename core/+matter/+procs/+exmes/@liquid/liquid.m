classdef liquid < matter.procs.exme
    
    properties (SetAccess = protected, GetAccess = public)

        % Pressure on the exme
        fPressure; %in Pa
  
        %level of liquid above the exme, not overall level in the store
        fLiquidLevel; % in m
        
        %acceleration affecting the liquid at this port, can be gravity or
        %from flying accelerating space craft. The acceleration has to be
        %set with the correct sign depending on wether the liquid is pulled
        %away (negative sign) from the exme or pressed toward it (positive
        %sign)
        fAcceleration; %in m/s²
        
        %Flow speed over this port
        fFlowSpeed; %in m/s
        
    end
    
    methods
        function this = liquid(oPhase, sName, fFlowSpeed, fLiquidLevel, fAcceleration)
            this@matter.procs.exme(oPhase, sName);
            
            if nargin == 3
                this.fLiquidLevel = 0;
                this.fAcceleration = 0;
                this.fFlowSpeed = fFlowSpeed;
            elseif nargin == 4
                this.fLiquidLevel = fLiquidLevel;
                this.fAcceleration = 0;
                this.fFlowSpeed = fFlowSpeed;
            elseif nargin == 5
                this.fLiquidLevel = fLiquidLevel;
                this.fAcceleration = fAcceleration;
                this.fFlowSpeed = fFlowSpeed;
            else
                this.fLiquidLevel = 0;
                this.fAcceleration = 0;
                this.fFlowSpeed = 0;
            end
            
            %calculates the pressure at the exme by using the inherent tank
            %pressure for 0g and adding the pressure which is created by
            %gravity
            this.fPressure = this.oPhase.fPressure + this.fLiquidLevel*...
                this.fAcceleration*this.oPhase.fDensity;
        
        end
        
        function [ fPortPressure, fPortTemperature , fPortFlowSpeed, fPortLiquidLevel, fPortAcceleration] = getPortProperties(this)
            
            fPortPressure    = this.fPressure;
            
            fPortTemperature = this.oPhase.fTemp;
            
            fPortLiquidLevel = this.fLiquidLevel;
            
            fPortFlowSpeed = this.fFlowSpeed;
            
            fPortAcceleration = this.fAcceleration;
        end
        function [ ] = setPortProperties(this, fPortPressure, fPortTemperature, fFlowSpeed, fLiquidLevel, fAcceleration, fDensity)
            
            this.fPressure = fPortPressure;
            fDensity = 0;
            
            if nargin == 3
                this.oPhase.setTemp(fPortTemperature);
            elseif nargin == 4
                this.oPhase.setTemp(fPortTemperature);
                this.fFlowSpeed = fFlowSpeed;
            elseif nargin == 5
                this.oPhase.setTemp(fPortTemperature);
                this.fLiquidLevel = fLiquidLevel;
                this.fFlowSpeed = fFlowSpeed;
            elseif nargin == 6
                this.oPhase.setTemp(fPortTemperature);
                this.fLiquidLevel = fLiquidLevel;
                this.fFlowSpeed = fFlowSpeed;
                this.fAcceleration = fAcceleration;
            elseif nargin == 7
                this.oPhase.setTemp(fPortTemperature);
                this.fLiquidLevel = fLiquidLevel;
                this.fFlowSpeed = fFlowSpeed;
                this.fAcceleration = fAcceleration;
            end
            
            this.oPhase.setPressure(this.fPressure-(this.fLiquidLevel*...
                this.fAcceleration*fDensity));
            
            
        end
    end
end

