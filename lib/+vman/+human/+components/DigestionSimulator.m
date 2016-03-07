classdef DigestionSimulator < matter.manips.substance.flow
    
    %A phase manipulator to simulate conversion of food to feces
                                    
    
    properties (SetAccess = protected, GetAccess = public)
        fLastUpdate;
       
        afInitialMassSolidFood;
        
        % According to BVAD page 84 table 4.38 each crew member produces
        % 123 g of feces per day that consist of 32g solids and 91 g water        
        fFecesWaterPercent = 0.7398; 
        
        fWaterFlowToFeces = 0;
        
        % According to BVAD table 3.26 on page 50 for a consumption of dry
        % solid food mass of 0.81 kg the human body produces 0.4 kg of
        % metabolic water, 0.032 kg of solid feces, 0.059 kg of solid urine
        % and 0.224 kg of C for O2 to CO2 (difference between O2
        % consumption and CO2 production). Additionally 0.018 kg of solids
        % for perspiration/respiration which will be considered included in
        % other solid outputs (such as hair, nail growth) in this model.
        % Other solid outputs have to close the mass balance thus 0.095 kg
        % of other solids are produced. These values are transformed into %
        % values now:
        fPercentFeces           = 0.0395;
        fPercentUrineSolid      = 0.7284;
        fPercentMetabolicH2O    = 0.494;
        fPercentOtherWaste      = 0.11716;
        % the value missing for 100% is the C used for CO2 production, but
        % that C is calculated based on the oxgen intake!
        
        cEatenFood;
        
        bUpdateFlowRates = true;
        
        fFecesFlowRate          = 0;
        fSolidUrineFlowRate     = 0;
        fMetabolicWaterFlowRate = 0;
        fOtherWasteFlowRate     = 0;
        fTotalFlowRate          = 0;
    end
    
    methods
        function this = DigestionSimulator(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            this.fLastUpdate = 0;
            
            this.afInitialMassSolidFood = this.oPhase.afMass;
            
            this.afPartialFlows= zeros(1, this.oPhase.oMT.iSubstances);
        end
        
        function eat(this,~)
            % Function used to update the food the human ate
            tEat.fTime                   = this.oTimer.fTime;
            
            afMassCurrent                = this.oPhase.afMass - this.afInitialMassSolidFood;
            % now the mass eaten previously to this eat event is calculated
            fMassPreviouslyEaten = 0;
            for iK = 1:length(this.cEatenFood)
                fMassPreviouslyEaten = fMassPreviouslyEaten + this.cEatenFood{iK}.fDrymass;
            end
            
            tEat.fDrymass                = afMassCurrent(this.oMT.tiN2I.C) - fMassPreviouslyEaten;
            
            % And the flow rates required for this eat event to process the
            % food are calculated. Note that no precise time for the
            % digestion is implemented yet and it is instead assumed that
            % all food take one day to digest.
            tEat.fFecesFlowRate          =   (this.fPercentFeces          * tEat.fDrymass)/(24*3600);
            tEat.fSolidUrineFlowRate     =   (this.fPercentUrineSolid     * tEat.fDrymass)/(24*3600);
            tEat.fMetabolicWaterFlowRate =   (this.fPercentMetabolicH2O   * tEat.fDrymass)/(24*3600);
            tEat.fOtherWasteFlowRate     =   (this.fPercentOtherWaste     * tEat.fDrymass)/(24*3600);
            
            % Finally this eat event is saved as the last in the cEatenFood
            % property. Therefore the oldest eat event is always the first
            % one in the property
            this.cEatenFood{end+1} = tEat;
            
            % tells the manip to recalculate its flowrates during its next
            % update function
            this.bUpdateFlowRates = true;
        end
        
        function update(this)
            
            fTimeStep = this.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            if fTimeStep <= 0.1
                return
            end
            
            afPartialFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            
            % Currently no detailed time for the duration of digestion.
            % The basic assumption here is that the food the human consumed
            % is digested within one day. Therefore if the oldest eat event
            % was more than 24 hours ago the food consumed during this
            % event has been processed and the event is deleted
            if ~isempty(this.cEatenFood) && ((this.oTimer.fTime - this.cEatenFood{1}.fTime) > 24*3600)
                this.cEatenFood = this.cEatenFood(2:end);
                this.bUpdateFlowRates = true;
            end
            
            if this.bUpdateFlowRates
                % the overall flow rates of the manip are the sum over all the
                % digestion flow rates of the previously eaten food
                this.fFecesFlowRate          = 0;
                this.fSolidUrineFlowRate     = 0;
                this.fMetabolicWaterFlowRate = 0;
                this.fOtherWasteFlowRate     = 0;
                for iK = 1:length(this.cEatenFood)
                    this.fFecesFlowRate          = this.fFecesFlowRate            + this.cEatenFood{iK}.fFecesFlowRate;
                    this.fSolidUrineFlowRate     = this.fSolidUrineFlowRate       + this.cEatenFood{iK}.fSolidUrineFlowRate;
                    this.fMetabolicWaterFlowRate = this.fMetabolicWaterFlowRate   + this.cEatenFood{iK}.fMetabolicWaterFlowRate;
                    this.fOtherWasteFlowRate     = this.fOtherWasteFlowRate       + this.cEatenFood{iK}.fOtherWasteFlowRate;
                end

                %calculates the necessary water flow rate to produces feces
                %with the specified percentage of water
                this.fWaterFlowToFeces  =   this.fFecesWaterPercent * (this.fFecesFlowRate/(1 - this.fFecesWaterPercent));

                % calculates the total flow rate of processed matter to have a
                % value of how much solid food mass has to be removed from the
                % phase
                this.fTotalFlowRate          = this.fFecesFlowRate + this.fSolidUrineFlowRate +  this.fMetabolicWaterFlowRate + this.fOtherWasteFlowRate;
            end
            
            % Now the flow rates have to be set for the manip. Since the
            % water remains water the manip does not change it, instead the
            % flow rate calculated for the water here is then used by the
            % p2p to move the according amount of water to the feces phase.
            afPartialFlowRates(this.oMT.tiN2I.Feces)        =  this.fFecesFlowRate;
            afPartialFlowRates(this.oMT.tiN2I.UrineSolids)  =  this.fSolidUrineFlowRate;
            afPartialFlowRates(this.oMT.tiN2I.H2O)          =  this.fMetabolicWaterFlowRate;
            afPartialFlowRates(this.oMT.tiN2I.Waste)        =  this.fOtherWasteFlowRate;
            
            afPartialFlowRates(this.oMT.tiN2I.C)            = -this.fTotalFlowRate;
            
            update@matter.manips.substance.flow(this, afPartialFlowRates);
            
            this.fLastUpdate = this.oPhase.oStore.oTimer.fTime;
        end
        
        
    end
end