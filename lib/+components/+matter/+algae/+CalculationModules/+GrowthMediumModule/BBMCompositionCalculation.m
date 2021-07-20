classdef BBMCompositionCalculation < base
    %BBMCOMPOSITIONCALCULATION determines the mass of the components of the
    %bolds basal medium (most commonly used for algae) depending on the
    %desired volume of medium. The composition is passed back as a struct
    %containing the component divided into ions and its respective mass. in
    %the system class it is then used to create the growth medium phase.
    %The composition is based on the BBM recipe from PhytoTechnology
    %Laboratories 50x concentration (see thesis literature list [80]),
    %which states that 20ml of the concentrate have to be mixed with 980ml
    %of pure water in order to create 1 liter of medium. Some components
    %are ommited  because too low concentration, or no contribution to pH,
    %Nitrogen or Phosphorous Supply (still shown here but commented out).
    %the bActive operator can be used to use or ommit a certain component.
    
    properties
        fMediumVolume                       %[m3]
        oMT                                 %Matter Table Object
        
        tfBBMComposition                    %[kg]struct with masses of modelled BBM Components. accessed through name in matter table.
        
        fDisodiumEDTASaltConc               %[moles/m3]
        fDisodiumEDTASaltMoles              %[moles]
                
        fDibasicPotassiumPhosphateConc      %[moles/m3]
        fDibasicPotassiumPhosphateMoles     %[moles]
        
        fMonobasicPotassiumPhosphateConc    %[moles/m3]
        fMonobasicPotassiumPhosphateMoles   %[moles]
        
        fKOHConc                            %[moles/m3]
        fKOHMoles                           %[moles]
        
        fSodiumNitrateConc                  %[moles/m3]
        fSodiumNitrateMoles                 %[moles]
        
    end
    
    methods
        
        function this = BBMCompositionCalculation(fMediumVolume, oMT, oSystem)
           this.fMediumVolume = fMediumVolume;
           this.oMT = oMT;
            
            % Omited components: fBoricAcidInConcentrate = 571*10^-3;
            % %[kg/m3] bBoricAcidActive = 0;
            % %[bool]
            %
            % fAnhydrousCalciumChlorideInConcentrate = 943.6*10^-3;
            % %[kg/m3] bCalciumChlorideActive = 0;
            % %[bool]
            %
            % fCobaltNitrate6H2OInConcentrate = 24.5*10^-3;
            % %[kg/m3] bCobaltNitrateActive = 0;
            % %[bool]
            %
            % fCupricSulfate5H2OInConcentrate = 78.5*10^-3;
            % %[kg/m3] bCupricSulfateActive = 0;
            % %[bool]
            
            % fFerrousSulfate7H2OInConcentrate = 249*10^-3;
            % %[kg/m3] bFerrousSulfateActive = 0;
            % %[bool]
            %
            % fAnhydrousMagnesiumSulfateInConcentrate = 1831.3*10^-3;
            % %[kg/m3] bMagnesiumSulfateActive = 0;
            % %[bool]
            %
            % fManganeseChloride4H2OInConcentrate = 72*10^-3;
            % %[kg/m3] bManganeseChlorideActive = 0;
            % %[bool]
            %
            % fSodiumMolybdateInConcentrate = 59.7*10^-3;
            % %[kg/m3] bSodiumMolybdateActive = 0;
            % %[bool]
            
            % fZincSulfate7H2OInConcentrate = 441*10^-3;
            % %[kg/m3] bZincSulfateActive = 0;
            % %[bool]
            
            % modelled components
            fDisodiumEDTASaltInConcentrate = 3180.5*10^-3;          %[kg/m3]
            bDisodiumEDTAActive = 1;                                %[bool]
            
            fPotassiumHydroxideInConcentrate = 1550*10^-3;          %[kg/m3] according to the recipe actually more of this should be added until pH = 6.6
            bPotassiumHydroxideActive = 1;                          %[bool]
            
            fDibasicPotassiumPhosphateInConcentrate = 3750*10^-3;   %[kg/m3]
            bDibasicPotassiumPhosphateActive = 1;                   %[bool]
            
            fMonobasicPotassiumPhosphateInConcentrate = 8750*10^-3; %[kg/m3]
            bMonobasicPotassiumPhosphateActive = 1;                 %[bool]
            
            fSodiumChlorideInConcentrate = 1250*10^-3;             %[kg/m3]
            bSodiumChlorideActive = 1;                             %[bool]
            
            fSodiumNitrateInConcentrate = 12500*10^-3;             %[kg/m3]
            bSodiumNitrateActive = 1;                              %[bool]
            
            fWaterDensity = this.oMT.calculateDensity('liquid', struct('H2O', 1));
            %water in concentrate is based on 1000kg/m3 and subtracted the
            %other concentrations (which together are 30.98kg/m3)
            fWaterInConcentrate = fWaterDensity - 30.98;           %[kg/m3]
            bWaterActive = 1;                                      %[bool]
            
            %% determine volumes of water and concentrate to reach medium volume
            
            fWaterVolume = fMediumVolume * (980/1000);              %[m3], 980/1000 refers to the BBM recipe that demands the mixing of 20ml of concentrate with 980 ml of water to form 1 liter of BBM
            fConcentrateVolume = fMediumVolume - fWaterVolume;      %[m3] equal to (20/1000) * fMediumVolume
            
            
            %% calculate water mass
            fWaterMass = fWaterVolume * fWaterDensity;    %[kg] 
            
            %% calculate concentrate masses in kg
            
            % %%inactive components if bBoricAcidActive == 1
            %     fBoricAcidMass = fBoricAcidInConcentrate *
            %     fConcentrateVolume; %[kg]
            % else
            %     fBoricAcidMass = 0;%[kg]
            % end % if bCalciumChlorideActive == 1
            %     fAnhydrousCalciumChlorideMass =
            %     fAnhydrousCalciumChlorideInConcentrate *
            %     fConcentrateVolume; %[kg]
            % else
            %     fAnhydrousCalciumChlorideMass = 0; %[kg]
            % end % if bCobaltNitrateActive == 1
            %     fCobaltNitrate6H2OMass = fCobaltNitrate6H2OInConcentrate
            %     * fConcentrateVolume;%[kg]
            % else
            %     fCobaltNitrate6H2OMass = 0;%[kg]
            % end % if bCupricSulfateActive == 1
            %     fCupricSulfate5H2OMass = fCupricSulfate5H2OInConcentrate
            %     * fConcentrateVolume;%[kg]
            % else
            %     fCupricSulfate5H2OMass = 0;%[kg]
            % end
            %
            % if bFerrousSulfateActive == 1
            %     fFerrousSulfate7H2OMass =
            %     fFerrousSulfate7H2OInConcentrate * fConcentrateVolume;
            %     %[kg]
            % else
            %     fFerrousSulfate7H2OMass = 0;%[kg]
            % end
            %
            % if bMagnesiumSulfateActive == 1
            %     fAnhydrousMagnesiumSulfateMass =
            %     fAnhydrousMagnesiumSulfateInConcentrate *
            %     fConcentrateVolume; %[kg]
            % else
            %     fAnhydrousMagnesiumSulfateMass = 0;%[kg]
            % end
            %
            % if bManganeseChlorideActive == 1
            %     fManganeseChloride4H2OMass =
            %     fManganeseChloride4H2OInConcentrate * fConcentrateVolume;
            %     %[kg]
            % else
            %     fManganeseChloride4H2OMass = 0;%[kg]
            % end
            %
            % if bSodiumMolybdateActive == 1
            %     fSodiumMolybdateMass = fSodiumMolybdateInConcentrate *
            %     fConcentrateVolume;%[kg]
            % else
            %     fSodiumMolybdateMass = 0;%[kg]
            % end if bZincSulfateActive == 1
            %     fZincSulfate7H2OMass = fZincSulfate7H2OInConcentrate *
            %     fConcentrateVolume;%[kg]
            % else
            %     fZincSulfate7H2OMass = 0;%[kg]
            % end
            
            % active components
            if  bDisodiumEDTAActive == 1
                fDisodiumEDTASaltMass = fDisodiumEDTASaltInConcentrate * fConcentrateVolume;%[kg]
            else
                fDisodiumEDTASaltMass = 0;%[kg]
            end
            
            if bPotassiumHydroxideActive == 1
                fPotassiumHydroxideMass = fPotassiumHydroxideInConcentrate * fConcentrateVolume;%[kg]
            else
                fPotassiumHydroxideMass = 0;%[kg]
            end
            
            if bDibasicPotassiumPhosphateActive == 1
                fDibasicPotassiumPhosphateMass = fDibasicPotassiumPhosphateInConcentrate * fConcentrateVolume;%[kg]
            else
                fDibasicPotassiumPhosphateMass = 0;%[kg]
            end
            
            if bMonobasicPotassiumPhosphateActive == 1
                fMonobasicPotassiumPhosphateMass = fMonobasicPotassiumPhosphateInConcentrate * fConcentrateVolume;%[kg]
            else
                fMonobasicPotassiumPhosphateMass = 0;%[kg]
            end
            
            if bSodiumChlorideActive == 1
                fSodiumChlorideMass = fSodiumChlorideInConcentrate * fConcentrateVolume;%[kg]
            else
                fSodiumChlorideMass = 0;%[kg]
            end
            
            if bSodiumNitrateActive == 1
                fSodiumNitrateMass = fSodiumNitrateInConcentrate * fConcentrateVolume;%[kg]
            else
                fSodiumNitrateMass = 0;%[kg]
            end
            
            if bWaterActive == 1
                fWaterInConcentrateMass = fWaterInConcentrate * fConcentrateVolume;
            else
                fWaterInConcentrateMass = 0;
            end
            
            
            %% create struct with masses and modelled substances
            
            %all reactive components are directly split up to ions as it
            %happens in water. Molar relations/masses are needed for this!
            %OH- is not individually added, because just less H+ are
            %produced due to nature of the ph calculation. Through putting
            %OH- on left side of the equation, it is already implied, that
            %OH- reacts directly with H+. Adding it here would result in a
            %higher OH- concentration than is actually  in the solution.
            
            this.fDisodiumEDTASaltConc = (fDisodiumEDTASaltMass / this.oMT.afMolarMass(this.oMT.tiN2I.(oMT.tsN2S.DisodiumEDTASalt))) / (fMediumVolume*1000); %[moles/m3]
            this.fDisodiumEDTASaltMoles = fDisodiumEDTASaltMass / this.oMT.afMolarMass(this.oMT.tiN2I.(oMT.tsN2S.DisodiumEDTASalt)); %[moles]
            
            
            this.fDibasicPotassiumPhosphateConc = (fDibasicPotassiumPhosphateMass / this.oMT.afMolarMass(this.oMT.tiN2I.(oMT.tsN2S.DibasicPotassiumPhosphate))) / (fMediumVolume*1000); %[moles/m3]
            this.fDibasicPotassiumPhosphateMoles = fDibasicPotassiumPhosphateMass / this.oMT.afMolarMass(this.oMT.tiN2I.(oMT.tsN2S.DibasicPotassiumPhosphate)); %[moles]
            
            this.fMonobasicPotassiumPhosphateConc = (fMonobasicPotassiumPhosphateMass / this.oMT.afMolarMass(this.oMT.tiN2I.(oMT.tsN2S.MonobasicPotassiumPhosphate))) / (fMediumVolume*1000); %[moles/m3]
            this.fMonobasicPotassiumPhosphateMoles = fMonobasicPotassiumPhosphateMass / this.oMT.afMolarMass(this.oMT.tiN2I.(oMT.tsN2S.MonobasicPotassiumPhosphate)); %[moles]
            
            this.fKOHConc = (fPotassiumHydroxideMass / this.oMT.afMolarMass(this.oMT.tiN2I.KOH)) / (fMediumVolume*1000); %[moles/m3]
            this.fKOHMoles = (fPotassiumHydroxideMass / this.oMT.afMolarMass(this.oMT.tiN2I.KOH)); %[moles]
            
            this.fSodiumNitrateConc = (fSodiumNitrateMass / this.oMT.afMolarMass(this.oMT.tiN2I.(oMT.tsN2S.SodiumNitrate))) / (fMediumVolume*1000); %[moles/m3]
            this.fSodiumNitrateMoles = fSodiumNitrateMass / this.oMT.afMolarMass(this.oMT.tiN2I.(oMT.tsN2S.SodiumNitrate)); %[moles]
            
            this.tfBBMComposition = struct('H2O', fWaterMass + fWaterInConcentrateMass,...
                'C10H14N2O8', this.fDisodiumEDTASaltMoles * this.oMT.afMolarMass(oMT.tiN2I.C10H14N2O8),...
                'HPO4',     this.fDibasicPotassiumPhosphateMoles    * this.oMT.afMolarMass(oMT.tiN2I.(oMT.tsN2S.HydrogenPhosphate)),...
                'H2PO4',    this.fMonobasicPotassiumPhosphateMoles  * this.oMT.afMolarMass(oMT.tiN2I.(oMT.tsN2S.DihydrogenPhosphate)),...
                'Kplus',    (2*this.fDibasicPotassiumPhosphateMoles + this.fMonobasicPotassiumPhosphateMoles + this.fKOHMoles) * this.oMT.afMolarMass(oMT.tiN2I.(oMT.tsN2S.PotassiumIon)),...
                'NaCl',     fSodiumChlorideMass,...
                'NO3',      this.fSodiumNitrateMoles * this.oMT.afMolarMass(oMT.tiN2I.NO3),...
                'Naplus',   (this.fSodiumNitrateMoles + 2 * this.fDisodiumEDTASaltMoles) * this.oMT.afMolarMass(oMT.tiN2I.(oMT.tsN2S.SodiumIon)),...
                'OH',       this.fKOHMoles * this.oMT.afMolarMass(oMT.tiN2I.OH)); %[kg]
            
            %% Check charge balance
            fChargeBalanceNatrium =	(this.tfBBMComposition.C10H14N2O8   / this.oMT.afMolarMass(oMT.tiN2I.C10H14N2O8))   * (-2) +...
                                    (this.tfBBMComposition.NO3          / this.oMT.afMolarMass(oMT.tiN2I.NO3))          * (-1) +...
                                    (this.tfBBMComposition.Naplus       / this.oMT.afMolarMass(oMT.tiN2I.Naplus))       * (+1);
                                
            fChargeBalanceKalium =  (this.tfBBMComposition.HPO4         / this.oMT.afMolarMass(oMT.tiN2I.HPO4))         * (-2) +...
                                    (this.tfBBMComposition.H2PO4        / this.oMT.afMolarMass(oMT.tiN2I.H2PO4))        * (-1) +...
                                    (this.tfBBMComposition.OH           / this.oMT.afMolarMass(oMT.tiN2I.OH))      * (-1) +... 
                                    (this.tfBBMComposition.Kplus        / this.oMT.afMolarMass(oMT.tiN2I.Kplus))        * (+1);
           
            if abs(fChargeBalanceNatrium) > 1e-12 || abs(fChargeBalanceKalium) > 1e-12
                keyboard()
            end
        end
    end
end
