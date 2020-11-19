classdef Metabolic < vsys
    % Note that protein metabolism was not yet part of the V-HAB 1.0 human
    % model. This is added to it in this implementation.
    % Also the anaerobic metabolism is currently not functional!
    
    % TO DO: 
    % - check if the exercise recovery system is working properly
    % - implement schedule compatibility for the exercise
    % - translate the BodyComposition function into something
    %   useable by the V-HAB 2 implementation

    properties (SetAccess = protected, GetAccess = public)
        fBodyMass     	= 75;     	% [kg] (Mcardle,2006,p761)
        
        fMaxHeartRate;          % [beat/min]
        % Cardiac output is the blood output from the heart
        fMaxCardiacOutput;      % [l/min]
        fRestHeartRate;         % [beat/min]
        fVO2_rest;             	% [l/min]
        fVO2_max;               % [l/min]
        fVO2_Debt = 0;          % [l/min]
        fVO2;                   % [l/min]
        fVCO2;                  % [l/min]
        
        % the maximum volume of blood the heart can pump per beat
        fMaxStrokeVolume   	= 0.1;      % (for trained) [l/beat] (Mcardle,2006,p347)
        fRestStrokeVolume  	= 0.07102;  % [l/beat]
        
        fLeanBodyMass;
        fBoneMass;
        fOrganMass;
        fTotalH2OMass;
        fH2OinBloodPlasmaMass;
        fH2OinInterstitialFluidMass;
        fH2OinIntracellulcarFluidMass;
        % Abbr. in original model:
        % BP = Blood Plasma
        % Int = interstitial fluid
        % ICF = intracellular fluid
        
        
        fBMI;
        
        % The molar volume for the current body temperature used to convert
        % the VO2 values into molar values and vice versa
        fMolarVolume;
        
        rRespiratoryCoefficient;
        
        % This struct contains stochiometric factors used in the nutrient
        % conversion calculations
        tfMetabolicConversionFactors;
        
        % Exercise onset fat usage ratio
        hExerciseOnsetFatUsage;
        
        %
        fCurrentStateStartTime = 0;
        
        % Value can be between 0 and 1.5. It is the current VO2/VO2_max
        rActivityLevel = 0.15;
        rExerciseTargetActivityLevel = 0.15;
        rActivityLevelBeforeExercise = 0.15;
        
        % here the post exercise additional O2 consumption is stored over
        % the time
        mrExcessPostExerciseActivityLevel = zeros(2,0);
        
        tfMetabolicFlowsRest;
        tfMetabolicFlowsAerobicActivity;
        tfMetabolicFlowsProteins;
        tfMetabolicFlowsFatSynthesis;
        
        % the linear contribution factor of anaerobic energy.
        % From experimental measurement they derived ? as a median of 0.876.
        % DA if Matthias Pfeiffer page 128-129 (Equation 8.17)
        fAlpha_Debt = 0.876;
        
        % Aerobic Activity Metabolic Rate
        fAerobicActivityMetabolicRate = 0;
        % Base Metabolic Rate
        fBaseMetabolicRate = 0;
        % Resting Metabolic Rate
        fRestMetabolicRate = 0;
        
        fTotalMetabolicRate = 0;
        
        % Last time the AerobicEnergyMonitor function was executed
        fLastAerobicMonitorExecution = 0;
        
        % total energy consumption
        fTotalAerobicEnergyExpenditure             = 0; % [J]
        % total aerobic activity energy consumption
        fTotalAerobicActivityEnergyExpenditure     = 0; % [J]
        % total basal energy consumption
        fTotalBasicEnergyExpenditure               = 0; % [J]
        % total ATP energy
        fTotalATPEnergy                            = 0; % [J]
        
        % The metabolic generated heat flow
        fMetabolicHeatFlow; % [W]
        
        % This property is used to store the base metabolic heat flow, all
        % metabolic heat flow above the base level will result in sweating
        fBaseMetabolicHeatFlow; % [W]
        
        % These two booleans are used to decide if the necessary duration
        % of training have been reached for muscle improvement effects as
        % assumed in the model
        bDailyAerobicTrainingThresholdReached   = false;
        bDailyAnaerobicTrainingThresholdReached = false;
        
        iRestDays               = 0;
        iAerobicTrainingDays    = 0;
        iAnaerobicTrainingDays  = 0;
        iAerobicTrainingWeeks   = 0;
        iAnaerobicTrainingWeeks = 0;
        iAerobicDetrainingWeeks	= 0;
        iAnaerobicDetrainingWeeks	= 0;
        
        fTimeModuloWeek = 0; % s
        fTimeModuloDay  = 0; % s
        
        % Struct to store the current training improvements factors of the
        % model
        tTrainingFactors;
        
        % Once per week the discreet muscle mass change is calculated and
        % converted into a mass flow in kg/s for the current week
        fMuscleChangeMassFlow = 0;
        fMaximumGlucoseContetLiver;
        fMaximumGlucoseContetMuscle;
        
        % Struct to store required interpolations for the model
        tInterpolations;
        
        bExercise = false;
        bPostExercise = false;
        
        fRestingDailyEnergyExpenditure; % [kJ / day]
        % This parameter stores how much additional food energy demand the
        % human has from exercise in addition to fRestingDailyEnergyExpenditure
        fAdditionalFoodEnergyDemand = 0; % [kJ / day]
        
        % This value relates the released energy per kg of oxygen consumed.
        % The base value defined here is based on the 5 kcal/l used by the
        % V-HAB 1 model:
        % 1 l of oxygen corresponds to 1/22.41396954 mol which is
        % 0.001427627531254 kg.
        % so 5 * 4184 / 0.001427627531254 kg.
        fCaloricValueOxygen = 1.4654e+07; % [J/kg]
        
        fUreaFlowRate = 0;
        
        fLastMetabolismUpdate = 0;
        
        fInitialProteinMassMetabolism;
    end
    
    
    properties (Constant)
        % Cardiac performance parameters
        fRestCardiacOutput 	= 5;     	% [l/min] (Mcardle,2006,p346)
        
        % A newer table with more points can be found on pager 349 (Figure
        % 17.4) of McArdle 2015
        mfVO2_max           = [1.6      3.2         5.2];    	% table (Mcardle,2006,p348), [l/min]
        mfMaxCardiacOutput  = [9.5      20          30.40];     % table (Mcardle,2006,p348), [l/min]
        
        % each mol of ATP releases 7.3 kcal, 32 mol of ATP release in total
        % according to "Exercise Physiology", McArdle, 2015, p 151 and
        % "Biochemie", Stryer, 2014, p 559. The previously used value of 36
        % mol of ATP came from an older release of Stryer and were redacted
        % in the new version!
        rGlucoseEnergyConversionEfficiency  = ((32*12)/686); 
        
        rFatEnergyConversionEfficiency      = ((106*12)/2340);
        
        % assumed efficiency of mechanical work. Since the energy yield of
        % ATP as previously wrongly assumed to be 12 kcal/mol, while the
        % correct yield (see comment at the energy yield) is 7.3 kcal/mol,
        % the mechanical efficiency is adapted. Since the food consumption
        % with 12 kcal/mol and 0.25 was correct according to BVAD, the
        % total ATP expenditure should remain the same.
        rMechanicalEfficiency = 0.25/(7.3/12);
        
        % The activity level at lactate threshold
        rLactateActivityLevelThreshold = 0.7;
        
        % Two books, "Biochemstry" Berg et.al. 2013 on page 434 and
        % Molecular Cell Biology of Lodish 2016 on page 62 mention the
        % energy release of ATP to be 7.3 kcal/mol. The original V-Man
        % model assumed 12 kcal/mol
        fEnergyYieldATP = 7.3 * 4184;
        
        % Corresponds to epsilon_gluc,liver in the dissertation
        rRatioOfGlucoseUsedFromLiver = 0.2;
        fAverageMaximumGlucoseContetLiver  = 0.1;
        fAverageMaximumGlucoseContetMuscle = 0.4;
        
        % Inital Body Muscle Mass
        fInitialMuscleMass  = 31.3;
        fInitialFatMass 	= 11.25;    % [kg] (Mcardle,2006,p761)
        fInitialBodyMassWithoutFatOrMuslce = 75 - 31.3 - 11.25;
        
        rBoneToLeanMassRatio                = 0.14;
        rOrgansToLeanMassRatio              = 0.14;
        rH2OtoMuscleMassRatio               = 0.75;
        rH2OtoFatMassRatio                  = 0.15;
        % THis is necessary to simplify some calculations
        rH2OtoFatWithoutH2OMassRatio        = 1/((1/0.15) - 1);
        rH2OtoBoneMassRatio                 = 0.13;
        rH2OtoOrganMassRatio                = 0.75;
        
        % These mass ratios are compared to the total h2o mass in the body
        rH2OinBloodPlasmaMassRatio          = 0.067;
        rH2OinInterstitialFluidMassRatio    = 0.313;
        rH2OinIntracellularFluidMassRatio   = 0.62;
        
        rSlowTwitchInitial = 0.398;
        rFastTwitchInitial = 0.602;
        
        %% Training and Detraining tables
        % From the dissertation of Markus Czupalla
        % For the following tables, as long as nothing else is stated the
        % following description holds true:
        % First column is the weeks of training, second column
        % is the improvment factor
        % Table 11-5:
        mStrokeVolumeImprovement = [0,      1;
                                    4,      1.045;
                                    8,      1.09;
                                    24,     1.3;
                                    48,     1.35;
                                    72,     1.4;
                                    96,     1.45;
                                    150,    1.5];
                                
        % Table 11-6
        mAerobicLiverStorageImprovment =  [0,       1;
                                           4,       1.1;
                                           8,       1.2;
                                           24,      1.3;
                                           48,      1.4;
                                           72,      1.49;
                                           96,      1.5;
                                           150,     1.51];
                                       
        % Table 11-7
        mAerobicSlowTwitchImprovment =    [0,       1;
                                           4,       1.08;
                                           8,       1.15;
                                           24,      1.18;
                                           48,      1.19;
                                           72,      1.20;
                                           96,      1.201;
                                           150,     1.202];
        % Table 11-8
        mAnaerobicSlowTwitchImprovment =  [0,       1;
                                           4,       1.08;
                                           8,       1.15;
                                           24,      1.18;
                                           48,      1.19;
                                           72,      1.20;
                                           96,      1.201;
                                           150,     1.202];
    	% Table 11-9
        mAnaerobicFastTwitchImprovment =  [0,       1;
                                           8,       1.05;
                                           16,      1.08;
                                           24,      1.12;
                                           150,     1.121];
    	% Table 11-11, first column is the max stroke volume improvement
    	% ratio, second column is the ratio between max and base stroke
    	% volume
        mBaseStrokeVolumeImprovement   =  [1,       1.408;
                                           1.5,     1.79];
                                       
        % Please note that the detraining tables are in fact the same as
        % the training tables, just used the other way around (they are
        % used to calculate the weeks of detraining based on the current
        % improvement factor)
       
    end
    
    methods
        function this = Metabolic(oParent, sName)
            this@vsys(oParent, sName, inf);
            
            this.fMaximumGlucoseContetLiver = this.fAverageMaximumGlucoseContetLiver;
            this.fMaximumGlucoseContetMuscle = this.fAverageMaximumGlucoseContetMuscle;
            
            
            % Value can be between 0 and 1.5. It is the current VO2/VO2_max
            this.rActivityLevel                 = oParent.fNominalAcitivityLevel;
            this.rExerciseTargetActivityLevel   = oParent.fNominalAcitivityLevel;
            this.rActivityLevelBeforeExercise   = oParent.fNominalAcitivityLevel;
            % Respiratory Coefficients:
            % At the moment the coefficients for each substance is fixed at a
            % certain value. In a future implemention it could be changed
            % according to the detailed composition of e.g. the fats the human
            % digests. RC is defined as mol(CO2)/mol(O2)
            this.tfMetabolicConversionFactors.rRespiratoryCoefficientFat      	= 51/72.5;
            this.tfMetabolicConversionFactors.rRespiratoryCoefficientGlucose    = 1;
            this.tfMetabolicConversionFactors.rRespiratoryCoefficientProteins   = 5/6;

            % ATP Conversion: These factors correlate how many mol of ATP
            % are produced per mol of oxygen consumed
            this.tfMetabolicConversionFactors.rATPCoefficientFat                = 336.5/72;
            this.tfMetabolicConversionFactors.rATPCoefficientGlucose            = 32/6;
            
            % H2O Conversion: These factors correlate how many mol of H2O
            % are produced per mol of oxygen consumed. The previous model
            % assumed 11 mol of water per 72 mol of oxygen in the following
            % equation:
            % C51H98O6 + 72 O2 -> 51 CO2 + 407 ATP + 11 H2O
            % This equation is obviously wrong because the water generated
            % in ATP production is not considered. Also the ADP input is
            % not considered. If ATP is removed from the equation the mass
            % balance between the two sides obviously does not work.
            % Therefore a new derivation of the reaction was performed and
            % lead to equation:
            % C51H98O6 + 72.5 O2 -> 51 CO2 + 49 H2O
            % which is based on values provided in Berg, J. M., Tymoczko,
            % J. L., Stryer, L. et al. (2013), Biochemie (7. Auflage,
            % Berlin: Springer Spektrum)
            % <http://dx.doi.org/10.1007/978-3-8274-2989-6>.
            this.tfMetabolicConversionFactors.rH2OCoefficientFat                = 49/72.5;
            
            % In the dissertation this coefficient is stated to be 7, in
            % the old code of V-HAB 1 (both simulink and text based
            % variant) it is set to 6. However, as described in the
            % original master thesis which developed the models "Design of
            % a human metabolic model for integrated ECLSS robustness
            % analysis", Matthias Pfeiffer, RT-DA 2007/11
            % The reaction modelled is (Eqation 3.5 in the DA):
            % C6H12O6 + 6*O2 + 36*ADP(3-) + 36HP04(2-)-> 6*CO2 + 42*H2O + 36*ATP(4-)
            % Which corresponds to a factor of 7. However, as shown in Fig.
            % 8-12 of the master thesis the factor of 6 was already used in
            % that simulink model. It is important to note that 36 mol of
            % water produced here should later be consumed in when the ATP
            % is consumed and reverts to ADP!
            %
            % What further complicates this issue is that the ATP
            % production is outdated, as three different sources all agree
            % on a new ATP production of either 30 or 32 ATP. 
            % In this version of the human model we will use a conversion
            % factor of one because we will not consider the water produced
            % during ATP production. ATP will also not be created as a mass
            % within V-HAB as it would only complicate the different flows
            % necessary.
            this.tfMetabolicConversionFactors.rH2OCoefficientGlucose            = 1;
            
            % For fat the conversion factors that were
            this.tfMetabolicConversionFactors.rCoefficientFat                   = 1/72.5;
            this.tfMetabolicConversionFactors.rCoefficientGlucose               = 1/6;
            
            % The following ratios can be used to calculate the amount of
            % mol created for each mol of glucose converted to
            % triacylglycerid (with a C-16 fatty acid)
            % 14 C6H12O6 + 11.5 O2 -> C51H98O6 + 33 CO2 + 35 H2O
            this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficient          = 1/14;
            this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficientOxygen    = 11.5/14;
            this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficientCO2       = 33/14;
            this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficientH2O       = 35/14;
            this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficientATP       = 28/14;
            
            % The following ratios can be used to calculate the amount of
            % mol created for each mol of protein converted to
            % triacylglycerid (with a C-16 fatty acid)
            % 2 C6H12O6 + 24 C3H7NO2 + 11.5 O2 -> C51H98O6 + 12 CH4N2O + 21 CO2 + 23 H2O
            this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficient          = 1/24;
            this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientOxygen    = 11.5/24;
            this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientGlucose   = 2/24;
            this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientUrea      = 12/24;
            this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientCO2       = 21/24;
            this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientH2O       = 23/24;
            this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientATP       = -37/24;
            
            
            % The following ratios are calculated based on the metabolic
            % pathways of Alanin!
            % 2*C3H7NO2 + 6*O2 -> 5*CO2 + CH4N2O + 5*H2O (and 26 ATP)
            this.tfMetabolicConversionFactors.rProteinMetabolism                = 1/3;
            this.tfMetabolicConversionFactors.rProteinMetabolismH2O           	= 5/6;
            this.tfMetabolicConversionFactors.rProteinMetabolismATP           	= 26/6;
            this.tfMetabolicConversionFactors.rProteinMetabolismUrea           	= 1/6;
            
            % DA from Matthias Pfeiffer (RT-DA 2007-11) page 87 figure 6-4
            ExcerciseLoad           = (0.0:0.1:0.8);
            ExcerciseTime           = [  0  0.16   0.5     2    10    15] .* 60;
            rFatUsage               = [0.0 0.000 0.000 0.000 0.000 0.000;... % 0
                                       0.0 0.065 0.163 0.423 0.586 0.651;... % 0.1
                                       0.0 0.057 0.142 0.370 0.512 0.569;... % 0.2
                                       0.0 0.049 0.122 0.317 0.439 0.488;... % 0.3
                                       0.0 0.043 0.109 0.283 0.391 0.435;... % 0.4
                                       0.0 0.041 0.102 0.265 0.368 0.408;... % 0.5
                                       0.0 0.038 0.096 0.248 0.344 0.382;... % 0.6
                                       0.0 0.033 0.082 0.214 0.297 0.330;... % 0.7
                                       0.0 0.028 0.070 0.181 0.250 0.278];   % 0.8
                                   
             % Instead of storing the table and redoing the interpolation
             % every time it is needed, we interpolate once and store that
             % interpolation. However, in order to do this, we first have
             % to use a linear interpolation between the exisiting data
             % points using a scattered interpolant to create a gridded
             % data set
             mfTime = ones(length(ExcerciseLoad),1) * ExcerciseTime;
             mfLoad = ones(1, length(ExcerciseTime)) .* ExcerciseLoad';
             % cubic interpolation does not work here, therefore we use the
             % makima interpolation which is Modified Akima cubic Hermite
             % interpolation
             this.hExerciseOnsetFatUsage = griddedInterpolant(mfTime',mfLoad',rFatUsage','makima','none');
             % In order to plot the interpolation and compare it to the
             % values from just the table, execute the following lines of
             % code when you set a break point here!
%             mfLoad = (0:0.01:0.8);
%             mfTime = (0:0.5:15);
%             for iTime = 1:length(mfTime)
%                 for iLoad = 1:length(mfLoad)
%                     mrFatUsage(iLoad, iTime) = hInterpolation(mfTime(iTime), mfLoad(iLoad));
%                     
%                 end
%             end
%             mesh(mfTime, mfLoad, mrFatUsage)
%             figure
%             mesh(ExcericeTime, ExcericeLoad, rFatUsage)
            
            % Now we create the required interpolations for the training
            % and detraining calculations
            this.tInterpolations.hVO2maxFromCardiacOutput           = griddedInterpolant(this.mfMaxCardiacOutput,                   this.mfVO2_max);
            this.tInterpolations.hStrokeVolumeImprovement           = griddedInterpolant(this.mStrokeVolumeImprovement(:,1),        this.mStrokeVolumeImprovement(:,2));
            this.tInterpolations.hAerobicLiverStorageImprovement    = griddedInterpolant(this.mAerobicLiverStorageImprovment(:,1),  this.mAerobicLiverStorageImprovment(:,2));
            this.tInterpolations.hAerobicSlowTwitchImprovment       = griddedInterpolant(this.mAerobicSlowTwitchImprovment(:,1), 	this.mAerobicSlowTwitchImprovment(:,2));
            this.tInterpolations.hAnaerobicSlowTwitchImprovment     = griddedInterpolant(this.mAnaerobicSlowTwitchImprovment(:,1),  this.mAnaerobicSlowTwitchImprovment(:,2));
            this.tInterpolations.hAnaerobicFastTwitchImprovment     = griddedInterpolant(this.mAnaerobicFastTwitchImprovment(:,1),  this.mAnaerobicFastTwitchImprovment(:,2));
            this.tInterpolations.hBaseStrokeVolumeImprovement       = griddedInterpolant(this.mBaseStrokeVolumeImprovement(:,1),  this.mBaseStrokeVolumeImprovement(:,2));
            
            this.tInterpolations.hStrokeVolumeDetraining            = griddedInterpolant(this.mStrokeVolumeImprovement(:,2),        this.mStrokeVolumeImprovement(:,1));
            this.tInterpolations.hAerobicLiverStorageDetraining     = griddedInterpolant(this.mAerobicLiverStorageImprovment(:,2),  this.mAerobicLiverStorageImprovment(:,1));
            this.tInterpolations.hAerobicSlowTwitchDetraining       = griddedInterpolant(this.mAerobicSlowTwitchImprovment(:,2), 	this.mAerobicSlowTwitchImprovment(:,1));
            this.tInterpolations.hAnaerobicSlowTwitchDetraining     = griddedInterpolant(this.mAnaerobicSlowTwitchImprovment(:,2),  this.mAnaerobicSlowTwitchImprovment(:,1));
            this.tInterpolations.hAnaerobicFastTwitchDetraining     = griddedInterpolant(this.mAnaerobicFastTwitchImprovment(:,2),  this.mAnaerobicFastTwitchImprovment(:,1));

        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% Intialization parameters
            fLiverVolume    = 1;
            fAdiposeTissueVolume = 10;
            
            fMetabolismVolume = fLiverVolume + fAdiposeTissueVolume + 0.01;
            
            %% Stores and phases
            matter.store(this, 'Metabolism', fMetabolismVolume);
            % Initial mass according to the values provided in Markus
            % Czupalla dissertation chapter 11.1.1.2.9
            oLiver              = matter.phases.mixture(this.toStores.Metabolism,	'Liver',            'liquid',    struct('C6H12O6',  this.fAverageMaximumGlucoseContetLiver),                                                 this.oParent.fBodyCoreTemperature, 1e5);
            oAdiposeTissue      = matter.phases.mixture(this.toStores.Metabolism,	'AdiposeTissue',    'liquid',    struct('C51H98O6', this.fInitialFatMass, 'H2O', this.rH2OtoFatWithoutH2OMassRatio * this.fInitialFatMass),	this.oParent.fBodyCoreTemperature, 1e5);
            oMuscleTissue       = matter.phases.mixture(this.toStores.Metabolism,  	'MuscleTissue',     'liquid',    struct('C6H12O6',  this.fAverageMaximumGlucoseContetMuscle, 'Human_Tissue', this.fInitialMuscleMass),   	this.oParent.fBodyCoreTemperature, 1e5);

            
            % This is not a real human organ, it is just a modelling helper
            % to simplify all of the transformations etc that take place within
            % the human body. Also it represents the absorbed nutrients
            % from the digestion layer. Therefore, if the metabolism system
            % is empty, it means the humand consumed too little food and
            % cannot perform the work he us supposed to perform. For that
            % case we have to input checks before they are catched!
            oMetabolism         = matter.phases.mixture(this.toStores.Metabolism, 	'Metabolism',       'liquid',    struct('C3H7NO2', 0.2, 'C51H98O6', 0.3, 'C6H12O6', 0.5), this.oParent.fBodyCoreTemperature, 1e5);
            
            this.fInitialProteinMassMetabolism = oMetabolism.afMass(this.oMT.tiN2I.C3H7NO2);
            
            %% manipulators
            components.matter.Manips.ManualManipulator(this, 'MetabolismManipulator', oMetabolism, true);
            
            %% P2Ps
            components.matter.P2Ps.ManualP2P(this.toStores.Metabolism, 'Metabolism_to_Liver',           oMetabolism, oLiver);
            components.matter.P2Ps.ManualP2P(this.toStores.Metabolism, 'Metabolism_to_AdiposeTissue',   oMetabolism, oAdiposeTissue);
            components.matter.P2Ps.ManualP2P(this.toStores.Metabolism, 'Metabolism_to_MuscleTissue',    oMetabolism, oMuscleTissue);
            
        end
        
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
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
                    
                    arMaxChange = zeros(1,this.oMT.iSubstances);
                    arMaxChange(this.oMT.tiN2I.C6H12O6)     = 0.1;
                    arMaxChange(this.oMT.tiN2I.C51H98O6)    = 0.1;
                    arMaxChange(this.oMT.tiN2I.C6H12O6)     = 0.1;
                    arMaxChange(this.oMT.tiN2I.H2O)         = 0.1;
                    tTimeStepProperties.arMaxChange = arMaxChange;

                    oPhase.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            this.setThermalSolvers();
        end
        
        function setActivityLevel(this, rActivityLevel, bExercise, bPostExercise)
            this.rActivityLevel = rActivityLevel;
            this.bExercise      = bExercise;
            this.fCurrentStateStartTime = this.oTimer.fTime;
            if bExercise
                this.rExerciseTargetActivityLevel = rActivityLevel;
                this.rActivityLevelBeforeExercise = this.rActivityLevel;
            else
                this.rExerciseTargetActivityLevel = [];
            end
            
            if this.bPostExercise && ~bPostExercise
                this.mrExcessPostExerciseActivityLevel = zeros(2,0);
            end
            this.bPostExercise  = bPostExercise;
            
        end
        
        function resetAdditionalFoodEnergyDemand(this)
            % after each meal the additional energy demand is reset to 0
            this.fAdditionalFoodEnergyDemand = 0;
        end
    end
    
    methods (Access = protected)
        
        function CardiacPerformance(this)
            %
            % 
            % Corresponds to section 11.1.1.2.1 Cardiac Performance in the
            % dissertation from Markus Czupalla 
            
            % These values seem to be used only to calculate VO2 max
            
            
            this.fMaxHeartRate          = 220 - this.oParent.fAge;   % (beat/min)
            
            % Cardiac output is the blood output from the heart
            this.fMaxCardiacOutput      = (this.fMaxHeartRate * this.fMaxStrokeVolume);     % (l/min)
            
            this.fRestHeartRate         = this.fRestCardiacOutput/this.fRestStrokeVolume;

            this.fVO2_max  = this.tInterpolations.hVO2maxFromCardiacOutput(this.fMaxCardiacOutput);  % interpolation from McArdle
        end
        
        function BodyComposition(this)
            % BodyComposition calculates the current composition of the
            % human body based on the claculate fat mass difference and
            % muscle mass difference
            % 
            % Corresponds to section 11.1.1.2.2 Body Composition in the
            % dissertation from Markus Czupalla. The fat body mass ratio
            % was left out and instead the fat mass itself is used for the
            % calculations. This provides higher numeric accuracy as there
            % are less conversions.
            this.fBodyMass     	= this.fInitialBodyMassWithoutFatOrMuslce + this.toStores.Metabolism.toPhases.AdiposeTissue.afMass(this.oMT.tiN2I.C51H98O6) + this.toStores.Metabolism.toPhases.MuscleTissue.afMass(this.oMT.tiN2I.Human_Tissue);
            
            this.fLeanBodyMass	= this.fBodyMass - this.toStores.Metabolism.toPhases.AdiposeTissue.afMass(this.oMT.tiN2I.C51H98O6);
            this.fBMI           = this.fBodyMass / this.oParent.fHeight^2; 
            
            % This part is from the water balance model section 11.1.1.3.1
            % however it was moved here, in order to maintain one central
            % location for the body mass calculations. In the previous
            % model the parameters were sometimes represented twice, making
            % it difficult to ensure data consistency (e.g. Body mass was
            % defined in water layer to be 70 kg, while the metabolic layer
            % assumed 75 kg)
            this.fBoneMass      = this.fLeanBodyMass * this.rBoneToLeanMassRatio;
            this.fOrganMass     = this.fLeanBodyMass * this.rOrgansToLeanMassRatio;
            this.fTotalH2OMass  =       this.rH2OtoFatWithoutH2OMassRatio  	* this.toStores.Metabolism.toPhases.AdiposeTissue.afMass(this.oMT.tiN2I.C51H98O6) ...
                                    +   this.rH2OtoMuscleMassRatio          * this.toStores.Metabolism.toPhases.MuscleTissue.afMass(this.oMT.tiN2I.Human_Tissue)...
                                    +   this.rH2OtoBoneMassRatio            * this.fBoneMass ...
                                    +   this.rH2OtoOrganMassRatio           * this.fOrganMass;
                                
            this.fBoneMass = this.fLeanBodyMass * this.rBoneToLeanMassRatio;
            
            this.fH2OinBloodPlasmaMass          = this.rH2OinBloodPlasmaMassRatio           * this.fTotalH2OMass;
            this.fH2OinInterstitialFluidMass    = this.rH2OinInterstitialFluidMassRatio     * this.fTotalH2OMass;
            this.fH2OinIntracellulcarFluidMass  = this.rH2OinIntracellularFluidMassRatio    * this.fTotalH2OMass;
        end
        
        function [tfMetabolicFlowsRest] = RestingAerobicSystem(this)
            % This function is used to calculate the resting metabolic
            % system. It calculates the current metabolic flowrates for
            % fat, glucose, O2, CO2, H2O and ATP
            % Based on chapter 11.1.1.2.3 from the dissertation of Markus
            % Czupalla. All equation numbers also refer to the
            % dissertation.
            %
            % While not direct inputs, via the properties the following
            % inputs are made:
            % fLeanBodyMass
            
            % Resting Daily Energy Expenditure(J/day) 
            this.fRestingDailyEnergyExpenditure = (370 + 21.6 * this.fLeanBodyMass) * 4184;
            % Basal Metabolic Rate (J per s)
            this.fBaseMetabolicRate = this.fRestingDailyEnergyExpenditure/86400;
            
            % The original human model used a fixed value to calculate the
            % VO2 from the metabolic rate, but that is not correct as the
            % caloric value of oxygen depends on the current diet.
            % Therefore, the new model calculates the caloric value of
            % oxygen and we use the value from the last tick to calculate
            % the VO2:
            % Eq (11-85) resting O2 consumption
            fBaseOxygenConsumption = this.fBaseMetabolicRate / this.fCaloricValueOxygen; % kg/s
            
            % 1.243478737288464 is the density of oxygen according to V-HAB
            % matter table at 309.5 K and 1 bar, the 60 and 1000 are to
            % convert m^3 per s into l /min:
            this.fVO2_rest = (fBaseOxygenConsumption / 1.243478737288464) * 60 * 1000;
            
            [this.fRestMetabolicRate, fMolarOxygenConsumption, rOxygenForFat, rOxygenForGlucose] = this.calculateMetabolicRate(this.fVO2_rest, 0, 0);
            tfMetabolicFlowsRest = calculateMetabolicFlows(this, fMolarOxygenConsumption, rOxygenForFat, rOxygenForGlucose);
            
        end
        
        function rActivityOnset = ExerciseOnset(this)
            % This function is used to calculate the activity level when
            % exercise starts. Based on chapter 11.1.1.2.4 from the
            % dissertation of Markus Czupalla. All equation numbers also
            % refer to the dissertation.
            %
            % While not direct inputs, via the properties the following
            % inputs are made:
            % fCurrentStateStartTime
            % fVO2_max
            % rActivityLevel
            % fBaseMetabolicRate
            fExerciseTime = this.oTimer.fTime - this.fCurrentStateStartTime;
            fVO2_current = this.rExerciseTargetActivityLevel * this.fVO2_max;
            
            if fExerciseTime > 0

                [fMetabolicRateOnset, ~, ~, ~] = this.calculateMetabolicRate(fVO2_current, this.rActivityLevel, fExerciseTime);

                % Equation (11-106) but since we already calculated everything
                % in W we do not require the conversion factor
                fDeltaMetabolicRate = (fMetabolicRateOnset - this.fBaseMetabolicRate) * this.rMechanicalEfficiency;

                fVO2_LactateThreshold = this.rLactateActivityLevelThreshold * this.fVO2_max;

                fDeltaVO2_LactateThreshold = (this.fVO2_max - fVO2_LactateThreshold) * 0.4 + fVO2_LactateThreshold;

                if fVO2_current  >= this.fVO2_max
                    fG_1   = 9.99e-3;   % [l/ W min]
                    fG_tot = 13.33e-3;  % [l/ W min]
                    fTau_1 = 34;        % [s]
                    fTau_2 = 163;       % [s]
                elseif fVO2_current  > fDeltaVO2_LactateThreshold
                    fG_1   = 10.72e-3;  % [l/ W min]
                    fG_tot = 12.57e-3;  % [l/ W min]
                    fTau_1 = 34;        % [s]
                    fTau_2 = 170;       % [s]
                elseif fVO2_current > fVO2_LactateThreshold
                    fG_1   = 11.02e-3;  % [l/ W min]
                    fG_tot = 0;         % [l/ W min]
                    fTau_1 = 32;        % [s]
                    fTau_2 = 0;         % [s]
                else
                    fG_1   = 11.52e-3;  % [l/ W min]
                    fG_tot = 0;         % [l/ W min]
                    fTau_1 = 33;        % [s]
                    fTau_2 = 0;         % [s]
                end

                fA_1   = fG_1 * fDeltaMetabolicRate;
                fA_2   = (fG_1 - fG_tot) * fDeltaMetabolicRate;
                fA_tot = fA_1 + fA_2;

                if fA_2 > 0
                    fVO2_fast = (fA_1 / fA_tot) * fVO2_current;
                    fVO2_slow = (fA_2 / fA_tot) * fVO2_current;
                else
                    fVO2_fast = fVO2_current;
                    fVO2_slow = 0;
                end
                % Equation (11-116) without the conversion from minutes to
                % seconds because the time is already in seconds
                rActivityOnset = (fVO2_fast * (1 - exp( -fExerciseTime / fTau_1)) + fVO2_slow * (1 - exp( -fExerciseTime / fTau_2))) / (fVO2_fast + fVO2_slow);
            else
                rActivityOnset = 0;
            end
            % Equation (11-133)
            this.mrExcessPostExerciseActivityLevel(1, end+1) = fExerciseTime;
            this.mrExcessPostExerciseActivityLevel(2, end) =  (this.rExerciseTargetActivityLevel - this.rActivityLevelBeforeExercise) * (1 - rActivityOnset) + this.rActivityLevelBeforeExercise;
            
        end
        
        function tfMetabolicFlowsAerobicActivity = AerobicActivitySystem(this, rAerobicActivityLevel)
            % This function is used to calculate the metabolic flows during
            % activity. Based on chapter 11.1.1.2.5 from the dissertation
            % of Markus Czupalla. All equation numbers also
            % refer to the dissertation.
            
            % This is the VO2 used for the aerobic activity, it does not
            % include the resting aerobic activity, as that is calculated
            % seperatly
            fVO2_Exercise = ((this.fVO2_max - this.fVO2_rest) * rAerobicActivityLevel);
            fExerciseTime = this.oTimer.fTime - this.fCurrentStateStartTime;
            
            [this.fAerobicActivityMetabolicRate, fMolarOxygenConsumption, rOxygenForFat, rOxygenForGlucose] = this.calculateMetabolicRate(fVO2_Exercise, rAerobicActivityLevel, fExerciseTime);
            tfMetabolicFlowsAerobicActivity = calculateMetabolicFlows(this, fMolarOxygenConsumption, rOxygenForFat, rOxygenForGlucose);
        end
        
        function [fMetabolicRate, fMolarOxygenConsumption, rOxygenForFat, rOxygenForGlucose] = calculateMetabolicRate(this, fVO2, rActivityLevel, fExerciseTime)
            % Equation (11-86) resting o2 consumption (mol/s)
            fMolarOxygenConsumption = fVO2 / 60 / 1000 / this.fMolarVolume;

            % Resting Metabolism according to "Exercise Physiology: Basis
            % of Human Movement in Health and Disease", Brown, 2006, page
            % 77 Figure 4.2
            % At rest the energy is supplied by 50% from carbohydrates and
            % by 50% from fat. The protein metabolism is different as
            % proteins are used to built muscles and other required
            % substances and all remaining proteins are denaturated into
            % carbohydrates (McArdle, 2006, p. 152), (Design of a human
            % metabolic model for integrated ECLSS robustness analysis
            % Matthias Pfeiffer p.42)
            %
            % We only use the interpolation if the exercise time is smaller
            % than 30 minutes, because for longer exercises, the fat
            % metabolism is fast enough to ramp up its energy productions
            if rActivityLevel > 0.4 && fExerciseTime < 1800
                
                if fExerciseTime > 900 || this.bPostExercise
                    fExerciseTime = 900;
                end

                if rActivityLevel > 0.8
                    rActivityLevel = 0.8;
                end

                rOxygenForFat    = this.hExerciseOnsetFatUsage(fExerciseTime, rActivityLevel);
                rOxygenForGlucose = 1 - rOxygenForFat;
            else
                % The V-HAB model simply assumed a 50/50 split for this,
                % but that results in a not well regulated metabolism with
                % regard to the inputs, where glucose can be consumed
                % completly. Therefore, instead we check here the current
                % glucose content of the muscle and liver (which store
                % glucose within the body) and increase the fatty acid
                % usage if these values are low:
                fMuscleGlucose = this.toStores.Metabolism.toPhases.MuscleTissue.afMass(this.oMT.tiN2I.C6H12O6);
                fLiverGlucose  = this.toStores.Metabolism.toPhases.Liver.afMass(this.oMT.tiN2I.C6H12O6);

                rFatUsageRatioFromMuscle    = 2 * (this.fMaximumGlucoseContetMuscle - fMuscleGlucose) / this.fMaximumGlucoseContetMuscle;
                rFatUsageRatioFromLiver 	= 2 * (this.fMaximumGlucoseContetLiver - fLiverGlucose) / this.fMaximumGlucoseContetLiver;
                
                % Setup so that the oxygen consumption for fat is 50% if
                % both muscle and liver are at their normal storage values
                % for glucose. If they are below, more fat will be used up
                % to 100% if they are bewlow 50% of their capacity
                rFatRatio = (rFatUsageRatioFromMuscle + rFatUsageRatioFromLiver) / 4 + 0.5;
                
                if rFatRatio > 1
                    rFatRatio = 1;
                elseif rFatRatio < 0
                    rFatRatio = 0;
                end
                
                rOxygenForFat = rFatRatio;
                rOxygenForGlucose = 1 - rFatRatio;
            end
            % If you want to calculate how much of the required energy is
            % produced via fat or glucose using the oxygen ratios, these
            % equations can be used
            % rEnergyGainFromFat     = 1/(1 + (rOxygenConumptionForGlucose / rOxygenConsumptionForFat) * (this.oMT.ttxMatter.C6H12O6.fNutritionalEnergy  / this.oMT.ttxMatter.C16H32O2.fNutritionalEnergy));
            % rEnergyGainFromGlucose = 1 - rEnergyGainFromFat;
            
            % Originally this was Equation (11-92), however since the
            % caloric value of oxygen is now calculated anyway, we can use
            % that value to calculate the current metabolic rate
            fMetabolicRate      =   (fMolarOxygenConsumption * this.oMT.afMolarMass(this.oMT.tiN2I.O2)) * this.fCaloricValueOxygen; % [J/s]
        end
        
        function tfMetabolicFlows = calculateMetabolicFlows(this, fMolarOxygenConsumption, rOxygenForFat, rOxygenForGlucose)
            % Note that we seperate the corresponding metabolic flows which
            % were summed up in the dissertation into the parts from the
            % fat metabolism and the parts from the glucose metabolism!
            % This is necessary to include the protein metabolism in the
            % model!
            % Equation (11-93) and (11-94)
            tfMetabolicFlows.Glucose.fMolarOxygenConsumption    = fMolarOxygenConsumption * rOxygenForGlucose; % oxygen used for glucose oxidation (mol/s)
            tfMetabolicFlows.Fat.fMolarOxygenConsumption        = fMolarOxygenConsumption * rOxygenForFat;     % oxygen used for fatty acid oxidation (mol/s)
            
            % Equation (11-95)
            tfMetabolicFlows.Glucose.fMolarCO2Production        = tfMetabolicFlows.Glucose.fMolarOxygenConsumption   * this.tfMetabolicConversionFactors.rRespiratoryCoefficientGlucose;   % mol/s
            tfMetabolicFlows.Fat.fMolarCO2Production            = tfMetabolicFlows.Fat.fMolarOxygenConsumption       * this.tfMetabolicConversionFactors.rRespiratoryCoefficientFat;       % mol/s
            
            % Equation (11-96)
            tfMetabolicFlows.Glucose.fMolarATPProduction        = tfMetabolicFlows.Glucose.fMolarOxygenConsumption   * this.tfMetabolicConversionFactors.rATPCoefficientGlucose;   % mol/s
            tfMetabolicFlows.Fat.fMolarATPProduction            = tfMetabolicFlows.Fat.fMolarOxygenConsumption       * this.tfMetabolicConversionFactors.rATPCoefficientFat;    	% mol/s
            
            tfMetabolicFlows.Glucose.fMolarH2OProduction        = tfMetabolicFlows.Glucose.fMolarOxygenConsumption   * this.tfMetabolicConversionFactors.rH2OCoefficientGlucose;   % mol/s
            tfMetabolicFlows.Fat.fMolarH2OProduction            = tfMetabolicFlows.Fat.fMolarOxygenConsumption       * this.tfMetabolicConversionFactors.rH2OCoefficientFat;      	% mol/s

            tfMetabolicFlows.Glucose.fMolarGlucoseConsumption 	= tfMetabolicFlows.Glucose.fMolarOxygenConsumption   * this.tfMetabolicConversionFactors.rCoefficientGlucose;   	% mol/s
            tfMetabolicFlows.Fat.fMolarFatConsumption          	= tfMetabolicFlows.Fat.fMolarOxygenConsumption       * this.tfMetabolicConversionFactors.rCoefficientFat;        	% mol/s
            
            % Initialize the metabolic flows to 0, to prevent errors from
            % occuring
            tfMetabolicFlows.Protein.fMolarOxygenConsumption   = 0;
            tfMetabolicFlows.Protein.fMolarCO2Production       = 0;
            tfMetabolicFlows.Protein.fMolarH2OProduction       = 0;
            tfMetabolicFlows.Protein.fMolarATPProduction       = 0;
            tfMetabolicFlows.Protein.fMolarUreaProduction      = 0;
            tfMetabolicFlows.Protein.fMolarProteinConsumption  = 0;
            % For some calculations the total molar flows are required!
            % However these are calculated in the exec already including
            % the protein metabolism!
        end
        
        function AnaerobicActivitySystem(this)
            % This function is used to calculate the amount of anerobic
            % contribution to the current metabolic rate and from that
            % derives an VO2 value which is lacking and has to be
            % rebreathed later on.
            % Based on chapter 11.1.1.2.7 from the dissertation
            % of Markus Czupalla. All equation numbers also
            % refer to the dissertation.
            fExerciseTime = this.oTimer.fTime - this.fCurrentStateStartTime;
            
            % This corresponds to equation (11-135) to (11-140)
            fVO2_current = this.rActivityLevel * this.fVO2_max;
            [fMetabolicRateGoal, ~, ~, ~] = this.calculateMetabolicRate(fVO2_current, this.rActivityLevel, fExerciseTime);
            
            % This corresponds to equation (11-141) to (11-146)
            fVO2_LactateThreshold = this.rLactateActivityLevelThreshold * this.fVO2_max;
            [fMetabolicRateLactateThreshold, ~, ~, ~] = this.calculateMetabolicRate(fVO2_LactateThreshold, this.rLactateActivityLevelThreshold, 900);
            
            % This corresponds to equation (11-147) to (11-152)
            [fMetabolicRateAerobicMax, ~, ~, ~] = this.calculateMetabolicRate(this.fVO2_max, 1, 900);
            
            if fMetabolicRateGoal <= fMetabolicRateLactateThreshold
                fMetabolicRateOxygenDebt = fMetabolicRateGoal - this.fAerobicActivityMetabolicRate;
            elseif fMetabolicRateGoal >= fMetabolicRateAerobicMax
                fMetabolicRateOxygenDebt = (fMetabolicRateLactateThreshold - this.fAerobicActivityMetabolicRate) * this.fAlpha_Debt;
            else
                fMetabolicRateOxygenDebt = (fMetabolicRateAerobicMax - fMetabolicRateLactateThreshold) * this.fAlpha_Debt + (this.fAerobicActivityMetabolicRate - fMetabolicRateAerobicMax);
            end
            
            % Equation (11-156) but we have to convert the molar flows per
            % second into per minute and the volume in m^3 into l
            this.fVO2_Debt = (fMetabolicRateOxygenDebt * this.tfMetabolicFlowsAerobicActivity.fMolarOxygenConsumption * 60) / (this.fAerobicActivityMetabolicRate * this.fMolarVolume * 1000);
        end
        
        function AerobicEnergyMonitoring(this)
            % This function should be called before anything else is
            % update. It then uses the elapsed time since its last
            % execution and the current metabolic values to calculate some
            % integrated values for the metabolic rates!
            % Based on chapter 11.1.1.2.8 from the dissertation
            % of Markus Czupalla. All equation numbers also
            % refer to the dissertation.
            
            % We only want to sum up the values over one day, the variable
            % fLastAerobicMonitorExecution therefore stores the time in the
            % current day when the monitor was last executed. If a day has
            % past the value is set to 0 together with the monitored
            % integrals
            if mod(this.oTimer.fTime, 86400) < this.fLastAerobicMonitorExecution
                this.fLastAerobicMonitorExecution = 0;
                
                this.fTotalAerobicEnergyExpenditure             = 0;
                this.fTotalAerobicActivityEnergyExpenditure     = 0;
                this.fTotalBasicEnergyExpenditure               = 0;
                this.fTotalATPEnergy                            = 0;
            end
            fTimeStep = this.oTimer.fTime + this.fLastAerobicMonitorExecution;
            
            this.fTotalAerobicActivityEnergyExpenditure     = this.fTotalAerobicActivityEnergyExpenditure   + this.fAerobicActivityMetabolicRate * fTimeStep;
            this.fTotalBasicEnergyExpenditure               = this.fTotalBasicEnergyExpenditure             + this.fBaseMetabolicRate * fTimeStep;
            this.fTotalAerobicEnergyExpenditure             = this.fTotalAerobicActivityEnergyExpenditure   + this.fTotalBasicEnergyExpenditure;
            
            % Total ATP flow: (Note that ATP is not modelled as a mass in
            % V-HAB, but we calculate the total flow. Also the fatty acid
            % synthesis is set up to produce as much ATP as it consumes)
            % TO DO: Check where this is required
            fMolarATP_total = this.tfMetabolicFlowsRest.fMolarATPProduction  + this.tfMetabolicFlowsAerobicActivity.fMolarATPProduction;
            fEnergyRateATP  = this.fEnergyYieldATP * fMolarATP_total;
            
            this.fTotalATPEnergy = this.fTotalATPEnergy + fEnergyRateATP * fTimeStep;
        end
        
        function [tfP2PFlowRates, tfMetabolicFlowsFatSynthesis] = MetabolismSystem(this, fMolarFlowProteinsRemaining)
            % Based on chapter 11.1.1.2.9 from the dissertation
            % of Markus Czupalla. All equation numbers also
            % refer to the dissertation.
            fCurrentGlucoseMassLiver  = this.toStores.Metabolism.toPhases.Liver.afMass(this.oMT.tiN2I.C6H12O6);
            fCurrentGlucoseMassMuslce = this.toStores.Metabolism.toPhases.MuscleTissue.afMass(this.oMT.tiN2I.C6H12O6);
            
            this.fMaximumGlucoseContetLiver = this.fAverageMaximumGlucoseContetLiver * this.tTrainingFactors.rLiverStorageImprovement;
            this.fMaximumGlucoseContetMuscle = this.toStores.Metabolism.toPhases.MuscleTissue.afMass(this.oMT.tiN2I.Human_Tissue) * (this.fAverageMaximumGlucoseContetMuscle / this.fInitialMuscleMass);
            
            rGlucoseForLiver = 1 - (fCurrentGlucoseMassLiver / this.fMaximumGlucoseContetLiver);
            
            if fCurrentGlucoseMassMuslce < 0.2 * this.fMaximumGlucoseContetMuscle && (fCurrentGlucoseMassLiver > 0.2 * this.fMaximumGlucoseContetLiver)
                rGlucoseFromLiver = (1 - ((fCurrentGlucoseMassMuslce / this.fMaximumGlucoseContetLiver) / 0.2)) * 0.8 + 0.2;
            else
                rGlucoseFromLiver = this.rRatioOfGlucoseUsedFromLiver;
            end
            
            fGlucoseConsumptionMassFlowLiver = rGlucoseFromLiver * this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6) * (this.tfMetabolicFlowsAerobicActivity.fMolarGlucoseConsumption + this.tfMetabolicFlowsRest.fMolarGlucoseConsumption);
            
            if fCurrentGlucoseMassLiver >= 0.9 * this.fMaximumGlucoseContetLiver
                
                fGlucoseForLiver = this.oParent.toChildren.Digestion.fDigestedMassFlowCarbohydrates * rGlucoseForLiver;
                % Adjusted this equation to provide a smoother transition
                % between fat synthesis and no fat synthesis
                rUnusedGlucose = (fCurrentGlucoseMassLiver - 0.9 * this.fMaximumGlucoseContetLiver) / (0.1 * this.fMaximumGlucoseContetLiver);
                
                fUnusedMassFlowGlucoseLiver =       rUnusedGlucose  * fGlucoseForLiver;
                fGlucoseInputMassFlowLiver  = (1 -  rUnusedGlucose) * fGlucoseForLiver;
            else
                fUnusedMassFlowGlucoseLiver = 0;
                fGlucoseInputMassFlowLiver = this.oParent.toChildren.Digestion.fDigestedMassFlowCarbohydrates * rGlucoseForLiver;
            end
            
            rGlucoseForMuscle               = 1 - rGlucoseForLiver;
            rRatioOfGlucoseUsedFromMuscle   = 1 - rGlucoseFromLiver;
            
            fGlucoseConsumptionMassFlowMuscle = rRatioOfGlucoseUsedFromMuscle * this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6) * (this.tfMetabolicFlowsAerobicActivity.fMolarGlucoseConsumption + this.tfMetabolicFlowsRest.fMolarGlucoseConsumption);
            
            if fCurrentGlucoseMassMuslce >= 0.9 * this.fMaximumGlucoseContetMuscle
                
                fGlucoseForMuscle = this.oParent.toChildren.Digestion.fDigestedMassFlowCarbohydrates * rGlucoseForMuscle;
                % Adjusted this equation to provide a smoother transition
                % between fat synthesis and no fat synthesis
                rUnusedGlucose = (fCurrentGlucoseMassMuslce - 0.9 * this.fMaximumGlucoseContetMuscle) / (0.1 * this.fMaximumGlucoseContetMuscle);
                
                fUnusedMassFlowGlucoseMuscle =       rUnusedGlucose  * fGlucoseForMuscle;
                fGlucoseInputMassFlowMuscle  = (1 -  rUnusedGlucose) * fGlucoseForMuscle;
            else
                fUnusedMassFlowGlucoseMuscle = 0;
                fGlucoseInputMassFlowMuscle = this.oParent.toChildren.Digestion.fDigestedMassFlowCarbohydrates * rGlucoseForMuscle;
            end
            
            % Note that a negative value for this means that glucose is
            % taken out of the stored glucose in the liver/muscle
            tfP2PFlowRates.fGlucoseToLiver   = fGlucoseInputMassFlowLiver    - fGlucoseConsumptionMassFlowLiver;
            tfP2PFlowRates.fGlucoseToMuscle  = fGlucoseInputMassFlowMuscle   - fGlucoseConsumptionMassFlowMuscle;
            
            fUnusedMassFlowGlucose = fUnusedMassFlowGlucoseMuscle + fUnusedMassFlowGlucoseLiver;
            fUnusedMolarFlowGlucose = fUnusedMassFlowGlucose / this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6);
            fUnusedMolarFlowGlucoseInitial = fUnusedMolarFlowGlucose;
            
            % If we also have proteins remaining, we can calculate the
            % amount of fat synthesized from protein.
            if fMolarFlowProteinsRemaining > 0
                
                tfMetabolicFlowsFatSynthesis.Protein = this.calculateFatSynthesisFromProteins(fMolarFlowProteinsRemaining);
                
                fUnusedMolarFlowGlucose = fUnusedMolarFlowGlucose - tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowGlucoseforFatSynthesis;
                if fUnusedMolarFlowGlucose < 0
                    % in this case the currently unused glucose is not
                    % sufficient to generate the glycerol and the
                    % intermediate metabolites of the fatty acid synthesis.
                    % Since for this case proteins are remaining, no
                    % glucose is consumed during the resting and aerobic
                    % metabolic phases, since proteins are more difficult
                    % to store for the body.
                    % Since glucose is not beeing consumed in this case
                    % anywhere, we cannot free some of it by consuming
                    % less. Therefore, we adjust the metabolism to consume
                    % more proteins than fat to generate the required ATP:
                    fPotentialMolarFlowProteinToFat = fUnusedMolarFlowGlucoseInitial * (1 / this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientGlucose);
                    
                    fAdditionalMolarFlowProteinToMetabolism = fMolarFlowProteinsRemaining - fPotentialMolarFlowProteinToFat;
                    
                    fMolarFlowProteinsRemaining = fPotentialMolarFlowProteinToFat;
                    
                    tfMetabolicFlowsFatSynthesis.Protein = this.calculateFatSynthesisFromProteins(fMolarFlowProteinsRemaining);
                    
                    % Now adjust the metabolite usage for fat and proteins:
                    fAdditionalOxygen   = fAdditionalMolarFlowProteinToMetabolism * (1 / this.tfMetabolicConversionFactors.rProteinMetabolism);
                    fAdditionalATP      = fAdditionalOxygen * this.tfMetabolicConversionFactors.rProteinMetabolismATP;
                    
                    if fAdditionalATP > this.tfMetabolicFlowsRest.Fat.fMolarATPProduction
                        fAdditionalATPfromProteinRest       = this.tfMetabolicFlowsRest.Fat.fMolarATPProduction;
                        fAdditionalATPfromProteinActivity   = fAdditionalATP - fAdditionalATPfromProteinRest;
                    else
                        fAdditionalATPfromProteinRest       = fAdditionalATP;
                        fAdditionalATPfromProteinActivity   = 0;
                    end
                    
                    fAdditionalOxygen	= fAdditionalATPfromProteinRest * (1 / this.tfMetabolicConversionFactors.rProteinMetabolismATP);
                    fAdditionalCO2      = fAdditionalOxygen             * this.tfMetabolicConversionFactors.rRespiratoryCoefficientProteins;
                    fAdditionalH2O      = fAdditionalOxygen             * this.tfMetabolicConversionFactors.rProteinMetabolismH2O;
                    fAdditionalUrea     = fAdditionalOxygen             * this.tfMetabolicConversionFactors.rProteinMetabolismUrea;
                    fAdditionalProtein  = fAdditionalOxygen             * this.tfMetabolicConversionFactors.rProteinMetabolism;
                    
                    this.tfMetabolicFlowsRest.Protein.fMolarATPProduction       = fAdditionalATPfromProteinRest	+ this.tfMetabolicFlowsRest.Protein.fMolarATPProduction;
                    this.tfMetabolicFlowsRest.Protein.fMolarCO2Production       = fAdditionalCO2                + this.tfMetabolicFlowsRest.Protein.fMolarCO2Production;
                    this.tfMetabolicFlowsRest.Protein.fMolarH2OProduction       = fAdditionalH2O                + this.tfMetabolicFlowsRest.Protein.fMolarH2OProduction;
                    this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption   = fAdditionalOxygen             + this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption;
                    this.tfMetabolicFlowsRest.Protein.fMolarUreaProduction      = fAdditionalUrea               + this.tfMetabolicFlowsRest.Protein.fMolarUreaProduction;
                    this.tfMetabolicFlowsRest.Protein.fMolarProteinConsumption  = fAdditionalProtein            + this.tfMetabolicFlowsRest.Protein.fMolarProteinConsumption;
                    
                    % In this case we calculate by how much we have to
                    % lower the fat consumption metabolism to correpond
                    % to the addiitional atp from proteins
                    fReducedOxygen  = fAdditionalATPfromProteinRest * (1 / this.tfMetabolicConversionFactors.rATPCoefficientFat);
                    fReducedFat     = fReducedOxygen * this.tfMetabolicConversionFactors.rCoefficientFat;
                    fReducedH2O     = fReducedOxygen * this.tfMetabolicConversionFactors.rH2OCoefficientFat;
                    fReducedCO2     = fReducedOxygen * this.tfMetabolicConversionFactors.rRespiratoryCoefficientFat;

                    this.tfMetabolicFlowsRest.Fat.fMolarATPProduction       = - fAdditionalATPfromProteinRest   + this.tfMetabolicFlowsRest.Fat.fMolarATPProduction;
                    this.tfMetabolicFlowsRest.Fat.fMolarCO2Production       = - fReducedCO2                     + this.tfMetabolicFlowsRest.Fat.fMolarCO2Production;
                    this.tfMetabolicFlowsRest.Fat.fMolarFatConsumption      = - fReducedFat                     + this.tfMetabolicFlowsRest.Fat.fMolarFatConsumption;
                    this.tfMetabolicFlowsRest.Fat.fMolarH2OProduction       = - fReducedH2O                     + this.tfMetabolicFlowsRest.Fat.fMolarH2OProduction;
                    this.tfMetabolicFlowsRest.Fat.fMolarOxygenConsumption   = - fReducedOxygen                  + this.tfMetabolicFlowsRest.Fat.fMolarOxygenConsumption;
                    
                    % now adjust the overal flowrates for resting
                    % metabolism
                    this.tfMetabolicFlowsRest.fMolarATPProduction       = this.tfMetabolicFlowsRest.Fat.fMolarATPProduction     + this.tfMetabolicFlowsRest.Protein.fMolarATPProduction;
                    this.tfMetabolicFlowsRest.fMolarCO2Production       = this.tfMetabolicFlowsRest.Fat.fMolarCO2Production     + this.tfMetabolicFlowsRest.Protein.fMolarCO2Production;
                    this.tfMetabolicFlowsRest.fMolarH2OProduction       = this.tfMetabolicFlowsRest.Fat.fMolarH2OProduction     + this.tfMetabolicFlowsRest.Protein.fMolarH2OProduction;
                    this.tfMetabolicFlowsRest.fMolarOxygenConsumption	= this.tfMetabolicFlowsRest.Fat.fMolarOxygenConsumption + this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption;
                    this.tfMetabolicFlowsRest.fMolarFatConsumption      = this.tfMetabolicFlowsRest.Fat.fMolarFatConsumption;
                    this.tfMetabolicFlowsRest.fMolarProteinConsumption	= this.tfMetabolicFlowsRest.Protein.fMolarProteinConsumption;
                    this.tfMetabolicFlowsRest.fMolarUreaProduction      = this.tfMetabolicFlowsRest.Protein.fMolarUreaProduction; 
                    
                    if fAdditionalATPfromProteinActivity ~= 0
                        
                        if fAdditionalATPfromProteinActivity > this.tfMetabolicFlowsAerobicActivity.Fat.fMolarATPProduction
                            % Note that additional ATP from proteins can be
                            % higher than the fat production of ATP, in this
                            % case we reduce the amount of ATP produced by
                            % proteins, which results in proteins beeing
                            % stored in the metabolism phase, which usually
                            % does not occur. These additional proteins
                            % will then be consumed over time once the
                            % conditions are better again
                            fAdditionalATPfromProteinActivity = this.tfMetabolicFlowsAerobicActivity.Fat.fMolarATPProduction;
                        end
                        
                        % Now adjust the metabolite usage for fat and proteins:
                        fAdditionalOxygen	= fAdditionalATPfromProteinActivity * (1 / this.tfMetabolicConversionFactors.rProteinMetabolismATP);
                        fAdditionalCO2      = fAdditionalOxygen                 * this.tfMetabolicConversionFactors.rRespiratoryCoefficientProteins;
                        fAdditionalH2O      = fAdditionalOxygen                 * this.tfMetabolicConversionFactors.rProteinMetabolismH2O;
                        fAdditionalUrea     = fAdditionalOxygen                 * this.tfMetabolicConversionFactors.rProteinMetabolismUrea;
                        fAdditionalProtein  = fAdditionalOxygen                 * this.tfMetabolicConversionFactors.rProteinMetabolism;

                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarATPProduction       = fAdditionalATPfromProteinActivity + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarATPProduction;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarCO2Production       = fAdditionalCO2                    + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarCO2Production;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarH2OProduction       = fAdditionalH2O                    + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarH2OProduction;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption   = fAdditionalOxygen                 + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarUreaProduction      = fAdditionalUrea                   + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarUreaProduction;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarProteinConsumption  = fAdditionalProtein                + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarProteinConsumption;

                        fReducedOxygen  = fAdditionalATPfromProteinActivity * (1 / this.tfMetabolicConversionFactors.rATPCoefficientFat);
                        fReducedFat     = fReducedOxygen * this.tfMetabolicConversionFactors.rCoefficientFat;
                        fReducedH2O     = fReducedOxygen * this.tfMetabolicConversionFactors.rH2OCoefficientFat;
                        fReducedCO2     = fReducedOxygen * this.tfMetabolicConversionFactors.rRespiratoryCoefficientFat;

                        this.tfMetabolicFlowsAerobicActivity.Fat.fMolarATPProduction       = - fAdditionalATPfromProteinActivity   + this.tfMetabolicFlowsAerobicActivity.Fat.fMolarATPProduction;
                        this.tfMetabolicFlowsAerobicActivity.Fat.fMolarCO2Production       = - fReducedCO2                         + this.tfMetabolicFlowsAerobicActivity.Fat.fMolarCO2Production;
                        this.tfMetabolicFlowsAerobicActivity.Fat.fMolarFatConsumption      = - fReducedFat                         + this.tfMetabolicFlowsAerobicActivity.Fat.fMolarFatConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Fat.fMolarH2OProduction       = - fReducedH2O                         + this.tfMetabolicFlowsAerobicActivity.Fat.fMolarH2OProduction;
                        this.tfMetabolicFlowsAerobicActivity.Fat.fMolarOxygenConsumption   = - fReducedOxygen                      + this.tfMetabolicFlowsAerobicActivity.Fat.fMolarOxygenConsumption;

                        % now adjust the overal flowrates for resting
                        % metabolism
                        this.tfMetabolicFlowsAerobicActivity.fMolarATPProduction        = this.tfMetabolicFlowsAerobicActivity.Fat.fMolarATPProduction     + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarATPProduction;
                        this.tfMetabolicFlowsAerobicActivity.fMolarCO2Production        = this.tfMetabolicFlowsAerobicActivity.Fat.fMolarCO2Production     + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarCO2Production;
                        this.tfMetabolicFlowsAerobicActivity.fMolarH2OProduction        = this.tfMetabolicFlowsAerobicActivity.Fat.fMolarH2OProduction     + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarH2OProduction;
                        this.tfMetabolicFlowsAerobicActivity.fMolarOxygenConsumption    = this.tfMetabolicFlowsAerobicActivity.Fat.fMolarOxygenConsumption + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.fMolarFatConsumption       = this.tfMetabolicFlowsAerobicActivity.Fat.fMolarFatConsumption;
                        this.tfMetabolicFlowsAerobicActivity.fMolarProteinConsumption	= this.tfMetabolicFlowsAerobicActivity.Protein.fMolarProteinConsumption;
                        this.tfMetabolicFlowsAerobicActivity.fMolarUreaProduction       = this.tfMetabolicFlowsAerobicActivity.Protein.fMolarUreaProduction;
                    end
                    % In this case we have no unused glucose for ATP
                    % production or fatty acid storage
                    fUnusedMolarFlowGlucose = 0;
                end
                
                % Note that synthesizing fat from proteins requires ATP
                fAddtionalOxygen    = - tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowATPforFatSynthesis * (1 / this.tfMetabolicConversionFactors.rATPCoefficientGlucose);
                fAdditionalGlucose  = fAddtionalOxygen * this.tfMetabolicConversionFactors.rCoefficientGlucose;
                
                if fUnusedMolarFlowGlucose > fAdditionalGlucose
                    % In this case the currently unused glucose can be used
                    % to generate the required ATP for fat synthesis from
                    % proteins
                    fAddtionalCO2       = fAddtionalOxygen * this.tfMetabolicConversionFactors.rRespiratoryCoefficientGlucose;
                    fAdditionalH2O      = fAddtionalOxygen * this.tfMetabolicConversionFactors.rH2OCoefficientGlucose;

                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowO2forFatSynthesis        = fAddtionalOxygen      + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowO2forFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowGlucoseforFatSynthesis   = fAdditionalGlucose    + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowGlucoseforFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowCO2fromFatSynthesis      = fAddtionalCO2         + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowCO2fromFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowH2OfromFatSynthesis      = fAdditionalH2O        + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowH2OfromFatSynthesis;

                    fUnusedMolarFlowGlucose = fUnusedMolarFlowGlucose - fAdditionalGlucose;
                else
                    % In this case the missing ATP must be generated by the
                    % proteins, however, that also reduces the amount of
                    % fat synthesized:
                    fAddtionalOxygen    = fUnusedMolarFlowGlucose * (1 / this.tfMetabolicConversionFactors.rCoefficientGlucose);
                    fAddtionalCO2       = fAddtionalOxygen * this.tfMetabolicConversionFactors.rRespiratoryCoefficientGlucose;
                    fAdditionalH2O      = fAddtionalOxygen * this.tfMetabolicConversionFactors.rH2OCoefficientGlucose;
                    fAdditionalATP      = fAddtionalOxygen * this.tfMetabolicConversionFactors.rATPCoefficientGlucose;
                    
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowO2forFatSynthesis        = fAddtionalOxygen      + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowO2forFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowGlucoseforFatSynthesis   = fAdditionalGlucose    + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowGlucoseforFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowCO2fromFatSynthesis      = fAddtionalCO2         + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowCO2fromFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowH2OfromFatSynthesis      = fAdditionalH2O        + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowH2OfromFatSynthesis;

                    fError = 1;
                    iIteration = 1;
                    fProteinsForFatPrevious = fMolarFlowProteinsRemaining;
                    while fError > 1e-12 && iIteration < 200
                        fRemainingATP       = tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowATPforFatSynthesis + fAdditionalATP;
                        fAddtionalOxygen    = - fRemainingATP * (1 / this.tfMetabolicConversionFactors.rProteinMetabolismATP);
                        fAdditionalProtein  = fAddtionalOxygen * this.tfMetabolicConversionFactors.rProteinMetabolism;

                        fProteinsForFat = fMolarFlowProteinsRemaining - fAdditionalProtein;
                        tfMetabolicFlowsFatSynthesis.Protein = this.calculateFatSynthesisFromProteins(fProteinsForFat);
                        
                        fError = abs(fProteinsForFatPrevious - fProteinsForFat);
                        fProteinsForFatPrevious = fProteinsForFat;
                        iIteration = iIteration + 1;
                    end
                    fAddtionalCO2       = fAddtionalOxygen * this.tfMetabolicConversionFactors.rRespiratoryCoefficientProteins;
                    fAdditionalH2O      = fAddtionalOxygen * this.tfMetabolicConversionFactors.rProteinMetabolismH2O;
                    fAdditionalUrea     = fAddtionalOxygen * this.tfMetabolicConversionFactors.rProteinMetabolismUrea;
                    
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowO2forFatSynthesis        = fAddtionalOxygen      + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowO2forFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowCO2fromFatSynthesis      = fAddtionalCO2         + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowCO2fromFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowH2OfromFatSynthesis      = fAdditionalH2O        + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowH2OfromFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowUreafromFatSynthesis     = fAdditionalUrea       + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowUreafromFatSynthesis;
                    tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowProteinforFatSynthesis   = fAdditionalProtein    + tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowProteinforFatSynthesis;
                    
                    fUnusedMolarFlowGlucose = 0;
                end
                
            
            else
                tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowFatfromFatSynthesis      = 0;
                tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowO2forFatSynthesis        = 0;
                tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowGlucoseforFatSynthesis   = 0;
                tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowCO2fromFatSynthesis      = 0;
                tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowH2OfromFatSynthesis      = 0;
                tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowUreafromFatSynthesis     = 0;
                tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowATPforFatSynthesis       = 0;
                tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowProteinforFatSynthesis   = 0;
            end
                
            if fUnusedMolarFlowGlucose > 0
                
                % If the fat synthesis produce excess ATP that is currently
                % neglected. Previously the human model assumed that simply
                % no ATP is consumed or generated during the synthesis
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowGlucoseforFatSynthesis   = fUnusedMolarFlowGlucose;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowFatfromFatSynthesis      = this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficient          * fUnusedMolarFlowGlucose;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowO2forFatSynthesis        = this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficientOxygen    * fUnusedMolarFlowGlucose;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowCO2fromFatSynthesis      = this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficientCO2       * fUnusedMolarFlowGlucose;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowH2OfromFatSynthesis      = this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficientH2O       * fUnusedMolarFlowGlucose;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowATPfromFatSynthesis      = this.tfMetabolicConversionFactors.Glucose.rFatsynthesisCoefficientATP       * fUnusedMolarFlowGlucose;
            else
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowGlucoseforFatSynthesis   = 0;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowFatfromFatSynthesis      = 0;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowO2forFatSynthesis        = 0;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowCO2fromFatSynthesis      = 0;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowH2OfromFatSynthesis      = 0;
                tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowATPfromFatSynthesis      = 0;
            end
            
            % Now we combine the metabolic flows for fat synthesis from all
            % nutrient sources:
            tfMetabolicFlowsFatSynthesis.fMolarFatProduction        = tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowFatfromFatSynthesis    + tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowFatfromFatSynthesis;
            tfMetabolicFlowsFatSynthesis.fMolarO2Consumption        = tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowO2forFatSynthesis      + tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowO2forFatSynthesis;
            tfMetabolicFlowsFatSynthesis.fMolarGlucoseConsumption   = tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowGlucoseforFatSynthesis + tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowGlucoseforFatSynthesis;
            tfMetabolicFlowsFatSynthesis.fMolarCO2Production        = tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowCO2fromFatSynthesis    + tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowCO2fromFatSynthesis;
            tfMetabolicFlowsFatSynthesis.fMolarH2OProduction        = tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowH2OfromFatSynthesis    + tfMetabolicFlowsFatSynthesis.Glucose.fMolarFlowH2OfromFatSynthesis;
            tfMetabolicFlowsFatSynthesis.fMolarUreaProduction       = tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowUreafromFatSynthesis;
            tfMetabolicFlowsFatSynthesis.fMolarProteinConsumption   = tfMetabolicFlowsFatSynthesis.Protein.fMolarFlowProteinforFatSynthesis;

            % At this point we can now calculate the total adipose tissue
            % mass change. The digested fat mass is modelled to be
            % transfered into adipose tissue mass
            tfP2PFlowRates.fFatToAdiposeTissue = this.oParent.toChildren.Digestion.fDigestedMassFlowFat + (tfMetabolicFlowsFatSynthesis.fMolarFatProduction - (this.tfMetabolicFlowsAerobicActivity.fMolarFatConsumption + this.tfMetabolicFlowsRest.fMolarFatConsumption)) * this.oMT.afMolarMass(this.oMT.tiN2I.C51H98O6);
            tfP2PFlowRates.fH2OToAdiposeTissue = this.rH2OtoFatWithoutH2OMassRatio * tfP2PFlowRates.fFatToAdiposeTissue;
            
        end
        
        function ProteinFatSynthesis = calculateFatSynthesisFromProteins(this, fMolarFlowProteinToFat)
            
            % 2 C6H12O6 + 24 C3H7NO2 + 11.5 O2 -> C51H98O6 + 12 CH4N2O + 21 CO2 + 23 H2O
            ProteinFatSynthesis.fMolarFlowFatfromFatSynthesis      = fMolarFlowProteinToFat * this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficient;
            ProteinFatSynthesis.fMolarFlowO2forFatSynthesis        = fMolarFlowProteinToFat * this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientOxygen;
            ProteinFatSynthesis.fMolarFlowGlucoseforFatSynthesis   = fMolarFlowProteinToFat * this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientGlucose;
            ProteinFatSynthesis.fMolarFlowCO2fromFatSynthesis      = fMolarFlowProteinToFat * this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientCO2;
            ProteinFatSynthesis.fMolarFlowH2OfromFatSynthesis      = fMolarFlowProteinToFat * this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientH2O;
            ProteinFatSynthesis.fMolarFlowUreafromFatSynthesis     = fMolarFlowProteinToFat * this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientUrea;
            ProteinFatSynthesis.fMolarFlowATPforFatSynthesis       = fMolarFlowProteinToFat * this.tfMetabolicConversionFactors.Protein.rFatsynthesisCoefficientATP;
            ProteinFatSynthesis.fMolarFlowProteinforFatSynthesis   = fMolarFlowProteinToFat;

        end
        
        function tfMetabolicFlowsProteins = ProteinMetabolism(this, fMuscleChangeMassFlow)
            % Based on biochemistry from "Biochemie" 2013 Berg et al
            fMetabolizedFlowrateProteins = this.oParent.toChildren.Digestion.fDigestedMassFlowProteins - (1 - this.rH2OtoMuscleMassRatio) * fMuscleChangeMassFlow;
            
            fMetabolizedFlowrateProteins = fMetabolizedFlowrateProteins + (this.toStores.Metabolism.toPhases.Metabolism.afMass(this.oMT.tiN2I.C3H7NO2) - this.fInitialProteinMassMetabolism) / 3600;
            
            if fMetabolizedFlowrateProteins < 0
                % In this case ammino acids must be synthesized from
                % glucose. This process is not modelled in detail, but the
                % missing mass for the muscle creation is then taken from
                % the consumed glucose
                tfMetabolicFlowsProteins.fGlucoseToMuscleMassFlow        = -fMetabolizedFlowrateProteins;
                fMetabolizedFlowrateProteins    = 0;
            else
                tfMetabolicFlowsProteins.fGlucoseToMuscleMassFlow        = 0;
            end
            
            tfMetabolicFlowsProteins.fMetabolizedMolarFlowProteins = fMetabolizedFlowrateProteins / this.oMT.afMolarMass(this.oMT.tiN2I.C3H7NO2);
            
            tfMetabolicFlowsProteins.fMolarOxygenConsumption    = (1/this.tfMetabolicConversionFactors.rProteinMetabolism)          * tfMetabolicFlowsProteins.fMetabolizedMolarFlowProteins;
            tfMetabolicFlowsProteins.fMolarATPProduction        = this.tfMetabolicConversionFactors.rProteinMetabolismATP           * tfMetabolicFlowsProteins.fMolarOxygenConsumption;
            tfMetabolicFlowsProteins.fMolarH2OProduction        = this.tfMetabolicConversionFactors.rProteinMetabolismH2O           * tfMetabolicFlowsProteins.fMolarOxygenConsumption;
            tfMetabolicFlowsProteins.fMolarUreaProduction       = this.tfMetabolicConversionFactors.rProteinMetabolismUrea          * tfMetabolicFlowsProteins.fMolarOxygenConsumption;
            tfMetabolicFlowsProteins.fMolarCO2Production        = this.tfMetabolicConversionFactors.rRespiratoryCoefficientProteins * tfMetabolicFlowsProteins.fMolarOxygenConsumption;
            
        end
        
        function TrainingDetraining(this)
            % Based on chapter 11.1.1.2.10 from the dissertation
            % of Markus Czupalla. All equation numbers also
            % refer to the dissertation.
            %
            % Check once per day if the training threshold was reached:
            if mod(this.oTimer.fTime, 86400) < this.fTimeModuloDay
                if this.bDailyAnaerobicTrainingThresholdReached
                    this.iAnaerobicTrainingDays = this.iAnaerobicTrainingDays + 1;
                elseif this.bDailyAerobicTrainingThresholdReached
                    this.iAerobicTrainingDays   = this.iAerobicTrainingDays + 1;
                else
                    this.iRestDays              = this.iRestDays + 1;
                end
            end
            this.fTimeModuloDay = mod(this.oTimer.fTime, 86400);
            
            % In order to check if a week has passed, we store the modulo
            % values of the current time in the property fTimeModuloWeek,
            % if a full week has passed the value from the last execution
            % is higher than the current value, thus triggering this
            % calculation
            if mod(this.oTimer.fTime, 604800) < this.fTimeModuloWeek
                if this.iAnaerobicTrainingDays
                    this.iAerobicTrainingWeeks   = this.iAerobicTrainingWeeks + 1;
                else
                    this.iAerobicDetrainingWeeks = this.iAerobicDetrainingWeeks + 1;
                end
                if this.iAerobicTrainingDays
                    this.iAnaerobicTrainingWeeks    = this.iAnaerobicTrainingWeeks + 1;
                else
                    this.iAnaerobicDetrainingWeeks	= this.iAnaerobicDetrainingWeeks + 1;
                end
                
                % The human is fully detrained once the total sum of the
                % detraining weeks becomes larger than the total sum of
                % training weeks
                if this.iAerobicTrainingWeeks < this.iAerobicDetrainingWeeks
                    this.iAerobicTrainingWeeks      = 0;
                    this.iAerobicDetrainingWeeks    = 0;
                end
                if this.iAnaerobicTrainingWeeks < this.iAnaerobicDetrainingWeeks
                    this.iAnaerobicTrainingWeeks    = 0;
                    this.iAnaerobicDetrainingWeeks  = 0;
                end
                % Equation 11-220 and Section 11.1.1.2.11
                fNewSlowTwitchMass = this.rSlowTwitchInitial * this.fInitialMuscleMass * ((this.tTrainingFactors.rAerobicSlowTwitchImprovement + this.tTrainingFactors.rAnaerobicSlowTwitchImprovement) - 1);
                fNewFastTwitchMass = this.rFastTwitchInitial * this.fInitialMuscleMass * this.tTrainingFactors.rAnaerobicFastTwitchImprovement;
                this.fMuscleChangeMassFlow = ((fNewSlowTwitchMass + fNewFastTwitchMass) - this.fInitialMuscleMass) / (7 * 24 * 3600);
            end
            
            rMaxStrokeVolumeImprovement         = this.tInterpolations.hStrokeVolumeImprovement(this.iAerobicTrainingWeeks);
            rMaxLiverStorageImprovement         = this.tInterpolations.hAerobicLiverStorageImprovement(this.iAerobicTrainingWeeks);
            rMaxAerobicSlowTwitchImprovement    = this.tInterpolations.hAerobicSlowTwitchImprovment(this.iAerobicTrainingWeeks);
            rMaxAnaerobicSlowTwitchImprovement  = this.tInterpolations.hAnaerobicSlowTwitchImprovment(this.iAnaerobicTrainingWeeks);
            rMaxAnaerobicFastTwitchImprovement  = this.tInterpolations.hAnaerobicFastTwitchImprovment(this.iAnaerobicTrainingWeeks);
            
            fDetrainingDurationStrokeVolume         = this.tInterpolations.hStrokeVolumeDetraining(this.iAerobicDetrainingWeeks);
            fDetrainingDurationLiverStorage         = this.tInterpolations.hAerobicLiverStorageDetraining(this.iAerobicDetrainingWeeks);
            fDetrainingDurationAerobicSlowTwitch	= this.tInterpolations.hAerobicSlowTwitchDetraining(this.iAerobicDetrainingWeeks);
            fDetrainingDurationAnaerobicSlowTwitch  = this.tInterpolations.hAnaerobicSlowTwitchDetraining(this.iAnaerobicDetrainingWeeks);
            fDetrainingDurationAnaerobicFastTwitch	= this.tInterpolations.hAnaerobicFastTwitchDetraining(this.iAnaerobicDetrainingWeeks);
            
            this.tTrainingFactors.rStrokeVolumeImprovement            = rMaxStrokeVolumeImprovement           - ((rMaxStrokeVolumeImprovement - 1)        * (this.iAerobicDetrainingWeeks   / fDetrainingDurationStrokeVolume));
            this.tTrainingFactors.rLiverStorageImprovement            = rMaxLiverStorageImprovement           - ((rMaxLiverStorageImprovement - 1)        * (this.iAerobicDetrainingWeeks   / fDetrainingDurationLiverStorage));
            this.tTrainingFactors.rAerobicSlowTwitchImprovement       = rMaxAerobicSlowTwitchImprovement      - ((rMaxAerobicSlowTwitchImprovement - 1)   * (this.iAerobicDetrainingWeeks   / fDetrainingDurationAerobicSlowTwitch));
            this.tTrainingFactors.rAnaerobicSlowTwitchImprovement     = rMaxAnaerobicSlowTwitchImprovement    - ((rMaxAnaerobicSlowTwitchImprovement - 1) * (this.iAnaerobicDetrainingWeeks / fDetrainingDurationAnaerobicSlowTwitch));
            this.tTrainingFactors.rAnaerobicFastTwitchImprovement     = rMaxAnaerobicFastTwitchImprovement    - ((rMaxAnaerobicFastTwitchImprovement - 1) * (this.iAnaerobicDetrainingWeeks / fDetrainingDurationAnaerobicFastTwitch));
            
            rBaseAndMaxStrokeVolume = this.tInterpolations.hBaseStrokeVolumeImprovement(this.tTrainingFactors.rStrokeVolumeImprovement);
            
            this.fMaxStrokeVolume   = 0.1 * this.tTrainingFactors.rStrokeVolumeImprovement;
            this.fRestStrokeVolume  = this.fMaxStrokeVolume / rBaseAndMaxStrokeVolume;
            
            this.fTimeModuloWeek = mod(this.oTimer.fTime, 604800);
        end
        
        function fMolarFlowProteinsRemaining = calculateFinalMetabolicFlows(this)
            
        
            if this.bExercise
                this.rActivityLevel = (this.rExerciseTargetActivityLevel - this.rActivityLevelBeforeExercise) * this.ExerciseOnset() + this.rActivityLevelBeforeExercise;
                % Post exercise activity level is set in the parent human
                % system
            end
            
            this.tfMetabolicFlowsAerobicActivity = this.AerobicActivitySystem(this.rActivityLevel);
            
            % So basically we calculate the resting and exercise metabolic
            % flows without considering the proteins. Then we check how
            % much ATP is generated from the proteins, how much glucose (if
            % any) is required for amino acid synthesis for muscle mass and
            % how much glucose must still be converted to ATP. After this
            % we can calculate how much glucose is unused and can be used
            % for fatty acid synthesis!
            if this.tfMetabolicFlowsRest.Glucose.fMolarATPProduction > this.tfMetabolicFlowsProteins.fMolarATPProduction
                % First we calculate how much ATP is still produced from
                % glucose:
                this.tfMetabolicFlowsRest.Glucose.fMolarATPProduction       = this.tfMetabolicFlowsRest.Glucose.fMolarATPProduction - this.tfMetabolicFlowsProteins.fMolarATPProduction;
                
                % Then we can convert the ATP flow from glucose into the
                % molar oxgyen flow, using the inverse stochiometric
                % conversion factor:
                this.tfMetabolicFlowsRest.Glucose.fMolarOxygenConsumption   = (1 / this.tfMetabolicConversionFactors.rATPCoefficientGlucose) * this.tfMetabolicFlowsRest.Glucose.fMolarATPProduction;
                % The other molar flows can then be calculated from the
                % oxygen consumption, using the stochiometric conversion
                % factors:
                this.tfMetabolicFlowsRest.Glucose.fMolarCO2Production       = this.tfMetabolicConversionFactors.rRespiratoryCoefficientGlucose  * this.tfMetabolicFlowsRest.Glucose.fMolarOxygenConsumption;
                this.tfMetabolicFlowsRest.Glucose.fMolarH2OProduction       = this.tfMetabolicConversionFactors.rH2OCoefficientGlucose          * this.tfMetabolicFlowsRest.Glucose.fMolarOxygenConsumption;
                this.tfMetabolicFlowsRest.Glucose.fMolarGlucoseConsumption  = this.tfMetabolicConversionFactors.rCoefficientGlucose             * this.tfMetabolicFlowsRest.Glucose.fMolarOxygenConsumption;

                this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption   = this.tfMetabolicFlowsProteins.fMolarOxygenConsumption;
                this.tfMetabolicFlowsRest.Protein.fMolarCO2Production       = this.tfMetabolicFlowsProteins.fMolarCO2Production;
                this.tfMetabolicFlowsRest.Protein.fMolarH2OProduction       = this.tfMetabolicFlowsProteins.fMolarH2OProduction;
                this.tfMetabolicFlowsRest.Protein.fMolarATPProduction       = this.tfMetabolicFlowsProteins.fMolarATPProduction;
                this.tfMetabolicFlowsRest.Protein.fMolarUreaProduction      = this.tfMetabolicFlowsProteins.fMolarUreaProduction;
                this.tfMetabolicFlowsRest.Protein.fMolarProteinConsumption  = this.tfMetabolicFlowsProteins.fMetabolizedMolarFlowProteins;
                
                % In this case no proteins remain
                fMolarFlowProteinsRemaining = 0;
            else
                % In this case more ATP is produced from the protein
                % metabolism than is required durin rest from glucose.
                % In that case we have to calculate how much of the protein
                % metabolism is used for the resting system while the
                % glucose metabolism can be set to 0
                this.tfMetabolicFlowsRest.Protein.fMolarATPProduction       = this.tfMetabolicFlowsRest.Glucose.fMolarATPProduction;
                
                % now we calculate the molar flow of oxygen for this ATP
                % production:
                this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption   = (1/this.tfMetabolicConversionFactors.rProteinMetabolismATP) * this.tfMetabolicFlowsRest.Protein.fMolarATPProduction;
                
                this.tfMetabolicFlowsRest.Protein.fMolarCO2Production       = this.tfMetabolicConversionFactors.rRespiratoryCoefficientProteins * this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption;
                this.tfMetabolicFlowsRest.Protein.fMolarH2OProduction       = this.tfMetabolicConversionFactors.rProteinMetabolismH2O           * this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption;
                this.tfMetabolicFlowsRest.Protein.fMolarUreaProduction      = this.tfMetabolicConversionFactors.rProteinMetabolismUrea          * this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption;
                this.tfMetabolicFlowsRest.Protein.fMolarProteinConsumption  = this.tfMetabolicConversionFactors.rProteinMetabolism              * this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption;
                
                this.tfMetabolicFlowsRest.Glucose.fMolarATPProduction       = 0;
                this.tfMetabolicFlowsRest.Glucose.fMolarOxygenConsumption   = 0;
                this.tfMetabolicFlowsRest.Glucose.fMolarCO2Production       = 0;
                this.tfMetabolicFlowsRest.Glucose.fMolarH2OProduction       = 0;
                this.tfMetabolicFlowsRest.Glucose.fMolarGlucoseConsumption  = 0;
                
                if this.rActivityLevel > 0
                    % In this case now we check if there currently is exercise
                    % or post exercise metabolism activity which could consume
                    % the proteins:
                    if this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarATPProduction > (this.tfMetabolicFlowsProteins.fMolarATPProduction - this.tfMetabolicFlowsRest.Protein.fMolarATPProduction)
                        
                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarATPProduction       = this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarATPProduction - (this.tfMetabolicFlowsProteins.fMolarATPProduction - this.tfMetabolicFlowsRest.Protein.fMolarATPProduction);

                        % Then we can convert the ATP flow from glucose into the
                        % molar oxgyen flow, using the inverse stochiometric
                        % conversion factor:
                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarOxygenConsumption   = (1 / this.tfMetabolicConversionFactors.rATPCoefficientGlucose) * this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarATPProduction;
                        % The other molar flows can then be calculated from the
                        % oxygen consumption, using the stochiometric conversion
                        % factors:
                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarCO2Production       = this.tfMetabolicConversionFactors.rRespiratoryCoefficientGlucose  * this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarH2OProduction       = this.tfMetabolicConversionFactors.rH2OCoefficientGlucose          * this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarGlucoseConsumption  = this.tfMetabolicConversionFactors.rCoefficientGlucose             * this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarOxygenConsumption;
                    
                        
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarATPProduction       = this.tfMetabolicFlowsProteins.fMolarATPProduction - this.tfMetabolicFlowsRest.Protein.fMolarATPProduction;

                        % now we calculate the molar flow of oxygen for this ATP
                        % production:
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption   = (1/this.tfMetabolicConversionFactors.rProteinMetabolismATP) * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarATPProduction;

                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarCO2Production       = this.tfMetabolicConversionFactors.rRespiratoryCoefficientProteins * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarH2OProduction       = this.tfMetabolicConversionFactors.rProteinMetabolismH2O           * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarUreaProduction      = this.tfMetabolicConversionFactors.rProteinMetabolismUrea          * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarProteinConsumption  = this.tfMetabolicConversionFactors.rProteinMetabolism              * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;

                    else
                        
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarATPProduction       = this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarATPProduction;

                        % now we calculate the molar flow of oxygen for this ATP
                        % production:
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption   = (1/this.tfMetabolicConversionFactors.rProteinMetabolismATP) * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarATPProduction;

                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarCO2Production       = this.tfMetabolicConversionFactors.rRespiratoryCoefficientProteins * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarH2OProduction       = this.tfMetabolicConversionFactors.rProteinMetabolismH2O           * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarUreaProduction      = this.tfMetabolicConversionFactors.rProteinMetabolismUrea          * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;
                        this.tfMetabolicFlowsAerobicActivity.Protein.fMolarProteinConsumption  = this.tfMetabolicConversionFactors.rProteinMetabolism              * this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption;

                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarATPProduction       = 0;
                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarOxygenConsumption   = 0;
                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarCO2Production       = 0;
                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarH2OProduction       = 0;
                        this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarGlucoseConsumption  = 0;
                    
                    end
                else
                    % No exercise also means no 
                    this.tfMetabolicFlowsAerobicActivity.Protein.fMolarATPProduction       = 0;
                    this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption   = 0;
                    this.tfMetabolicFlowsAerobicActivity.Protein.fMolarCO2Production       = 0;
                    this.tfMetabolicFlowsAerobicActivity.Protein.fMolarH2OProduction       = 0;
                    this.tfMetabolicFlowsAerobicActivity.Protein.fMolarUreaProduction      = 0;
                    this.tfMetabolicFlowsAerobicActivity.Protein.fMolarProteinConsumption  = 0;
                end
                fMolarFlowProteinsRemaining = this.tfMetabolicFlowsProteins.fMetabolizedMolarFlowProteins - (this.tfMetabolicFlowsRest.Protein.fMolarProteinConsumption + this.tfMetabolicFlowsAerobicActivity.Protein.fMolarProteinConsumption);
            end
                
            % Now we calculate the total molar flows for rest and
            % exercise from all three nutrient sources, fat, glucose
            % and protein. These values are then stored on the top
            % level layer of the metabolic structs:
            % Rest:
            this.tfMetabolicFlowsRest.fMolarOxygenConsumption   = this.tfMetabolicFlowsRest.Protein.fMolarOxygenConsumption + this.tfMetabolicFlowsRest.Glucose.fMolarOxygenConsumption + this.tfMetabolicFlowsRest.Fat.fMolarOxygenConsumption;
            this.tfMetabolicFlowsRest.fMolarCO2Production       = this.tfMetabolicFlowsRest.Protein.fMolarCO2Production     + this.tfMetabolicFlowsRest.Glucose.fMolarCO2Production     + this.tfMetabolicFlowsRest.Fat.fMolarCO2Production ;
            this.tfMetabolicFlowsRest.fMolarH2OProduction       = this.tfMetabolicFlowsRest.Protein.fMolarH2OProduction     + this.tfMetabolicFlowsRest.Glucose.fMolarH2OProduction     + this.tfMetabolicFlowsRest.Fat.fMolarH2OProduction;
            this.tfMetabolicFlowsRest.fMolarATPProduction       = this.tfMetabolicFlowsRest.Protein.fMolarATPProduction     + this.tfMetabolicFlowsRest.Glucose.fMolarATPProduction     + this.tfMetabolicFlowsRest.Fat.fMolarATPProduction;
            this.tfMetabolicFlowsRest.fMolarUreaProduction      = this.tfMetabolicFlowsRest.Protein.fMolarUreaProduction;
            this.tfMetabolicFlowsRest.fMolarProteinConsumption  = this.tfMetabolicFlowsRest.Protein.fMolarProteinConsumption;
            this.tfMetabolicFlowsRest.fMolarGlucoseConsumption  = this.tfMetabolicFlowsRest.Glucose.fMolarGlucoseConsumption;
            this.tfMetabolicFlowsRest.fMolarFatConsumption      = this.tfMetabolicFlowsRest.Fat.fMolarFatConsumption;

            % Exercise:
            this.tfMetabolicFlowsAerobicActivity.fMolarOxygenConsumption   = this.tfMetabolicFlowsAerobicActivity.Protein.fMolarOxygenConsumption + this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarOxygenConsumption + this.tfMetabolicFlowsAerobicActivity.Fat.fMolarOxygenConsumption;
            this.tfMetabolicFlowsAerobicActivity.fMolarCO2Production       = this.tfMetabolicFlowsAerobicActivity.Protein.fMolarCO2Production     + this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarCO2Production     + this.tfMetabolicFlowsAerobicActivity.Fat.fMolarCO2Production ;
            this.tfMetabolicFlowsAerobicActivity.fMolarH2OProduction       = this.tfMetabolicFlowsAerobicActivity.Protein.fMolarH2OProduction     + this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarH2OProduction     + this.tfMetabolicFlowsAerobicActivity.Fat.fMolarH2OProduction;
            this.tfMetabolicFlowsAerobicActivity.fMolarATPProduction       = this.tfMetabolicFlowsAerobicActivity.Protein.fMolarATPProduction     + this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarATPProduction     + this.tfMetabolicFlowsAerobicActivity.Fat.fMolarATPProduction;
            this.tfMetabolicFlowsAerobicActivity.fMolarUreaProduction      = this.tfMetabolicFlowsAerobicActivity.Protein.fMolarUreaProduction;
            this.tfMetabolicFlowsAerobicActivity.fMolarProteinConsumption  = this.tfMetabolicFlowsAerobicActivity.Protein.fMolarProteinConsumption;
            this.tfMetabolicFlowsAerobicActivity.fMolarGlucoseConsumption  = this.tfMetabolicFlowsAerobicActivity.Glucose.fMolarGlucoseConsumption;
            this.tfMetabolicFlowsAerobicActivity.fMolarFatConsumption      = this.tfMetabolicFlowsAerobicActivity.Fat.fMolarFatConsumption;
        end
            
        function exec(this, ~)
            exec@vsys(this);
            % We do not use the exec functions of the human layers, as it
            % is not possible to define the update order if we use the exec
            % functions!!
        end
    end
    methods (Access = {?components.matter.DetailedHuman.Human})
        
        function update(this)
            
            %% calculate the additional food energy demand:
            % calculated before anything else, because we want to calculate
            % it with the old rates, as we now know how long these old
            % rates were used!
            fTimeStep = this.oTimer.fTime - this.fLastMetabolismUpdate;
            this.fAdditionalFoodEnergyDemand = this.fAdditionalFoodEnergyDemand + this.fAerobicActivityMetabolicRate * fTimeStep;
            
            
            % Now we also check if we can set the exercise triggers for
            % this day up
            if this.bExercise
                fExerciseTime = this.oTimer.fTime - this.fCurrentStateStartTime;
                if fExerciseTime > 2700 && this.rActivityLevel >= 0.6
                    this.bDailyAerobicTrainingThresholdReached   = true;
                elseif fExerciseTime > 1200 && this.rActivityLevel > 1
                    this.bDailyAnaerobicTrainingThresholdReached = true;
                end
            end
            
            % The molar volume can be calculated from the current
            % temperature and pressure. Since we assume standard pressure
            % for inside of the human body, it only depends on the
            % temperature
            % [(kg m^2 / s^2 mol K) * K / (N/m^2)]
            % [(N m / mol) * (m^2/N)]
            % [m^3 / mol]
            this.fMolarVolume = this.oMT.Const.fUniversalGas * this.oParent.fBodyCoreTemperature / this.oMT.Standard.Pressure;
            
            % The energy monitor is calculated before anything else,
            % because it requires the flowrates from the last execution and
            % the elapsed time between the previous tick and now to
            % calculate the expended energy up to this point.
            if ~(this.oTimer.iTick == 0)
                this.AerobicEnergyMonitoring();
            end
            
            this.BodyComposition();
            this.CardiacPerformance();
            
            % The first step should be to calculate the change in muscle
            % mass. Muscle fiber is primarily created from proteins so we
            % first subtract the increase in muscle fiber mass from the
            % consumed protein mass flow. The remaining protein flow is
            % metabolised, because proteins cannot be stored in the body
            % ("Biochemie" Berg et. al 2013 page 689). In the model we
            % assume that the metabolised proteins are part of the glucose
            % pathway. Therefore, the metabolised ATP from proteins is
            % subtracted from the amount of ATP that should be generated by
            % the glucose pathways.
            this.tfMetabolicFlowsProteins = this.ProteinMetabolism(this.fMuscleChangeMassFlow);
            
            this.tfMetabolicFlowsRest = this.RestingAerobicSystem();
            
            fMolarFlowProteinsRemaining = this.calculateFinalMetabolicFlows();
            
            % The metabolism system requires the training and detraining
            % factors, so we calculate that beforehand
            this.TrainingDetraining();
            
            [tfP2PFlowRates, this.tfMetabolicFlowsFatSynthesis] = this.MetabolismSystem(fMolarFlowProteinsRemaining);
            
            if this.bExercise
                % Since the anaerobic activity system already requires the
                % total molar flows, it must be calculated after the
                % previous calculations to include the protein metabolism!
                this.AnaerobicActivitySystem();
                
            end
            
            %% Now we can set the manipulator flowrate to handle the metabolic conversions
            afManipFlowRates = zeros(1, this.oMT.iSubstances);
            
            % Total Protein flow:
            afManipFlowRates(this.oMT.tiN2I.C3H7NO2)     = - this.oMT.afMolarMass(this.oMT.tiN2I.C3H7NO2)   * (	this.tfMetabolicFlowsRest.fMolarProteinConsumption +...
                                                                                                             	this.tfMetabolicFlowsAerobicActivity.fMolarProteinConsumption +...
                                                                                                              	this.tfMetabolicFlowsFatSynthesis.fMolarProteinConsumption);  
                                                                                          
            % Total Fat flow:
            afManipFlowRates(this.oMT.tiN2I.C51H98O6) 	 = - this.oMT.afMolarMass(this.oMT.tiN2I.C51H98O6)  * (	this.tfMetabolicFlowsRest.fMolarFatConsumption +...
                                                                                                              	this.tfMetabolicFlowsAerobicActivity.fMolarFatConsumption -...
                                                                                                              	this.tfMetabolicFlowsFatSynthesis.fMolarFatProduction);  
                                                                                          
            % Total Glucose flow:
            afManipFlowRates(this.oMT.tiN2I.C6H12O6)     = - this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6)   * (	this.tfMetabolicFlowsRest.fMolarGlucoseConsumption +...
                                                                                                               	this.tfMetabolicFlowsAerobicActivity.fMolarGlucoseConsumption +...
                                                                                                            	this.tfMetabolicFlowsFatSynthesis.fMolarGlucoseConsumption);  
                                                                                          
            % Total Oxygen flow:
            afManipFlowRates(this.oMT.tiN2I.O2)          = - this.oMT.afMolarMass(this.oMT.tiN2I.O2)        * (	this.tfMetabolicFlowsRest.fMolarOxygenConsumption +...
                                                                                                              	this.tfMetabolicFlowsAerobicActivity.fMolarOxygenConsumption +...
                                                                                                              	this.tfMetabolicFlowsFatSynthesis.fMolarO2Consumption);
            % Total CO2 flow:
            afManipFlowRates(this.oMT.tiN2I.CO2)         =   this.oMT.afMolarMass(this.oMT.tiN2I.CO2)       * (	this.tfMetabolicFlowsRest.fMolarCO2Production +...
                                                                                                                this.tfMetabolicFlowsAerobicActivity.fMolarCO2Production +...
                                                                                                                this.tfMetabolicFlowsFatSynthesis.fMolarCO2Production);
              
            % Total H2O flow:
            afManipFlowRates(this.oMT.tiN2I.H2O)         =   this.oMT.afMolarMass(this.oMT.tiN2I.H2O)       * (	this.tfMetabolicFlowsRest.fMolarH2OProduction +...
                                                                                                             	this.tfMetabolicFlowsAerobicActivity.fMolarH2OProduction +...
                                                                                                            	this.tfMetabolicFlowsFatSynthesis.fMolarH2OProduction);  
                
            % Total Urea flow:
            afManipFlowRates(this.oMT.tiN2I.CH4N2O)      =   this.oMT.afMolarMass(this.oMT.tiN2I.CH4N2O)    * (	this.tfMetabolicFlowsRest.fMolarUreaProduction +...
                                                                                                              	this.tfMetabolicFlowsAerobicActivity.fMolarUreaProduction +...
                                                                                                               	this.tfMetabolicFlowsFatSynthesis.fMolarUreaProduction);  
            
            
            % Now we also have to consider the generated muscle mass:
            % Human tissue is modelled to consist of muscle mass and water,
            % where the muscle mass itself is generated from proteins or,
            % if not sufficient proteins are present, glucose
            afManipFlowRates(this.oMT.tiN2I.C3H7NO2)        =  afManipFlowRates(this.oMT.tiN2I.C3H7NO2) - (1 - this.rH2OtoMuscleMassRatio) * this.fMuscleChangeMassFlow;
            afManipFlowRates(this.oMT.tiN2I.H2O)            =  afManipFlowRates(this.oMT.tiN2I.H2O)     - this.rH2OtoMuscleMassRatio * this.fMuscleChangeMassFlow;
            afManipFlowRates(this.oMT.tiN2I.C6H12O6)        =  afManipFlowRates(this.oMT.tiN2I.C6H12O6) - this.tfMetabolicFlowsProteins.fGlucoseToMuscleMassFlow;
            
            afManipFlowRates(this.oMT.tiN2I.Human_Tissue)	=  this.fMuscleChangeMassFlow;
            
            this.toStores.Metabolism.toPhases.Metabolism.toManips.substance.setFlowRate(afManipFlowRates);
            
            % The manual manipulator changes these flows slightly to
            % prevent mass errors. Therefore, get the final manips
            % flowrates here:
            afManipFlowRates = this.toStores.Metabolism.toPhases.Metabolism.toManips.substance.afManualFlowRates;
            
            this.fUreaFlowRate = afManipFlowRates(this.oMT.tiN2I.CH4N2O);
            
            % For these flows it is important to include the protein CO2
            % values!
            % From Markus Czupallas Dissertation Section 11.1.1.2.8 
            % Equation (11-162)
            %
            % the anaerobic metabolism can likely not be implemented like
            % this. Because the only value adjusted by the oxygen dept
            % calculated from the anaerobic metabolism is the intake of
            % oxygen, while the remaining metabolic flows still assume
            % oxygen is present and can be used.
            fVO2_total  = -60 * (afManipFlowRates(this.oMT.tiN2I.O2) / this.oMT.afMolarMass(this.oMT.tiN2I.O2)) * this.fMolarVolume * 1000;
            this.fVO2 = fVO2_total - this.fVO2_Debt;
            
            this.fVCO2 = 60 * (afManipFlowRates(this.oMT.tiN2I.CO2) / this.oMT.afMolarMass(this.oMT.tiN2I.CO2)) * this.fMolarVolume * 1000;

            %% The distribution of matter within the metabolism system is handled by P2Ps:
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.oMT.tiN2I.C6H12O6) = tfP2PFlowRates.fGlucoseToLiver;
            this.toStores.Metabolism.toProcsP2P.Metabolism_to_Liver.setFlowRate(            afPartialFlowRates);
            
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.oMT.tiN2I.C6H12O6) = tfP2PFlowRates.fGlucoseToMuscle;
            afPartialFlowRates(this.oMT.tiN2I.Human_Tissue) = afManipFlowRates(this.oMT.tiN2I.Human_Tissue);
            this.toStores.Metabolism.toProcsP2P.Metabolism_to_MuscleTissue.setFlowRate(     afPartialFlowRates);
            
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.oMT.tiN2I.C51H98O6) = tfP2PFlowRates.fFatToAdiposeTissue;
            afPartialFlowRates(this.oMT.tiN2I.H2O)      = tfP2PFlowRates.fH2OToAdiposeTissue;
            this.toStores.Metabolism.toProcsP2P.Metabolism_to_AdiposeTissue.setFlowRate(    afPartialFlowRates);
            
            %% And the branch flowrates handling the matter distribution within the model
            
            
            % According to "Cardiovascular response to dynamicaerobic
            % exercise: a mathematical model", E. Magosso, M. Ursino, 2002
            % During activity blood flow is directed towards the muscles.
            % This was not done in the V-HAB model since the oxygen
            % consumption in the brain was also increased, which is not
            % realistic. Hence the model was adapted to maintain the brain
            % blood flow but increase the tissue blood flow and the
            % additional oxygen consumption from exercise will also occur
            % in the tissue
            fOxygenFlowForActivity = this.tfMetabolicFlowsAerobicActivity.fMolarOxygenConsumption * this.oMT.afMolarMass(this.oMT.tiN2I.O2);
            fBaseOxygenFlow = - afManipFlowRates(this.oMT.tiN2I.O2) - fOxygenFlowForActivity;
            
            afFlowRatesO2_Brain  = zeros(1, this.oMT.iSubstances);
            afFlowRatesO2_Tissue = zeros(1, this.oMT.iSubstances);
            afFlowRatesO2_Brain(this.oMT.tiN2I.O2)     = 0.2 * fBaseOxygenFlow;
            afFlowRatesO2_Tissue(this.oMT.tiN2I.O2)    = 0.8 * fBaseOxygenFlow + fOxygenFlowForActivity;
            this.oParent.toBranches.O2_from_Brain.oHandler.setFlowRate( afFlowRatesO2_Brain);
            this.oParent.toBranches.O2_from_Tissue.oHandler.setFlowRate(afFlowRatesO2_Tissue);
            
            fCO2FlowForActivity = this.tfMetabolicFlowsAerobicActivity.fMolarCO2Production * this.oMT.afMolarMass(this.oMT.tiN2I.CO2);
            fBaseCO2Flow = afManipFlowRates(this.oMT.tiN2I.CO2) - fCO2FlowForActivity;
            
            afFlowRatesCO2_Brain  = zeros(1, this.oMT.iSubstances);
            afFlowRatesCO2_Tissue = zeros(1, this.oMT.iSubstances);
            afFlowRatesCO2_Brain(this.oMT.tiN2I.CO2) 	= 0.2 * fBaseCO2Flow;
            afFlowRatesCO2_Tissue(this.oMT.tiN2I.CO2)	= 0.8 * fBaseCO2Flow + fCO2FlowForActivity;
            this.oParent.toBranches.CO2_to_Brain.oHandler.setFlowRate( afFlowRatesCO2_Brain);
            this.oParent.toBranches.CO2_to_Tissue.oHandler.setFlowRate(afFlowRatesCO2_Tissue);
            
            afFlowRates = zeros(1, this.oMT.iSubstances);
            afFlowRates(this.oMT.tiN2I.H2O)     = afManipFlowRates(this.oMT.tiN2I.H2O) - tfP2PFlowRates.fH2OToAdiposeTissue;
            this.oParent.toBranches.MetabolicWater_to_BloodPlasma.oHandler.setFlowRate(afFlowRates);
            
            afFlowRates = zeros(1, this.oMT.iSubstances);
            afFlowRates(this.oMT.tiN2I.CH4N2O)	= afManipFlowRates(this.oMT.tiN2I.CH4N2O);
            this.oParent.toBranches.Urea_Output.oHandler.setFlowRate(afFlowRates);
            
            %% calculate the metabolic heat flow:
            fMolarATP_total = this.tfMetabolicFlowsRest.fMolarATPProduction  + this.tfMetabolicFlowsAerobicActivity.fMolarATPProduction;
            fEnergyRateATP  = this.fEnergyYieldATP * fMolarATP_total;
            
            % Equation 11-166
            this.fMetabolicHeatFlow = (this.fAerobicActivityMetabolicRate + this.fBaseMetabolicRate) - (this.rMechanicalEfficiency * fEnergyRateATP);
            
            if this.rActivityLevel < 0.3
                this.fBaseMetabolicHeatFlow = this.fMetabolicHeatFlow;
            end
            %% calculate Total values
            this.fTotalMetabolicRate = this.fRestMetabolicRate + this.fAerobicActivityMetabolicRate;
            
            this.rRespiratoryCoefficient =  (this.tfMetabolicFlowsAerobicActivity.fMolarCO2Production + this.tfMetabolicFlowsRest.fMolarCO2Production) / ...
                                            (this.tfMetabolicFlowsAerobicActivity.fMolarOxygenConsumption + this.tfMetabolicFlowsRest.fMolarOxygenConsumption);
            
            %% calculate the caloric value of oxygen:
            % The V-HAB 1 human model used a fix 5 kcal/l value to convert
            % the metabolic rate into VO2. However, the correct conversion
            % actually depends on the current diet
            fTotalOxygenConsumption = this.tfMetabolicFlowsAerobicActivity.fMolarOxygenConsumption + this.tfMetabolicFlowsRest.fMolarOxygenConsumption;
            
            fFatEnergy      = (this.tfMetabolicFlowsAerobicActivity.fMolarFatConsumption     + this.tfMetabolicFlowsRest.fMolarFatConsumption)     * this.oMT.afMolarMass(this.oMT.tiN2I.C51H98O6) * this.oMT.afNutritionalEnergy(this.oMT.tiN2I.C51H98O6);
            fProteinEnergy  = (this.tfMetabolicFlowsAerobicActivity.fMolarProteinConsumption + this.tfMetabolicFlowsRest.fMolarProteinConsumption) * this.oMT.afMolarMass(this.oMT.tiN2I.C3H7NO2)  * this.oMT.afNutritionalEnergy(this.oMT.tiN2I.C3H7NO2);
            fGlucoseEnergy  = (this.tfMetabolicFlowsAerobicActivity.fMolarGlucoseConsumption + this.tfMetabolicFlowsRest.fMolarGlucoseConsumption) * this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6)  * this.oMT.afNutritionalEnergy(this.oMT.tiN2I.C6H12O6);
            fTotalEnergy    = fFatEnergy + fProteinEnergy + fGlucoseEnergy;
            
            this.fCaloricValueOxygen = fTotalEnergy / (fTotalOxygenConsumption * this.oMT.afMolarMass(this.oMT.tiN2I.O2));
            
            this.fLastMetabolismUpdate = this.oTimer.fTime;
        end
    end
end