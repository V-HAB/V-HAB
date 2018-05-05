classdef Human < vsys
    % human model subsystem
    properties (SetAccess = protected, GetAccess = public)
        
        %% FIX Values that do not change during the simulation
        % The basic energy demand from food this human has without
        % excercise
        fBasicFoodEnergyDemand; % in J/(Human and day)
        
        fVO2_max; % ml/kg/min
        
        fHumanMass;
        fHumanHeight;
        
        tfEnergyContent
        
        txCrewPlaner;
        
        trInitialFoodComposition;
        
        afInitialMassHuman;
        
        %% Variables that change during the simulation
        fVO2_current;
        
        fCurrentEnergyDemand; % in J/s
        
        fRespiratoryCoefficient;
        fCaloricValueOxygen;    % J/kg
        
        fOxygenDemand;  % in kg/s
        fCO2Production; % in kg/s
        
        fMetabolicWaterProduction;
        fUrineSolidsProduction;
        
        % Current state the human is in, 0 means sleep, 1 means nominal, 2
        % means exercise
        iState
        
    end
    
    methods
        function this = Human(oParent, sName, bMale, fAge, fHumanMass, fHumanHeight, txCrewPlaner, trInitialFoodComposition)
            
            this@vsys(oParent, sName, 60);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            if nargin > 7
                this.trInitialFoodComposition = trInitialFoodComposition;
            else
                % standard food composition based on the composition
                % suggested in the HDIH on page 2010 488
                this.trInitialFoodComposition.Fat           = 0.3;
                this.trInitialFoodComposition.Protein       = 0.2;
                this.trInitialFoodComposition.Carbohydrate  = 0.5;
            end
            
            % "Chapter 3: Calculation Of The Energy Content Of Foods – Energy
            % Conversion Factors". Food and Agriculture Organization of the
            % United Nations.
            this.tfEnergyContent.Fat          = 37 * 10^6; % J/kg
            this.tfEnergyContent.Protein      = 17 * 10^6; % J/kg
            this.tfEnergyContent.Carbohydrate = 17 * 10^6; % J/kg
            
            % boolean is the easiest way to differentiate between male and
            % female, calculate the basic energy demand
            if bMale
                % Equation for metabolic consumption of a human male
                % according to NASA BVAD TP-2015-218570 page 43
                this.fBasicFoodEnergyDemand = 10^6 * (622 - 9.53 * fAge + 1.25*(15.9 * fHumanMass + 539.6 * fHumanHeight))/(0.238853*10^3);
            else
                % Equation for metabolic consumption of a human female
                % according to NASA BVAD TP-2015-218570 page 43
                this.fBasicFoodEnergyDemand = 10^6 * (354 - 6.91 * fAge + 1.25*(9.36 * fHumanMass + 726 * fHumanHeight))/(0.238853*10^3);
            end
            
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
            
            this.fHumanMass     = fHumanMass;
            this.fHumanHeight   = fHumanHeight;
            
            this.txCrewPlaner = txCrewPlaner;
            
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
            tfMassesFeces = struct('Feces', 0.02);
            fVolumeFeces = 0.1;

            tfMassesUrine = struct('UrineSolids', 0.2, 'H2O', 1); 
            fVolumeUrine = 0.1;
            
            tfMassesStomach = struct(); 
            fVolumeStomach = 0.1;
            
            % for fat, proteins and carbohydrates the human initially has 7
            % day worth of these stored, based on the defined initial food
            % composition
            fFatMass            = 7 * this.trInitialFoodComposition.Fat          * this.fBasicFoodEnergyDemand / this.tfEnergyContent.Fat;
            fProteinMass        = 7 * this.trInitialFoodComposition.Protein      * this.fBasicFoodEnergyDemand / this.tfEnergyContent.Protein;
            fCarbohydrateMass   = 7 * this.trInitialFoodComposition.Carbohydrate * this.fBasicFoodEnergyDemand / this.tfEnergyContent.Carbohydrate;
            
            % not an actual representation of the masses inside the human,
            % only the masses that humans consume/produce
            tfMassesHuman = struct('O2', 1, 'CO2', 1, 'H2O', 2, 'C4H5ON', fProteinMass, 'C16H32O2', fFatMass, 'C6H12O6', fCarbohydrateMass, 'Feces', 0.032,  'UrineSolids', 0.059);
            fVolumeHuman = 0.1; 
            fVolumeLung = 0.05;

            % Creating Stores
            matter.store(this, 'Human', fVolumeHuman + fVolumeUrine + fVolumeFeces + fVolumeLung + fVolumeStomach ); 

            oHumanPhase = matter.phases.mixture(this.toStores.Human, 'HumanPhase', 'liquid', tfMassesHuman, fVolumeHuman, fHumanTemperature, 101325); 
            
            this.afInitialMassHuman = oHumanPhase.afMass;
            
            matter.procs.exmes.mixture(oHumanPhase, 'Urine_Out_Internal'); 
            matter.procs.exmes.mixture(oHumanPhase, 'Feces_Out_Internal');  
            matter.procs.exmes.mixture(oHumanPhase, 'CO2_Out_Internal'); 
            matter.procs.exmes.mixture(oHumanPhase, 'O2_In_Internal'); 
            matter.procs.exmes.mixture(oHumanPhase, 'Humidity_Out_Internal'); 
            
            matter.procs.exmes.mixture(oHumanPhase, 'Food_In_Internal');
            
            matter.procs.exmes.mixture(oHumanPhase, 'Potable_Water_In'); 
            
            % add a manip that converts food to metabolism products
            components.human.DigestionSimulator('DigestionSimulator', oHumanPhase);
            
            
            oStomachPhase = matter.phases.mixture(this.toStores.Human, 'Stomach', 'liquid', tfMassesStomach, fVolumeStomach, fHumanTemperature, 101325);
            
            matter.procs.exmes.mixture(oStomachPhase, 'Food_In');
            matter.procs.exmes.mixture(oStomachPhase, 'Food_Out_Internal');
            
            % the food input of the human can be pretty much anything
            % edible (tomatoes, wheat etc.) this converter will break into
            % down into the basic components (proteins, fat, carbohydrates,
            % water)
            components.human.FoodConverter('FoodConverter', oStomachPhase, 60);
            
            % airphase helper
            % defined co2 level and relative humidity
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Human, fVolumeLung, struct('CO2', 0.0062),  fHumanTemperature, 0.4, 101325);
             
            oAirPhase = matter.phases.gas(this.toStores.Human, 'Air', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            oAirPhase.bFlow = true;
            
            matter.procs.exmes.gas(oAirPhase, 'O2_Out');
            matter.procs.exmes.gas(oAirPhase, 'CO2_In');
            matter.procs.exmes.gas(oAirPhase, 'Humidity_In');
            matter.procs.exmes.gas(oAirPhase, 'Air_In'); %IF
            matter.procs.exmes.gas(oAirPhase, 'Air_Out'); %IF
            
            % Urine Phase
            oBladderPhase = matter.phases.mixture(this.toStores.Human, 'Urine', 'liquid', tfMassesUrine, fVolumeUrine, fHumanTemperature, 101325); 
             
            matter.procs.exmes.mixture(oBladderPhase, 'Urine_Out');
            matter.procs.exmes.mixture(oBladderPhase, 'Urine_In_Internal');
            
            % Feces phase
            oFecesPhase = matter.phases.mixture( this.toStores.Human, 'Feces', 'solid', tfMassesFeces, fVolumeFeces, fHumanTemperature, 101325); 
            
            matter.procs.exmes.mixture(oFecesPhase, 'Feces_In_Internal');
            matter.procs.exmes.mixture(oFecesPhase, 'Feces_Out');
            
            % Add p2p procs that remove the produced materials from the process
            % phase and add O2 to it
            components.P2Ps.ConstantMassP2P(this,   this.toStores.Human, 'CO2_P2P',             'HumanPhase.CO2_Out_Internal',       'Air.CO2_In',                  {'CO2'}, 1);
            components.P2Ps.ConstantMassP2P(this,   this.toStores.Human, 'Food_P2P',            'Stomach.Food_Out_Internal',         'HumanPhase.Food_In_Internal', {'C4H5ON', 'C16H32O2', 'C6H12O6', 'H2O'}, 1);
            components.P2Ps.ConstantMassP2P(this,   this.toStores.Human, 'Urine_Removal',       'HumanPhase.Urine_Out_Internal',    'Urine.Urine_In_Internal',      {'Urine'}, 1);
            components.P2Ps.ConstantMassP2P(this,   this.toStores.Human, 'Feces_Removal',       'HumanPhase.Feces_Out_Internal',    'Feces.Feces_In_Internal',      {'Feces'}, 1);
            
            components.P2Ps.ManualP2P(this,   this.toStores.Human, 'O2_P2P',              'Air.O2_Out',                        'HumanPhase.O2_In_Internal');
            components.P2Ps.ManualP2P(this,   this.toStores.Human, 'CrewH2OProduction',   'HumanPhase.Humidity_Out_Internal',	'Air.Humidity_In');
            
            %% adding the interface to the habitat            
            matter.branch(this, 'Human.Air_Out',            {}, 'Air_Out'             ,'Air_Out');
            matter.branch(this, 'Human.Air_In',             {}, 'Air_In'              ,'Air_In');
            matter.branch(this, 'Human.Food_In',            {}, 'Food_In'             ,'Food_In');
            matter.branch(this, 'Human.Feces_Out',          {}, 'Feces_Out'           ,'Feces_Out');
            matter.branch(this, 'Human.Urine_Out',          {}, 'Urine_Out'           ,'Urine_Out');
            matter.branch(this, 'Human.Potable_Water_In',	{}, 'Potable_Water_In'    ,'Potable_Water_In');
            
           
         end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.Food_In);
            solver.matter.manual.branch(this.toBranches.Potable_Water_In);
            solver.matter.residual.branch(this.toBranches.Feces_Out);
            solver.matter.residual.branch(this.toBranches.Urine_Out);
            solver.matter.manual.branch(this.toBranches.Air_In);    
            solver.matter.residual.branch(this.toBranches.Air_Out);
            
            this.setThermalSolvers();
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
            
        end
        

    end
   
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
            %% Drinking
            % Logic for drinking is kept simple, if more than 0.5 kg of
            % water are missing from the human, the missing water is
            % consumed be the human model
            fWaterDifference = this.afInitialMassHuman(this.oMT.tiN2I.H2O) - this.toStores.Human.toPhases.HumanPhase.afMass(this.oMT.tiN2I.H2O);
            if fWaterDifference > 0.5
                this.toBranches.Potable_Water_In.oHandler.setFlowRate(fWaterDifference, 60);
            end
            
            %% Eating
            % calculate food energy demand for the current meal (assumes
            % 20% of caloric intake during breakfast, 50% during lunch and
            % 30% during dinner, adds the demand from exercise to the first
            % meal that comes up after the exercise)
            
            %% Restroom
            % kept simple, similar to drinking, whenever the bladder
            % reaches a mass of 0.5 kg the human visits the toilet, on
            % average this happens ~3 times a day
            %
            % for feces a similar logic applies with 116 g of feces
            % necessary for the human to got to the restroom, in general
            % this occurs about once per day. In the event that the
            % restroom visit is because of the feces mass, the human will
            % still empty the bladder
            
            %% Scheduler
            % this handles the different events and defined in the crew
            % schedule (like sleep, exercise etc)
            
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
            % calculated assuming the human consumes 1 J of energy:
            tfPercentMol.Fat            = (tfPercent.Fat / this.tfEnergyContent.Fat) / this.oMT.afMolarMass(this.oMT.tiN2I.C16H32O2);
            tfPercentMol.Protein        = (tfPercent.Protein / this.tfEnergyContent.Protein) / this.oMT.afMolarMass(this.oMT.tiN2I.C4H5ON);
            tfPercentMol.Carbohydrate   = (tfPercent.Carbohydrate / this.tfEnergyContent.Carbohydrate) / this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6);
            
            % C16H32O2 (fats)          + 23 O2     =    16 CO2 + 16H20
            % 2C4H5ON  (protein)       + 7  O2     =    C2H6O2N2 (urine solids) + 6 CO2 + 2H2O 
            % C6H12O6 (carbohydrates)  + 6  O2     =    6 CO2 + 6H2O
            this.fRespiratoryCoefficient = (tfPercentMol.Fat * 16 + tfPercentMol.Protein * 6 + tfPercentMol.Carbohydrate * 6) /...
                                           (tfPercentMol.Fat * 23 + tfPercentMol.Protein * 7 + tfPercentMol.Carbohydrate * 6);
                                    
            % Based on the Respiratory coefficient and according to
            % E. Hofmann, "Funktionelle Biochemie des Menschen" © Springer
            % Fachmedien Wiesbaden 1979 it is possible to calculate a
            % colric value for oxygen (the amount of energy released per
            % unit of oxygen)
            % Following the calculation from above for 1 J of energy a
            % total of x kg of oxygen is consumed, and 1/ this is the
            % amount of energy that can be released per kg of oxygen
            this.fCaloricValueOxygen = 1 /  (this.oMT.afMolarMass(this.oMT.tiN2I.O2) *(tfPercentMol.Fat * 23  +  tfPercentMol.Protein * 7  + tfPercentMol.Carbohydrate * 6 ));
            
            
            %% Respiration
            
            fBasicDailyOxygenDemand = this.fBasicFoodEnergyDemand * this.fCaloricValueOxygen; % kg/d
            
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
            fOxygenDemandNominal    = fBasicDailyOxygenDemand / (0.6338 * 8 * 3600 + 16 * 3600);
            fOxygenDemandSleep      = 0.6338 * fOxygenDemandNominal;
            
            if this.iState == 0
                % sleeping
                this.fOxygenDemand = fOxygenDemandSleep;
                this.fVO2_current = (fOxygenDemandSleep / this.oMT.afMolarMass(this.oMT.tiN2I.O2)) * 22.4 * 1000 * 60;
                
            elseif this.iState == 2
                % excersice
                %
                % fPercentVO2_max must be defined in the scheduler for the
                % exercise period!
                this.fVO2_current = fPercentVO2_max * this.fVO2_max; % ml/kg/min
                this.fOxygenDemand = ((this.fVO2_current/1000/60) / 22.4) * this.oMT.afMolarMass(this.oMT.tiN2I.O2);
                
            else
                % nominal
                this.fOxygenDemand = fOxygenDemandNominal;
                this.fVO2_current = (fOxygenDemandNominal / this.oMT.afMolarMass(this.oMT.tiN2I.O2)) * 22.4 * 1000 * 60;
            end
            
            %% Digestion
            
            % the current energy demand is now calculated based on the
            % current oxygen demand (which depends on the state of the crew
            this.fCurrentEnergyDemand = this.fOxygenDemand * this.fCaloricValueOxygen;
            
            tfMassConsumption.Fat            = (this.fCurrentEnergyDemand * tfPercent.Fat) / this.tfEnergyContent.Fat;
            tfMassConsumption.Protein        = (this.fCurrentEnergyDemand * tfPercent.Protein) / this.tfEnergyContent.Protein;
            tfMassConsumption.Carbohydrate   = (this.fCurrentEnergyDemand * tfPercent.Carbohydrate) / this.tfEnergyContent.Carbohydrate;
            
            tfMolarConsumption.Fat            = tfMassConsumption.Fat / this.oMT.afMolarMass(this.oMT.tiN2I.C16H32O2);
            tfMolarConsumption.Protein        = tfMassConsumption.Protein / this.oMT.afMolarMass(this.oMT.tiN2I.C4H5ON);
            tfMolarConsumption.Carbohydrate   = tfMassConsumption.Carbohydrate / this.oMT.afMolarMass(this.oMT.tiN2I.C6H12O6);
            
            
            % C16H32O2 (fats)          + 23 O2     =    16 CO2 + 16H20
            % 2C4H5ON  (protein)       + 7  O2     =    C2H6O2N2 (urine solids) + 6 CO2 + 2H2O 
            % C6H12O6 (carbohydrates)  + 6  O2     =    6 CO2 + 6H2O
            this.fCO2Production             = this.oMT.afMolarMass(this.oMT.tiN2I.CO2) * (tfMolarConsumption.Fat * 16 + tfMolarConsumption.Protein * 6 + tfMolarConsumption.Carbohydrate * 6);
            this.fMetabolicWaterProduction  = this.oMT.afMolarMass(this.oMT.tiN2I.H2O) * (tfMolarConsumption.Fat * 16 + tfMolarConsumption.Protein * 2 + tfMolarConsumption.Carbohydrate * 6);
            this.fUrineSolidsProduction     = this.oMT.afMolarMass(this.oMT.tiN2I.C2H6O2N2) * tfMolarConsumption.Protein;
             
            
            % 5C4H5ON + C6H12O6 + C16H32O2 = C42H69O13N5 (feces solids composition)
            
            
            %% Other stuff
            % air flow rate for breathing is set so that 4% of the inhaled
            % oxygen is consumed! Write function bound to trigger to do
            % this automatically
            
        end
    end
end