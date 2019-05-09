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

% loop over all known edible substances
for iI = 1:length(this.csEdibleSubstances)
    sSubstance = this.csEdibleSubstances{iI};
    if oPhase.afMass(this.tiN2I.(sSubstance)) ~= 0
        % get the nutrient data struct for the edible substance
        txNutrientData = this.ttxMatter.(sSubstance).txNutrientData;
        
        % substance name
        ttxResults.(sSubstance).Substance = sSubstance;
        
        % substance mass and dry mass [kg]
        ttxResults.(sSubstance).Mass = oPhase.afMass(this.tiN2I.(sSubstance));
        ttxResults.(sSubstance).DryMass = oPhase.afMass(this.tiN2I.(sSubstance)) * (1 - txNutrientData.fWaterMass);
        
        % protein, lipid, carbohydrate and ash content [kg]
        ttxResults.(sSubstance).ProteinMass = ttxResults.(sSubstance).DryMass * txNutrientData.fProteinDMF;
        ttxResults.(sSubstance).LipidMass = ttxResults.(sSubstance).DryMass * txNutrientData.fLipidDMF;
        ttxResults.(sSubstance).CarbohydrateMass = ttxResults.(sSubstance).DryMass * txNutrientData.fCarbohydrateDMF;
        ttxResults.(sSubstance).AshMass = ttxResults.(sSubstance).DryMass - (ttxResults.(sSubstance).ProteinMass + ttxResults.(sSubstance).LipidMass + ttxResults.(sSubstance).CarbohydrateMass);
        
        % total and partly energy content [J]
        ttxResults.(sSubstance).TotalEnergy = txNutrientData.fEnergyMass * ttxResults.(sSubstance).Mass;
        
        % "Chapter 3: Calculation Of The Energy Content Of Foods – Energy
        % Conversion Factors". Food and Agriculture Organization of the
        % United Nations.
        % Protein:          17 * 10^6; % J/kg
        % Fat:              37 * 10^6; % J/kg
        % Carbohydrates:    17 * 10^6; % J/kg
        %
        % However, the values in the calculate Nutritional Content
        % function, which is based on American data, divergeses
        % TO DO: find a better solution for this, if this is
        % changed, the lib human model must also be changed!
        ttxResults.(sSubstance).ProteinEnergy = ttxResults.(sSubstance).ProteinMass * 17 * 10^6; % txNutrientData.fProteinEnergyFactor;
        ttxResults.(sSubstance).LipidEnergy = ttxResults.(sSubstance).LipidMass * 37 * 10^6; % txNutrientData.fLipidEnergyFactor;
        ttxResults.(sSubstance).CarbohydrateEnergy = ttxResults.(sSubstance).CarbohydrateMass * 17 * 10^6; %txNutrientData.fCarbohydrateEnergyFactor;
        
        % Mineral content [kg]
        ttxResults.(sSubstance).CalciumMass = ttxResults.(sSubstance).DryMass * txNutrientData.fCalciumDMF;
        ttxResults.(sSubstance).IronMass = ttxResults.(sSubstance).DryMass * txNutrientData.fIronDMF;
        ttxResults.(sSubstance).MagnesiumMass = ttxResults.(sSubstance).DryMass * txNutrientData.fMagnesiumDMF;
        ttxResults.(sSubstance).PhosphorusMass = ttxResults.(sSubstance).DryMass * txNutrientData.fPhosphorusDMF;
        ttxResults.(sSubstance).PotassiumMass = ttxResults.(sSubstance).DryMass * txNutrientData.fPotassiumDMF;
        ttxResults.(sSubstance).SodiumMass = ttxResults.(sSubstance).DryMass * txNutrientData.fSodiumDMF;
        ttxResults.(sSubstance).ZincMass = ttxResults.(sSubstance).DryMass * txNutrientData.fZincDMF;
        ttxResults.(sSubstance).CopperMass = ttxResults.(sSubstance).DryMass * txNutrientData.fCopperDMF;
        ttxResults.(sSubstance).ManganeseMass = ttxResults.(sSubstance).DryMass * txNutrientData.fManganeseDMF;
        ttxResults.(sSubstance).SeleniumMass = ttxResults.(sSubstance).DryMass * txNutrientData.fSeleniumDMF;
        ttxResults.(sSubstance).FluorideMass = ttxResults.(sSubstance).DryMass * txNutrientData.fFluorideDMF;
        
        % Vitamin content [kg]
        ttxResults.(sSubstance).VitaminCMass = ttxResults.(sSubstance).DryMass * txNutrientData.fVitaminCDMF;
        ttxResults.(sSubstance).ThiaminMass = ttxResults.(sSubstance).DryMass * txNutrientData.fThiaminDMF;
        ttxResults.(sSubstance).RiboflavinMass = ttxResults.(sSubstance).DryMass * txNutrientData.fRiboflavinDMF;
        ttxResults.(sSubstance).NiacinMass = ttxResults.(sSubstance).DryMass * txNutrientData.fNiacinDMF;
        ttxResults.(sSubstance).PantothenicAcidMass = ttxResults.(sSubstance).DryMass * txNutrientData.fPantothenicAcidDMF;
        ttxResults.(sSubstance).VitaminB6Mass = ttxResults.(sSubstance).DryMass * txNutrientData.fVitaminB6DMF;
        ttxResults.(sSubstance).FolateMass = ttxResults.(sSubstance).DryMass * txNutrientData.fFolateDMF;
        ttxResults.(sSubstance).VitaminB12Mass = ttxResults.(sSubstance).DryMass * txNutrientData.fVitaminB12DMF;
        ttxResults.(sSubstance).VitaminAMass = ttxResults.(sSubstance).DryMass * txNutrientData.fVitaminADMF;
        ttxResults.(sSubstance).VitaminEMass = ttxResults.(sSubstance).DryMass * txNutrientData.fVitaminEDMF;
        ttxResults.(sSubstance).VitaminDMass = ttxResults.(sSubstance).DryMass * txNutrientData.fVitaminDDMF;
        ttxResults.(sSubstance).VitaminKMass = ttxResults.(sSubstance).DryMass * txNutrientData.fVitaminKDMF;
        
        % Amino Acid content [kg]
        ttxResults.(sSubstance).TryptophanMass = ttxResults.(sSubstance).DryMass * txNutrientData.fTryptophanDMF;
        ttxResults.(sSubstance).ThreonineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fThreonineDMF;
        ttxResults.(sSubstance).IsoleucineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fIsoleucineDMF;
        ttxResults.(sSubstance).LeucineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fLeucineDMF;
        ttxResults.(sSubstance).LysineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fLysineDMF;
        ttxResults.(sSubstance).MethionineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fMethionineDMF;
        ttxResults.(sSubstance).CystineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fCystineDMF;
        ttxResults.(sSubstance).PhenylalanineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fPhenylalanineDMF;
        ttxResults.(sSubstance).TyrosineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fTyrosineDMF;
        ttxResults.(sSubstance).ValineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fValineDMF;
        ttxResults.(sSubstance).HistidineMass = ttxResults.(sSubstance).DryMass * txNutrientData.fHistidineDMF;
        
        %% Total Edible Substance Content
        
        ttxResults.EdibleTotal.Mass = ttxResults.EdibleTotal.Mass + ttxResults.(sSubstance).Mass;
        ttxResults.EdibleTotal.DryMass = ttxResults.EdibleTotal.DryMass + ttxResults.(sSubstance).DryMass;
        
        ttxResults.EdibleTotal.ProteinMass = ttxResults.EdibleTotal.ProteinMass + ttxResults.(sSubstance).ProteinMass;
        ttxResults.EdibleTotal.LipidMass = ttxResults.EdibleTotal.LipidMass + ttxResults.(sSubstance).LipidMass;
        ttxResults.EdibleTotal.CarbohydrateMass = ttxResults.EdibleTotal.CarbohydrateMass + ttxResults.(sSubstance).CarbohydrateMass;
        ttxResults.EdibleTotal.AshMass = ttxResults.EdibleTotal.AshMass + ttxResults.(sSubstance).AshMass;
        
        ttxResults.EdibleTotal.TotalEnergy = ttxResults.EdibleTotal.TotalEnergy + ttxResults.(sSubstance).TotalEnergy;
        ttxResults.EdibleTotal.ProteinEnergy = ttxResults.EdibleTotal.ProteinEnergy + ttxResults.(sSubstance).ProteinEnergy;
        ttxResults.EdibleTotal.LipidEnergy = ttxResults.EdibleTotal.LipidEnergy + ttxResults.(sSubstance).LipidEnergy;
        ttxResults.EdibleTotal.CarbohydrateEnergy = ttxResults.EdibleTotal.CarbohydrateEnergy + ttxResults.(sSubstance).CarbohydrateEnergy;
        
        ttxResults.EdibleTotal.CalciumMass = ttxResults.EdibleTotal.CalciumMass + ttxResults.(sSubstance).CalciumMass;
        ttxResults.EdibleTotal.IronMass = ttxResults.EdibleTotal.IronMass + ttxResults.(sSubstance).IronMass;
        ttxResults.EdibleTotal.MagnesiumMass = ttxResults.EdibleTotal.MagnesiumMass + ttxResults.(sSubstance).MagnesiumMass;
        ttxResults.EdibleTotal.PhosphorusMass = ttxResults.EdibleTotal.PhosphorusMass + ttxResults.(sSubstance).PhosphorusMass;
        ttxResults.EdibleTotal.PotassiumMass = ttxResults.EdibleTotal.PotassiumMass + ttxResults.(sSubstance).PotassiumMass;
        ttxResults.EdibleTotal.SodiumMass = ttxResults.EdibleTotal.SodiumMass + ttxResults.(sSubstance).SodiumMass;
        ttxResults.EdibleTotal.ZincMass = ttxResults.EdibleTotal.ZincMass + ttxResults.(sSubstance).ZincMass;
        ttxResults.EdibleTotal.CopperMass = ttxResults.EdibleTotal.CopperMass + ttxResults.(sSubstance).DryMass;
        ttxResults.EdibleTotal.ManganeseMass = ttxResults.EdibleTotal.ManganeseMass + ttxResults.(sSubstance).ManganeseMass;
        ttxResults.EdibleTotal.SeleniumMass = ttxResults.EdibleTotal.SeleniumMass + ttxResults.(sSubstance).SeleniumMass;
        ttxResults.EdibleTotal.FluorideMass = ttxResults.EdibleTotal.FluorideMass + ttxResults.(sSubstance).FluorideMass;
        
        ttxResults.EdibleTotal.VitaminCMass = ttxResults.EdibleTotal.VitaminCMass + ttxResults.(sSubstance).VitaminCMass;
        ttxResults.EdibleTotal.ThiaminMass = ttxResults.EdibleTotal.ThiaminMass + ttxResults.(sSubstance).ThiaminMass;
        ttxResults.EdibleTotal.RiboflavinMass = ttxResults.EdibleTotal.RiboflavinMass + ttxResults.(sSubstance).RiboflavinMass;
        ttxResults.EdibleTotal.NiacinMass = ttxResults.EdibleTotal.NiacinMass + ttxResults.(sSubstance).NiacinMass;
        ttxResults.EdibleTotal.PantothenicAcidMass = ttxResults.EdibleTotal.PantothenicAcidMass + ttxResults.(sSubstance).PantothenicAcidMass;
        ttxResults.EdibleTotal.VitaminB6Mass = ttxResults.EdibleTotal.VitaminB6Mass + ttxResults.(sSubstance).VitaminB6Mass;
        ttxResults.EdibleTotal.FolateMass = ttxResults.EdibleTotal.FolateMass + ttxResults.(sSubstance).FolateMass;
        ttxResults.EdibleTotal.VitaminB12Mass = ttxResults.EdibleTotal.VitaminB12Mass + ttxResults.(sSubstance).VitaminB12Mass;
        ttxResults.EdibleTotal.VitaminAMass = ttxResults.EdibleTotal.VitaminAMass + ttxResults.(sSubstance).VitaminAMass;
        ttxResults.EdibleTotal.VitaminEMass = ttxResults.EdibleTotal.VitaminEMass + ttxResults.(sSubstance).VitaminEMass;
        ttxResults.EdibleTotal.VitaminDMass = ttxResults.EdibleTotal.VitaminDMass + ttxResults.(sSubstance).VitaminDMass;
        ttxResults.EdibleTotal.VitaminKMass = ttxResults.EdibleTotal.VitaminKMass + ttxResults.(sSubstance).VitaminKMass;
        
        ttxResults.EdibleTotal.TryptophanMass = ttxResults.EdibleTotal.TryptophanMass + ttxResults.(sSubstance).TryptophanMass;
        ttxResults.EdibleTotal.ThreonineMass = ttxResults.EdibleTotal.ThreonineMass + ttxResults.(sSubstance).ThreonineMass;
        ttxResults.EdibleTotal.IsoleucineMass = ttxResults.EdibleTotal.IsoleucineMass + ttxResults.(sSubstance).IsoleucineMass;
        ttxResults.EdibleTotal.LeucineMass = ttxResults.EdibleTotal.LeucineMass + ttxResults.(sSubstance).LeucineMass;
        ttxResults.EdibleTotal.LysineMass = ttxResults.EdibleTotal.LysineMass + ttxResults.(sSubstance).LysineMass;
        ttxResults.EdibleTotal.MethionineMass = ttxResults.EdibleTotal.MethionineMass + ttxResults.(sSubstance).MethionineMass;
        ttxResults.EdibleTotal.CystineMass = ttxResults.EdibleTotal.CystineMass + ttxResults.(sSubstance).CystineMass;
        ttxResults.EdibleTotal.PhenylalanineMass = ttxResults.EdibleTotal.PhenylalanineMass + ttxResults.(sSubstance).PhenylalanineMass;
        ttxResults.EdibleTotal.TyrosineMass = ttxResults.EdibleTotal.TyrosineMass + ttxResults.(sSubstance).TyrosineMass;
        ttxResults.EdibleTotal.ValineMass = ttxResults.EdibleTotal.ValineMass + ttxResults.(sSubstance).ValineMass;
        ttxResults.EdibleTotal.HistidineMass = ttxResults.EdibleTotal.HistidineMass + ttxResults.(sSubstance).HistidineMass;
        
    end
end
end