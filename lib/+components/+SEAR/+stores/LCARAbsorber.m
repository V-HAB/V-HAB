classdef LCARAbsorber < matter.store
%LCARAbsorber Lithium Chloride Absorber Radiator Model 
%
%   Absorber is modeled as a store with two phases, one representing the
%   flow volume, the other representing the volume taken up by the material
%   absorbing matter from the gas stream through the flow volume.The two
%   phases are connected by a phase-to-phase (p2p) processor. The flow rate
%   through the p2p corresponds to the rate of absorption.
%
%   Input:
%   --------------------- Absorber ----------------------------------------
%   fMassLiCl           [kg]    Mass of LiCl salt in absorber module 
%   rMassFracLiCl       [-]     Initial mass fraction of LiCl
%   (=m(LiCl)/m(total))
%   --------------------- Radiator ----------------------------------------
%   fArea               [m2]    Radiating surface area
%   rEmissivity         [-]     Emissivity of the surface
%   rAlphaAbsorb        [-]     Absorbtance
%   rViewFac            [-]     View factor
%
%   Assumptions:
%   none
    
    properties (SetAccess = protected, GetAccess = public)
        % Phase to phase processor object
        oProc;
        % Temperature of the radiator [K]
        fTempRad = 293.15;
        % Radiated Heat Flow [W]
        fRadHeatFlow = 0;
        % Last time when temperature was updated [s]
        fLastTempUpdate = 0;   
    end
    
    properties (SetAccess = public, GetAccess = public)
        % Temperature of the environment [K]
        fTempSink = 3;
        % Additional heat flow out of the LCAR [W]
        fHeatLoss = 0;
    end
    
    methods
        function this = LCARAbsorber(oContainer, sName, tParameters)
            %% LCAR Absorber Store
            
            % Creating a matter store object
            this@matter.store(oContainer, sName);
            
            %% Graphite phase for the thermal system
            
            fVolumeGraphite = tParameters.fAbsorberArea * tParameters.fGraphitePlateThickness;
            fMassGraphite   = this.oMT.ttxMatter.Graphite.ttxPhases.tSolid.Density * fVolumeGraphite;
            
            matter.phases.solid(this, 'RadiatorSurface', struct('Graphite', fMassGraphite), fVolumeGraphite, tParameters.fInitialTemperature);
            
            %% Add Flow Phase (Vapor)         

            oFlow = components.SEAR.phases.FlowPhase(this,...
                                        'Vapor',...
                                        struct('H2O', 1.26e-5),...
                                        1,...
                                        tParameters.fInitialTemperature);   
            oFlow.bSynced  = true;
            
            tTimeStepProperties.fFixedTimeStep = 2;
            oFlow.setTimeStepProperties(tTimeStepProperties);
            
     

            %% Add Absorbent Phase (LiCl Solution)
            
            % Enter initial LiCl mass fraction [-]
            %rMassFracLiCl = 0.95; 
            % Enter mass of absorbent salt in LCAR [kg]
            %fMassLiCl = 0.426;  %1 - honeycomb LCAR demonstrator (2013)
            %fMassLiCl = 0.768;  %2 - subscale prototype of flexible LCAR design (2012)
            %fMassLiCl = 2.1;    %3 - full-scale multifunctional LCAR (perfect honeycomb)
            %fMassLiCl = 3;      %4 - user defined
            
            fMassH2O = (tParameters.fMassLiCl / tParameters.fInitialMassFraction) - tParameters.fMassLiCl;
            tfMasses = struct('H2O', fMassH2O, 'LiCl', tParameters.fMassLiCl);
            
            % Add AbsorbentPhase to store
            oAbsorberPhase = components.SEAR.phases.AbsorbentPhase(this,...
                                        'AbsorberPhase',... Name
                                        tfMasses,       ... Mass content
                                        tParameters.fInitialTemperature ...
                                        ); 
            
            oAbsorberPhase.bSynced  = true;
            
            tTimeStepProperties.fFixedTimeStep = 2;
            oAbsorberPhase.setTimeStepProperties(tTimeStepProperties);
            
            %% Exmes attached to phases
            
            % Create an Exme for incoming mass flow
            matter.procs.exmes.gas(oFlow,     'In');
            % Create an Exme to release non-condensible gases 
            matter.procs.exmes.gas(oFlow,     'Out');            
            % Create Exmes for p2p processor
            matter.procs.exmes.gas(oFlow,     'absorberport');
            matter.procs.exmes.liquid(oAbsorberPhase, 'absorberport');
            
            %% Physical Absorber as p2p processor
            
            % Creating the p2p processor
            % PhysicalAbsorber(oStore, sName, sPhaseIn, sPhaseOut, sSpecies)
            this.oProc = components.SEAR.processors.PhysicalAbsorber(this, 'absorberproc','Vapor.absorberport', 'AbsorberPhase.absorberport','H2O');

        end
        
        
    end

   
%     methods (Access = public)
%         function updateRadiatorTemp(this, fHeatFlow)
%             %% Choose radiator design concept
%             % 1 - honeycomb LCAR demonstrator (2013)
%             % 2 - subscale prototype of flexible LCAR design (2012)
%             % 3 - full-scale multifunctional LCAR (estimations)
%             % 4 - user defined            
%             flag_Design = 1;
%             
%             switch flag_Design
%                 case 1
%                     fArea = 0.186;      %[m2]
%                     rEmissivity = 0.9;
%                     rViewFac = 0.98;
%                     rAlphaAbsorb = 1;
%                 case 2
%                     fArea = 0.264;      %[m2]
%                     rEmissivity = 0.9;
%                     rViewFac = 1;
%                     rAlphaAbsorb = 1;
%                 case 3
%                     fArea = 0.697;      %[m2]
%                     rEmissivity = 0.9;
%                     rViewFac = 1;
%                     rAlphaAbsorb = 1;
%                 case 4
%                     fArea = 0.81;      %[m2]
%                     rEmissivity = 0.9;
%                     rViewFac = 1;
%                     rAlphaAbsorb = 1;                   
%             end
%             
%             %% Compute radiator temperature [K] and radiator power [W]
%             
%             % Bolzmann Constant
%             fBolzmann = 5.67e-8;            
%             % Heat capacity of absorbent
%             fHeatCapacity = this.toPhases.AbsorberPhase.fHeatCap;
%             
%             % Time step needed for integration of differential equation
%             % (Euler Method)
%             fTime     = this.oTimer.fTime;
%             fTimeStep = fTime - this.fLastTempUpdate;
%             
%             % Return if no time has passed
%             if fTimeStep == 0, return; end;
%             
%             this.fLastTempUpdate = fTime;
%             fTempLastUpdate      = this.fTempRad;
%             
%             % Calculate radiator temperature (integration with time step)
%             this.fTempRad = fTempLastUpdate + fTimeStep * (1 / fHeatCapacity) * ...
%                             (...
%                             (fArea * rEmissivity * rViewFac * rAlphaAbsorb * ...
%                             fBolzmann) * (((this.fTempSink)^4) - (fTempLastUpdate^4))...
%                             + fHeatFlow...
%                             - this.fHeatLoss);
%                         
%             % Throw warning when temperature is below 273K (some formulas
%             % concerning properties of LiCl are only valid for T>273K
%             if this.fTempRad <= 273
%             disp('Warning! Temperature below freezing point');
%             end
%                         
%             % Compute radiated heat flow
%             this.fRadHeatFlow = fArea * rEmissivity * rViewFac * rAlphaAbsorb * ...
%                 fBolzmann * ((this.fTempSink^4) - (this.fTempRad^4));
%             
% 
%         end
%            
% 
%         
%     end
end