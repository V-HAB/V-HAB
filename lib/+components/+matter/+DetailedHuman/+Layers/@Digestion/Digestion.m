classdef Digestion < vsys
    
    properties (SetAccess = protected, GetAccess = public)
        
        fDigestedMassFlowCarbohydrates;
        fDigestedMassFlowProteins;
        fDigestedMassFlowFat;
            
        requestFood;
        
        % This can have values between 0 and 5, for 0 the human has
        % no need to defecat, for 5 immediate defecation occurs regardless
        % of schedule
        fDefecationNeed = 0;
        
        tfSmallIntestineFoodTimer;
        
        fLastUpdateTime = 0;
        
        tfFlowRates;
        txFoodWater;
        
        arPassThroughRatios;
        
        hCalculateChangeRate;
        tOdeOptions = odeset('RelTol', 1e-1, 'AbsTol', 1e-2);
        tfInternalFlowRates;
        fInternalTimeStep = 5;
    end
    
    properties (Constant)
    
        % The parameters for the digestion system had to be adjusted to
        % match the new implementation. E.g. there is no longer a
        % difference between the ingested and secreted water and drinking
        % water also passes through the digestion system. The original
        % equations are correct, but also a bit instable, in the regard
        % that they were simply adjusted till they matched the data, but
        % that data was not actually used in their definition, making it
        % difficult to adjust them to new conditions. Therefore the
        % following parameters were defined base on BVAD values to directly
        % sset requirements to the system:
        fAverageDailyFecesWaterContent = 0.091; % BVAD Table 4.38
        fAverageDailyFecesSolidContent = 0.032; % BVAD Table 4.38
        % According to BVAD Equation 4.1 Feces can be modelled as
        % C42H69O26N5. This represents 5 mol of protein (C3H7NO2) 
        % But the other values cannot be achieved directly by mixing
        % glucose and fat. BVAD also states that there is a lot of
        % variability in the composition depending on diet. In the model,
        % dietary fiber is currently not digested and amounts to 
        % According to "MASS BALANCES FOR A BIOLOGICAL LIFE SUPPORT SYSTEM
        % SIMULATION MODEL", Tyler Volk and John D. Rummel, 1987. 
        % Feces composition is assumed to 50% protein, 25%
        % carbohydrates and 25% fat instead.  This results in the following
        % chemical reaction assumed in the simple human model:            
        % 5 C4H5ON + C6H12O6 + C16H32O2 = C42H69O13N5 (feces solids composition)
        % Since here fats are modelled as C51H98O6 we only use one third of
        % the fats:
        % 5 C4H5ON + C6H12O6 + 1/3 C51H98O6 = C43 H69.67 O13 N5
        % Still that is quite close to the BVAD value and therefore used
        % from here on. The overall molar mass for the composite is then
        % (oMT.afMolarMass(oMT.tiN2I.C6H12O6) + 1/3 * oMT.afMolarMass(oMT.tiN2I.C51H98O6) +  5 * oMT.afMolarMass(oMT.tiN2I.C3H7NO2))
        % = 0.8947 kg/mol 
        % Therefore the mass ratios are:
        % 0.4979 for Proteins, 0.2014 for Glucose and 0.3007 for Fats
        trAverageFecesMassRatios = struct('Protein', 0.4979, 'Gluocose', 0.2014, 'Fat', 0.3007);
        
        
        
    	tfMouthParameters           = struct(   'fMinimalSalivaFlow',               0.35/60000,...  % [kg/s]
                                                'fMaximalSalivaFlow',               4/60000,...     % [kg/s]
                                                'fMinimalMassTransferToStomach',	5/60000,...     % [kg/s]
                                                'fMaximalMassTransferToStomach',  	10/60000,...    % [kg/s]
                                                'fMinimalNaConcentrationSecretion',	0.1e-3,...      % [kg (Na) / kg (H2O)]
                                                'fMaximalNaConcentrationSecretion',	1.2e-3);        % [kg (Na) / kg (H2O)]
         
    	tfStomachParameters         = struct(   'fMinimalSecretionFlow',        	1/60000,...     % [kg/s]
                                                'fMaximalSecretionFlow',           	30/60000,...    % [kg/s]
                                                'fMinimalOutputMassFlow',           5/60000,...     % [kg/s]
                                                'fMaximalOutputMassFlow',           10/60000,...    % [kg/s]
                                                'fMinimalNaConcentrationSecretion', 0.1e-3,...      % [kg (Na) / kg (H2O)]
                                                'fMaximalNaConcentrationSecretion',	1.2e-3,...      % [kg (Na) / kg (H2O)]
                                                'fMaximalContent',                  1);             % [kg]
                                
    	tfDuodenumParameters        = struct(   'fMinimalSecretionFlow',        	1.7/60000,... 	% [kg/s]
                                                'fMaximalSecretionFlow',           	8.5/60000,...  	% [kg/s]
                                                'fMinimalOutputMassFlow',           1.35/60000,... 	% [kg/s]
                                                'fMaximalOutputMassFlow',           17/60000,...    % [kg/s]
                                                'fMinimalNaConcentrationSecretion',	2.9e-3,...      % [kg (Na) / kg (H2O)]
                                                'fMaximalNaConcentrationSecretion',	2.95e-3,...     % [kg (Na) / kg (H2O)]
                                                'fMaximalContent',                  0.4,...         % [kg]
                                                'fCarbohydrateAbsorptionRate',     	1.5/60000,...     % [kg/s]
                                                'fFatAbsorptionRate',               0.9/60000,...  	% [kg/s]
                                                'fProteinAbsorptionRate',           0.6/60000,...  	% [kg/s]
                                                'fSodiumAbsorptionRate',            0.9/60000,... 	% [kg/s]
                                                'fWaterAbsorptionRate',             2/60000,... 	% [kg/s]
                                                'fTimeConstant',                    600);           % [s]
                                            
    	tfJejunumParameters         = struct(   'fMinimalSecretionFlow',        	1/60000,... 	% [kg/s]
                                                'fMaximalSecretionFlow',           	5/60000,...  	% [kg/s]
                                                'fMinimalOutputMassFlow',           1.35/60000,... 	% [kg/s]
                                                'fMaximalOutputMassFlow',           17/60000,...    % [kg/s]
                                                'fMinimalNaConcentrationSecretion',	0.23e-3,...     % [kg (Na) / kg (H2O)]
                                                'fMaximalNaConcentrationSecretion',	0.46e-3,...     % [kg (Na) / kg (H2O)]
                                                'fMaximalContent',                  1.1,...         % [kg]
                                                'fCarbohydrateAbsorptionRate',     	1.4/60000,...     % [kg/s]
                                                'fFatAbsorptionRate',               0.9/60000,...  	% [kg/s]
                                                'fProteinAbsorptionRate',           0.6/60000,...  	% [kg/s]
                                                'fSodiumAbsorptionRate',            0.9/60000,... 	% [kg/s]
                                                'fWaterAbsorptionRate',             1.5/60000,... 	% [kg/s]
                                                'fTimeConstant',                    900);           % [s]
                                            
    	tfIleumParameters           = struct(   'fMinimalSecretionFlow',        	0.8/60000,... 	% [kg/s]
                                                'fMaximalSecretionFlow',           	4/60000,...  	% [kg/s]
                                                'fMinimalOutputMassFlow',           1.35/60000,... 	% [kg/s]
                                                'fMaximalOutputMassFlow',           16/60000,...    % [kg/s]
                                                'fMinimalNaConcentrationSecretion',	0.185e-3,...   	% [kg (Na) / kg (H2O)]
                                                'fMaximalNaConcentrationSecretion',	0.37e-3,...     % [kg (Na) / kg (H2O)]
                                                'fMaximalContent',                  1.1,...         % [kg]
                                                'fCarbohydrateAbsorptionRate',     	1.5/60000,...   % [kg/s]
                                                'fFatAbsorptionRate',               1/60000,...  	% [kg/s]
                                                'fProteinAbsorptionRate',           0.4/60000,...  	% [kg/s]
                                                'fSodiumAbsorptionRate',            0.9/60000,... 	% [kg/s]
                                                'fWaterAbsorptionRate',             2/60000,... 	% [kg/s]
                                                'fTimeConstant',                    900);           % [s]
                                            
    	tfLargeIntestineParameters  = struct(   'fMinimalSecretionFlow',        	0.1/60000,... 	% [kg/s]
                                                'fMaximalSecretionFlow',           	0.5/60000,...  	% [kg/s]
                                                'fMinimalOutputMassFlow',           0.15/60000,... 	% [kg/s]
                                                'fMaximalOutputMassFlow',           1/60000,...   	% [kg/s]
                                                'fMinimalNaConcentrationSecretion',	0.028e-3,...    % [kg (Na) / kg (H2O)]
                                                'fMaximalNaConcentrationSecretion',	0.046e-3,...    % [kg (Na) / kg (H2O)]
                                                'fMaximalContent',                  2,...           % [kg]
                                                'fSodiumAbsorptionRate',            0.5/60000,... 	% [kg/s]
                                                'fWaterAbsorptionRate',             2/60000,... 	% [kg/s]
                                                'fTimeConstant',                    18000);        	% [s]
                                            
    	tfRectumParameters          = struct(   'fMaximalContent',                  1.2);          	% [kg]
    end
    
    methods
        function this = Digestion(oParent, sName)
            this@vsys(oParent, sName, inf);
            
            this.tfFlowRates.Mouth.afSecretionMasses           = zeros(1, this.oMT.iSubstances);
            
            this.tfFlowRates.Stomach.afSecretionFlowRates      = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Stomach.afAbsorptionFlowRate      = zeros(1, this.oMT.iSubstances);
            
            this.tfFlowRates.Duodenum.afDigestionFlowRates     = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Duodenum.afAbsorptionFlowRates    = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Duodenum.afTransportFlowRates     = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Duodenum.afSecretionFlowRates     = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Duodenum.mfPastInputFlowRates     = zeros(1, this.oMT.iSubstances);
            
            this.tfFlowRates.Jejunum.afDigestionFlowRates      = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Jejunum.afAbsorptionFlowRates     = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Jejunum.afTransportFlowRates      = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Jejunum.afSecretionFlowRates      = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Jejunum.mfPastInputFlowRates      = zeros(1, this.oMT.iSubstances);
            
            this.tfFlowRates.Ileum.afDigestionFlowRates        = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Ileum.afAbsorptionFlowRates       = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Ileum.afTransportFlowRates        = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Ileum.afSecretionFlowRates        = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Ileum.mfPastInputFlowRates        = zeros(1, this.oMT.iSubstances);
            
            this.tfFlowRates.LargeIntestine.afAbsorptionFlowRates     = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.LargeIntestine.afTransportFlowRates      = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.LargeIntestine.afSecretionFlowRates      = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.LargeIntestine.mfPastInputFlowRates      = zeros(1, this.oMT.iSubstances);
            
            this.tfFlowRates.afTime                   = 0;
    
            %% (Non)Absorption Rate deduction
            % For Food, about 0.81 kg are consumed daily which consists of
            % (among other things):
            % 0.0032 kg fiber
            % 0.1316 kg of Proteins
            % 0.3949 kg of glucose
            % 0.1003 kg of fats
            % (according to the ISS food composition calculated in the
            % matter table from HDIH and BVAD values) 
            % Since fiber is not digested, it normally contributes about
            % 10% of the feces solid composition, leaving 90% for the
            % nutrients to make up. 
            % Proteins: 0.9 * 0.032 * 0.4979 = 0.0143 kg
            % Glucose:  0.9 * 0.032 * 0.2014 = 0.0058 kg
            % Fat:      0.9 * 0.032 * 0.3007 = 0.0087 kg
            %
            % So on average the following non absorbed ratios can be assumed
            % for the nutrients:
            % Proteins: 0.0143 kg / 0.1316 kg = 0.109
            % Glucose:  0.0058 kg / 0.3949 kg = 0.0147
            % Fat:      0.0087 kg / 0.1003 kg = 0.0863
            %
            % Since the Jejunum is about 2m long while the illeum about 3 m and
            % the the duodenum only 0.3 m. We assume that 99% of the food
            % passes through the duodenum for all nutrients and that the ratio
            % of the non absorption in the jejunum is 1.5 times higher than in
            % the ileum. In total this results in the following ratios:
            % (Equation for Ileum non absorption ratio ((0.0147/0.99)/1.5)^0.5)
            % Equation for Jejunum: 0.0147 / (0.99 * 0.0995)
            %               Proteins    Glucose     Fat    
            % Duodenum:     0.99        0.99    	0.99
            % Jejunum:      0.406       0.1492      0.3616
            % Ileum:        0.271       0.0995      0.2411
            % Total:        0.109       0.0147      0.0863
            %
            % On average the human drinks 2.5 kg of water per day and
            % consumed 0.7 kg of water in food per day. This means ~ 3.2
            % kg of water pass through the digestive system according to
            % BVAD.
            % For water we assume that in total 90% is absorbed in the
            % small intestine, with the remaining fraction beeing absorbed
            % in the large intestine so we use the same approach as above and
            % calculate the pass through ratios:
            %               Water
            % Duodenum:     0.99
            % Jejunum:      0.3892
            % Ileum:        0.2595
            % Total:        0.1
            % 
            % For water the target non absorption rate overall is
            % Water:       0.1 kg /    3.2 kg = 0.0313
            % Therefore the large intestin has a non absorption rate of:
            % 0.0313 / 0.1 = 0.3130
            % However, for currently unkown reasons, the feces water
            % production was higher by a factor of 2.3 so the non
            % absorption rate was adjusted to 0.1361. With the reworked of
            % the digestion layer, it seems that some of the water is mixed
            % up wit the secreation, which is why the pass through had to
            % increase to produce the correct amount of feces water. This
            % issue is to be handled
            %
            % for Sodium we assume that everything is absorbed
            
            % We initialize the pass through ratios to one, so that for
            % everything else, nothing is absorbed and everything is passed
            % on
            this.arPassThroughRatios.Duodenum       = ones(1, this.oMT.iSubstances);
            this.arPassThroughRatios.Jejunum      	= ones(1, this.oMT.iSubstances);
            this.arPassThroughRatios.Ileum          = ones(1, this.oMT.iSubstances);
            this.arPassThroughRatios.LargeIntestine = ones(1, this.oMT.iSubstances);
            
            % The ratios deduced above are as follows:
            %               Proteins    Glucose     Fat         Water    	Sodium
            % Duodenum:     0.99        0.99    	0.99        0.99        0.99 
            % Jejunum:      0.406       0.1492      0.3616      0.3892      0.66
            % Ileum:        0.271       0.0995      0.2411      0.2595      0.33
            % Large Int.:   1           1           1           0.313       0
            % Total:        0.109       0.0147      0.0863      0.0313      0
            %
            % These are now set to the corresponding fields
            
            this.arPassThroughRatios.Duodenum(this.oMT.tiN2I.C3H7NO2)           = 0.99;
            this.arPassThroughRatios.Duodenum(this.oMT.tiN2I.C6H12O6)           = 0.99;
            this.arPassThroughRatios.Duodenum(this.oMT.tiN2I.C51H98O6)          = 0.99;
            this.arPassThroughRatios.Duodenum(this.oMT.tiN2I.H2O)               = 0.99;
            this.arPassThroughRatios.Duodenum(this.oMT.tiN2I.Naplus)            = 0.99;
            
            this.arPassThroughRatios.Jejunum(this.oMT.tiN2I.C3H7NO2)            = 0.406;
            this.arPassThroughRatios.Jejunum(this.oMT.tiN2I.C6H12O6)            = 0.1492;
            this.arPassThroughRatios.Jejunum(this.oMT.tiN2I.C51H98O6)           = 0.3616;
            this.arPassThroughRatios.Jejunum(this.oMT.tiN2I.H2O)                = 0.6487;
            this.arPassThroughRatios.Jejunum(this.oMT.tiN2I.Naplus)             = 0.66;
            
            this.arPassThroughRatios.Ileum(this.oMT.tiN2I.C3H7NO2)              = 0.2741;
            this.arPassThroughRatios.Ileum(this.oMT.tiN2I.C6H12O6)              = 0.0995;
            this.arPassThroughRatios.Ileum(this.oMT.tiN2I.C51H98O6)             = 0.2411;
            this.arPassThroughRatios.Ileum(this.oMT.tiN2I.H2O)                  = 0.3460;
            this.arPassThroughRatios.Ileum(this.oMT.tiN2I.Naplus)               = 0.33;
            
            this.arPassThroughRatios.LargeIntestine(this.oMT.tiN2I.C3H7NO2)     = 1;
            this.arPassThroughRatios.LargeIntestine(this.oMT.tiN2I.C6H12O6)     = 1;
            this.arPassThroughRatios.LargeIntestine(this.oMT.tiN2I.C51H98O6)    = 1;
            this.arPassThroughRatios.LargeIntestine(this.oMT.tiN2I.H2O)         = 0.613;
            this.arPassThroughRatios.LargeIntestine(this.oMT.tiN2I.Naplus)      = 0;
            
            
            % Define rate of change function for ODE solver.
            this.hCalculateChangeRate = @(t, m) this.calculateChangeRate(m, t);
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% Stores and phases
            fDigestionVolume = (this.tfStomachParameters.fMaximalContent + this.tfDuodenumParameters.fMaximalContent + this.tfJejunumParameters.fMaximalContent +...
                                this.tfIleumParameters.fMaximalContent + this.tfLargeIntestineParameters.fMaximalContent + this.tfRectumParameters.fMaximalContent) / 1000;
            
            matter.store(this, 'Digestion', fDigestionVolume);
            
            fInitialSodiumConcentration = 0.01;
            
            %% Stomach
            % initialized with 50% of max content as base food and 20% of
            % the current mass as water and sodium
            fInitialFoodMass    = 0.5 * this.tfStomachParameters.fMaximalContent;
            tfStomachContent = struct('Food',                                                    fInitialFoodMass,...
                                      'H2O',                           0.2 * (fInitialFoodMass + fInitialFoodMass * 0.2),...
                                      'Naplus', fInitialSodiumConcentration *   0.2 * (fInitialFoodMass + fInitialFoodMass * 0.2));
            
            oStomachPhase = this.toStores.Digestion.createPhase(	'mixture',	'Stomach', 'liquid',        this.tfStomachParameters.fMaximalContent/1000,       tfStomachContent,       this.oParent.fBodyCoreTemperature, 1e5);
            
            % Add a manipulator to convert the ingested food into the base
            % nutrients it is comprised of
            components.matter.Manips.ManualManipulator(this, 'FoodConverter', oStomachPhase, true);
            
            this.txFoodWater.Stomach.rRatio     = 0.8;
            this.txFoodWater.Stomach.fMass      = 0.8 * oStomachPhase.afMass(this.oMT.tiN2I.H2O);
            this.txFoodWater.Stomach.fSodiumSecretionMass = (1 - this.txFoodWater.Stomach.rRatio)    * fInitialSodiumConcentration * oStomachPhase.afMass(this.oMT.tiN2I.H2O);
            
            %% Duodenum
            % standard food composition based on the composition suggested
            % in the HDIH on page 2010 488 is initilized with 50% fill
            % status for the Duodenum
            tfDuodenumContent = struct( 'C6H12O6',                          0.5 * 0.4  * this.tfDuodenumParameters.fMaximalContent,...
                                        'C3H7NO2',                          0.5 * 0.16 * this.tfDuodenumParameters.fMaximalContent,...
                                        'C51H98O6',                         0.5 * 0.24 * this.tfDuodenumParameters.fMaximalContent,...
                                        'H2O',                              0.5 * 0.25 * this.tfDuodenumParameters.fMaximalContent,...
                                        'Naplus',   fInitialSodiumConcentration *    0.5 * 0.25 * this.tfDuodenumParameters.fMaximalContent);
                                        
            oDuodenumPhase = this.toStores.Digestion.createPhase(	'mixture',	'Duodenum', 'liquid',        this.tfDuodenumParameters.fMaximalContent/1000,      tfDuodenumContent,       this.oParent.fBodyCoreTemperature, 1e5);
            
            this.txFoodWater.Duodenum.rRatio                = 0.1;
            this.txFoodWater.Duodenum.fMass                 = this.txFoodWater.Duodenum.rRatio          * oDuodenumPhase.afMass(this.oMT.tiN2I.H2O);
            this.txFoodWater.Duodenum.fSodiumSecretionMass  = (1 - this.txFoodWater.Duodenum.rRatio)    * fInitialSodiumConcentration * oDuodenumPhase.afMass(this.oMT.tiN2I.H2O);
            
            %% Jejunum
            % standard food composition based on the composition suggested
            % in the HDIH on page 2010 488 is initilized with 40% fill
            % status for the Jejunum
            tfJejunumContent = struct( 'C6H12O6',                           0.4 * 0.4   * this.tfJejunumParameters.fMaximalContent,...
                                        'C3H7NO2',                          0.4 * 0.16  * this.tfJejunumParameters.fMaximalContent,...
                                        'C51H98O6',                         0.4 * 0.24   * this.tfJejunumParameters.fMaximalContent,...
                                        'H2O',                              0.4 * 0.25  * this.tfJejunumParameters.fMaximalContent,...
                                        'Naplus',   fInitialSodiumConcentration *    0.4 * 0.25 * this.tfJejunumParameters.fMaximalContent);
                                        
            oJejunumPhase = this.toStores.Digestion.createPhase(	'mixture',	'Jejunum', 'liquid',        this.tfJejunumParameters.fMaximalContent/1000,      tfJejunumContent,       this.oParent.fBodyCoreTemperature, 1e5);
            
            this.txFoodWater.Jejunum.rRatio                = 0.1;
            this.txFoodWater.Jejunum.fMass                 = this.txFoodWater.Duodenum.rRatio          * oJejunumPhase.afMass(this.oMT.tiN2I.H2O);
            this.txFoodWater.Jejunum.fSodiumSecretionMass  = (1 - this.txFoodWater.Duodenum.rRatio)    * fInitialSodiumConcentration * oJejunumPhase.afMass(this.oMT.tiN2I.H2O);
            
            %% Ileum
            % standard food composition based on the composition suggested
            % in the HDIH on page 2010 488 is initilized with 30% fill
            % status for the Ileum
            tfIleumContent = struct(    'C6H12O6',                         0.3 * 0.4   * this.tfIleumParameters.fMaximalContent,...
                                        'C3H7NO2',                         0.3 * 0.16   * this.tfIleumParameters.fMaximalContent,...
                                        'C51H98O6',                        0.3 * 0.24   * this.tfIleumParameters.fMaximalContent,...
                                        'H2O',                             0.3 * 0.25 * this.tfIleumParameters.fMaximalContent,...
                                        'Naplus',   fInitialSodiumConcentration *   0.3 * 0.25 * this.tfIleumParameters.fMaximalContent);
                                        
            oIleumPhase = this.toStores.Digestion.createPhase(	'mixture',	'Ileum', 'liquid',        this.tfIleumParameters.fMaximalContent/1000,      tfIleumContent,       this.oParent.fBodyCoreTemperature, 1e5);
            
            this.txFoodWater.Ileum.rRatio                = 0.1;
            this.txFoodWater.Ileum.fMass                 = this.txFoodWater.Duodenum.rRatio          * oIleumPhase.afMass(this.oMT.tiN2I.H2O);
            this.txFoodWater.Ileum.fSodiumSecretionMass  = (1 - this.txFoodWater.Duodenum.rRatio)    * oIleumPhase.afMass(this.oMT.tiN2I.H2O);
            
            %% LargeIntestine
            % initialized to be empty
            tfLargeIntestineContent = struct(   'DietaryFiber',                             0.02 * 0.75 * this.tfLargeIntestineParameters.fMaximalContent,...
                                                'H2O',                                      0.02 * 0.25 * this.tfLargeIntestineParameters.fMaximalContent,...
                                                'Naplus',   fInitialSodiumConcentration *   0.02 * 0.25 * this.tfLargeIntestineParameters.fMaximalContent);
                                        
            oLargeIntestinePhase = this.toStores.Digestion.createPhase(	'mixture',	'LargeIntestine', 'liquid',        this.tfLargeIntestineParameters.fMaximalContent/1000,      tfLargeIntestineContent,       this.oParent.fBodyCoreTemperature, 1e5);
            
            this.txFoodWater.LargeIntestine.rRatio                = 0.1;
            this.txFoodWater.LargeIntestine.fMass                 = this.txFoodWater.Duodenum.rRatio          * oLargeIntestinePhase.afMass(this.oMT.tiN2I.H2O);
            this.txFoodWater.LargeIntestine.fSodiumSecretionMass  = (1 - this.txFoodWater.Duodenum.rRatio)    * fInitialSodiumConcentration * oLargeIntestinePhase.afMass(this.oMT.tiN2I.H2O);
            
            %% Rectum
            % initialized to be empty
            tfRectumContent = struct();
                                        
            oRectumPhase = this.toStores.Digestion.createPhase(	'mixture',	'Rectum', 'liquid',        this.tfRectumParameters.fMaximalContent/1000,      tfRectumContent,       this.oParent.fBodyCoreTemperature, 1e5);
            
            components.matter.Manips.ManualManipulator(this, 'FecesConverter', oRectumPhase, true);
            
            %% P2Ps
            components.matter.P2Ps.ManualP2P(this.toStores.Digestion, 'Stomach_to_Duodenum',             oStomachPhase,        oDuodenumPhase);
            components.matter.P2Ps.ManualP2P(this.toStores.Digestion, 'Duodenum_to_Jejunum',             oDuodenumPhase,       oJejunumPhase);
            components.matter.P2Ps.ManualP2P(this.toStores.Digestion, 'Jejunum_to_Ileum',                oJejunumPhase,        oIleumPhase);
            components.matter.P2Ps.ManualP2P(this.toStores.Digestion, 'Ileum_to_LargeIntestine',         oIleumPhase,          oLargeIntestinePhase);
            components.matter.P2Ps.ManualP2P(this.toStores.Digestion, 'LargeIntestine_to_Rectum',        oLargeIntestinePhase, oRectumPhase);
            
            
            this.tfSmallIntestineFoodTimer.Duodenum         = this.oTimer.fTime;
            this.tfSmallIntestineFoodTimer.Jejunum          = this.oTimer.fTime;
            this.tfSmallIntestineFoodTimer.Ileum            = this.oTimer.fTime;
            this.tfSmallIntestineFoodTimer.LargeIntestine   = this.oTimer.fTime;
            
        end
        
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            % We add a constant temperature heat source for the stomach
            % phase, which will maintain the body core temperature for the
            % ingested mass
            oHeatSource = components.thermal.heatsources.ConstantTemperature('StomachConstantTemperature');
            this.toStores.Digestion.toPhases.Stomach.oCapacity.addHeatSource(oHeatSource);
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            csStores = fieldnames(this.toStores);
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    
                    tTimeStepProperties = struct();
                    
                    tTimeStepProperties.fMaxStep = this.oParent.fTimeStep;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                    
                    tTimeStepProperties.rMaxChange = 0.1;
                    
