classdef Food_to_Feces_Converter < matter.manips.substance.flow
    
    %A phase manipulator to simulate conversion of food to feces
                                    
    
    properties (SetAccess = protected, GetAccess = public)
        fLastUpdate;
       
       
        % According to BVAD page 84 table 4.38 each crew member produces
        % 123 g of feces per day that consist of 32g solids and 91 g water
        fDailyFecesProductionPerCM = 0.123;
        
        fFecesWaterPercent = 0.7398; 
        
        fWaterFlowToFeces = 0;
    end
    
    methods
        function this = Food_to_Feces_Converter(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            this.fLastUpdate = 0;
            
            this.afPartialFlows= zeros(1, this.oPhase.oMT.iSubstances);
        end
        
        function update(this)
            
            fTimeStep = this.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            if fTimeStep <= 0.1
                return
            end
            
            arPartialFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            
            afMassCurrent = this.oPhase.afMass - this.oPhase.oStore.oContainer.afInitialMassSolidFood;
            
            % TO DO: once the food property table is implemented in V-HAB
            % use it to find out all possible names for food for V-HAB and
            % use that to decide the total food mass in the phase.
            % Currently it only uses the carbon mass.
            fFoodMass       = afMassCurrent(this.oMT.tiN2I.C);
            
            % Total baseline flowrate of feces (solid and water)
            fBaselineFlowRate = this.oPhase.oStore.oContainer.iCrewMembers * this.fDailyFecesProductionPerCM / (24*3600);
            
            if fFoodMass > (this.oPhase.oStore.oContainer.iCrewMembers * this.fDailyFecesProductionPerCM)
                fExcessMass = fFoodMass - (this.oPhase.oStore.oContainer.iCrewMembers * this.fDailyFecesProductionPerCM * (1/this.fFecesWaterPercent));
                fFoodProcessTime = 12*3600;
                
                fAdditionalFecesFlow = fExcessMass / fFoodProcessTime;
            else
                fAdditionalFecesFlow = 0;
            end
            
            % The total flow rate of feces (solid and water) acccording to
            % the baseline and the additional food the human ate
            fTotalFecesFlow = fBaselineFlowRate + fAdditionalFecesFlow;
            
            % The respective water flow rate is the total flow rate times
            % the water percentage within the feces
            this.fWaterFlowToFeces = fTotalFecesFlow * this.fFecesWaterPercent;
            
            % while the solid feces flow rate is the total flow minus the
            % water flow
            fFecesFlow = fTotalFecesFlow - this.fWaterFlowToFeces;
            
            if isnan(fFecesFlow)
                keyboard()
            end
            % Now the flow rates have to be set for the manip. Since the
            % water remains water the manip does not change it, instead the
            % flow rate calculated for the water here is then used by the
            % p2p to move the according amount of water to the feces phase.
            arPartialFlowRates(this.oMT.tiN2I.Feces) =  fFecesFlow;
            arPartialFlowRates(this.oMT.tiN2I.C)     = -fFecesFlow;
            
            update@matter.manips.substance.flow(this, arPartialFlowRates);
            
            this.fLastUpdate = this.oPhase.oStore.oTimer.fTime;
        end
        
        
    end
end