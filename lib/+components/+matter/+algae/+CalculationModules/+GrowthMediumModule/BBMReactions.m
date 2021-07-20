classdef BBMReactions < base
    
    properties
        oCallingManip               %manipulator calling this function
        
        fM_EDTA2minus_ini;          %moles initial of EDTA2- added to solution
        fM_H2PO4_ini;               %moles initial of Dihydrogen Phosphate added to solution
        fM_HPO4_ini;                %moles  Hydrogen Phosphate added to solution
        fM_KOH_ini;                 %moles Potassium hydroxide added to solution
        
        fC_EDTA2minus_ini           %[mol/L] initial concentration of EDTA2-^
        fC_H2PO4_ini                %[mol/L] initial concentration of Dihydrogen Phosphate
        fC_HPO4_ini                 %[mol/L] initial concentration of Hydrogen Phosphate
        fC_KOH_ini                  %[mol/L] initial concentration of Potassium Hydroxide
        
        mfCurrentConcentrationAll;
        fCurrentTotalEDTA               = 0;
        fCurrentTotalInorganicCarbon    = 0;
        fCurrentTotalPhosphate          = 0;
        fCurrentTotalMass               = 0;
        
        fCurrentCalculatedHplus         = 0;
        fCurrentCalculatedPH            = 0;
        fCurrentCalculatedOH            = 0;
        
        miTranslator;
        abSolve;
        
        fCurrentVolume                  = 0;
        
        %% acid constants
        fK_EDTA;                %[-] acid constant of EDTA to EDTA- and H+
        fK_EDTAminus;           %[-] acid constant of EDTA- to EDTA2- and H+
        fK_EDTA2minus;          %[-] acid constant of EDTA2- to EDTA3- and H+
        fK_EDTA3minus;          %[-] acid constant of EDTA3- to EDTA4- and H+
        
        fK_CO2;                 %[-] acid constant of CO2 + H2O to HCO3 and H+
        fK_HCO3;                %[-] acid constant of HCO3 to CO3 and H+
        
        fK_H3PO4;               %[-] acid constant of H3PO4 to H2PO4 and H+
        fK_H2PO4;               %[-] acid constant of H2PO4 to HPO4 and H+
        fK_HPO4;                %[-] acid constant of HPO4 to PO4 and H+
        
        fK_w;                    %[-] acid constant of H2O to OH- and H+
        
        oMT;
    end
    
    methods
        function this = BBMReactions(oCallingManip)

            this.oCallingManip = oCallingManip;

            this.oMT = this.oCallingManip.oMT;
            
            %% get initial moles in the medium.
            afMols = this.oCallingManip.oPhase.afMass ./ this.oMT.afMolarMass; %[mol]
            
            this.fM_EDTA2minus_ini  = afMols(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA2minus)); %[mol]
            this.fM_H2PO4_ini       = afMols(this.oMT.tiN2I.H2PO4);%[mol]
            this.fM_HPO4_ini        = afMols(this.oMT.tiN2I.HPO4);%[mol]
            this.fM_KOH_ini         = afMols(this.oMT.tiN2I.KOH);%[mol]
            
            %% set acid constnats
            this.fK_EDTA = 1 * 10^-0.26;  % Deutsche Forschungsgemeinschaft and Commission for the Investigation of Health Hazards of Chemical Compounds in the Work Area, Eds., "Ethylendiamintetraessigsäure (EDTA) und ihre Alkalisalze [MAK Value Documentation in German language, 2009], thesis literature [90]
            this.fK_EDTAminus = 1 * 10^-0.96; %Deutsche Forschungsgemeinschaft and Commission for the Investigation of Health Hazards of Chemical Compounds in the Work Area, Eds., "Ethylendiamintetraessigsäure (EDTA) und ihre Alkalisalze [MAK Value Documentation in German language, 2009], thesis literature [90]
            this.fK_EDTA2minus = 1 * 10^-2; % "Product Information Sheet: Ethylenediaminetetraacetic acid disodium salt dihydrate." Sigma-Aldrich, Inc., thesis literature [89]
            this.fK_EDTA3minus = 1 * 10^-2.4; % "Product Information Sheet: Ethylenediaminetetraacetic acid disodium salt dihydrate." Sigma-Aldrich, Inc., thesis literature [89]
   
            this.fK_CO2 = 4.47*10^-7;   % H. Kalka, ?The Closed Carbonate System.? [Online]. Available: http://www.aqion.de/site/160. [Accessed: 04-Nov-2018]. thesis literatuere [91]
            this.fK_HCO3 = 4.67*10^-11; % H. Kalka, ?The Closed Carbonate System.? [Online]. Available: http://www.aqion.de/site/160. [Accessed: 04-Nov-2018]. thesis literatuere [91]
        
            this.fK_H3PO4 = 7.07946*10^-3;  %D. D. Perrin, "Dissociation Constants of Inorganic Acids and Bases in Aqueous Solution." De Gruyter, Australian National University, Canberra, 1965. thesis literatuere [88]
            this.fK_H2PO4 = 6.30957*10^-8; %D. D. Perrin, "Dissociation Constants of Inorganic Acids and Bases in Aqueous Solution." De Gruyter, Australian National University, Canberra, 1965. thesis literatuere [88]
            this.fK_HPO4 = 4.265795*10^-13; %D. D. Perrin, "Dissociation Constants of Inorganic Acids and Bases in Aqueous Solution." De Gruyter, Australian National University, Canberra, 1965. thesis literatuere [88]
            
            this.fK_w = 10^-14;
        
            this.miTranslator = [this.oMT.tiN2I.(this.oMT.tsN2S.EDTA),...
                                 this.oMT.tiN2I.(this.oMT.tsN2S.EDTAminus),...
                                 this.oMT.tiN2I.(this.oMT.tsN2S.EDTA2minus),...
                                 this.oMT.tiN2I.(this.oMT.tsN2S.EDTA3minus),...
                                 this.oMT.tiN2I.(this.oMT.tsN2S.EDTA4minus),...
                                 this.oMT.tiN2I.(this.oMT.tsN2S.PhosphoricAcid),...
                                 this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate),...
                                 this.oMT.tiN2I.(this.oMT.tsN2S.HydrogenPhosphate),...
                                 this.oMT.tiN2I.(this.oMT.tsN2S.Phosphate),...
                                 this.oMT.tiN2I.CO2,...
                                 this.oMT.tiN2I.HCO3,...
                                 this.oMT.tiN2I.CO3,...
                                 this.oMT.tiN2I.H2O,...
                                 this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon),...
                                 this.oMT.tiN2I.Hplus];
                      
            this.abSolve = false(1, this.oMT.iSubstances);
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.EDTAminus))         = true;
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA2minus))        = true;
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA3minus))        = true;
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA4minus))        = true;
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA))              = true;
            this.abSolve(this.oMT.tiN2I.HCO3)                     = true;
            this.abSolve(this.oMT.tiN2I.CO3)                   = true;
            this.abSolve(this.oMT.tiN2I.CO2)                           = true;
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate)) = true;
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.HydrogenPhosphate)) = true;
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.Phosphate))         = true;
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.PhosphoricAcid))    = true;
            this.abSolve(this.oMT.tiN2I.(this.oMT.tsN2S.HydroxideIon))      = true;
            this.abSolve(this.oMT.tiN2I.H2O)                           = true;
            this.abSolve(this.oMT.tiN2I.Hplus)                         = true;       
        end
        
        function afPartialFlowRates = update(this, fTimeStep)
            %% initial concentrations (left side of charge balance)
            %calculate the initial concentrations by using the initial
            %moles and relating them to the current water volume, since
            %concentrations could have changed due to changed water volume
            
            this.oMT = this.oCallingManip.oMT;
            
            fCurrentWaterVolume = 1000*this.oCallingManip.oPhase.afMass(this.oMT.tiN2I.H2O)/this.oCallingManip.oPhase.fDensity; %1000*[m3] = [L]
            this.fC_EDTA2minus_ini = this.fM_EDTA2minus_ini / fCurrentWaterVolume; %[mol/L]
            this.fC_H2PO4_ini = (this.fM_H2PO4_ini)/ fCurrentWaterVolume;    %[mol/L]
            this.fC_HPO4_ini = this.fM_HPO4_ini / fCurrentWaterVolume;       %[mol/L
            this.fC_KOH_ini =  this.fM_KOH_ini / fCurrentWaterVolume;        %[mol/L]
            
            this.fCurrentVolume = fCurrentWaterVolume;
            
            %% gather current concentrations (right side of charge balance)
            
            mfCurrentConcentration                = (this.oCallingManip.oPhase.afMass ./ this.oMT.afMolarMass) ./ fCurrentWaterVolume; %[mol/L] from mass, molar mass and current water volume.
            this.mfCurrentConcentrationAll        = mfCurrentConcentration;
            mfCurrentMass                         = this.oCallingManip.oPhase.afMass;
            mfCurrentConcentration(~this.abSolve) = 0;
            mfCurrentMass(~this.abSolve)          = 0;
            
            this.fCurrentTotalEDTA               = mfCurrentConcentration(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA))             + mfCurrentConcentration(this.oMT.tiN2I.(this.oMT.tsN2S.EDTAminus))             + mfCurrentConcentration(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA2minus))     	+ mfCurrentConcentration(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA3minus)) + mfCurrentConcentration(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA4minus));
            this.fCurrentTotalInorganicCarbon    = mfCurrentConcentration(this.oMT.tiN2I.HCO3)                         + mfCurrentConcentration(this.oMT.tiN2I.CO3)                            + mfCurrentConcentration(this.oMT.tiN2I.CO2);
            this.fCurrentTotalPhosphate          = mfCurrentConcentration(this.oMT.tiN2I.(this.oMT.tsN2S.PhosphoricAcid))	+ mfCurrentConcentration(this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate))	+ mfCurrentConcentration(this.oMT.tiN2I.(this.oMT.tsN2S.HydrogenPhosphate))	+ mfCurrentConcentration(this.oMT.tiN2I.(this.oMT.tsN2S.Phosphate));

            this.fCurrentTotalMass               = sum(mfCurrentMass);
            
                             
            % Now we calculate the correct equilibrium solution that
            % ensures chemical equilibrium and charge balance. However, the
            % actual mass conversion is not considered in this system,
            % therefore the mass balance must be ensured seperatly. It is
            % possible that the system would strive toward a different
            % equilibrium than is currently possible with the exisiting
            % phase content
            fError = inf;
            iCounter = 0;
            fCurrentC_H2O    = mfCurrentConcentration(this.oMT.tiN2I.H2O);
            
            % if PH is higher than 10 the interval represents the OH-
            % concentration
            fCurrentPH = -log10(mfCurrentConcentration(this.oMT.tiN2I.Hplus));
            
            mfInitializationIntervall = [0, 1e-14, 1e-13, 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-3, 1e-2, 1e-1, 1];
            fMaxError = 1e-18;
            
            mfInitializatonError = zeros(1, length(mfInitializationIntervall));
            
            for iBoundary = 1:length(mfInitializationIntervall)
                
                if fCurrentPH > 7
                    fCurrentC_Hplus = 10^-(-log10(this.fK_w) - -log10(mfInitializationIntervall(iBoundary)));
                else
                    fCurrentC_Hplus = mfInitializationIntervall(iBoundary);
                end 
                mfConcentrations = this.solveLinearSystem(fCurrentC_Hplus, fCurrentC_H2O, fCurrentWaterVolume);

                mfInitializatonError(iBoundary) = mfConcentrations(15) - fCurrentC_Hplus;
            end
            
            for iError = 1:length(mfInitializatonError)-1
                if sign(mfInitializatonError(iError)) ~= sign(mfInitializatonError(iError+1))
                    
                    mfError(1) = mfInitializatonError(iError);
                    mfError(2) = mfInitializatonError(iError+1);
                    
                    mfIntervall(1) = mfInitializationIntervall(iError);
                    mfIntervall(2) = mfInitializationIntervall(iError+1);
                    
                    fIntervallSize = mfIntervall(2) - mfIntervall(1);
                    break
                end
            end

            while (abs(fError) > fMaxError) && fIntervallSize > fMaxError  && iCounter < 1000
                
                iCounter = iCounter + 1;
                
                fIntervallSize = mfIntervall(2) - mfIntervall(1);
                
                fNewBoundary = sum(mfIntervall) / 2;
                
                if fCurrentPH > 7
                    fCurrentC_Hplus = 10^-(-log10(this.fK_w) - -log10(fNewBoundary));
                else
                    fCurrentC_Hplus = fNewBoundary;
                end
                
                mfConcentrations = this.solveLinearSystem(fCurrentC_Hplus, fCurrentC_H2O, fCurrentWaterVolume);
                
                fError = mfConcentrations(15) - fCurrentC_Hplus;
                    
                if fIntervallSize < 1e-6
                    fCurrentC_H2O   = mfConcentrations(13);
                end
                
                if sign(fError) == sign(mfError(1))
                    mfError(1)      = fError;
                    mfIntervall(1)  = fNewBoundary;
                    
                elseif sign(fError) == sign(mfError(2))
                    mfError(2) = fError;
                    mfIntervall(2)  = fNewBoundary;
                    
                end
                
            end
            if this.fCurrentTotalEDTA == 0
                mfConcentrations(1:5) = 0;
            end
            if this.fCurrentTotalPhosphate == 0
                mfConcentrations(6:9) = 0;
            end
            if this.fCurrentTotalInorganicCarbon == 0
                mfConcentrations(10:12) = 0;
            end
            % Translate it into V-HAB notation
            mfTargetConcentration = zeros(1, this.oMT.iSubstances);
            mfTargetConcentration(this.miTranslator) = mfConcentrations;
            
            % Since the solution of the system of equation is numerical
            % slight negative values might occur from numerical erros,
            % these are rounded. Other errors result in a stop
            abNegative = mfTargetConcentration < 0;
            if all(abs(mfTargetConcentration(abNegative)) < 1e-10)
                mfTargetConcentration(abNegative) = 0;
            else
                mfConcentrations = this.solveLinearSystem(fCurrentC_Hplus, fCurrentC_H2O, fCurrentWaterVolume, mfCurrentConcentration(this.miTranslator)');
                
                mfTargetConcentration(this.miTranslator) = mfConcentrations;
                abNegative = mfTargetConcentration < 0;
                if ~all(abs(mfTargetConcentration(abNegative)) < 1e-10)
                    keyboard()
                end
            end
            
            %% Compare Concentrations of present and target in moles / L
            %difference is positive if target is larger than current
            %current concentration --> difference is positive if mass is
            %created 
            mfConcentrationDifference = mfTargetConcentration - mfCurrentConcentration;

            %% change differences to masses by multiplying with volume and molar mass
            mfMassDifference = mfConcentrationDifference .* this.oMT.afMolarMass .* fCurrentWaterVolume; %[kg]
            
            fMassError = abs(sum(mfMassDifference));
            
            if fMassError > 1e-8
                keyboard()
            end
            
            this.fCurrentCalculatedHplus = mfTargetConcentration(this.oMT.tiN2I.Hplus);
            this.fCurrentCalculatedPH	 = -log10(mfTargetConcentration(this.oMT.tiN2I.Hplus));
            
            this.fCurrentCalculatedOH = mfTargetConcentration(this.oMT.tiN2I.OH);
            
            %% set flow rates according to mass differences:
            % check if time step is larger than 0 (exclude first time
            % step) in order to ensure one is not dividing by zero
            if this.oCallingManip.fTimeStep > 0
                afPartialFlowRates = mfMassDifference ./ fTimeStep;
            else
                afPartialFlowRates = zeros(1, this.oMT.iSubstances); %[kg/s]
            end
        end
        
        function mfConcentrations = solveLinearSystem(this, fCurrentC_Hplus, fCurrentC_H2O, fCurrentWaterVolume, mfCurrentConcentrations)
            
            %% EDTA
            % mfConcentrationEDTAs = [EDTA; EDTA-; EDTA2-; EDTA3-; EDTA4-]

            % Equilibrium constant equations and conversation of mass for
            % the final equation yield the corresponding equations of the
            % new concentrations
            mfLinearSystemEDTA =    [     this.fK_EDTA         , - fCurrentC_Hplus     ,       0               ,       0               ,   0;...
                                             0                 ,     this.fK_EDTAminus , - fCurrentC_Hplus     ,       0               ,   0;...
                                             0                 ,           0           ,    this.fK_EDTA2minus , - fCurrentC_Hplus     ,   0;...
                                             0                 ,           0           ,       0               ,    this.fK_EDTA3minus ,   - fCurrentC_Hplus;...
                                             1                 ,           1           ,       1               ,       1               ,   1];

            mfLeftSideEDTA = zeros(5,1);
            mfLeftSideEDTA(5) = this.fCurrentTotalEDTA;


            %% phosphats
            % mfConcentrationPhosphats = [PhosphoricAcid; DihydrogenPhosphate; HydrogenPhosphate; Phosphate]
            mfLinearSystemPhosphat = [     this.fK_H3PO4        , - fCurrentC_Hplus     ,       0               ,       0           ;...
                                              0                 ,       this.fK_H2PO4   , - fCurrentC_Hplus     ,       0           ;...
                                              0                 ,           0           ,      this.fK_HPO4     , - fCurrentC_Hplus  ;...
                                              1                 ,           1           ,       1               ,       1           ];

            mfLeftSidePhosphat = zeros(4,1);
            mfLeftSidePhosphat(4) = this.fCurrentTotalPhosphate;

            %% carbon and water
            % mfConcentrationCarbon = [CO2; HCO3; CO3;  H2O, OH-, H+]
            fKC_CO2     = this.fK_CO2 * fCurrentC_H2O;
            mfLinearSystemCarbon = [      fKC_CO2     , - fCurrentC_Hplus     ,       0             ,     0       ,     0             , 0 ;...
                                              0 	  ,        this.fK_HCO3   , - fCurrentC_Hplus   ,     0       ,     0             , 0 ;...
                                              1       ,           1           ,       1             ,     0       ,     0             , 0 ;...
                                              0       ,           0           ,       0             ,     0       , fCurrentC_Hplus   , 0 ];
    
            mfLeftSideCarbon = zeros(4,1);
            mfLeftSideCarbon(3) = this.fCurrentTotalInorganicCarbon;
            mfLeftSideCarbon(4) = this.fK_w;

            %% Full System
            % mfConcentrations = [EDTA; EDTA-; EDTA2-; EDTA3-; EDTA4-; PhosphoricAcid;  DihydrogenPhosphate; HydrogenPhosphate; Phosphate; CO2; HCO3; CO3, H2O, OH-, H+]

            % Now we built the full linear system from the part systems
            mfFullLinearSystem = zeros(15,15);
            mfFullLinearSystem(1:5, 1:5)        = mfLinearSystemEDTA;
            mfFullLinearSystem(6:9, 6:9)        = mfLinearSystemPhosphat;
            mfFullLinearSystem(10:13, 10:15)    = mfLinearSystemCarbon;

            mfFullLeftSide = zeros(15,1);
            mfFullLeftSide(1:5)                 = mfLeftSideEDTA;
            mfFullLeftSide(6:9)                 = mfLeftSidePhosphat;
            mfFullLeftSide(10:13)               = mfLeftSideCarbon;

            % No we add the total mass balance
            mfFullLinearSystem(14,:) = ones(1,15);
            mfFullLinearSystem(14,:) = mfFullLinearSystem(14,:) .* this.oMT.afMolarMass(this.miTranslator) .* fCurrentWaterVolume;

            mfFullLeftSide(14) = this.fCurrentTotalMass;

            % The 15th equation is the charge balance over the considered
            % Ions and the 15th concentration is H+
            %                           [EDTA; EDTA-; EDTA2-; EDTA3-; EDTA4-; PhosphoricAcid;  DihydrogenPhosphate; HydrogenPhosphate; Phosphate; CO2; HCO3; CO3, H2O, OH-, H+]
            mfFullLinearSystem(15,:) = [    0,  -1,     -2,     -3,     -4,      0,                     -1,             -2,                 -3,     0,    -1,       -2,        0,   -1,  +1];
            mfFullLeftSide(15)       = - (this.mfCurrentConcentrationAll(this.oMT.tiN2I.Kplus) + this.mfCurrentConcentrationAll(this.oMT.tiN2I.Naplus)) + this.mfCurrentConcentrationAll(this.oMT.tiN2I.NO3);
            
            warning('OFF', 'all')
            mfConcentrations = mfFullLinearSystem\mfFullLeftSide;
            
            if any(mfConcentrations < -1e-10) && nargin > 4
                % in this case try solving by using a lower bound optimization algorithm:
                
                LowerBound = zeros(15,1);
                UpperBound = ones(15,1)*inf;
                options.Algorithm = 'trust-region-reflective';
                options.Diagnostics = 'off';
                options.Display = 'none';
                options.FunctionTolerance = 1e-18;
                options.OptimalityTolerance = 1e-18;
                mfConcentrations = lsqlin(mfFullLinearSystem,mfFullLeftSide,[],[],[],[],LowerBound,UpperBound, mfCurrentConcentrations, options);
                
            end
            
            warning('ON', 'all')
        end
    end
end