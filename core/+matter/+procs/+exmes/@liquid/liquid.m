classdef liquid < matter.procs.exme
    
    properties (SetAccess = protected, GetAccess = public)

        % Pressure on the exme
        fPressure; %in Pa
  
        %level of liquid above the exme, not overall level in the store
        fLiquidLevel = 0; % in m
        
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
        function this = liquid(oPhase, sName, fFlowSpeed, fAcceleration)
            this@matter.procs.exme(oPhase, sName);
            
            if nargin == 3
                this.fAcceleration = 0;
                this.fFlowSpeed = fFlowSpeed;
            elseif nargin == 4
                this.fAcceleration = fAcceleration;
                this.fFlowSpeed = fFlowSpeed;
            else
                this.fAcceleration = 0;
                this.fFlowSpeed = 0;
            end
            
            sGeometryTank = this.oPhase.oStore.sGeometry;
            fVolumeTank = this.oPhase.oStore.fVolume;
            fVolumeLiquid = this.oPhase.fVolume;
            
            if strcmp(sGeometryTank.Shape, 'box') || strcmp(sGeometryTank.Shape,'Box')
                fAreaTank = sGeometryTank.Area;
                fHeightExMe = sGeometryTank.HeightExMe;
                
                fHeightTank = fVolumeTank/fAreaTank;
                if fHeightTank < fHeightExMe
                    error('the height of the exme is larger than the height of the tank')
                end
                
                fLiquidLevelTank = fVolumeLiquid/fAreaTank;
                
                if (fLiquidLevelTank-fHeightExMe) >= 0
                    this.fLiquidLevel = fLiquidLevelTank-fHeightExMe;
                end
           	else
                error('check the name for store geometry')
            end
            
            %calculates the pressure at the exme by using the inherent tank
            %pressure for 0g and adding the pressure which is created by
            %gravity
            this.fPressure = this.oPhase.fPressure + this.fLiquidLevel*...
                this.fAcceleration*this.oPhase.fDensity;
        
        end
        
        function [ fPortPressure, fPortTemperature , fPortFlowSpeed, fPortAcceleration] = getPortProperties(this)
            
            fPortPressure    = this.fPressure;
            
            fPortTemperature = this.oPhase.fTemp;
            
            fPortFlowSpeed = this.fFlowSpeed;
            
            fPortAcceleration = this.fAcceleration;
        end
        function [ ] = setPortProperties(this, fPressureTank, fPortTemperature, fFlowSpeed, fAcceleration, fDensity)
           
            if nargin == 3
                this.oPhase.setTemp(fPortTemperature);
            elseif nargin == 4
                this.oPhase.setTemp(fPortTemperature);
                this.fFlowSpeed = fFlowSpeed;
            elseif nargin >= 5
                this.oPhase.setTemp(fPortTemperature);
                this.fFlowSpeed = fFlowSpeed;
                this.fAcceleration = fAcceleration;
            end
            
            if nargin < 6
                fDensity = 0;
            end
            
            sGeometryTank = this.oPhase.oStore.sGeometry;
            fVolumeTank = this.oPhase.oStore.fVolume;
            fVolumeLiquid = this.oPhase.fVolume;
            
            if strcmp(sGeometryTank.Shape, 'box') || strcmp(sGeometryTank.Shape,'Box')
                fAreaTank = sGeometryTank.Area;
                fHeightExMe = sGeometryTank.HeightExMe;
                
                fHeightTank = fVolumeTank/fAreaTank;
                if fHeightTank < fHeightExMe
                    error('the height of the exme is larger than the height of the tank')
                end
                
                fLiquidLevelTank = fVolumeLiquid/fAreaTank;
                
                if (fLiquidLevelTank-fHeightExMe) >= 0
                    this.fLiquidLevel = fLiquidLevelTank-fHeightExMe;
                end
            else
                error('check the name for store geometry')
            end
            
            %calculates the pressure at the exme by using the inherent tank
            %pressure for 0g and adding the pressure which is created by
            %gravity
            this.fPressure = fPressureTank + this.fLiquidLevel*...
                this.fAcceleration*fDensity;   
            
            this.oPhase.setPressure(fPressureTank);
            
            
        end
    end
end

