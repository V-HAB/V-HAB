classdef DigestionSimulator < matter.manips.substance.flow
    
    % A phase manipulator to simulate conversion of food to
    % feces,urine,carbon dioxide and metabolic water due to 
    % metabolic stoichiometric reactions of oxidation of 
    % carbohydrates, fats, proteins
    
    
    % C6H12O6 (carbohydrates)  + 6  O2     =    6 CO2 + 6H2O
    % C16H32O2 (fats)          + 23 O2     =    16 CO2 + 16H20
    % 2C4H5ON  (protein)       + 7  O2     =    C2H6O2N2 (urine solids) + 6CO2 + 2H2O 
    
    % 5C4H5ON + C6H12O6 + C16H32O2 = C42H69O13N5 (feces solids composition)
    properties (SetAccess = protected, GetAccess = public)
        
        fCO2Production;
        fCO2Production_Fat;
        fCO2Production_Protein;
        fH2OProduction;
        fH2OProduction_Fat;
        fH2OProduction_Protein;
        fO2TotalReduction;
        fO2Reduction;
        fO2Reduction_Fat;
        fO2Reduction_Protein;
        sfPartialMassFood;
        fEnergyFlowRate = 0;
        
        fCarbohydrateMassReduction; % C6H12O6
        fProteinMassReduction;      % C4H5ON
        fFatMassReduction;          % C16H32O2
        fH2OinFoodFlowRate;
        fAshFlowRate;

        fLastExec = 0;
        fLastUpdate;
        
        ttxResults;
        
        % According to BVAD page 50 table 3.26 each crew member produces
        % 132 g of feces per day that consist of 32g solids and 100 g water
        fFecesWaterPercent = 0.746;     
        fUrineWaterPercent = 0.9644;    
        
        fWaterFlowToFeces = 0;
        fUrineFlowRate = 0;
        fLiquidUrineFlowRate = 0;
        fWaterFoodFlowRate = 0;
       
        fTime;
        
        fFoodFlowRate = 0;
        fCO2FlowRate            = 0;
        fFecesFlowRate          = 0;
        fSolidUrineFlowRate     = 0;
        fMetabolicWaterFlowRate = 0;

        fTotalMassError = 0;
        fEfficiency_Carbo = 0.90; 
        fEfficiency_Protein = 0.85; 
        fEfficiency_Fat = 0.90;  
        
        sNutrientFlowRates;
    end
    
    methods
        function this = DigestionSimulator(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            this.fLastUpdate = 0;
            
            this.afPartialFlows= zeros(1, this.oPhase.oMT.iSubstances);
            
            % Initialisation of sNutrientFlowRates
            this.sNutrientFlowRates.Carbohydrate = 0; 
            this.sNutrientFlowRates.Fat = 0; 
            this.sNutrientFlowRates.Protein = 0;  
            this.sNutrientFlowRates.Ash = 0;                
            this.sNutrientFlowRates.H2O = 0;      
            this.sNutrientFlowRates.Total = 0;
            
            % Initialisation of sfPartialmassFood
            this.sfPartialMassFood.EdibleTotal = 0;
            this.sfPartialMassFood.CabbageEdibleWet = 0;
            this.sfPartialMassFood.ChufaEdibleWet = 0;
            this.sfPartialMassFood.WheatEdibleWet = 0;
            this.sfPartialMassFood.SoybeanEdibleWet = 0;
            this.sfPartialMassFood.PeanutEdibleWet = 0;
            this.sfPartialMassFood.LettuceEdibleWet = 0;
            this.sfPartialMassFood.DrybeanEdibleWet = 0;
            this.sfPartialMassFood.CarrotsEdibleWet = 0;
            this.sfPartialMassFood.Food = 0;
            
        end

        
        function update(this)
            % Takes data from the crew
            
            
            keyboard()
            
            this.sNutrientFlowRates.Total = this.oPhase.oStore.oContainer.fFlowRateFood;
            this.sfPartialMassFood = this.oPhase.oStore.oContainer.sfPartialMassFood;
            this.ttxResults = this.oPhase.oStore.oContainer.ttxResults; % Must be calculated with the nutrient data of the content in the stomach, not the content of the HumanPhase
            % Energy per kg food
            this.fEnergyFlowRate = this.ttxResults.EdibleTotal.TotalEnergy / this.ttxResults.EdibleTotal.Mass * this.sNutrientFlowRates.Total;

            afPartialFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            % Calculates the amount of the different components in the food
            this.sNutrientFlowRates.H2O = (this.ttxResults.EdibleTotal.Mass - this.ttxResults.EdibleTotal.DryMass) / (this.ttxResults.EdibleTotal.Mass);
            this.sNutrientFlowRates.Carbohydrate = this.ttxResults.EdibleTotal.CarbohydrateMass / this.ttxResults.EdibleTotal.Mass;
            this.sNutrientFlowRates.Fat = this.ttxResults.EdibleTotal.LipidMass / this.ttxResults.EdibleTotal.Mass;
            this.sNutrientFlowRates.Protein = this.ttxResults.EdibleTotal.ProteinMass / this.ttxResults.EdibleTotal.Mass;
            this.sNutrientFlowRates.Ash = this.ttxResults.EdibleTotal.AshMass / this.ttxResults.EdibleTotal.Mass;
            
            fMolMassCarbohydrateMass = 0.180;
            fMolMassLipidMass = 0.256;
            fMolMassProteinMass =0.083;
            
            % Calculates the resulting flow rates after efficiency loss
            this.fH2OinFoodFlowRate = this.sNutrientFlowRates.Total * this.sNutrientFlowRates.H2O;
            this.fAshFlowRate = this.sNutrientFlowRates.Total * this.sNutrientFlowRates.Ash;
            
            this.fCarbohydrateMassReduction   = this.sNutrientFlowRates.Total * this.sNutrientFlowRates.Carbohydrate * this.fEfficiency_Carbo;


            this.fFatMassReduction   = this.sNutrientFlowRates.Total * this.sNutrientFlowRates.Fat * this.fEfficiency_Fat; % Hier Weiter machen ab hier fertig letztes


            this.fProteinMassReduction   = this.sNutrientFlowRates.Total  *  this.sNutrientFlowRates.Protein * this.fEfficiency_Protein;

            % O2 Reduciton for carbohydrates, fat and protein
            this.fO2Reduction = (this.fCarbohydrateMassReduction  / fMolMassCarbohydrateMass) * 6 * this.oMT.afMolarMass(this.oMT.tiN2I.O2);
            
            this.fO2Reduction_Fat = ( this.fFatMassReduction / fMolMassLipidMass) * 23 * this.oMT.afMolarMass(this.oMT.tiN2I.O2);
            
            this.fO2Reduction_Protein = (this.fProteinMassReduction / fMolMassProteinMass) * 7/2 * this.oMT.afMolarMass(this.oMT.tiN2I.O2);
            % Carbohydrate digestion
            fMolMassWater = this.oPhase.oMT.afMolarMass(tiN2I.H2O); %kg/mol
            fMolMassCO2 = this.oPhase.oMT.afMolarMass(tiN2I.CO2); %kg/mol
            rCO2Ratio = 6 *fMolMassCO2/(6*fMolMassWater+6*fMolMassCO2);
            rH2ORatio = 1-rCO2Ratio;
            
            fTotalMassFlowUsed = this.fCarbohydrateMassReduction+this.fO2Reduction; %kg/s
            
            this.fCO2Production = fTotalMassFlowUsed*rCO2Ratio; %kg/s
            this.fH2OProduction = fTotalMassFlowUsed*rH2ORatio; %kg/s
            
            % Fat digestion 
            fMolMassWater_Fat = this.oPhase.oMT.afMolarMass(tiN2I.H2O); %kg/mol
            fMolMassCO2_Fat = this.oPhase.oMT.afMolarMass(tiN2I.CO2); %kg/mol
            rCO2Ratio_Fat = 16 * fMolMassCO2_Fat/(16*fMolMassWater_Fat+16*fMolMassCO2_Fat);
            rH2ORatio_Fat = 1-rCO2Ratio_Fat;
            
            fTotalMassFlowUsed_Fat = this.fFatMassReduction+this.fO2Reduction_Fat; %kg/s
            
            this.fCO2Production_Fat = fTotalMassFlowUsed_Fat*rCO2Ratio_Fat; %kg/s
            this.fH2OProduction_Fat = fTotalMassFlowUsed_Fat*rH2ORatio_Fat; %kg/s
            
             % Protein digestion
            fMolMassWater_Protein = this.oPhase.oMT.afMolarMass(tiN2I.H2O); %kg/mol
            fMolMassCO2_Protein = this.oPhase.oMT.afMolarMass(tiN2I.CO2); %kg/mol
            fMolMassSolidUrine = 0.090; %UrineSolids
            rCO2Ratio_Protein = 6 * fMolMassCO2_Protein/(2*fMolMassWater_Protein+6*fMolMassCO2_Protein + fMolMassSolidUrine);
            rH2ORatio_Protein = 2 * fMolMassWater_Protein/( fMolMassSolidUrine + 6*fMolMassCO2_Protein + 2*fMolMassWater_Protein);
            rUrineRatio       = 1-(rCO2Ratio_Protein + rH2ORatio_Protein);
            
            fTotalMassFlowUsed_Protein= this.fProteinMassReduction+this.fO2Reduction_Protein; %kg/s
            
            this.fCO2Production_Protein = fTotalMassFlowUsed_Protein*rCO2Ratio_Protein; %kg/s
            this.fH2OProduction_Protein = fTotalMassFlowUsed_Protein*rH2ORatio_Protein; %kg/s
            this.fSolidUrineFlowRate    = fTotalMassFlowUsed_Protein*rUrineRatio; 
            
            % Feces consist of the undigested carbohydrates, fats and
            % proteins in this model. Calculation of the Urine and Feces
            % amounts
            this.fFecesFlowRate =   (1-this.fEfficiency_Carbo)/this.fEfficiency_Carbo* this.fCarbohydrateMassReduction + ...
                                    (1-this.fEfficiency_Protein) / this.fEfficiency_Protein * this.fProteinMassReduction + ...
                                    (1-this.fEfficiency_Fat) / this.fEfficiency_Fat *this.fFatMassReduction + this.fAshFlowRate;
            
            this.fLiquidUrineFlowRate  =    this.fUrineWaterPercent / (1-this.fUrineWaterPercent)*  this.fSolidUrineFlowRate;
            this.fWaterFlowToFeces  =       this.fFecesWaterPercent / (1-this.fFecesWaterPercent) * this.fFecesFlowRate;    
           
            % Total flow rates
            this.fCO2FlowRate               = this.fCO2Production   + this.fCO2Production_Fat   + this.fCO2Production_Protein;
            this.fMetabolicWaterFlowRate    = this.fH2OProduction   + this.fH2OProduction_Fat   + this.fH2OProduction_Protein;
            this.fO2TotalReduction          = this.fO2Reduction     + this.fO2Reduction_Fat     + this.fO2Reduction_Protein;

            afPartialFlowRates(this.oMT.tiN2I.Feces)            =  this.fFecesFlowRate; 
            afPartialFlowRates(this.oMT.tiN2I.UrineSolids)      =  this.fSolidUrineFlowRate;
            afPartialFlowRates(this.oMT.tiN2I.CO2)              =  this.fCO2FlowRate;
            afPartialFlowRates(this.oMT.tiN2I.H2O)              =  this.fMetabolicWaterFlowRate + this.fH2OinFoodFlowRate;
            afPartialFlowRates(this.oMT.tiN2I.O2)               = -this.fO2TotalReduction;
            
            aFieldsEdibles = fieldnames(this.sfPartialMassFood);
            for iEdiblesCounter=2 : length(aFieldsEdibles)
                 afPartialFlowRates(this.oMT.tiN2I.(aFieldsEdibles{iEdiblesCounter})) = - this.sNutrientFlowRates.Total * this.sfPartialMassFood.(aFieldsEdibles{iEdiblesCounter});
            end
            
            if abs(sum(afPartialFlowRates)) > 1e-18
                % this sum should be small, There can be numerical errors
                % on a small scale from the calculation (smaller than 1e-18
                % normally) but aside from these no error should be allowed
                % here no matter what the current situation is
                keyboard()
            end
            
            update@matter.manips.substance.flow(this, afPartialFlowRates);           
            this.fLastUpdate = this.oPhase.oStore.oTimer.fTime;
            
 
            
            
        end
    end
end