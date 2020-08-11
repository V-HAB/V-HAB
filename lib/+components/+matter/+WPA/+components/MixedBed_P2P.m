classdef MixedBed_P2P < matter.procs.p2ps.flow
    
    %% Mixed Bed = P2P doing ion exchange in the Multifiltration beds based on
    % DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER PROCESSOR
    % written by David Robert Hokanson
    
    properties (SetAccess = public, GetAccess = public)
        
        % Vector containing the seperation factors for each ion
        afSeperationFactors; % [-]
        % Matrix containing the division of the specific ion seperation
        % factor with all other seperations factors as rows
        mfSeperationFactors; % [-]
        
        % total Volume of the cell 
        fCellVolume; % [m^3]
        % The void fraction of the cell volume (cell volume is the volume
        % of resin and fluid)
        rVoidFraction; % [-]
        % Resin mass (not the ion mass)!
        fResinMass; % [kg]
        
        % Boolean to decide if this is a cation or anion bed
        bCationResin;
        
        % Boolean vector to find the specific ions from the V-HAB vectors
        abIons;
        
        % Object reference to the P2P handling desorption:
        oDesorptionP2P;
    end
    
    methods
        function this = MixedBed_P2P(oStore, sName, sPhaseIn, sPhaseOut, oDesorptionP2P)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn,sPhaseOut);
            
            this.oDesorptionP2P = oDesorptionP2P;
            this.bCationResin   = oStore.oContainer.bCationResin;
            this.rVoidFraction 	= oStore.oContainer.rVoidFraction;
            this.fResinMass     = oStore.oContainer.fResinMass  / oStore.oContainer.iCells;
            this.fCellVolume    = oStore.oContainer.fVolume     / oStore.oContainer.iCells;
            
            if this.bCationResin
                % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
                % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
                % PROCESSOR", David Robert Hokanson, 2004, Table 2-14
                this.afSeperationFactors = zeros(1, this.oMT.iSubstances);
                this.afSeperationFactors(this.oMT.tiN2I.Hplus)    = 1;
                this.afSeperationFactors(this.oMT.tiN2I.Naplus)   = 1.68;
                this.afSeperationFactors(this.oMT.tiN2I.Kplus)    = 2.15;
                this.afSeperationFactors(this.oMT.tiN2I.Ca2plus)  = 72.7;
                this.afSeperationFactors(this.oMT.tiN2I.NH4)      = 1.9;
                
                this.abIons = (this.afSeperationFactors ~= 0);
            else
                % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
                % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
                % PROCESSOR", David Robert Hokanson, 2004, Table 2-15
                this.afSeperationFactors = zeros(1, this.oMT.iSubstances);
                this.afSeperationFactors(this.oMT.tiN2I.OH)       = 1;
                this.afSeperationFactors(this.oMT.tiN2I.CMT)      = 214;
                this.afSeperationFactors(this.oMT.tiN2I.Clminus)  = 16.7;
                this.afSeperationFactors(this.oMT.tiN2I.C4H7O2)   = 3.21;
                this.afSeperationFactors(this.oMT.tiN2I.C2H3O2)   = 1.99;
                this.afSeperationFactors(this.oMT.tiN2I.HCO3)     = 4.99;
                this.afSeperationFactors(this.oMT.tiN2I.SO4)      = 149;
                this.afSeperationFactors(this.oMT.tiN2I.C3H5O3)   = 2.266;
                
                this.abIons = (this.afSeperationFactors ~= 0);
            end
            
            this.mfSeperationFactors = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            
            this.mfSeperationFactors(this.abIons, this.abIons) = this.afSeperationFactors(this.abIons)' ./ this.afSeperationFactors(this.abIons);
            
            this.mfSeperationFactors(logical(eye(this.oMT.iSubstances))) = 0;
            
        end
        
        function calculateFlowRate(this, afInsideInFlowRate, aarInsideInPartials, ~, ~)
            
            % calculate the current inflows
            afPartialInFlows = sum((afInsideInFlowRate .* aarInsideInPartials),1);
            afPartialInFlows = afPartialInFlows + this.oIn.oPhase.toManips.substance.afPartialFlows;
            afPartialInFlows(afPartialInFlows < 0) = 0;
            
            % Now we calculate the total molar equivalents flowing in the
            % liquid [mol * valence / s]
            afEquivalentInletFlows = zeros(1, this.oMT.iSubstances);
            afEquivalentInletFlows(this.abIons)  = (afPartialInFlows(this.abIons) ./ this.oMT.afMolarMass(this.abIons)) .* abs(this.oMT.aiCharge(this.abIons));

            % From these we can also calculate the total equivalent flow,
            % simply by summing it up
            fTotalEquivalentFlows = sum(afEquivalentInletFlows); %[eq/s]

            fDensity = this.oMT.calculateDensity(this.oIn.oPhase);
            fVolumetricFlowRate = sum(afPartialInFlows) / fDensity;

            % We also require the current resin phase ratios of the
            % adsorbents:
            afCurrentAdsorbentEquivalentRatios = (this.oOut.oPhase.afMass(this.abIons) .* abs(this.oMT.aiCharge(this.abIons))) ./ (this.fResinMass .* this.oMT.afMolarMass(this.abIons));

            % Here we calculate the sum of the seperation factors (called
            % alpha_ij in the Dissertation) and the current adsorbent mass
            % ratios (q_j in the Dissertation). We directly do so for all
            % Ions i over all ions j!
            afSeperationFactorSumValues = sum(this.mfSeperationFactors(this.abIons,this.abIons) .* afCurrentAdsorbentEquivalentRatios, 2);
            afSeperationFactorSumValues = afSeperationFactorSumValues';

            mfSeperationFactorSumWithoutSelf = this.mfSeperationFactors;
            afSeperationFactorSumWithoutSelf = sum(mfSeperationFactorSumWithoutSelf(this.abIons,this.abIons) .* afCurrentAdsorbentEquivalentRatios, 2);
            afSeperationFactorSumWithoutSelf = afSeperationFactorSumWithoutSelf';

            % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
            % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
            % PROCESSOR", David Robert Hokanson, 2004, Equation (III-65)
            % for Cations or (III-68) for Anions on page 181/182
            %
            % The equation was adjusted slightly, the total concentration
            % is now calculated from the in flows, to accomodated the flow
            % phase implemention from V-HAB!
            dqdt = zeros(1, this.oMT.iSubstances);
            dqdt(this.abIons) = afEquivalentInletFlows(this.abIons) - fTotalEquivalentFlows * (afCurrentAdsorbentEquivalentRatios ./ afSeperationFactorSumValues) ./...
                 (this.fResinMass + this.rVoidFraction .* this.fCellVolume .* (fTotalEquivalentFlows / fVolumetricFlowRate) .* afSeperationFactorSumWithoutSelf ./ afSeperationFactorSumValues.^2);

            % The value dqdt is in mol*valence / resin mass. Therefore, we
            % have to transform it into mass flows for V-HAB
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.abIons)  = dqdt(this.abIons) .* this.fResinMass .* this.oMT.afMolarMass(this.abIons) ./ abs(this.oMT.aiCharge(this.abIons));

            
            if this.bCationResin
                afPartialFlowRates(this.oMT.tiN2I.Hplus)    = 0;
            else
                afPartialFlowRates(this.oMT.tiN2I.OH)       = 0;
            end
            
            afDesorptionTime = this.oOut.oPhase.afMass ./ afPartialFlowRates;
            afPartialFlowRates(afDesorptionTime > -20 & afDesorptionTime < 0) = - this.oOut.oPhase.afMass(afDesorptionTime > -20 & afDesorptionTime < 0) ./ 20;
            
            abLimitFlows = afPartialFlowRates > afPartialInFlows;
            afPartialFlowRates(abLimitFlows) = afPartialInFlows(abLimitFlows);
            
            dqdt(this.abIons) = (abs(this.oMT.aiCharge(this.abIons)) ./ this.oMT.afMolarMass(this.abIons)) .* afPartialFlowRates(this.abIons);
            
            % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
            % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
            % PROCESSOR", David Robert Hokanson, 2004, Equation (III-63)
            %
            % This equation basically states that for each equivalent that
            % is adsorbed by the ion exchange bed, the equivalent mol
            % number of presaturated ions must be released from the resin
            if this.bCationResin
                dqdt(this.oMT.tiN2I.Hplus) = 0;
                afPartialFlowRates(this.oMT.tiN2I.Hplus)    = - sum(dqdt * this.fResinMass) * this.oMT.afMolarMass(this.oMT.tiN2I.Hplus);
            else
                dqdt(this.oMT.tiN2I.OH) = 0;
                afPartialFlowRates(this.oMT.tiN2I.OH)       = - sum(dqdt * this.fResinMass) * this.oMT.afMolarMass(this.oMT.tiN2I.OH);
            end
            
            afDesorptionFlowRates = zeros(1, this.oMT.iSubstances);
            afAdsorptionFlowRates = afDesorptionFlowRates;
            
            afAdsorptionFlowRates(afPartialFlowRates > 0) = afPartialFlowRates(afPartialFlowRates > 0);
            afDesorptionFlowRates(afPartialFlowRates < 0) = afPartialFlowRates(afPartialFlowRates < 0);
            abLimitDesorption = this.oOut.oPhase.afMass < 1e-12;
            afDesorptionFlowRates(abLimitDesorption) = 0;
            
            fDesorptionFlowRate = sum(afDesorptionFlowRates);
            if fDesorptionFlowRate == 0
                arExtractPartialsDesorption = zeros(1,this.oMT.iSubstances);
            else
                arExtractPartialsDesorption = afDesorptionFlowRates/fDesorptionFlowRate;
            end
            
            fAdsorptionFlowRate = sum(afAdsorptionFlowRates);
            if fAdsorptionFlowRate == 0
                arExtractPartialsAdsorption = zeros(1,this.oMT.iSubstances);
            else
                arExtractPartialsAdsorption = afAdsorptionFlowRates/fAdsorptionFlowRate;
            end
            
            this.setMatterProperties(fAdsorptionFlowRate, arExtractPartialsAdsorption);
            this.oDesorptionP2P.setMatterProperties(fDesorptionFlowRate, arExtractPartialsDesorption);
            
        end
    end
    
    methods (Access = protected)
        function update(~)
        end
    end
end
