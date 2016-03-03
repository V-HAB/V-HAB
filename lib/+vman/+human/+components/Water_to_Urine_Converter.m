classdef Water_to_Urine_Converter < matter.manips.substance.flow
    
    %A phase manipulator to simulate conversion of food to feces
                                    
    
    properties (SetAccess = protected, GetAccess = public)
        fLastUpdate;
       
    end
    
    methods
        function this = Water_to_Urine_Converter(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            this.fLastUpdate = 0;
        end
        
        function update(this)
            
            fTimeStep = this.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            if fTimeStep <= 0
                return
            end
            
            arPartialFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            
            afMassCurrent = this.oPhase.afMass - this.oPhase.oStore.oContainer.afInitialMassLiquidFood;
            
            % TO DO: once the food property table is implemented in V-HAB
            % use it to find out all possible names for food for V-HAB and
            % use that to decide the total food mass in the phase.
            % Currently it only uses the carbon mass.
            fWaterMass       = afMassCurrent(this.oMT.tiN2I.H2O);
            
            % According to the BVAD human values (see main file of the
            % human model) a human produces 1.4323 kg of humidity for 8h
            % sleep and 16 h nominal conditions. Therefore assuming a 2kg
            % water consumption of the human generally about 0.57 kg of 
            % urine are produced per day 
            fBaselineFlowRate = this.oPhase.oStore.oContainer.iCrewMembers * 0.57 / (24*3600);
            
            if fWaterMass > (this.oPhase.oStore.oContainer.iCrewMembers * 0.57)
                fExcessWaterMass = fWaterMass - (this.oPhase.oStore.oContainer.iCrewMembers * 0.57);
                fFoodProcessTime = 12*3600;
                
                fAdditionalUrineFlow = fExcessWaterMass / fFoodProcessTime;
            else
                fAdditionalUrineFlow = 0;
            end
            
            fUrineFlow = fBaselineFlowRate + fAdditionalUrineFlow;
            
            % Now the flow rates have to be set for the manip
            arPartialFlowRates(this.oMT.tiN2I.H2O)      =  -fUrineFlow;
            arPartialFlowRates(this.oMT.tiN2I.Urine)    =   fUrineFlow;
            
            update@matter.manips.substance.flow(this, arPartialFlowRates);
            
            this.fLastUpdate = this.oPhase.oStore.oTimer.fTime;
        end
        
        
    end
end