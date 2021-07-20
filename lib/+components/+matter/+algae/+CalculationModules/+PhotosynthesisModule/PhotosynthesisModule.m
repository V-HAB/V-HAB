classdef PhotosynthesisModule < base
    %PHOTOSYNTHESISMODULE calculates the changes due to the algal growth
    %rate as determined by the growth calculation modules. The mass flows
    %are calculated based on the stoichiometric growth equations for
    %different sources of nitrogen.
    %The class constructor allows to change the stoichiometric relations of the
    %growth equations. However, these reactions only change, if the algal
    %composition changes, and therefore the matter table also has to be updated
    %for a new molar mass if other algal compositions and resulting reactions
    %should be used. The V-HAB human model does not contain any urea in its
    %urine, but rather urine solids, which represent an average composition of
    %the solid matter diluted in urine. The urine solids are similar to the
    %composition of urea but have an additional COH2 group attached. Currently,
    %urine solids are treated to be metabolized like urea and the COH2 group is
    %left behind in the medium. This has to be respected in the stoichiometric
    %reactions. Currently, the uptake of phosphorus is not modelled in the
    %equations, since the V-HAB human model does not contain phosphorus in its
    %urine.
    properties
        oSystem;                                %ChlorellaInMediaSystem
        oMT;                                    %Matter Table
        
        afCombinedPartialFlowRates              %[kg/s] combined from different nitrogen sources
        fTotalOxygenEvolution;                  %[kg]sum of all oxygen so far evolved from algal photosyntehsis
        fTotalCarbonDioxideAssimilation;        %[kg]sum of all carbon dioxide so far assimilated by the algal culture (needed for average values)
        fCombinedCO2AvailabilityFactor          %[-] factor between 0 and 1
        fCombinedNitrogenAvailabilityFactor     %[-] factor between 0 and 1, combination of nitrate and urine
        fAssimilationCoefficient;               %[-] consumed carbon dioxide in relation to produced oxygen
        fActualGrowthRate;                      %[kg/s] growth rate that was actually reached, when possible CO2 or nitrogen supply limitation is considered.
        %Urea as nitrogen source reaction
        %CO2 + 0.075 CO(NH2)2 + 0.008 H2PO4^- + 0.721 H2O -->
        %CH_1.75O_0.42N_0.15P0.008 + 1.125 O2 + 0.075 CO2 + 0.0008 OH-
        %CO2 product included in taking less in the beginning in actual
        %calculations 0.925 CO2 + 0.075 CO(NH2)2 + 0.008 H2PO4^- +
        %0.721 H2O --> CH_1.75O_0.42N_0.15P0.008 + 1.125 O2  + 0.0008
        %OH-
        fChlorellaReactionMolesWithUrea         %[moles] in reaction to produce one (relative) mole chlorella
        fNO3ReactionMolesWithUrea               %[moles] in reaction to produce one (relative) mole chlorella
        fCO2ReactionMolesWithUrea               %[moles] in reaction to produce one (relative) mole chlorella
        fUrineSolidsReactionMolesWithUrea       %[moles] in reaction to produce one (relative) mole chlorella
        fUreaReactionMolesWithUrea              %[moles] in reaction to produce one (relative) mole chlorella
        fH2PO4ReactionMolesWithUrea             %[moles] in reaction to produce one (relative) mole chlorella
        fWaterReactionMolesWithUrea             %[moles] in reaction to produce one (relative) mole chlorella
        fO2ReactionMolesWithUrea                %[moles] in reaction to produce one (relative) mole chlorella
        fHydroxideIonReactionMolesWithUrea      %[moles] in reaction to produce one (relative) mole chlorella
        fCOH2ReactionMolesWithUrea              %[moles] in reaction to produce one (relative) mole chlorella
        fUreaAssimilationFactor                 %[-] consumed carbon dioxide in relation to produced oxygen for urea as N source
        
        %VHAB Urine Solids as nitrogen source reaction
        % 0.925 CO2 + 0.075 CO(NH2)2-COH2 + 0.008 H2PO4^- +0.721 H2O -->
        %CH_1.75O_0.42N_0.15P0.008 + 1.125 O2 + 0.0008 OH- + 0.075 COH2
        fChlorellaReactionMolesWithUrineSolids  %[moles] in reaction to produce one (relative) mole chlorella
        fNO3ReactionMolesWithUrineSolids        %[moles] in reaction to produce one (relative) mole chlorella
        fCO2ReactionMolesWithUrineSolids        %[moles] in reaction to produce one (relative) mole chlorella
        fUrineSolidsReactionMolesWithUrineSolids %[moles] in reaction to produce one (relative) mole chlorella
        fUreaReactionMolesWithUrineSolids       %[moles] in reaction to produce one (relative) mole chlorella
        fH2PO4ReactionMolesWithUrineSolids      %[moles] in reaction to produce one (relative) mole chlorella
        fWaterReactionMolesWithUrineSolids      %[moles] in reaction to produce one (relative) mole chlorella
        fO2ReactionMolesWithUrineSolids         %[moles] in reaction to produce one (relative) mole chlorella
        fHydroxideIonReactionMolesWithUrineSolids%[moles] in reaction to produce one (relative) mole chlorella
        fCOH2ReactionMolesWithUrineSolids       %[moles] in reaction to produce one (relative) mole chlorella
        fUrineSolidsAssimilationFactor          %[-] consumed carbon dioxide in relation to produced oxygen for V-HAB Urine Solids as N source
        
        
        %Nitrate as nitrogen source reaction
        % (each nitrate transformation to NH3 needs 9 h+ which it takes
        %from water, leaving oh-) CO2 + 0.15 NO3- + 0.008 H2PO4^- + 1.546 H2O -->
        %CH_1.75O_0.42N_0.15P0.008 + 1.125 O2 + 1.358 OH-
        fChlorellaReactionMolesWithNitrate      %[moles] in reaction to produce one (relative) mole chlorella
        fNO3ReactionMolesWithNitrate            %[moles] in reaction to produce one (relative) mole chlorella
        fCO2ReactionMolesWithNitrate            %[moles] in reaction to produce one (relative) mole chlorella
        fUrineSolidsReactionMolesWithNitrate    %[moles] in reaction to produce one (relative) mole chlorella
        fUreaReactionMolesWithNitrate           %[moles] in reaction to produce one (relative) mole chlorella
        fH2PO4ReactionMolesWithNitrate          %[moles] in reaction to produce one (relative) mole chlorella
        fWaterReactionMolesWithNitrate          %[moles] in reaction to produce one (relative) mole chlorella
        fO2ReactionMolesWithNitrate             %[moles] in reaction to produce one (relative) mole chlorella
        fHydroxideIonReactionMolesWithNitrate   %[moles] in reaction to produce one (relative) mole chlorella
        fCOH2ReactionMolesWithNitrate           %[moles] in reaction to produce one (relative) mole chlorella
        fNO3AssimilationFactor                  %[-] consumed carbon dioxide in relation to produced oxygen for nitrate as N source
        
        
        fMolarMassChlorella;
    end
    methods
        
        function this = PhotosynthesisModule(oSystem, oMT)
            this.oSystem = oSystem;
            this.oMT = oMT;
            
            this.fTotalOxygenEvolution = 0;                     %[kg]sum of all oxygen so far evolved from algal photosyntehsis
            this.fTotalCarbonDioxideAssimilation = 0;           %[kg]sum of all carbon dioxide so far assimilated by the algal culture (needed for average values)
            this.fCombinedCO2AvailabilityFactor = 0;            %[-] factor between 0 and 1
            this.fCombinedNitrogenAvailabilityFactor = 0;       %[-] factor between 0 and 1, combination of nitrate and urine
            this.fAssimilationCoefficient = 0;                  %[-] consumed carbon dioxide in relation to produced oxygen
            
            % Since the thesis worked with a specific molar mass for
            % chlorella, which however is not the one the algae has if it
            % is defined as compound mass with the corresponding base food
            % compound (proteins etc.) we define the assumed molar mass
            % here
            this.fMolarMassChlorella = this.oMT.afMolarMass(this.oMT.tiN2I.C) + 1.75 * this.oMT.afMolarMass(this.oMT.tiN2I.H) + 0.42*this.oMT.afMolarMass(this.oMT.tiN2I.O) + 0.15*this.oMT.afMolarMass(this.oMT.tiN2I.N);
            %% stoichiometric relations
            % chemical reaction, set rations of moles in relation to mole of chlorella
            
            %negative means they are being reduced, positive means they are being
            %produced when growth rate is positive
            
            %Urea as N Source
            
            this.fChlorellaReactionMolesWithUrea   	= 1;
            this.fNO3ReactionMolesWithUrea          = 0;
            this.fCO2ReactionMolesWithUrea          = 0.925;
            this.fUrineSolidsReactionMolesWithUrea  = 0;
            this.fUreaReactionMolesWithUrea         = 0.075;
            this.fH2PO4ReactionMolesWithUrea        = 0;        % 0.008;
            this.fWaterReactionMolesWithUrea        = 0.725;    % 0.721;
            this.fO2ReactionMolesWithUrea           = 1.115;    % 1.125;
            this.fHydroxideIonReactionMolesWithUrea = 0;        % 0.008;
            this.fCOH2ReactionMolesWithUrea         = 0;
            
            this.fUreaAssimilationFactor = this.fCO2ReactionMolesWithUrea/this.fO2ReactionMolesWithUrea;
            
            %with vhab "urine solids"
            
            this.fChlorellaReactionMolesWithUrineSolids = 1;
            this.fNO3ReactionMolesWithUrineSolids = 0;
            this.fCO2ReactionMolesWithUrineSolids = 0.925;
            this.fUrineSolidsReactionMolesWithUrineSolids = 0.075;
            this.fUreaReactionMolesWithUrineSolids = 0;
            this.fH2PO4ReactionMolesWithUrineSolids = 0;
            this.fWaterReactionMolesWithUrineSolids = 0.725;
            this.fO2ReactionMolesWithUrineSolids = 1.115;
            this.fHydroxideIonReactionMolesWithUrineSolids = 0;
            this.fCOH2ReactionMolesWithUrineSolids = 0.075;
            
            this.fUrineSolidsAssimilationFactor = this.fCO2ReactionMolesWithUrineSolids/this.fO2ReactionMolesWithUrineSolids;
            
            %with Nitrate
            this.fChlorellaReactionMolesWithNitrate = 1;
            this.fNO3ReactionMolesWithNitrate = 0.15;
            this.fCO2ReactionMolesWithNitrate = 1;
            this.fUrineSolidsReactionMolesWithNitrate = 0;
            this.fUreaReactionMolesWithNitrate = 0;
            this.fH2PO4ReactionMolesWithNitrate = 0;
            this.fWaterReactionMolesWithNitrate = 0.95;
            this.fO2ReactionMolesWithNitrate = 1.415;
            this.fHydroxideIonReactionMolesWithNitrate = 0.15;
            this.fCOH2ReactionMolesWithNitrate = 0;
            
            this.fNO3AssimilationFactor = this.fCO2ReactionMolesWithNitrate/this.fO2ReactionMolesWithNitrate;
        end
        
        
        function [afCombinedPartialFlowRates] = update(this,oCallingManip)
            %get how much chlorella has to grow in this timestep in KG and moles. If
            %not enough nutrients (CO2, No3, H2PO4) are available, calculate how much
            %is available and use up the limited resource until it is zero. if one of
            %the nutrients is not available at all, set growth to 0. also calculate
            %factors that say how many nutrients are available in relation to what is
            %required to support optimum growth as required by the growth rate
            %calculation object. CO2 and NO3 factors say that a resource is limited if
            %they are below one. Nutrient availability factor says how much Chlorella
            %Growth was achieved compared to what could be achieved in an optimal case.
            %If this is smaller than 1, then one of the other two (CO2 or NO3
            %availability) will also be smaller than one.
            
            %% how much chlorella has to be produced?
            fChlorellaMassIncrease = oCallingManip.oPhase.oStore.oContainer.oGrowthRateCalculationModule.fAchievableCurrentBiomassGrowthRate; %[kg/s]
            fMolesChlorella = fChlorellaMassIncrease / this.fMolarMassChlorella; %moles/s
            
            %% production in two separate functions according to fractions of total required production, Urea currently not modelled due to unavailability in V-HAB
            
            [afPartialsFromUrineSolidsNitrogen,fUrineSolidsAvailability,fUrineSolidsCO2Availability] = this.UrineSolidsNitrogen(fMolesChlorella,oCallingManip); %[kg/s]
            
            [afPartialFlowRatesFromUreaNitrogen,fUreaAvailabilityFactor,fCO2AvailabilityFactor] = this.UreaNitrogen(fMolesChlorella,oCallingManip);
            
            fMolesChlorellaFromUrineSolids =(afPartialsFromUrineSolidsNitrogen(this.oMT.tiN2I.Chlorella) / this.fMolarMassChlorella); %[moles/s]
            fMolesChlorellaFromUrea =(afPartialFlowRatesFromUreaNitrogen(this.oMT.tiN2I.Chlorella) / this.fMolarMassChlorella); %[moles/s]
            
            %only when not enough urine is not available, use nitrate.
            %Initially set to 0 and overwritten if changed.
            fMolesChlorellaFromNitrate = 0; %[moles/s]
            fNO3Availability=0;
            fNO3CO2Availability = 0;
            afPartialsFromNO3Nitrogen = zeros(1, this.oMT.iSubstances);
            
            fTotalChlorellaMassIncreaseFromUrine = afPartialsFromUrineSolidsNitrogen(this.oMT.tiN2I.Chlorella) + afPartialFlowRatesFromUreaNitrogen(this.oMT.tiN2I.Chlorella);
            if fTotalChlorellaMassIncreaseFromUrine < fChlorellaMassIncrease
                %how much still has to be produced?
                fMolesChlorellaNeededAdditionally = fMolesChlorella - (fTotalChlorellaMassIncreaseFromUrine / this.fMolarMassChlorella); %[moles/s]
                [afPartialsFromNO3Nitrogen,fNO3Availability, fNO3CO2Availability] = this.NO3Nitrogen(fMolesChlorellaNeededAdditionally,oCallingManip);
                fMolesChlorellaFromNitrate = (afPartialsFromNO3Nitrogen(this.oMT.tiN2I.Chlorella) / this.fMolarMassChlorella); %[moles/s]
            end
            
            %             if isnan(fMolesChlorellaFromNitrate)
            %                 fMolesChlorellaFromNitrate = 0;
            %             end
            
            %% determine actual growth rate and fractions
            fProducedMolesChlorella = fMolesChlorellaFromUrineSolids + fMolesChlorellaFromNitrate + fMolesChlorellaFromUrea; %[moles/s]
            
            if fProducedMolesChlorella > 0
                fUrineSolidsFraction = fMolesChlorellaFromUrineSolids /  fProducedMolesChlorella;
                fNO3Fraction = fMolesChlorellaFromNitrate /  fProducedMolesChlorella;
                fUreaFraction = fMolesChlorellaFromUrea /  fProducedMolesChlorella;
            else
                fUrineSolidsFraction = 0;
                fNO3Fraction = 0;
                fUreaFraction = fMolesChlorellaFromUrineSolids /  fProducedMolesChlorella;
            end
            
            if isnan(fNO3Fraction)
                fNO3Fraction = 0;
            end
            if isnan(fUrineSolidsFraction)
                fUrineSolidsFraction = 0;
            end
            if isnan(fUreaFraction)
                fUreaFraction = 0;
            end
            
            this.fActualGrowthRate = afPartialsFromUrineSolidsNitrogen(this.oMT.tiN2I.Chlorella) + afPartialFlowRatesFromUreaNitrogen(this.oMT.tiN2I.Chlorella) + afPartialsFromNO3Nitrogen(this.oMT.tiN2I.Chlorella); %[kg/s]
            
            %% combine afPartalFlowRates and calculate plotting parameters
            %afCombinedPartialFlowRates = afPartialsFromUreaNitrogen + afPartialsFromUrineSolidsNitrogen + afPartialsFromNO3Nitrogen;
            % this.afCombinedPartialFlowRates = zeros(1, this.oMT.iSubstances); %[kg/s]
            this.afCombinedPartialFlowRates =  afPartialsFromUrineSolidsNitrogen + afPartialFlowRatesFromUreaNitrogen + afPartialsFromNO3Nitrogen; %[kg/s]
            afCombinedPartialFlowRates = this.afCombinedPartialFlowRates; %[kg/s]
            
            %afCombinedPartialFlowRates = afPartialsFromUrineSolidsNitrogen + afPartialsFromNO3Nitrogen;
            %fCombinedH2PO4AvailabilityFactor = fUrineSolidsH2PO4Availability*fUrineSolidsFraction + fNO3H2PO4Availability*fNO3Fraction ;
            this.fCombinedCO2AvailabilityFactor =  fUrineSolidsCO2Availability*fUrineSolidsFraction + fNO3CO2Availability*fNO3Fraction + fCO2AvailabilityFactor*fUreaFraction; %[-] between 0 and 1
            this.fCombinedNitrogenAvailabilityFactor = fUrineSolidsAvailability*fUrineSolidsFraction + fNO3Availability*fNO3Fraction + fUreaAvailabilityFactor*fUreaFraction; %[-] between 0 and 1
            
            this.fAssimilationCoefficient = fUrineSolidsFraction*this.fUrineSolidsAssimilationFactor + fUreaFraction*this.fUreaAssimilationFactor + fNO3Fraction*this.fNO3AssimilationFactor; %%[-]
            
            %total produced oxygen and consumed carbon dioxide over entire
            %sim time.
            if oCallingManip.fLastExecTimeStep > 0
                this.fTotalOxygenEvolution = this.fTotalOxygenEvolution + this.afCombinedPartialFlowRates(this.oMT.tiN2I.O2)*oCallingManip.fLastExecTimeStep; %[kg]
                this.fTotalCarbonDioxideAssimilation =this.fTotalCarbonDioxideAssimilation - this.afCombinedPartialFlowRates(this.oMT.tiN2I.CO2)*oCallingManip.fLastExecTimeStep; %[kg]
            end
        end
        
        function [afPartialFlowRatesFromUrineSolidsNitrogen,fUrineSolidsAvailabilityFactor,fCO2AvailabilityFactor] = UrineSolidsNitrogen(this,fChlorellaMolesFromUrineSolidsNitrogen,oCallingManip)
            fMolesChlorella = fChlorellaMolesFromUrineSolidsNitrogen;
            
            % check if time step is larger than 0 (exclude first time
            % step) in order to ensure one is not dividing by zero.
            % Furthermore, don't calculate everything if Chlorella Change
            % is 0 anyway.  && operator only works with
            % scalars, and the fTimeStep of the manipulator's phase is not
            % a number in the first calculation step. Have to use &.
            if ~isempty(oCallingManip.fTimeStep) && oCallingManip.fTimeStep > 0 && fMolesChlorella > 0
                %% Consumed substances in this time step
                %products
                fChlorellaChange    = this.fChlorellaReactionMolesWithUrineSolids       * fMolesChlorella  * this.fMolarMassChlorella;     %[kg/s]
                fO2Change           = this.fO2ReactionMolesWithUrineSolids              * fMolesChlorella  * this.oMT.afMolarMass(this.oMT.tiN2I.O2); %[kg/s]
                fHydroxideIonChange = this.fHydroxideIonReactionMolesWithUrineSolids    * fMolesChlorella  * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)); %[kg/s]
                fCOH2Change         = this.fCOH2ReactionMolesWithUrineSolids            * fMolesChlorella  * this.oMT.afMolarMass(this.oMT.tiN2I.COH2); %[kg/s]
                
                %reactants
                fCO2Change          = - this.fCO2ReactionMolesWithUrineSolids           * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.CO2); %[kg/s]
                fH2OChange          = - this.fWaterReactionMolesWithUrineSolids         * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.H2O); %[kg/s]
                fNO3Change          = - this.fNO3ReactionMolesWithUrineSolids           * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);    %[kg/s]
                fUreaChange         = - this.fUreaReactionMolesWithUrineSolids          * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea));    %[kg/s]
                fH2PO4Change        = - this.fH2PO4ReactionMolesWithUrineSolids         * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate));    %[kg/s]
                fUrineSolidsChange  = - this.fUrineSolidsReactionMolesWithUrineSolids   * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2);   %[kg/s]
                
                % check if something would result in negative mass.
                % problem can be that not enought CO2 is in the media phase to allow for the algae to grow how much they need to in the time step and the growth rate is automatically set to 0 if not enough nutrients are available. should change this to also be able to growth with less than wat is required. problem here is, that the growth rate will be slower due to less nutrients being currently available although in reality the required CO2 could just be drawn from the atmosphere due to the decreased concentration when it is used up.
                if oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O) + fH2OChange*oCallingManip.fTimeStep < 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) + fCO2Change*oCallingManip.fTimeStep < 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.C2H6O2N2) + fUrineSolidsChange*oCallingManip.fTimeStep < 0
                    
                    %one resource totally depleted, then set all to 0
                    if oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O) <= 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) <= 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.C2H6O2N2) <= 0
                        
                        %set everything to 0 since there aren't enough
                        %substances to be consumed for the reaction to take
                        %place
                        afPartialFlowRates = zeros(1, this.oMT.iSubstances); %[kg/s]
                        %Consumed Substances
                        afPartialFlowRates(this.oMT.tiN2I.H2O) = 0 ; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.CO2) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.NO3) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) = 0 ;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.C2H6O2N2) = 0 ;%[kg/s]
                        
                        %Produced Substances
                        afPartialFlowRates(this.oMT.tiN2I.Chlorella)= 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.O2) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.OH) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.COH2) = 0 ;%[kg/s]
                        
                        %set availability factor of substance that is
                        %limiting. assumption for this factor is that only one
                        %substance is limiting at a time. (even if untrue (close to unlikely),
                        %this will only affect the visual output, not
                        %produced and consumed masses)
                        if oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) <= 0
                            fCO2AvailabilityFactor = 0; %[-]
                            fUrineSolidsAvailabilityFactor = 1; %[-]
                        elseif oCallingManip.oPhase.afMass(this.oMT.tiN2I.C2H6O2N2) <= 0
                            fCO2AvailabilityFactor = 1; %[-]
                            fUrineSolidsAvailabilityFactor = 0; %[-]
                        end
                        
                        
                    else
                        %if only a part of what is required for the reaction is
                        %available, then use this part.
                        %determine available moles of nutrients
                        fAvailableH2O = oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O) / this.oMT.afMolarMass(this.oMT.tiN2I.H2O); %[mol]
                        fAvailableCO2 = oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) / this.oMT.afMolarMass(this.oMT.tiN2I.CO2); %[mol]
                        fAvailableC2H6O2N2 = oCallingManip.oPhase.afMass(this.oMT.tiN2I.C2H6O2N2) / this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2);%[mol]
                        
                        %calculate limiting factor, which relates the mole availability
                        %to how much is needed for the reaction
                        mfAvailabilityFactor(1) = fAvailableH2O / this.fWaterReactionMolesWithUrineSolids; %[-]
                        mfAvailabilityFactor(2) = fAvailableCO2 / this.fCO2ReactionMolesWithUrineSolids; %[-]
                        mfAvailabilityFactor(3) = fAvailableC2H6O2N2 / this.fUrineSolidsReactionMolesWithUrineSolids; %[-]
                        
                        %fidn most limiting of availability factors
                        fLimitingFactor = min(mfAvailabilityFactor);
                        
                        % determine how much chlorella is produced and how much of the nutrients can be
                        % used
                        fMaximumPossibleChlorellaChange     = fLimitingFactor * this.fChlorellaReactionMolesWithUrineSolids * this.fMolarMassChlorella;     %[kg]
                        fMaximumPossibleO2Change            = fLimitingFactor * this.fO2ReactionMolesWithUrineSolids* this.oMT.afMolarMass(this.oMT.tiN2I.O2); %[kg]
                        fMaximumPossibleHydroxideIonChange  = fLimitingFactor * this.fHydroxideIonReactionMolesWithUrineSolids * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)); %[kg]
                        fMaximumPossibleCOH2Change          = fLimitingFactor * this.fCOH2ReactionMolesWithUrineSolids * this.oMT.afMolarMass(this.oMT.tiN2I.COH2); %[kg]
                        
                        
                        fMaximumPossibleCO2Change = fLimitingFactor * - this.fCO2ReactionMolesWithUrineSolids * this.oMT.afMolarMass(this.oMT.tiN2I.CO2); %[kg]
                        fMaximumPossibleH2OChange = fLimitingFactor * - this.fWaterReactionMolesWithUrineSolids * this.oMT.afMolarMass(this.oMT.tiN2I.H2O); %[kg]
                        fMaximumPossibleNO3Change = fLimitingFactor * - this.fNO3ReactionMolesWithUrineSolids * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);    %[kg]
                        fMaximumPossibleUreaChange = fLimitingFactor * - this.fUreaReactionMolesWithUrineSolids * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea));%[kg]
                        fMaximumPossibleUrineSolidsChange = fLimitingFactor * - this.fUrineSolidsReactionMolesWithUrineSolids * this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2); %[kg]
                        fMaximumPossibleH2PO4Change = fLimitingFactor * - this.fH2PO4ReactionMolesWithUrineSolids * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)); %[kg]
                        
                        %set flow rates
                        afPartialFlowRates = zeros(1, this.oMT.iSubstances); %?kg/s
                        %Consumed Substances, when growth positive
                        afPartialFlowRates(this.oMT.tiN2I.H2O) = fMaximumPossibleH2OChange / oCallingManip.fTimeStep; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.CO2) = fMaximumPossibleCO2Change / oCallingManip.fTimeStep;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.NO3) = fMaximumPossibleNO3Change/ oCallingManip.fTimeStep; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) = fMaximumPossibleUreaChange/ oCallingManip.fTimeStep; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = fMaximumPossibleH2PO4Change / oCallingManip.fTimeStep; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.C2H6O2N2) = fMaximumPossibleUrineSolidsChange/ oCallingManip.fTimeStep; %[kg/s]
                        
                        %Produced Substances when growth positive
                        afPartialFlowRates(this.oMT.tiN2I.Chlorella)= fMaximumPossibleChlorellaChange / oCallingManip.fTimeStep; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.O2) = fMaximumPossibleO2Change / oCallingManip.fTimeStep; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)) = fMaximumPossibleHydroxideIonChange / oCallingManip.fTimeStep ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.COH2) = fMaximumPossibleCOH2Change / oCallingManip.fTimeStep ;%[kg/s]
                        
                        
                        %determine availability factor by relating what is available to
                        %what would be required to support the current growth rate
                        fCO2AvailabilityFactor = (fAvailableCO2 * this.oMT.afMolarMass(this.oMT.tiN2I.CO2)) / (-fCO2Change*oCallingManip.fTimeStep) ; %kg/kg = [-]
                        fUrineSolidsAvailabilityFactor =(fAvailableC2H6O2N2 * this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2)) / ( -fUrineSolidsChange*oCallingManip.fTimeStep) ; %kg/kg = [-]
                        
                        
                        
                        %typically one of both will be larger than 1 because most
                        %likely the nutrients won't become limited all at once. Set
                        %the one larger than 1 to 1 for ease of reading.
                        if fCO2AvailabilityFactor > 1
                            fCO2AvailabilityFactor = 1; %[-]
                        end
                        
                        if fUrineSolidsAvailabilityFactor > 1
                            fUrineSolidsAvailabilityFactor = 1; %[-]
                        end
                    end
                else
                    %if everything is available in excess of what is needed
                    %set flow rates (kg/s) to pass back by dividing the desired
                    %mass conversion (kg) through the time step (s)
                    
                    afPartialFlowRates = zeros(1, this.oMT.iSubstances); %[kg/s]
                    %Consumed Substances, when growth positive
                    afPartialFlowRates(this.oMT.tiN2I.H2O) = fH2OChange; %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.CO2) = fCO2Change;%[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.NO3) = fNO3Change; %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) = fUreaChange; %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = fH2PO4Change; %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.C2H6O2N2) = fUrineSolidsChange; %[kg/s]
                    
                    %Produced Substances when growth positive
                    afPartialFlowRates(this.oMT.tiN2I.Chlorella)= fChlorellaChange; %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.O2) = fO2Change; %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)) = fHydroxideIonChange ;%[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.COH2) = fCOH2Change ;%[kg/s]
                    
                    
                    
                    fCO2AvailabilityFactor = 1; %[-]
                    fUrineSolidsAvailabilityFactor = 1; %[-]
                    %
                end
                
            else
                %time step or required chlorella from this function is 0,
                %no need to calculate, automatically set evreything to 0.
                afPartialFlowRates = zeros(1, this.oMT.iSubstances); %[kg/s]
                fCO2AvailabilityFactor = 0; %[-]
                fUrineSolidsAvailabilityFactor = 0; %[-]
                
            end
            
            afPartialFlowRatesFromUrineSolidsNitrogen = afPartialFlowRates;
        end
        
        function [afPartialFlowRatesFromNO3Nitrogen,fNO3AvailabilityFactor,fCO2AvailabilityFactor] = NO3Nitrogen (this,fChlorellaMolesFromNO3Nitrogen,oCallingManip)
            fMolesChlorella = fChlorellaMolesFromNO3Nitrogen;
            
            % check if time step is larger than 0 (exclude first time
            % step) in order to ensure one is not dividing by zero.
            % Furthermore, don't calculate everything if Chlorella Change
            % is 0 anyway. && operator only works with
            % scalars, and the fTimeStep of the manipulator's phase is not
            % a number in the first calculation step. Have to use &.
            if ~isempty(oCallingManip.fTimeStep) && oCallingManip.fTimeStep > 0 && fMolesChlorella > 0
                %% Consumed substances in this time step
                %products
                fChlorellaChange    = this.fChlorellaReactionMolesWithNitrate       * fMolesChlorella  * this.fMolarMassChlorella;     %[kg/s]
                fO2Change           = this.fO2ReactionMolesWithNitrate              * fMolesChlorella  * this.oMT.afMolarMass(this.oMT.tiN2I.O2); %[kg/s]s
                fHydroxideIonChange = this.fHydroxideIonReactionMolesWithNitrate    * fMolesChlorella  * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)); %[kg/s]
                fCOH2Change         = this.fCOH2ReactionMolesWithNitrate            * fMolesChlorella  * this.oMT.afMolarMass(this.oMT.tiN2I.COH2); %[kg/s]
                
                %reactants
                fCO2Change          = - this.fCO2ReactionMolesWithNitrate           * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.CO2); %[kg/s]
                fH2OChange          = - this.fWaterReactionMolesWithNitrate         * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.H2O); %[kg/s]
                fNO3Change          = - this.fNO3ReactionMolesWithNitrate           * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);   %[kg/s]
                fUreaChange         = - this.fUreaReactionMolesWithNitrate          * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea));    %[kg/s]
                fH2PO4Change        = - this.fH2PO4ReactionMolesWithNitrate         * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate));    %[kg/s]
                fUrineSolidsChange  = - this.fUrineSolidsReactionMolesWithNitrate   * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2);    %[kg/s]
                
                
                % problem can be that not enought CO2 is in the media phase to allow for the algae to grow how much they need to in the time step and the growth rate is automatically set to 0 if not enough nutrients are available. should change this to also be able to growth with less than wat is required. problem here is, that the growth rate will be slower due to less nutrients being currently available although in reality the required CO2 could just be drawn from the atmosphere due to the decreased concentration when it is used up.
                if oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O) + fH2OChange*oCallingManip.fTimeStep < 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) + fCO2Change*oCallingManip.fTimeStep < 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.NO3) + fNO3Change*oCallingManip.fTimeStep < 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) + fH2PO4Change*oCallingManip.fTimeStep < 0
                    
                    %completely depleted resource
                    if oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O) <= 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) <= 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.NO3) <= 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) <= 0
                        %set everything to 0 since there aren't enough
                        %substances to be consumed for the reaction to take
                        %place
                        afPartialFlowRates = zeros(1, this.oMT.iSubstances); %[kg/s]
                        %Consumed Substances
                        afPartialFlowRates(this.oMT.tiN2I.H2O) = 0 ; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.CO2) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.NO3) = 0 ;%%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.C2H6O2N2) = 0 ;%[kg/s]
                        
                        %Produced Substances
                        afPartialFlowRates(this.oMT.tiN2I.Chlorella)= 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.O2) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)) = 0 ;%[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.COH2) = 0 ;%[kg/s]
                        
                        if oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) <= 0
                            fCO2AvailabilityFactor = 0; %[-]
                            fNO3AvailabilityFactor = 1;%[-]
                        elseif oCallingManip.oPhase.afMass(this.oMT.tiN2I.NO3) <= 0
                            fCO2AvailabilityFactor = 1;%[-]
                            fNO3AvailabilityFactor = 0;%[-]
                        end
                        
                        
                    else
                        %if only a part of what is required for the reaction is
                        %available, then use this part.
                        %determine available moles of nutrients
                        fAvailableH2O = oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O) / this.oMT.afMolarMass(this.oMT.tiN2I.H2O); %[mol]
                        fAvailableCO2 = oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) / this.oMT.afMolarMass(this.oMT.tiN2I.CO2);%[mol]
                        fAvailableNO3 = oCallingManip.oPhase.afMass(this.oMT.tiN2I.NO3) / this.oMT.afMolarMass(this.oMT.tiN2I.NO3);%[mol]
                        
                        
                        %calculate limiting factor, which relates the mole availability
                        %to how much is needed for the reaction
                        mfAvailabilityFactor(1) = fAvailableH2O / this.fWaterReactionMolesWithNitrate; %[-]
                        mfAvailabilityFactor(2) = fAvailableCO2 / this.fCO2ReactionMolesWithNitrate;%[-]
                        mfAvailabilityFactor(3) = fAvailableNO3 / this.fNO3ReactionMolesWithNitrate;%[-]
                        
                        
                        fLimitingFactor = min(mfAvailabilityFactor);
                        
                        % determine how much chlorella is produced and how much of the nutrients can be
                        % used
                        fMaximumPossibleChlorellaChange     = fLimitingFactor * this.fChlorellaReactionMolesWithNitrate     * this.fMolarMassChlorella;    %[kg]
                        fMaximumPossibleO2Change            = fLimitingFactor * this.fO2ReactionMolesWithNitrate            * this.oMT.afMolarMass(this.oMT.tiN2I.O2);   %[kg]
                        fMaximumPossibleHydroxideIonChange  = fLimitingFactor * this.fHydroxideIonReactionMolesWithNitrate  * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon));   %[kg]
                        fMaximumPossibleCOH2Change          = fLimitingFactor * this.fCOH2ReactionMolesWithNitrate          * this.oMT.afMolarMass(this.oMT.tiN2I.COH2);   %[kg]
                        
                        
                        fMaximumPossibleCO2Change           = fLimitingFactor * - this.fCO2ReactionMolesWithNitrate         * this.oMT.afMolarMass(this.oMT.tiN2I.CO2);   %[kg]
                        fMaximumPossibleH2OChange           = fLimitingFactor * - this.fWaterReactionMolesWithNitrate       * this.oMT.afMolarMass(this.oMT.tiN2I.H2O);   %[kg]
                        fMaximumPossibleNO3Change           = fLimitingFactor * - this.fNO3ReactionMolesWithNitrate         * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);     %[kg]
                        fMaximumPossibleUreaChange          = fLimitingFactor * - this.fUreaReactionMolesWithNitrate        * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea));   %[kg]
                        fMaximumPossibleUrineSolidsChange   = fLimitingFactor * - this.fUrineSolidsReactionMolesWithNitrate * this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2);   %[kg]
                        fMaximumPossibleH2PO4Change         = fLimitingFactor * - this.fH2PO4ReactionMolesWithNitrate       * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate));   %[kg]
                        
                        %set flow rates
                        afPartialFlowRates = zeros(1, this.oMT.iSubstances);   %[kg/s]
                        %Consumed Substances, when growth positive
                        afPartialFlowRates(this.oMT.tiN2I.H2O)                                  = fMaximumPossibleH2OChange         / oCallingManip.fTimeStep;  %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.CO2)                                  = fMaximumPossibleCO2Change         / oCallingManip.fTimeStep; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.NO3)                                  = fMaximumPossibleNO3Change         / oCallingManip.fTimeStep;  %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.Urea))                = fMaximumPossibleUreaChange        / oCallingManip.fTimeStep; %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = fMaximumPossibleH2PO4Change       / oCallingManip.fTimeStep;  %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.C2H6O2N2)                             = fMaximumPossibleUrineSolidsChange / oCallingManip.fTimeStep; %[kg/s]
                        
                        %Produced Substances when growth positive
                        afPartialFlowRates(this.oMT.tiN2I.Chlorella)                     = fMaximumPossibleChlorellaChange      / oCallingManip.fTimeStep;  %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.O2)                            = fMaximumPossibleO2Change             / oCallingManip.fTimeStep;  %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)) = fMaximumPossibleHydroxideIonChange   / oCallingManip.fTimeStep;  %[kg/s]
                        afPartialFlowRates(this.oMT.tiN2I.COH2)                          = fMaximumPossibleCOH2Change           / oCallingManip.fTimeStep ; %[kg/s]
                        
                        
                        
                        
                        %determine availability factor by relating what is available to
                        %what would be required to support the current growth rate
                        fCO2AvailabilityFactor = (fAvailableCO2 * this.oMT.afMolarMass(this.oMT.tiN2I.CO2)) / (-fCO2Change*oCallingManip.fTimeStep) ; %kg/kg = [-]
                        fNO3AvailabilityFactor =(fAvailableNO3 * this.oMT.afMolarMass(this.oMT.tiN2I.NO3)) / ( -fNO3Change*oCallingManip.fTimeStep) ; %kg/kg = [-]
                        
                        %typically one of both will be larger than 1 because most
                        %likely the nutrients won't become limited all at once. Set
                        %the one larger than 1 to 1 for ease of reading.
                        if fCO2AvailabilityFactor > 1
                            fCO2AvailabilityFactor = 1;  %[-]
                        end
                        
                        if fNO3AvailabilityFactor > 1
                            fNO3AvailabilityFactor = 1;  %[-]
                        end
                    end
                else
                    %if everything is available in excess of what is needed
                    %set flow rates (kg/s) to pass back by dividing the desired
                    %mass conversion (kg) through the time step (s)
                    
                    afPartialFlowRates = zeros(1, this.oMT.iSubstances);  %[kg/s]
                    %Consumed Substances, when growth positive
                    afPartialFlowRates(this.oMT.tiN2I.H2O) = fH2OChange;  %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.CO2) = fCO2Change; %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.NO3) = fNO3Change;  %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) = fUreaChange;  %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = fH2PO4Change;  %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.C2H6O2N2) = fUrineSolidsChange; %[kg/s]
                    
                    %Produced Substances when growth positive
                    afPartialFlowRates(this.oMT.tiN2I.Chlorella)= fChlorellaChange;  %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.O2) = fO2Change;  %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)) = fHydroxideIonChange ; %[kg/s]
                    afPartialFlowRates(this.oMT.tiN2I.COH2) = fCOH2Change ; %[kg/s]
                    
                    
                    
                    fCO2AvailabilityFactor = 1;  %[-]
                    fNO3AvailabilityFactor = 1;  %[-]
                end
            else
                %if time step or required chlorella mass from this function
                %smaller than 0, then set all to 0. no need to calculate.
                afPartialFlowRates = zeros(1, this.oMT.iSubstances);  %[kg/s]
                fCO2AvailabilityFactor = 0;   %[-]
                fNO3AvailabilityFactor = 0;  %[-]
                
            end
            %pass back to calling function.
            afPartialFlowRatesFromNO3Nitrogen = afPartialFlowRates;  %[kg/s]
        end
        
        
        %% (this.oMT.tsN2S.Urea) function is not needed here, but can still be used at a later time.
        function [afPartialFlowRatesFromUreaNitrogen,fUreaAvailabilityFactor,fCO2AvailabilityFactor] = UreaNitrogen(this, fChlorellaMolesFromUreaNitrogen,oCallingManip)
            % 0.925 CO2 + 0.075 CH4N2O + 0.725 H2O -> Ch1.75O0.42N0.15 +  1.115 O2
            
            fMolesChlorella = fChlorellaMolesFromUreaNitrogen;

            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            
            % check if time step is larger than 0 (exclude first time
            % step) in order to ensure one is not dividing by zero
            if ~isempty(oCallingManip.fTimeStep) && oCallingManip.fTimeStep > 0 && fMolesChlorella > 0
                %% Consumed substances in this time step
                %products
                fChlorellaChange    = this.fChlorellaReactionMolesWithUrea      * fMolesChlorella * this.fMolarMassChlorella;     %kg/s
                fO2Change           = this.fO2ReactionMolesWithUrea             * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.O2); %kg/s
                fHydroxideIonChange = this.fHydroxideIonReactionMolesWithUrea   * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)); %kg/s
                fCOH2Change         = this.fCOH2ReactionMolesWithUrea           * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.COH2); %kg/s

                %reactants
                fCO2Change          = - this.fCO2ReactionMolesWithUrea          * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.CO2); %kg/s
                fH2OChange          = - this.fWaterReactionMolesWithUrea        * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.H2O); %kg/s
                fNO3Change          = - this.fNO3ReactionMolesWithUrea          * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);    %kg/s
                fUreaChange         = - this.fUreaReactionMolesWithUrea         * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea));    %kg/s
                fH2PO4Change        = - this.fH2PO4ReactionMolesWithUrea        * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate));    %kg/s
                fUrineSolidsChange  = - this.fUrineSolidsReactionMolesWithUrea  * fMolesChlorella * this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2);    %kg/s

                %% set flow rates to pass back

                % check if something would result in negative mass.
                % problem can be that not enought CO2 is in the media phase to allow for the algae to grow how much they need to in the time step and the growth rate is automatically set to 0 if not enough nutrients are available. should change this to also be able to growth with less than wat is required. problem here is, that the growth rate will be slower due to less nutrients being currently available although in reality the required CO2 could just be drawn from the atmosphere due to the decreased concentration when it is used up.
                if oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O) + fH2OChange*oCallingManip.fTimeStep < 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) + fCO2Change*oCallingManip.fTimeStep < 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) + fUreaChange*oCallingManip.fTimeStep < 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) + fH2PO4Change*oCallingManip.fTimeStep < 0

                    %this will not work with variable reaction equations, differ by
                    %case
                    if oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O) <= 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) <= 0 || oCallingManip.oPhase.afMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) <= 0 % || oCallingManip.oPhase.afMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) <= 0
                        %set everything to 0 since there aren't enough
                        %substances to be consumed for the reaction to take
                        %place

                        %Consumed Substances
                        afPartialFlowRates(this.oMT.tiN2I.H2O) = 0 ; %kg/s
                        afPartialFlowRates(this.oMT.tiN2I.CO2) = 0 ;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.NO3) = 0 ;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) = 0 ;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = 0 ;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.C2H6O2N2) = 0 ;%kg/s

                        %Produced Substances
                        afPartialFlowRates(this.oMT.tiN2I.Chlorella)= 0 ;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.O2) = 0 ;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)) = 0 ;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.COH2) = 0 ;%kg/s

                        fCO2AvailabilityFactor = 0;
                        fUreaAvailabilityFactor = 0;