%                     arMaxChange = zeros(1,this.oMT.iSubstances);
%                     arMaxChange(this.oMT.tiN2I.C6H12O6)     = 0.1;
%                     arMaxChange(this.oMT.tiN2I.C51H98O6)    = 0.1;
%                     arMaxChange(this.oMT.tiN2I.C6H12O6)     = 0.1;
%                     arMaxChange(this.oMT.tiN2I.H2O)         = 0.1;
%                     tTimeStepProperties.arMaxChange = arMaxChange;

                    oPhase.setTimeStepProperties(tTimeStepProperties);
                end
            end
            % The rectum will empty and fill itself but matter properties
            % are not important for it --> rMaxChange can be set to inf:
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = inf;
            arMaxChange = zeros(1,this.oMT.iSubstances);
            tTimeStepProperties.arMaxChange = arMaxChange;
            this.toStores.Digestion.toPhases.Rectum.setTimeStepProperties(tTimeStepProperties);
            
            tTimeStepProperties = struct();
            tTimeStepProperties.fMassErrorLimit = 1e-12;
            this.toStores.Digestion.toPhases.Stomach.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
        
        function bindRequestFoodFunction(this, requestFood)
            % This function is used when registering the human at the food
            % store. The request food function of the food store can then
            % be called by the human
            this.requestFood = requestFood;
        end
        
        function Eat(this, fEnergyDemand, fTime, arComposition)
            % The detailed human model requires a seperate function for
            % food consumption than the requestFood function from the food
            % store since it has to react to food intake
            
            if nargin > 3
                afPartialMasses = this.requestFood(fEnergyDemand, fTime, arComposition);
            else
                afPartialMasses = this.requestFood(fEnergyDemand, fTime);
            end
            
            fMassFlow = sum(afPartialMasses) / fTime;
            
            if fMassFlow < this.tfMouthParameters.fMinimalMassTransferToStomach
                
            	fSalivaFlow = this.tfMouthParameters.fMinimalSalivaFlow;
                fNaFlow     = fSalivaFlow * this.tfMouthParameters.fMinimalNaConcentrationSecretion;
                
            elseif fMassFlow > this.tfMouthParameters.fMaximalMassTransferToStomach
                
            	fSalivaFlow = this.tfMouthParameters.fMaximalSalivaFlow;
                fNaFlow     = fSalivaFlow * this.tfMouthParameters.fMaximalNaConcentrationSecretion;
                
            else
                fSalivaFlow = (fMassFlow/this.tfMouthParameters.fMaximalMassTransferToStomach) * this.tfMouthParameters.fMaximalSalivaFlow;
                fNaFlow     = fSalivaFlow * (fSalivaFlow / this.tfMouthParameters.fMaximalSalivaFlow) * this.tfMouthParameters.fMaximalNaConcentrationSecretion;
            end
            
            afMassTransferSaliva = zeros(1, this.oMT.iSubstances);
            afMassTransferSaliva(this.oMT.tiN2I.H2O)    = fSalivaFlow * fTime;
            afMassTransferSaliva(this.oMT.tiN2I.Naplus) = fNaFlow * fTime;
            this.oParent.toBranches.SalivaToMouth.oHandler.setMassTransfer(afMassTransferSaliva, fTime);
            
            this.tfFlowRates.Mouth.afSecretionMasses = zeros(1, this.oMT.iSubstances);
            this.tfFlowRates.Mouth.afSecretionMasses(this.oMT.tiN2I.H2O)     = fSalivaFlow * fTime;
            this.tfFlowRates.Mouth.afSecretionMasses(this.oMT.tiN2I.Naplus)  = fNaFlow * fTime;
        end
        
        function Drink(this, fWaterMass)
            %% Drinking
            % Logic for drinking is kept simple, the waterBalance layer
            % triggers this function and tells the human how much to drink
            if ~this.oParent.toBranches.Potable_Water_In.oHandler.bMassTransferActive
                this.oParent.toBranches.Potable_Water_In.oHandler.setMassTransfer(-fWaterMass, 60);
            end
        end
    end
    
    methods (Access = protected)
        function [afFoodConversionFlowRates, afTransportFlowRates, afSecretionFlowRates] = calculateStomach(this, afMass)
            %% calculateStomach
            % the conversion of food is modelled to take the amount of
            % time the food stuff usually remains within the body. in the
            % current version the equation from the V-HAB 1 V-Man are
            % used, for improvements specific durations for the individual
            % food stuffs can be implemented!
            %
            % Also handled within this function is transfer to the Small
            % Intestine - Duodenum, which is modelled to be the food
            % conversion flow rates plus a flow rate for the secretions
            % from mouth and stomach. And the secretion flowrate of water
            % and sodium into the stomach
            oStomachPhase = this.toStores.Digestion.toPhases.Stomach;
            
            
            % Time step from the last execution to now. Is used to
            % calculate the current food water mass ratio in the
            % intestine:
            fTimeStep = this.oTimer.fTime - this.fLastUpdateTime;
            
            this.txFoodWater.Stomach.fMass = this.txFoodWater.Stomach.rRatio * afMass(this.oMT.tiN2I.H2O);
            
            if this.txFoodWater.Stomach.rRatio == 0
                fNewSecretionMass       = afMass(this.oMT.tiN2I.H2O);
                fSodiumSecretionMass    = afMass(this.oMT.tiN2I.Naplus);
            else
                fSecretionMassPrevious  = (1 - this.txFoodWater.Stomach.rRatio) * (this.txFoodWater.Stomach.fMass / this.txFoodWater.Stomach.rRatio);
                fNewSecretionMass       = fSecretionMassPrevious                              + this.tfFlowRates.Stomach.afSecretionFlowRates(this.oMT.tiN2I.H2O)     * fTimeStep + this.tfFlowRates.Mouth.afSecretionMasses(this.oMT.tiN2I.H2O);
                fSodiumSecretionMass    = this.txFoodWater.Stomach.fSodiumSecretionMass    + this.tfFlowRates.Stomach.afSecretionFlowRates(this.oMT.tiN2I.Naplus)  * fTimeStep + this.tfFlowRates.Mouth.afSecretionMasses(this.oMT.tiN2I.Naplus);
            end
            
            % Now we reset the secretion masses from mouth to not consider
            % them twice
            this.tfFlowRates.Mouth.afSecretionMasses = zeros(1, this.oMT.iSubstances);
            
            if fNewSecretionMass > afMass(this.oMT.tiN2I.H2O)
                fNewSecretionMass       = afMass(this.oMT.tiN2I.H2O);
                fSodiumSecretionMass    = afMass(this.oMT.tiN2I.Naplus);
                fCurrentFoodWaterMass   = 0;
                fCurrentFoodSodiumMass  = 0;
            else
                fCurrentFoodWaterMass   = afMass(this.oMT.tiN2I.H2O) - fNewSecretionMass;
                fCurrentFoodSodiumMass  = afMass(this.oMT.tiN2I.Naplus)- fSodiumSecretionMass;
            end
            this.txFoodWater.Stomach.fMass = fCurrentFoodWaterMass;
            this.txFoodWater.Stomach.rRatio = fCurrentFoodWaterMass / afMass(this.oMT.tiN2I.H2O);
            this.txFoodWater.Stomach.fSodiumSecretionMass = fSodiumSecretionMass;
            
            fSodiumSecretionMass = (1 - this.txFoodWater.Stomach.rRatio) * afMass(this.oMT.tiN2I.Naplus);
            
            rSecretionMassRatioInStomach = fNewSecretionMass / sum(afMass);
            
            % the abEdibleSubstances vector only contains the edible
            % compound masses, not the base nutrients like fats,
            % carbohydrates and proteins
            fTotalUndigestedFoodInStomach = sum(afMass(this.oMT.abEdibleSubstances));
            
            afNutrientMassInUndigestedFood = this.oMT.resolveCompoundMass(afMass, oStomachPhase.arCompoundMass);
            
            afNutrientMassInUndigestedFood(this.oMT.tiN2I.Naplus) = afNutrientMassInUndigestedFood(this.oMT.tiN2I.Na) + afNutrientMassInUndigestedFood(this.oMT.tiN2I.Naplus);
            afNutrientMassInUndigestedFood(this.oMT.tiN2I.Na) = 0;

            % Since the value afNutrientMassInUndigestedFood should only
            % content the nutrition content in the undigested food we
            % subtract the current water and sodium content of the food.
            % The other nutrients are directly transfered out of the
            % stomache once they are converted
            afNutrientMassInUndigestedFood(this.oMT.tiN2I.H2O)      = afNutrientMassInUndigestedFood(this.oMT.tiN2I.H2O)    - afMass(this.oMT.tiN2I.H2O);
            afNutrientMassInUndigestedFood(this.oMT.tiN2I.Naplus)   = afNutrientMassInUndigestedFood(this.oMT.tiN2I.Naplus) - afMass(this.oMT.tiN2I.Naplus);
                    
            % The secretion mass ratio must be larger than 20% before
            % anything is converted into basic nutrients:
            if rSecretionMassRatioInStomach > 0.2 && fTotalUndigestedFoodInStomach > 0
                % These two equations correspond to equations (11-372) to
                % (11-377) in the dissertation of Markus Czupalla
                fSlowFactor = 1 / ( 1 + 0.5 * (0.2 * afNutrientMassInUndigestedFood(this.oMT.tiN2I.C3H7NO2) + afNutrientMassInUndigestedFood(this.oMT.tiN2I.C16H32O2)) / (afNutrientMassInUndigestedFood(this.oMT.tiN2I.C6H12O6) + afNutrientMassInUndigestedFood(this.oMT.tiN2I.C3H7NO2) + afNutrientMassInUndigestedFood(this.oMT.tiN2I.C16H32O2)));
                
                % A change to the original equations is, that the minimal
                % mass flow from the stomach to the duodenum was weighthed
                % with the current mass ratio of the corresponding
                % undigested nutrient
                afFoodConversionFlowRates = (this.tfStomachParameters.fMinimalOutputMassFlow + this.tfStomachParameters.fMaximalOutputMassFlow .* fSlowFactor .* rSecretionMassRatioInStomach) .* (afNutrientMassInUndigestedFood ./ this.tfStomachParameters.fMaximalContent);
                afFoodConversionFlowRates(afNutrientMassInUndigestedFood == 0) = 0;
                
                % Now we have the flow rates of the base nutrients that are
                % created from the food, but we do not have the flowrates of
                % food that are consumed to produce these. In order to
                % calculate the digestion flowrate of each food stuff we have
                % to calculate the contribution of that food stuff to the total
                % undigested nutritions:
                aiEdibleSubstanceIndices = find(afMass(this.oMT.abEdibleSubstances));
                iTotalEdibleSubstancesInStomach = sum(aiEdibleSubstanceIndices ~= 0);
                for iEdibleSubstance = 1:iTotalEdibleSubstancesInStomach

                    sEdibleSubstance = this.oMT.csEdibleSubstances{aiEdibleSubstanceIndices(iEdibleSubstance)};

                    % Now we get the nutrient composition for this specific
                    % edible substance
                    afIndividualSubstanceMass = zeros(1, this.oMT.iSubstances);
                    afIndividualSubstanceMass(this.oMT.tiN2I.(sEdibleSubstance)) = afMass(this.oMT.tiN2I.(sEdibleSubstance));
                    afIndividualUndigestedNutrients = this.oMT.resolveCompoundMass(afIndividualSubstanceMass , oStomachPhase.arCompoundMass);

                    
                    afIndividualUndigestedNutrients(this.oMT.tiN2I.Naplus) = afIndividualUndigestedNutrients(this.oMT.tiN2I.Na) + afIndividualUndigestedNutrients(this.oMT.tiN2I.Naplus);
                    afIndividualUndigestedNutrients(this.oMT.tiN2I.Na) = 0;
                    
                    % by dividing the individual nutrient masses for this
                    % specific edible substance with the overall nutrient
                    % masses from all edible substances, we can calculate the
                    % contribuition of this edible substance to the overall
                    % nutrient flow of each nutrient.
                    arNutrientContributions = afIndividualUndigestedNutrients(afNutrientMassInUndigestedFood ~= 0) ./ afNutrientMassInUndigestedFood(afNutrientMassInUndigestedFood ~= 0);

                    % The flow rate of this edible substance that is converted
                    % is then the sum over all individual nutrient flowrates
                    % that are created times the contribution of this specific
                    % edible substance.
                    afFoodConversionFlowRates(this.oMT.tiN2I.(sEdibleSubstance)) = - sum(arNutrientContributions .* afFoodConversionFlowRates(afNutrientMassInUndigestedFood ~= 0));
                end

                % Note that small errors in the food conversion flow rate (as
                % in it does not sum up to exactly 0) can occur but are handled
                % by the manual manipulator code. If the error becomes too
                % large, the manual manipulator will throw an error
            else
                afFoodConversionFlowRates = zeros(1, this.oMT.iSubstances);
            end
            
            
            % now we set the calculated flowrate
            oStomachPhase.toManips.substance.setFlowRate(afFoodConversionFlowRates);
            
            afFoodConversionFlowRates = oStomachPhase.toManips.substance.afManualFlowRates;
            
            % Now we set the P2P flowrate which transports the digested
            % matter into the small intestine! For this we also have to
            % consider a contribution from the stomach secretions which are
            % transported:
            afTransportFlowRates = afFoodConversionFlowRates;
            afTransportFlowRates(afTransportFlowRates < 0) = 0;
            
            % Assume that consumed drinking water passes through the
            % stomach in 3 minutes
            fDrinkingWaterTransportFlow = fCurrentFoodWaterMass / 180;
            fDrinkingSodiumTransportFlow = fCurrentFoodSodiumMass / 180;
            
            % Assume that 100g water always remain in the stomach
            if afMass(this.oMT.tiN2I.H2O) < 0.1
                afTransportFlowRates(this.oMT.tiN2I.H2O)    = 0;
            else
                afTransportFlowRates(this.oMT.tiN2I.H2O)    = afTransportFlowRates(this.oMT.tiN2I.H2O) + fDrinkingWaterTransportFlow;
            end
            if afMass(this.oMT.tiN2I.Naplus) < 0.001
                afTransportFlowRates(this.oMT.tiN2I.Naplus) = 0;
            else
                afTransportFlowRates(this.oMT.tiN2I.Naplus) = afTransportFlowRates(this.oMT.tiN2I.Naplus) + fDrinkingSodiumTransportFlow;
            end
            
            %% Secretion calculation:
            % For the stomach, it is not really correct to have it readsorb
            % water, but that makes the overall model much easier to
            % handle, than transporting stomach secretion water downstream.
            % therefore, if the food mass in the stomach becomes small, the
            % stomach will readsorb water, to keep it at 0.25 to 0.3 mass
            % ratio of secretions, requiring new secretions once new food
            % enters the stomach
            if rSecretionMassRatioInStomach > 0.3 && afMass(this.oMT.tiN2I.H2O) > 0.1
                fSecretionFlow  = -((rSecretionMassRatioInStomach - 0.3) / 0.7) * (fNewSecretionMass - 0.3 * sum(afMass)) / 60;
                fNaFlow         = -((rSecretionMassRatioInStomach - 0.3) / 0.7) * (fSodiumSecretionMass - 0.3 * fSodiumSecretionMass) / 60;
                
            elseif rSecretionMassRatioInStomach > 0.25
                fSecretionFlow = 0;
                fNaFlow = 0;
            else
                fSecretionFlow  = this.tfStomachParameters.fMinimalSecretionFlow + (fTotalUndigestedFoodInStomach / (0.8 * this.tfStomachParameters.fMaximalContent)) * (this.tfStomachParameters.fMaximalSecretionFlow - this.tfStomachParameters.fMinimalSecretionFlow);
                fNaFlow         = fSecretionFlow * (fTotalUndigestedFoodInStomach / this.tfStomachParameters.fMaximalContent) * (this.tfStomachParameters.fMaximalNaConcentrationSecretion - this.tfStomachParameters.fMinimalNaConcentrationSecretion);
            end
            
            afSecretionFlowRates = zeros(1, this.oMT.iSubstances);
            afSecretionFlowRates(this.oMT.tiN2I.H2O)    = fSecretionFlow;
            afSecretionFlowRates(this.oMT.tiN2I.Naplus) = fNaFlow;
            
            this.tfFlowRates.Stomach.afSecretionFlowRates = afSecretionFlowRates;
        end
        
        function [afDigestionFlowRates, afAbsorptionFlowRates, afTransportFlowRates, afSecretionFlowRates] = calculateIntestine(this, sIntestine, afMass, tfParameters)
            
            % Time step from the last execution to now. Is used to
            % calculate the current food water mass ratio in the
            % intestine:
            fTimeStep = this.oTimer.fTime - this.fLastUpdateTime;
            
            tfIntestinePreviousFlowRate  = this.tfFlowRates.(sIntestine);
            txIntestineFoodWater         = this.txFoodWater.(sIntestine);
            
            if txIntestineFoodWater.rRatio > 0
                fSecretionMassPrevious = (1 - txIntestineFoodWater.rRatio) * (txIntestineFoodWater.fMass / txIntestineFoodWater.rRatio);

                fSecretionMass = fSecretionMassPrevious + tfIntestinePreviousFlowRate.afSecretionFlowRates(this.oMT.tiN2I.H2O) * fTimeStep;
                fSodiumSecretionMass = txIntestineFoodWater.fSodiumSecretionMass + tfIntestinePreviousFlowRate.afSecretionFlowRates(this.oMT.tiN2I.Naplus) * fTimeStep;
            else
                fSecretionMass          = afMass(this.oMT.tiN2I.H2O);
                fSodiumSecretionMass    = afMass(this.oMT.tiN2I.Naplus);
            end
                
            fCurrentFoodWaterMass = afMass(this.oMT.tiN2I.H2O) - fSecretionMass;
            txIntestineFoodWater.fMass  = fCurrentFoodWaterMass;
            if afMass(this.oMT.tiN2I.H2O) > 0
                txIntestineFoodWater.rRatio = fCurrentFoodWaterMass / afMass(this.oMT.tiN2I.H2O);
            else
                txIntestineFoodWater.rRatio = 0;
            end
            txIntestineFoodWater.fSodiumSecretionMass = fSodiumSecretionMass;
            
            fSodiumSecretionMass = (1 - txIntestineFoodWater.rRatio) * afMass(this.oMT.tiN2I.Naplus);
            
            this.txFoodWater.(sIntestine) = txIntestineFoodWater;
            
            %% Secretion calculation:
            
            rSecretionMassRatio = fSecretionMass / sum(afMass);
            
            if rSecretionMassRatio > 0.3
                fSecretionFlow  = -((rSecretionMassRatio - 0.3) / 0.7) * (fSecretionMass - 0.3 * sum(afMass)) / 60;
                fNaFlow         = -((rSecretionMassRatio - 0.3) / 0.7) * (fSodiumSecretionMass - 0.3 * fSodiumSecretionMass) / 60;
                
            elseif rSecretionMassRatio > 0.25
                fSecretionFlow = 0;
                fNaFlow = 0;
            else
                fSecretionFlow  = tfParameters.fMinimalSecretionFlow + ((sum(afMass) - fSecretionMass) / (0.8 * tfParameters.fMaximalContent)) * (tfParameters.fMaximalSecretionFlow - tfParameters.fMinimalSecretionFlow);
                rSodiumRatioSecretions = ((sum(afMass) - fSecretionMass) / (0.8 * tfParameters.fMaximalContent)) * (tfParameters.fMaximalNaConcentrationSecretion - tfParameters.fMinimalNaConcentrationSecretion);
                fNaFlow         = fSecretionFlow * rSodiumRatioSecretions;
            end
            
            afSecretionFlowRates = zeros(1, this.oMT.iSubstances);
            afSecretionFlowRates(this.oMT.tiN2I.H2O)    = fSecretionFlow;
            afSecretionFlowRates(this.oMT.tiN2I.Naplus) = fNaFlow;
            
            % Now we get the transport flowrate which occured at as much
            % time ago as the time constant with this compartment defines
            fDelayedTime = this.oTimer.fTime - tfParameters.fTimeConstant;
            
            abEqualTime = this.tfFlowRates.afTime == fDelayedTime;
            if any(abEqualTime)
                iTimeIndex = find(abEqualTime, 1);
            else
                abSmallerTime = this.tfFlowRates.afTime < fDelayedTime;

                iTimeIndex = find(abSmallerTime, 1, 'last' );
                if isempty(iTimeIndex)
                    % if the index is empty we use the oldest available
                    % entry and no interpolation
                    iTimeIndex = 1;
                end
            end
            afDelayedTransportFlow = tfIntestinePreviousFlowRate.mfPastInputFlowRates(iTimeIndex, :);
            
            afDelayedTransportFlow(afMass == 0) = 0;
            
            % Of these delayed input flows, the corresponding ratios
            % are then passed on to the next compartment. Since the
            % transport flows only contain food water and not secretions
            % the ratios of absorption are in total then correct.
            afTransportFlowRates = afDelayedTransportFlow .* this.arPassThroughRatios.(sIntestine);
            
            afUptakeFlowRate = afDelayedTransportFlow .* (1 - this.arPassThroughRatios.(sIntestine));
            
            afDigestionFlowRates = afUptakeFlowRate;
            afDigestionFlowRates(this.oMT.tiN2I.H2O)    = 0;
            afDigestionFlowRates(this.oMT.tiN2I.Naplus) = 0;
            
            afAbsorptionFlowRates = zeros(1,this.oMT.iSubstances);
            afAbsorptionFlowRates(this.oMT.tiN2I.H2O)       = afUptakeFlowRate(this.oMT.tiN2I.H2O);
            afAbsorptionFlowRates(this.oMT.tiN2I.Naplus)    = afUptakeFlowRate(this.oMT.tiN2I.Naplus);
            
        end
        
        function calculateRectum(this, afTransportFlowRates)
            
            fMass = this.toStores.Digestion.toPhases.Rectum.fMass;
            % This polynomial defecation need calculation was created
            % through fitting a second grade polynomial to the levels
            % defined in the disseration of Markus Czupalla.
            this.fDefecationNeed = -4.5683 * fMass^2 + 10.0798 * fMass - 0.2078;
            
            if this.fDefecationNeed > 2
                this.oParent.toBranches.Feces_Out.oHandler.setMassTransfer(fMass * 0.98, 60);
            end
            
            %% Feces conversion
            % since we want the human to output a compound mass called
            % Feces, we define a manipulator to convert all incoming
            % substances into the compound mass:
            
            fTotalFecesFlowRate = sum(afTransportFlowRates);
            afManipulatorFlowRates = zeros(1,this.oMT.iSubstances);
            aarFlowsToCompound = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            
            if fTotalFecesFlowRate ~= 0
                aiSubstances = find(afTransportFlowRates);
                for iSubstance = 1:length(aiSubstances)
                    afManipulatorFlowRates(aiSubstances(iSubstance))                = - afTransportFlowRates(aiSubstances(iSubstance));
                    aarFlowsToCompound(this.oMT.tiN2I.Feces, aiSubstances(iSubstance)) = afTransportFlowRates(aiSubstances(iSubstance)) / fTotalFecesFlowRate;
                end
            end
            afManipulatorFlowRates(this.oMT.tiN2I.Feces) 	=   fTotalFecesFlowRate;
            
            this.toStores.Digestion.toPhases.Rectum.toManips.substance.setFlowRate(afManipulatorFlowRates, aarFlowsToCompound);
        end
        
        function exec(this, ~)
            exec@vsys(this);
            % We do not use the exec functions of the human layers, as it
            % is not possible to define the update order if we use the exec
            % functions!!
        end
        
        function afMassChangeRate = calculateChangeRate(this, afMasses, iStep)
            
            afStomachMass       = afMasses(1:this.oMT.iSubstances)';
            afDuodenumMass      = afMasses(this.oMT.iSubstances + 1     : 2 * this.oMT.iSubstances)';
            afJejunumMass       = afMasses(2 * this.oMT.iSubstances + 1 : 3 * this.oMT.iSubstances)';
            afIleumMass         = afMasses(3 * this.oMT.iSubstances + 1 : 4 * this.oMT.iSubstances)';
            aLargeIntestineMass = afMasses(4 * this.oMT.iSubstances + 1 : 5 * this.oMT.iSubstances)';
            
            %% Stomach
            
            [afFoodConversionFlowRates, afTransportFlowRates, afSecretionFlowRates] = this.calculateStomach(afStomachMass);
            
            afFlowRatesStomach = - afTransportFlowRates + afSecretionFlowRates + afFoodConversionFlowRates;
            
            this.tfInternalFlowRates.afFoodConversionFlowRates(iStep,:)     = afFoodConversionFlowRates;
            this.tfInternalFlowRates.afTransportFlowRatesStomach(iStep,:)   = afTransportFlowRates;
            this.tfInternalFlowRates.afSecretionFlowRatesStomach(iStep,:)   = afSecretionFlowRates;
            
            %% Duodenum
            [afDigestionFlowRatesDuodenum, afAbsorptionFlowRatesDuodenum, afTransportFlowRatesDuodenum, afSecretionFlowRatesDuodenum] = this.calculateIntestine('Duodenum', afDuodenumMass, this.tfDuodenumParameters);
            
            afFlowRatesDuodenum = afDigestionFlowRatesDuodenum - afAbsorptionFlowRatesDuodenum - afTransportFlowRatesDuodenum + afSecretionFlowRatesDuodenum;
            
            this.tfInternalFlowRates.afDigestionFlowRatesDuodenum(iStep,:)	= afDigestionFlowRatesDuodenum;
            this.tfInternalFlowRates.afAbsorptionFlowRatesDuodenum(iStep,:) = afAbsorptionFlowRatesDuodenum;
            this.tfInternalFlowRates.afTransportFlowRatesDuodenum(iStep,:)  = afTransportFlowRatesDuodenum;
            this.tfInternalFlowRates.afSecretionFlowRatesDuodenum(iStep,:)  = afSecretionFlowRatesDuodenum;
            
            %% Jejunum
            [afDigestionFlowRatesJejunum, afAbsorptionFlowRatesJejunum, afTransportFlowRatesJejunum, afSecretionFlowRatesJejunum] = this.calculateIntestine('Jejunum',  afJejunumMass,  this.tfJejunumParameters);
            
            afFlowRatesJejunum = afDigestionFlowRatesJejunum - afAbsorptionFlowRatesJejunum - afTransportFlowRatesJejunum + afSecretionFlowRatesJejunum;
            
            this.tfInternalFlowRates.afDigestionFlowRatesJejunum(iStep,:)  = afDigestionFlowRatesJejunum;
            this.tfInternalFlowRates.afAbsorptionFlowRatesJejunum(iStep,:) = afAbsorptionFlowRatesJejunum;
            this.tfInternalFlowRates.afTransportFlowRatesJejunum(iStep,:)  = afTransportFlowRatesJejunum;
            this.tfInternalFlowRates.afSecretionFlowRatesJejunum(iStep,:)  = afSecretionFlowRatesJejunum;
            
            %% Ileum
            [afDigestionFlowRatesIleum, afAbsorptionFlowRatesIleum, afTransportFlowRatesIleum, afSecretionFlowRatesIleum] = this.calculateIntestine('Ileum',    afIleumMass,    this.tfIleumParameters);
            
            afFlowRatesIleum = afDigestionFlowRatesIleum - afAbsorptionFlowRatesIleum - afTransportFlowRatesIleum + afSecretionFlowRatesIleum;
            
            this.tfInternalFlowRates.afDigestionFlowRatesIleum(iStep,:)	 = afDigestionFlowRatesIleum;
            this.tfInternalFlowRates.afAbsorptionFlowRatesIleum(iStep,:) = afAbsorptionFlowRatesIleum;
            this.tfInternalFlowRates.afTransportFlowRatesIleum(iStep,:)  = afTransportFlowRatesIleum;
            this.tfInternalFlowRates.afSecretionFlowRatesIleum(iStep,:)  = afSecretionFlowRatesIleum;
            
            %% LargeIntestine
            % the difference between the large and small intestines is
            % that the large intestine does not digest nutrients it only
            % readsorbes water 
            [~, afAbsorptionFlowRates, afTransportFlowRates, afSecretionFlowRates] = this.calculateIntestine('LargeIntestine',    aLargeIntestineMass,    this.tfLargeIntestineParameters);
            
            afFlowRatesLargeIntestine = - afAbsorptionFlowRates - afTransportFlowRates + afSecretionFlowRates;
            
            this.tfInternalFlowRates.afAbsorptionFlowRatesLargeInt(iStep,:)	= afAbsorptionFlowRates;
            this.tfInternalFlowRates.afTransportFlowRatesLargeInt(iStep,:)  = afTransportFlowRates;
            this.tfInternalFlowRates.afSecretionFlowRatesLargeInt(iStep,:)  = afSecretionFlowRates;
            
            afMassChangeRate = [afFlowRatesStomach';...
                              	afFlowRatesDuodenum';...
                              	afFlowRatesJejunum';...
                             	afFlowRatesIleum';...
                                afFlowRatesLargeIntestine'];
                            
        end
     end
     
    methods (Access = {?components.matter.DetailedHuman.Human})
        
        function update(this)
            
            fStepBeginTime = this.fLastUpdateTime;
            fStepEndTime   = this.oTimer.fTime;
            
            if (fStepEndTime - fStepBeginTime) > this.fInternalTimeStep
                
                fOriginalInternalStep = this.fInternalTimeStep;
                if (fStepEndTime - fStepBeginTime) < this.fInternalTimeStep
                    mfTimes = [fStepBeginTime fStepEndTime];
                else
                    fSteps = (fStepEndTime - fStepBeginTime) / this.fInternalTimeStep;
                    this.fInternalTimeStep = this.fInternalTimeStep * (1 + mod(fSteps, 1)  ./ floor(fSteps));

                    mfTimes = fStepBeginTime:this.fInternalTimeStep:fStepEndTime;
                end
                iSteps = length(mfTimes);
                this.tfInternalFlowRates = struct();
                this.tfInternalFlowRates.afFoodConversionFlowRates        = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afTransportFlowRatesStomach      = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afSecretionFlowRatesStomach      = zeros(iSteps, this.oMT.iSubstances);
                
                this.tfInternalFlowRates.afDigestionFlowRatesDuodenum     = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afAbsorptionFlowRatesDuodenum    = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afTransportFlowRatesDuodenum     = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afSecretionFlowRatesDuodenum     = zeros(iSteps, this.oMT.iSubstances);

                this.tfInternalFlowRates.afDigestionFlowRatesJejunum      = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afAbsorptionFlowRatesJejunum     = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afTransportFlowRatesJejunum      = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afSecretionFlowRatesJejunum      = zeros(iSteps, this.oMT.iSubstances);

                this.tfInternalFlowRates.afDigestionFlowRatesIleum        = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afAbsorptionFlowRatesIleum       = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afTransportFlowRatesIleum        = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afSecretionFlowRatesIleum        = zeros(iSteps, this.oMT.iSubstances);
                
                this.tfInternalFlowRates.afAbsorptionFlowRatesLargeInt    = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afTransportFlowRatesLargeInt     = zeros(iSteps, this.oMT.iSubstances);
                this.tfInternalFlowRates.afSecretionFlowRatesLargeInt     = zeros(iSteps, this.oMT.iSubstances);
                
                afMasses = [ this.toStores.Digestion.toPhases.Stomach.afMass';...
                                    this.toStores.Digestion.toPhases.Duodenum.afMass';...
                                    this.toStores.Digestion.toPhases.Jejunum.afMass';...
                                    this.toStores.Digestion.toPhases.Ileum.afMass';...
                                    this.toStores.Digestion.toPhases.LargeIntestine.afMass'];
                % Since we are not interested in the masses, but in the
                % internal flowrates a for loop is better suited for our
                % purposes
%                 [mfSolutionTimes, afSolutionMasses] = ode45(this.hCalculateChangeRate, [fStepBeginTime, fStepEndTime], afInitialMasses, this.tOdeOptions);
%                 afSolutionMassesLast = afSolutionMasses(end,:)';
%                 
%                 afStomachMass       = afSolutionMassesLast(1:this.oMT.iSubstances)';
%                 afDuodenumMass      = afSolutionMassesLast(this.oMT.iSubstances + 1     : 2 * this.oMT.iSubstances)';
%                 afJejunumMass       = afSolutionMassesLast(2 * this.oMT.iSubstances + 1 : 3 * this.oMT.iSubstances)';
%                 afIleumMass         = afSolutionMassesLast(3 * this.oMT.iSubstances + 1 : 4 * this.oMT.iSubstances)';
%                 aLargeIntestineMass = afSolutionMassesLast(4 * this.oMT.iSubstances + 1 : 5 * this.oMT.iSubstances)';
                
                for iTime = 1:iSteps
                    afMassChangeRate = this.calculateChangeRate(afMasses, iTime);
                    afMasses = afMasses + afMassChangeRate * this.fInternalTimeStep;
                end
                
                this.fInternalTimeStep = fOriginalInternalStep;

                
                afFoodConversionFlowRates       = sum(this.tfInternalFlowRates.afFoodConversionFlowRates, 1)        ./ iSteps;
                afTransportFlowRatesStomach     = sum(this.tfInternalFlowRates.afTransportFlowRatesStomach, 1)      ./ iSteps;
                afSecretionFlowRatesStomach     = sum(this.tfInternalFlowRates.afSecretionFlowRatesStomach, 1)      ./ iSteps;
                
                afDigestionFlowRatesDuodenum    = sum(this.tfInternalFlowRates.afDigestionFlowRatesDuodenum, 1)     ./ iSteps;
                afAbsorptionFlowRatesDuodenum   = sum(this.tfInternalFlowRates.afAbsorptionFlowRatesDuodenum, 1)    ./ iSteps;
                afTransportFlowRatesDuodenum    = sum(this.tfInternalFlowRates.afTransportFlowRatesDuodenum, 1)     ./ iSteps;
                afSecretionFlowRatesDuodenum    = sum(this.tfInternalFlowRates.afSecretionFlowRatesDuodenum, 1)     ./ iSteps;

                afDigestionFlowRatesJejunum     = sum(this.tfInternalFlowRates.afDigestionFlowRatesJejunum, 1)      ./ iSteps;
                afAbsorptionFlowRatesJejunum    = sum(this.tfInternalFlowRates.afAbsorptionFlowRatesJejunum, 1)     ./ iSteps;
                afTransportFlowRatesJejunum     = sum(this.tfInternalFlowRates.afTransportFlowRatesJejunum, 1)      ./ iSteps;
                afSecretionFlowRatesJejunum     = sum(this.tfInternalFlowRates.afSecretionFlowRatesJejunum, 1)      ./ iSteps;

                afDigestionFlowRatesIleum       = sum(this.tfInternalFlowRates.afDigestionFlowRatesIleum, 1)        ./ iSteps;
                afAbsorptionFlowRatesIleum      = sum(this.tfInternalFlowRates.afAbsorptionFlowRatesIleum, 1)       ./ iSteps;
                afTransportFlowRatesIleum       = sum(this.tfInternalFlowRates.afTransportFlowRatesIleum, 1)        ./ iSteps;
                afSecretionFlowRatesIleum       = sum(this.tfInternalFlowRates.afSecretionFlowRatesIleum, 1)        ./ iSteps;
                
                afAbsorptionFlowRatesLargeInt   = sum(this.tfInternalFlowRates.afAbsorptionFlowRatesLargeInt, 1)    ./ iSteps;
                afTransportFlowRatesLargeInt    = sum(this.tfInternalFlowRates.afTransportFlowRatesLargeInt, 1)     ./ iSteps;
                afSecretionFlowRatesLargeInt    = sum(this.tfInternalFlowRates.afSecretionFlowRatesLargeInt, 1)     ./ iSteps;
                
            else
                [afFoodConversionFlowRates, afTransportFlowRatesStomach, afSecretionFlowRatesStomach]                                       = this.calculateStomach(this.toStores.Digestion.toPhases.Stomach.afMass);
                [afDigestionFlowRatesDuodenum, afAbsorptionFlowRatesDuodenum, afTransportFlowRatesDuodenum, afSecretionFlowRatesDuodenum]   = this.calculateIntestine('Duodenum',           this.toStores.Digestion.toPhases.Duodenum.afMass, this.tfDuodenumParameters);
                [afDigestionFlowRatesJejunum, afAbsorptionFlowRatesJejunum, afTransportFlowRatesJejunum, afSecretionFlowRatesJejunum]       = this.calculateIntestine('Jejunum',            this.toStores.Digestion.toPhases.Jejunum.afMass,  this.tfJejunumParameters);
                [afDigestionFlowRatesIleum, afAbsorptionFlowRatesIleum, afTransportFlowRatesIleum, afSecretionFlowRatesIleum]               = this.calculateIntestine('Ileum',              this.toStores.Digestion.toPhases.Ileum.afMass,    this.tfIleumParameters);
                [~, afAbsorptionFlowRatesLargeInt, afTransportFlowRatesLargeInt, afSecretionFlowRatesLargeInt]                              = this.calculateIntestine('LargeIntestine',     this.toStores.Digestion.toPhases.LargeIntestine.afMass,    this.tfLargeIntestineParameters);
            end
            %% Stomach
            this.toStores.Digestion.toPhases.Stomach.toManips.substance.setFlowRate(afFoodConversionFlowRates);
            
%             afFoodConversionFlowRates = oStomachPhase.toManips.substance.afManualFlowRates;
            this.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum.setFlowRate(afTransportFlowRatesStomach);
            
            this.oParent.toBranches.SecretionToStomach.oHandler.setFlowRate(afSecretionFlowRatesStomach);
            
            %% Duodenum
            this.oParent.toBranches.DuodenumToMetabolism.oHandler.setFlowRate(afDigestionFlowRatesDuodenum);
            
            this.oParent.toBranches.ReadsorptionFromDuodenum.oHandler.setFlowRate(afAbsorptionFlowRatesDuodenum);
            
            this.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum.setFlowRate(afTransportFlowRatesDuodenum);
            
            this.oParent.toBranches.SecretionToDuodenum.oHandler.setFlowRate(afSecretionFlowRatesDuodenum);
            
            %% Jejunum
            this.oParent.toBranches.JejunumToMetabolism.oHandler.setFlowRate(afDigestionFlowRatesJejunum);
            
            this.oParent.toBranches.ReadsorptionFromJejunum.oHandler.setFlowRate(afAbsorptionFlowRatesJejunum);
            
            this.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum.setFlowRate(afTransportFlowRatesJejunum);
            
            this.oParent.toBranches.SecretionToJejunum.oHandler.setFlowRate(afSecretionFlowRatesJejunum);
            
            %% Ileum
            this.oParent.toBranches.IleumToMetabolism.oHandler.setFlowRate(afDigestionFlowRatesIleum);
            
            this.oParent.toBranches.ReadsorptionFromIleum.oHandler.setFlowRate(afAbsorptionFlowRatesIleum);
            
            this.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine.setFlowRate(afTransportFlowRatesIleum);
            
            this.oParent.toBranches.SecretionToIleum.oHandler.setFlowRate(afSecretionFlowRatesIleum);
            
            %% LargeIntestine
            this.oParent.toBranches.ReadsorptionFromLargeIntestine.oHandler.setFlowRate(afAbsorptionFlowRatesLargeInt);
            
            this.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum.setFlowRate(afTransportFlowRatesLargeInt);
            
            this.oParent.toBranches.SecretionToLargeIntestine.oHandler.setFlowRate(afSecretionFlowRatesLargeInt);
            
            % as interface for the metabolic layer, set the total digested
            % flowrates for the individual base nutrients
            this.fDigestedMassFlowCarbohydrates = afDigestionFlowRatesDuodenum(this.oMT.tiN2I.C6H12O6)  + afDigestionFlowRatesJejunum(this.oMT.tiN2I.C6H12O6)  + afDigestionFlowRatesIleum(this.oMT.tiN2I.C6H12O6);
            this.fDigestedMassFlowProteins      = afDigestionFlowRatesDuodenum(this.oMT.tiN2I.C3H7NO2)  + afDigestionFlowRatesJejunum(this.oMT.tiN2I.C3H7NO2)  + afDigestionFlowRatesIleum(this.oMT.tiN2I.C3H7NO2);
            this.fDigestedMassFlowFat           = afDigestionFlowRatesDuodenum(this.oMT.tiN2I.C51H98O6) + afDigestionFlowRatesJejunum(this.oMT.tiN2I.C51H98O6) + afDigestionFlowRatesIleum(this.oMT.tiN2I.C51H98O6);
             
            this.tfFlowRates.Duodenum.afDigestionFlowRates     = afDigestionFlowRatesDuodenum;
            this.tfFlowRates.Duodenum.afAbsorptionFlowRates    = afAbsorptionFlowRatesDuodenum;
            this.tfFlowRates.Duodenum.afTransportFlowRates     = afTransportFlowRatesDuodenum;
            this.tfFlowRates.Duodenum.afSecretionFlowRates     = afSecretionFlowRatesDuodenum;
            
            this.tfFlowRates.Jejunum.afDigestionFlowRates      = afDigestionFlowRatesJejunum;
            this.tfFlowRates.Jejunum.afAbsorptionFlowRates     = afAbsorptionFlowRatesJejunum;
            this.tfFlowRates.Jejunum.afTransportFlowRates      = afTransportFlowRatesJejunum;
            this.tfFlowRates.Jejunum.afSecretionFlowRates      = afSecretionFlowRatesJejunum;
            
            this.tfFlowRates.Ileum.afDigestionFlowRates        = afDigestionFlowRatesIleum;
            this.tfFlowRates.Ileum.afAbsorptionFlowRates       = afAbsorptionFlowRatesIleum;
            this.tfFlowRates.Ileum.afTransportFlowRates        = afTransportFlowRatesIleum;
            this.tfFlowRates.Ileum.afSecretionFlowRates        = afSecretionFlowRatesIleum;
            
            this.tfFlowRates.LargeIntestine.afAbsorptionFlowRates     = afAbsorptionFlowRatesLargeInt;
            this.tfFlowRates.LargeIntestine.afTransportFlowRates      = afTransportFlowRatesLargeInt;
            this.tfFlowRates.LargeIntestine.afSecretionFlowRates      = afSecretionFlowRatesLargeInt;
            
            this.tfFlowRates.Duodenum.mfPastInputFlowRates(end+1,:)         = afTransportFlowRatesStomach;
            this.tfFlowRates.Jejunum.mfPastInputFlowRates(end+1,:)          = afTransportFlowRatesDuodenum;
            this.tfFlowRates.Ileum.mfPastInputFlowRates(end+1,:)            = afTransportFlowRatesJejunum;
            this.tfFlowRates.LargeIntestine.mfPastInputFlowRates(end+1,:)   = afTransportFlowRatesIleum;
            
            this.tfFlowRates.afTime(end+1)         = this.oTimer.fTime;
            
            if (this.oTimer.fTime - this.tfFlowRates.afTime(1)) > this.tfLargeIntestineParameters.fTimeConstant
                this.tfFlowRates.afTime(1) = [];
                
                this.tfFlowRates.Duodenum.mfPastInputFlowRates(1,:)         = [];
                this.tfFlowRates.Jejunum.mfPastInputFlowRates(1,:)          = [];
                this.tfFlowRates.Ileum.mfPastInputFlowRates(1,:)            = [];
                this.tfFlowRates.LargeIntestine.mfPastInputFlowRates(1,:)   = [];
            end
            
            %% Rectum
            % In the Rectum remaining nutrients and fiber are converted to
            % a compound mass called Feces
            this.calculateRectum(afTransportFlowRatesLargeInt);
            
            this.fLastUpdateTime = this.oTimer.fTime;
        end
    end
end