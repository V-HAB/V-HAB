classdef WaterBalance < vsys
    
    properties
        % The osmolality of the different phases within this model
        tfOsmolality; % [mol/kg]
        
        % A helper to easily find the mass indicies for the modelled
        % solvents
        aiSolvents;
        
        % The initial masses of the different phases are stored in this
        % struct
        tfInitialMasses;
        tfInitialOsmolalities;
        
        fLastKidneyUpdateTime = 0;
        
        fInitialExtracellularFluidVolume;
        fInitialBloodPlasmaVolume;
        fConcentrationOfADHinBloodPlasma            = 4;    %[munits/l]
        fConcentrationChangeOfADH                   = 0;    %[(munits/l) / s]
        
        fConcentrationOfReninInBloodPlasma          = 0.06; %[ng/l]
        fConcentrationChangeOfRenin                 = 0;    %[(ng/l) / s]
        
        fConcentrationOfAngiotensinIIInBloodPlasma  = 27;   %[ng/l]
        fConcentrationChangeOfAngiotensinII         = 0;    %[(ng/l) / s]
        
        fConcentrationOfAldosteronInBloodPlasma     = 85;   %[ng/l]
        fConcentrationChangeOfAldosteron            = 0;    %[(ng/l) / s]
        
        rRatioOfAvailableSweat = 0;
        
        fThirst = 0;
        fMinimumDailyWaterIntake = 2.5;
        fRemainingMinimumDailyWaterIntake = 2.5;
        fTimeInCurrentDay = 0;
        
        fLastInternalUpdate = 0;
        
        hBindPostTickInternalUpdate;
        bInternalUpdateRegistered = false;
        hCalculateChangeRate;
        
        fCurrenStepDensityH2O;
        
        
        tOdeOptions = odeset('RelTol', 1e-3, 'AbsTol', 1e-4);
    end
    
    properties (Constant)
        % Base Concentrations in blood plasma
        % Note that mmol/l is equivalent to mol/m^3! But in the original
        % model everything was stated in mmol/l
        tfBaseConcentrations = struct('BloodPlasma', struct(...
            'Naplus'   	,   142,...  mmol/l
            'Kplus'    	,   4.3,...  mmol/l
            'Ca2plus' 	,   1.5,...  mmol/l
            'Mg2plus'  	,   0.4,...  mmol/l
            'Clminus'  	,   104,...  mmol/l
            'HCO3'      ,   24,...   mmol/l
            'HPO4'      ,   1),...   mmol/l
            ...
            'InterstitialFluid', struct(...
            'Naplus'   	,   143,...  mmol/l
            'Kplus'    	,   4,...    mmol/l
            'Ca2plus' 	,   1.3,...  mmol/l
            'Mg2plus'  	,   0.5,...  mmol/l
            'Clminus'  	,   115,...  mmol/l
            'HCO3'      ,   27,...   mmol/l
            'HPO4'      ,   1),...   mmol/l
            ...
            'IntracellularFluid', struct(...
            'Naplus'   	,   12,...   mmol/l
            'Kplus'    	,   140,...  mmol/l
            'Ca2plus' 	,   0.0005,... mmol/l
            'Mg2plus'  	,   0.8495,... mmol/l
            'Clminus'  	,   3,...    mmol/l
            'HCO3'      ,   10,...   mmol/l
            'HPO4'      ,   15));  % mmol/l
        
        % The osmotic coefficient (unitless)
        fOsmoticCoefficient = 0.96;
        
        fHydraulicConductivity      = 2.54167e-14;  % [m^3 / (N kg s)]
        fReflectionCoefficient      = 0.7;          % [-]
        fPermeabilityOfEndothelium  = 6.24e-7;      % [m/s]
        
        fCellMembraneExchangeArea   = 3.55e11;      % [m^2]
        fPermeabilityOfCellMembrane = 1.48e-22;     % [m/s]
        
        fKidneyBloodFlowResistance  = 86.61;        % [mmHg * min / l]
        
        % Volumes:
        fBloodPlasmaVolume          = 2.8e-3;
        fInterstitialFluidVolume    = 13.1e-3;
        fIntracellularFluidVolume 	= 26.1e-3;
        fKidneyVolume               = 0.3e-3; %no source, just a possible value
        fBladderVolume              = 0.35e-3; %bladder assumed to have a volume of 350 ml
        
    end
    
    methods
        function this = WaterBalance(oParent, sName)
            this@vsys(oParent, sName, inf);
            
            this.hBindPostTickInternalUpdate  = this.oTimer.registerPostTick(@this.updateInteralFlowrates,   'matter',        'pre_solver');
            
            % Define rate of change function for ODE solver.
            this.hCalculateChangeRate = @(t, m) this.calculateChangeRate(m, t);
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            fWaterBalanceVolume = this.fBloodPlasmaVolume + this.fInterstitialFluidVolume + this.fIntracellularFluidVolume + this.fKidneyVolume + this.fBladderVolume;
             
            this.aiSolvents = [ this.oMT.tiN2I.Naplus,...
                                this.oMT.tiN2I.Kplus,...
                                this.oMT.tiN2I.Ca2plus,...
                                this.oMT.tiN2I.Mg2plus,...
                                this.oMT.tiN2I.Clminus,...
                                this.oMT.tiN2I.HCO3,...
                                this.oMT.tiN2I.HPO4];
            
            matter.store(this, 'WaterBalance', fWaterBalanceVolume);
            
            %% Blood Plasma
            fDensityH2O = this.oMT.calculateDensity('liquid', struct('H2O', 1), this.oParent.fBodyCoreTemperature, 1e5);
            
            % These are converted into mass concentrations kg (x) / kg (H2O)
            % using a temperature of 309.95 K and 1e5 Pa as conditions for the
            % water density calculation (993.3787 kg/m^3)
            % 142 * this.oMT.afMolarMass(this.oMT.tiN2I.Naplus) / fDensityH2O
            csFields = fieldnames(this.tfBaseConcentrations.BloodPlasma);
            fH2O_MassConcentration = 1;
            
            tfBloodPlasmaInitialMasses = struct();
            for iField = 1:length(csFields)
                tfBloodPlasmaInitialMasses.(csFields{iField}) = this.tfBaseConcentrations.BloodPlasma.(csFields{iField}) * this.oMT.afMolarMass(this.oMT.tiN2I.(csFields{iField})) / fDensityH2O;
                fH2O_MassConcentration = fH2O_MassConcentration - tfBloodPlasmaInitialMasses.(csFields{iField});
            end
            tfBloodPlasmaInitialMasses.H2O = fH2O_MassConcentration;
            
            oBloodPlasma                = this.toStores.WaterBalance.createPhase(	'liquid',   	'BloodPlasma',              this.fBloodPlasmaVolume,            tfBloodPlasmaInitialMasses,                  this.oParent.fBodyCoreTemperature, 1e5);
           
            this.tfOsmolality.fBloodPlasmaOsmolality = this.calculateOsmolality(oBloodPlasma.afMass);
            
            %% Interstitial Fluid
            csFields = fieldnames(this.tfBaseConcentrations.InterstitialFluid);
            fH2O_MassConcentration = 1;
            
            tfInterstitialFluidInitialMasses = struct();
            for iField = 1:length(csFields)
                tfInterstitialFluidInitialMasses.(csFields{iField}) = this.tfBaseConcentrations.InterstitialFluid.(csFields{iField}) * this.oMT.afMolarMass(this.oMT.tiN2I.(csFields{iField})) / fDensityH2O;
                fH2O_MassConcentration = fH2O_MassConcentration - tfInterstitialFluidInitialMasses.(csFields{iField});
            end
            tfInterstitialFluidInitialMasses.H2O = fH2O_MassConcentration;
            
            oInterstitialFluid          = this.toStores.WaterBalance.createPhase(	'liquid',       'InterstitialFluid',       this.fInterstitialFluidVolume,           tfInterstitialFluidInitialMasses,       this.oParent.fBodyCoreTemperature, 1e5);
           
            this.tfOsmolality.fInterstitialFluidOsmolality = this.calculateOsmolality(oInterstitialFluid.afMass);
            
            %% Intracellular Fluid
            csFields = fieldnames(this.tfBaseConcentrations.IntracellularFluid);
            fH2O_MassConcentration = 1;
            
            tfIntracellularFluidInitialMasses = struct();
            for iField = 1:length(csFields)
                tfIntracellularFluidInitialMasses.(csFields{iField}) = this.tfBaseConcentrations.IntracellularFluid.(csFields{iField}) * this.oMT.afMolarMass(this.oMT.tiN2I.(csFields{iField})) / fDensityH2O;
                fH2O_MassConcentration = fH2O_MassConcentration - tfIntracellularFluidInitialMasses.(csFields{iField});
            end
            tfIntracellularFluidInitialMasses.H2O = fH2O_MassConcentration;
            
            oIntracellularFluid         = this.toStores.WaterBalance.createPhase(	'liquid',       'IntracellularFluid',       this.fIntracellularFluidVolume,         tfIntracellularFluidInitialMasses,      this.oParent.fBodyCoreTemperature, 1e5);
           
            this.tfOsmolality.fIntracellularFluidOsmolality = this.calculateOsmolality(oIntracellularFluid.afMass);
            
            %% Kidney
            csFields = fieldnames(this.tfBaseConcentrations.BloodPlasma);
            fH2O_MassConcentration = 1;
            for iField = 1:length(csFields)
                fH2O_MassConcentration = fH2O_MassConcentration - this.tfBaseConcentrations.BloodPlasma.(csFields{iField});
            end
            
            oKidney                     = this.toStores.WaterBalance.createPhase( 	'liquid',     	'Kidney',               	this.fKidneyVolume,                      tfBloodPlasmaInitialMasses,           	 this.oParent.fBodyCoreTemperature, 1e5);
           
            this.tfOsmolality.fKidneyOsmolality = this.calculateOsmolality(oKidney.afMass);
            
            %% Bladder
            tfBladderInitialMasses      = struct( 'Urine',      0.02);
            oBladder                    = this.toStores.WaterBalance.createPhase( 	'liquid',     	'Bladder',               	this.fBladderVolume,                     tfBladderInitialMasses,                  this.oParent.fBodyCoreTemperature, 1e5);
           
            components.matter.Manips.ManualManipulator(this, 'UrineConverter', oBladder, true);
            
            %% PerspirationFlow
            % THis phase is necessary because P2P branches cannot be IF
            % branches, and therefore we need this phase to output
            % perspiration to the cabin air
            % THis must be in a seperate store, because otherwise the
            % liquid phases in the water balance will assume the pressure
            % of this flow phase
            matter.store(this, 'PerspirationOutput', 1e-6);
            this.toStores.PerspirationOutput.createPhase( 	'gas', 'flow',	'PerspirationFlow',	1e-6, struct('N2', 1e5), this.oParent.fBodyCoreTemperature);
           
            
            %% Store initial masses
            this.tfInitialMasses.BloodPlasma.afMass         = this.toStores.WaterBalance.toPhases.BloodPlasma.afMass;
            this.tfInitialMasses.InterstitialFluid.afMass   = this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass;
            this.tfInitialMasses.IntracellularFluid.afMass  = this.toStores.WaterBalance.toPhases.IntracellularFluid.afMass;
            this.tfInitialMasses.Kidney.afMass              = this.toStores.WaterBalance.toPhases.Kidney.afMass;
            this.tfInitialMasses.Bladder.afMass             = this.toStores.WaterBalance.toPhases.Bladder.afMass;
            
            fWaterMassExtraCellularFluid                    = this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass(this.oMT.tiN2I.H2O) + this.toStores.WaterBalance.toPhases.BloodPlasma.afMass(this.oMT.tiN2I.H2O);
            this.fInitialExtracellularFluidVolume           = fWaterMassExtraCellularFluid / fDensityH2O;
            this.fInitialBloodPlasmaVolume                  = this.toStores.WaterBalance.toPhases.BloodPlasma.afMass(this.oMT.tiN2I.H2O) / fDensityH2O;
            
            % In the old model it was not necessary to consider this,
            % because drinking was a direct input into the water balance
            % layer
            oDigestion = this.oParent.toChildren.Digestion.toStores.Digestion;
            
            this.tfInitialMasses.fTotalBodyWater            =   this.toStores.WaterBalance.toPhases.BloodPlasma.afMass(this.oMT.tiN2I.H2O) + ...
                                                                this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass(this.oMT.tiN2I.H2O) + ...
                                                                this.toStores.WaterBalance.toPhases.IntracellularFluid.afMass(this.oMT.tiN2I.H2O) + ...
                                                                this.toStores.WaterBalance.toPhases.Kidney.afMass(this.oMT.tiN2I.H2O) + ...
                                                                oDigestion.toPhases.Duodenum.afMass(this.oMT.tiN2I.H2O) + ...
                                                                oDigestion.toPhases.Ileum.afMass(this.oMT.tiN2I.H2O) + ...
                                                                oDigestion.toPhases.Jejunum.afMass(this.oMT.tiN2I.H2O) + ...
                                                                oDigestion.toPhases.LargeIntestine.afMass(this.oMT.tiN2I.H2O) + ...
                                                                oDigestion.toPhases.Stomach.afMass(this.oMT.tiN2I.H2O);
            
            this.tfInitialOsmolalities = this.tfOsmolality;
            
            %% P2Ps
            components.matter.P2Ps.ManualP2P(this.toStores.WaterBalance, 'FluxThroughEndothelium',      oInterstitialFluid,     oBloodPlasma);
            components.matter.P2Ps.ManualP2P(this.toStores.WaterBalance, 'ReFluxThroughEndothelium',    oBloodPlasma,           oInterstitialFluid);
            components.matter.P2Ps.ManualP2P(this.toStores.WaterBalance, 'ReadsorptionFluxFromKidney', 	oKidney,                oBloodPlasma);
            components.matter.P2Ps.ManualP2P(this.toStores.WaterBalance, 'InFluxKidney',                oBloodPlasma,           oKidney);
            components.matter.P2Ps.ManualP2P(this.toStores.WaterBalance, 'FluxthroughCellMembranes',	oInterstitialFluid,     oIntracellularFluid);
            components.matter.P2Ps.ManualP2P(this.toStores.WaterBalance, 'ReFluxthroughCellMembranes',	oIntracellularFluid,    oInterstitialFluid);
            components.matter.P2Ps.ManualP2P(this.toStores.WaterBalance, 'KidneyToBladder',             oKidney,                oBladder);
            
            
            %% We bind the internal flowrate calculations to the update of the corresponding phases
            this.toStores.WaterBalance.toPhases.BloodPlasma.bind(           'update_post', @this.bindInternalUpdate);
            this.toStores.WaterBalance.toPhases.InterstitialFluid.bind(     'update_post', @this.bindInternalUpdate);
            this.toStores.WaterBalance.toPhases.IntracellularFluid.bind(    'update_post', @this.bindInternalUpdate);
            this.toStores.WaterBalance.toPhases.Kidney.bind(                'update_post', @this.bindInternalUpdate);
            this.toStores.WaterBalance.toPhases.Bladder.bind(               'update_post', @this.bindInternalUpdate);
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
                    arMaxChange(this.oMT.tiN2I.Naplus)      = 1e-1;
                    arMaxChange(this.oMT.tiN2I.Kplus)       = 1e-1;
                    arMaxChange(this.oMT.tiN2I.Ca2plus)     = 1e-1;
                    arMaxChange(this.oMT.tiN2I.Mg2plus)     = 1e-1;
                    arMaxChange(this.oMT.tiN2I.Clminus)     = 1e-1;
                    arMaxChange(this.oMT.tiN2I.HCO3)        = 1e-1;
                    arMaxChange(this.oMT.tiN2I.HPO4)        = 1e-1;
                    arMaxChange(this.oMT.tiN2I.H2O)         = 1e-1;
                    tTimeStepProperties.arMaxChange = arMaxChange;

                    oPhase.setTimeStepProperties(tTimeStepProperties);
                end
            end
            % The bladder will empty and fill itself but matter properties
            % are not important for it --> rMaxChange can be set to inf:
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = inf;
            arMaxChange = zeros(1,this.oMT.iSubstances);
            tTimeStepProperties.arMaxChange = arMaxChange;
            tTimeStepProperties.fMassErrorLimit = 1e-12;
            this.toStores.WaterBalance.toPhases.Bladder.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
        
        function setOdeOptions(this, tOdeOptions)
            this.tOdeOptions = tOdeOptions;
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            % We do not use the exec functions of the human layers, as it
            % is not possible to define the update order if we use the exec
            % functions!!
            
        end
        
        function fOsmolality = calculateOsmolality(this, afMass)
            % This function calculates the current blood plasma osmolality
            % according to Equations 11-245 to 11-247 from the dissertation
            % of Markus Czupalla.
            % In the 0ld simulink model, this section is located in water ->
            % inner milieu --> blood plasma
            afMassIons(this.oMT.aiCharge == 0) = 0;
            
            afOsmoticCoefficients = afMassIons ./ this.oMT.afMolarMass .* abs(this.oMT.aiCharge) .* this.fOsmoticCoefficient;
            
            fOsmolality = sum(afOsmoticCoefficients) / afMass(this.oMT.tiN2I.H2O); % [mol / kg]
        end
        
        function afPartialFlowRates = EndotheliumFlowRates(this, fDensityH2O, afCurrentBloodPlasmaMasses, afCurrentInterstitialFluidMasses)
            
            if nargin < 3
                afCurrentBloodPlasmaMasses   = this.toStores.WaterBalance.toPhases.BloodPlasma.afMass;
                afCurrentInterstitialFluidMasses  = this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass;
            end
            % Equation 11-264
            fEndothelialExchangeArea = 777.77 * this.oParent.toChildren.Metabolic.rActivityLevel + 222.22;
            
            % Equation 11-263
            fUltrafiltrationCoefficient = this.oParent.toChildren.Metabolic.fBodyMass * this.fHydraulicConductivity * fEndothelialExchangeArea; % [m^3 / (Pa s)]
            
            % Equation 11-262
            % Flowrate in kg/s, unit check was performed for the equation
            % a positive water flow means water flows into the blood
            % plasma!
            % the lower the osmolality is, the more diluted is this fluid.
            % Therefore, water should flow from the more diluted fluid to
            % the less diluted fluid. Which means it should have a positive
            % flowrate if the osmolality of the BloodPlasma fluid is
            % higher than the interstitial fluid and water should flow from
            % the interstitial to the BloodPlasma fluid
            fFlowRateWater = fUltrafiltrationCoefficient * this.oMT.Const.fUniversalGas * this.oParent.fBodyCoreTemperature * (this.tfOsmolality.fBloodPlasmaOsmolality - this.tfOsmolality.fInterstitialFluidOsmolality) * fDensityH2O^2;
            
            afBloodPlasmaSolventConcentrations                  =   afCurrentBloodPlasmaMasses(this.aiSolvents)         ./ afCurrentBloodPlasmaMasses(this.oMT.tiN2I.H2O);
            afInterstitialFluidSolventConcentrations            =   afCurrentInterstitialFluidMasses(this.aiSolvents)   ./ afCurrentInterstitialFluidMasses(this.oMT.tiN2I.H2O);
            
