function [ ttxResults ] = calculateNutritionalContent(this, oPhase)
            
    %% Initialize

    % temporary struct
    ttxResults = struct();

    % Initialize totals
    ttxResults.EdibleTotal.Substance = 'Total';
    ttxResults.EdibleTotal.Mass = 0;
    ttxResults.EdibleTotal.DryMass = 0;

    ttxResults.EdibleTotal.ProteinMass = 0;
    ttxResults.EdibleTotal.LipidMass = 0;
    ttxResults.EdibleTotal.CarbohydrateMass = 0;
    ttxResults.EdibleTotal.AshMass = 0;

    ttxResults.EdibleTotal.TotalEnergy = 0;
    ttxResults.EdibleTotal.ProteinEnergy = 0;
    ttxResults.EdibleTotal.LipidEnergy = 0;
    ttxResults.EdibleTotal.CarbohydrateEnergy = 0;

    ttxResults.EdibleTotal.CalciumMass = 0;
    ttxResults.EdibleTotal.IronMass = 0;
    ttxResults.EdibleTotal.MagnesiumMass = 0;
    ttxResults.EdibleTotal.PhosphorusMass = 0;
    ttxResults.EdibleTotal.PotassiumMass = 0;
    ttxResults.EdibleTotal.SodiumMass = 0;
    ttxResults.EdibleTotal.ZincMass = 0;
    ttxResults.EdibleTotal.CopperMass = 0;
    ttxResults.EdibleTotal.ManganeseMass = 0;
    ttxResults.EdibleTotal.SeleniumMass = 0;
    ttxResults.EdibleTotal.FluorideMass = 0;

    ttxResults.EdibleTotal.VitaminCMass = 0;
    ttxResults.EdibleTotal.ThiaminMass = 0;
    ttxResults.EdibleTotal.RiboflavinMass = 0;
    ttxResults.EdibleTotal.NiacinMass = 0;
    ttxResults.EdibleTotal.PantothenicAcidMass = 0;
    ttxResults.EdibleTotal.VitaminB6Mass = 0;
    ttxResults.EdibleTotal.FolateMass = 0;
    ttxResults.EdibleTotal.VitaminB12Mass = 0;
    ttxResults.EdibleTotal.VitaminAMass = 0;
    ttxResults.EdibleTotal.VitaminEMass = 0;
    ttxResults.EdibleTotal.VitaminDMass = 0;
    ttxResults.EdibleTotal.VitaminKMass = 0;

    ttxResults.EdibleTotal.TryptophanMass = 0;
    ttxResults.EdibleTotal.ThreonineMass = 0;
    ttxResults.EdibleTotal.IsoleucineMass = 0;
    ttxResults.EdibleTotal.LeucineMass = 0;
    ttxResults.EdibleTotal.LysineMass = 0;
    ttxResults.EdibleTotal.MethionineMass = 0;
    ttxResults.EdibleTotal.CystineMass = 0;
    ttxResults.EdibleTotal.PhenylalanineMass = 0;
    ttxResults.EdibleTotal.TyrosineMass = 0;
    ttxResults.EdibleTotal.ValineMass = 0;
    ttxResults.EdibleTotal.HistidineMass = 0;

    %% Calculate

    % check contained substances if nutritional data available
    for iI = 1:(this.iSubstances)
        if oPhase.afMass(iI) ~= 0
            % check for all currently available edible substances 
            if isfield(this.ttxNutrientData, this.csI2N{iI})

                % substance name
                ttxResults.(this.csI2N{iI}).Substance = this.csI2N{iI};

                % substance mass and dry mass [kg]
                ttxResults.(this.csI2N{iI}).Mass = oPhase.afMass(iI);
                ttxResults.(this.csI2N{iI}).DryMass = oPhase.afMass(iI) * (1 - this.ttxNutrientData.(this.csI2N{iI}).fWaterMass);

                % protein, lipid, carbohydrate and ash content [kg]
                ttxResults.(this.csI2N{iI}).ProteinMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fProteinDMF;
                ttxResults.(this.csI2N{iI}).LipidMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fLipidDMF;
                ttxResults.(this.csI2N{iI}).CarbohydrateMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fCarbohydrateDMF;
                ttxResults.(this.csI2N{iI}).AshMass = ttxResults.(this.csI2N{iI}).DryMass - (ttxResults.(this.csI2N{iI}).ProteinMass + ttxResults.(this.csI2N{iI}).LipidMass + ttxResults.(this.csI2N{iI}).CarbohydrateMass);

                % total and partly energy content [J]
                ttxResults.(this.csI2N{iI}).TotalEnergy = this.ttxNutrientData.(this.csI2N{iI}).fEnergyMass * ttxResults.(this.csI2N{iI}).Mass;
                ttxResults.(this.csI2N{iI}).ProteinEnergy = ttxResults.(this.csI2N{iI}).ProteinMass * this.ttxNutrientData.(this.csI2N{iI}).fProteinEnergyFactor;
                ttxResults.(this.csI2N{iI}).LipidEnergy = ttxResults.(this.csI2N{iI}).ProteinMass * this.ttxNutrientData.(this.csI2N{iI}).fLipidEnergyFactor;
                ttxResults.(this.csI2N{iI}).CarbohydrateEnergy = ttxResults.(this.csI2N{iI}).ProteinMass * this.ttxNutrientData.(this.csI2N{iI}).fCarbohydrateEnergyFactor;

                % Mineral content [kg]
                ttxResults.(this.csI2N{iI}).CalciumMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fCalciumDMF;
                ttxResults.(this.csI2N{iI}).IronMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fIronDMF;
                ttxResults.(this.csI2N{iI}).MagnesiumMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fMagnesiumDMF;
                ttxResults.(this.csI2N{iI}).PhosphorusMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fPhosphorusDMF;
                ttxResults.(this.csI2N{iI}).PotassiumMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fPotassiumDMF;
                ttxResults.(this.csI2N{iI}).SodiumMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fSodiumDMF;
                ttxResults.(this.csI2N{iI}).ZincMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fZincDMF;
                ttxResults.(this.csI2N{iI}).CopperMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fCopperDMF;
                ttxResults.(this.csI2N{iI}).ManganeseMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fManganeseDMF;
                ttxResults.(this.csI2N{iI}).SeleniumMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fSeleniumDMF;
                ttxResults.(this.csI2N{iI}).FluorideMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fFluorideDMF;

                % Vitamin content [kg]
                ttxResults.(this.csI2N{iI}).VitaminCMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fVitaminCDMF;
                ttxResults.(this.csI2N{iI}).ThiaminMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fThiaminDMF;
                ttxResults.(this.csI2N{iI}).RiboflavinMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fRiboflavinDMF;
                ttxResults.(this.csI2N{iI}).NiacinMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fNiacinDMF;
                ttxResults.(this.csI2N{iI}).PantothenicAcidMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fPantothenicAcidDMF;
                ttxResults.(this.csI2N{iI}).VitaminB6Mass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fVitaminB6DMF;
                ttxResults.(this.csI2N{iI}).FolateMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fFolateDMF;
                ttxResults.(this.csI2N{iI}).VitaminB12Mass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fVitaminB12DMF;
                ttxResults.(this.csI2N{iI}).VitaminAMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fVitaminADMF;
                ttxResults.(this.csI2N{iI}).VitaminEMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fVitaminEDMF;
                ttxResults.(this.csI2N{iI}).VitaminDMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fVitaminDDMF;
                ttxResults.(this.csI2N{iI}).VitaminKMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fVitaminKDMF;

                % Amino Acid content [kg]
                ttxResults.(this.csI2N{iI}).TryptophanMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fTryptophanDMF;
                ttxResults.(this.csI2N{iI}).ThreonineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fThreonineDMF;
                ttxResults.(this.csI2N{iI}).IsoleucineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fIsoleucineDMF;
                ttxResults.(this.csI2N{iI}).LeucineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fLeucineDMF;
                ttxResults.(this.csI2N{iI}).LysineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fLysineDMF;
                ttxResults.(this.csI2N{iI}).MethionineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fMethionineDMF;
                ttxResults.(this.csI2N{iI}).CystineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fCystineDMF;
                ttxResults.(this.csI2N{iI}).PhenylalanineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fPhenylalanineDMF;
                ttxResults.(this.csI2N{iI}).TyrosineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fTyrosineDMF;
                ttxResults.(this.csI2N{iI}).ValineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fValineDMF;
                ttxResults.(this.csI2N{iI}).HistidineMass = ttxResults.(this.csI2N{iI}).DryMass * this.ttxNutrientData.(this.csI2N{iI}).fHistidineDMF;

                %% Total Edible Substance Content

                ttxResults.EdibleTotal.Mass = ttxResults.EdibleTotal.Mass + ttxResults.(this.csI2N{iI}).Mass;
                ttxResults.EdibleTotal.DryMass = ttxResults.EdibleTotal.DryMass + ttxResults.(this.csI2N{iI}).DryMass;

                ttxResults.EdibleTotal.ProteinMass = ttxResults.EdibleTotal.ProteinMass + ttxResults.(this.csI2N{iI}).ProteinMass;
                ttxResults.EdibleTotal.LipidMass = ttxResults.EdibleTotal.LipidMass + ttxResults.(this.csI2N{iI}).LipidMass;
                ttxResults.EdibleTotal.CarbohydrateMass = ttxResults.EdibleTotal.CarbohydrateMass + ttxResults.(this.csI2N{iI}).CarbohydrateMass;
                ttxResults.EdibleTotal.AshMass = ttxResults.EdibleTotal.AshMass + ttxResults.(this.csI2N{iI}).AshMass;

                ttxResults.EdibleTotal.TotalEnergy = ttxResults.EdibleTotal.TotalEnergy + ttxResults.(this.csI2N{iI}).TotalEnergy;
                ttxResults.EdibleTotal.ProteinEnergy = ttxResults.EdibleTotal.ProteinEnergy + ttxResults.(this.csI2N{iI}).ProteinEnergy;
                ttxResults.EdibleTotal.LipidEnergy = ttxResults.EdibleTotal.LipidEnergy + ttxResults.(this.csI2N{iI}).LipidEnergy;
                ttxResults.EdibleTotal.CarbohydrateEnergy = ttxResults.EdibleTotal.CarbohydrateEnergy + ttxResults.(this.csI2N{iI}).CarbohydrateEnergy;

                ttxResults.EdibleTotal.CalciumMass = ttxResults.EdibleTotal.CalciumMass + ttxResults.(this.csI2N{iI}).CalciumMass;
                ttxResults.EdibleTotal.IronMass = ttxResults.EdibleTotal.IronMass + ttxResults.(this.csI2N{iI}).IronMass;
                ttxResults.EdibleTotal.MagnesiumMass = ttxResults.EdibleTotal.MagnesiumMass + ttxResults.(this.csI2N{iI}).MagnesiumMass;
                ttxResults.EdibleTotal.PhosphorusMass = ttxResults.EdibleTotal.PhosphorusMass + ttxResults.(this.csI2N{iI}).PhosphorusMass;
                ttxResults.EdibleTotal.PotassiumMass = ttxResults.EdibleTotal.PotassiumMass + ttxResults.(this.csI2N{iI}).PotassiumMass;
                ttxResults.EdibleTotal.SodiumMass = ttxResults.EdibleTotal.SodiumMass + ttxResults.(this.csI2N{iI}).SodiumMass;
                ttxResults.EdibleTotal.ZincMass = ttxResults.EdibleTotal.ZincMass + ttxResults.(this.csI2N{iI}).ZincMass;
                ttxResults.EdibleTotal.CopperMass = ttxResults.EdibleTotal.CopperMass + ttxResults.(this.csI2N{iI}).DryMass;
                ttxResults.EdibleTotal.ManganeseMass = ttxResults.EdibleTotal.ManganeseMass + ttxResults.(this.csI2N{iI}).ManganeseMass;
                ttxResults.EdibleTotal.SeleniumMass = ttxResults.EdibleTotal.SeleniumMass + ttxResults.(this.csI2N{iI}).SeleniumMass;
                ttxResults.EdibleTotal.FluorideMass = ttxResults.EdibleTotal.FluorideMass + ttxResults.(this.csI2N{iI}).FluorideMass;

                ttxResults.EdibleTotal.VitaminCMass = ttxResults.EdibleTotal.VitaminCMass + ttxResults.(this.csI2N{iI}).VitaminCMass;
                ttxResults.EdibleTotal.ThiaminMass = ttxResults.EdibleTotal.ThiaminMass + ttxResults.(this.csI2N{iI}).ThiaminMass;
                ttxResults.EdibleTotal.RiboflavinMass = ttxResults.EdibleTotal.RiboflavinMass + ttxResults.(this.csI2N{iI}).RiboflavinMass;
                ttxResults.EdibleTotal.NiacinMass = ttxResults.EdibleTotal.NiacinMass + ttxResults.(this.csI2N{iI}).NiacinMass;
                ttxResults.EdibleTotal.PantothenicAcidMass = ttxResults.EdibleTotal.PantothenicAcidMass + ttxResults.(this.csI2N{iI}).PantothenicAcidMass;
                ttxResults.EdibleTotal.VitaminB6Mass = ttxResults.EdibleTotal.VitaminB6Mass + ttxResults.(this.csI2N{iI}).VitaminB6Mass;
                ttxResults.EdibleTotal.FolateMass = ttxResults.EdibleTotal.FolateMass + ttxResults.(this.csI2N{iI}).FolateMass;
                ttxResults.EdibleTotal.VitaminB12Mass = ttxResults.EdibleTotal.VitaminB12Mass + ttxResults.(this.csI2N{iI}).VitaminB12Mass;
                ttxResults.EdibleTotal.VitaminAMass = ttxResults.EdibleTotal.VitaminAMass + ttxResults.(this.csI2N{iI}).VitaminAMass;
                ttxResults.EdibleTotal.VitaminEMass = ttxResults.EdibleTotal.VitaminEMass + ttxResults.(this.csI2N{iI}).VitaminEMass;
                ttxResults.EdibleTotal.VitaminDMass = ttxResults.EdibleTotal.VitaminDMass + ttxResults.(this.csI2N{iI}).VitaminDMass;
                ttxResults.EdibleTotal.VitaminKMass = ttxResults.EdibleTotal.VitaminKMass + ttxResults.(this.csI2N{iI}).VitaminKMass;

                ttxResults.EdibleTotal.TryptophanMass = ttxResults.EdibleTotal.TryptophanMass + ttxResults.(this.csI2N{iI}).TryptophanMass;
                ttxResults.EdibleTotal.ThreonineMass = ttxResults.EdibleTotal.ThreonineMass + ttxResults.(this.csI2N{iI}).ThreonineMass;
                ttxResults.EdibleTotal.IsoleucineMass = ttxResults.EdibleTotal.IsoleucineMass + ttxResults.(this.csI2N{iI}).IsoleucineMass;
                ttxResults.EdibleTotal.LeucineMass = ttxResults.EdibleTotal.LeucineMass + ttxResults.(this.csI2N{iI}).LeucineMass;
                ttxResults.EdibleTotal.LysineMass = ttxResults.EdibleTotal.LysineMass + ttxResults.(this.csI2N{iI}).LysineMass;
                ttxResults.EdibleTotal.MethionineMass = ttxResults.EdibleTotal.MethionineMass + ttxResults.(this.csI2N{iI}).MethionineMass;
                ttxResults.EdibleTotal.CystineMass = ttxResults.EdibleTotal.CystineMass + ttxResults.(this.csI2N{iI}).CystineMass;
                ttxResults.EdibleTotal.PhenylalanineMass = ttxResults.EdibleTotal.PhenylalanineMass + ttxResults.(this.csI2N{iI}).PhenylalanineMass;
                ttxResults.EdibleTotal.TyrosineMass = ttxResults.EdibleTotal.TyrosineMass + ttxResults.(this.csI2N{iI}).TyrosineMass;
                ttxResults.EdibleTotal.ValineMass = ttxResults.EdibleTotal.ValineMass + ttxResults.(this.csI2N{iI}).ValineMass;
                ttxResults.EdibleTotal.HistidineMass = ttxResults.EdibleTotal.HistidineMass + ttxResults.(this.csI2N{iI}).HistidineMass;

            % if not an edible substance
            else
                % substance name
                ttxResults.(this.csI2N{iI}).Substance = this.csI2N{iI};

                % substance mass and dry mass [kg]
                ttxResults.(this.csI2N{iI}).Mass = oPhase.afMass(iI);
            end
        end
    end
end