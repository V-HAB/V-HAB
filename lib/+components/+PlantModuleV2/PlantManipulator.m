classdef PlantManipulator < matter.manips.substance.flow
    % This manipulator converts O2, CO2, H2O, Nutrients and Biomass 
    
    properties
        % parent system reference
        oParent;
        
        iEdibleWetBiomass;
        iInedibleWetBiomass;
        
        fTotalError = 0;
        fLastExec = 0;
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
            
            fTimeStep = this.oTimer.fTime - this.fLastExec;
            
            fError = sum(this.afPartialFlows);
            this.fTotalError = this.fTotalError + (fError * fTimeStep);
            
            
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
            
            
            update@matter.manips.substance.flow(this, afPartialFlows);
            
            %%
            
            %% Set Plant Growth Flow Rates

            % current masses in the balance phase:
            afCurrentBalanceMass = this.oPhase.afMass;
            
            afPartialFlowRatesBiomass = zeros(1,this.oMT.iSubstances);
            if 0.999*this.oParent.afInitialBalanceMass(this.iEdibleWetBiomass) > afCurrentBalanceMass (this.iEdibleWetBiomass)
                afPartialFlowRatesBiomass(this.iEdibleWetBiomass) = afPartialFlows(this.iEdibleWetBiomass) * 1.01;

            elseif 1.001*this.oParent.afInitialBalanceMass(this.iEdibleWetBiomass) < afCurrentBalanceMass (this.iEdibleWetBiomass)
                afPartialFlowRatesBiomass(this.iEdibleWetBiomass) = afPartialFlows(this.iEdibleWetBiomass) * 0.99;

            else
                afPartialFlowRatesBiomass(this.iEdibleWetBiomass) = afPartialFlows(this.iEdibleWetBiomass);
            end

            if 0.999*this.oParent.afInitialBalanceMass(this.iInedibleWetBiomass) > afCurrentBalanceMass (this.iInedibleWetBiomass)
                afPartialFlowRatesBiomass(this.iInedibleWetBiomass) = afPartialFlows(this.iInedibleWetBiomass) * 1.01;

            elseif 1.001*this.oParent.afInitialBalanceMass(this.iInedibleWetBiomass) < afCurrentBalanceMass (this.iInedibleWetBiomass)
                afPartialFlowRatesBiomass(this.iInedibleWetBiomass) = afPartialFlows(this.iInedibleWetBiomass) * 0.99;

            else
                afPartialFlowRatesBiomass(this.iInedibleWetBiomass) = afPartialFlows(this.iInedibleWetBiomass);
            end

            this.oParent.toStores.Plant_Culture.toProcsP2P.BiomassGrowth_P2P.setFlowRate(afPartialFlowRatesBiomass);

            %% Set atmosphere flow rates
            % one p2p for inflows one for outflows

            % Substances that are controlled by these branches:
            aiSubstances = [this.oMT.tiN2I.CO2, this.oMT.tiN2I.H2O, this.oMT.tiN2I.O2];


            afMassChange = zeros(1,this.oMT.iSubstances);
            afMassChange(aiSubstances) =  afCurrentBalanceMass(aiSubstances) - this.oParent.afInitialBalanceMass(aiSubstances);

            afPartialFlowRatesGas = afMassChange./3600;

            afPartialFlowRatesGas(this.oMT.tiN2I.O2) = afPartialFlowRatesGas(this.oMT.tiN2I.O2)   + afPartialFlows(this.oMT.tiN2I.O2);
            afPartialFlowRatesGas(this.oMT.tiN2I.CO2) = afPartialFlowRatesGas(this.oMT.tiN2I.CO2) + afPartialFlows(this.oMT.tiN2I.CO2);
            afPartialFlowRatesGas(this.oMT.tiN2I.H2O) = afPartialFlowRatesGas(this.oMT.tiN2I.H2O) + this.oParent.tfGasExchangeRates.fTranspirationRate;

            if afPartialFlowRatesGas(this.oMT.tiN2I.H2O) < 0
                afPartialFlowRatesGas(this.oMT.tiN2I.H2O) = 0;
            end

            if ~this.oParent.bLight && (afPartialFlowRatesGas(this.oMT.tiN2I.CO2) < 0)
                afPartialFlowRatesGas(this.oMT.tiN2I.CO2) = 0;
            elseif this.oParent.bLight && (afPartialFlowRatesGas(this.oMT.tiN2I.O2) < 0)
                afPartialFlowRatesGas(this.oMT.tiN2I.O2) = 0;
            end

            afPartialFlowRatesIn = zeros(1,this.oMT.iSubstances);
            afPartialFlowRatesIn(afPartialFlowRatesGas < 0) = afPartialFlowRatesGas(afPartialFlowRatesGas < 0);

            afPartialFlowRatesOut = zeros(1,this.oMT.iSubstances);
            afPartialFlowRatesOut(afPartialFlowRatesGas > 0) = afPartialFlowRatesGas(afPartialFlowRatesGas > 0);

            % in flows are negative because it is subsystem if branch!
            this.oParent.toBranches.Atmosphere_In.oHandler.setFlowRate(afPartialFlowRatesIn);
            this.oParent.toBranches.Atmosphere_Out.oHandler.setFlowRate(afPartialFlowRatesOut);


            %% Set Water and Nutrient branch flow rates
            if 0.999 * this.oParent.afInitialBalanceMass(this.oMT.tiN2I.H2O) > afCurrentBalanceMass(this.oMT.tiN2I.H2O)
                this.oParent.toBranches.WaterSupply_In.oHandler.setFlowRate(-this.oParent.fWaterConsumptionRate * 1.01);
            elseif 1.001 * this.oParent.afInitialBalanceMass(this.oMT.tiN2I.H2O) < afCurrentBalanceMass(this.oMT.tiN2I.H2O)
                this.oParent.toBranches.WaterSupply_In.oHandler.setFlowRate(-this.oParent.fWaterConsumptionRate * 0.99);
            else
                this.oParent.toBranches.WaterSupply_In.oHandler.setFlowRate(-this.oParent.fWaterConsumptionRate);
            end
            
            if 0.999 * this.oParent.afInitialBalanceMass(this.oMT.tiN2I.Nutrients) > afCurrentBalanceMass(this.oMT.tiN2I.Nutrients)
                this.oParent.toBranches.NutrientSupply_In.oHandler.setFlowRate(-this.oParent.fNutrientConsumptionRate * 1.01);
            elseif 1.001 * this.oParent.afInitialBalanceMass(this.oMT.tiN2I.Nutrients) < afCurrentBalanceMass(this.oMT.tiN2I.Nutrients)
                this.oParent.toBranches.NutrientSupply_In.oHandler.setFlowRate(-this.oParent.fNutrientConsumptionRate * 0.99);
            else
                this.oParent.toBranches.NutrientSupply_In.oHandler.setFlowRate(-this.oParent.fNutrientConsumptionRate);
            end
            
            % For debugging, if the mass balance is no longer correct
%             fBalance = this.oParent.fNutrientConsumptionRate + this.oParent.fWaterConsumptionRate - sum(afPartialFlowRatesBiomass) - sum(afPartialFlowRatesIn) - sum(afPartialFlowRatesOut);
%             if abs(fBalance) > 1e-10
%                 keyboard()
%             end
            
            this.fLastExec = this.oTimer.fTime;
        end
    end
end