%             afInitialBloodPlasmaSolventConcentrations         	=   this.tfInitialMasses.BloodPlasma.afMass(this.aiSolvents)        ./ this.tfInitialMasses.BloodPlasma.afMass(this.oMT.tiN2I.H2O);
%             afInitialInterstitialFluidSolventConcentrations     =   this.tfInitialMasses.InterstitialFluid.afMass(this.aiSolvents) 	./ this.tfInitialMasses.InterstitialFluid.afMass(this.oMT.tiN2I.H2O);
                    
            % The original model did not consider the water mass changes
            % from the water flow rate. Since that is implemented in this
            % model, we also require a correcting force for this, which
            % tries to keep the initial water masses. Here we maintain the
            % blood plasma mass, as that is the smallest of all water
            % masses in the body. In the cell membrane calculation we
            % maintain the interstitial fluid mass, but also try to
            % distribute overall water loss between these two layers. This
            % calculation has a postive flowrate if the initial mass of
            % blood plasma is higher, because that results in a mass
            % increase for the blood plasma!
            % While at it, we also handle maintaining the initial
            % concentrations of the blood plasma here (previously equation
            % 11-269 and 11-270
            afBloodPlasmaMassDifference = this.tfInitialMasses.BloodPlasma.afMass - afCurrentBloodPlasmaMasses;
            
            afCorrectionFlows = afBloodPlasmaMassDifference / this.oParent.fTimeStep;
            fFlowRateWater = fFlowRateWater + afCorrectionFlows(this.oMT.tiN2I.H2O);
            
            % The solvent drag flowrate is defined in the same direction as
            % the water flow, from Interstitial fluid to blood plasma!
            if fFlowRateWater < 0
                % Equation 11-265
                afFlowRatesSolventDrag = fFlowRateWater .* (1 - this.fReflectionCoefficient) .* this.fOsmoticCoefficient .* afBloodPlasmaSolventConcentrations;
            else
                % Equation 11-266
                afFlowRatesSolventDrag = fFlowRateWater .* (1 - this.fReflectionCoefficient) .* this.fOsmoticCoefficient .* afInterstitialFluidSolventConcentrations;
            end
            
           	% Equation 11-267
            % Defined as having a positive flowrate from interstitial fluid
            % to blood plasma, the same as the P2P
            afFlowRatesDiffusion        = this.fPermeabilityOfEndothelium .* fEndothelialExchangeArea .* fDensityH2O .* (afInterstitialFluidSolventConcentrations - afBloodPlasmaSolventConcentrations) .* this.fReflectionCoefficient;
            
            % Equation 11-268
            % Defined as having a positive flowrate from intersitital fluid
            % to blood plasma
            afFlowRatesActiveTransport = afCorrectionFlows(this.aiSolvents);
            
            % The flux through the endothelium p2p is defined from the
            % interstitial fluid to the blood plasma. Since the diffusion
            % and active transport flowrates are defined the other way
            % around, they require a negative sign!
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.aiSolvents)     = afFlowRatesSolventDrag + afFlowRatesDiffusion + afFlowRatesActiveTransport;
            afPartialFlowRates(this.oMT.tiN2I.H2O) 	= fFlowRateWater;
        end
        
        function afPartialFlowRates = CellMembraneFlowRates(this, fDensityH2O, afCurrentInterstitialMasses, afCurrentIntracellularMasses)
            
            if nargin < 3
                afCurrentInterstitialMasses     = this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass;
                afCurrentIntracellularMasses	= this.toStores.WaterBalance.toPhases.IntracellularFluid.afMass;
            end
            
            % Equation 11-272
            % fUltrafiltrationCoefficient = this.oParent.toChildren.Metabolic.fBodyMass * this.fHydraulicConductivity * this.fCellMembraneExchangeArea; % [m^3 / (Pa s)]
            % IN RT_Da 2008-05 from Philipp Hager, the Ultrafiltration
            % Coefficient for the Cellmembrane is mentioned to be the
            % following value. The cell membrane area mentioned is the same
            % as in the dissertation of Markus Czupalla. It is unclear how
            % such a low value could result from the Ultrafiltration
            % calculation (if it is performed with the provided values and
            % equations the value for the Cell Membrane ultrafiltration is
            % 0.6767. In the simulink models the following value was also
            % used as fix value. Therefore, we will do the same here.
            fUltrafiltrationCoefficient = 4.935e-12;
            % Equation 11-271
            % Flowrate in kg/s, unit check was performed for the equation
            % a positive water flow means water flows into the blood
            % plasma!
            % [m^3 / (Pa s)] * [kg m^2 / s^2 mol K] * [K] * [mol / kg] * [kg^2 / m^6]
            % yes unit check works out, results in kg/s
            % the lower the osmolality is, the more diluted is this fluid.
            % Therefore, water should flow from the more diluted fluid to
            % the less diluted fluid. Which means it should have a positive
            % flowrate if the osmolality of the intracellular fluid is
            % higher than the interstitial fluid and water should flow from
            % the interstitial to the intracellular fluid
            fFlowRateWater = fUltrafiltrationCoefficient * this.oMT.Const.fUniversalGas * this.oParent.fBodyCoreTemperature * (this.tfOsmolality.fIntracellularFluidOsmolality - this.tfOsmolality.fInterstitialFluidOsmolality) * fDensityH2O^2;
            
            afIntracellularFluidSolventConcentrations           =   afCurrentIntracellularMasses(this.aiSolvents)	./ afCurrentIntracellularMasses(this.oMT.tiN2I.H2O);
            afInterstitialFluidSolventConcentrations            =   afCurrentInterstitialMasses(this.aiSolvents) 	./ afCurrentInterstitialMasses(this.oMT.tiN2I.H2O);
            
            afInitialIntracellularFluidSolventConcentrations 	=   this.tfInitialMasses.IntracellularFluid.afMass(this.aiSolvents)	./ this.tfInitialMasses.IntracellularFluid.afMass (this.oMT.tiN2I.H2O);
            afInitialInterstitialFluidSolventConcentrations     =   this.tfInitialMasses.InterstitialFluid.afMass(this.aiSolvents) 	./ this.tfInitialMasses.InterstitialFluid.afMass (this.oMT.tiN2I.H2O);
            
            % Since the endothelium calculation maintains the water mass in
            % the blood plasma, here we handle the water balance between
            % the interstitial and intracellular fluid and try to
            % distribute water and electrolyte losses between these two layers:
            % First we calculate the current mass differences of the two
            % fluids. Values are calculated so that losses appears
            % negative:
            afInterstitialMassDifference    = afCurrentInterstitialMasses  - this.tfInitialMasses.InterstitialFluid.afMass;
            afIntracellularMassDifference   = afCurrentIntracellularMasses - this.tfInitialMasses.IntracellularFluid.afMass;
            
            % Then we calculate an overall difference for both fluids
            afTotalMassDifference = afInterstitialMassDifference + afIntracellularMassDifference;
            
            % Since the intracellular fluid is twice as large as the
            % interstitial fluid, the intracellular fluid should have 2/3
            % of the difference. From this we can calculated target
            % masses each fluid should have at the moment
            arInterstitialRatios = zeros(1, this.oMT.iSubstances);
            arInterstitialRatios([this.aiSolvents, this.oMT.tiN2I.H2O]) = this.tfInitialMasses.InterstitialFluid.afMass([this.aiSolvents, this.oMT.tiN2I.H2O]) ./ (this.tfInitialMasses.InterstitialFluid.afMass([this.aiSolvents, this.oMT.tiN2I.H2O]) + this.tfInitialMasses.IntracellularFluid.afMass([this.aiSolvents, this.oMT.tiN2I.H2O]));
            
            arIntracellularRatios = zeros(1, this.oMT.iSubstances);
            arIntracellularRatios([this.aiSolvents, this.oMT.tiN2I.H2O]) = this.tfInitialMasses.IntracellularFluid.afMass([this.aiSolvents, this.oMT.tiN2I.H2O]) ./ (this.tfInitialMasses.InterstitialFluid.afMass([this.aiSolvents, this.oMT.tiN2I.H2O]) + this.tfInitialMasses.IntracellularFluid.afMass([this.aiSolvents, this.oMT.tiN2I.H2O]));
            
            afTargetMassInterstitialFluid  = this.tfInitialMasses.InterstitialFluid.afMass  + arInterstitialRatios .* afTotalMassDifference;
            afTargetMassIntracellularFluid = this.tfInitialMasses.IntracellularFluid.afMass + arIntracellularRatios .* afTotalMassDifference;
            
            % These two values are calculated to be positive if the
            % respective fluid should increase in mass
            afRequiredInfluxesIntersitialFluid   = afTargetMassInterstitialFluid  - afCurrentInterstitialMasses;
            afRequiredInfluxesIntracellularFluid = afTargetMassIntracellularFluid - afCurrentIntracellularMasses;
            
            % Since the p2p is defined from the interstitial to the
            % intracellular fluid, a mass increase of the interstitial
            % fluid is achieved by negative water flows. Since we also have
            % two flowrates which usually achieve the same thing, we divide
            % it by 2 and by 60:
            afCorrectionFlows = (afRequiredInfluxesIntracellularFluid - afRequiredInfluxesIntersitialFluid) / (2 * 60);
            
            fFlowRateWater = fFlowRateWater + afCorrectionFlows(this.oMT.tiN2I.H2O);
            
            % The solvent drag flowrate is defined in the same direction as
            % the water flow, from Interstitial fluid to Intracellular Fluid!
            % So for negative flowrates we have to use the values from the
            % intracellular fluid
            if fFlowRateWater < 0
                % Equation 11-273
                afFlowRatesSolventDrag = fFlowRateWater .* (1 - this.fReflectionCoefficient) .* this.fOsmoticCoefficient .* afIntracellularFluidSolventConcentrations;
            else
                % Equation 11-274
                afFlowRatesSolventDrag = fFlowRateWater .* (1 - this.fReflectionCoefficient) .* this.fOsmoticCoefficient .* afInterstitialFluidSolventConcentrations;
            end
            
           	% Equation 11-275
            % Defined as having a positive flowrate from blood plasma to
            % intersitital fluid
            afFlowRatesDiffusion        = this.fPermeabilityOfCellMembrane .* this.fCellMembraneExchangeArea .* fDensityH2O .* (afInterstitialFluidSolventConcentrations - afIntracellularFluidSolventConcentrations) .* this.fReflectionCoefficient;
            
           	% Equation 11-277
            % This is defined the other way around, because it is
            % responsible for keeping the initial concentration difference
            afFlowRatesActiveDiffusion  = this.fPermeabilityOfCellMembrane .* this.fCellMembraneExchangeArea .* fDensityH2O .* (afInitialIntracellularFluidSolventConcentrations- afInitialInterstitialFluidSolventConcentrations) .* this.fReflectionCoefficient;
            
           	% Equation 11-278 from the dissertation was replaced with the
           	% balancing logic implemented initially for water. This way
           	% electrolyte losses are distributed between the interstitial
           	% and intracellular fluid
            afFlowRatesActiveSolventDrag= afCorrectionFlows(this.aiSolvents);
            
            % Equation 11-276
            % Defined as having a positive flowrate from blood plasma to
            % intersitital fluid
            afFlowRatesActiveTransport = afFlowRatesActiveDiffusion + afFlowRatesActiveSolventDrag;
            
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.aiSolvents)     = afFlowRatesDiffusion + afFlowRatesActiveTransport + afFlowRatesSolventDrag;
            afPartialFlowRates(this.oMT.tiN2I.H2O) 	= fFlowRateWater;
        end
        
        function [fWaterFlowToBladder, fNatriumFlowToBladder] = KidneyModel(this, fDensityH2O)
            %% Kidney Model
            % calculate the water and Na+ flow into the kidney and into the
            % bladder.
            %
            % We first update the ADH concentration based on the previously
            % calculated concentration change of ADH
            fKidneyTimeStep = this.oTimer.fTime - this.fLastKidneyUpdateTime;
            
            this.fConcentrationOfADHinBloodPlasma           = this.fConcentrationOfADHinBloodPlasma             + this.fConcentrationChangeOfADH            * fKidneyTimeStep; %[munits/l]
            this.fConcentrationOfReninInBloodPlasma         = this.fConcentrationOfReninInBloodPlasma           + this.fConcentrationChangeOfRenin          * fKidneyTimeStep; %[ng/l]
            this.fConcentrationOfAngiotensinIIInBloodPlasma = this.fConcentrationOfAngiotensinIIInBloodPlasma   + this.fConcentrationChangeOfAngiotensinII  * fKidneyTimeStep; %[ng/l]
            this.fConcentrationOfAldosteronInBloodPlasma  	= this.fConcentrationOfAldosteronInBloodPlasma  	+ this.fConcentrationChangeOfAldosteron   	* fKidneyTimeStep; %[ng/l]
            
            if this.fConcentrationOfADHinBloodPlasma < 0
                this.fConcentrationOfADHinBloodPlasma = 0;
            end
            if this.fConcentrationOfReninInBloodPlasma < 0
                this.fConcentrationOfReninInBloodPlasma = 0;
            end
            if this.fConcentrationOfAngiotensinIIInBloodPlasma < 0
                this.fConcentrationOfAngiotensinIIInBloodPlasma = 0;
            end
            if this.fConcentrationOfAldosteronInBloodPlasma < 0
                this.fConcentrationOfAldosteronInBloodPlasma = 0;
            end
            
            fVolumetricBloodFlow    = -0.411 * this.oParent.toChildren.Metabolic.rActivityLevel + 1.161;    % [l/min]
            fBloodPressure          = fVolumetricBloodFlow * this.fKidneyBloodFlowResistance;               % [mmHg]
            
            oInterstitialFluid  = this.toStores.WaterBalance.toPhases.InterstitialFluid;
            oBloodPlasma        = this.toStores.WaterBalance.toPhases.BloodPlasma;
            
            fWaterMassExtraCellularFluid    = oInterstitialFluid.afMass(this.oMT.tiN2I.H2O)     + oBloodPlasma.afMass(this.oMT.tiN2I.H2O);
            fSodiumMassExtraCellularFluid   = oInterstitialFluid.afMass(this.oMT.tiN2I.Naplus)  + oBloodPlasma.afMass(this.oMT.tiN2I.Naplus);
            
            fWaterVolumeExtraCellularFluid = fWaterMassExtraCellularFluid / fDensityH2O;
            
            %% Proximal Tubule
            % The volumetric molar concentration in mmol/l is equal to the one in mol/m^3!
            fVolumetricMolarConcentrationNa = (fSodiumMassExtraCellularFluid / this.oMT.afMolarMass(this.oMT.tiN2I.Naplus)) / (fWaterMassExtraCellularFluid / fDensityH2O);
            fMassConcentrationNa            = fSodiumMassExtraCellularFluid / fWaterMassExtraCellularFluid;
            
            % Paper regarding this:
            % https://jasn.asnjournals.org/content/19/12/2272
            % From this paper it is deduced that GTB cannot be 100%
            % efficient, since it is a statistical process. More delivary
            % hence also means more changes to readsorb, but at the same
            % time for a molecule to pass. Therefore, we limit the GTB
            % value to a maximum of 90% (usually it is 70%)
            
            % A typical value for this is ~0.74, which should occur for Na
            % concentrations of about 142 mmol/l
            rGlomerularTubularBalance = 5.815 - 0.0357 * fVolumetricMolarConcentrationNa;
            % In the simulink model, this was performed by a saturation
            % block, which limits the values to be between 0 and 1
            if rGlomerularTubularBalance > 0.95
                rGlomerularTubularBalance = 0.95;
            elseif rGlomerularTubularBalance < 0
                rGlomerularTubularBalance = 0; 
            end
            
            % Equation 11-291, value in ml/min
            fVolumetricGlomerularFiltrationRate = 14.1014 - 1.62 * fBloodPressure + 0.1 * fBloodPressure^2 - 1.2e-3 * fBloodPressure^3 + 5.73e-6 * fBloodPressure^4 - 9.892e-9 * fBloodPressure^5;
            % Value in kg/s , 60000000 is the conversion for ml to m^3
            % combined with the conversion of /min to s
            %
            % From RT-DA 2008-05 Hager, Table 8.32 typical values for the
            % walter filtrated into Kidney is 124 g/min = 0.0021 kg/s.
            % Typical value for the rGlomerularTubularBalance is about 0.74
            %
            % While for Sodium the values flowing into the kidney are 
            % 17.65  g/min = 2.94e-4 kg/s and reabsorbed are 13.15 g/min.
            % THe flow into the loop of henle is mentioned to be 
            % 4.5 mmol/min, but that is strange since the difference
            % between the other two values is exactly 4.5 g/min
            fMassGlomerularFiltrationRate           = (fVolumetricGlomerularFiltrationRate / (60000000)) * fDensityH2O;
            fNatriumFlowProximalTubule              = fMassGlomerularFiltrationRate * fMassConcentrationNa;
            
            fNatriumFlowReadsorptionProximalTubule  = fNatriumFlowProximalTubule * rGlomerularTubularBalance;
            fWaterFlowReadsorptionProximalTubule   	= fMassGlomerularFiltrationRate * rGlomerularTubularBalance;
            
            fWaterFlowToLoopOfHenle                 = fMassGlomerularFiltrationRate - fWaterFlowReadsorptionProximalTubule;
            fNaFlowToLoopOfHenle                    = fNatriumFlowProximalTubule    - fNatriumFlowReadsorptionProximalTubule;
            
            %% Loop of Henle
            % Equation 11-297, but since the mass flows in V-Hab 1 were in
            % g/min the factor is adjusted according to new unit of kg/s
            % Typical value for the water flow into loop of henle,
            % according to RT-DA 2008-05 Hager, Table 8.33 is 31.5 g/min =
            % 5.25e-4 kg/s. And typical for the flow to distal tubule is 
            % 21 g/min = 3.5e-4
            %
            % Sodium to the distal tubule should be 0.9 mmol/min =
            % 0.02 g/min = 3.45e-7 kg/s
            rFractionOfWaterLoadInLoopOfHenle       = -0.01 * fWaterFlowToLoopOfHenle * 60000 + 0.65;
            
            fNatriumFlowReadsorptionLoopOfHenle     = 0.8 * fNaFlowToLoopOfHenle;
            fWaterFlowReadsorptionLoopOfHenle     	= rFractionOfWaterLoadInLoopOfHenle * fWaterFlowToLoopOfHenle;
            
            fWaterFlowToDistalTubule                = fWaterFlowToLoopOfHenle - fWaterFlowReadsorptionLoopOfHenle;
            fNaFlowToDistalTubule                   = fNaFlowToLoopOfHenle    - fNatriumFlowReadsorptionLoopOfHenle;
            
            %% Distal Tubule
            % According to RT-DA 2008-05 Hager, Table 8.34 a typical value
            % for the water flow to the bladder is 31.5 g/min, which is
            % higher than the water flow into the distal tubule. There
            % seems to be an error there, because according to the
            % equations, the flow can only be higher if the Readsorption
            % flow of the distal tubule becomes negative.
            if this.fConcentrationOfADHinBloodPlasma <= 0.765
                rFractionOfWaterLoadInDistalTubule = 0;
            elseif this.fConcentrationOfADHinBloodPlasma <= 3
                rFractionOfWaterLoadInDistalTubule = 0.383 * this.fConcentrationOfADHinBloodPlasma - 0.293;
            elseif this.fConcentrationOfADHinBloodPlasma <= 5
                rFractionOfWaterLoadInDistalTubule = -0.0383 * this.fConcentrationOfADHinBloodPlasma^2 + 0.364 * this.fConcentrationOfADHinBloodPlasma + 0.109;
            else
                rFractionOfWaterLoadInDistalTubule = 0.0012 * this.fConcentrationOfADHinBloodPlasma + 0.9653;
            end
            
            fWaterFlowReadsorptionDistalTubule = rFractionOfWaterLoadInDistalTubule * fWaterFlowToDistalTubule;
            fWaterFlowToBladder = fWaterFlowToDistalTubule - fWaterFlowReadsorptionDistalTubule;
            
            if this.fConcentrationOfAldosteronInBloodPlasma <= 0
                fNatriumFlowReadsorptionDistalTubule = 0.6 * fNaFlowToDistalTubule;
            elseif this.fConcentrationOfAldosteronInBloodPlasma <= 85
                fNatriumFlowReadsorptionDistalTubule = (0.003 * this.fConcentrationOfAldosteronInBloodPlasma + 0.596) * fNaFlowToDistalTubule;
            elseif this.fConcentrationOfAldosteronInBloodPlasma <= 800
                fNatriumFlowReadsorptionDistalTubule = (0.00021 * this.fConcentrationOfAldosteronInBloodPlasma + 0.883) * fNaFlowToDistalTubule;
            else
                fNatriumFlowReadsorptionDistalTubule = fNaFlowToDistalTubule;
            end
            % Initial concentration of aldosteron is 85 ng, with that the
            % readsorption ratio is 0.851, so of the 0.9 mmol/min 
            % 0.1341 mmol/min pass into the bladder in standard conditions.
            % This corresponds to 0.0031 g/min or 5.1382e-8 kg/s
            % However, this results in a sodium loss of 4.44 g/day in
            % standard conditions. The NASA HDIH however states the total
            % recommended sodium intake per day is 1.5 to 2.3 g/day 
            % (Table 7.2-3 Micronutrient Guidelines for Spaceflight)
            % The WHO recommended Sodium intake is also at ~ 2g/d but
            % should even be lowered
            % (https://www.who.int/nutrition/publications/guidelines/sodium_intake_printversion.pdf)
            %
            % In addition NASA BVAD table 4.27 states the sodium chloride
            % concentration in urine is ~8 mg/l.
            % From BVAD the daily sodium loss in urine for the initial
            % water flow rate (which is 1.78 kg/day initially) would be
            % about 1.42e-5 kg of sodium loss. 
            % According to "ISS Potable Water Sampling and Chemical
            % Analysis Results for 2016", 47th International Conference on
            % Environmental Systems, ICES-2017-337, 16-20 July 2017,
            % Charleston, South Carolina, J.E.Straub et.al.
            % The sodium concentration in potable water is ~0.5 mg/l, which
            % amounts to 1.25 mg per day for 2.5 kg of water intake
            %
            % All of this does not really match, while some sodium loss
            % apart from Urine would pe perspiration, it seems a bit much
            % to assume almost all of the loss is perspiration (because
            % otherwise sodium would built up in the body)
                
            fNatriumFlowToBladder       = fNaFlowToDistalTubule - fNatriumFlowReadsorptionDistalTubule;
            fWaterFlowReadsorption      = fMassGlomerularFiltrationRate - fWaterFlowToBladder;
            fNatriumFlowReadsorption    = fNatriumFlowProximalTubule - fNatriumFlowToBladder;
            
            % According to BVAD table 4.27 the sodium chloride
            % concentration in urine is 8 mg/l. Here 
            %
            
            %% Set P2P Flowrates for Kidney
            % Kidney input
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.oMT.tiN2I.Naplus)   = fNatriumFlowProximalTubule;
            afPartialFlowRates(this.oMT.tiN2I.H2O)      = fMassGlomerularFiltrationRate;
            this.toStores.WaterBalance.toProcsP2P.InFluxKidney.setFlowRate(                 afPartialFlowRates);
            
            % Kidney readsorption
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.oMT.tiN2I.Naplus)   = fNatriumFlowReadsorption;
            afPartialFlowRates(this.oMT.tiN2I.H2O)      = fWaterFlowReadsorption;
            this.toStores.WaterBalance.toProcsP2P.ReadsorptionFluxFromKidney.setFlowRate(   afPartialFlowRates);
            
            % Kidney to bladder
            afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates(this.oMT.tiN2I.Naplus)   = fNatriumFlowToBladder;
            afPartialFlowRates(this.oMT.tiN2I.H2O)      = fWaterFlowToBladder;
            this.toStores.WaterBalance.toProcsP2P.KidneyToBladder.setFlowRate(              afPartialFlowRates);
            
            
            %% ADH System, note all ADH concentration related parameters are
            % in munits/l!!
            fDeltaWaterVolumeExtraCellularFluid = (fWaterVolumeExtraCellularFluid - this.fInitialExtracellularFluidVolume) * 1000; % in l
            
            if this.fConcentrationOfADHinBloodPlasma < 4
                fRateOfADHClearance = 0.374625 - 0.042 * this.fConcentrationOfADHinBloodPlasma;
            else
                fRateOfADHClearance = 0.206625;
            end
            
            if fDeltaWaterVolumeExtraCellularFluid < -1.2
                fVolumetricADHRelease = 1.71;
            elseif fDeltaWaterVolumeExtraCellularFluid < 1
                fVolumetricADHRelease = 0.813 - 0.75 * fDeltaWaterVolumeExtraCellularFluid;
            elseif fDeltaWaterVolumeExtraCellularFluid < 1.8
                fVolumetricADHRelease = 0.15 - 0.082 * fDeltaWaterVolumeExtraCellularFluid;
            else
                fVolumetricADHRelease = 0;
            end
            
            if fVolumetricMolarConcentrationNa < 141.9
                fOsmoticADHRelease = 0.0625 * fVolumetricMolarConcentrationNa - 8.04;
            else
                fOsmoticADHRelease = 0.2374 * fVolumetricMolarConcentrationNa - 32.89;
            end
            
            fWaterVolumeBloodPlasma = oBloodPlasma.afMass(this.oMT.tiN2I.H2O) / fDensityH2O * 1000; % in [l]
            this.fConcentrationChangeOfADH = ((fVolumetricADHRelease + fOsmoticADHRelease)/2 - this.fConcentrationOfADHinBloodPlasma * fRateOfADHClearance) / (60 * fWaterVolumeBloodPlasma);
            
            %% Renin Angiotensin II - Aldosteron
            fReleaseOfRenin = 0.0163 - 0.0093 * fNaFlowToDistalTubule;
            this.fConcentrationChangeOfRenin = (fReleaseOfRenin - this.fConcentrationOfReninInBloodPlasma * 4/30) / (60 * fWaterVolumeBloodPlasma);
            
            fReleaseOfAngiotensinII = 1750/3 * this.fConcentrationOfReninInBloodPlasma * fWaterVolumeBloodPlasma;
            this.fConcentrationChangeOfAngiotensinII = (fReleaseOfAngiotensinII - this.fConcentrationOfAngiotensinIIInBloodPlasma * 35/9) / (60 * fWaterVolumeBloodPlasma);
            
            if this.fConcentrationOfAngiotensinIIInBloodPlasma < 18
                fReleaseOfAldosteronHormonal = this.fConcentrationOfAngiotensinIIInBloodPlasma;
            elseif this.fConcentrationOfAngiotensinIIInBloodPlasma < 34
                fReleaseOfAldosteronHormonal = 4.45 * this.fConcentrationOfAngiotensinIIInBloodPlasma - 61.7;
            else
                fReleaseOfAldosteronHormonal = 0.78 * this.fConcentrationOfAngiotensinIIInBloodPlasma - 62.4;
            end
            
            fVolumetricMolarConcentrationK = (this.toStores.WaterBalance.toPhases.BloodPlasma.afMass(this.oMT.tiN2I.Kplus) / this.oMT.afMolarMass(this.oMT.tiN2I.Kplus)) / (this.toStores.WaterBalance.toPhases.BloodPlasma.afMass(this.oMT.tiN2I.H2O) / fDensityH2O);
            
            fReleaseOfAldosteronKalium = 21.64 * fVolumetricMolarConcentrationK * this.fOsmoticCoefficient - 52.279;
                
            fReleaseOfAldosteron = (3 * fReleaseOfAldosteronHormonal + fReleaseOfAldosteronKalium) / 4;
            this.fConcentrationChangeOfAldosteron = (fReleaseOfAldosteron - this.fConcentrationOfAldosteronInBloodPlasma * 0.62) / (60 * fWaterVolumeBloodPlasma);
            
            this.fLastKidneyUpdateTime = this.oTimer.fTime;
        end
        
        function fThirst = Thirst(this, fDensityH2O)
            
            fWaterVolumeBloodPlasma = (this.toStores.WaterBalance.toPhases.BloodPlasma.afMass(this.oMT.tiN2I.H2O) / fDensityH2O) * 1000; % in [l]
            
            fDeltaVolume        = fWaterVolumeBloodPlasma / (this.fInitialBloodPlasmaVolume * 1000);
            if fDeltaVolume <= 0.9
                fThirstFactorDeltaVolume = 0.5 + ((0.9 - fDeltaVolume) / 0.9) * 0.5;
            else
                fThirstFactorDeltaVolume = 0;
            end
            
            fDeltaOsmolality    = this.tfOsmolality.fBloodPlasmaOsmolality / this.tfInitialOsmolalities.fBloodPlasmaOsmolality;
            if fDeltaOsmolality > 1.01
                fThirstFactorOsmolality = 0.5 + ((fDeltaOsmolality - 1.01)) * 0.5;
            else
                fThirstFactorOsmolality = 0;
            end
            
            fDeltaAngiotensinII = this.fConcentrationOfAngiotensinIIInBloodPlasma / 27;
            if fDeltaAngiotensinII > 1.015
                fThirstFactorAngiotensinII = 1;
            else
                fThirstFactorAngiotensinII = 0;
            end
            
            fDeltaMass          = this.toStores.WaterBalance.toPhases.IntracellularFluid.fMass / sum(this.tfInitialMasses.IntracellularFluid.afMass);
            if fDeltaMass < 1
                % Calculation so that thirst becomes larger than 1 if ICF
                % mass is lower than 90%
                fThirstFactorICFMass = 0.5 + ((1 - fDeltaMass)/0.1) * 0.5;
            else
                fThirstFactorICFMass = 0;
            end
            
            % We assume that the human must consume at least
            % this.fMinimumDailyWaterIntake and that this occurs in at
            % least 10 increments per day. So if after 1/10 day the 
            % this.fRemainingMinimumDailyWaterIntake is larger than 
            fConsumedWaterTillNow = this.fMinimumDailyWaterIntake - this.fRemainingMinimumDailyWaterIntake;
            
            fRequiredWaterConsumptionTillNow = (this.fTimeInCurrentDay/8640) * (this.fMinimumDailyWaterIntake/10);
            
            fThirstFromMinimumWaterIntake = (fRequiredWaterConsumptionTillNow - fConsumedWaterTillNow) / (this.fMinimumDailyWaterIntake/10);
            
            if fThirstFromMinimumWaterIntake < 0 
                fThirstFromMinimumWaterIntake = 0;
            end
            
            fThirst = (fThirstFactorDeltaVolume + fThirstFactorOsmolality + fThirstFactorAngiotensinII + fThirstFactorICFMass) / 3 + fThirstFromMinimumWaterIntake;
            
        end
        
        function bindInternalUpdate(this, ~)
            if ~this.bInternalUpdateRegistered
                this.hBindPostTickInternalUpdate()
            end
        end
        
        function afMassChangeRate = calculateChangeRate(this, afMasses, ~)
            
            afMassBloodPlasma   = afMasses(1:this.oMT.iSubstances)';
            afMassInterstitial  = afMasses(this.oMT.iSubstances + 1     : 2 * this.oMT.iSubstances)';
            afMassIntracellular = afMasses(2 * this.oMT.iSubstances + 1 : 3 * this.oMT.iSubstances)';
            
            this.tfOsmolality.fBloodPlasmaOsmolality        = this.calculateOsmolality(afMassBloodPlasma);
            this.tfOsmolality.fInterstitialFluidOsmolality  = this.calculateOsmolality(afMassInterstitial);
            this.tfOsmolality.fIntracellularFluidOsmolality = this.calculateOsmolality(afMassIntracellular);
            
            afPartialFlowRatesEndothelium   = this.EndotheliumFlowRates(this.fCurrenStepDensityH2O, afMassBloodPlasma, afMassInterstitial);
            afPartialFlowRatesCellMembrane  = this.CellMembraneFlowRates(this.fCurrenStepDensityH2O, afMassInterstitial, afMassIntracellular);
            
            % In both cases a positive flow rate represents an outflow from
            % the interstitial fluid and an inflow into the other fluid:
            afMassChangeRateBloodPlasma   = afPartialFlowRatesEndothelium;
            afMassChangeRateInterstitial  = - afPartialFlowRatesEndothelium - afPartialFlowRatesCellMembrane;
            afMassChangeRateIntraCellular = afPartialFlowRatesCellMembrane;
            
            afMassChangeRate = [afMassChangeRateBloodPlasma'; afMassChangeRateInterstitial'; afMassChangeRateIntraCellular'];
            
        end
        
        function updateInteralFlowrates(this, ~)
            % This function can be used to update only the Water layer
            % internal flowrates. It was implemented because the water
            % layer showed high oscillations due to the human time step
            % beeing too large. Therefore these calculations are performed
            % if any of the corresponding phases requires an update, not
            % within the human model time steps
            
            this.fCurrenStepDensityH2O = this.oMT.calculateDensity('liquid', struct('H2O', 1), this.oParent.fBodyCoreTemperature, 1e5);
            
            this.tfOsmolality.fBloodPlasmaOsmolality        = this.calculateOsmolality(this.toStores.WaterBalance.toPhases.BloodPlasma.afMass);
            this.tfOsmolality.fInterstitialFluidOsmolality  = this.calculateOsmolality(this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass);
            this.tfOsmolality.fIntracellularFluidOsmolality = this.calculateOsmolality(this.toStores.WaterBalance.toPhases.IntracellularFluid.afMass);
            this.tfOsmolality.fKidneyOsmolality             = this.calculateOsmolality(this.toStores.WaterBalance.toPhases.Kidney.afMass);
            
            fStepBeginTime = this.fLastInternalUpdate;
            fStepEndTime   = this.oTimer.fTime;
            
            if (fStepEndTime - fStepBeginTime) > 1
                afInitialMasses = [this.toStores.WaterBalance.toPhases.BloodPlasma.afMass'; this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass'; this.toStores.WaterBalance.toPhases.IntracellularFluid.afMass'];

                [~, afSolutionMassesOriginal] = ode45(this.hCalculateChangeRate, [fStepBeginTime, fStepEndTime], afInitialMasses, this.tOdeOptions);

                afSolutionMasses = afSolutionMassesOriginal(end,:)';
                afMassBloodPlasma   = afSolutionMasses(1:this.oMT.iSubstances)';
                % afMassInterstitial  = afSolutionMasses(this.oMT.iSubstances + 1     : 2 * this.oMT.iSubstances)';
                afMassIntracellular = afSolutionMasses(2 * this.oMT.iSubstances + 1 : 3 * this.oMT.iSubstances)';

                afFlowRatesEndothelium  = (afMassBloodPlasma   - this.toStores.WaterBalance.toPhases.BloodPlasma.afMass)        ./ (fStepEndTime - fStepBeginTime);
                afFlowRatesCellMembrane = (afMassIntracellular - this.toStores.WaterBalance.toPhases.IntracellularFluid.afMass) ./ (fStepEndTime - fStepBeginTime);
            else
                afFlowRatesEndothelium  = this.EndotheliumFlowRates(    this.fCurrenStepDensityH2O, this.toStores.WaterBalance.toPhases.BloodPlasma.afMass, this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass);
                afFlowRatesCellMembrane = this.CellMembraneFlowRates( 	this.fCurrenStepDensityH2O, this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass, this.toStores.WaterBalance.toPhases.IntracellularFluid.afMass);
            end
            
            afPartialFlowRatesPositive = afFlowRatesEndothelium;
            afPartialFlowRatesPositive(afPartialFlowRatesPositive < 0) = 0;
            afPartialFlowRatesNegative = afFlowRatesEndothelium;
            afPartialFlowRatesNegative(afPartialFlowRatesNegative > 0) = 0;
            % Since the P2P is defined in the other directions, we set the
            % flows to positive values
            afPartialFlowRatesNegative = -1 .* afPartialFlowRatesNegative;

            this.toStores.WaterBalance.toProcsP2P.FluxThroughEndothelium.setFlowRate( 	afPartialFlowRatesPositive);
            this.toStores.WaterBalance.toProcsP2P.ReFluxThroughEndothelium.setFlowRate(	afPartialFlowRatesNegative);

            afPartialFlowRatesPositive = afFlowRatesCellMembrane;
            afPartialFlowRatesPositive(afPartialFlowRatesPositive < 0) = 0;
            afPartialFlowRatesNegative = afFlowRatesCellMembrane;
            afPartialFlowRatesNegative(afPartialFlowRatesNegative > 0) = 0;
            % Since the P2P is defined in the other directions, we set the
            % flows to positive values
            afPartialFlowRatesNegative = -1 .* afPartialFlowRatesNegative;

            this.toStores.WaterBalance.toProcsP2P.FluxthroughCellMembranes.setFlowRate(    afPartialFlowRatesPositive);
            this.toStores.WaterBalance.toProcsP2P.ReFluxthroughCellMembranes.setFlowRate(  afPartialFlowRatesNegative);

            this.fLastInternalUpdate = this.oTimer.fTime;
            
            [fWaterFlowToBladder, fNatriumFlowToBladder] = this.KidneyModel(this.fCurrenStepDensityH2O);
            
            %% Urine conversion
            % since we want the human to output a compound mass called
            % Urine, which consists of Urea and water (instead of
            % these two mixtures), we define a manipulator to convert these
            % substances into the compound mass:
            fUreaFlowRate = this.oParent.toChildren.Metabolic.fUreaFlowRate;
            
            fTotalUrineFlowRate = (fUreaFlowRate + fWaterFlowToBladder + fNatriumFlowToBladder);
            afManipulatorFlowRates = zeros(1,this.oMT.iSubstances);
            afManipulatorFlowRates(this.oMT.tiN2I.H2O)          = - fWaterFlowToBladder;
            afManipulatorFlowRates(this.oMT.tiN2I.CH4N2O)    	= - fUreaFlowRate;
            afManipulatorFlowRates(this.oMT.tiN2I.Naplus)   	= - fNatriumFlowToBladder;
            afManipulatorFlowRates(this.oMT.tiN2I.Urine)        =   fTotalUrineFlowRate;
            
            aarFlowsToCompound = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            aarFlowsToCompound(this.oMT.tiN2I.Urine, this.oMT.tiN2I.H2O)       = fWaterFlowToBladder   / fTotalUrineFlowRate;
            aarFlowsToCompound(this.oMT.tiN2I.Urine, this.oMT.tiN2I.CH4N2O)    = fUreaFlowRate         / fTotalUrineFlowRate;
            aarFlowsToCompound(this.oMT.tiN2I.Urine, this.oMT.tiN2I.Naplus)    = fNatriumFlowToBladder / fTotalUrineFlowRate;
            
            % Currently not considered in the water balance is the
            % transepidermal water loss (the water lost through the skin)
            this.toStores.WaterBalance.toPhases.Bladder.toManips.substance.setFlowRate(afManipulatorFlowRates, aarFlowsToCompound, false);
            
            this.bInternalUpdateRegistered = false;
        end
	end
    methods (Access = {?components.matter.DetailedHuman.Human})
        
        function update(this)
            
            fDensityH2O = this.oMT.calculateDensity('liquid', struct('H2O', 1), this.oParent.fBodyCoreTemperature, 1e5);
            
            % now we calculate the water and electrolyte loss
            oDigestion = this.oParent.toChildren.Digestion.toStores.Digestion;
            
            fTotalBodyWater            =    this.toStores.WaterBalance.toPhases.BloodPlasma.afMass(this.oMT.tiN2I.H2O) + ...
                                         	this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass(this.oMT.tiN2I.H2O) + ...
                                        	this.toStores.WaterBalance.toPhases.IntracellularFluid.afMass(this.oMT.tiN2I.H2O) + ...
                                            this.toStores.WaterBalance.toPhases.Kidney.afMass(this.oMT.tiN2I.H2O) + ...
                                            oDigestion.toPhases.Duodenum.afMass(this.oMT.tiN2I.H2O) + ...
                                            oDigestion.toPhases.Ileum.afMass(this.oMT.tiN2I.H2O) + ...
                                            oDigestion.toPhases.Jejunum.afMass(this.oMT.tiN2I.H2O) + ...
                                            oDigestion.toPhases.LargeIntestine.afMass(this.oMT.tiN2I.H2O) + ...
                                            oDigestion.toPhases.Stomach.afMass(this.oMT.tiN2I.H2O);
                                        
            rBodyWaterLossRatio = (1 - fTotalBodyWater/this.tfInitialMasses.fTotalBodyWater);
            
%             afElectrolyteDebt = this.tfInitialMasses.BloodPlasma.afMass                 + this.tfInitialMasses.InterstitialFluid.afMass                 + this.tfInitialMasses.IntracellularFluid.afMass -...
%                                 this.toStores.WaterBalance.toPhases.BloodPlasma.afMass  - this.toStores.WaterBalance.toPhases.InterstitialFluid.afMass  - this.toStores.WaterBalance.toPhases.IntracellularFluid.afMass;
%             afElectrolyteDebt(this.oMT.tiN2I.H2O) = 0;
            
            this.rRatioOfAvailableSweat = (-0.354369 * rBodyWaterLossRatio^3 + 2.62428 * rBodyWaterLossRatio^2 - 6.1602 * rBodyWaterLossRatio + 1);
            
            
            if mod(this.oTimer.fTime, 86400) < this.fTimeInCurrentDay
                % Once per day reset the required minimum water intake
                % parameter
                this.fRemainingMinimumDailyWaterIntake = this.fMinimumDailyWaterIntake;
            end
            this.fTimeInCurrentDay = mod(this.oTimer.fTime, 86400);
            
            this.fThirst = this.Thirst(fDensityH2O);
            
            if this.fThirst > 1
                fWaterDebt = (this.tfInitialMasses.fTotalBodyWater) - fTotalBodyWater;
                
                if fWaterDebt < 0
                    fWaterDebt = 0;
                end
                
                fWaterToIngestPerThirst = this.fMinimumDailyWaterIntake / 10;
                
                if fWaterDebt > fWaterToIngestPerThirst
                    fWaterToIngest = fWaterDebt;
                else
                    if this.fRemainingMinimumDailyWaterIntake < 0
                        fWaterToIngest = fWaterDebt;
                    elseif this.fRemainingMinimumDailyWaterIntake < fWaterToIngestPerThirst
                        if fWaterDebt > this.fRemainingMinimumDailyWaterIntake
                            fWaterToIngest = fWaterDebt;
                        else
                            fWaterToIngest = this.fRemainingMinimumDailyWaterIntake;
                        end
                    else
                        fWaterToIngest = fWaterToIngestPerThirst;
                    end
                end
                
                this.fRemainingMinimumDailyWaterIntake = this.fRemainingMinimumDailyWaterIntake - fWaterToIngest;
                
                % trigger a drinking event for the digestion layer!
                this.oParent.toChildren.Digestion.Drink(fWaterToIngest);
            end
            
            %% Micturation
            fCurrentWaterVolumeInBladder = this.toStores.WaterBalance.toPhases.Bladder.afMass(this.oMT.tiN2I.Urine) / fDensityH2O;
            
            if fCurrentWaterVolumeInBladder > this.fBladderVolume && ~this.oParent.toBranches.Urine_Out.oHandler.bMassTransferActive
                this.oParent.toBranches.Urine_Out.oHandler.setMassTransfer(this.toStores.WaterBalance.toPhases.Bladder.fMass * 0.98, 60);
            end
            % Perspiration is calculated in thermal layer. Respiration was
            % moved to respiratory layer!
            %RespirationWaterOutput PerspirationWaterOutput
        end
    end
end