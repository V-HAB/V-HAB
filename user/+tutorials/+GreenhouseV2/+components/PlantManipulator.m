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
            
            this.oParent.update();
            
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            % for faster reference
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            % phase inflows (water and nutrients)
            afPartialFlows(1, tiN2I.H2O) =         -(this.oParent.fWaterConsumptionRate - this.oParent.tfGasExchangeRates.fTranspirationRate);
            afPartialFlows(1, tiN2I.Nutrients) =   -this.oParent.fNutrientConsumptionRate;

            % gas exchange with atmosphere (default plants -> atmosphere, 
            % so same sign for destruction)
            afPartialFlows(1, tiN2I.O2) =          this.oParent.tfGasExchangeRates.fO2ExchangeRate;
            afPartialFlows(1, tiN2I.CO2) =         this.oParent.tfGasExchangeRates.fCO2ExchangeRate;

            % edible and inedible biomass growth
            afPartialFlows(1, this.iEdibleWetBiomass) =   this.oParent.tfBiomassGrowthRates.fGrowthRateEdible;
            afPartialFlows(1, this.iInedibleWetBiomass) = this.oParent.tfBiomassGrowthRates.fGrowthRateInedible;
            
            % to reduce mass erros the current error in mass is spread over
            % the in and outs
            fError = abs(sum(afPartialFlows));
            if fError ~= 0
                fPositiveFlowRate = sum(afPartialFlows(afPartialFlows > 0));
                fNegativeFlowRate = abs(sum(afPartialFlows(afPartialFlows < 0)));
                
                if fPositiveFlowRate > fNegativeFlowRate
                    % reduce the positive flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = afPartialFlows(afPartialFlows > 0)./fPositiveFlowRate;
                    
                    afPartialFlows(afPartialFlows > 0) = afPartialFlows(afPartialFlows > 0) - fDifference .* arRatios;
                else
                    % reduce the negative flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = abs(afPartialFlows(afPartialFlows < 0)./fNegativeFlowRate);
                    
                    afPartialFlows(afPartialFlows < 0) = afPartialFlows(afPartialFlows < 0) - fDifference .* arRatios;
                end
            end
            
            fError = abs(sum(afPartialFlows));
            if fError > 1e-18
                keyboard()
            end
            update@matter.manips.substance.flow(this, afPartialFlows);
            
        end
    end
end