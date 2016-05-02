classdef SubstanceConverterWaterNutrients < matter.manips.substance.flow
    % This manipulator converts O2, CO2, H2O, Nutrients and Biomass 
    
    properties
        % parent system reference
        oParent;
    end
    
    methods
        function this = SubstanceConverterWaterNutrients(oParent, sName, oPhase)
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
            afPartialFlows(1, tiN2I.BiomassBalance) = this.oParent.fWaterConsumptionRate + this.oParent.fNutrientConsumptionRate;
            
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
end