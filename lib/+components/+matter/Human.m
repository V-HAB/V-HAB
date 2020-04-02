classdef Human < vsys
    % human model subsystem
    properties (SetAccess = protected, GetAccess = public)
        
        %% FIX Values that do not change during the simulation
        % The basic energy demand from food this human has without
        % excercise
        fBasicFoodEnergyDemand; % in J/(Human and day)
        
        fVO2_max; % ml/kg/min
        
        iNumberOfHumans = 1;
        
        fHumanMass;
        fHumanHeight;
        
        tfEnergyContent
        
        txCrewPlaner;
        
        trInitialFoodComposition;
        
        afInitialMassHuman;
        afInitialMassFeces;
        afInitialMassUrine;
        
        tHumanMetabolicValues;
        
        % Please note, you must shift the iState property by +1 to get the
        % correct state (since 0 for sleep seemed logical):
        % this.csStates{this.iState + 1}
        csStates;
        
        %% Variables that change during the simulation
        fVO2_current;
        
        fCurrentEnergyDemand; % in J/s
        fAdditionalFoodEnergyDemand = 0;  % in J/(Human and day) , summed up till the next meal
        
        fRespiratoryCoefficient;
        fCaloricValueOxygen;    % J/kg
        
        fOxygenDemand;  % in kg/s
        fCO2Production; % in kg/s
        
        fMetabolicWaterProduction;
        fUrineSolidsProduction;
        % Feces solid flowrate according to BVAD 2015 table 3.26 is
        % 0.032 kg/d
        fFecesSolidProduction = (0.032/86400);
        
        % Current state the human is in, 0 means sleep, 1 means nominal, 2
        % means exercise first 15 Minutes, 3 is exercise from minute 15
        % onwards, 4 is the first 15 minutes of recovery, 5,6,7 are
        % respectivly the next 15 minute increments of recovery
        iState = 1;
        
        fStateStartTime = 0;
        
        iEvent = 1;
        
        requestFood;
        oFoodBranch;
        
        oHeatSource;
        
        %% Variables just for plotting 
        fOxygenDemandNominal;
        fOxygenDemandSleep;
        
    end
    
    methods
        function this = Human(oParent, sName, bMale, fAge, fHumanMass, fHumanHeight, txCrewPlaner, iNumberOfHumans, trInitialFoodComposition)
            
            this@vsys(oParent, sName, 2 * 60);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            if nargin > 7
                this.iNumberOfHumans = iNumberOfHumans;
            end
            
            this.fFecesSolidProduction = this.fFecesSolidProduction * this.iNumberOfHumans;
            
            if nargin > 8
                this.trInitialFoodComposition = trInitialFoodComposition;
            else
                % standard food composition based on the composition
                % suggested in the HDIH on page 2010 488
                this.trInitialFoodComposition.Fat           = 0.3;
                this.trInitialFoodComposition.Protein       = 0.2;
                this.trInitialFoodComposition.Carbohydrate  = 0.5;
            end
            
            % For legacy reasons, define the nutritional energy content
            % here locally
            this.tfEnergyContent.Fat          = this.oMT.afNutritionalEnergy(this.oMT.tiN2I.C16H32O2);
            this.tfEnergyContent.Protein      = this.oMT.afNutritionalEnergy(this.oMT.tiN2I.C4H5ON);
            this.tfEnergyContent.Carbohydrate = this.oMT.afNutritionalEnergy(this.oMT.tiN2I.C6H12O6);
            
            % boolean is the easiest way to differentiate between male and
            % female, calculate the basic energy demand
            if bMale
                % Equation for metabolic consumption of a human male
                % according to NASA BVAD TP-2015-218570 page 43, however as
                % exercise is considered seperatly an activity factor of 1
                % is used
                this.fBasicFoodEnergyDemand = this.iNumberOfHumans * 10^6 * (622 - 9.53 * fAge + 1*(15.9 * fHumanMass + 539.6 * fHumanHeight))/(0.238853*10^3);
            else
                % Equation for metabolic consumption of a human female
                % according to NASA BVAD TP-2015-218570 page 43, however as
                % exercise is considered seperatly an activity factor of 1
                % is used
                this.fBasicFoodEnergyDemand = this.iNumberOfHumans * 10^6 * (354 - 6.91 * fAge + 1*(9.36 * fHumanMass + 726 * fHumanHeight))/(0.238853*10^3);
            end
            
            % Since the feces are also modelled as a chemical reaction that
            % consumes fat, protein and carbohydrate, the basic food demand
            % (which is also used to calculate the current O2 consumption
            % of the human) is adapted. Since the energy demand above is
            % the overall, it includes the consumption of feces, that value
            % is later on added again in a way that it does not impact O2
            % and CO2 (as that would lead to an imbalance in the masses)
            fMolarFlowFeces = this.fFecesSolidProduction / this.oMT.afMolarMass(this.oMT.tiN2I.C42H69O13N5);
            tfMassConsumptionFeces.Fat          =     fMolarFlowFeces * this.oMT.afMolarMass(this.oMT.tiN2I.C16H32O2);
            tfMassConsumptionFeces.Protein      = 5 * fMolarFlowFeces * this.oMT.afMolarMass(this.oMT.tiN2I.C4H5ON);
            tfMassConsumptionFeces.Carbohydrate =     fMolarFlowFeces * this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6);
            
            tfEnergyEquivalentFeces.Fat             = tfMassConsumptionFeces.Fat * this.tfEnergyContent.Fat;
            tfEnergyEquivalentFeces.Protein         = tfMassConsumptionFeces.Protein * this.tfEnergyContent.Protein;
            tfEnergyEquivalentFeces.Carbohydrate    = tfMassConsumptionFeces.Carbohydrate * this.tfEnergyContent.Carbohydrate;
            fEnergyEquivalenFecesTotal = (tfEnergyEquivalentFeces.Fat + tfEnergyEquivalentFeces.Protein + tfEnergyEquivalentFeces.Carbohydrate);
            
            this.fBasicFoodEnergyDemand = this.fBasicFoodEnergyDemand - (fEnergyEquivalenFecesTotal * 86400);
            
            % Based on the basic food demand and the current respiratory
            % coefficient the digestion manipulator can calculate the
            % current oxygen demand and co2 production. To calculate the
            % respective exercise O2 consumption the table for VO2max from
            % HDIH 2010 table 5.2-1 on page 91 for the 90th percentile is used
            
            if bMale
                if fAge < 30
                    this.fVO2_max = 51.4;
                    
                elseif fAge < 40
                    this.fVO2_max = 50.4;
                    
                elseif fAge < 50
                    this.fVO2_max = 48.2;
                    
                elseif fAge < 60
                    this.fVO2_max = 45.3;
                    
                elseif fAge >= 60
                    this.fVO2_max = 42.5;
                    
                end
            else
                if fAge < 30
                    this.fVO2_max = 44.2;
                    
                elseif fAge < 40
                    this.fVO2_max = 41.0;
                    
                elseif fAge < 50
                    this.fVO2_max = 39.5;
                    
                elseif fAge < 60
                    this.fVO2_max = 35.2;
                    
                elseif fAge >= 60
                    this.fVO2_max = 35.2;
                    
                end
            end
            
            this.fHumanMass     = this.iNumberOfHumans * fHumanMass;
            this.fHumanHeight   = fHumanHeight;
            
            this.txCrewPlaner = txCrewPlaner;
            
            % Current state the human is in, 0 means sleep, 1 means nominal, 2
            % means exercise first 15 Minutes, 3 is exercise from minute 15
            % onwards, 4 is the first 15 minutes of recovery, 5,6,7 are
            % respectivly the next 15 minute increments of recovery
            %
            % Please note, you must shift the iState property by +1 to get the
            % correct state (since 0 for sleep seemed logical):
            % this.csStates{this.iState + 1}
            this.csStates = {'sleep', 'nominal', 'exercise015', 'exercise1530', 'recovery015', 'recovery1530', 'recovery3045', 'recovery4560'};
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                   BVAD Metabolic Values                 %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %the model for the crew does not have a mass balance since
            %there is no food taken into account. Also a lot of the actual
            %processes are severly simplified.
            %all values taken from NASA/TP-2015–218570 "Life Support
            %Baseline Values and Assumptions Document"
            
            %these are multiple states for the human metabolic rate taken
            %from table 3.22 in the above mentioned document saved into a
            %struct to allow easy access:
            this.tHumanMetabolicValues = struct();
            %all values converted to SI units
            %sleeping state
            this.tHumanMetabolicValues.sleep.fDryHeat = 224*1000/3600;
            this.tHumanMetabolicValues.sleep.fWaterVapor = (6.3*10^-4)/60;
            this.tHumanMetabolicValues.sleep.fSweat = 0;
            this.tHumanMetabolicValues.sleep.fO2Consumption = (3.6*10^-4)/60;
            this.tHumanMetabolicValues.sleep.fCO2Production = (4.55*10^-4)/60;
            %nominal state
            this.tHumanMetabolicValues.nominal.fDryHeat = 329*1000/3600;
            this.tHumanMetabolicValues.nominal.fWaterVapor = (11.77*10^-4)/60;
            this.tHumanMetabolicValues.nominal.fSweat = 0;
            this.tHumanMetabolicValues.nominal.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.nominal.fCO2Production = (7.2*10^-4)/60;
            %nominal state
            this.tHumanMetabolicValues.harvest.fDryHeat = 329*1000/3600;
            this.tHumanMetabolicValues.harvest.fWaterVapor = (11.77*10^-4)/60;
            this.tHumanMetabolicValues.harvest.fSweat = 0;
            this.tHumanMetabolicValues.harvest.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.harvest.fCO2Production = (7.2*10^-4)/60;
            %exercise minute 0-15
            this.tHumanMetabolicValues.exercise015.fDryHeat = 514*1000/3600;
            this.tHumanMetabolicValues.exercise015.fWaterVapor = (46.16*10^-4)/60;
            this.tHumanMetabolicValues.exercise015.fSweat = (1.56*10^-4)/60;
            this.tHumanMetabolicValues.exercise015.fO2Consumption = (39.40*10^-4)/60;
            this.tHumanMetabolicValues.exercise015.fCO2Production = (49.85*10^-4)/60;
            %exercise minute 15-30
            this.tHumanMetabolicValues.exercise1530.fDryHeat = 624*1000/3600;
            this.tHumanMetabolicValues.exercise1530.fWaterVapor = (128.42*10^-4)/60;
            this.tHumanMetabolicValues.exercise1530.fSweat = (33.52*10^-4)/60;
            this.tHumanMetabolicValues.exercise1530.fO2Consumption = (39.40*10^-4)/60;
            this.tHumanMetabolicValues.exercise1530.fCO2Production = (49.85*10^-4)/60;
            %recovery minute 0-15
            this.tHumanMetabolicValues.recovery015.fDryHeat = 568*1000/3600;
            this.tHumanMetabolicValues.recovery015.fWaterVapor = (83.83*10^-4)/60;
            this.tHumanMetabolicValues.recovery015.fSweat = (15.16*10^-4)/60;
            this.tHumanMetabolicValues.recovery015.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery015.fCO2Production = (7.2*10^-4)/60;
            %recovery minute 15-30
            this.tHumanMetabolicValues.recovery1530.fDryHeat = 488*1000/3600;
            this.tHumanMetabolicValues.recovery1530.fWaterVapor = (40.29*10^-4)/60;
            this.tHumanMetabolicValues.recovery1530.fSweat = (0.36*10^-4)/60;
            this.tHumanMetabolicValues.recovery1530.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery1530.fCO2Production = (7.2*10^-4)/60;
            %recovery minute 30-45
            this.tHumanMetabolicValues.recovery3045.fDryHeat = 466*1000/3600;
            this.tHumanMetabolicValues.recovery3045.fWaterVapor = (27.44*10^-4)/60;
            this.tHumanMetabolicValues.recovery3045.fSweat = (0*10^-4)/60;
            this.tHumanMetabolicValues.recovery3045.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery3045.fCO2Production = (7.2*10^-4)/60;
            %recovery minute 45-60
            this.tHumanMetabolicValues.recovery4560.fDryHeat = 455*1000/3600;
            this.tHumanMetabolicValues.recovery4560.fWaterVapor = (20.4*10^-4)/60;
            this.tHumanMetabolicValues.recovery4560.fSweat = (0*10^-4)/60;
            this.tHumanMetabolicValues.recovery4560.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery4560.fCO2Production = (7.2*10^-4)/60;
            
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Temperature used in the human model for the phases. This must
            % be different from the normal temperature a human would have
            % (about 38°C) because the heat realease is modelles seperatly.
            % For example if the CO2 the human released had a temperature
            % of 38°C while the cabin has 22°C that would result in an
            % additional heat flow from the human to the cabin. But since a
            % dedicated calculation for the heat release of the humans is
            % used this hast to be omitted for a correct calculation!
            fHumanTemperature = 298.15; %~25°C
                       
            
            %% Creating the stores and phases with init masses
            % Init masses and volumes
            tfMassesFeces = struct('Feces', 0.1);
            fVolumeFeces = 0.1;

            tfMassesUrine = struct('Urine', 1.6); 
            fVolumeUrine = 0.1;
            
            tfMassesStomach = struct(); 
            fVolumeStomach = 0.1;
            
            % for fat, proteins and carbohydrates the human initially has 7
            % day worth of these stored, based on the defined initial food
            % composition
            fFatMass            = this.iNumberOfHumans * 7 * this.trInitialFoodComposition.Fat          * this.fBasicFoodEnergyDemand / this.tfEnergyContent.Fat;
            fProteinMass        = this.iNumberOfHumans * 7 * this.trInitialFoodComposition.Protein      * this.fBasicFoodEnergyDemand / this.tfEnergyContent.Protein;
            fCarbohydrateMass   = this.iNumberOfHumans * 7 * this.trInitialFoodComposition.Carbohydrate * this.fBasicFoodEnergyDemand / this.tfEnergyContent.Carbohydrate;
            
            % not an actual representation of the masses inside the human,
            % only the masses that humans consume/produce
            tfMassesHuman = struct('O2', 1, 'CO2', 1, 'H2O', 2, 'C4H5ON', fProteinMass, 'C16H32O2', fFatMass, 'C6H12O6', fCarbohydrateMass, 'C42H69O13N5', 0.032,  'C2H6O2N2', 0.059);
            fVolumeHuman = 0.1; 
            fVolumeLung = 0.05;

            % Creating Stores
            matter.store(this, 'Human', fVolumeHuman + fVolumeUrine + fVolumeFeces + fVolumeLung + fVolumeStomach ); 

            oHumanPhase = matter.phases.mixture(this.toStores.Human, 'HumanPhase', 'solid', tfMassesHuman, fHumanTemperature, 101325); 
            
            this.afInitialMassHuman = oHumanPhase.afMass;
            
            matter.procs.exmes.mixture(oHumanPhase, 'Urine_Out_Internal'); 
            matter.procs.exmes.mixture(oHumanPhase, 'Feces_Out_Internal');  
            matter.procs.exmes.mixture(oHumanPhase, 'CO2_Out_Internal'); 
            matter.procs.exmes.mixture(oHumanPhase, 'O2_In_Internal'); 
            matter.procs.exmes.mixture(oHumanPhase, 'Humidity_Out_Internal'); 
            
            matter.procs.exmes.mixture(oHumanPhase, 'Food_In_Internal');
            
            matter.procs.exmes.mixture(oHumanPhase, 'Potable_Water_In'); 
            
            % add a manip that converts food to metabolism products
            components.matter.Manips.ManualManipulator(this, 'DigestionSimulator', oHumanPhase);
            
            oStomachPhase = matter.phases.mixture(this.toStores.Human, 'Stomach', 'liquid', tfMassesStomach, fHumanTemperature, 101325);
            
            matter.procs.exmes.mixture(oStomachPhase, 'Food_In');
            matter.procs.exmes.mixture(oStomachPhase, 'Food_Out_Internal');
            
            % the food input of the human can be pretty much anything
            % edible (tomatoes, wheat etc.) this converter will break into
            % down into the basic components (proteins, fat, carbohydrates,
            % water)
            components.matter.Manips.ManualManipulator(this, 'FoodConverter', oStomachPhase);
            
            % airphase helper
            % defined co2 level and relative humidity
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Human, fVolumeLung, struct('CO2', 0.0062),  fHumanTemperature, 0.4, 101325);
            oAirPhase = matter.phases.flow.gas(this.toStores.Human, 'Air', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            matter.procs.exmes.gas(oAirPhase, 'O2_Out');
            matter.procs.exmes.gas(oAirPhase, 'CO2_In');
            matter.procs.exmes.gas(oAirPhase, 'Humidity_In');
            matter.procs.exmes.gas(oAirPhase, 'Air_In'); %IF
            matter.procs.exmes.gas(oAirPhase, 'Air_Out'); %IF
            
            % Urine Phase
            oBladderPhase = matter.phases.mixture(this.toStores.Human, 'Urine', 'liquid', tfMassesUrine, fHumanTemperature, 101325); 
            this.afInitialMassUrine = oBladderPhase.afMass;
            
            matter.procs.exmes.mixture(oBladderPhase, 'Urine_Out');
            matter.procs.exmes.mixture(oBladderPhase, 'Urine_In_Internal');
            
            % Feces phase
            oFecesPhase = matter.phases.mixture( this.toStores.Human, 'Feces', 'solid', tfMassesFeces, fHumanTemperature, 101325); 
            this.afInitialMassFeces = oFecesPhase.afMass;
            
            matter.procs.exmes.mixture(oFecesPhase, 'Feces_In_Internal');
            matter.procs.exmes.mixture(oFecesPhase, 'Feces_Out');
            
            % Add p2p procs that remove the produced materials from the process
            % phase and add O2 to it
            % components.matter.P2Ps.ConstantMassP2P(this,   this.toStores.Human, 'Food_P2P',            'Stomach.Food_Out_Internal',         'HumanPhase.Food_In_Internal', {'C4H5ON', 'C16H32O2', 'C6H12O6', 'H2O'}, 1);
            components.matter.P2Ps.ManualP2P(this.toStores.Human, 'Food_P2P',            'Stomach.Food_Out_Internal',         'HumanPhase.Food_In_Internal');
            
            components.matter.P2Ps.ManualP2P(this.toStores.Human, 'CO2_P2P',             'HumanPhase.CO2_Out_Internal',        'Air.CO2_In');
            components.matter.P2Ps.ManualP2P(this.toStores.Human, 'O2_P2P',              'Air.O2_Out',                         'HumanPhase.O2_In_Internal');
            components.matter.P2Ps.ManualP2P(this.toStores.Human, 'CrewHumidityProduction',   'HumanPhase.Humidity_Out_Internal',	'Air.Humidity_In');
            components.matter.P2Ps.ManualP2P(this.toStores.Human, 'Urine_Removal',       'HumanPhase.Urine_Out_Internal',      'Urine.Urine_In_Internal');
            components.matter.P2Ps.ManualP2P(this.toStores.Human, 'Feces_Removal',       'HumanPhase.Feces_Out_Internal',      'Feces.Feces_In_Internal');
            
            %% adding the interface to the habitat            
            matter.branch(this, 'Human.Air_Out',            {}, 'Air_Out'             ,'Air_Out');
            matter.branch(this, 'Human.Air_In',             {}, 'Air_In'              ,'Air_In');
            matter.branch(this, 'Human.Food_In',            {}, 'Food_In'             ,'Food_In');
            matter.branch(this, 'Human.Feces_Out',          {}, 'Feces_Out'           ,'Feces_Out');
            matter.branch(this, 'Human.Urine_Out',          {}, 'Urine_Out'           ,'Urine_Out');
            matter.branch(this, 'Human.Potable_Water_In',	{}, 'Potable_Water_In'    ,'Potable_Water_In');
            
         end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            % to prevent small time steps because the food is at a
            % different temperature than the human, we set a constant
            % temperature heat source for the stomach
            oConstantTemperatureHeatSource = components.thermal.heatsources.ConstantTemperature('StomachConstantTemperature');
            this.toStores.Human.toPhases.Stomach.oCapacity.addHeatSource(oConstantTemperatureHeatSource);
            oConstantTemperatureHeatSource = components.thermal.heatsources.ConstantTemperature('HumanConstantTemperature');
            this.toStores.Human.toPhases.HumanPhase.oCapacity.addHeatSource(oConstantTemperatureHeatSource);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.Potable_Water_In);
            solver.matter.manual.branch(this.toBranches.Feces_Out);
            solver.matter.manual.branch(this.toBranches.Urine_Out);
            solver.matter.manual.branch(this.toBranches.Air_In);
            
            solver.matter.residual.branch(this.toBranches.Air_Out);
            
            if ~isempty(this.requestFood)
                oResidual = solver.matter.residual.branch(this.toBranches.Food_In);
                oResidual.setPositiveFlowDirection(false);
            end
            
            tTimeStepProperties.fFixedTimeStep = this.fTimeStep;
            
            % set time steps. The phases use the same time step as the
            % system for a fixed time step. The time step calculation
            % prevents mass balance errors and unphyiscal properties also
            % for fixed time steps
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    
                    oPhase.setTimeStepProperties(tTimeStepProperties);
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            % In the stomach the food conversion can result in generated
            % mass errors, but since only occurs three times a day setting
            % the allowed value of this to 0 for the stomach does not slow
            % down the simulation significantly, but reduces the mass
            % errors a lot.
            tTimeStepProperties.fMassErrorLimit = 0;
            this.toStores.Human.toPhases.Stomach.setTimeStepProperties(tTimeStepProperties);
                
            this.setThermalSolvers();
            
            this.setState(1);
            this.setTimeStep(this.fTimeStep);
        end
        
        function setIfFlows(this, varargin)
            % This function connects the system and subsystem level branches with
            % each other. It uses the connectIF function provided by the
            % matter.container class
            this.connectIF('Air_Out' ,          varargin{1});
            this.connectIF('Air_In' ,           varargin{2});
            this.connectIF('Potable_Water_In',  varargin{3}); 
            this.connectIF('Food_In',           varargin{4});
            this.connectIF('Feces_Out',         varargin{5});
            this.connectIF('Urine_Out',         varargin{6});
            
            %% Add a way for the human to release heat into the cabin
            this.oHeatSource = thermal.heatsource([this.sName, '_Heater'], 0);
            this.toBranches.Air_In.coExmes{2}.oPhase.oCapacity.addHeatSource(this.oHeatSource);
        end
        
        function bindRequestFoodFunction(this, requestFood)
            this.requestFood = requestFood;
        end

    end
   
    methods (Access = protected)
        
        function setState(this, iState)
            
            this.iState = iState;
            this.fStateStartTime = this.oTimer.fTime;
            
            afHumidityP2PFlowRates = zeros(1,this.oMT.iSubstances);
            afHumidityP2PFlowRates(this.oMT.tiN2I.H2O) = this.tHumanMetabolicValues.(this.csStates{iState + 1}).fWaterVapor + this.tHumanMetabolicValues.(this.csStates{iState + 1}).fSweat;
            this.toStores.Human.toProcsP2P.CrewHumidityProduction.setFlowRate(this.iNumberOfHumans .* afHumidityP2PFlowRates);
            
            % TO DO: find dynamic way to calculate human thermal heat
            % release simply
            this.oHeatSource.setHeatFlow(this.iNumberOfHumans * this.tHumanMetabolicValues.(this.csStates{iState + 1}).fDryHeat)
            
        end
        
        function exec(this, ~)
            exec@vsys(this);
            
            this.fLastExec = this.oTimer.fTime;
            
            %% Restroom
            % kept simple, similar to drinking, whenever the bladder
            % reaches a mass of 0.5 kg the human visits the toilet, on
            % average this happens ~3 times a day
            % Here the fixed time step results in something quite strange.
            % Since the update of the phase masses occurs in the post tick
            % logic, the phase mass is not yet updated when the 60 seconds
            % timestep of this exec have passed. This means the exec
            % actually sees the same amount of Urine in the phase for two
            % timesteps. Therefore, to prevent it from accidentially
            % activating this logic due to an "old" mass value, we also
            % check the bMassTransferActive property of the solver!
            if this.toStores.Human.toPhases.Urine.fMass > ((0.5 * this.iNumberOfHumans) + sum(this.afInitialMassUrine)) && ~this.toBranches.Urine_Out.oHandler.bMassTransferActive
                this.toBranches.Urine_Out.oHandler.setMassTransfer(0.5  * this.iNumberOfHumans, 60);
            end
            
            % for feces a similar logic applies with 132 g of feces
            % necessary for the human to got to the restroom, in general
            % this occurs about once per day. In the event that the
            % restroom visit is because of the feces mass, the human will
            % still empty the bladder
            if this.toStores.Human.toPhases.Feces.fMass > ((0.132 * this.iNumberOfHumans)  + sum(this.afInitialMassFeces)) && ~this.toBranches.Feces_Out.oHandler.bMassTransferActive
                this.toBranches.Feces_Out.oHandler.setMassTransfer(0.132 * this.iNumberOfHumans, 360);
            end
            
            %% Scheduler
            % this handles the different events and defined in the crew
            % schedule (like sleep, exercise etc)
            
            if (this.oTimer.fTime >= this.txCrewPlaner.ctEvents{this.iEvent}.Start) && ~this.txCrewPlaner.ctEvents{this.iEvent}.Started
                
                this.txCrewPlaner.ctEvents{this.iEvent}.Started = true;
                
                this.setState(this.txCrewPlaner.ctEvents{this.iEvent}.State);
                
            end
            
            if this.oTimer.fTime >= this.txCrewPlaner.ctEvents{this.iEvent}.End && ~this.txCrewPlaner.ctEvents{this.iEvent}.Ended

                this.txCrewPlaner.ctEvents{this.iEvent}.Ended = true;

                % Checks if the initialised event was an excercise, if
                % so the human does not go to nominal state, but into a
                % recovery state
                if this.txCrewPlaner.ctEvents{this.iEvent}.State == 2
                    this.setState(4);
                else
                    this.setState(1);
                end
                this.iEvent = this.iEvent + 1;
            end
                
            % Automatically move the crew member to the next state in case
            % of excerise or recovery states
            if this.iState == 2 && (this.oTimer.fTime - this.fStateStartTime) > 900
                this.setState(3);
                
            elseif this.iState >= 4 && (this.oTimer.fTime - this.fStateStartTime) > 900
                if (this.iState + 1) == 8
                    this.setState(1);
                else
                    this.setState(this.iState + 1);
                end
            end
            
            %% Respiratory Coefficient
            
            tfFoodMass.Fat              = this.toStores.Human.toPhases.HumanPhase.afMass(this.oMT.tiN2I.C16H32O2);
            tfFoodMass.Protein          = this.toStores.Human.toPhases.HumanPhase.afMass(this.oMT.tiN2I.C4H5ON);
            tfFoodMass.Carbohydrate     = this.toStores.Human.toPhases.HumanPhase.afMass(this.oMT.tiN2I.C6H12O6);
            
            tfTotalEnergy.Fat           = tfFoodMass.Fat * this.tfEnergyContent.Fat;
            tfTotalEnergy.Protein       = tfFoodMass.Protein * this.tfEnergyContent.Protein;
            tfTotalEnergy.Carbohydrate  = tfFoodMass.Carbohydrate * this.tfEnergyContent.Carbohydrate;
            
            
            fTotalEnergy = tfTotalEnergy.Fat + tfTotalEnergy.Protein + tfTotalEnergy.Carbohydrate;
            
            % calculates what percentage of the respective nutrition covers
            % the energy demand
            tfPercent.Fat          = tfTotalEnergy.Fat / fTotalEnergy;
            tfPercent.Protein      = tfTotalEnergy.Protein / fTotalEnergy;
            tfPercent.Carbohydrate = tfTotalEnergy.Carbohydrate / fTotalEnergy;
            
            % from these percentages the respiratory coefficient can be
            % calculated assuming the human consumes 1 J of energy, so
            % these values are the mol consumed of each nutrient to produce
            % 1 J of energy:
            tfMolarConsumptionPerJoule.Fat            = (tfPercent.Fat / this.tfEnergyContent.Fat) / this.oMT.afMolarMass(this.oMT.tiN2I.C16H32O2);
            tfMolarConsumptionPerJoule.Protein        = (tfPercent.Protein / this.tfEnergyContent.Protein) / this.oMT.afMolarMass(this.oMT.tiN2I.C4H5ON);
            tfMolarConsumptionPerJoule.Carbohydrate   = (tfPercent.Carbohydrate / this.tfEnergyContent.Carbohydrate) / this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6);
            
            % C16H32O2 (fats)          + 23 O2     =    16 CO2 + 16H20
            % 2 C4H5ON  (protein)      + 7  O2     =    C2H6O2N2 (urine solids) + 6 CO2 + 2H2O 
            % C6H12O6 (carbohydrates)  + 6  O2     =    6 CO2 + 6H2O
            this.fRespiratoryCoefficient = (tfMolarConsumptionPerJoule.Fat * 16 + tfMolarConsumptionPerJoule.Protein * 3   + tfMolarConsumptionPerJoule.Carbohydrate * 6) /...
                                           (tfMolarConsumptionPerJoule.Fat * 23 + tfMolarConsumptionPerJoule.Protein * 3.5 + tfMolarConsumptionPerJoule.Carbohydrate * 6);
            
            % Based on the Respiratory coefficient and according to
            % E. Hofmann, "Funktionelle Biochemie des Menschen" © Springer
            % Fachmedien Wiesbaden 1979 it is possible to calculate a
            % caloric value for oxygen (the amount of energy released per
            % unit of oxygen)
            % Following the calculation from above for 1 J of energy a
            % total of x kg of oxygen is consumed, and 1/ this is the
            % amount of energy that can be released per kg of oxygen. It
            % therefore has the unit J/kg
            this.fCaloricValueOxygen = 1 /  (this.oMT.afMolarMass(this.oMT.tiN2I.O2) *(tfMolarConsumptionPerJoule.Fat * 23  +  tfMolarConsumptionPerJoule.Protein * 3.5  + tfMolarConsumptionPerJoule.Carbohydrate * 6 ));
            
            
            %% Respiration
            
            fBasicDailyOxygenDemand = this.fBasicFoodEnergyDemand / this.fCaloricValueOxygen; % kg/d
            
            % sleep is ~ 8h per day. This means that sleep accounts for
            % 1/3 of the time per day with 0.6338 times the nominal oxygen
            % consumption:
            %
            % fBasicDailyOxygenDemand = fOxygenDemandSleep * 8 * 3600 + fOxygenDemandNominal * 16 * 3600;
            %
            % according to BVAD 2015 table 3.22 on page 45 oxygen demand
            % during sleep is 63.38% of the oxygen demand during nominal:
            %
            % fBasicDailyOxygenDemand = fOxygenDemandNominal * (0.6338 * 8 * 3600 + 16 * 3600);
            %
            % Therefore:
            this.fOxygenDemandNominal    = fBasicDailyOxygenDemand / (0.6338 * 8 * 3600 + 16 * 3600);   % kg/s
            this.fOxygenDemandSleep      = 0.6338 * this.fOxygenDemandNominal;      % kg/s
            
            if this.iState == 0
                % sleeping
                this.fOxygenDemand = this.fOxygenDemandSleep;
                this.fVO2_current = (this.fOxygenDemandSleep / this.oMT.afMolarMass(this.oMT.tiN2I.O2)) * 22.4 * 1000 * 60 / this.fHumanMass;
                
            elseif this.iState == 2 || this.iState == 3
                % excersice
                %
                % fPercentVO2_max must be defined in the scheduler for the
                % exercise period!
                this.fVO2_current = this.txCrewPlaner.ctEvents{this.iEvent}.VO2_percent * this.fVO2_max; % ml/kg/min
                this.fOxygenDemand = ((this.fVO2_current/1000/60) / 22.4) * this.oMT.afMolarMass(this.oMT.tiN2I.O2) * this.fHumanMass;
                
            else
                % nominal
                this.fOxygenDemand = this.fOxygenDemandNominal;
                this.fVO2_current = (this.fOxygenDemandNominal / this.oMT.afMolarMass(this.oMT.tiN2I.O2)) * 22.4 * 1000 * 60 / this.fHumanMass;
            end
            
            %% Food Conversion
            oStomachPhase = this.toStores.Human.toPhases.Stomach;
            afResolvedMass = this.oMT.resolveCompoundMass(oStomachPhase.afMass, oStomachPhase.arCompoundMass);
            
            fFoodConversionTimeStep = this.fTimeStep * 2;
            csFood = fieldnames(this.oMT.ttxNutrientData);
            afFoodConversionFlowRates = zeros(1,this.oMT.iSubstances);
            
            % The simplified human model does not account for other
            % components of the food aside from Protein, Fat, Carbohdyrates
            % and Ash (which represents the mass that remains if the
            % food would be burned, it represents all minerals in the
            % food which are necessary nutrients but are not part of
            % the energy balance)
            afFoodConversionFlowRates(this.oMT.tiN2I.C6H12O6)   = (afResolvedMass(this.oMT.tiN2I.C6H12O6) - oStomachPhase.afMass(this.oMT.tiN2I.C6H12O6))   / fFoodConversionTimeStep;
            % Note that the simplified human model represents fats as
            % C16H32O2, while the detailed human model uses C51H98O6!
            afFoodConversionFlowRates(this.oMT.tiN2I.C16H32O2)  = (afResolvedMass(this.oMT.tiN2I.C51H98O6) - oStomachPhase.afMass(this.oMT.tiN2I.C16H32O2)) / fFoodConversionTimeStep;
            % Note that the simplified human model represents proteins as
            % C4H5ON, while the detailed human model uses C3H7NO2!
            afFoodConversionFlowRates(this.oMT.tiN2I.C4H5ON)    = (afResolvedMass(this.oMT.tiN2I.C3H7NO2) - oStomachPhase.afMass(this.oMT.tiN2I.C4H5ON))     / fFoodConversionTimeStep;

            afFoodConversionFlowRates(this.oMT.tiN2I.H2O)       = (afResolvedMass(this.oMT.tiN2I.H2O) - oStomachPhase.afMass(this.oMT.tiN2I.H2O))           / fFoodConversionTimeStep;
            
            
            for iFood = 1:length(csFood)
                sFood = csFood{iFood};
                
                afFoodConversionFlowRates(this.oMT.tiN2I.(sFood)) = - oStomachPhase.afMass(this.oMT.tiN2I.(sFood)) / fFoodConversionTimeStep;
            end
            
            % Ash is represented as Carbon
            % Since we do not want to model all the minerals etc which are
            % modelled in the food stuff, we simplify it to combine all
            % remaining entries into ash or C. Since we so far only
            % converted parts of the food composition into the relevant
            % things, but also subtracted the total food flowrates that are
            % converted, we can simply use the sum over the current food
            % conversion flowrates to get this.
            afFoodConversionFlowRates(this.oMT.tiN2I.C)         = - sum(afFoodConversionFlowRates);

            
            oStomachPhase.toManips.substance.setFlowRate(afFoodConversionFlowRates);
            
            afP2PFoodFlowRate = afFoodConversionFlowRates;
            afP2PFoodFlowRate(afP2PFoodFlowRate < 0) = 0;
            
            this.toStores.Human.toProcsP2P.Food_P2P.setFlowRate(afP2PFoodFlowRate);
            
            %% Digestion
            
            % the current energy demand is now calculated based on the
            % current oxygen demand (which depends on the state of the crew
            this.fCurrentEnergyDemand = this.fOxygenDemand * this.fCaloricValueOxygen; % J/s
            
            % this equation calculates the additional energy demand the
            % human has because of exercising
            if this.iState == 2 || this.iState == 3
                this.fAdditionalFoodEnergyDemand = this.fAdditionalFoodEnergyDemand + ((this.fOxygenDemand - this.fOxygenDemandNominal) * this.fTimeStep * this.fCaloricValueOxygen);
            end
            
            % Feces composition is assumed to 50% protein, 25%
            % carbohydrates and 25% fat according to "MASS BALANCES FOR A
            % BIOLOGICAL LIFE SUPPORT SYSTEM SIMULATION MODEL", Tyler Volk
            % and John D. Rummel, 1987. This results in the following
            % chemical reaction:            
            % 5 C4H5ON + C6H12O6 + C16H32O2 = C42H69O13N5 (feces solids composition)
            fMolarFlowFeces = this.fFecesSolidProduction / this.oMT.afMolarMass(this.oMT.tiN2I.C42H69O13N5);
            tfMassConsumptionFeces.Fat          =     fMolarFlowFeces * this.oMT.afMolarMass(this.oMT.tiN2I.C16H32O2);
            tfMassConsumptionFeces.Protein      = 5 * fMolarFlowFeces * this.oMT.afMolarMass(this.oMT.tiN2I.C4H5ON);
            tfMassConsumptionFeces.Carbohydrate =     fMolarFlowFeces * this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6);
            
            % calculates the energy equivalency of the feces production
            tfEnergyEquivalentFeces.Fat             = tfMassConsumptionFeces.Fat * this.tfEnergyContent.Fat;
            tfEnergyEquivalentFeces.Protein         = tfMassConsumptionFeces.Protein * this.tfEnergyContent.Protein;
            tfEnergyEquivalentFeces.Carbohydrate    = tfMassConsumptionFeces.Carbohydrate * this.tfEnergyContent.Carbohydrate;
            fEnergyEquivalenFecesTotal = (tfEnergyEquivalentFeces.Fat + tfEnergyEquivalentFeces.Protein + tfEnergyEquivalentFeces.Carbohydrate);
            
            % the mass for the feces production also has to be replenished
            % by food --> added as additional energy demand
            this.fAdditionalFoodEnergyDemand = this.fAdditionalFoodEnergyDemand + fEnergyEquivalenFecesTotal * this.fTimeStep;
            
            % Previously the energy for the feces was also considered here,
            % but that results in a higher mass consumption for these
            % nutrients and also a higher CO2 production etc. So that was
            % wrong
            tfMolarConsumption.Fat            = this.fCurrentEnergyDemand * tfMolarConsumptionPerJoule.Fat;
            tfMolarConsumption.Protein        = this.fCurrentEnergyDemand * tfMolarConsumptionPerJoule.Protein;
            tfMolarConsumption.Carbohydrate   = this.fCurrentEnergyDemand * tfMolarConsumptionPerJoule.Carbohydrate;
            
            tfMassConsumption.Fat             = tfMolarConsumption.Fat          * this.oMT.afMolarMass(this.oMT.tiN2I.C16H32O2);
            tfMassConsumption.Protein         = tfMolarConsumption.Protein      * this.oMT.afMolarMass(this.oMT.tiN2I.C4H5ON);
            tfMassConsumption.Carbohydrate    = tfMolarConsumption.Carbohydrate * this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6);
            
            % C16H32O2 (fats)          + 23 O2     =    16 CO2 + 16H20
            % 2 C4H5ON  (protein)      + 7  O2     =    C2H6O2N2 (urine solids) + 6 CO2 + 2H2O 
            % C6H12O6 (carbohydrates)  + 6  O2     =    6 CO2 + 6 H2O
            this.fCO2Production             = this.oMT.afMolarMass(this.oMT.tiN2I.CO2)      * (tfMolarConsumption.Fat * 16 + tfMolarConsumption.Protein * 3 + tfMolarConsumption.Carbohydrate * 6);
            this.fMetabolicWaterProduction  = this.oMT.afMolarMass(this.oMT.tiN2I.H2O)      * (tfMolarConsumption.Fat * 16 + tfMolarConsumption.Protein     + tfMolarConsumption.Carbohydrate * 6);
            this.fUrineSolidsProduction     = this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2) *  tfMolarConsumption.Protein * 0.5;
            
            % fO2ConsCheck = this.oMT.afMolarMass(this.oMT.tiN2I.O2)      * (tfMolarConsumption.Fat * 23 + tfMolarConsumption.Protein * 3.5 + tfMolarConsumption.Carbohydrate * 6);
            
            afManipulatorFlowRates = zeros(1,this.oMT.iSubstances);
            afManipulatorFlowRates(this.oMT.tiN2I.CO2)          = this.fCO2Production;
            
            afManipulatorFlowRates(this.oMT.tiN2I.C16H32O2)    	= - (tfMassConsumption.Fat          + tfMassConsumptionFeces.Fat);
            afManipulatorFlowRates(this.oMT.tiN2I.C4H5ON)     	= - (tfMassConsumption.Protein      + tfMassConsumptionFeces.Protein);
            afManipulatorFlowRates(this.oMT.tiN2I.C6H12O6)    	= - (tfMassConsumption.Carbohydrate + tfMassConsumptionFeces.Carbohydrate);
            afManipulatorFlowRates(this.oMT.tiN2I.O2)           = -  this.fOxygenDemand;
            
            % According to BVAD for 0.059 kg of solid urine 1.6 kg of urine water
            fUrineWater                                         = (1.6 / 0.059) * this.fUrineSolidsProduction;
            afManipulatorFlowRates(this.oMT.tiN2I.Urine)        = this.fUrineSolidsProduction + fUrineWater;
            
            % According to BVAD for 0.032 kg of solid feces 0.1 kg of water
            fFecesWater                                         = (0.1 / 0.032) * this.fFecesSolidProduction;
            afManipulatorFlowRates(this.oMT.tiN2I.Feces)        = this.fFecesSolidProduction + fFecesWater;
            
            afManipulatorFlowRates(this.oMT.tiN2I.H2O)          = this.fMetabolicWaterProduction - fUrineWater - fFecesWater;
            % Since we define compound masses we have to specify what
            % components contribute to what compound mass:
            aarFlowsToCompound = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            aarFlowsToCompound(this.oMT.tiN2I.Urine, this.oMT.tiN2I.H2O)         = fUrineWater / (this.fUrineSolidsProduction + fUrineWater);
            aarFlowsToCompound(this.oMT.tiN2I.Urine, this.oMT.tiN2I.C2H6O2N2)    = this.fUrineSolidsProduction / (this.fUrineSolidsProduction + fUrineWater);
            
            aarFlowsToCompound(this.oMT.tiN2I.Feces, this.oMT.tiN2I.H2O)         = fFecesWater / (this.fFecesSolidProduction + fFecesWater);
            aarFlowsToCompound(this.oMT.tiN2I.Feces, this.oMT.tiN2I.C42H69O13N5) = this.fFecesSolidProduction / (this.fFecesSolidProduction + fFecesWater);
            
            %% Setting of P2P and Manip flowrates
            afCO2P2PFlowRates = zeros(1,this.oMT.iSubstances);
            afCO2P2PFlowRates(this.oMT.tiN2I.CO2) = this.fCO2Production;
            this.toStores.Human.toProcsP2P.CO2_P2P.setFlowRate(afCO2P2PFlowRates);
            
            afO2P2PFlowRates = zeros(1,this.oMT.iSubstances);
            afO2P2PFlowRates(this.oMT.tiN2I.O2) = this.fOxygenDemand;
            this.toStores.Human.toProcsP2P.O2_P2P.setFlowRate(afO2P2PFlowRates);
            
            afUrineP2PFlowRates = zeros(1,this.oMT.iSubstances);
            afUrineP2PFlowRates(this.oMT.tiN2I.Urine) = afManipulatorFlowRates(this.oMT.tiN2I.Urine);
            this.toStores.Human.toProcsP2P.Urine_Removal.setFlowRate(afUrineP2PFlowRates);
            
            afFecesP2PFlowRates = zeros(1,this.oMT.iSubstances);
            afFecesP2PFlowRates(this.oMT.tiN2I.Feces) = afManipulatorFlowRates(this.oMT.tiN2I.Feces);
            this.toStores.Human.toProcsP2P.Feces_Removal.setFlowRate(afFecesP2PFlowRates);
            
            % Set manip flowrate
            this.toStores.Human.toPhases.HumanPhase.toManips.substance.setFlowRate(afManipulatorFlowRates, aarFlowsToCompound);
            
            %% Drinking
            % Logic for drinking is kept simple, if more than 0.5 kg of
            % water are missing from the human, the missing water is
            % consumed be the human model
            fWaterDifference = this.afInitialMassHuman(this.oMT.tiN2I.H2O) - this.toStores.Human.toPhases.HumanPhase.afMass(this.oMT.tiN2I.H2O);
            if fWaterDifference > 0.5  && ~this.toBranches.Potable_Water_In.oHandler.bMassTransferActive
                this.toBranches.Potable_Water_In.oHandler.setMassTransfer(-fWaterDifference, 60);
            end
            
            %% Eating
            % calculate food energy demand for the current meal (assumes
            % 20% of caloric intake during breakfast, 50% during lunch and
            % 30% during dinner, adds the demand from exercise to the first
            % meal that comes up after the exercise). If the mealtimes are
            % not defined in the crew planer the user has to supply the
            % human with food from a seperate logic in the respective
            % simulation that uses the human model
            
            if isfield(this.txCrewPlaner, 'tMealTimes')
                if this.oTimer.fTime >= this.txCrewPlaner.tMealTimes.Breakfast

                    % move the next breakfast time one day ahead
                    this.txCrewPlaner.tMealTimes.Breakfast = this.txCrewPlaner.tMealTimes.Breakfast + 86400;

                    fEnergyDemand = 0.2 * this.fBasicFoodEnergyDemand + this.fAdditionalFoodEnergyDemand;
                    
                    this.requestFood(fEnergyDemand, 5*60);
                    
                    this.fAdditionalFoodEnergyDemand = 0;
                    
                elseif this.oTimer.fTime >= this.txCrewPlaner.tMealTimes.Lunch

                    % move the next Lunch time one day ahead
                    this.txCrewPlaner.tMealTimes.Lunch = this.txCrewPlaner.tMealTimes.Lunch + 86400;

                    fEnergyDemand = 0.5 * this.fBasicFoodEnergyDemand + this.fAdditionalFoodEnergyDemand;
                    
                    this.requestFood(fEnergyDemand, 10*60);
                    
                    this.fAdditionalFoodEnergyDemand = 0;
                    
                elseif this.oTimer.fTime >= this.txCrewPlaner.tMealTimes.Dinner

                    % move the next Dinner time one day ahead
                    this.txCrewPlaner.tMealTimes.Dinner = this.txCrewPlaner.tMealTimes.Dinner + 86400;

                    fEnergyDemand = 0.3 * this.fBasicFoodEnergyDemand + this.fAdditionalFoodEnergyDemand;
                    
                    this.requestFood(fEnergyDemand, 5*60);
                    
                    this.fAdditionalFoodEnergyDemand = 0;
                end
            end
            
            
            %% Other stuff
            % sets the airflowrate into the human to a value that ~4% of
            % the Oxygen in the air is consumed
            this.toBranches.Air_In.oHandler.setFlowRate(- (this.fOxygenDemand/0.04)/this.toBranches.Air_In.coExmes{2}.oPhase.arPartialMass(this.oMT.tiN2I.O2));
        end
    end
end