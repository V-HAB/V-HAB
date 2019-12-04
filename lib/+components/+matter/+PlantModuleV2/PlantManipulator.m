classdef PlantManipulator < matter.manips.substance.stationary
    % This manipulator converts O2, CO2, H2O, Nutrients and Biomass 
    
    properties
        % parent system reference
        oParent;
        
        iEdibleBiomass;
        iInedibleBiomass;
        
        afTotalTransformedMass;
    end
    
    methods
        function this = PlantManipulator(oParent, sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);

            this.oParent = oParent;
            this.iEdibleBiomass = this.oMT.tiN2I.(this.oParent.txPlantParameters.sPlantSpecies);
            this.iInedibleBiomass = this.oMT.tiN2I.([this.oParent.txPlantParameters.sPlantSpecies, 'Inedible']);
            
            this.afTotalTransformedMass = zeros(1,this.oMT.iSubstances);
            
            this.registerUpdate();
        end
        
    end
        
    methods (Access = protected)
        function update(this)
            
            if this.oTimer.fTime <= 60
                afPartialFlows = zeros(1, this.oMT.iSubstances);
                update@matter.manips.substance.stationary(this, afPartialFlows);
                return;
            end
            
            fElapsedTime = this.oTimer.fTime - this.fLastExec;
            
            this.afTotalTransformedMass = this.afTotalTransformedMass + (this.afPartialFlows * fElapsedTime);
            
            
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
            afPartialFlows(1, this.iEdibleBiomass) =   this.oParent.tfBiomassGrowthRates.fGrowthRateEdible;
            afPartialFlows(1, this.iInedibleBiomass) = this.oParent.tfBiomassGrowthRates.fGrowthRateInedible;
            
            % to reduce mass erros the current error in mass is spread over
            % the in and outs
            fError = sum(afPartialFlows);
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
            
            
            update@matter.manips.substance.stationary(this, afPartialFlows);
            
            %%
            
            %% Set Plant Growth Flow Rates
            afPartialFlowRatesBiomass = zeros(1,this.oMT.iSubstances);
            % current masses in the balance phase:
            afPartialFlowRatesBiomass(this.iEdibleBiomass) = afPartialFlows(this.iEdibleBiomass); 
            afPartialFlowRatesBiomass(this.iInedibleBiomass) = afPartialFlows(this.iInedibleBiomass);
            this.oParent.toStores.Plant_Culture.toProcsP2P.BiomassGrowth_P2P.setFlowRate(afPartialFlowRatesBiomass);

            %% Set atmosphere flow rates
            % one p2p for inflows one for outflows
            afPartialFlowsGas = zeros(1,this.oMT.iSubstances);
            afPartialFlowsGas(this.oMT.tiN2I.O2)    = afPartialFlows(this.oMT.tiN2I.O2);
            afPartialFlowsGas(this.oMT.tiN2I.CO2)   = afPartialFlows(this.oMT.tiN2I.CO2);
            
            % Substances that are controlled by these branches:
            afPartialFlowsGas(this.oMT.tiN2I.H2O) = this.oParent.tfGasExchangeRates.fTranspirationRate;
            
            afPartialFlowRatesIn = zeros(1,this.oMT.iSubstances);
            afPartialFlowRatesIn(afPartialFlowsGas < 0) = afPartialFlowsGas(afPartialFlowsGas < 0);

            afPartialFlowRatesOut = zeros(1,this.oMT.iSubstances);
            afPartialFlowRatesOut(afPartialFlowsGas > 0) = afPartialFlowsGas(afPartialFlowsGas > 0);

            % in flows are negative because it is subsystem if branch!
            this.oParent.toStores.Plant_Culture.toProcsP2P.GasExchange_From_Plants_To_Atmosphere.setFlowRate(afPartialFlowRatesOut);
            this.oParent.toStores.Plant_Culture.toProcsP2P.GasExchange_From_Atmosphere_To_Plants.setFlowRate(-afPartialFlowRatesIn);
            
            %% Set Water and Nutrient branch flow rates
            this.oParent.toBranches.WaterSupply_In.oHandler.setFlowRate(-this.oParent.fWaterConsumptionRate);
            this.oParent.toBranches.NutrientSupply_In.oHandler.setFlowRate(-this.oParent.fNutrientConsumptionRate);
            
            % For debugging, if the mass balance is no longer correct
            fBalance = this.oParent.fNutrientConsumptionRate + this.oParent.fWaterConsumptionRate - sum(afPartialFlowRatesBiomass) - sum(afPartialFlowRatesIn) - sum(afPartialFlowRatesOut);
            if abs(fBalance) > 1e-10
                keyboard()
            end
            oCulture = this.oParent;
            fBalanceCulture = oCulture.tfGasExchangeRates.fO2ExchangeRate + oCulture.tfGasExchangeRates.fCO2ExchangeRate + oCulture.tfGasExchangeRates.fTranspirationRate + ...
                     (oCulture.tfBiomassGrowthRates.fGrowthRateInedible + oCulture.tfBiomassGrowthRates.fGrowthRateEdible) ...
                     - (oCulture.fWaterConsumptionRate + oCulture.fNutrientConsumptionRate);
            if abs(fBalanceCulture) > 1e-10
                keyboard()
            end
        end
    end
end