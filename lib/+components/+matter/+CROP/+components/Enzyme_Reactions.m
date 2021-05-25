classdef Enzyme_Reactions < matter.manips.substance.stationary
    % The modular manipulator "Enzyme Reactions" in the store "BioFilter".
    %   As is mentioned in the file "BioFilter.m", the manipulator 
    %   "Enzyme Reactions" is implemented in this file. The structure of
    %   the manipulator is described in section 4.2.3 in Sun's thesis.
    
    properties
        % The assumed volume in which the enzymatic reactions can take
        % place within the biological trickle filter
        fEnzymeVolume;
        
        % A concentration array which contains the concentrations of all 
        % reactants in mol/L (C_tot in Sun's thesis):
        csSubstances = {'H2O', 'CO2', 'O2', 'CH4N2O', 'NH3', 'NH4', 'NO2', 'NO3', 'AE', 'AES', 'AI', 'AEI', 'AESI', ' AEP', 'AEPI', 'BE', 'BESI', 'BI', 'BEI', 'BESI', 'BEP', 'BEPI', 'BES2', 'BESI2', 'CE', 'CES', 'CI', 'CESI', 'CEP', 'CEPI'};
        % 1:H2O, 2:CO2, 3:O2, 4:CH4N2O, 5:NH3, 6:NH4, 7:NO2, 8:NO3,
        % 9:A.E, 10:A.ES, 11:A.I, 12:A.EI, 13:A.ESI, 14:A.EP, 15:A.EPI,
        % 16:B.E, 17:B.ES1, 18:B.I, 19:B.EI, 20:B.ESI1, 21:B.EP, 22:B.EPI,
        % 23:B.ES2, 24:B.ESI2, 25:C.E, 26:C.ES, 27:C.I, 28:C.EI, 29:C.ESI, 
        % 30:C.EP, 31:C.EPI
        afConcentration = zeros(1,31);
        
        % The parameter struct which contains all rate constants 
        % (theta_tot in Sun's thesis)
        tParameter;
        tParameter_modified_T;
        tPmrCurrent;
        
        % An array containing the experimental temperatue values
        afTemperature;
        
        % The pH activity model
        tpH_Diagram;
        
        % The pH value
        fpH;
        
        % time step
        fElapsedTime;

        afPreviousFlowRates;
        afPreviousReactionRates;
        
        % Reference to the manip calculating the pH Value in CROP
        opH_Manip;
        
        setTimeStep;
        
        % Matrix containing the enzym kinetic model relations
        mK_total;
        hCalculateChangeRate;
        tOdeOptions = odeset('RelTol', 1e-3, 'AbsTol', 1e-4);
        
        % Molar Sum Vectors which can be used to check if the reactions
        % occured correctly. If the molar sum for any participating element
        % is not closed it is detected using these vectors
        %
        % 1:H2O, 2:CO2, 3:O2, 4:CH4N2O, 5:NH3, 6:NH4, 7:NO2, 8:NO3, 
        % 9:A.E, 10:CH4N2O_AES, 11:A.I, 12:A.EI, 13:CH4N2O_AESI, 14:(NH3)2_AEP, 15:(NH3)2_AEPI,
        % 16:B.E, 17:NH4_BES1, 18:B.I, 19:B.EI, 20:NH4_BESI1, 21:NO2_BEP, 22:NO2_BEPI,
        % 23:.NH3_BES, 24:NH3_BESI, 25:C.E, 26:NO2_CES, 27:C.I, 28:C.EI, 29:NO2_CESI, 
        % 30:NO3_CEP, 31:NO3_CEPI, 32: H+, 33: OH-
        afMolarSumH = [2, 0, 0, 4, 3, 4, 0, 0, 0, 4, 0, 0, 4, 6, 6, 0, 4, 0, 0, 4, 0, 0, 3, 3, 0, 0, 0, 0, 0, 0, 0, 1, 1];
        afMolarSumO = [1, 2, 2, 1, 0, 0, 2, 3, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 2, 0, 0, 2, 3, 3, 0, 1];
        afMolarSumC = [0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        afMolarSumN = [0, 0, 0, 2, 1, 1, 1, 1, 0, 2, 0, 0, 2, 2, 2, 0, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0];
        
        fStep = 0;
    end
    
    methods
        function this = Enzyme_Reactions(sName, oPhase, fEnzymeVolume)
           this@matter.manips.substance.stationary(sName, oPhase);
           
           this.fEnzymeVolume = fEnzymeVolume;
           % Rate constants
           load('lib\+components\+matter\+CROP\+components\Parameter.mat', 'tReaction');
           load('lib\+components\+matter\+CROP\+components\pH_model.mat', 'tpH_Diagram');

           % Note that Schalz wrongly assumed that reaction D should no
           % longer occur. But just because we switched the modelling from
           % NH4OH to NH4 the reaction still exists!
           tReaction.D.fk_f = 0.000045;
           % See equation 4-21 from MA of Yilun Sun
           tReaction.D.fk_r = tReaction.D.fk_f / (1.8*10^-5);
           
           this.tParameter = tReaction;
           
           % The concentration of enzyme E and inhibitor I, unit: mol/l
           % Attention: these reactants are not modelled as a matter in
           % the matter table in phases
           this.afConcentration = zeros(31,1);
           % Enzyme reaction A
           this.afConcentration(9)  = 5.06; % A.E
           this.afConcentration(11) = 4.3e-5; % A.I
           this.afConcentration(12) = 0; % A.EI
           
           % Enzyme reaction B
           this.afConcentration(16) = 5.0126;
           this.afConcentration(18) = 0.1142;
           this.afConcentration(19) = 0;
           
           % Enzyme reaction C
           this.afConcentration(25) = 5;
           this.afConcentration(27) = 2.34e-4;
           this.afConcentration(28) = 0;

           % The pH activity model which is created in the class file
           % "Launch_Sim.m" in the folder "+execution"
           this.tpH_Diagram = tpH_Diagram;
           
           this.opH_Manip = this.oPhase.oStore.oContainer.toStores.CROP_Tank.toPhases.Aeration.toManips.substance;
           
           this.afPreviousReactionRates = zeros(33,1);
           this.afPreviousFlowRates = zeros(1, this.oMT.iSubstances);
           
            this.setTimeStep = this.oTimer.bind(@(~) this.registerPhaseUpdate(), 0, struct(...
                'sMethod', 'update', ...
                'sDescription', 'The .update method of the crop enzym reactions', ...
                'oSrcObj', this ...
            ));
        
        
            % *********************************************************************
            % Internal matrix K_inter^A which represents the relationship between the 
            % reaction rates of the enzyme-related reactants in reaction A and the vector v^A
            tmK_inter.A = ...
                [-1  0 -1  0  0  0  1  0;...
                  1 -1  0 -1  0  0  0  0;...
                  0  0 -1 -1  0  0  0  0;...
                  0  0  1  0 -1  0  0  1;...
                  0  0  0  1  1 -1  0  0;...
                  0  1  0  0  0  0 -1  0;...
                  0  0  0  0  0  1  0 -1];

            % Internal matrix K_inter^B which represents the relationship between the 
            % reaction rates of the enzyme-related reactants in reaction B and the vector v^B
            tmK_inter.B = ...
                [-1  0 -1  0  0  0  1  0 -1  0  0  0  0;...
                  1 -1  0 -1  0  0  0  0  0  0  0  0  0;...
                  0  0 -1 -1  0  0  0  0  0  0  0 -1  0;...
                  0  0  1  0 -1  0  0  1  0 -1  0  0  0;...
                  0  0  0  1  1 -1  0  0  0  0  0  0  0;...
                  0  1  0  0  0  0 -1  0  0  0  1  0  0;...
                  0  0  0  0  0  1  0 -1  0  0  0  0  1;...
                  0  0  0  0  0  0  0  0  1  0 -1 -1  0;...
                  0  0  0  0  0  0  0  0  0  1  0  1 -1];

            % Internal matrix K_inter^C which represents the relationship between the 
            % reaction rates of the enzyme-related reactants in reaction C and the vector v^C
            tmK_inter.C = tmK_inter.A;

            % The base reactions occuring here are:
            % CH4N2O + H2O      -> CO2 + 2 NH3          Reaction A
            % NH4   + 1.5 O2    -> NO2 + H2O +2 H+      Reaction B I
            % NH3   + 1.5 O2    -> NO2 + H2O +  H+      Reaction B II
            % NO2   + 0.5 O2    -> NO3                  Reaction C
            % NH3   + H2O       -> NH4 + OH-            Reaction D
            
            % External matrix K_exter^A which represents the relationship between the 
            % reaction rates of the external reactants and the vector v^A
            tmK_exter.A = ...
                [0 -1  0  0  0 -1  0  0;...
                 0  1  0  0  0  1  0  0;...
                 0  0  0  0  0  0  0  0;...
                -1  0  0  0 -1  0  0  0;...
                 0  0  0  0  0  0  2  2;...
                 0  0  0  0  0  0  0  0;...
                 0  0  0  0  0  0  0  0;...
                 0  0  0  0  0  0  0  0];

            % External matrix K_exter^B which represents the relationship between the 
            % reaction rates of the external reactants and the vector v^B
            tmK_exter.B = ...
                [0  1   0  0  0  1   0  0  0  0  1   0  1;...
                 0  0   0  0  0  0   0  0  0  0  0   0  0;...
                 0 -1.5 0  0  0 -1.5 0  0  0  0 -1.5 0 -1.5;...
                 0  0   0  0  0  0   0  0  0  0  0   0  0;...
                 0  0   0  0  0  0   0  0 -1 -1  0   0  0;...
                -1  0   0  0 -1  0   0  0  0  0  0   0  0;...
                 0  0   0  0  0  0   1  1  0  0  0   0  0;...
                 0  0   0  0  0  0   0  0  0  0  0   0  0];

            % The base reactions occuring 
            % External matrix K_exter^C which represents the relationship between the 
            % reaction rates of the external reactants and the vector v^C
            tmK_exter.C = ...
                [0 0 0 0 0 0 0 0;...
                0 0 0 0 0 0 0 0;...
                0 -0.5 0 0 0 -0.5 0 0;...
                0 0 0 0 0 0 0 0;...
                0 0 0 0 0 0 0 0;...
                0 0 0 0 0 0 0 0;...
                -1 0 0 0 -1 0 0 0;...
                0 0 0 0 0 0 1 1];

            % External matrix K_exter^D which represents the relationship between the 
            % reaction rates of the external reactants and v^D
            tmK_exter.D = [-1 0 0 0 -1 1 0 0]';
            
            % Integration of the above matrices into a matrix K_tot as is described in
            % section 4.2.3.5 in Sun's thesis.
            this.mK_total = [tmK_exter.A tmK_exter.B tmK_exter.C tmK_exter.D;...
                tmK_inter.A zeros(7,22);...
                zeros(9,8) tmK_inter.B zeros(9,9);...
                zeros(7,21) tmK_inter.C zeros(7,1)];
            
            % See Eq 4-8 to 4-10 from Suns MA combined with the base chemical
            % reactions. Basically the reactions which include H+ as term
            % in 4-10 produce H+ and the exponent is the stochiometric
            % factor from the chemical reaction equation. The 8 is simply
            % the number of entries the previous reaction A includes
            % NH4   + 1.5 O2    -> NO2 + H2O +2 H+      Reaction B I
            % NH3   + 1.5 O2    -> NO2 + H2O +  H+      Reaction B II
            this.mK_total(32, 8+2)  = 2;
            this.mK_total(32, 8+6)  = 2;
            this.mK_total(32, 8+11) = 1;
            this.mK_total(32, 8+13) = 1;
            
            % See Eq 4-20 and comment above for reaction B, this reaction
            % produces OH-
            this.mK_total(33, 8+13+8+1)  = 1;
            
            this.setTimeStep(inf, true);
            % Define rate of change function for ODE solver.
            this.hCalculateChangeRate = @(t, m) this.DiffEquations(m, t);
        end
        
    end
    methods( Access = protected)
        
        function update(this)
            % The time step of the manipulator in each loop
            this.fElapsedTime = this.oTimer.fTime - this.fLastExec;
            
            
            %% gather current substance concentrations
            % Call the current mass of substances in the phase "FlowPhase"
            fFlowRates          = this.oPhase.oStore.oContainer.toBranches.Tank_to_BioFilter.fFlowRate;
            afFlowRates         = fFlowRates .* this.oPhase.oStore.oContainer.toBranches.Tank_to_BioFilter.aoFlows(1).arPartialMass;

            if fFlowRates == 0
                afPartialFlowRates = zeros(1, this.oMT.iSubstances);
                update@matter.manips.substance.stationary(this, afPartialFlowRates);
                this.oPhase.oStore.toProcsP2P.BiofilterIn.setFlowRate(afPartialFlowRates);
                this.oPhase.oStore.toProcsP2P.BiofilterOut.setFlowRate(afPartialFlowRates);
                return
            elseif all(abs(((this.afPreviousFlowRates - afFlowRates) ./ (this.afPreviousFlowRates + 1e-8))) < 0.025) && (abs(this.fpH - this.opH_Manip.fpH) < 0.25) && ~((this.fElapsedTime - this.fStep) > -1)
                % composition did not change sufficiently to warant
                % recalculation
                return
            end
            fDensity            = this.oPhase.oStore.oContainer.toBranches.Tank_to_BioFilter.aoFlows(1).getDensity;
            fVolumetricFlowRate = (fFlowRates / fDensity) * 1000; % l/s
            this.afPreviousFlowRates = afFlowRates;
            
            %% call the current pH value from the pHManipulator
            this.fpH = this.opH_Manip.fpH;
            
            % The molar mass of the substances and their sequences in the
            % matter table
            afMolMass  = this.oPhase.oMT.afMolarMass;
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            % ***********************************************************
              
            % Calculate the current concentration of all relevant
            % substances. The recalculation takes place
            % because the concentration saved in the variable
            % "afConcentration" in the step before would probably be changed
            % and is thus not same with the actual
            % concentration in the solution.
            
            % All internal reactants (ES,ESI,EP,EPI) use the mass in "BioPhase", 
            % All external reactants use the mass in "FlowPhase".
            if fFlowRates == 0
                afVHABConcentration    = zeros(1, this.oMT.iSubstances);
            else
                afVHABConcentration    = (afFlowRates ./ afMolMass) / fVolumetricFlowRate;
            end
            % An alternative option to calculate the concentrations would
            % be to use the tank solution phases. We do not use this here
            % as the other option is more modular. The results however are
            % similar
%             oTankSolution = this.oPhase.oStore.oContainer.toStores.CROP_Tank.toPhases.TankSolution;
%             afVHABConcentration = (oTankSolution.afMass  ./ afMolMass ) ./ (oTankSolution.fVolume * 1000);
            
            % Please note, that this conversion is VERY VERY stupid to do.
            % But i currently do not have the time to fix the stuff the
            % students did here. The code would be much shorter and faster
            % withour this...
            this.afConcentration(1) =       afVHABConcentration(tiN2I.H2O);
            this.afConcentration(2) =       afVHABConcentration(tiN2I.CO2);
            this.afConcentration(3) =       afVHABConcentration(tiN2I.O2);
            
            % Calculate the concentrations of the internal reactants, the
            % enzym complexes since they are not included in the mass
            % reaction rate conversion below. These internal reactants are
            % from 9 : 31. 
            this.afConcentration(9 : 31)    = this.afConcentration(9 : 31) + this.afPreviousReactionRates(9 : 31) .* this.fElapsedTime;
            this.afConcentration(14 : 15)   = this.afConcentration(14 : 15);
            
            % We have to subtract the enzym substrate complex from the substrate concentrations
            this.afConcentration(4)  =      afVHABConcentration(tiN2I.CH4N2O)   - this.afConcentration(10) - this.afConcentration(13); 
            this.afConcentration(5)  =      afVHABConcentration(tiN2I.NH3)      - this.afConcentration(23) - this.afConcentration(24) - 2 * (this.afConcentration(14) + this.afConcentration(15));
            this.afConcentration(6)  =      afVHABConcentration(tiN2I.NH4)      - this.afConcentration(17) - this.afConcentration(20); 
            this.afConcentration(7)  =      afVHABConcentration(tiN2I.NO2)      - this.afConcentration(21) - this.afConcentration(22) - this.afConcentration(26) - this.afConcentration(29);
            this.afConcentration(8)  =      afVHABConcentration(tiN2I.NO3)      - this.afConcentration(30) - this.afConcentration(31);
            this.afConcentration(32) =          10^( - ( this.fpH ));
            this.afConcentration(33) =          10^( - ( 14 -  this.fpH ));

            %% temperature effect
            % Add the effect of temperature to the rate constants which is
            % described in section 4.2.3.7 in Sun's thesis. NOTE
            % TEMPERATURE IS IN °C FOR THIS!
            this.tParameter_modified_T = components.matter.CROP.tools.Reaction_Factor_T(this.tParameter, this.oPhase.fTemperature - 273.15);
            
            % Add the effect of the pH value to the rate constants which is
            % described in section 4.2.3.8 in Sun's thesis with the function
            % "Reaction_Factor_pH.m"
            this.tPmrCurrent = components.matter.CROP.tools.Reaction_Factor_pH(this.tParameter_modified_T, this.tpH_Diagram, this.fpH);
            
            %% DiffEquations
            % The basic enzyme kinetics is implemented in the function "DiffEquations"
            % which is described from section 4.2.3.1 to section 4.2.3.5 in
            % Sun's thesis. Unit of afReactionRate is mol/(L*s). Note that
            % the reaction system from Sun was adapted to use ions which
            % required the addition of H+ and OH- as well as the adjustment
            % of the produced water for reaction rate 14, which represents 
            % equation NH4   + 1.5 O2    -> NO2 + H2O +2 H+
            % In the non ion case this reaction produces 2 mol of water
            % The matlab ode45 solver is used to achieve a stable solution
            
            % Use time step of the crop system as time step for the
            % differential equation system
            this.fStep = this.oPhase.oStore.oContainer.fTimeStep;
            fStepBeginTime = this.oTimer.fTime;
            fStepEndTime   = this.oTimer.fTime + this.fStep;
            
            [~, afSolutionConcentrations] = ode45(this.hCalculateChangeRate, [fStepBeginTime, fStepEndTime], this.afConcentration, this.tOdeOptions);

            afConcentrationDifference = (afSolutionConcentrations(end,:)' - this.afConcentration);

            afReactionRate = afConcentrationDifference ./ this.fStep;

            this.setTimeStep(this.fStep, true);
            
            % ****************************************************************
            % Store the current reaction rates to calculate the new
            % concentrations of internal reactants for the next step
            this.afPreviousReactionRates = afReactionRate;
            
            %% flow rates
            % Here the molar reaction rates of all reactants are converted
            % to mass reaction rates, because the manipulator uses mass of
            % a matter for calculation but not the concentration.
            %
            % The decision which volume should be used here is not trivial.
            % The relation is basically the volume available for the
            % microbes, which is considered to be the biophase volume here.
            % It would also be possible to use the volumetric flowrate, but
            % in that case the speed of the reaction would depend on the
            % volumetric flowrate (with higher flowrate higher conversion)
            % which is not realisitic:
            
            % The base reactions occuring here are:
            % CH4N2O + H2O      -> CO2 + 2 NH3
            % NH3   + H2O       -> NH4 + OH-
            % NH4   + 1.5 O2    -> NO2 + H2O +2 H+
            % NO2   + 0.5 O2    -> NO3
            %
            % We now have to translate the reaction flowrates into the
            % manipulator flowrates, which is a bit tricky as the reaction
            % includes reactions to the different enzyme complexes which
            % are not represented in V-HAB
            % 1:H2O, 2:CO2, 3:O2, 4:CH4N2O, 5:NH3, 6:NH4, 7:NO2, 8:NO3,
            % 9:A.E, 10:A.ES, 11:A.I, 12:A.EI, 13:A.ESI, 14:A.EP, 15:A.EPI,
            % 16:B.E, 17:B.ES1, 18:B.I, 19:B.EI, 20:B.ESI1, 21:B.EP, 22:B.EPI,
            % 23:B.ES2, 24:B.ESI2, 25:C.E, 26:C.ES, 27:C.I, 28:C.EI, 29:C.ESI, 
            % 30:C.EP, 31:C.EPI, 32: H+, 33: OH-
            afPartialFlowRatesEnzymeReactions = zeros(1, this.oPhase.oMT.iSubstances);
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.CH4N2O)	= (afMolMass(tiN2I.CH4N2O)  * this.fEnzymeVolume)  * (afReactionRate(4) + afReactionRate(10) + afReactionRate(13));
            % The reaction rates for 14 ((NH3)2 A.EP) and 15 ((NH3)2 A.EPI)
            % must be multiplied with 2 since they contain 2 molecules of
            % NH3!
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.NH3)       = (afMolMass(tiN2I.NH3)     * this.fEnzymeVolume)  * (afReactionRate(5) + afReactionRate(23) + afReactionRate(24) + 2 * (afReactionRate(14) + afReactionRate(15)));
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.NH4)   	= (afMolMass(tiN2I.NH4)     * this.fEnzymeVolume)  * (afReactionRate(6) + afReactionRate(17) + afReactionRate(20));
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.NO2)   	= (afMolMass(tiN2I.NO2)     * this.fEnzymeVolume)  * (afReactionRate(7) + afReactionRate(21) + afReactionRate(22) + afReactionRate(26) + afReactionRate(29));
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.NO3)   	= (afMolMass(tiN2I.NO3)     * this.fEnzymeVolume)  * (afReactionRate(8) + afReactionRate(30) + afReactionRate(31));
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.H2O)   	= (afMolMass(tiN2I.H2O)     * this.fEnzymeVolume)  *  afReactionRate(1);
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.CO2)   	= (afMolMass(tiN2I.CO2)     * this.fEnzymeVolume)  *  afReactionRate(2);
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.O2)        = (afMolMass(tiN2I.O2)      * this.fEnzymeVolume)  *  afReactionRate(3);
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.Hplus)     = (afMolMass(tiN2I.Hplus) 	* this.fEnzymeVolume)  *  afReactionRate(32);
            afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.OH)        = (afMolMass(tiN2I.OH)      * this.fEnzymeVolume)  *  afReactionRate(33);
            
            fError = sum(afPartialFlowRatesEnzymeReactions);
            
            % It may seem strange that this is necessary, but it is
            % required to the slight differences and rounding errors in the
            % molar masses. Even if the molar reaction rates match almost
            % exactly (error < 1e-14) the mass error is on the scale of
            % 2e-8 kg/s due to the differences in the molar masses. The
            % molar masses also vary slightly due to the energy mass
            % relation in chemical reactions, so this is not purely
            % rounding error
            if fError < 1e-6
                fPositiveFlowRate = sum(afPartialFlowRatesEnzymeReactions(afPartialFlowRatesEnzymeReactions > 0));
                fNegativeFlowRate = abs(sum(afPartialFlowRatesEnzymeReactions(afPartialFlowRatesEnzymeReactions < 0)));
                
                if fPositiveFlowRate > fNegativeFlowRate
                    % reduce the positive flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = afPartialFlowRatesEnzymeReactions(afPartialFlowRatesEnzymeReactions > 0)./fPositiveFlowRate;
                    
                    afPartialFlowRatesEnzymeReactions(afPartialFlowRatesEnzymeReactions > 0) = afPartialFlowRatesEnzymeReactions(afPartialFlowRatesEnzymeReactions > 0) - fDifference .* arRatios;
                else
                    % reduce the negative flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = abs(afPartialFlowRatesEnzymeReactions(afPartialFlowRatesEnzymeReactions < 0)./fNegativeFlowRate);
                    
                    afPartialFlowRatesEnzymeReactions(afPartialFlowRatesEnzymeReactions < 0) = afPartialFlowRatesEnzymeReactions(afPartialFlowRatesEnzymeReactions < 0) - fDifference .* arRatios;
                end
            elseif fError > 1e-6
            %% For larger errors the manipulator will throw an error
            
                if abs(sum(afReactionRate' .* this.afMolarSumC)) > 1e-10
                    keyboard()
                elseif abs(sum(afReactionRate' .* this.afMolarSumH)) > 1e-10
                    keyboard()
                elseif abs(sum(afReactionRate' .* this.afMolarSumN)) > 1e-10
                    keyboard()
                elseif abs(sum(afReactionRate' .* this.afMolarSumO)) > 1e-10
                    keyboard()
                else
                    % If none of the breaks above was reached, then the
                    % molar sum of the manipulator is correct and the
                    % difference is likely due to rounding errors in the
                    % molar masses.
                    keyboard()
                end
            end
            
            %% pass back flow rates
            update@matter.manips.substance.stationary(this, afPartialFlowRatesEnzymeReactions);
            
            % Negative mass flows in the manip means the substance is
            % consumed and must be added to the phase. Since the P2Ps are
            % both defined as Filter to Flow, a negative flowrate results
            % in an inflow into the filter!
            abInFlow = afPartialFlowRatesEnzymeReactions < 0;
            afInP2PFlows    = zeros(1, this.oMT.iSubstances);
            afInP2PFlows(abInFlow) = afPartialFlowRatesEnzymeReactions(abInFlow);
            
            this.oPhase.oStore.toProcsP2P.BiofilterIn.setFlowRate(afInP2PFlows);
            
            afOutP2PFlows   =  zeros(1, this.oMT.iSubstances);
            afOutP2PFlows(~abInFlow) = afPartialFlowRatesEnzymeReactions(~abInFlow);
            
            this.oPhase.oStore.toProcsP2P.BiofilterOut.setFlowRate(afOutP2PFlows);
            
            afO2P2PFlows    = zeros(1, this.oMT.iSubstances);
            afO2P2PFlows(this.oMT.tiN2I.O2) = - afPartialFlowRatesEnzymeReactions(this.oMT.tiN2I.O2);
            this.oPhase.oStore.oContainer.toStores.CROP_Tank.toProcsP2P.O2_to_TankSolution.setFlowRate(afO2P2PFlows);
            

        end

        function afReactionRate = DiffEquations(this, afConcentration, ~)
            % The basic enzyme kinetics in the manipulator "Enzyme Reactions" 
            % (the orange block in Fig.4-7 in Sun's thesis)
            
            tPmr = this.tPmrCurrent;
            
            % Concentrations of the external reactants
            fCon_CH4N2O             = afConcentration(4);
            fCon_NH3                = afConcentration(5);
            fCon_NH4                = afConcentration(6);
            fCon_NO2                = afConcentration(7);
            fCon_NO3                = afConcentration(8);
            fCurrentH               = afConcentration(32);
            fCurrentOH              = afConcentration(33);
            
            % Struct C_inter^A containing the internal reactants in enzyme reaction A
            tfCon_A_inter.E         = afConcentration(9);
            tfCon_A_inter.ES        = afConcentration(10);
            tfCon_A_inter.I         = afConcentration(11);
            tfCon_A_inter.EI        = afConcentration(12);
            tfCon_A_inter.ESI       = afConcentration(13);
            tfCon_A_inter.EP        = afConcentration(14);
            tfCon_A_inter.EPI       = afConcentration(15);

            % Struct C_inter^B containing the internal reactants in enzyme reaction B
            tfCon_B_inter.E         = afConcentration(16);
            tfCon_B_inter.ES1       = afConcentration(17);
            tfCon_B_inter.I         = afConcentration(18);
            tfCon_B_inter.EI        = afConcentration(19);
            tfCon_B_inter.ESI1      = afConcentration(20);
            tfCon_B_inter.EP        = afConcentration(21);
            tfCon_B_inter.EPI       = afConcentration(22);
            tfCon_B_inter.ES2       = afConcentration(30-7);
            tfCon_B_inter.ESI2      = afConcentration(31-7);

            % Struct C_inter^C containing the internal reactants in enzyme reaction C
            tfCon_C_inter.E         = afConcentration(23+2);
            tfCon_C_inter.ES        = afConcentration(24+2);
            tfCon_C_inter.I         = afConcentration(25+2);
            tfCon_C_inter.EI        = afConcentration(26+2);
            tfCon_C_inter.ESI       = afConcentration(27+2);
            tfCon_C_inter.EP        = afConcentration(28+2);
            tfCon_C_inter.EPI       = afConcentration(29+2);

            % Reaction rate vectors of reaction A, B, C, D (v^A, v^B, v^C, v^D in the thesis)
            % Reaction rate vectors of reaction A (v^A)
            afFluxA(1)  =  tPmr.A.a.fk_f * tfCon_A_inter.E  * fCon_CH4N2O       -       tPmr.A.a.fk_r * tfCon_A_inter.ES;
            afFluxA(3)  =  tPmr.A.c.fk_f * tfCon_A_inter.E  * tfCon_A_inter.I   -       tPmr.A.c.fk_r * tfCon_A_inter.EI;
            afFluxA(5)  =  tPmr.A.e.fk_f * tfCon_A_inter.EI * fCon_CH4N2O       -       tPmr.A.e.fk_r * tfCon_A_inter.ESI;
            afFluxA(2)  =  tPmr.A.b.fk_f * tfCon_A_inter.ES                     -       tPmr.A.b.fk_r * tfCon_A_inter.EP;
            afFluxA(7)  =  tPmr.A.g.fk_f * tfCon_A_inter.EP                     -       tPmr.A.g.fk_r * tfCon_A_inter.E   * fCon_NH3 * fCon_NH3;     %![NH3]^2
            afFluxA(4)  =  tPmr.A.d.fk_f * tfCon_A_inter.ES * tfCon_A_inter.I   -       tPmr.A.d.fk_r * tfCon_A_inter.ESI;
            afFluxA(6)  =  tPmr.A.f.fk_f * tfCon_A_inter.ESI                    -       tPmr.A.f.fk_r * tfCon_A_inter.EPI;
            afFluxA(8)  =  tPmr.A.h.fk_f * tfCon_A_inter.EPI                    -       tPmr.A.h.fk_r * tfCon_A_inter.EI  * fCon_NH3 * fCon_NH3;   %![NH3]^2

            % NH3 + H2O -> NH4+ + OH-
            fFluxD      =  tPmr.D.fk_f   * fCon_NH3                             -       tPmr.D.fk_r   * fCon_NH4 * fCurrentOH;

            % Reaction rate vectors of reaction B (v^B)
            afFluxB(1)  =  tPmr.B.a.fk_f * tfCon_B_inter.E  * fCon_NH4          -       tPmr.B.a.fk_r * tfCon_B_inter.ES1;                
            afFluxB(3)  =  tPmr.B.c.fk_f * tfCon_B_inter.E  * tfCon_B_inter.I   -       tPmr.B.c.fk_r * tfCon_B_inter.EI;
            afFluxB(5)  =  tPmr.B.e.fk_f * tfCon_B_inter.EI * fCon_NH4          -       tPmr.B.e.fk_r * tfCon_B_inter.ESI1;               
            afFluxB(2)  =  tPmr.B.b.fk_f * tfCon_B_inter.ES1                    -       tPmr.B.b.fk_r * tfCon_B_inter.EP  * fCurrentH^2;  % ! added the influence of H+
            afFluxB(7)  =  tPmr.B.g.fk_f * tfCon_B_inter.EP                     -       tPmr.B.g.fk_r * tfCon_B_inter.E   * fCon_NO2;
            afFluxB(4)  =  tPmr.B.d.fk_f * tfCon_B_inter.ES1 * tfCon_B_inter.I  -       tPmr.B.d.fk_r * tfCon_B_inter.ESI1;
            afFluxB(6)  =  tPmr.B.f.fk_f * tfCon_B_inter.ESI1                   -       tPmr.B.f.fk_r * tfCon_B_inter.EPI * fCurrentH^2;  % ! added the influence of H+
            afFluxB(8)  =  tPmr.B.h.fk_f * tfCon_B_inter.EPI                    -       tPmr.B.h.fk_r * tfCon_B_inter.EI  * fCon_NO2;

            afFluxB(9)  =  tPmr.B.a.fk_f * tfCon_B_inter.E  * fCon_NH3          -       tPmr.B.a.fk_r * tfCon_B_inter.ES2;                
            afFluxB(10) =  tPmr.B.e.fk_f * tfCon_B_inter.EI * fCon_NH3          -       tPmr.B.e.fk_r * tfCon_B_inter.ESI2;               
            afFluxB(11) =  tPmr.B.b.fk_f * tfCon_B_inter.ES2                    -       tPmr.B.b.fk_r * tfCon_B_inter.EP  * fCurrentH;  % ! added the influence of H+
            afFluxB(12) =  tPmr.B.d.fk_f * tfCon_B_inter.ES2 * tfCon_B_inter.I  -       tPmr.B.d.fk_r * tfCon_B_inter.ESI2;
            afFluxB(13) =  tPmr.B.f.fk_f * tfCon_B_inter.ESI2                   -       tPmr.B.f.fk_r * tfCon_B_inter.EPI * fCurrentH;  % ! added the influence of H+


            % Reaction rate vectors of reaction C (v^C)
            afFluxC(1)  =  tPmr.C.a.fk_f * tfCon_C_inter.E  * fCon_NO2          -       tPmr.C.a.fk_r * tfCon_C_inter.ES;
            afFluxC(3)  =  tPmr.C.c.fk_f * tfCon_C_inter.E  * tfCon_C_inter.I   -       tPmr.C.c.fk_r * tfCon_C_inter.EI;
            afFluxC(5)  =  tPmr.C.e.fk_f * tfCon_C_inter.EI * fCon_NO2          -       tPmr.C.e.fk_r * tfCon_C_inter.ESI;
            afFluxC(2)  =  tPmr.C.b.fk_f * tfCon_C_inter.ES                     -       tPmr.C.b.fk_r * tfCon_C_inter.EP; 
            afFluxC(7)  =  tPmr.C.g.fk_f * tfCon_C_inter.EP                     -       tPmr.C.g.fk_r * tfCon_C_inter.E   * fCon_NO3;
            afFluxC(4)  =  tPmr.C.d.fk_f * tfCon_C_inter.ES * tfCon_C_inter.I   -       tPmr.C.d.fk_r * tfCon_C_inter.ESI;
            afFluxC(6)  =  tPmr.C.f.fk_f * tfCon_C_inter.ESI                    -       tPmr.C.f.fk_r * tfCon_C_inter.EPI;
            afFluxC(8)  =  tPmr.C.h.fk_f * tfCon_C_inter.EPI                    -       tPmr.C.h.fk_r * tfCon_C_inter.EI  * fCon_NO3;

            % Integration of the reaction rate vectors
            afFlux_total = [afFluxA afFluxB afFluxC fFluxD]';

            % Calculation of the reaction rate vector of all reactants as is described
            % in Eq.(4-23) in section 4.2.3.5 in Sun's thesis.
            afReactionRate = this.mK_total * afFlux_total;
        end
        
        function registerPhaseUpdate(this)
            this.oPhase.registerUpdate();
        end
    end
end