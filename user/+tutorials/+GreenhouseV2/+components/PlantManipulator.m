classdef PlantManipulator < matter.manips.substance.flow
    % This manipulator converts O2, CO2, H2O, Nutrients and Biomass 
    
    properties
        % parent system reference
        oParent;
        
        iEdibleWetBiomass;
        iInedibleWetBiomass;
    end
    
    methods
        function this = PlantManipulator(oParent, sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);

            this.oParent = oParent;
            this.iEdibleWetBiomass = this.oMT.tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'EdibleWet']);
            this.iInedibleWetBiomass = this.oMT.tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'InedibleWet']);
        end
        
        function update(this)
            
            if this.oTimer.fTime <= 60
                return;
            end
            
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            % for faster reference
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            % phase inflows (water and nutrients)   
            afPartialFlows(1, tiN2I.H2O) =         -this.oParent.fWaterConsumptionRate;
            afPartialFlows(1, tiN2I.Nutrients) =   -this.oParent.fNutrientConsumptionRate;

            % gas exchange with atmosphere (default plants -> atmosphere, 
            % so same sign for destruction)
            afPartialFlows(1, tiN2I.O2) =          this.oParent.tfGasExchangeRates.fO2ExchangeRate;
            afPartialFlows(1, tiN2I.CO2) =         this.oParent.tfGasExchangeRates.fCO2ExchangeRate;
            afPartialFlows(1, tiN2I.H2O) =         this.oParent.tfGasExchangeRates.fTranspirationRate;

            % edible and inedible biomass growth
            afPartialFlows(1, this.iEdibleWetBiomass) =   this.oParent.tfBiomassGrowthRates.fGrowthRateEdible;
            afPartialFlows(1, this.iInedibleWetBiomass) = this.oParent.tfBiomassGrowthRates.fGrowthRateInedible;
            
            % to reduce mass erros the current error in mass is spread over
            % the in and outs
            fError = abs(sum(afPartialFlows));
            arRatios = afPartialFlows./abs(sum(afPartialFlows));
            afPartialFlows = afPartialFlows - (fError .* arRatios);
            
            if abs(sum(afPartialFlows)) > 1e-18
                keyboard()
            end
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
end