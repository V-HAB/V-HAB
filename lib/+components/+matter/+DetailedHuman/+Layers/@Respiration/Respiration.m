classdef Respiration < vsys
    
    properties (SetAccess = protected, GetAccess = public)
        % All parameters are from chapter 11.1.1.1 of the dissertation of
        % Markus Czupalla but are converted into standard SI units as used
        % in V-HAB 2!
        
        
        % Not from the dissertation, calculated based on the total volume
        % of 40 l assumed in the dissertation, then assuemd 8 l  of blood
        % volume in total and used that to calculate the blood volume
        % fraction
        fBloodVolumeRatioBrain  = 0.2;
        fBloodVolumeRatioTissue = 0.2;
        
        %% Curent Volumetric Flowrates
        fVolumetricFlow_Air;                            % m^3/s
        fVolumetricFlow_BrainBlood;                     % m^3/s
        fVolumetricFlow_TissueBlood;                    % m^3/s
        
        fDeltaVentilationCentralChemorezeptor       =   1.037 / 1000 / 60;  % [m^3/s]
        fDeltaVentilationPeripheralChemorezeptor    = - 1.6 / 1000 / 60;    % [m^3/s]
        
        fDelayedVentilationResponseToExercise       =  0;    % [m^3/s]
        
        %% Basic partial pressures
        
        trInitialBloodComposition;
        
        % TBD: Calculate this dynamically? Only makes sense if it is added
        % to the matter table. More information on this can be found in:
        % "The measurement of blood density and its meaning", T. Kenner,
        % 1989
        % https://link.springer.com/content/pdf/10.1007%2FBF01907921.pdf
        fBloodDensity = 1050;
        
        % Control Variable for Oxygen and Carbon Dioxide in the blood
        fYo2    =-0.000989;
        fYco2   = 0.001393;
        
        % Control Variable for Respiration
        fAlphaH = 1.55;
        
        % In order to model delays in the ventilation control we have to
        % store the partial pressure of co2 in the brain and the peripheral
        % chemorezopter discharge frequency for the last 100 ticks
        mfPartialPressureCO2_Brain;                 % [Pa]
        mfPeriheralChemorezeptorDischargeFrequency; % [Hz]
        
        % time that has passed since the last update of respiration layer
        fElapsedTime = 0;  % [s]
        fLastRespirationUpdate = 0;  % [s]
        
        fRespirationWaterOutput = 0; % [kg/s]
        
        tfPartialPressure;
        
        tfBloodFlows;
        
        fHumanTimeStep;
        
        fNewVolumetricBloodFlowFromActivity;
        fDeltaVentilationActivity;
        
        hCalculateChangeRate;
        
        fInternalTimeStep = 2;
        
        tOdeFlowRates;
        tOdeOptions = odeset('RelTol', 1e-1, 'AbsTol', 1e-2);
    end
    
    properties (Constant)
        % Parameters according to "An integrated model of the human
        % ventilatory control system: the response to hypercapnia",
        % Ursino, M.; Magosso, E.; Avanzolini, G., 2001 
        % Table 1
        
        
        % Also called the equivalent alveolar compartment volume
        fLungVolume             = 3.28e-3;	% [m^3]
        
        fBrainVolume            = 1.32e-3;	% [m^3]
        
        fTissueVolume           = 38.68e-3;	% [m^3]
        
        rDeadSpaceFractionLung  = 0.33;
        
        %% Saturation calculation parameters
        fBeta_1     =   0.008275;   %[mmHg^-1]
        fBeta_2     =   0.03255;    %[mmHg^-1]
        fAlpha_1    =   0.03198;    %[mmHg^-1]
        fAlpha_2    =   0.05591;    %[mmHg^-1]
        fK1         =   14.99;      %[mmHg]
        fK2         =   194.4;      %[mmHg]
        fC1         =   9;          %[mmol l^-1]
        fC2         =   86.11;      %[mmol l^-1]
        fa1         =   0.3836;
        fa2         =   1.819;
        %                            gas density at standard conditions * 
        fHenryConstantO2  = (3.17*10^-5 * 1.4290 * 1.059 * 760 / 101325); % [kg/(m^3 Pa)]
        fHenryConstantCO2 = (6.67*10^-4 * 1.9768 * 1.059 * 760 / 101325); % [kg/(m^3 Pa)]
        
        %% Basal Partial Pressures
        fBasePartialPressureCO2_Brain       = 45   * 101325 / 760;	% [Pa]
        fBasePartialPressureO2_Brain        = 32   * 101325 / 760;	% [Pa]
        fBasePartialPressureCO2_Arteries    = 40   * 101325 / 760;	% [Pa]
        fBasePartialPressureO2_Arteries     = 95   * 101325 / 760;	% [Pa]
        
        %% Basic Volumetric Flowrates
        fBaseVolumetricFlow_Air             = 6.62 / 1000 / 60;     % m^3/s
        % 
        fBaseVolumetricFlow_BrainBlood      = (0.75 / 1000)/ 60;    % m^3/s
        fBaseVolumetricFlow_TissueBlood     = (4.25 / 1000)/ 60;    % m^3/s
        
        % The ratio of the blood stream that bypasses the alveola is
        % determined by this value!
        rPulmonaryShunt                     = 0.024;
        
        %% Cardiac Control
        % Blood Flow Delay constants
        fTauO2  = 10;   % [s]
        fTauCO2 = 20;   % [s]
        % Central Ventilation Depression
        fTauH   = 300;  % [s]
        
        % Cardiac Control Constants:
        fCardiacC1  =  17;
        fCardiacC2  =  11 * 101325 / 760;	% [Pa]
        fCardiacA   =  20.9;
        fCardiacB   =  92.8;
        fCardiacC   =  10570;
        fCardiacD   = -5.251;
        fCardiacRho =  0.32;
        
        %% Ventilation Control Parameters
        % Central Ventilation Depression
        fThetaHmin = 29.8 * 101325 / 760; % [Pa]
        fThetaHmax = 35   * 101325 / 760; % [Pa]
        fGH        = 10;
        
        % Central Chemorezeptor
        fTauC                                               = 60;                               % [s]
        % The unit for Gc in both the dissertation and the original
        % source is [l/(min * Hz)], however that does not make any
        % sense at all. The correct unit in the original work should be
        % [l/(min * mmHg)] which is also used here and transformed into
        % [m^3/(s * Pa)]
        fGc                                                 = 2 * (760 / 101325) / 1000 / 60;	% [m^3/(s * Pa)]
        fKdc                                                = 0.9238 / 1000;                    % [m^3]
        
        % Periphereal Chemorezeptor
        fBasalPeriheralChemorezeptorDischargeFrequency      = 3.78;                             % [Hz]
        fMinimalPeriheralChemorezeptorDischargeFrequency    = 0.8352;                           % [Hz]
        fMaximalPeriheralChemorezeptorDischargeFrequency    = 12.3;                             % [Hz]
        
        fTauP                                               = 7;                                % [s]
        % The unit for Gp in both the dissertation and the original
        % source is [l/(min * Hz)], however that does not make any
        % sense at all. The correct unit in the original work should be
        % [l/(min * mmHg)] which is also used here and transformed into
        % [m^3/(s * Pa)]
        fGp                                                 = 2.5 * (760 / 101325) / 1000 / 60;	% [m^3/(s * Pa)]
        fK                                                  = 1.738;
        fBp                                                 = 18    * 101325 / 760;             % [Pa]
        fPeripheralChemorezeptorPartialPressureO2_Constant  = 45    * 101325 / 760;             % [Pa]
        fKpc                                                = 29.27 * 101325 / 760;             % [Pa]
        fKdp                                                = 0.588 / 1000;                     % [m^3]
        
        %% Activity Control Parameters
        fTauV   = 60;               % [s]
        fAv     = 33 / 1000 / 60;   % [m^3 / s]
        fBv     = 61 / 1000 / 60;   % [m^3 / s]
    end
    
    methods
        function this = Respiration(oParent, sName)
            this@vsys(oParent, sName, inf);
            
            this.mfPartialPressureCO2_Brain = zeros(2, 1);
            this.mfPeriheralChemorezeptorDischargeFrequency = zeros(2, 1);
            
            this.mfPartialPressureCO2_Brain(2, 1)                   = this.fBasePartialPressureCO2_Brain;
            this.mfPeriheralChemorezeptorDischargeFrequency(2, 1)   = this.fBasalPeriheralChemorezeptorDischargeFrequency;
            
            this.trInitialBloodComposition = struct('Human_Blood' , 1);
            
            this.tfPartialPressure.Brain.O2         = 0;
            this.tfPartialPressure.Brain.CO2        = 0;
            this.tfPartialPressure.Tissue.O2        = 0;
            this.tfPartialPressure.Tissue.CO2       = 0;
            this.tfPartialPressure.Arteries.O2      = 0;
            this.tfPartialPressure.Arteries.CO2     = 0;
            
            % Define rate of change function for ODE solver.
            this.hCalculateChangeRate = @(t, m) this.calculateChangeRate(m, t);
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            fHumanTissueDensity = this.oMT.calculateDensity('solid', struct('Human_Tissue', 1));
            
            %% Lung
            matter.store(this, 'Lung', this.fLungVolume);
            % Intitialize the lung with standard air, since we use a flow
            % phase for the lung it does not matter what the initial
            % composition is
            fAirVolumeLung  = this.fLungVolume * (1 - this.rDeadSpaceFractionLung);
            oLungPhase    	= this.toStores.Lung.createPhase(       'air',      'flow',   	'Air',                      fAirVolumeLung,     this.oParent.fBodyCoreTemperature);
            
            % In Addition the lung store also contains a flow phase for the
            % blood flowing through the alveola
            fBloodVolumeLung = this.fLungVolume * this.rDeadSpaceFractionLung;
            oAlveolaBlood	= this.toStores.Lung.createPhase(       'mixture',  'flow',     'Blood',	'liquid',       fBloodVolumeLung,	this.trInitialBloodComposition, this.oParent.fBodyCoreTemperature, 1e5);
            
            %% Brain
            % For the respiration calculations we require the output
            % concentrations in the blood flow concentrations, but at the
            % same time we requires the inertance of the blood mass.
            % Therefore, we use a normal phase for the blood and a flow
            % phase. The normal phase models the inertence, while the flow
            % phase is used to calculate the outlet concentrations.
            [rBaseConcentrationBloodO2, rBaseConcentrationBloodCO2] = this.calculateBloodConcentrations(this.fBasePartialPressureO2_Arteries, this.fBasePartialPressureCO2_Arteries);

            matter.store(this, 'Brain', this.fBrainVolume + 2e-6);
            fBloodVolumeBrain = this.fBrainVolume * this.fBloodVolumeRatioBrain;
            
            rBloodMass = 1 - rBaseConcentrationBloodO2 - rBaseConcentrationBloodCO2;
            
            trBloodComposition = struct('Human_Blood', rBloodMass, 'O2', rBaseConcentrationBloodO2, 'CO2', rBaseConcentrationBloodCO2);
            
            oBrainBlood     = this.toStores.Brain.createPhase(      'mixture',              'Blood',        'liquid',    	fBloodVolumeBrain,  trBloodComposition,             this.oParent.fBodyCoreTemperature, 1e5);
            
            oBrainBloodOutlet= this.toStores.Brain.createPhase(     'mixture',  'flow',   	'BloodOutlet',  'liquid',    	1e-6,               trBloodComposition,             this.oParent.fBodyCoreTemperature, 1e5);
            
            fTissueVolumeBrain = this.fBrainVolume * (1 - this.fBloodVolumeRatioBrain);
            
            % Based on the basal partial pressures from "An integrated model of the human ventilatory control
            % system: the response to hypercapnia", Ursino, M.; Magosso,
            % E.; Avanzolini, G., 2001 Table 1 the concentration of HCO3 is
            % mentioned to be 26 mEq / l for both brain and tissue and that
            % this concentration will remain constant
            rBaseConcentrationTissueO2    = this.fHenryConstantO2 * this.fBasePartialPressureO2_Brain;
            rBaseConcentrationTissueCO2   = this.fHenryConstantCO2 * this.fBasePartialPressureCO2_Brain;
            
            % From "An integrated model of the human ventilatory control
            % system: the response to hypercapnia", Ursino, M.; Magosso,
            % E.; Avanzolini, G., 2001 Table 1 the concentration of HCO3 is
            % mentioned to be 26 mEq / l for both brain and tissue and that
            % this concentration will remain constant
            fInitialConcentrationHCO3_Brain = 26;  	% Initial HCO3 Concentration in mol/m^3 in Brain
            rBaseConcentrationHCO3          = fInitialConcentrationHCO3_Brain * this.oMT.afMolarMass(this.oMT.tiN2I.HCO3) / fHumanTissueDensity;
            
            rTissueMass = 1 - rBaseConcentrationTissueO2 - rBaseConcentrationTissueCO2 - rBaseConcentrationHCO3;
            trBrainMasses = struct('Human_Tissue', rTissueMass, 'O2', rBaseConcentrationTissueO2, 'CO2', rBaseConcentrationTissueCO2, 'HCO3', rBaseConcentrationHCO3);
            
            oBrainTissue    = this.toStores.Brain.createPhase(      'mixture',              'Tissue',       'liquid',       fTissueVolumeBrain, trBrainMasses,                  this.oParent.fBodyCoreTemperature, 1e5);
            
            %% Other Tissue
            
            matter.store(this, 'Tissue', this.fTissueVolume + 2e-6);
            fBloodVolumeTissue = this.fTissueVolume * this.fBloodVolumeRatioTissue;
            
            trBloodComposition = struct('Human_Blood', rBloodMass, 'O2', rBaseConcentrationBloodO2, 'CO2', rBaseConcentrationBloodCO2);
            
            oTissueBlood  	= this.toStores.Tissue.createPhase(     'mixture',              'Blood',        'liquid',       fBloodVolumeTissue, trBloodComposition,              this.oParent.fBodyCoreTemperature, 1e5);
            
            oTissueBloodOutlet= this.toStores.Tissue.createPhase(    'mixture', 'flow',     'BloodOutlet',  'liquid',       1e-6,               trBloodComposition,              this.oParent.fBodyCoreTemperature, 1e5);
            
            fTissueVolumeTissue = this.fTissueVolume * (1 - this.fBloodVolumeRatioTissue);
            
            trTissueMasses = struct('Human_Tissue', rTissueMass, 'O2', rBaseConcentrationTissueO2, 'CO2', rBaseConcentrationTissueCO2, 'HCO3', rBaseConcentrationHCO3);
            
            oTissueTissue   = this.toStores.Tissue.createPhase(     'mixture',              'Tissue',       'liquid',       fTissueVolumeTissue, trTissueMasses,                this.oParent.fBodyCoreTemperature, 1e5);
            
            %% Arteries and veins
            matter.store(this, 'Arteries', 1e-6);
            oArteries       = this.toStores.Arteries.createPhase(   'mixture',	'flow',     'Blood',        'liquid',        1e-6,               this.trInitialBloodComposition, this.oParent.fBodyCoreTemperature, 1e5);
            
            matter.store(this, 'Veins', 1e-6);
            oVeins          = this.toStores.Veins.createPhase(      'mixture',  'flow',     'Blood',        'liquid',        1e-6,               this.trInitialBloodComposition, this.oParent.fBodyCoreTemperature, 1e5);
            
            %% P2Ps
            % These p2ps are used to model the exchange of O2 and CO2 in
            % the different parts of the body. The O2 is then transported
            % to the metabolic layer, while the CO2 comes from the
            % metabolic layer
            % Since the lung contains flow phases, we have to use flow P2Ps
            % here to perform the correct calculations!
            oCO2_P2P =  components.matter.DetailedHuman.components.RespirationGasExchangeCO2(this.toStores.Lung, 'Alveola_to_Air', oAlveolaBlood,      oLungPhase);
                        components.matter.DetailedHuman.components.RespirationGasExchangeO2( this.toStores.Lung, 'Air_to_Alveola', oLungPhase,         oAlveolaBlood, oCO2_P2P);
            
            components.matter.P2Ps.ManualP2P(this.toStores.Brain, 'Blood_to_Brain',     oBrainBloodOutlet,	oBrainTissue);
            components.matter.P2Ps.ManualP2P(this.toStores.Brain, 'Brain_to_Blood',     oBrainTissue,     	oBrainBloodOutlet);
            
            components.matter.P2Ps.ManualP2P(this.toStores.Tissue, 'Blood_to_Tissue',   oTissueBloodOutlet, oTissueTissue);
            components.matter.P2Ps.ManualP2P(this.toStores.Tissue, 'Tissue_to_Blood',   oTissueTissue,  	oTissueBloodOutlet);
            
            
            %% Branches
            % Connect the alveola of the lung to the venous blood and
            % arterial blood
            matter.branch(this, oVeins,             {},     oAlveolaBlood,          'Veins_to_Alveola');
            matter.branch(this, oVeins,             {},     oArteries,              'Veins_to_Arteries');
            matter.branch(this, oAlveolaBlood,    	{},     oArteries,              'Alveola_to_Arteries');
            
            % now connect the arterial blood to the brain and the tissue
            matter.branch(this, oArteries,          {},     oBrainBlood,            'Arteries_to_Brain');
            matter.branch(this, oBrainBlood,      	{},     oBrainBloodOutlet,    	'Brain_to_BrainOutlet');
            matter.branch(this, oArteries,          {},     oTissueBlood,           'Arteries_to_Tissue');
            matter.branch(this, oTissueBlood,      	{},     oTissueBloodOutlet,    	'Tissue_to_TissueOutlet');
            
            % now connect the tissue and brain to the veins
            matter.branch(this, oBrainBloodOutlet,	{},     oVeins,                 'Brain_to_Veins');
            matter.branch(this, oTissueBloodOutlet,	{},     oVeins,                 'Tissue_to_Veins');
            
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            % We add a constant temperature heat source for the lung
            % phase, which will maintain the body core temperature for the
            % outlet air flow
            oHeatSource = components.thermal.heatsources.ConstantTemperature('LungConstantTemperature');
            this.toStores.Lung.toPhases.Air.oCapacity.addHeatSource(oHeatSource);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('BrainConstantTemperature');
            this.toStores.Brain.toPhases.Blood.oCapacity.addHeatSource(oHeatSource);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('TissueConstantTemperature');
            this.toStores.Tissue.toPhases.Blood.oCapacity.addHeatSource(oHeatSource);
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Residual branches often created problems in the past. Since
            % the human model will rely on setting all flowrates directly
            % anyway, all branches use manual solvers! The model
            % calculations then have to ensure the compatability of all
            % flows
            solver.matter.manual.branch(this.toBranches.Veins_to_Alveola);
            solver.matter.manual.branch(this.toBranches.Brain_to_BrainOutlet);
            solver.matter.manual.branch(this.toBranches.Tissue_to_TissueOutlet);
            % The flowrate to the brain must also be set manually,
            % otherwise the multi branch solver is not able to decide how
            % much matter should flow to the brain or to the tissue
            solver.matter.manual.branch(this.toBranches.Arteries_to_Brain);
             
            solver.matter.manual.branch(this.oParent.toBranches.Air_In);
            
            aoMultiSolverBranches = [this.toBranches.Brain_to_Veins; this.toBranches.Tissue_to_Veins; this.toBranches.Veins_to_Arteries; this.toBranches.Alveola_to_Arteries; this.toBranches.Arteries_to_Tissue; this.oParent.toBranches.Air_Out];
            
            tSolverProperties.fMaxError = 1e-6;
            tSolverProperties.iMaxIterations = 500;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 200;
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            csStores = fieldnames(this.toStores);
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    
                    tTimeStepProperties = struct();
                    
                    tTimeStepProperties.fMaxStep = this.oParent.fTimeStep;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                    
                    tTimeStepProperties.rMaxChange = 0.1;
                    
                    arMaxChange = zeros(1,this.oMT.iSubstances);
                    arMaxChange(this.oMT.tiN2I.C6H12O6)     = 0.01;
                    arMaxChange(this.oMT.tiN2I.C51H98O6)    = 0.01;
                    arMaxChange(this.oMT.tiN2I.C6H12O6)     = 0.01;
                    arMaxChange(this.oMT.tiN2I.H2O)         = 0.01;
                    arMaxChange(this.oMT.tiN2I.O2)          = 0.01;
                    arMaxChange(this.oMT.tiN2I.CO2)         = 0.01;
                    tTimeStepProperties.arMaxChange = arMaxChange;

                    oPhase.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            
            this.setThermalSolvers();
        end
        
        function connectHumanToNewAirPhase(~)%this, oNewAirPhase)
            % Probably provide a function for this on the human level,
            % however thee things that should be done here should be
            % internal to the respiratory layer. So the function on the
            % human level should only be "superficial"
        end
        
        function [fPartialPressureO2, fPartialPressureCO2] = calculateBloodPartialPressure(this, fConcentrationO2, fConcentrationCO2)
            % Calculates the new partial pressure of oxygen and carbon
            % dioxide that correspond to the current concentrations in the
            % blood. The input concentrations are in kg/kg while the
            % output partial pressures are in Pa
            
            %% NOT IN SI UNITS!!
            %
            % Convert the concentrations into mmol/l concentrations
            % mmol would be dividing with 1000 while transforming into
            % /m^3 would multiply it with 1000 --> cancles only transform
            % into mass/m^3 instead of mol/m^3
            %                           [kg (O2)/kg(blood)]                     [kg/mol]                        kg/m^3
            fConcentrationO2_mmol_l  = fConcentrationO2  / this.oMT.afMolarMass(this.oMT.tiN2I.O2)  * this.fBloodDensity;
            fConcentrationCO2_mmol_l = fConcentrationCO2 / this.oMT.afMolarMass(this.oMT.tiN2I.CO2) * this.fBloodDensity;
            
            if fConcentrationO2_mmol_l > this.fC1
                fConcentrationO2_mmol_l = this.fC1*0.999;
            end
            if fConcentrationCO2_mmol_l > this.fC2
                fConcentrationCO2_mmol_l = this.fC2*0.999;
            end
            
            % Equations according to "Computational expressions for blood
            % oxygen and carbon dioxide concentrations", Spencer, J. L.;
            % Firouztale, E.; Mellins, R. B., 1979 
            % Equation 6 and 7 and helper variables
            %
            % Also described in the dissertation by Markus Czupalla in Eq.
            % (11-10) to (11-17)
            fD1  =   this.fK1 * ( fConcentrationO2_mmol_l  / (this.fC1 - fConcentrationO2_mmol_l))^this.fa1;
            fD2  =   this.fK2 * ( fConcentrationCO2_mmol_l / (this.fC2 - fConcentrationCO2_mmol_l))^this.fa2;
            
            s1  =   -(fD1 + this.fAlpha_1 * fD1 * fD2) / (this.fBeta_2 + this.fAlpha_2 * this.fBeta_1 * fD2);
            s2  =   -(fD2 + this.fAlpha_2 * fD2 * fD1) / (this.fBeta_1 + this.fAlpha_1 * this.fBeta_2 * fD1);
            
            r1  =   -(1 + this.fBeta_1 * fD2 - this.fBeta_2 * fD1 - this.fAlpha_1 * this.fAlpha_2 * fD1 * fD2) / (2 * (this.fBeta_2 + this.fAlpha_2 * this.fBeta_1 * fD2));
            r2  =   -(1 + this.fBeta_2 * fD1 - this.fBeta_1 * fD2 - this.fAlpha_2 * this.fAlpha_1 * fD2 * fD1) / (2 * (this.fBeta_1 + this.fAlpha_1 * this.fBeta_2 * fD1));

            fPartialPressureO2_Torr  = r1 + (r1^2 - s1)^(1/2);
            fPartialPressureCO2_Torr = r2 + (r2^2 - s2)^(1/2);
            
            % The Partial pressures are calculated in mmHg or Torr and are
            % therefore now converted into Pa
            fPartialPressureO2  = fPartialPressureO2_Torr  * (101325 / 760);
            fPartialPressureCO2 = fPartialPressureCO2_Torr * (101325 / 760);
        end
        
        function [fConcentrationO2, fConcentrationCO2] = calculateBloodConcentrations(this, fPartialPressureO2, fPartialPressureCO2)
            % Calculates the new concentration of oxygen and carbon dioxide
            % that can remain in the blood based on the current partial
            % pressures of O2 and CO2
            % The Input partial pressures must be in Pa, the output
            % concentrations are in kg/kg
            
            %% NOT IN SI UNITS!!
            %
            % Equation according to "An integrated model of the human
            % ventilatory control system: the response to hypercapnia",
            % Ursino, M.; Magosso, E.; Avanzolini, G., 2001 
            % Equation A-11 and A-12. 
            % Also described in the dissertation by Markus Czupalla in
            % Equation 11-4 to 11-7. Please note that the Units for Z and
            % C_1, C_2 described in the dissertation are wrong. Refer to
            % the original source for these values!. Also note that the Z
            % value from the dissertation is just a conversion factor,
            % which is therefore not used here!
            % While the original source also provides values in kPa, the
            % paper on which that is based uses torr and the dissertation
            % also uses torr therefore it was decided to use the torr
            % values here!
            
            % The Partial pressures handed into this function are values in
            % Pa, which are therefore converted into mmHg or Torr
            fPartialPressureO2_Torr  = fPartialPressureO2  / (101325 / 760);
            fPartialPressureCO2_Torr = fPartialPressureCO2 / (101325 / 760);
            
            % O2
            fIntermediateVariableO2     = fPartialPressureO2_Torr * (1 + this.fBeta_1 * fPartialPressureCO2_Torr) / (this.fK1 * (1 + this.fAlpha_1 * fPartialPressureCO2_Torr));
            % Note according to the original source for these equations:
            % "COMPUTATIONAL EXPRESSIONS FOR BLOOD OXYGEN AND CARBON
            % DIOXIDE CONCENTRATIONS", J.L. Spencer, E. Firouztale, R.B.
            % Mellins, 1979
            % The blood is saturated with O2 at ~ 9 mmol/l
            fConcentrationO2_mmol_l     = this.fC1 * (fIntermediateVariableO2 ^ (1 / this.fa1)) / (1 + fIntermediateVariableO2 ^ (1 / this.fa1));
            
            % CO2
            fIntermediateVariableCO2    = fPartialPressureCO2_Torr * (1 + this.fBeta_2 * fPartialPressureO2_Torr) / (this.fK2 * (1 + this.fAlpha_2 * fPartialPressureO2_Torr));
            fConcentrationCO2_mmol_l    = this.fC2 * (fIntermediateVariableCO2 ^ (1 / this.fa2)) / (1 + fIntermediateVariableCO2 ^ (1 / this.fa2));
            
            % mmol would be dividing with 1000 while transforming into
            % /m^3 would multiply it with 1000 --> cancles only transform
            % into mass/m^3 instead of mol/m^3 
            % mol * kg/mol = kg/m^3 / kg/m^3 is a mass ratio (we basically
            % multiply the m^3 through wich we divide with the blood
            % density, turning it into a blood mass)
            fConcentrationO2  = fConcentrationO2_mmol_l  * this.oMT.afMolarMass(this.oMT.tiN2I.O2)  / this.fBloodDensity;
            fConcentrationCO2 = fConcentrationCO2_mmol_l * this.oMT.afMolarMass(this.oMT.tiN2I.CO2) / this.fBloodDensity;
        end
        
        function [fPartialPressureO2, fPartialPressureCO2] = calculatePartialPressuresTissue(this, afMass)
            % This calculation provides the corresponding partial pressure
            % equivalents of O2 and CO2 for the provided tissue phase and
            % calculates the flow rates of O2 and CO2 from the tissue to
            % the blood stream
            
            %% Oxygen
            fConcentrationO2 = afMass(this.oMT.tiN2I.O2) / afMass(this.oMT.tiN2I.Human_Tissue); % kg/kg
            
            fPartialPressureO2 = fConcentrationO2 / this.fHenryConstantO2;
            
            %% Carbon Dioxide
            fConcentrationCO2  = afMass(this.oMT.tiN2I.CO2)  / afMass(this.oMT.tiN2I.Human_Tissue); % kg/kg
            fConcentrationHCO3 = afMass(this.oMT.tiN2I.HCO3) / afMass(this.oMT.tiN2I.Human_Tissue); % kg/kg
            
            fDissolvedConcentrationCO2 = fConcentrationCO2 - fConcentrationHCO3;
            
            fPartialPressureCO2 = fDissolvedConcentrationCO2 / this.fHenryConstantCO2;
        end
    end
    
    methods (Access = protected)
        %% General explanation
        % The logic behind the functions is that it is aparant what the in-
        % and outputs of each calculation are to make it more transparent
        % in what order the functions must be called. While it would also
        % be possible to store all these values in properties, that would
        % likely make the code more confusing
        
        function [fNewVolumetricFlow_BrainBlood, fNewVolumetricFlow_TissueBlood] = BloodFlowControl(this, fPartialPressureO2, fPartialPressureCO2, fNewVolumetricBloodFlowFromActivity, fInternalElapsedTime)
            % This function represents the cardiac control function which
            % controls the blood flow based on the arterial partial
            % pressure of oxygen and carbon dioxide, which must be provided
            % in Pa
            %
            % Corresponds to section 11.1.1.1.10 Cardiac Controller in the
            % dissertation from Markus Czupalla or equation A24 to A27 from
            % "An integrated model of the human ventilatory control system:
            % the response to hypercapnia", Ursino, M.; Magosso, E.;
            % Avanzolini, G., 2001
            % The difference to the original source is the added blood flow
            % from activity which is only represented in the dissertation
            % not the original paper!
            fPsiO2      = this.fCardiacC1 * (exp(-(fPartialPressureO2 / this.fCardiacC2)) - exp(-(this.fBasePartialPressureO2_Arteries / this.fCardiacC2)));
            
            this.fYo2   = this.fYo2 + ((1/ this.fTauO2) * (fPsiO2 - this.fYo2)) * fInternalElapsedTime;
            
            fPsiCO2     = ((this.fCardiacA + this.fCardiacB / (1 + this.fCardiacC * exp(this.fCardiacD * log10(fPartialPressureCO2)))) / ...
                           (this.fCardiacA + this.fCardiacB / (1 + this.fCardiacC * exp(this.fCardiacD * log10(this.fBasePartialPressureCO2_Arteries))))) - 1;
            
            this.fYco2  = this.fYco2 + ((1/ this.fTauCO2) * (fPsiCO2 - this.fYco2)) * fInternalElapsedTime;
            
            % According to "Cardiovascular response to dynamicaerobic
            % exercise: a mathematical model", E. Magosso, M. Ursino, 2002
            % During activity blood flow is directed towards the muscles.
            % This was not done in the V-HAB model since the oxygen
            % consumption in the brain was also increased, which is not
            % realistic. Hence the model was adapted to maintain the brain
            % blood flow but increase the tissue blood flow and the
            % additional oxygen consumption from exercise will also occur
            % in the tissue
            fNewVolumetricFlow_BrainBlood  = this.fBaseVolumetricFlow_BrainBlood  * (1 + this.fYo2 + this.fYco2);
            fNewVolumetricFlow_TissueBlood = this.fBaseVolumetricFlow_TissueBlood * (1 + this.fCardiacRho * this.fYco2)   +  fNewVolumetricBloodFlowFromActivity;
        end
        
        function [fNewDeltaVentilationPeripheralChemorezeptor, fPeripheralChemorezeptorDelay] = PeripheralChemoreceptor(this, fTotalVolumetricFlow_Blood, fInternalElapsedTime)
            %% Peripheral Chemoreceptor
            % This section models the peripheral chemoreceptor as
            % described in the dissertation from Markus Czupalla in section
            % 11.1.1.1.12, equation (11-53) and (11-55) or in A17 and A19
            % from "An integrated model of the human ventilatory control
            % system: the response to hypercapnia", Ursino, M.; Magosso,
            % E.; Avanzolini, G., 2001
            
            
            % Equation (11-55) from the dissertation of Markus Czupalla or
            % equation A19 from "An integrated model of the human
            % ventilatory control system: the response to hypercapnia",
            % Ursino, M.; Magosso, E.; Avanzolini, G., 2001
            fPeripheralChemorezeptorDelay = this.fKdp / fTotalVolumetricFlow_Blood;
            
            % The equation uses a delay, which means the discharge
            % frequency at a different time is required. The following
            % equations are used to calculate the time point of interest
            % and select or calculate the corresponding old discharge
            % frequency!
            
            % Now we calculate the time from which we want to know the
            % partial pressure of CO2 in the brain
            fDelayedTime = this.oTimer.fTime - fPeripheralChemorezeptorDelay;
            
            % if that time is smaller than zero, we use the basal partial
            % pressure of the brain
            if fDelayedTime < 0
                fDelayedPeriheralChemorezeptorDischargeFrequency = this.fBasalPeriheralChemorezeptorDischargeFrequency;
            else
                % in this case we have to find the correct values from the
                % stored time array, either the value is directly found, or
                % there are values at an earlier and later time stored. Or
                % only an older value is found but no newer value
                abEqualTime = this.mfPeriheralChemorezeptorDischargeFrequency(1,:) == fDelayedTime;
                if any(abEqualTime)
                    fDelayedPeriheralChemorezeptorDischargeFrequency = this.mfPeriheralChemorezeptorDischargeFrequency(2,abEqualTime);
                else
                    abSmallerTime = this.mfPeriheralChemorezeptorDischargeFrequency(1,:) < fDelayedTime;
                    
                    iIndex = find(abSmallerTime, 1, 'last' );
                    if isempty(iIndex)
                        % if the index is empty we use the oldest available
                        % entry and no interpolation
                        iIndex = 1;
                        fDelayedPeriheralChemorezeptorDischargeFrequency = this.mfPeriheralChemorezeptorDischargeFrequency(2,iIndex);
                        
                    elseif all(abSmallerTime)
                        % In this case the last entry is also already from
                        % longer ago than the entries we are looking for
                        % --> use the last entry without interpolation
                        fDelayedPeriheralChemorezeptorDischargeFrequency = this.mfPeriheralChemorezeptorDischargeFrequency(2,iIndex);
                    else
                        % in this case use linear interpolation to find the
                        % correct value for the specific time
                        fDeltaTime      = this.mfPeriheralChemorezeptorDischargeFrequency(1,iIndex + 1) - this.mfPeriheralChemorezeptorDischargeFrequency(1,iIndex);
                        fDeltaFrequency = this.mfPeriheralChemorezeptorDischargeFrequency(2,iIndex + 1) - this.mfPeriheralChemorezeptorDischargeFrequency(2,iIndex);
                        
                        fDelayedPeriheralChemorezeptorDischargeFrequency = this.mfPeriheralChemorezeptorDischargeFrequency(2,iIndex) + (fDeltaFrequency / fDeltaTime) * (fDelayedTime - this.mfPeriheralChemorezeptorDischargeFrequency(1,iIndex));
                    end
                end
            end
            
            % Equation (11-53) from the dissertation of Markus Czupalla or
            % equation A18 from "An integrated model of the human
            % ventilatory control system: the response to hypercapnia",
            % Ursino, M.; Magosso, E.; Avanzolini, G., 2001
            % Note that the equation from the dissertation multiplied the
            % equation with 60, which basically changes the time constant
            % fTauP to 1s. Here the implementation from the original source
            % is used
            fNewDeltaVentilationPeripheralChemorezeptor = this.fDeltaVentilationPeripheralChemorezeptor + (...
                                                          (fInternalElapsedTime / this.fTauP) * (-this.fDeltaVentilationPeripheralChemorezeptor + this.fGp * ...
                                                          (fDelayedPeriheralChemorezeptorDischargeFrequency - this.fBasalPeriheralChemorezeptorDischargeFrequency)));
            
            this.fDeltaVentilationPeripheralChemorezeptor = fNewDeltaVentilationPeripheralChemorezeptor;
        end
        
        function fNewPeriheralChemorezeptorDischargeFrequency = calculatePeripheralChemorezeptorDischargeFrequency(this, fPartialPressureO2_Arteries, fPartialPressureCO2_Arteries)
            %% Peripheral Chemoreceptor Discharge frequency
            % This section models the peripheral chemoreceptor as
            % described in the dissertation from Markus Czupalla in section
            % 11.1.1.1.12, equation (11-54) or in A17
            % from "An integrated model of the human ventilatory control
            % system: the response to hypercapnia", Ursino, M.; Magosso,
            % E.; Avanzolini, G., 2001
            %
            % This was seperated into an individual function because the
            % actual calculation of the current peripheral chemorezeptor is
            % independent from the partial pressures because of delays.
            % Therefore, this function is called only when the variable
            % storage section is reached to save the discharge frequency at
            % the current partial pressure values for future executions of
            % the human model!
            fNewPeriheralChemorezeptorDischargeFrequency = this.fK * log(fPartialPressureCO2_Arteries / this.fBp) * (...
                                                           (this.fMaximalPeriheralChemorezeptorDischargeFrequency + this.fMinimalPeriheralChemorezeptorDischargeFrequency * ...
                                                           exp((fPartialPressureO2_Arteries - this.fPeripheralChemorezeptorPartialPressureO2_Constant) / this.fKpc)) /...
                                                           (1 + exp((fPartialPressureO2_Arteries - this.fPeripheralChemorezeptorPartialPressureO2_Constant) / this.fKpc)));
           
            if fNewPeriheralChemorezeptorDischargeFrequency > this.fMaximalPeriheralChemorezeptorDischargeFrequency
               fNewPeriheralChemorezeptorDischargeFrequency = this.fMaximalPeriheralChemorezeptorDischargeFrequency;
            elseif fNewPeriheralChemorezeptorDischargeFrequency < this.fMinimalPeriheralChemorezeptorDischargeFrequency
               fNewPeriheralChemorezeptorDischargeFrequency = this.fMinimalPeriheralChemorezeptorDischargeFrequency;
            end
            
        end
        
        function [fNewDeltaVentilationCentralChemorezeptor, fCentralChemorezeptorDelay] = CentralChemoreceptor(this, fTotalVolumetricFlow_Blood, fInternalElapsedTime)
            %% Central Chemoreceptor
            % This section models the central chemoreceptor as
            % described in the dissertation from Markus Czupalla in section
            % 11.1.1.1.13, equation (11-56) to (11-57) or in A20 and A21
            % from "An integrated model of the human ventilatory control
            % system: the response to hypercapnia", Ursino, M.; Magosso,
            % E.; Avanzolini, G., 2001
            %
            % As inputs it requires the total blood flow in m^3/s
            
            % Equation (11-57) from the dissertation of Markus Czupalla or
            % equation A21 from "An integrated model of the human
            % ventilatory control system: the response to hypercapnia",
            % Ursino, M.; Magosso, E.; Avanzolini, G., 2001
            fCentralChemorezeptorDelay = this.fKdc / fTotalVolumetricFlow_Blood;
            
            % The equation uses a delay, which means the partial pressure
            % of CO2 in the brain at a different time is required. The
            % following equations are used to calculate the time point of
            % interest and select or calculate the corresponding old
            % partial pressure!
            
            % Now we calculate the time from which we want to know the
            % partial pressure of CO2 in the brain
            fDelayedTime = this.oTimer.fTime - fCentralChemorezeptorDelay;
            
            % if that time is smaller than zero, we use the basal partial
            % pressure of the brain
            if fDelayedTime < 0
                fDelayedPartialPressureCO2_Brain = this.fBasePartialPressureCO2_Brain;
            else
                % in this case we have to find the correct values from the
                % stored time array, either the value is directly found, or
                % there are values at an earlier and later time stored. Or
                % only an older value is found but no newer value
                abEqualTime = this.mfPartialPressureCO2_Brain(1,:) == fDelayedTime;
                if any(abEqualTime)
                    fDelayedPartialPressureCO2_Brain = this.mfPartialPressureCO2_Brain(2,abEqualTime);
                else
                    abSmallerTime = this.mfPartialPressureCO2_Brain(1,:) < fDelayedTime;
                    
                    iIndex = find(abSmallerTime, 1, 'last' );
                    if isempty(iIndex)
                        % if the index is empty we use the oldest available
                        % entry and no interpolation
                        iIndex = 1;
                        fDelayedPartialPressureCO2_Brain = this.mfPartialPressureCO2_Brain(2,iIndex);
                        
                    elseif all(abSmallerTime)
                        % In this case the last entry is also already from
                        % longer ago than the entries we are looking for
                        % --> use the last entry without interpolation
                        fDelayedPartialPressureCO2_Brain = this.mfPartialPressureCO2_Brain(2,iIndex);
                        
                    else
                        % in this case use linear interpolation to find the
                        % correct value for the specific time
                        fDeltaTime      = this.mfPartialPressureCO2_Brain(1,iIndex + 1) - this.mfPartialPressureCO2_Brain(1,iIndex);
                        fDeltaPressure  = this.mfPartialPressureCO2_Brain(2,iIndex + 1) - this.mfPartialPressureCO2_Brain(2,iIndex);
                        
                        fDelayedPartialPressureCO2_Brain = this.mfPartialPressureCO2_Brain(2,iIndex) + (fDeltaPressure / fDeltaTime) * (fDelayedTime - this.mfPartialPressureCO2_Brain(1,iIndex));
                    end
                end
            end
            
            % Equation (11-56) from the dissertation of Markus Czupalla or
            % equation A20 from "An integrated model of the human
            % ventilatory control system: the response to hypercapnia",
            % Ursino, M.; Magosso, E.; Avanzolini, G., 2001
            % Note that the equation from the dissertation multiplied the
            % equation with 60, which basically changes the time constant
            % fTauC to 1s. Here the implementation from the original source
            % is used
            fDeltaVentialtionChange = ((fInternalElapsedTime / this.fTauC) * (-this.fDeltaVentilationCentralChemorezeptor + this.fGc * (fDelayedPartialPressureCO2_Brain - this.fBasePartialPressureCO2_Brain)));
            fNewDeltaVentilationCentralChemorezeptor = this.fDeltaVentilationCentralChemorezeptor + fDeltaVentialtionChange;
                                                     
            this.fDeltaVentilationCentralChemorezeptor = fNewDeltaVentilationCentralChemorezeptor;
        end
            
        function fNewAlphaH = CentralVentilationDepression(this, fPartialPressureO2_Brain, fInternalElapsedTime)
            %% Central Ventilation Depression
            % this section models the central ventilation depression as
            % described in the dissertation from Markus Czupalla in section
            % 11.1.1.1.14, equation (11-58) to (11-61) or in equation A22
            % to A23 from "An integrated model of the human ventilatory
            % control system: the response to hypercapnia", Ursino, M.;
            % Magosso, E.; Avanzolini, G., 2001
            if fPartialPressureO2_Brain < this.fThetaHmin
                fHstat = 1 + this.fGH * ((this.fThetaHmin           - this.fBasePartialPressureO2_Brain) / this.fBasePartialPressureO2_Brain);
                
            elseif fPartialPressureO2_Brain > this.fThetaHmax
                fHstat = 1 + this.fGH * ((this.fThetaHmax           - this.fBasePartialPressureO2_Brain) / this.fBasePartialPressureO2_Brain);
                
            else
                fHstat = 1 + this.fGH * ((fPartialPressureO2_Brain  - this.fBasePartialPressureO2_Brain) / this.fBasePartialPressureO2_Brain);
                
            end
            
            fNewAlphaH      = this.fAlphaH + ((1 / this.fTauH) * (- this.fAlphaH) * fHstat) * fInternalElapsedTime;
            this.fAlphaH    = fNewAlphaH;
        end
        
        function [fNewVolumetricBloodFlowFromActivity, fDeltaVentilationActivity] = ActivityControl(this)
            %% Activity Control
            % this section models the activity control for blood and ventilation as
            % described in the dissertation from Markus Czupalla in section
            % 11.1.1.1.15, equation (11-62) to (11-67). It is an addition
            % to the model which is original to the dissertation
            
            rActivityLevel = this.oParent.toChildren.Metabolic.rActivityLevel;
            
            % Equation (11-65)
            fSteadyVentilationResponseToExercise  = this.fAv * rActivityLevel + this.fBv * rActivityLevel^2;
            % Equation (11-63)
            fInstantVentilationResponseToExercise = 0.45 * fSteadyVentilationResponseToExercise;
            
            % Equation (11-64)
            fNewDelayedVentilationResponseToExercise = this.fDelayedVentilationResponseToExercise + ...
                                                       (1 / this.fTauV) * (-this.fDelayedVentilationResponseToExercise + 0.55 * fSteadyVentilationResponseToExercise);
            
            this.fDelayedVentilationResponseToExercise = fNewDelayedVentilationResponseToExercise;
            
            % Equation (11-62)
            fDeltaVentilationActivity = fInstantVentilationResponseToExercise + fNewDelayedVentilationResponseToExercise;
            
            if rActivityLevel <= 0.4
                % Equation (11-66)
                fNewVolumetricBloodFlowFromActivity = 13.115 * rActivityLevel;
            else
                % Equation (11-67)
                fNewVolumetricBloodFlowFromActivity = -9.84 * rActivityLevel^2 + 21.25 * rActivityLevel - 1.69;
            end
            % The calculated blood flow is in l/min so we have to convert
            % it:
            fNewVolumetricBloodFlowFromActivity = fNewVolumetricBloodFlowFromActivity / 60000;
            
        end
        
        function fWaterFlowRate = calculateWaterOutput(this, fCurrentAirInletFlow)
            % This function was not yet implemented in the V-HAB 1 human
            % model, it calculates the water released by respiration,
            % assuming that the exhaled air is at 100% humidity
            
            % We get the inflowing partial pressure of water
            fPartialPressureH2OInlet = this.oParent.toBranches.Air_In.coExmes{2}.oPhase.afPP(this.oMT.tiN2I.H2O);
            
            % And calculate the amount of water that must be injected to
            % reach 100% humidity:
            fVaporPressure = this.oMT.calculateVaporPressure(this.toStores.Lung.toPhases.Air.fTemperature, 'H2O');
            
            fDeltaWaterPressure = fVaporPressure - fPartialPressureH2OInlet;
            
            fVolumetricInletFlowrate = (fCurrentAirInletFlow * (this.oMT.Const.fUniversalGas / this.oParent.toBranches.Air_In.coExmes{2}.oPhase.fMolarMass) * this.oParent.toBranches.Air_In.coExmes{2}.oPhase.fTemperature) / this.oParent.toBranches.Air_In.coExmes{2}.oPhase.fPressure;
            
            fWaterFlowRate = (fDeltaWaterPressure * fVolumetricInletFlowrate) / ((this.oMT.Const.fUniversalGas / this.oMT.afMolarMass(this.oMT.tiN2I.H2O)) * this.toStores.Lung.toPhases.Air.fTemperature);
            
            % happens when the air already is at 100% humidity or above
            if fWaterFlowRate < 0
                fWaterFlowRate = 0;
            end
        end
        
        function exec(this, ~)
            exec@vsys(this);
            % We do not use the exec functions of the human layers, as it
            % is not possible to define the update order if we use the exec
            % functions!!
        end
        
        function afMassChangeRate = calculateChangeRate(this, afMasses, fTime, fInternalElapsedTime, arMassArteries)
            
            afMassBrainBlood   = afMasses(1:this.oMT.iSubstances)';
            afMassBrainTissue  = afMasses(this.oMT.iSubstances + 1     : 2 * this.oMT.iSubstances)';
            afMassTissueBlood  = afMasses(2 * this.oMT.iSubstances + 1 : 3 * this.oMT.iSubstances)';
            afMassTissueTissue = afMasses(3 * this.oMT.iSubstances + 1 : 4 * this.oMT.iSubstances)';
            
            arMassBrainBlood  = afMassBrainBlood ./ sum(afMassBrainBlood);
            arMassTissueBlood = afMassTissueBlood ./ sum(afMassTissueBlood);
            
            
            % Calculate the current partial pressure of oxygen and co2 in
            % the arteries
            [fPartialPressureO2_Arteries, fPartialPressureCO2_Arteries]     = this.calculateBloodPartialPressure(arMassArteries(this.oMT.tiN2I.O2), arMassArteries(this.oMT.tiN2I.CO2));
            
            
            %% Blood Flow Calculations
            % Using these pressure values we can calculate the current
            % blood flow through the brain and the tissue
            [fNewVolumetricFlow_BrainBlood, fNewVolumetricFlow_TissueBlood] = this.BloodFlowControl(fPartialPressureO2_Arteries, fPartialPressureCO2_Arteries, this.fNewVolumetricBloodFlowFromActivity, fInternalElapsedTime);
            
            % Since the calculated values are volumetric, we have to
            % transform them into mass flows
            this.tfBloodFlows.fCurrentTissueBloodFlow =  fNewVolumetricFlow_TissueBlood * this.fBloodDensity;
            this.tfBloodFlows.fCurrentBrainBloodFlow  =  fNewVolumetricFlow_BrainBlood  * this.fBloodDensity;
            this.tfBloodFlows.fCurrentTotalBloodFlow  =  this.tfBloodFlows.fCurrentTissueBloodFlow + this.tfBloodFlows.fCurrentBrainBloodFlow;
            
            this.tfBloodFlows.fCurrentAlveolaBloodFlow = this.tfBloodFlows.fCurrentTotalBloodFlow * (1 - this.rPulmonaryShunt);
            this.tfBloodFlows.fCurrentShuntBloodFlow   = this.tfBloodFlows.fCurrentTotalBloodFlow - this.tfBloodFlows.fCurrentAlveolaBloodFlow;
            
            %% Calculate gas exchange flows in the brain
            [fPartialPressureO2_Brain, fPartialPressureCO2_Brain] = this.calculatePartialPressuresTissue(afMassBrainTissue);
            
            [fConcentrationO2, fConcentrationCO2] = this.calculateBloodConcentrations(fPartialPressureO2_Brain, fPartialPressureCO2_Brain);
            % now we subtract inlet and outlet concentration, the
            % difference is what the P2P absorbs. The concentrations are
            % calculated in kg/kg and therefore are actually mass ratios
            fAdsorptionFlowRateO2_Brain  =   this.tfBloodFlows.fCurrentBrainBloodFlow * (arMassBrainBlood(this.oMT.tiN2I.O2)  - fConcentrationO2);
            fDesorptionFlowRateCO2_Brain = - this.tfBloodFlows.fCurrentBrainBloodFlow * (arMassBrainBlood(this.oMT.tiN2I.CO2) - fConcentrationCO2);
            
            afPartialFlowRatesBrainO2 = zeros(1, this.oMT.iSubstances);
            afPartialFlowRatesBrainO2(this.oMT.tiN2I.O2) = fAdsorptionFlowRateO2_Brain;
            
            afPartialFlowRatesBrainCO2 = zeros(1, this.oMT.iSubstances);
            afPartialFlowRatesBrainCO2(this.oMT.tiN2I.CO2) = fDesorptionFlowRateCO2_Brain;
            
            %% calculate gas exchange flows in the tissue
            [fPartialPressureO2, fPartialPressureCO2] = this.calculatePartialPressuresTissue(afMassTissueTissue);
            
            [fConcentrationO2, fConcentrationCO2] = this.calculateBloodConcentrations(fPartialPressureO2, fPartialPressureCO2);
            % now we subtract inlet and outlet concentration, the
            % difference is what the P2P absorbs. The concentrations are
            % calculated in kg/kg and therefore are actually mass ratios
            fAdsorptionFlowRateO2_Tissue  =   this.tfBloodFlows.fCurrentTissueBloodFlow * (arMassTissueBlood(this.oMT.tiN2I.O2)  - fConcentrationO2);
            fDesorptionFlowRateCO2_Tissue = - this.tfBloodFlows.fCurrentTissueBloodFlow * (arMassTissueBlood(this.oMT.tiN2I.CO2) - fConcentrationCO2);
            
            afPartialFlowRatesTissueO2 = zeros(1, this.oMT.iSubstances);
            afPartialFlowRatesTissueO2(this.oMT.tiN2I.O2) = fAdsorptionFlowRateO2_Tissue;
            
            afPartialFlowRatesTissueCO2 = zeros(1, this.oMT.iSubstances);
            afPartialFlowRatesTissueCO2(this.oMT.tiN2I.CO2) = fDesorptionFlowRateCO2_Tissue;
            
            %% Ventilation Control
            % This section handles the calculation of the new volumetric
            % air flow rate. For this purpose the corresponding functions
            % to calculate the necessary parameters are called here
            fTotalVolumetricFlow_Blood = this.tfBloodFlows.fCurrentTotalBloodFlow / this.fBloodDensity;
            fNewAlphaH                                          = this.CentralVentilationDepression( fPartialPressureO2_Brain,      fInternalElapsedTime);
            [fNewDeltaVentilationCentralChemorezeptor,      ~] 	= this.CentralChemoreceptor(         fTotalVolumetricFlow_Blood ,   fInternalElapsedTime);
            [fNewDeltaVentilationPeripheralChemorezeptor,   ~]  = this.PeripheralChemoreceptor(      fTotalVolumetricFlow_Blood,    fInternalElapsedTime);
            
            % Equation (11-51) from the dissertation by Markus Czupalla or 
            % A15 from "An integrated model of the human ventilatory
            % control system: the response to hypercapnia", Ursino, M.;
            % Magosso, E.; Avanzolini, G., 2001
            fCurrentVolumetricFlow_Air = this.fBaseVolumetricFlow_Air + fNewAlphaH * fNewDeltaVentilationPeripheralChemorezeptor + fNewDeltaVentilationCentralChemorezeptor + this.fDeltaVentilationActivity;
            
            % According to A15 the value cannot become negative, but zero
            % (apneic phase)
            if fCurrentVolumetricFlow_Air < 0
                fCurrentVolumetricFlow_Air = 1e-6;
            end
            
            % Equation (11-52) from the dissertation by Markus Czupalla or
            % A16 from "An integrated model of the human ventilatory
            % control system: the response to hypercapnia", Ursino, M.;
            % Magosso, E.; Avanzolini, G., 2001
            fCurrentVolumetricFlow_AlveolaAir = fCurrentVolumetricFlow_Air * (1 - this.rDeadSpaceFractionLung);
            
            % We could also set a volumetric flow rate to the branch, but
            % then outlet branch would have to react dynamically. Also
            % since a large enough change in the inlet air conditions
            % necessitates a complete recalculation of the respiratory
            % layer, it does not provide a real advantage.
            fCurrentAirInletFlow = this.oParent.toBranches.Air_In.coExmes{2}.oPhase.fDensity * fCurrentVolumetricFlow_AlveolaAir;
            
            %% Built rate vector for ODE
            % Now we built rate vector for each compartment in the
            % respiratory layer which can then be combined to an overall
            % mass change vector
            
            % Brain Blood:
            afFlowratesBrainBlood = this.tfBloodFlows.fCurrentBrainBloodFlow .* (arMassArteries - arMassBrainBlood);
            afFlowratesBrainBlood = afFlowratesBrainBlood - afPartialFlowRatesBrainO2 + afPartialFlowRatesBrainCO2;
            
            % Tissue Blood:
            afFlowratesTissueBlood = this.tfBloodFlows.fCurrentTissueBloodFlow .* (arMassArteries - arMassTissueBlood);
            afFlowratesTissueBlood = afFlowratesTissueBlood - afPartialFlowRatesTissueO2 + afPartialFlowRatesTissueCO2;
            
            % Brain Tissue:
            afFlowratesBrainTissue = afPartialFlowRatesBrainO2 - afPartialFlowRatesBrainCO2;
            afFlowratesBrainTissue(this.oMT.tiN2I.CO2) = afFlowratesBrainTissue(this.oMT.tiN2I.CO2) + this.oParent.toBranches.CO2_to_Brain.fFlowRate;
            afFlowratesBrainTissue(this.oMT.tiN2I.O2)  = afFlowratesBrainTissue(this.oMT.tiN2I.O2) - this.oParent.toBranches.O2_from_Brain.fFlowRate;
            
            % Tissue Tissue:
            afFlowratesTissueTissue = afPartialFlowRatesTissueO2 - afPartialFlowRatesTissueCO2;
            afFlowratesTissueTissue(this.oMT.tiN2I.CO2) = afFlowratesTissueTissue(this.oMT.tiN2I.CO2) + this.oParent.toBranches.CO2_to_Tissue.fFlowRate;
            afFlowratesTissueTissue(this.oMT.tiN2I.O2)  = afFlowratesTissueTissue(this.oMT.tiN2I.O2) - this.oParent.toBranches.O2_from_Tissue.fFlowRate;
            
            afMassChangeRate = [afFlowratesBrainBlood';...
                              	afFlowratesBrainTissue';...
                              	afFlowratesTissueBlood';...
                             	afFlowratesTissueTissue'];
                            
            % In this case we are not actually interested in the masses the
            % ODE calculates as results, but rather in the flowrates that
            % are calculated in between:
            this.tOdeFlowRates.afPartialFlowRatesBrainO2(end+1,:)     = afPartialFlowRatesBrainO2;
            this.tOdeFlowRates.afPartialFlowRatesBrainCO2(end+1,:)    = afPartialFlowRatesBrainCO2;
            this.tOdeFlowRates.afPartialFlowRatesTissueO2(end+1,:)    = afPartialFlowRatesTissueO2;
            this.tOdeFlowRates.afPartialFlowRatesTissueCO2(end+1,:)   = afPartialFlowRatesTissueCO2;
            this.tOdeFlowRates.fCurrentTissueBloodFlow(end+1)         = this.tfBloodFlows.fCurrentTissueBloodFlow;
            this.tOdeFlowRates.fCurrentBrainBloodFlow(end+1)          = this.tfBloodFlows.fCurrentBrainBloodFlow;
            this.tOdeFlowRates.fCurrentTotalBloodFlow(end+1)          = this.tfBloodFlows.fCurrentTotalBloodFlow;
            this.tOdeFlowRates.fCurrentAlveolaBloodFlow(end+1)        = this.tfBloodFlows.fCurrentAlveolaBloodFlow;
            this.tOdeFlowRates.fCurrentAirInletFlow(end+1)            = fCurrentAirInletFlow;
            this.tOdeFlowRates.fTime(end+1)                           = fTime;
            
            
            %% Variable Storage handling
            % for a few variables it is necessary to store values over time
            % to model delays. This is handled at the end of the update in
            % this section

            % Store the value of partial pressure for future calculations
            this.mfPartialPressureCO2_Brain(1,end+1) = fTime;
            this.mfPartialPressureCO2_Brain(2,end) = fPartialPressureCO2_Brain;

            % If the vector already has more than 4000 entries, remove the
            % first entry. We do not want to keep data for several weeks
            % stored in here!
            if length(this.mfPartialPressureCO2_Brain) > 4000
                this.mfPartialPressureCO2_Brain(:,1) = [];
            end

            % store the discharge frequency of the peripheral chemoreceptor
            this.mfPeriheralChemorezeptorDischargeFrequency(1,end+1) = fTime;
            this.mfPeriheralChemorezeptorDischargeFrequency(2,end)   = calculatePeripheralChemorezeptorDischargeFrequency(this, fPartialPressureO2_Arteries, fPartialPressureCO2_Arteries);

            % If the vector already has more than 4000 entries, remove the
            % first entry. We do not want to keep data for several weeks
            % stored in here!
            if length(this.mfPeriheralChemorezeptorDischargeFrequency) > 4000
                this.mfPeriheralChemorezeptorDischargeFrequency(:,1) = [];
            end

            %% Informative Variable Story
            % In this section we only store variables as properties that
            % are interesting for logging and plotting purposes. They could
            % also be removed from the list of properties and the code
            % would still function
            this.fVolumetricFlow_BrainBlood         = fNewVolumetricFlow_BrainBlood;
            this.fVolumetricFlow_TissueBlood        = fNewVolumetricFlow_TissueBlood;
            this.fVolumetricFlow_Air                = fCurrentVolumetricFlow_Air;

            this.tfPartialPressure.Brain.O2         = fPartialPressureO2_Brain;
            this.tfPartialPressure.Brain.CO2        = fPartialPressureCO2_Brain;
            this.tfPartialPressure.Tissue.O2        = fPartialPressureO2;
            this.tfPartialPressure.Tissue.CO2       = fPartialPressureCO2;
            this.tfPartialPressure.Arteries.O2      = fPartialPressureO2_Arteries;
            this.tfPartialPressure.Arteries.CO2     = fPartialPressureCO2_Arteries;
        end
    end
    methods (Access = {?components.matter.DetailedHuman.Human})
        
        function update(this)
            
            this.fElapsedTime = this.oTimer.fTime - this.fLastRespirationUpdate;
            
            % Calculate the current impact of activity on the respiration
            % and blood flow
            [this.fNewVolumetricBloodFlowFromActivity, this.fDeltaVentilationActivity] = this.ActivityControl();
            
            
            fStepBeginTime = this.fLastRespirationUpdate;
            fStepEndTime   = this.oTimer.fTime;
            
            this.tOdeFlowRates = struct();
            this.tOdeFlowRates.afPartialFlowRatesBrainO2(1,:)     = zeros(1, this.oMT.iSubstances);
            this.tOdeFlowRates.afPartialFlowRatesBrainCO2(1,:)    = zeros(1, this.oMT.iSubstances);
            this.tOdeFlowRates.afPartialFlowRatesTissueO2(1,:)    = zeros(1, this.oMT.iSubstances);
            this.tOdeFlowRates.afPartialFlowRatesTissueCO2(1,:)   = zeros(1, this.oMT.iSubstances);
            this.tOdeFlowRates.fCurrentTissueBloodFlow(1)         = 0;
            this.tOdeFlowRates.fCurrentBrainBloodFlow(1)          = 0;
            this.tOdeFlowRates.fCurrentTotalBloodFlow(1)          = 0;
            this.tOdeFlowRates.fCurrentAlveolaBloodFlow(1)        = 0;
            this.tOdeFlowRates.fCurrentAirInletFlow(1)            = 0;
            this.tOdeFlowRates.fTime(1)                           = this.oTimer.fTime;

            if ~any(this.toStores.Arteries.toPhases.Blood.arPartialMass ~= 0)
                afInitialMasses = [this.toStores.Brain.toPhases.Blood.afMass';...
                                   this.toStores.Brain.toPhases.Tissue.afMass';...
                                   this.toStores.Tissue.toPhases.Blood.afMass';...
                                   this.toStores.Tissue.toPhases.Tissue.afMass'];
            else
                afInitialMasses = [this.toStores.Brain.toPhases.Blood.afMass';...
                                   this.toStores.Brain.toPhases.Tissue.afMass';...
                                   this.toStores.Tissue.toPhases.Blood.afMass';...
                                   this.toStores.Tissue.toPhases.Tissue.afMass'];
            end
            % For an ODE solver to work, a different way to handle the
            % delayed chemorezeptor responses would be necessary, as the
            % hCalculatueChangeRate function is called with varying times.
            % Also a way to get the elapsed time compared to previous step
            % would be necessary or these parts would have to be better
            % integrated into the ODE.
            % if (fStepEndTime - fStepBeginTime) > 1
            %     [mfSolutionTimes, afSolutionMasses] = ode45(this.hCalculateChangeRate, [fStepBeginTime, fStepEndTime], afInitialMasses, this.tOdeOptions);
            % else

            fOriginalInternalStep = this.fInternalTimeStep;
            if (fStepEndTime - fStepBeginTime) < this.fInternalTimeStep
                mfTimes = [fStepBeginTime fStepEndTime];
            else
                fSteps = (fStepEndTime - fStepBeginTime) / this.fInternalTimeStep;
                this.fInternalTimeStep = this.fInternalTimeStep * (1 + mod(fSteps, 1)  ./ floor(fSteps));

                mfTimes = fStepBeginTime:this.fInternalTimeStep:fStepEndTime;
            end

            afMasses = afInitialMasses;

            for iTime = 2:length(mfTimes)
                if iTime > 2
                    afMassBrainBlood   = afMasses(1:this.oMT.iSubstances)';
                    afMassTissueBlood  = afMasses(2 * this.oMT.iSubstances + 1 : 3 * this.oMT.iSubstances)';

                    arMassBrainBlood  = afMassBrainBlood ./ sum(afMassBrainBlood);
                    arMassTissueBlood = afMassTissueBlood ./ sum(afMassTissueBlood);
            
                    % Built partial mass ratio vectors for the flow phases based on
                    % the current conditions
                    % Veins:
                    if this.tfBloodFlows.fCurrentTotalBloodFlow == 0
                        arMassVeins = zeros(1, this.oMT.iSubstances);
                    else
                        arMassVeins = (this.tfBloodFlows.fCurrentTissueBloodFlow .* arMassTissueBlood + this.tfBloodFlows.fCurrentBrainBloodFlow .* arMassBrainBlood) / this.tfBloodFlows.fCurrentTotalBloodFlow;
                    end

                    % Alveola:
                    afFlowRatesAlveola = this.toStores.Lung.toProcsP2P.Air_to_Alveola.fFlowRate .* this.toStores.Lung.toProcsP2P.Air_to_Alveola.arPartialMass;
                    afFlowRatesAlveola = afFlowRatesAlveola - (this.toStores.Lung.toProcsP2P.Alveola_to_Air.fFlowRate .* this.toStores.Lung.toProcsP2P.Alveola_to_Air.arPartialMass);
                    % We also have to include the mass change from different in and
                    % out flow compositions
                    afFlowRatesAlveola = afFlowRatesAlveola + (this.tfBloodFlows.fCurrentAlveolaBloodFlow .* arMassVeins);
                    afFlowRatesAlveola(afFlowRatesAlveola < 0) = 0;
                    
                    % Since for alveola we only consider the ratios, not the total
                    % masses we adjust the vector to reflect ratio changes:
                    if sum(afFlowRatesAlveola) == 0
                        arMassAlveola = zeros(1, this.oMT.iSubstances);
                    else
                        arMassAlveola = (afFlowRatesAlveola ./ sum(afFlowRatesAlveola));
                    end

                    % Arteries:
                    if this.tfBloodFlows.fCurrentTotalBloodFlow == 0
                        arMassArteries = zeros(1, this.oMT.iSubstances);
                    else
                        arMassArteries = (this.tfBloodFlows.fCurrentShuntBloodFlow .* arMassVeins + this.tfBloodFlows.fCurrentAlveolaBloodFlow .* arMassAlveola) / this.tfBloodFlows.fCurrentTotalBloodFlow;
                    end
                    
                else
                    arMassArteries  = this.toStores.Arteries.toPhases.Blood.arPartialMass;
                end
                fInternalElapsedTime = mfTimes(iTime) - mfTimes(iTime - 1);
                
                afMassChangeRate = this.calculateChangeRate(afMasses, mfTimes(iTime), fInternalElapsedTime, arMassArteries);
                
                afMasses = afMasses + afMassChangeRate .* (mfTimes(iTime) - mfTimes(iTime-1));
                afMasses(afMasses < 0) = 0;
            end

            iSteps = length(mfTimes) - 1;
            afPartialFlowRatesBrainO2   = sum(this.tOdeFlowRates.afPartialFlowRatesBrainO2(2:end,:), 1) ./ iSteps;
            afPartialFlowRatesBrainCO2  = sum(this.tOdeFlowRates.afPartialFlowRatesBrainCO2(2:end,:), 1) ./ iSteps;
            afPartialFlowRatesTissueO2  = sum(this.tOdeFlowRates.afPartialFlowRatesTissueO2(2:end,:), 1) ./ iSteps;
            afPartialFlowRatesTissueCO2 = sum(this.tOdeFlowRates.afPartialFlowRatesTissueCO2(2:end,:), 1) ./ iSteps;
            fCurrentTissueBloodFlow     = sum(this.tOdeFlowRates.fCurrentTissueBloodFlow(2:end)) ./ iSteps;
            fCurrentBrainBloodFlow      = sum(this.tOdeFlowRates.fCurrentBrainBloodFlow(2:end)) ./ iSteps;
            fCurrentAlveolaBloodFlow    = sum(this.tOdeFlowRates.fCurrentAlveolaBloodFlow(2:end)) ./ iSteps;
            fCurrentAirInletFlow        = sum(this.tOdeFlowRates.fCurrentAirInletFlow(2:end)) ./ iSteps;
                
            this.fInternalTimeStep = fOriginalInternalStep;
            
            %% Set branch and P2P flow rates
            % Only some branches are set manually, the remaining branches
            % are multi solver branches to ensure mass balance and correct
            % calculation of the P2Ps
            this.oParent.toBranches.Air_In.oHandler.setFlowRate(- fCurrentAirInletFlow);

            this.toBranches.Arteries_to_Brain.oHandler.setFlowRate(     fCurrentBrainBloodFlow);
            this.toBranches.Brain_to_BrainOutlet.oHandler.setFlowRate(	fCurrentBrainBloodFlow);

            this.toBranches.Tissue_to_TissueOutlet.oHandler.setFlowRate(fCurrentTissueBloodFlow);

            this.toBranches.Veins_to_Alveola.oHandler.setFlowRate(      fCurrentAlveolaBloodFlow);

            if any([~isreal(fCurrentAirInletFlow), ~isreal(fCurrentBrainBloodFlow), ~isreal(fCurrentTissueBloodFlow), ~isreal(fCurrentAlveolaBloodFlow)])
                keyboard()
            end
            % different from the V-HAB 1 model we add the water consumption
            % from respiration here:
            this.fRespirationWaterOutput = this.calculateWaterOutput(fCurrentAirInletFlow);
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.oMT.tiN2I.H2O)      = this.fRespirationWaterOutput;
            this.oParent.toBranches.RespirationWaterOutput.oHandler.setFlowRate(afPartialFlowRates);

            this.toStores.Brain.toProcsP2P.Blood_to_Brain.setFlowRate(afPartialFlowRatesBrainO2);
            this.toStores.Brain.toProcsP2P.Brain_to_Blood.setFlowRate(afPartialFlowRatesBrainCO2);
            this.toStores.Tissue.toProcsP2P.Blood_to_Tissue.setFlowRate(afPartialFlowRatesTissueO2);
            this.toStores.Tissue.toProcsP2P.Tissue_to_Blood.setFlowRate(afPartialFlowRatesTissueCO2);

            this.fLastRespirationUpdate = this.oTimer.fTime;
        end
    end
end