%                         fH2PO4AvailabilityFactor = 0;


                    else
                        %if only a part of what is required for the reaction is
                        %available, then use this part.
                        %determine available moles of nutrients
                        fAvailableH2O           = oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O) / this.oMT.afMolarMass(this.oMT.tiN2I.H2O); %mol
                        fAvailableCO2           = oCallingManip.oPhase.afMass(this.oMT.tiN2I.CO2) / this.oMT.afMolarMass(this.oMT.tiN2I.CO2); %mol
                        %fAvailableNO3          = oCallingManip.oPhase.afMass(this.oMT.tiN2I.NO3) / this.oMT.afMolarMass(this.oMT.tiN2I.NO3);%mol
                        fAvailableUrea          = oCallingManip.oPhase.afMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) / this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea));%mol
                        %fAvailableC2H6O2N2     = oCallingManip.oPhase.afMass(this.oMT.tiN2I.C2H6O2N2) / this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2);%mol
                        fAvailableH2PO4         = oCallingManip.oPhase.afMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) / this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate));%mol

                        %calculate limiting factor, which relates the mole availability
                        %to how much is needed for the reaction
                        mfAvailabilityFactor(1) = fAvailableH2O     / this.fWaterReactionMolesWithUrea;
                        mfAvailabilityFactor(2) = fAvailableCO2     / this.fCO2ReactionMolesWithUrea;
                        mfAvailabilityFactor(3) = fAvailableH2PO4   / this.fH2PO4ReactionMolesWithUrea;

                        mfAvailabilityFactor(4) = fAvailableUrea    / this.fUreaReactionMolesWithUrea;


                        fLimitingFactor = min(mfAvailabilityFactor);
                        if fLimitingFactor > 1
                            fLimitingFactor = 1;
                        end

                        % determine how much chlorella is produced and how much of the nutrients can be
                        % used
                        fMaximumPossibleChlorellaChange     = fLimitingFactor * this.fChlorellaReactionMolesWithUrea        * this.fMolarMassChlorella;     %kg
                        fMaximumPossibleO2Change            = fLimitingFactor * this.fO2ReactionMolesWithUrea               * this.oMT.afMolarMass(this.oMT.tiN2I.O2); %kg
                        fMaximumPossibleHydroxideIonChange  = fLimitingFactor * this.fHydroxideIonReactionMolesWithUrea     * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)); %kg
                        fMaximumPossibleCOH2Change          = fLimitingFactor * this.fCOH2ReactionMolesWithUrea             * this.oMT.afMolarMass(this.oMT.tiN2I.COH2); %kg

                        fMaximumPossibleCO2Change           = fLimitingFactor * - this.fCO2ReactionMolesWithUrea            * this.oMT.afMolarMass(this.oMT.tiN2I.CO2); %kg
                        fMaximumPossibleH2OChange           = fLimitingFactor * - this.fWaterReactionMolesWithUrea          * this.oMT.afMolarMass(this.oMT.tiN2I.H2O); %kg
                        fMaximumPossibleNO3Change           = fLimitingFactor * - this.fNO3ReactionMolesWithUrea            * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);    %kg
                        fMaximumPossibleUreaChange          = fLimitingFactor * - this.fUreaReactionMolesWithUrea           * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)); %kg
                        fMaximumPossibleUrineSolidsChange   = fLimitingFactor * - this.fUrineSolidsReactionMolesWithUrea    * this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2); %kg
                        fMaximumPossibleH2PO4Change         = fLimitingFactor * - this.fH2PO4ReactionMolesWithUrea          * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)); %kg

                        %set flow rates
                        %Consumed Substances, when growth positive
                        afPartialFlowRates(this.oMT.tiN2I.H2O) = fMaximumPossibleH2OChange / oCallingManip.fTimeStep; %kg/s
                        afPartialFlowRates(this.oMT.tiN2I.CO2) = fMaximumPossibleCO2Change / oCallingManip.fTimeStep;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.NO3) = fMaximumPossibleNO3Change/ oCallingManip.fTimeStep; %kg/s
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) = fMaximumPossibleUreaChange/ oCallingManip.fTimeStep; %kg/s
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = fMaximumPossibleH2PO4Change / oCallingManip.fTimeStep; %kg/s
                        afPartialFlowRates(this.oMT.tiN2I.C2H6O2N2) = fMaximumPossibleUrineSolidsChange/ oCallingManip.fTimeStep; %kg/s

                        %Produced Substances when growth positive
                        afPartialFlowRates(this.oMT.tiN2I.Chlorella)= fMaximumPossibleChlorellaChange / oCallingManip.fTimeStep; %kg/s
                        afPartialFlowRates(this.oMT.tiN2I.O2) = fMaximumPossibleO2Change / oCallingManip.fTimeStep; %kg/s
                        afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)) = fMaximumPossibleHydroxideIonChange / oCallingManip.fTimeStep ;%kg/s
                        afPartialFlowRates(this.oMT.tiN2I.COH2) = fMaximumPossibleCOH2Change / oCallingManip.fTimeStep ;%kg/s
                        
                        %determine availability factor by relating what is available to
                        %what would be required to support the current growth rate
                        fCO2AvailabilityFactor = (fAvailableCO2 * this.oMT.afMolarMass(this.oMT.tiN2I.CO2)) / (-fCO2Change*oCallingManip.fTimeStep) ; %kg/kg = [-]
                        fUreaAvailabilityFactor =(fAvailableUrea * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea))) / ( -fUreaChange*oCallingManip.fTimeStep) ; %kg/kg = [-]
