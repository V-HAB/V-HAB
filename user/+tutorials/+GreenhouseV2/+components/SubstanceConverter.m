classdef SubstanceConverter < matter.manips.substance.flow
    % This manipulator converts O2, CO2, H2O, Nutrients and Biomass 
    
    properties
        % parent system reference
        oParent;
    end
    
    methods
        function this = SubstanceConverter(oParent, sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);

            this.oParent = oParent;
        end
        
        function update(this)
            
            if this.oTimer.iTick == 0
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
            afPartialFlows(1, tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'EdibleWet'])) =   this.oParent.tfBiomassGrowthRates.fGrowthRateEdible;
            afPartialFlows(1, tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'InedibleWet'])) = this.oParent.tfBiomassGrowthRates.fGrowthRateInedible;
            
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
end