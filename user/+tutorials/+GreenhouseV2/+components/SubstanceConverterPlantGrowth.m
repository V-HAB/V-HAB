classdef SubstanceConverterPlantGrowth < matter.manips.substance.flow
    % This manipulator converts O2, CO2, H2O, Nutrients and Biomass 
    
    properties
        % parent system reference
        oParent;
    end
    
    methods
        function this = SubstanceConverterPlantGrowth(oParent, sName, oPhase)
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
 
            % edible and inedible biomass growth
            afPartialFlows(1, tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'EdibleWet'])) =   this.oParent.tfBiomassGrowthRates.fGrowthRateEdible;
            afPartialFlows(1, tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'InedibleWet'])) = this.oParent.tfBiomassGrowthRates.fGrowthRateInedible;
            afPartialFlows(1, tiN2I.BiomassBalance) = -(this.oParent.tfBiomassGrowthRates.fGrowthRateEdible + this.oParent.tfBiomassGrowthRates.fGrowthRateInedible);
            
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
end