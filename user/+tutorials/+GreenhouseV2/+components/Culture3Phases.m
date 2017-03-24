classdef Culture3Phases < vsys
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
        
        %
        bLight = 1;
        
        % 
        fLightTimeFlag = 0;
        
        afInitialBalanceMass;
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
        function this = Culture3Phases(oParent, txPlantParameters, txInput, fUpdateFrequency)
            this@vsys(oParent, txInput.sCultureName, fUpdateFrequency);
            
            this.oTimer.setMinStep(1e-20);
            
            this.txPlantParameters = txPlantParameters;
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
            
            matter.store(this, this.txInput.sCultureName, 20);
            
            % TO DO: Specify volumes of the phases individually!!! and
            % simply make the store mass the sum of it. Also maybe make a
            % plant store / phase that simply has a fix volume and does not
            % use it to calculate the density or stuff like that...
            % (basically a storeroom? where you can simply put stuff in)
            
            oPlants = matter.phases.mixture(...
                this.toStores.(this.txInput.sCultureName), ...          % store containing phase
                [this.txInput.sCultureName, '_Plants'], ...             % phase name 
                'solid',...                                             % primary phase of the mixture phase
                struct(...                                              % phase contents    [kg]
                    ([this.txPlantParameters.sPlantSpecies, 'EdibleWet']), 1e-3,...
                    ([this.txPlantParameters.sPlantSpecies, 'InedibleWet']), 1e-3), ...
                10, ...                                                 % volume    [m^3]
                293.15, ...                                             % phase temperature [K]
                101325);                                                
            
            matter.procs.exmes.mixture(oPlants, [this.txInput.sCultureName, '_BiomassGrowth_P2P']);
            matter.procs.exmes.mixture(oPlants, [this.txInput.sCultureName, '_Biomass_Out']); 
            
            oBalance = matter.phases.mixture(...
                this.toStores.(this.txInput.sCultureName), ...          % store containing phase
                [this.txInput.sCultureName, '_Balance'], ...            % phase name 
                'solid',...                                             % primary phase of the mixture phase
                struct('CO2', 10, 'O2', 10, 'H2O', 50, 'Nutrients', 1,...
                    ([this.txPlantParameters.sPlantSpecies, 'EdibleWet']), 10,...
                    ([this.txPlantParameters.sPlantSpecies, 'InedibleWet']), 10), ...
                10, ...                                                 % volume    [m^3]
                293.15, ...                                             % phase temperature [K]
                101325);
            
            this.afInitialBalanceMass = oBalance.afMass;
            
            matter.procs.exmes.mixture(oBalance, [this.txInput.sCultureName, '_BiomassGrowth_P2P']);
            matter.procs.exmes.mixture(oBalance, [this.txInput.sCultureName, '_WaterSupply_In']);
            matter.procs.exmes.mixture(oBalance, [this.txInput.sCultureName, '_NutrientSupply_In']);
            
            matter.procs.exmes.mixture(oBalance, [this.txInput.sCultureName, '_GasExchange_In']);
            matter.procs.exmes.mixture(oBalance, [this.txInput.sCultureName, '_GasExchange_Out']);
            
            %% Create Biomass Growth P2P Processor
            
            % 
            tutorials.GreenhouseV2.components.ConstantMassP2P(...
                this, ...                                                                       % parent system reference
                this.toStores.(this.txInput.sCultureName), ...                                  % store containing phases
                [this.txInput.sCultureName, '_BiomassGrowth_P2P'], ...                          % p2p processor name
                [oBalance.sName, '.', this.txInput.sCultureName, '_BiomassGrowth_P2P'], ...     % first phase and exme
                [oPlants.sName, '.', this.txInput.sCultureName, '_BiomassGrowth_P2P'], ...      % second phase and exme
                {([this.txPlantParameters.sPlantSpecies, 'EdibleWet']),...
                ([this.txPlantParameters.sPlantSpecies, 'InedibleWet'])}, 1);                                                                    % substance to keep constant and possible directions (0 is both)
            
            %% Create Substance Conversion Manipulators
            
            tutorials.GreenhouseV2.components.PlantManipulator(this, [this.txInput.sCultureName, '_PlantManipulator'], this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Balance']));
            
            %% Create Branches
            
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_GasExchange_In'],   {}, 'Atmosphere_FromIF_In',     'Atmosphere_In', true);
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_GasExchange_Out'],  {}, 'Atmosphere_ToIF_Out',      'Atmosphere_Out', true);
            
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_WaterSupply_In'],             {}, 'WaterSupply_FromIF_In',    'WaterSupply_In');
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_NutrientSupply_In'],          {}, 'NutrientSupply_FromIF_In', 'NutrientSupply_In');
            matter.branch(this, [this.txInput.sCultureName, '.', this.txInput.sCultureName, '_Biomass_Out'],                {}, 'Biomass_ToIF_Out',         'Biomass_Out');
            
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
            solver.matter.p2p.branch(this.toBranches.Atmosphere_In);
            solver.matter.p2p.branch(this.toBranches.Atmosphere_Out);
            solver.matter.manual.branch(this.toBranches.WaterSupply_In);
            solver.matter.manual.branch(this.toBranches.NutrientSupply_In);
            solver.matter.manual.branch(this.toBranches.Biomass_Out);
            
            % initialize flowrates
            this.toBranches.Atmosphere_In.oHandler.setFlowRate(zeros(1,this.oMT.iSubstances));
            this.toBranches.Atmosphere_Out.oHandler.setFlowRate(zeros(1,this.oMT.iSubstances));
            this.toBranches.WaterSupply_In.oHandler.setFlowRate(0);
            this.toBranches.NutrientSupply_In.oHandler.setFlowRate(0);
            this.toBranches.Biomass_Out.oHandler.setFlowRate(0);
            
            % set time steps
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    oPhase.fMaxStep = this.fTimeStep;
                    this.toStores.(csStoreNames{iStore}).fDefaultTimeStep = this.fTimeStep;
                end
            end
        end
        
        %% Connect Subsystem Interfaces with Parent System
        
        function setIfFlows(this, sIF1, sIF2, sIF3, sIF4, sIF5)
            this.connectIF('Atmosphere_FromIF_In', sIF1);
            this.connectIF('Atmosphere_ToIF_Out', sIF2);
            this.connectIF('WaterSupply_FromIF_In', sIF3);
            this.connectIF('NutrientSupply_FromIF_In', sIF4);
            this.connectIF('Biomass_ToIF_Out', sIF5);
        end
        function update(this)
            
            %% plant sowing
            % in the input struct an Array can be defined to decide when
            % each generation will be sowed (meaning the start time for
            % plant growth for that generation). If nothing was specified 
            % by the user the culture simply created the values in a way
            % that each culture is sowed immediatly after the previous
            % generation is harvested
            if (this.oTimer.fTime > this.txInput.mfSowTime(this.iInternalGeneration)) && this.iState == 4
                this.iState = 1;
                % to prevent the sowing of one generation to happen
                % more than once, we just set the time of the sowing to
                % inf to indicate that this culture was already sowed
                this.txInput.mfSowTime(this.iInternalGeneration) = inf;
            end
            
            %% Calculate 8 MMEC Parameters
            
            % calculate density of liquid H2O, required for transpiration
            tH2O.sSubstance = 'H2O';
            tH2O.sProperty = 'Density';
            tH2O.sFirstDepName = 'Pressure';
%             tH2O.fFirstDepValue = this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fPressure;
            tH2O.fFirstDepValue = this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fPressure;
            tH2O.sSecondDepName = 'Temperature';
%             tH2O.fSecondDepValue = this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Phase_1']).fTemperature;
            tH2O.fSecondDepValue = this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fTemperature;
            tH2O.sPhaseType = 'liquid';
            
            fDensityH2O = this.oMT.findProperty(tH2O);
            
            % calculate CO2 concentration of atmosphere
            this.fCO2 = this.oParent.CalculateCO2Concentration();
            
                [ this ] = ...                                                  % return current culture object
                tutorials.GreenhouseV2.components.PlantGrowth(...
                    this, ...                                               % current culture object
                    this.oTimer.fTime, ...                                  % current simulation time
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMass * this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fMassToPressure, ...                 % atmosphere pressure
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fDensity, ...                  % atmosphere density
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fTemperature, ...              % atmosphere temperature
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.rRelHumidity, ...              % atmosphere relative humidity
                    this.oParent.toStores.Atmosphere.toPhases.Atmosphere_Phase_1.fSpecificHeatCapacity, ...     % atmosphere heat capacity
                    fDensityH2O, ...                                        % density of liquid water under atmosphere conditions
                    this.fCO2);                                             % CO2 concentration in ppm
            
                %% Harvest
            
                % if current culture state is harvest
                % if phase empty too, increase generation and change status
                % to growth, or set to fallow 
                if (this.iState == 2) && (this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).fMass <= 1e-3)
                    if this.iInternalGeneration < this.txInput.iConsecutiveGenerations
                        this.iInternalGeneration = this.iInternalGeneration + 1;
                        this.iState = 4;
                    else
                        this.iState = 4;
                    end
                    
                    this.fInternalTime = 0;
                    disp('Harvesting');
                    
                    this.toBranches.Biomass_Out.oHandler.setFlowRate(0.1);
                
                elseif this.iState == 2
                    %
                    this.toBranches.Biomass_Out.oHandler.setFlowRate(...
                        this.toStores.(this.txInput.sCultureName).toPhases.([this.txInput.sCultureName, '_Plants']).fMass / this.oParent.fTimeStep);
                end
               
                %% Set atmosphere flow rates
                % one p2p for inflows one for outflows
                
                % Substances that are controlled by these branches:
                aiSubstances = [this.oMT.tiN2I.CO2, this.oMT.tiN2I.H2O, this.oMT.tiN2I.O2];
                
                % current masses in the balance phase:
                afCurrentBalanceMass = this.toStores.(this.sName).toPhases.([this.sName,'_Balance']).afMass;
                
                afMassChange = zeros(1,this.oMT.iSubstances);
                afMassChange(aiSubstances) =  afCurrentBalanceMass(aiSubstances) - this.afInitialBalanceMass(aiSubstances);
                
                afPartialFlowRates = afMassChange./36000;
                
                afPartialFlowRates(this.oMT.tiN2I.O2) = afPartialFlowRates(this.oMT.tiN2I.O2) + this.tfGasExchangeRates.fO2ExchangeRate;
                afPartialFlowRates(this.oMT.tiN2I.CO2) = afPartialFlowRates(this.oMT.tiN2I.CO2) + this.tfGasExchangeRates.fCO2ExchangeRate;
                afPartialFlowRates(this.oMT.tiN2I.H2O) = afPartialFlowRates(this.oMT.tiN2I.H2O) + this.tfGasExchangeRates.fTranspirationRate;
            
                if afPartialFlowRates(this.oMT.tiN2I.H2O) < 0
                    afPartialFlowRates(this.oMT.tiN2I.H2O) = 0;
                end
                
                if ~this.bLight && (afPartialFlowRates(this.oMT.tiN2I.CO2) < 0)
                    afPartialFlowRates(this.oMT.tiN2I.CO2) = 0;
                elseif this.bLight && (afPartialFlowRates(this.oMT.tiN2I.O2) < 0)
                    afPartialFlowRates(this.oMT.tiN2I.O2) = 0;
                end
                
                afPartialFlowRatesIn = zeros(1,this.oMT.iSubstances);
                afPartialFlowRatesIn(afPartialFlowRates < 0) = afPartialFlowRates(afPartialFlowRates < 0);
                
                afPartialFlowRatesOut = zeros(1,this.oMT.iSubstances);
                afPartialFlowRatesOut(afPartialFlowRates > 0) = afPartialFlowRates(afPartialFlowRates > 0);
                
                % in flows are negative because it is subsystem if branch!
                this.toBranches.Atmosphere_In.oHandler.setFlowRate(afPartialFlowRatesIn);
                this.toBranches.Atmosphere_Out.oHandler.setFlowRate(afPartialFlowRatesOut);
                
                
                %% Set branch flow rates
%                 this.toBranches.Atmosphere_In.oHandler.setFlowRate(this.fAirFlow);
%                 this.toBranches.Atmosphere_Out.oHandler.setFlowRate(1e-2 + this.tfGasExchangeRates.fO2ExchangeRate + this.tfGasExchangeRates.fCO2ExchangeRate + this.tfGasExchangeRates.fTranspirationRate);
                %setPartialFlowRates
                
                this.toBranches.WaterSupply_In.oHandler.setFlowRate(-this.fWaterConsumptionRate);
                if this.afInitialBalanceMass(this.oMT.tiN2I.Nutrients) < afCurrentBalanceMass (this.oMT.tiN2I.Nutrients)
                    this.toBranches.NutrientSupply_In.oHandler.setFlowRate(-this.fNutrientConsumptionRate*0.99);
                else
                    this.toBranches.NutrientSupply_In.oHandler.setFlowRate(-this.fNutrientConsumptionRate*0.99);
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
        end
    end
end