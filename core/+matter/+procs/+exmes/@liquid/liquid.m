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
        fAcceleration = 0; %in m/s²
        
        fHeightExMe = 0;
    end
    
    methods
        function this = liquid(oPhase, sName, fAcceleration, fHeightExMe)
            %% liquid exme class constructor
            % as liquid exmes can have gravity driven flows, the liquid
            % exme also can be given additional properties and also
            % performs calculations to decide what additional pressure from
            % the gravity of the liquid is acting on it depending on its
            % position in the store and the acceleration
            %
            % Required Inputs:
            % oPhase:   the phase the exme is attached to
            % sName:    the name of the processor
            %
            % Optional Inputs:
            % fAcceleration:    The current acceleration acting on the
            %                   liquid to which the exme is connected in
            %                   m/s^2
            % fHeightExMe:      The height of the ExMe from the bottom in
            %                   m. The bottom is defined as the direction
            %                   in which fAcceleration is pointing
            this@matter.procs.exme(oPhase, sName);
            
            if nargin >= 3
                this.fAcceleration = fAcceleration;
            end
            if nargin >= 4
                this.fHeightExMe = fHeightExMe;
            end
            
            tTankGeomParams = this.oPhase.oStore.tGeometryParameters;
            fVolumeTank = this.oPhase.oStore.fVolume;
            fVolumeLiquid = this.oPhase.fVolume;
            
            if strcmpi(tTankGeomParams.Shape, 'box')
                fAreaTank = tTankGeomParams.Area;
                
                % Move heightexme to the exme, to allow different heights
                % for different exmes, when setting the parameter to exme
                % check if it is consistent with height of store
                
                fHeightTank = fVolumeTank/fAreaTank;
                if fHeightTank < this.fHeightExMe
                    error('the height of the exme is larger than the height of the tank')
                end
                
                fLiquidLevelTank = fVolumeLiquid/fAreaTank;
                
                if (fLiquidLevelTank - this.fHeightExMe) >= 0
                    this.fLiquidLevel = fLiquidLevelTank - this.fHeightExMe;
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
        
        function [ fExMePressure, fExMeTemperature ] = getExMeProperties(this)
            %% lquid getExMeProperties
            % Returns the exme properties. Since gravity driven flows are
            % an option for liquid exmes the pressure of the ExMe itself is
            % returned. Only if the exme pressure is empty, the pressure of
            % the phase is used.
            %
            % Outputs:
            % fExMePressure:    Pressure of the Mass passing through this ExMe in Pa
            % fExMeTemperature: Temperature of the Mass passing through this ExMe in K
            
            if isempty(this.fPressure)
                fExMePressure = this.oPhase.fPressure;
            else
                fExMePressure    = this.fPressure;
            end
            fExMeTemperature = this.fTemperature;
            
            
        end
        
        function setPortAcceleration(this, fAcceleration)
            %% setPortAcceleration
            % can be used to overwrite the ExMe acceleration, e.g. to model
            % changing gravity conditions on a flight
            %
            % Required Inputs:
            % fAcceleration:    The current acceleration acting on the
            %                   liquid to which the exme is connected in
            %                   m/s^2
            this.fAcceleration = fAcceleration;
            
        end
        
        function this = update(this)
            %% liquid exme update function
            %
            % if an acceleration for the ExMe is defined, gravity driven
            % pressure calculations are performed. Also the exme checks the
            % current level of liquid within the tank based on the tank
            % geometry and then calculaltes a pressure based on the liquid
            % level, acceleration and density of liquid
            
            if this.fAcceleration ~= 0
                tTankGeomParams = this.oPhase.oStore.tGeometryParameters;
                fVolumeTank     = this.oPhase.oStore.fVolume;
                fVolumeLiquid   = this.oPhase.fVolume;
                fPressureTank   = this.oPhase.fPressure;
                fMassTank       = this.oPhase.fMass;
                
                this.fTemperature = this.oPhase.fTemperature;
                fDensityLiquid = fMassTank/fVolumeLiquid;
                
                if strcmp(tTankGeomParams.Shape, 'box') || strcmp(tTankGeomParams.Shape,'Box')
                    fAreaTank = tTankGeomParams.Area;
                    
                    fHeightTank = fVolumeTank/fAreaTank;
                    if fHeightTank < this.fHeightExMe
                        error('the height of the exme is larger than the height of the tank')
                    end
                    
                    fLiquidLevelTank = fVolumeLiquid/fAreaTank;
                    
                    if (fLiquidLevelTank - this.fHeightExMe) >= 0
                        this.fLiquidLevel = fLiquidLevelTank - this.fHeightExMe;
                    end
                else
                    error('check the name for store geometry')
                end
                
                %calculates the pressure at the exme by using the inherent tank
                %pressure for 0g and adding the pressure which is created by
                %gravity
                this.fPressure = fPressureTank + this.fLiquidLevel*this.fAcceleration*fDensityLiquid;
                
            else
                this.fPressure = this.oPhase.fPressure;
            end
        end
    end
end