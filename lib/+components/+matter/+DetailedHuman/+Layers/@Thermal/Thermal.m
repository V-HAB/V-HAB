classdef Thermal < vsys
% This is a simple thermal layer for the detailed human model which can be
% used if exact thermal calculations are not of interest. Limitations and
% discussions are provided here in the following comments:
%
%% Overall assumption:
% The basic assumption for this layer is, that the human is in thermal
% equilibrium at all times. This means the produced metabolic heat load
% this.Metabolic.fMetabolicHeatFlow must be released to the environment.
% The ways of heat transfer are sweating (assumed to evaporate),
% respiration (air is heated and humidified), trans epidermal water loss
% (water evaporated through the skin) and remaining sensible heat transfer
%
% As interfaces, the exhaled air is already implemented and used, one
% matter branch for transpired water (combining sweat and TEWL) and a
% thermal manual branch for the remaining sensible heat output.
%
%% Sweat
% The VHP sweat calculation is very simple, but requires body core and skin
% temperature calculations: From Saltin 1972, Body temperatures and
% sweating during exhaustive exercise, Equation 11 ( Temperature values
% must be in °C)
% fTotalEvaporativeHeatLossPerArea = ( 6.9 * (fTempSkinC - 34) + 110.2 * (fTempCoreC - 36.4) ) * exp((fTempSkinC - 34)/10);
% Since accurate calculations for the core and skin temperature are not
% easy, this cannot be implemented for the simple thermal layer.
% 
% Instead for sweat the simple thermal layer assumes that a percentage of
% the additional thermal load during exercise is released through sweat
%            
%% Transepidermal Water Loss (TEWL)
% according to https://www.sciencedirect.com/topics/agricultural-and-biological-sciences/transepidermal-water-loss
% by Golara Honari, Howard Maibach, in Applied Dermatotoxicology, 2014,
% "The Measurement of Transepidermal Water Loss"
% the average value of TEWL is 300 to 400 ml per day. For the simple model
% we just assume 350 g/d of TEWL
%
    properties (SetAccess = protected, GetAccess = public)
        
        fRequiredSweatWaterFlow = 0;
        
        fPerspirationWaterOutput = 0; % [kg/s]
        
    end
    
    properties (Constant)
        % according to NIST chemistry webbook, at 373.15 K
        fEnthalpyOfVaporizationWater = 2.2574e6; % [J/kg]
            
        % Transepidermal Water Loss (TEWL)
        % according to https://www.sciencedirect.com/topics/agricultural-and-biological-sciences/transepidermal-water-loss
        % by Golara Honari, Howard Maibach, in Applied Dermatotoxicology, 2014,
        % "The Measurement of Transepidermal Water Loss"
        % the average value of TEWL is 300 to 400 ml per day. For the simple model
        % we just assume 350 g/d of TEWL
        fTransepidermalWaterLoss = 0.35 / (24*3600);
    end
    
    methods
        function this = Thermal(oParent, sName)
            this@vsys(oParent, sName, inf);
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            fHumanTissueDensity = this.oMT.calculateDensity('solid', struct('Human_Tissue', 1));
            
            fVolume = this.oParent.toChildren.Metabolic.fBodyMass / fHumanTissueDensity;
            
            matter.store(this, 'Thermal', fVolume);
            
            
            this.toStores.Thermal.createPhase('solid', 'Tissue', 1, struct('Human_Tissue', fVolume), this.oParent.fBodyCoreTemperature, 1e5);
            
        end
        
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            % We add a constant temperature heat source for the thermal
            % phase, which will maintain the body core temperature for the
            % phase. since the sensible heat output will be taken from this
            % phase
            oHeatSource = components.thermal.heatsources.ConstantTemperature('ThermalConstantTemperature');
            this.toStores.Thermal.toPhases.Tissue.oCapacity.addHeatSource(oHeatSource);
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            tTimeStepProperties.fMaxStep = 60;

            this.toStores.Thermal.toPhases.Tissue.oCapacity.setTimeStepProperties(tTimeStepProperties);
            
            tTimeStepProperties.rMaxChange = 0.1;
            
            this.toStores.Thermal.toPhases.Tissue.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
        
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            % We do not use the exec functions of the human layers, as it
            % is not possible to define the update order if we use the exec
            % functions!!
        end
     end
     
    methods (Access = {?components.matter.DetailedHuman.Human})
        
        function update(this)
            
            this.oParent.toChildren.Metabolic.fMetabolicHeatFlow;
            
            %% Respiration
            % Calculate the thermal energy from water evaporation
            fRespirationLatentHeatFlow = this.fEnthalpyOfVaporizationWater * this.oParent.toChildren.Respiration.fRespirationWaterOutput; % [W]
            
            % The constant temperature heat source is updated after this
            % exec is executed, so we are always one step behind. But in
            % sum this does not impact the thermal balance.
            fHeatFlowToHeatExhaledAir = this.oParent.toChildren.Respiration.toStores.Lung.toPhases.Air.oCapacity.toHeatSources.LungConstantTemperature.fHeatFlow;
            
            fOtherRespirationHeatFlows = this.oParent.toChildren.Respiration.toStores.Brain.toPhases.Blood.oCapacity.toHeatSources.BrainConstantTemperature.fHeatFlow + ...
                                         this.oParent.toChildren.Respiration.toStores.Tissue.toPhases.Blood.oCapacity.toHeatSources.TissueConstantTemperature.fHeatFlow;
                                     
            fRespirationHeatFlow = fRespirationLatentHeatFlow + fHeatFlowToHeatExhaledAir + fOtherRespirationHeatFlows;
            
            %% Transepidermal Water Loss (TEWL)
            % according to https://www.sciencedirect.com/topics/agricultural-and-biological-sciences/transepidermal-water-loss
            % by Golara Honari, Howard Maibach, in Applied Dermatotoxicology, 2014,
            % "The Measurement of Transepidermal Water Loss"
            % the average value of TEWL is 300 to 400 ml per day. For the simple model
            % we just assume 350 g/d of TEWL
            fTransepidermalWaterLossHeatFlow = this.fEnthalpyOfVaporizationWater * this.fTransepidermalWaterLoss; % [W]
            
            %% Sweat
            % Based on BVAD table 3.22 during exercise 2974 kJ/h of heat
            % are released in total, of which 2352 kJ/h are latent heat
            % (sweat and persiration). So we calculate the sweat ratio by
            % subtracting the respiration latent heat flow and the
            % transepidermal water loss heat flow from the total latent
            % heat flow specified in the BVAD and calculate a ratio based
            % on this. (2352 kJ/h = 653.33 W and 2974 = 826.11 W)
            fSweatHeatFlow = ((653.33 - fRespirationLatentHeatFlow - fTransepidermalWaterLossHeatFlow)/826.11) * (this.oParent.toChildren.Metabolic.fMetabolicHeatFlow - this.oParent.toChildren.Metabolic.fBaseMetabolicHeatFlow);
            if fSweatHeatFlow < 0
                fSweatHeatFlow = 0;
            end
            this.fRequiredSweatWaterFlow = fSweatHeatFlow / this.fEnthalpyOfVaporizationWater;
            
            % The flowrates for sweat are coming for the blood plasma
            % according to the V-HAB 1 code!
            fWaterFlowSweat = this.fRequiredSweatWaterFlow * this.oParent.toChildren.WaterBalance.rRatioOfAvailableSweat;
            
            % 3.5e-2 is the amount of Na in mol in one kg sweat
            % fNaPlusFlowSweat = fWaterFlowSweat * 3.5e-2 * this.oMT.afMolarMass(this.oMT.tiN2I.Naplus);
            
            %% Total Perspiratin
            this.fPerspirationWaterOutput =  fWaterFlowSweat + this.fTransepidermalWaterLoss;
            
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            % for now we neglect the sodim from sweat, as that spells
            % trouble. If we want to imlpement this, we need a specific
            % output branch for it as otherwise the cabin air would receive
            % sodium
            afPartialFlowRates(this.oMT.tiN2I.Naplus) 	= 0; %  fNaPlusFlowSweat;
            afPartialFlowRates(this.oMT.tiN2I.H2O)      = this.fPerspirationWaterOutput;
            this.oParent.toBranches.PerspirationWaterTransfer.oHandler.setFlowRate(afPartialFlowRates);
            
            fPerspirationHeatFlow = this.fEnthalpyOfVaporizationWater * this.fPerspirationWaterOutput; % [W]
            
            %% Sensible Heat Flow
            % All remaning energy is transfered into the current air phase
            % of the human model using the manual thermal solver branch
            % We also require a specific heat flow to heat up the ingested
            % matter to body temperature (or if the matter is hot, we have
            % to release additional heat):
            fHeatFlowToHeatIngestedMatter = this.oParent.toChildren.Digestion.toStores.Digestion.toPhases.Stomach.oCapacity.toHeatSources.StomachConstantTemperature.fHeatFlow;
            
            fSensibleHeatFlow = this.oParent.toChildren.Metabolic.fMetabolicHeatFlow - fRespirationHeatFlow - fPerspirationHeatFlow - fHeatFlowToHeatIngestedMatter;
           
            this.oParent.toThermalBranches.SensibleHeatOutput.oHandler.setHeatFlow(fSensibleHeatFlow);
        end
    end
end