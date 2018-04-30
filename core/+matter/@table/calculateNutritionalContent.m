function [ ttxResults ] = calculateNutritionalContent(this)
            
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
    for iI = 1:(this.oMT.iSubstances)
        if this.afMass(iI) ~= 0
            % check for all currently available edible substances 
            if isfield(this.ttxNutrientData, this.ttxMatter.(this.oMT.csI2N{iI}))     

                % substance name
                ttxResults.(this.oMT.csI2N{iI}).Substance = this.oMT.csI2N{iI};

                % substance mass and dry mass [kg]
                ttxResults.(this.oMT.csI2N{iI}).Mass = this.afMass(iI);
                ttxResults.(this.oMT.csI2N{iI}).DryMass = this.afMass(iI) * (1 - this.ttxNutrientData.(this.oMT.csI2N{iI}).fWaterMass);

                % protein, lipid, carbohydrate and ash content [kg]
                ttxResults.(this.oMT.csI2N{iI}).ProteinMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fProteinDMF;
                ttxResults.(this.oMT.csI2N{iI}).LipidMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fLipidDMF;
                ttxResults.(this.oMT.csI2N{iI}).CarbohydrateMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fCarbohydrateDMF;
                ttxResults.(this.oMT.csI2N{iI}).AshMass = ttxResults.(this.oMT.csI2N{iI}).DryMass - (ttxResults.(this.oMT.csI2N{iI}).ProteinMass + ttxResults.(this.oMT.csI2N{iI}).LipidMass + ttxResults.(this.oMT.csI2N{iI}).CarbohydrateMass);

                % total and partly energy content [J]
                ttxResults.(this.oMT.csI2N{iI}).TotalEnergy = this.ttxNutrientData.(this.oMT.csI2N{iI}).fEnergyMass * ttxResults.(this.oMT.csI2N{iI}).Mass;
                ttxResults.(this.oMT.csI2N{iI}).ProteinEnergy = ttxResults.(this.oMT.csI2N{iI}).ProteinMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fProteinEnergyFactor;
                ttxResults.(this.oMT.csI2N{iI}).LipidEnergy = ttxResults.(this.oMT.csI2N{iI}).ProteinMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fLipidEnergyFactor;
                ttxResults.(this.oMT.csI2N{iI}).CarbohydrateEnergy = ttxResults.(this.oMT.csI2N{iI}).ProteinMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fCarbohydrateEnergyFactor;

                % Mineral content [kg]
                ttxResults.(this.oMT.csI2N{iI}).CalciumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fCalciumDMF;
                ttxResults.(this.oMT.csI2N{iI}).IronMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fIronDMF;
                ttxResults.(this.oMT.csI2N{iI}).MagnesiumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fMagnesiumDMF;
                ttxResults.(this.oMT.csI2N{iI}).PhosphorusMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fPhosphorusDMF;
                ttxResults.(this.oMT.csI2N{iI}).PotassiumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fPotassiumDMF;
                ttxResults.(this.oMT.csI2N{iI}).SodiumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fSodiumDMF;
                ttxResults.(this.oMT.csI2N{iI}).ZincMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fZincDMF;
                ttxResults.(this.oMT.csI2N{iI}).CopperMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fCopperDMF;
                ttxResults.(this.oMT.csI2N{iI}).ManganeseMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fManganeseDMF;
                ttxResults.(this.oMT.csI2N{iI}).SeleniumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fSeleniumDMF;
                ttxResults.(this.oMT.csI2N{iI}).FluorideMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fFluorideDMF;

                % Vitamin content [kg]
                ttxResults.(this.oMT.csI2N{iI}).VitaminCMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fVitaminCDMF;
                ttxResults.(this.oMT.csI2N{iI}).ThiaminMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fThiaminDMF;
                ttxResults.(this.oMT.csI2N{iI}).RiboflavinMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fRiboflavinDMF;
                ttxResults.(this.oMT.csI2N{iI}).NiacinMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fNiacinDMF;
                ttxResults.(this.oMT.csI2N{iI}).PantothenicAcidMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fPantothenicAcidDMF;
                ttxResults.(this.oMT.csI2N{iI}).VitaminB6Mass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fVitaminB6DMF;
                ttxResults.(this.oMT.csI2N{iI}).FolateMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fFolateDMF;
                ttxResults.(this.oMT.csI2N{iI}).VitaminB12Mass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fVitaminB12DMF;
                ttxResults.(this.oMT.csI2N{iI}).VitaminAMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fVitaminADMF;
                ttxResults.(this.oMT.csI2N{iI}).VitaminEMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fVitaminEDMF;
                ttxResults.(this.oMT.csI2N{iI}).VitaminDMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fVitaminDDMF;
                ttxResults.(this.oMT.csI2N{iI}).VitaminKMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fVitaminKDMF;

                % Amino Acid content [kg]
                ttxResults.(this.oMT.csI2N{iI}).TryptophanMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fTryptophanDMF;
                ttxResults.(this.oMT.csI2N{iI}).ThreonineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fThreonineDMF;
                ttxResults.(this.oMT.csI2N{iI}).IsoleucineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fIsoleucineDMF;
                ttxResults.(this.oMT.csI2N{iI}).LeucineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fLeucineDMF;
                ttxResults.(this.oMT.csI2N{iI}).LysineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fLysineDMF;
                ttxResults.(this.oMT.csI2N{iI}).MethionineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fMethionineDMF;
                ttxResults.(this.oMT.csI2N{iI}).CystineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fCystineDMF;
                ttxResults.(this.oMT.csI2N{iI}).PhenylalanineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fPhenylalanineDMF;
                ttxResults.(this.oMT.csI2N{iI}).TyrosineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fTyrosineDMF;
                ttxResults.(this.oMT.csI2N{iI}).ValineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fValineDMF;
                ttxResults.(this.oMT.csI2N{iI}).HistidineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.ttxNutrientData.(this.oMT.csI2N{iI}).fHistidineDMF;

                %% Total Edible Substance Content

                ttxResults.EdibleTotal.Mass = ttxResults.EdibleTotal.Mass + ttxResults.(this.oMT.csI2N{iI}).Mass;
                ttxResults.EdibleTotal.DryMass = ttxResults.EdibleTotal.DryMass + ttxResults.(this.oMT.csI2N{iI}).DryMass;

                ttxResults.EdibleTotal.ProteinMass = ttxResults.EdibleTotal.ProteinMass + ttxResults.(this.oMT.csI2N{iI}).ProteinMass;
                ttxResults.EdibleTotal.LipidMass = ttxResults.EdibleTotal.LipidMass + ttxResults.(this.oMT.csI2N{iI}).LipidMass;
                ttxResults.EdibleTotal.CarbohydrateMass = ttxResults.EdibleTotal.CarbohydrateMass + ttxResults.(this.oMT.csI2N{iI}).CarbohydrateMass;
                ttxResults.EdibleTotal.AshMass = ttxResults.EdibleTotal.AshMass + ttxResults.(this.oMT.csI2N{iI}).AshMass;

                ttxResults.EdibleTotal.TotalEnergy = ttxResults.EdibleTotal.TotalEnergy + ttxResults.(this.oMT.csI2N{iI}).TotalEnergy;
                ttxResults.EdibleTotal.ProteinEnergy = ttxResults.EdibleTotal.ProteinEnergy + ttxResults.(this.oMT.csI2N{iI}).ProteinEnergy;
                ttxResults.EdibleTotal.LipidEnergy = ttxResults.EdibleTotal.LipidEnergy + ttxResults.(this.oMT.csI2N{iI}).LipidEnergy;
                ttxResults.EdibleTotal.CarbohydrateEnergy = ttxResults.EdibleTotal.CarbohydrateEnergy + ttxResults.(this.oMT.csI2N{iI}).CarbohydrateEnergy;

                ttxResults.EdibleTotal.CalciumMass = ttxResults.EdibleTotal.CalciumMass + ttxResults.(this.oMT.csI2N{iI}).CalciumMass;
                ttxResults.EdibleTotal.IronMass = ttxResults.EdibleTotal.IronMass + ttxResults.(this.oMT.csI2N{iI}).IronMass;
                ttxResults.EdibleTotal.MagnesiumMass = ttxResults.EdibleTotal.MagnesiumMass + ttxResults.(this.oMT.csI2N{iI}).MagnesiumMass;
                ttxResults.EdibleTotal.PhosphorusMass = ttxResults.EdibleTotal.PhosphorusMass + ttxResults.(this.oMT.csI2N{iI}).PhosphorusMass;
                ttxResults.EdibleTotal.PotassiumMass = ttxResults.EdibleTotal.PotassiumMass + ttxResults.(this.oMT.csI2N{iI}).PotassiumMass;
                ttxResults.EdibleTotal.SodiumMass = ttxResults.EdibleTotal.SodiumMass + ttxResults.(this.oMT.csI2N{iI}).SodiumMass;
                ttxResults.EdibleTotal.ZincMass = ttxResults.EdibleTotal.ZincMass + ttxResults.(this.oMT.csI2N{iI}).ZincMass;
                ttxResults.EdibleTotal.CopperMass = ttxResults.EdibleTotal.CopperMass + ttxResults.(this.oMT.csI2N{iI}).DryMass;
                ttxResults.EdibleTotal.ManganeseMass = ttxResults.EdibleTotal.ManganeseMass + ttxResults.(this.oMT.csI2N{iI}).ManganeseMass;
                ttxResults.EdibleTotal.SeleniumMass = ttxResults.EdibleTotal.SeleniumMass + ttxResults.(this.oMT.csI2N{iI}).SeleniumMass;
                ttxResults.EdibleTotal.FluorideMass = ttxResults.EdibleTotal.FluorideMass + ttxResults.(this.oMT.csI2N{iI}).FluorideMass;

                ttxResults.EdibleTotal.VitaminCMass = ttxResults.EdibleTotal.VitaminCMass + ttxResults.(this.oMT.csI2N{iI}).VitaminCMass;
                ttxResults.EdibleTotal.ThiaminMass = ttxResults.EdibleTotal.ThiaminMass + ttxResults.(this.oMT.csI2N{iI}).ThiaminMass;
                ttxResults.EdibleTotal.RiboflavinMass = ttxResults.EdibleTotal.RiboflavinMass + ttxResults.(this.oMT.csI2N{iI}).RiboflavinMass;
                ttxResults.EdibleTotal.NiacinMass = ttxResults.EdibleTotal.NiacinMass + ttxResults.(this.oMT.csI2N{iI}).NiacinMass;
                ttxResults.EdibleTotal.PantothenicAcidMass = ttxResults.EdibleTotal.PantothenicAcidMass + ttxResults.(this.oMT.csI2N{iI}).PantothenicAcidMass;
                ttxResults.EdibleTotal.VitaminB6Mass = ttxResults.EdibleTotal.VitaminB6Mass + ttxResults.(this.oMT.csI2N{iI}).VitaminB6Mass;
                ttxResults.EdibleTotal.FolateMass = ttxResults.EdibleTotal.FolateMass + ttxResults.(this.oMT.csI2N{iI}).FolateMass;
                ttxResults.EdibleTotal.VitaminB12Mass = ttxResults.EdibleTotal.VitaminB12Mass + ttxResults.(this.oMT.csI2N{iI}).VitaminB12Mass;
                ttxResults.EdibleTotal.VitaminAMass = ttxResults.EdibleTotal.VitaminAMass + ttxResults.(this.oMT.csI2N{iI}).VitaminAMass;
                ttxResults.EdibleTotal.VitaminEMass = ttxResults.EdibleTotal.VitaminEMass + ttxResults.(this.oMT.csI2N{iI}).VitaminEMass;
                ttxResults.EdibleTotal.VitaminDMass = ttxResults.EdibleTotal.VitaminDMass + ttxResults.(this.oMT.csI2N{iI}).VitaminDMass;
                ttxResults.EdibleTotal.VitaminKMass = ttxResults.EdibleTotal.VitaminKMass + ttxResults.(this.oMT.csI2N{iI}).VitaminKMass;

                ttxResults.EdibleTotal.TryptophanMass = ttxResults.EdibleTotal.TryptophanMass + ttxResults.(this.oMT.csI2N{iI}).TryptophanMass;
                ttxResults.EdibleTotal.ThreonineMass = ttxResults.EdibleTotal.ThreonineMass + ttxResults.(this.oMT.csI2N{iI}).ThreonineMass;
                ttxResults.EdibleTotal.IsoleucineMass = ttxResults.EdibleTotal.IsoleucineMass + ttxResults.(this.oMT.csI2N{iI}).IsoleucineMass;
                ttxResults.EdibleTotal.LeucineMass = ttxResults.EdibleTotal.LeucineMass + ttxResults.(this.oMT.csI2N{iI}).LeucineMass;
                ttxResults.EdibleTotal.LysineMass = ttxResults.EdibleTotal.LysineMass + ttxResults.(this.oMT.csI2N{iI}).LysineMass;
                ttxResults.EdibleTotal.MethionineMass = ttxResults.EdibleTotal.MethionineMass + ttxResults.(this.oMT.csI2N{iI}).MethionineMass;
                ttxResults.EdibleTotal.CystineMass = ttxResults.EdibleTotal.CystineMass + ttxResults.(this.oMT.csI2N{iI}).CystineMass;
                ttxResults.EdibleTotal.PhenylalanineMass = ttxResults.EdibleTotal.PhenylalanineMass + ttxResults.(this.oMT.csI2N{iI}).PhenylalanineMass;
                ttxResults.EdibleTotal.TyrosineMass = ttxResults.EdibleTotal.TyrosineMass + ttxResults.(this.oMT.csI2N{iI}).TyrosineMass;
                ttxResults.EdibleTotal.ValineMass = ttxResults.EdibleTotal.ValineMass + ttxResults.(this.oMT.csI2N{iI}).ValineMass;
                ttxResults.EdibleTotal.HistidineMass = ttxResults.EdibleTotal.HistidineMass + ttxResults.(this.oMT.csI2N{iI}).HistidineMass;

            % if not an edible substance
            else
                % substance name
                ttxResults.(this.oMT.csI2N{iI}).Substance = this.oMT.csI2N{iI};

                % substance mass and dry mass [kg]
                ttxResults.(this.oMT.csI2N{iI}).Mass = this.afMass(iI);
            end
        end
    end
end