%                         fH2PO4AvailabilityFactor = (fAvailableH2PO4 * this.oMT.afMolarMass(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate))) / ( -fH2PO4Change*oCallingManip.fTimeStep);
                        %typically one of both will be larger than 1 because most
                        %likely the nutrients won't become limited all at once. Set
                        %the one larger than 1 to 1 for ease of reading.
                        if fCO2AvailabilityFactor > 1
                            fCO2AvailabilityFactor = 1;
                        end

                        if fUreaAvailabilityFactor > 1
                            fUreaAvailabilityFactor = 1;
                        end

%                         if fH2PO4AvailabilityFactor > 1
%                             fH2PO4AvailabilityFactor = 1;
%                         end
                    end
                else
                    %if everything is available in excess of what is needed
                    %set flow rates (kg/s) to pass back by dividing the desired
                    %mass conversion (kg) through the time step (s)

                    %Consumed Substances, when growth positive
                    afPartialFlowRates(this.oMT.tiN2I.H2O) = fH2OChange; %kg/s
                    afPartialFlowRates(this.oMT.tiN2I.CO2) = fCO2Change;%kg/s
                    afPartialFlowRates(this.oMT.tiN2I.NO3) = fNO3Change; %kg/s
                    afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.Urea)) = fUreaChange; %kg/s
                    afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = fH2PO4Change; %kg/s
                    afPartialFlowRates(this.oMT.tiN2I.C2H6O2N2) = fUrineSolidsChange; %kg/s

                    %Produced Substances when growth positive
                    afPartialFlowRates(this.oMT.tiN2I.Chlorella)= fChlorellaChange; %kg/s
                    afPartialFlowRates(this.oMT.tiN2I.O2) = fO2Change; %kg/s
                    afPartialFlowRates(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon)) = fHydroxideIonChange ;%kg/s
                    afPartialFlowRates(this.oMT.tiN2I.COH2) = fCOH2Change ;%kg/s



                    fCO2AvailabilityFactor = 1;
                    fUreaAvailabilityFactor = 1;
