classdef SubstanceConverterGasExchange < matter.manips.substance.flow
    % This manipulator converts O2, CO2, H2O, Nutrients and Biomass 
    
    properties
        % parent system reference
        oParent;
        
        % gas component inflow conversion factor
        fFactorO2 = 0;
        fFactorCO2 = 0;
        fFactorH2O = 0;
        
        %% for logging
        fBalanceFlow = 0;
        fO2Flow = 0;
        fCO2Flow = 0;
        fH2OFlow = 0;
    end
    
    methods
        function this = SubstanceConverterGasExchange(oParent, sName, oPhase)
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
            
%             if this.oTimer.fTime >=120
%                 keyboard();
%             end
            
            %%  for logging
            this.fBalanceFlow   = this.oPhase.afCurrentTotalInOuts(tiN2I.BiomassBalance);
            this.fO2Flow        = this.fFactorO2 * this.fBalanceFlow;
            this.fCO2Flow       = this.fFactorCO2 * this.fBalanceFlow;
            this.fH2OFlow       = this.fFactorH2O * this.fBalanceFlow;
            
            afPartialFlows(1, tiN2I.O2)                 = this.fO2Flow;
            afPartialFlows(1, tiN2I.CO2)                = this.fCO2Flow;
            afPartialFlows(1, tiN2I.H2O)                = this.fH2OFlow;
            afPartialFlows(1, tiN2I.BiomassBalance)     = -this.fBalanceFlow;
            
            %%
%             % gas exchange with atmosphere (default plants -> atmosphere, 
%             % so same sign for destruction)
%             afPartialFlows(1, tiN2I.O2)                 = this.fFactorO2 * this.oPhase.afCurrentTotalInOuts(tiN2I.BiomassBalance);
%             afPartialFlows(1, tiN2I.CO2)                = this.fFactorCO2 * this.oPhase.afCurrentTotalInOuts(tiN2I.BiomassBalance);
%             afPartialFlows(1, tiN2I.H2O)                = this.fFactorH2O * this.oPhase.afCurrentTotalInOuts(tiN2I.BiomassBalance);
%             afPartialFlows(1, tiN2I.BiomassBalance)     = -this.oPhase.afCurrentTotalInOuts(tiN2I.BiomassBalance);
            
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
end