classdef SubstanceConverterPlantGrowth < matter.manips.substance.flow
    % This manipulator converts O2, CO2, H2O, Nutrients and Biomass 
    
    properties
        % parent system reference
        oParent;
        
        % inflow conversion factor edible and inedible 
        fFactorEdible = 0;
        fFactorInedible = 0;
        
        %% for logging
        fBalanceFlow = 0;
        fEdibleFlow = 0;
        fInedibleFlow = 0;
    end
    
    methods
        function this = SubstanceConverterPlantGrowth(oParent, sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);

            this.oParent = oParent;
        end
        
        function update(this)
            
            if this.oTimer.fTime <= 0
                return;
            end
            
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            % for faster reference
            tiN2I      = this.oPhase.oMT.tiN2I;
 
            %% for logging
            this.fBalanceFlow   = this.oPhase.afCurrentTotalInOuts(tiN2I.BiomassBalance);
            this.fEdibleFlow    = this.fFactorEdible * this.fBalanceFlow;
            this.fInedibleFlow  = this.fFactorInedible * this.fBalanceFlow;
            
            afPartialFlows(1, tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'EdibleWet']))      = this.fEdibleFlow;   
            afPartialFlows(1, tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'InedibleWet']))    = this.fInedibleFlow;
            afPartialFlows(1, tiN2I.BiomassBalance)                                                     = -this.fBalanceFlow;
            
            %%
%             % edible and inedible biomass growth
%             afPartialFlows(1, tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'EdibleWet']))      = this.fFactorEdible * this.oPhase.afCurrentTotalInOuts(tiN2I.BiomassBalance);
%             afPartialFlows(1, tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'InedibleWet']))    = this.fFactorInedible * this.oPhase.afCurrentTotalInOuts(tiN2I.BiomassBalance);
%             afPartialFlows(1, tiN2I.BiomassBalance)                                                     = -this.oPhase.afCurrentTotalInOuts(tiN2I.BiomassBalance);
            
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
end