%                     fH2PO4AvailabilityFactor = 1;
                end
            else
                %if timestep = 0;
                fCO2AvailabilityFactor = 0;
                fUreaAvailabilityFactor = 0;
%                 fH2PO4AvailabilityFactor = 0;
            end
            
            fError = sum(afPartialFlowRates);
            if fError < 1e-6
                fPositiveFlowRate = sum(afPartialFlowRates(afPartialFlowRates > 0));
                fNegativeFlowRate = abs(sum(afPartialFlowRates(afPartialFlowRates < 0)));
                
                if fPositiveFlowRate > fNegativeFlowRate
                    % reduce the positive flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = afPartialFlowRates(afPartialFlowRates > 0)./fPositiveFlowRate;
                    
                    afPartialFlowRates(afPartialFlowRates > 0) = afPartialFlowRates(afPartialFlowRates > 0) - fDifference .* arRatios;
                else
                    % reduce the negative flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = abs(afPartialFlowRates(afPartialFlowRates < 0)./fNegativeFlowRate);
                    
                    afPartialFlowRates(afPartialFlowRates < 0) = afPartialFlowRates(afPartialFlowRates < 0) - fDifference .* arRatios;
                end
            else
                keyboard()
            end
            afPartialFlowRatesFromUreaNitrogen = afPartialFlowRates;
        end
    end
end
