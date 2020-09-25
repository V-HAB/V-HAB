classdef PlantCulture < vsys
    % This class is used in creating the culture objects. It provides the
    % phase for plant growth, adds a p2p processor which is automatically
    % connected to biomass buffer store, two exmes and corresponding p2p
    % processors which are automatically connected to the edible and
    % inedible biomass phases and a manipulator to convert the incoming
    % biomass into the culture's specific one. It also contains specific
    % plant data depending on the species grown.
    
    properties
        % struct containing plant parameters specific to the grown culture,
        % from parent system
        txPlantParameters;
        
        % save input parameters, they need to be requested
        txInput;
        
        % struct containing the 8 parameters calculated via the (M)MEC and
        % FAO model equations. written by PlantGrowth() call in parent
        % system's exec() function.
        tfMMECRates = struct();     % [kg s^-1]
        
        % internal time of plant culture (passed time AFTER planting)
        fInternalTime = 0;          % [s]
        
        % time at which the current culture was sowed
        fSowTime =  0;              % [s]
        
        % time at which plant growth is initialized
        fPlantTimeInit; % [d]
        
        
        % time corresponding to the plants (different from fInternalTime
        % because fInternalTime counts the time from growing whereass
        % fPlantTime is the current time of the plant module
        % (this.oTimer.fTime + fPlantTimeInit * 86400)
        fPlantTime;
        
        % TODO: maybe later implement some kind of decay mechanic, already
        % using a placeholder for it here.
        % using numbers instead of strings for quicker and easier access
        % state of culture: 1 = growth, 2 = harvest, 3 = decay, 4 = fallow
        % default is fallow
        iState = 4;
        
        % internal generation counter, start at 1
        iInternalGeneration = 1;
        
        %
        fCO2 = 330;
        
        
        oAtmosphere;
        
        
        % Things needed for Plant Module Verification
        i = 1;
        mfOxygenProduction;
        mfCarbonDioxideUptake;
        mfWaterTranspiration;
        mfTotalBioMass;
        mfInedibleMass;
        mfEdibleMass;
        
        %
        bLight = 1;
        
        %
        fLightTimeFlag = 0;
        
        afInitialBalanceMass;
        
        % Matter indices for the edible and inedible plant mass of this
        % culture
        iEdibleBiomass;
        iInedibleBiomass;
        
    end
    
    properties
        %% Culture Mass Transfer Rates
        
        % culture gas exchange with atmosphere (O2, CO2, H2O)
        tfGasExchangeRates = struct();      % [kg s^-1]
        
        % culture water consumption
        fWaterConsumptionRate = 0;          % [kg s^-1]
        
        % culture nutrient consumption
        fNutrientConsumptionRate = 0;       % [kg s^-1]
        
        % culture biomass growth (edible and inedible, both wet)
        tfBiomassGrowthRates = struct();    % [kg s^-1]
        
        % Flowrate of the air from Greenhouse to the air surrounding the
        % plants
        fAirFlow = 0;                       % [kg s^-1]
    end
    
    methods
        function this = PlantCulture(oParent, sName, fUpdateFrequency, txInput, fPlantTimeInit)
            % In order to initialize the plant culture at a specific later
            % time you have to provide the value of that time in
            % fPlantTimeInit in seconds and the txInput struct requires the
            % additional field mfPlantMassInit which is vector with the
            % first entry as edible biomass in kg and the second entry as
            % inedible biomass in kg, at the time of plant initialization
            this@vsys(oParent, sName, fUpdateFrequency);
            
            % just to let old definitions operate without requiring rework
            if isfield(txInput, 'fH')
                txInput.fPhotoperiod = txInput.fH;
            end
            
            if (nargin >= 5)
                this.fPlantTimeInit = fPlantTimeInit;
            else
                this.fPlantTimeInit = 0;
            end
            
            this.txPlantParameters = components.matter.PlantModuleV2.plantparameters.importPlantParameters(txInput.sPlantSpecies);
            
            this.iEdibleBiomass = this.oMT.tiN2I.(this.txPlantParameters.sPlantSpecies);
            this.iInedibleBiomass = this.oMT.tiN2I.([this.txPlantParameters.sPlantSpecies, 'Inedible']);
            
            trBaseCompositionEdible     = this.oMT.ttxMatter.(this.oMT.csI2N{this.iEdibleBiomass}).trBaseComposition;
            trBaseCompositionInedible   = this.oMT.ttxMatter.(this.oMT.csI2N{this.iInedibleBiomass}).trBaseComposition;
            
            this.txPlantParameters.fWBF_Edible      = trBaseCompositionEdible.H2O;
            this.txPlantParameters.fWBF_Inedible    = trBaseCompositionInedible.H2O;
            
            this.txPlantParameters.fFBWF_Edible     = trBaseCompositionEdible.H2O   * (1 - trBaseCompositionEdible.H2O)^-1;
            this.txPlantParameters.fFBWF_Inedible 	= trBaseCompositionInedible.H2O * (1 - trBaseCompositionInedible.H2O)^-1;
            
            this.txInput = txInput;
            
            % the flowrates set here are all used in the manipulator
            % attached to the balance phase. Through this manipulator the
            % masses of CO2, O2, H2O and plants will change. The respective
            % flowrates for the P2Ps to maintain the mass in the other
            % phases are calculated from the mass changes in the balance
            % phase by using constant mass p2ps!
            % Example: The plants are currently in the dark and CO2 is
            % produced by the manipulator in the balance phase. In this
            % case the constant mass P2P for CO2 will have a flowrate
            % pushing CO2 from the balance phase to the atmosphere!
            
            % intialize empty structs
            this.tfGasExchangeRates.fO2ExchangeRate = 0;
            this.tfGasExchangeRates.fCO2ExchangeRate = 0;
            this.tfGasExchangeRates.fTranspirationRate = 0;
            
            this.tfBiomassGrowthRates.fGrowthRateEdible = 0;
            this.tfBiomassGrowthRates.fGrowthRateInedible = 0;
            
            this.tfMMECRates.fWC = 0;
            this.tfMMECRates.fTR = 0;
            this.tfMMECRates.fOC = 0;
            this.tfMMECRates.fOP = 0;
            this.tfMMECRates.fCO2C = 0;
            this.tfMMECRates.fCO2P = 0;
            this.tfMMECRates.fNC = 0;
            this.tfMMECRates.fCGR = 0;
            
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %% Create Store, Phases and Processors
            
            matter.store(this, 'Plant_Culture', 10000.1);
            
            % TO DO: Specify volumes of the phases individually!!! and
            % simply make the store mass the sum of it. Also maybe make a
            % plant store / phase that simply has a fix volume and does not
            % use it to calculate the density or stuff like that...
            % (basically a storeroom? where you can simply put stuff in)
            
            
            try
                 fEdibleMass = this.txInput.mfPlantMassInit(1);
                 fInedibleMass = this.txInput.mfPlantMassInit(2);
            catch
                 fEdibleMass = 1e-3;
                 fInedibleMass = 1e-3;
            end
            
            
            oPlants = matter.phases.mixture(...
                this.toStores.Plant_Culture, ...                        % store containing phase
                'Plants', ...                                           % phase name
                'solid',...                                             % primary phase of the mixture phase
                struct(...                                              % phase contents    [kg]
                this.txPlantParameters.sPlantSpecies, fEdibleMass,...
                [this.txPlantParameters.sPlantSpecies, 'Inedible'], fInedibleMass), ...
                293.15, ...                                             % phase temperature [K]
                101325);
            
            matter.procs.exmes.mixture(oPlants, 'BiomassGrowth_P2P_In');
            matter.procs.exmes.mixture(oPlants, 'Biomass_Out');
            
            oBalance = matter.phases.mixture(...
                this.toStores.Plant_Culture, ...                        % store containing phase
                'Balance', ...                                          % phase name
                'solid',...                                             % primary phase of the mixture phase
                struct('CO2', 0.1, 'O2', 0.1, 'H2O', 0.5, 'Nutrients', 0.01,...
                (this.txPlantParameters.sPlantSpecies), 0.1,...
                ([this.txPlantParameters.sPlantSpecies, 'Inedible']), 0.1), ...
                293.15, ...                                             % phase temperature [K]
                101325);
            
            this.afInitialBalanceMass = oBalance.afMass;
            
            matter.procs.exmes.mixture(oBalance, 'BiomassGrowth_P2P_Out');
            matter.procs.exmes.mixture(oBalance, 'WaterSupply_In');
            matter.procs.exmes.mixture(oBalance, 'NutrientSupply_In');
            
            matter.procs.exmes.mixture(oBalance, 'GasExchange1_In');
            matter.procs.exmes.mixture(oBalance, 'GasExchange2_Out');
            
            cAirHelper = matter.helper.phase.create.air(this.toStores.Plant_Culture, 0.1, 293.15, 0.5, 101325);
            oAtmospherePhase = matter.phases.flow.gas(this.toStores.Plant_Culture, 'PlantAtmosphere',  cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            matter.procs.exmes.gas(oAtmospherePhase, 'Air_From_Greenhouse');
            matter.procs.exmes.gas(oAtmospherePhase, 'Air_To_Greenhouse');
            
            matter.procs.exmes.gas(oAtmospherePhase, 'GasExchange2_In');
            matter.procs.exmes.gas(oAtmospherePhase, 'GasExchange1_Out');
            
            %% Create Biomass Growth P2P Processor
            
            %
            components.matter.P2Ps.ManualP2P(...
                this.toStores.Plant_Culture, ...                % store containing phases
                'BiomassGrowth_P2P', ...                     	% p2p processor name
                [oBalance.sName, '.BiomassGrowth_P2P_Out'], ...     % first phase and exme
                [oPlants.sName, '.BiomassGrowth_P2P_In']);         % second phase and exme
            
            components.matter.P2Ps.ManualP2P(...
                this.toStores.Plant_Culture, ...                % store containing phases
                'GasExchange_From_Atmosphere_To_Plants', ...       % p2p processor name
                [oAtmospherePhase.sName, '.GasExchange1_Out'], ...     % first phase and exme
                [oBalance.sName, '.GasExchange1_In']);         % second phase and exme
            
            components.matter.P2Ps.ManualP2P(...
                this.toStores.Plant_Culture, ...                % store containing phases
                'GasExchange_From_Plants_To_Atmosphere', ...       % p2p processor name
                [oBalance.sName, '.GasExchange2_Out'], ...     % first phase and exme
                [oAtmospherePhase.sName, '.GasExchange2_In']);         % second phase and exme

            %% Create Substance Conversion Manipulators
            
            components.matter.Manips.ManualManipulator(this, 'PlantManipulator', this.toStores.Plant_Culture.toPhases.Balance);
            
            %% Create Branches
            
            matter.branch(this, 'Plant_Culture.Air_From_Greenhouse',        {}, 'Atmosphere_FromIF_In',     'Atmosphere_In');
            matter.branch(this, 'Plant_Culture.Air_To_Greenhouse',          {}, 'Atmosphere_ToIF_Out',      'Atmosphere_Out');

            
            matter.branch(this, 'Plant_Culture.WaterSupply_In',             {}, 'WaterSupply_FromIF_In',    'WaterSupply_In');
            matter.branch(this, 'Plant_Culture.NutrientSupply_In',          {}, 'NutrientSupply_FromIF_In', 'NutrientSupply_In');
            matter.branch(this, 'Plant_Culture.Biomass_Out',                {}, 'Biomass_ToIF_Out',         'Biomass_Out');
            
            %% Check if user provided sow times, if not generate them
            % If nothing was specified by the user the culture simply
            % created the values in a way that each culture is sowed
            % immediatly after the previous generation is harvested
            if ~isfield(this.txInput, 'mfSowTime')
                % if it does not exist we just create it (Note times will
                % be zero, but that just means that it will occure
                % immediatly after the previous generation!)
                this.txInput.mfSowTime = zeros(1,this.txInput.iConsecutiveGenerations);
            end
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % add branches to solvers            
            solver.matter.manual.branch(this.toBranches.Atmosphere_In);
            
            tSolverProperties.fMaxError = 1e-6;
            tSolverProperties.iMaxIterations = 100;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 20;
            
            oSolver = solver.matter_multibranch.iterative.branch(this.toBranches.Atmosphere_Out, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            

            solver.matter.manual.branch(this.toBranches.WaterSupply_In);
            solver.matter.manual.branch(this.toBranches.NutrientSupply_In);
            solver.matter.manual.branch(this.toBranches.Biomass_Out);
            
            % initialize flowrates
            this.toBranches.Atmosphere_In.oHandler.setFlowRate(-0.01 * this.txInput.fGrowthArea);
            
            this.toBranches.WaterSupply_In.oHandler.setFlowRate(0);
            this.toBranches.NutrientSupply_In.oHandler.setFlowRate(0);
            this.toBranches.Biomass_Out.oHandler.setFlowRate(0);
            
            % set time steps
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    
                    arMaxChange = zeros(1,this.oMT.iSubstances);
                    arMaxChange(this.oMT.tiN2I.H2O) = 0.5;
                    arMaxChange(this.oMT.tiN2I.CO2) = 0.5;
                    arMaxChange(this.oMT.tiN2I.O2)  = 0.5;
                    tTimeStepProperties.arMaxChange =arMaxChange;
                    tTimeStepProperties.fMaxStep = this.fTimeStep;
                    
                    oPhase.setTimeStepProperties(tTimeStepProperties)
                end
            end
            
            tTimeStepProperties = struct();
            
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    
                    tTimeStepProperties.fMaxStep = this.fTimeStep;
                    
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties)
                end
            end
            
            clear tTimeStepProperties
            tTimeStepProperties.fFixedTimeStep = this.fTimeStep;
            this.toStores.Plant_Culture.toPhases.Plants.setTimeStepProperties(tTimeStepProperties);
            this.toStores.Plant_Culture.toPhases.Plants.oCapacity.setTimeStepProperties(tTimeStepProperties);
            
            %% Assign thermal solvers
            this.setThermalSolvers();
        end
        
        %% Connect Subsystem Interfaces with Parent System
        
        function setIfFlows(this, sIF1, sIF2, sIF3, sIF4, sIF5)
            this.connectIF('Atmosphere_FromIF_In', sIF1);
            this.connectIF('Atmosphere_ToIF_Out', sIF2);
            this.connectIF('WaterSupply_FromIF_In', sIF3);
            this.connectIF('NutrientSupply_FromIF_In', sIF4);
            this.connectIF('Biomass_ToIF_Out', sIF5);
            
            this.oAtmosphere = this.toBranches.Atmosphere_In.coExmes{2}.oPhase;
        end
        function update(this)
            
            
            % Calculating the Time for the Plant Module [s]
            this.fPlantTime = this.oTimer.fTime + (this.fPlantTimeInit * 86400);
            
            
            %% plant sowing
            % in the input struct an Array can be defined to decide when
            % each generation will be sowed (meaning the start time for
            % plant growth for that generation). If nothing was specified
            % by the user the culture simply created the values in a way
            % that each culture is sowed immediatly after the previous
            % generation is harvested
            if (this.fPlantTime > this.txInput.mfSowTime(1,this.iInternalGeneration)) && this.iState == 4
                this.iState = 1;
                % to prevent the sowing of one generation to happen
                % more than once, we just set the time of the sowing to
                % inf to indicate that this culture was already sowed
                if this.fPlantTime > this.txInput.mfSowTime(this.iInternalGeneration)
                    if this.iInternalGeneration == 1
                        this.fSowTime = this.txInput.mfSowTime(this.iInternalGeneration);
                        this.txInput.mfSowTime(this.iInternalGeneration) = inf;
                    elseif this.txInput.mfSowTime(this.iInternalGeneration) ~= 0
                        this.fSowTime = this.txInput.mfSowTime(this.iInternalGeneration);
                        this.txInput.mfSowTime(this.iInternalGeneration) = inf;
                    else
                        this.fSowTime = this.fPlantTime;
                        this.txInput.mfSowTime(this.iInternalGeneration) = inf;
                    end
                    
                else
                    this.txInput.mfSowTime(this.iInternalGeneration) = inf;
                    this.fSowTime = this.oTimer.fTime;
                end
                
            end
            
            % Get reference phase atmospheric values:
            this.fCO2 = ((this.oAtmosphere.afMass(this.oAtmosphere.oMT.tiN2I.CO2) * this.oAtmosphere.fMolarMass) / (this.oAtmosphere.fMass * this.oAtmosphere.oMT.afMolarMass(this.oAtmosphere.oMT.tiN2I.CO2))) * 1e6;
            
            %% Calculate 8 MMEC Parameters
            [ this ] =  components.matter.PlantModuleV2.PlantGrowth(this, this.fPlantTime);
            
            %% Set manip flowrates:
            afPartialFlows = zeros(1, this.oMT.iSubstances);
            
            % for faster reference
            tiN2I      = this.oMT.tiN2I;
            
            % phase inflows (water and nutrients)
            afPartialFlows(1, tiN2I.H2O) =         -(this.fWaterConsumptionRate - this.tfGasExchangeRates.fTranspirationRate);
            afPartialFlows(1, tiN2I.Nutrients) =   -this.fNutrientConsumptionRate;

            % gas exchange with atmosphere (default plants -> atmosphere, 
            % so same sign for destruction)
            afPartialFlows(1, tiN2I.O2) =          this.tfGasExchangeRates.fO2ExchangeRate;
            afPartialFlows(1, tiN2I.CO2) =         this.tfGasExchangeRates.fCO2ExchangeRate;

            % edible and inedible biomass growth
            afPartialFlows(1, this.iEdibleBiomass) =   this.tfBiomassGrowthRates.fGrowthRateEdible;
            afPartialFlows(1, this.iInedibleBiomass) = this.tfBiomassGrowthRates.fGrowthRateInedible;
            
            % to reduce mass erros the current error in mass is spread over
            % the in and outs
            fError = sum(afPartialFlows);
            if fError ~= 0
                fPositiveFlowRate = sum(afPartialFlows(afPartialFlows > 0));
                fNegativeFlowRate = abs(sum(afPartialFlows(afPartialFlows < 0)));
                
                if fPositiveFlowRate > fNegativeFlowRate
                    % reduce the positive flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = afPartialFlows(afPartialFlows > 0)./fPositiveFlowRate;
                    
                    afPartialFlows(afPartialFlows > 0) = afPartialFlows(afPartialFlows > 0) - fDifference .* arRatios;
                else
                    % reduce the negative flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = abs(afPartialFlows(afPartialFlows < 0)./fNegativeFlowRate);
                    
                    afPartialFlows(afPartialFlows < 0) = afPartialFlows(afPartialFlows < 0) - fDifference .* arRatios;
                end
            end
            
            trBaseCompositionEdible     = this.oMT.ttxMatter.(this.oMT.csI2N{this.iEdibleBiomass}).trBaseComposition;
            trBaseCompositionInedible   = this.oMT.ttxMatter.(this.oMT.csI2N{this.iInedibleBiomass}).trBaseComposition;
            
            fTotalPlantBiomassWaterConsumption = -afPartialFlows(1, tiN2I.H2O);
            
            fWaterConsumptionEdible     = trBaseCompositionEdible.H2O   * afPartialFlows(1, this.iEdibleBiomass);
            fWaterConsumptionInedible   = trBaseCompositionInedible.H2O * afPartialFlows(1, this.iInedibleBiomass);
            
            % Not all of the water is added as actual water content in the
            % biomass, some water is actually transformed into biomass. To
            % calculate the part of water that is necessary to create
            % biomass, we calculate the required water flow for the dry
            % crop growth rate:
            fDryGrowthEdible    = (this.tfBiomassGrowthRates.fGrowthRateEdible      / (this.txPlantParameters.fFBWF_Edible + 1));
            fDryGrowthInedible  =  this.tfBiomassGrowthRates.fGrowthRateInedible    / (this.txPlantParameters.fFBWF_Inedible + 1);
            
            % This water mass is not considered when calculating the water
            % content of the biomass in the following, because it is not
            % present as water in the plant but actually as biomass (e.g.
            % CO2 + H2O -> C6H12O6 + O2 does consume water without the
            % products containing water)
            fWaterToBiomass     = this.tfGasExchangeRates.fO2ExchangeRate + this.tfGasExchangeRates.fCO2ExchangeRate +  fDryGrowthEdible + fDryGrowthInedible - this.fNutrientConsumptionRate;
         
            % The MEC model does not produce biomass with necessarily
            % exactly the water content specified as base content.
            % Therefore, we have to check what the difference is. Usually
            % this difference will be handled in the inedible plant parts,
            % but for some plants there are no inedible parts after an
            % initial growth period (See BVAD table 4.119)
            fWaterConsumptionDifference = fTotalPlantBiomassWaterConsumption - fWaterConsumptionEdible - fWaterConsumptionInedible - fWaterToBiomass;
            
            % Now we have to decide how to spread the water difference
            % compared to the base values
            if fWaterConsumptionDifference > 0
                if fWaterConsumptionInedible > 2*fWaterConsumptionDifference
                    % in this case we assume the water difference to occur
                    % only in the inedible plant part
                    fEdibleWaterDifference      = 0;
                    fInedibleWaterDifference    = fWaterConsumptionDifference;
                else
                    % In this case we spread the water difference based on
                    % the water consumption rates compared to the total
                    % water consumption rate
                    fEdibleWaterDifference      = fWaterConsumptionDifference *  fWaterConsumptionEdible    / (fWaterConsumptionEdible + fWaterConsumptionInedible);
                    fInedibleWaterDifference    = fWaterConsumptionDifference *  fWaterConsumptionInedible  / (fWaterConsumptionEdible + fWaterConsumptionInedible);
                end
            else
                if (fWaterConsumptionInedible + fWaterConsumptionDifference) < 0.5 * fWaterConsumptionInedible
                    fEdibleWaterDifference      = fWaterConsumptionDifference *  fWaterConsumptionEdible    / (fWaterConsumptionEdible + fWaterConsumptionInedible);
                    fInedibleWaterDifference    = fWaterConsumptionDifference *  fWaterConsumptionInedible  / (fWaterConsumptionEdible + fWaterConsumptionInedible);
                else
                    fEdibleWaterDifference      = 0;
                    fInedibleWaterDifference    = fWaterConsumptionDifference;
                end
            end
            
            fWaterConsumptionEdible     = fWaterConsumptionEdible + fEdibleWaterDifference;
            fWaterConsumptionInedible   = fWaterConsumptionInedible + fInedibleWaterDifference;
            
            if fWaterConsumptionInedible < 0
                error('In the plant module too much water is used for inedible plant biomass production')
            end
            if fWaterConsumptionInedible - afPartialFlows(1, this.iInedibleBiomass) > 1e-6
                error('In the plant module more water is consumed than biomass is created! This might be due to a mismatch between the defined water content for the edible plant biomass and the assumed edible biomass water content in the MEC model')
            end
            
            aarManipCompoundMassRatios = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            
            if afPartialFlows(1, this.iInedibleBiomass) > 0
                if fWaterConsumptionInedible > afPartialFlows(1, this.iInedibleBiomass)
                    % This should not occur permanently, and large cases of
                    % this are catched by the errors above. For cases where
                    % this occurs on a small scale, we can set the water
                    % content to 1
                    aarManipCompoundMassRatios(this.iInedibleBiomass, this.oMT.tiN2I.H2O)       = 1;
                else
                    aarManipCompoundMassRatios(this.iInedibleBiomass, this.oMT.tiN2I.H2O)       = fWaterConsumptionInedible / afPartialFlows(1, this.iInedibleBiomass);

                    csInedibleComposition = fieldnames(trBaseCompositionInedible);
                    % This calculation enables easy addition of other materials to
                    % the inedible biomass of each plant. It only requires the
                    % addition of that mass to the base composition struct
                    for iField = 1:length(csInedibleComposition)
                        if strcmp(csInedibleComposition{iField}, 'H2O')
                            continue
                        end
                        rMassRatioWithoutWater = (trBaseCompositionInedible.(csInedibleComposition{iField}) / (1 - trBaseCompositionInedible.H2O));
                        aarManipCompoundMassRatios(this.iInedibleBiomass, this.oMT.tiN2I.(csInedibleComposition{iField}))   = rMassRatioWithoutWater * (afPartialFlows(1, this.iInedibleBiomass) - fWaterConsumptionInedible) / afPartialFlows(1, this.iInedibleBiomass);
                    end
                end
            end
            
            if afPartialFlows(1, this.iEdibleBiomass) > 0
                % This calculation enables easy addition of other materials to
                % the edible biomass of each plant. It only requires the
                % addition of that mass to the base composition struct
                aarManipCompoundMassRatios(this.iEdibleBiomass, this.oMT.tiN2I.H2O)       = fWaterConsumptionEdible / afPartialFlows(1, this.iEdibleBiomass);
                csEdibleComposition = fieldnames(trBaseCompositionEdible);
                for iField = 1:length(csEdibleComposition)
                    if strcmp(csEdibleComposition{iField}, 'H2O')
                        continue
                    end
                    rMassRatioWithoutWater = (trBaseCompositionEdible.(csEdibleComposition{iField}) / (1 - trBaseCompositionEdible.H2O));
                    aarManipCompoundMassRatios(this.iEdibleBiomass, this.oMT.tiN2I.(csEdibleComposition{iField}))   = rMassRatioWithoutWater * (afPartialFlows(1, this.iEdibleBiomass) - fWaterConsumptionEdible) / afPartialFlows(1, this.iEdibleBiomass);
                end
            end
            
            this.toStores.Plant_Culture.toPhases.Balance.toManips.substance.setFlowRate(afPartialFlows, aarManipCompoundMassRatios);
            
            %% Set Plant Growth Flow Rates
            afPartialFlowRatesBiomass = zeros(1,this.oMT.iSubstances);
            % current masses in the balance phase:
            afPartialFlowRatesBiomass(this.iEdibleBiomass) = afPartialFlows(this.iEdibleBiomass); 
            afPartialFlowRatesBiomass(this.iInedibleBiomass) = afPartialFlows(this.iInedibleBiomass);
            this.toStores.Plant_Culture.toProcsP2P.BiomassGrowth_P2P.setFlowRate(afPartialFlowRatesBiomass);

            %% Set atmosphere flow rates
            % one p2p for inflows one for outflows
            afPartialFlowsGas = zeros(1,this.oMT.iSubstances);
            afPartialFlowsGas(this.oMT.tiN2I.O2)    = afPartialFlows(this.oMT.tiN2I.O2);
            afPartialFlowsGas(this.oMT.tiN2I.CO2)   = afPartialFlows(this.oMT.tiN2I.CO2);
            
            % Substances that are controlled by these branches:
            afPartialFlowsGas(this.oMT.tiN2I.H2O) = this.tfGasExchangeRates.fTranspirationRate;
            
            afPartialFlowRatesIn = zeros(1,this.oMT.iSubstances);
            afPartialFlowRatesIn(afPartialFlowsGas < 0) = afPartialFlowsGas(afPartialFlowsGas < 0);

            afPartialFlowRatesOut = zeros(1,this.oMT.iSubstances);
            afPartialFlowRatesOut(afPartialFlowsGas > 0) = afPartialFlowsGas(afPartialFlowsGas > 0);

            % in flows are negative because it is subsystem if branch!
            this.toStores.Plant_Culture.toProcsP2P.GasExchange_From_Plants_To_Atmosphere.setFlowRate(afPartialFlowRatesOut);
            this.toStores.Plant_Culture.toProcsP2P.GasExchange_From_Atmosphere_To_Plants.setFlowRate(-afPartialFlowRatesIn);
            
            %% Set Water and Nutrient branch flow rates
            this.toBranches.WaterSupply_In.oHandler.setFlowRate(-this.fWaterConsumptionRate);
            this.toBranches.NutrientSupply_In.oHandler.setFlowRate(-this.fNutrientConsumptionRate);
            
            % For debugging, if the mass balance is no longer correct
            fBalanceCulture = this.tfGasExchangeRates.fO2ExchangeRate + this.tfGasExchangeRates.fCO2ExchangeRate + this.tfGasExchangeRates.fTranspirationRate + ...
                     (this.tfBiomassGrowthRates.fGrowthRateInedible + this.tfBiomassGrowthRates.fGrowthRateEdible) ...
                     - (this.fWaterConsumptionRate + this.fNutrientConsumptionRate);
            if abs(fBalanceCulture) > 1e-10
                keyboard()
            end
            
            %% Harvest
            
            % if current culture state is harvest
            % if phase empty too, increase generation and change status
            % to growth, or set to fallow
            if (this.iState == 2) && (this.toStores.Plant_Culture.toPhases.Plants.fMass <= 1e-3)
                if this.iInternalGeneration < this.txInput.iConsecutiveGenerations
                    this.iInternalGeneration = this.iInternalGeneration + 1;
                    this.iState = 4;
                else
                    this.iState = 4;
                end
                
                this.fInternalTime = 0;
                disp('Harvesting');
                
                % Finishing cleanup, the plant is now in the fallow
                % state, all flowrates set to zero. If a follow on
                % culture is used they will be reset on the next tick
                % once the new culture started.
                this.fWaterConsumptionRate = 0;
                this.fNutrientConsumptionRate = 0;
                this.tfGasExchangeRates.fO2ExchangeRate = 0;
                this.tfGasExchangeRates.fCO2ExchangeRate = 0;
                this.tfGasExchangeRates.fTranspirationRate = 0;
                this.tfBiomassGrowthRates.fGrowthRateEdible = 0;
                this.tfBiomassGrowthRates.fGrowthRateInedible = 0;
                
                this.toBranches.WaterSupply_In.oHandler.setFlowRate(0);
                this.toBranches.NutrientSupply_In.oHandler.setFlowRate(0);
                
                this.toStores.Plant_Culture.toProcsP2P.GasExchange_From_Atmosphere_To_Plants.setFlowRate(zeros(1,this.oMT.iSubstances));

                
            elseif this.iState == 2
                %
                this.toBranches.Biomass_Out.oHandler.setMassTransfer(0.99 * this.toStores.Plant_Culture.toPhases.Plants.fMass, 1*this.fTimeStep);
            end
            
            try
                this.oParent.update()
            catch
                % it is recommended to couple the update function of
                % the parent, if you have any cross influence between
                % the parent update and this update function
            end
            
            this.fLastExec = this.oTimer.fTime;
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            this.update();
        end
    end
end