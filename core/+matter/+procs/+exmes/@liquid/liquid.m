classdef liquid < matter.procs.exme
    %LIQUID An EXME that interfaces with a liquid phase
    
    properties (SetAccess = protected, GetAccess = public)

        % Pressure on the exme
        fPressure; %in Pa
        
        fTemperature; %in K
  
        %level of liquid above the exme, not overall level in the store
        fLiquidLevel = 0; % in m
        
        %acceleration affecting the liquid at this port, can be gravity or
        %from flying accelerating space craft. The acceleration has to be
        %set with the correct sign depending on wether the liquid is pulled
        %away (negative sign) from the exme or pressed toward it (positive
        %sign)
        fAcceleration; %in m/s²
        
    end
    
    methods
        function this = liquid(oPhase, sName, fAcceleration)
            this@matter.procs.exme(oPhase, sName);
            
            if nargin == 3
                this.fAcceleration = fAcceleration;
            else
                this.fAcceleration = 0;
            end
            
            tTankGeomParams = this.oPhase.oStore.tGeometryParameters;
            fVolumeTank = this.oPhase.oStore.fVolume;
            fVolumeLiquid = this.oPhase.fVolume;
            
            if strcmpi(tTankGeomParams.Shape, 'box')
                fAreaTank = tTankGeomParams.Area;
                fHeightExMe = tTankGeomParams.HeightExMe;
                
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
            
            this.fTemperature = this.oPhase.fTemperature;
        
        end
        
        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            
            fPortPressure    = this.fPressure;
            fPortTemperature = this.fTemperature;
            
            if isempty(this.fPressure)
                fPortPressure = this.oPhase.fPressure;
            end
            
        end
        
        function [ ] = setPortAcceleration(this, fAcceleration)
            
            this.fAcceleration = fAcceleration;
            
        end
        
        function this = update(this)
           
            tTankGeomParams = this.oPhase.oStore.tGeometryParameters;
            fVolumeTank     = this.oPhase.oStore.fVolume;
            fVolumeLiquid   = this.oPhase.fVolume;
            fPressureTank   = this.oPhase.fPressure;
            fMassTank       = this.oPhase.fMass;
            
            this.fTemperature = this.oPhase.fTemperature;
            fDensityLiquid = fMassTank/fVolumeLiquid;
            
            if strcmp(tTankGeomParams.Shape, 'box') || strcmp(tTankGeomParams.Shape,'Box')
                fAreaTank = tTankGeomParams.Area;
                fHeightExMe = tTankGeomParams.HeightExMe;
                
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
            this.fPressure = fPressureTank + this.fLiquidLevel*this.fAcceleration*fDensityLiquid;   
            
        end
    end
end

