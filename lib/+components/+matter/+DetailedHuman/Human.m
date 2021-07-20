classdef Human < vsys
    % human model subsystem
    properties (SetAccess = protected, GetAccess = public)
        
        fBodyCoreTemperature = 309.95;
        
        fAge            = 25;       % Years
        fHeight         = 1.80;     % [m]
        
        % Scheduler parameters
        % Current state the human is in, 0 means sleep, 1 means nominal, 2
        % and 3 means exercise 4 is recovery. For the detailed human model
        % no difference between exercise 2 and 3 is made. THis is just to
        % maintain consistency to the simple human model
        iState = 1;
        fStateStartTime = 0;
        txCrewPlaner;
        iEvent = 1;
        fPostExerciseStartTime;
        
        fNominalAcitivityLevel = 0.05;
        
        aoP2PBranches;
        toP2PBranches;
        
        bUpdateRegistered = false;
        hBindPostTickUpdate;
    end
    
    methods
        function this = Human(oParent, sName, txCrewPlaner, fTimeStep)
            
            this@vsys(oParent, sName, fTimeStep);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            this.txCrewPlaner = txCrewPlaner;
            
            %% Adding the layers:
            components.matter.DetailedHuman.Layers.Digestion(this,      'Digestion');
            components.matter.DetailedHuman.Layers.Metabolic(this,      'Metabolic');
            components.matter.DetailedHuman.Layers.Respiration(this,    'Respiration');
            components.matter.DetailedHuman.Layers.Thermal(this,        'Thermal');
            components.matter.DetailedHuman.Layers.WaterBalance(this,   'WaterBalance');
            
            this.aoP2PBranches = components.matter.DetailedHuman.components.P2P_Branch.branch.empty();
            
            
            this.hBindPostTickUpdate  = this.oTimer.registerPostTick(@this.update,   'matter',        'post_phase_update');
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% Define the phases with IFs of the different layers:
            % Note that this is a non standard approach, in the detailed
            % human model all branches are defined on the human (this
            % system) which enables direct definition of branches between
            % two subsystems (the layers) without requiring interface
            % stores
            % Respiration Phases:
            oLungPhase      = this.toChildren.Respiration.toStores.Lung.toPhases.Air;
            oBrainTissue    = this.toChildren.Respiration.toStores.Brain.toPhases.Tissue;
            oTissueTissue   = this.toChildren.Respiration.toStores.Tissue.toPhases.Tissue;
            
            % Metabolic Phases:
            oMetabolism = this.toChildren.Metabolic.toStores.Metabolism.toPhases.Metabolism;
            
            % Water Balance Phases:
            oBloodPlasma        = this.toChildren.WaterBalance.toStores.WaterBalance.toPhases.BloodPlasma;
            oInterstitialFluid  = this.toChildren.WaterBalance.toStores.WaterBalance.toPhases.InterstitialFluid;
            oBladder            = this.toChildren.WaterBalance.toStores.WaterBalance.toPhases.Bladder;
            oPerspirationFlow   = this.toChildren.WaterBalance.toStores.PerspirationOutput.toPhases.PerspirationFlow;
            
            % Digestion Phases:
            oStomach     	= this.toChildren.Digestion.toStores.Digestion.toPhases.Stomach;
            oDuodenum       = this.toChildren.Digestion.toStores.Digestion.toPhases.Duodenum;
            oJejunum        = this.toChildren.Digestion.toStores.Digestion.toPhases.Jejunum;
            oIleum          = this.toChildren.Digestion.toStores.Digestion.toPhases.Ileum;
            oLargeIntestine	= this.toChildren.Digestion.toStores.Digestion.toPhases.LargeIntestine;
            oRectum         = this.toChildren.Digestion.toStores.Digestion.toPhases.Rectum;
            
            %% Define Interface branches between the layer:
            % Respiration Branches
            
            % air in- and outlet
            matter.branch(this, oLungPhase,       	{},     'Air_In',           'Air_In');
            matter.branch(this, oLungPhase,      	{},     'Air_Out',          'Air_Out');
            
            % Metabolic Branches
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oBrainTissue,        {},     oMetabolism,            'O2_from_Brain');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oTissueTissue,       {},     oMetabolism,            'O2_from_Tissue');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oMetabolism,         {},     oBrainTissue,           'CO2_to_Brain');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oMetabolism,         {},     oTissueTissue,          'CO2_to_Tissue');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oMetabolism,         {},     oBloodPlasma,           'MetabolicWater_to_BloodPlasma');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oMetabolism,         {},     oBladder,               'Urea_Output');
            
            % Water Balance branches
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oBloodPlasma,       	{},     oStomach,               'DigestionWaterInput');
            
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oInterstitialFluid, 	{},     oLungPhase,           	'RespirationWaterOutput');
            
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oInterstitialFluid, 	{},     oPerspirationFlow,     	'PerspirationWaterTransfer');
            % Note that perspiration here only reflects the perspiration
            % insensibilies without the water lost from respiration. (And
            % also without sweat)
            matter.branch(this, oPerspirationFlow,	{},     'PerspirationWaterOutput',   'PerspirationWaterOutput');
            
            matter.branch(this, oBladder,          	{},     'Urine_Out',           	'Urine_Out');
            
            % Digestion Branches
            % Not saliva would actually enter the mouth, but for model
            % simpicity it is modelled to enter the stomach directly
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oBloodPlasma,       	{},     oStomach,                 'SalivaToMouth');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oBloodPlasma,       	{},     oStomach,                 'SecretionToStomach');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oBloodPlasma,       	{},     oDuodenum,                'SecretionToDuodenum');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oBloodPlasma,       	{},     oJejunum,                 'SecretionToJejunum');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oBloodPlasma,       	{},     oIleum,                   'SecretionToIleum');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oBloodPlasma,       	{},     oLargeIntestine,          'SecretionToLargeIntestine');
            
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oDuodenum,       	{},     oBloodPlasma,             'ReadsorptionFromDuodenum');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oJejunum,            {},     oBloodPlasma,             'ReadsorptionFromJejunum');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oIleum,              {},     oBloodPlasma,             'ReadsorptionFromIleum');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oLargeIntestine,   	{},     oBloodPlasma,             'ReadsorptionFromLargeIntestine');
            
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oDuodenum,           {},     oMetabolism,              'DuodenumToMetabolism');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oJejunum,            {},     oMetabolism,              'JejunumToMetabolism');
            components.matter.DetailedHuman.components.P2P_Branch.branch(this, oIleum,              {},     oMetabolism,              'IleumToMetabolism');
            
            matter.branch(this, oStomach,           {},     'Food_In',            	'Food_In');
            matter.branch(this, oStomach,         	{},     'Potable_Water_In',  	'Potable_Water_In');
            matter.branch(this, oRectum,          	{},     'Feces_Out',          	'Feces_Out');
         end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            % create a thermal branch for the sensible heat output:
            thermal.branch(this, this.toChildren.Thermal.toStores.Thermal.toPhases.Tissue.oCapacity, {}, 'SensibleHeatOutput', 'SensibleHeatOutput');
            
            this.createAdvectiveThermalBranches(this.aoP2PBranches, true);
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %% Interface branches
            oResidual = solver.matter.residual.branch(this.toBranches.Food_In);
            oResidual.setPositiveFlowDirection(false);
                
            solver.matter.manual.branch(this.toBranches.Potable_Water_In);
            solver.matter.manual.branch(this.toBranches.Urine_Out);
            solver.matter.manual.branch(this.toBranches.Feces_Out);
           
            % For the perspiration water output we have to combine a P2P
            % and a residual branch (hopefully we do not get trouble
            % transferring only water through a gas flow phase)
            components.matter.DetailedHuman.components.P2P_Branch.solver.branch(this.toBranches.PerspirationWaterTransfer);
            solver.matter.residual.branch(this.toBranches.PerspirationWaterOutput);
            
            %% Internal Branches
            csInternalP2PBranches = {'O2_from_Brain' 'O2_from_Tissue' 'CO2_to_Brain' 'CO2_to_Tissue' 'MetabolicWater_to_BloodPlasma' 'Urea_Output',... Metabolic Branches
                                     'DigestionWaterInput' 'RespirationWaterOutput',... Water Balance branches
                                     'SalivaToMouth' 'SecretionToStomach' 'SecretionToDuodenum' 'SecretionToJejunum' 'SecretionToIleum' 'SecretionToLargeIntestine',... digestion secretion branches
                                     'ReadsorptionFromDuodenum' 'ReadsorptionFromJejunum' 'ReadsorptionFromIleum' 'ReadsorptionFromLargeIntestine',... digestion readsorption branches
                                     'DuodenumToMetabolism' 'JejunumToMetabolism' 'IleumToMetabolism'}; % digestion IF branches to metabolism
            for iBranch = 1:length(csInternalP2PBranches)                     
                components.matter.DetailedHuman.components.P2P_Branch.solver.branch(this.toBranches.(csInternalP2PBranches{iBranch}));
            end
            
            %% Thermal Branches
            solver.thermal.manual.branch(this.toThermalBranches.SensibleHeatOutput);
            
            this.setThermalSolvers();
            
            %% since a change in the digestion layer impacts the other layers we update the human model if the phases require an update
            this.toChildren.Digestion.toStores.Digestion.toPhases.Stomach.bind(             'update_post', @this.bindUpdate);
            this.toChildren.Digestion.toStores.Digestion.toPhases.Duodenum.bind(           	'update_post', @this.bindUpdate);
            this.toChildren.Digestion.toStores.Digestion.toPhases.Jejunum.bind(           	'update_post', @this.bindUpdate);
            this.toChildren.Digestion.toStores.Digestion.toPhases.Ileum.bind(             	'update_post', @this.bindUpdate);
            this.toChildren.Digestion.toStores.Digestion.toPhases.LargeIntestine.bind(    	'update_post', @this.bindUpdate);
            this.toChildren.Digestion.toStores.Digestion.toPhases.Rectum.bind(              'update_post', @this.bindUpdate);
            
            %% For the respiration layer the same holds true.
            % This is necessary because otherwise too large steps between
            % the P2P calculations can occur, and the partial pressure of
            % O2 in the blood could exceed its limits
            this.toChildren.Respiration.toStores.Tissue.toPhases.Tissue.bind(               'update_post', @this.bindUpdate);
            this.toChildren.Respiration.toStores.Tissue.toPhases.Blood.bind(                'update_post', @this.bindUpdate);
            this.toChildren.Respiration.toStores.Brain.toPhases.Tissue.bind(                'update_post', @this.bindUpdate);
            this.toChildren.Respiration.toStores.Brain.toPhases.Blood.bind(                 'update_post', @this.bindUpdate);
            
        end
        
        function setIfFlows(this, varargin)
            % This function connects the system and subsystem level branches with
            % each other. It uses the connectIF function provided by the
            % matter.container class
            this.connectIF('Air_Out' ,                  varargin{1});
            this.connectIF('Air_In' ,                   varargin{2});
            this.connectIF('Potable_Water_In',          varargin{3}); 
            this.connectIF('Food_In',                   varargin{4});
            this.connectIF('Feces_Out',                 varargin{5});
            this.connectIF('Urine_Out',                 varargin{6});
            this.connectIF('PerspirationWaterOutput', 	varargin{7});
        end
        
        function setThermalIF(this, varargin)
            % This function connects the system and subsystem level thermal
            % branches with each other. It uses the connectIF function
            % provided by the matter.container class
            this.connectThermalIF('SensibleHeatOutput' ,          varargin{1});
            
        end
        
        function setBodyCoreTemperature(this, fBodyCoreTemperature)
            % Currently not used function, but implemented to maintain body
            % core temperature inside the model
            this.fBodyCoreTemperature = fBodyCoreTemperature;
            this.toChildren.Respiration.toStores.Lung.toPhases.Air.oCapacity.toHeatSources.LungConstantTemperature.setTemperature(this.fBodyCoreTemperature);
            
            this.toChildren.Digestion.toStores.Digestion.toPhases.Stomach.oCapacity.toHeatSources.StomachConstantTemperature.setTemperature(this.fBodyCoreTemperature);
        end
        
        function setState(this, iState)
            this.iState = iState;
            this.fStateStartTime = this.oTimer.fTime;
        end
        
        function bindUpdate(this, ~)
            if ~this.bUpdateRegistered
                this.hBindPostTickUpdate()
            end
        end
        
        function moveHuman(this, oNewCabinPhase)
            % This function can be used to move the human from the current
            % cabin phase, to another cabin phase. Only the air interfaces
            % are moved, but if you also want to move other interfaces
            % (e.g. having the human on a spacewalk would require all
            % Interfaces to be adjusted) you can use the same logic on your
            % system to reconnect the other interfaces as well!
            this.toBranches.Air_In.coExmes{2}.reconnectExMe(oNewCabinPhase);
            this.toBranches.Air_Out.coExmes{2}.reconnectExMe(oNewCabinPhase);
            this.toBranches.PerspirationWaterOutput.coExmes{2}.reconnectExMe(oNewCabinPhase);
            
            this.toThermalBranches.SensibleHeatOutput.coExmes{2}.reconnectExMe(oNewCabinPhase.oCapacity);
        end
        
        function addP2PBranch(this, oBranch)
            this.aoP2PBranches(end+1,1) = oBranch;
            
            if isfield(this.toP2PBranches, oBranch.sCustomName)
                this.throw('Human:addP2PBranch','A P2P Branch with the name ''%s'' already exists in the Human model.',oBranch.sCustomName);
            else
                this.toP2PBranches.(oBranch.sCustomName) = oBranch;
            end
        end
    end
    
    methods (Access = protected)
        function update(this, ~)
            %% Update Layers
            % The digestion layer is quite independent from the other
            % layers, as the metabolic layer stores absorbed nutrients and
            % does not directly consume them
            this.toChildren.Digestion.update();
            
            % The metabolic layer handles activity levels and must
            % therefore be performed before the respiration layer. Since it
            % also calculates the created Urea it must also be executed
            % before the water balance layer
            this.toChildren.Metabolic.update();
            this.toChildren.Respiration.update();
            this.toChildren.WaterBalance.update();
            % The thermal layer requires the current information on the
            % available sweat from the water layer, as well as heat flows
            % from the respiration, metabolic and digestion layer.
            % Therefore it must be updated last
            this.toChildren.Thermal.update();
        end
        
        function exec(this, ~)
            exec@vsys(this);
            
            %% Handle Scheduling
            % Differences to the simple human model are:
            % - no defined exercise levels that we move through, also no
            %   defined post exercise state that we move through. All of
            %   this is calculated dynamically in the detailed human model,
            %   we only have to set the activity level
            % - the original V-Man 1 model handled food intake through
            %   electrolyte debt and hunger levels. However, the current
            %   interface in the food store is to define an energy intake.
            %   Therefore, the metabolic layer calculates a total daily
            %   energy demand.
            
            % Scheduler
            % this handles the different events and defined in the crew
            % schedule (like sleep, exercise etc)
            % From the dissertation of Markus Czupalla Figure 11-60 the
            % following Activity Levels for tasks were used:
            %
            % Sleep:    0
            % Nominal:  0.15
            %
            % For exercise the event defines the level of VO2
            if (this.oTimer.fTime >= this.txCrewPlaner.ctEvents{this.iEvent}.Start) && ~this.txCrewPlaner.ctEvents{this.iEvent}.Started
                
                this.txCrewPlaner.ctEvents{this.iEvent}.Started = true;
                
                this.setState(this.txCrewPlaner.ctEvents{this.iEvent}.State);
                
                % For the detailed human model there are no different
                % exercise/recovery states as this is handled in the metabolic
                % layer
                
                % Handle the VO2 values based on the current state parameters
                if this.iState == 0
                    % sleeping
                    this.toChildren.Metabolic.setActivityLevel(0, false, false);
                    
                elseif this.iState == 2 || this.iState == 3
                    % excersice
                    %
                    % fPercentVO2_max must be defined in the scheduler for the
                    % exercise period!
                    this.toChildren.Metabolic.setActivityLevel(this.txCrewPlaner.ctEvents{this.iEvent}.VO2_percent, true, false);
                    
                else
                    % nominal
                    this.toChildren.Metabolic.setActivityLevel(this.fNominalAcitivityLevel, false, false);
                end
            end
            
            if this.oTimer.fTime >= this.txCrewPlaner.ctEvents{this.iEvent}.End && ~this.txCrewPlaner.ctEvents{this.iEvent}.Ended
                
                this.txCrewPlaner.ctEvents{this.iEvent}.Ended = true;
                
                % Checks if the initialised event was an excercise, if
                % so the human does not go to nominal state, but into a
                % recovery state
                if this.txCrewPlaner.ctEvents{this.iEvent}.State == 2 || this.txCrewPlaner.ctEvents{this.iEvent}.State == 3
                    this.setState(4);
                    this.fPostExerciseStartTime = this.oTimer.fTime;
                elseif this.txCrewPlaner.ctEvents{this.iEvent}.State == 0
                    this.setState(1);
                    this.toChildren.Metabolic.setActivityLevel(this.fNominalAcitivityLevel, false, false);
                end
                
                this.iEvent = this.iEvent + 1;
            end
            
            % The only thing we have to check continously during post
            % exercise conditions
            if this.iState == 4
                if this.oTimer.fTime >= (this.fPostExerciseStartTime + this.toChildren.Metabolic.mrExcessPostExerciseActivityLevel(1, end))
                    % move back to nominal state
                    this.setState(1);
                    this.toChildren.Metabolic.setActivityLevel(this.fNominalAcitivityLevel, false, false);
                else
                    
                    abExactTime = (this.oTimer.fTime - this.fPostExerciseStartTime) == this.toChildren.Metabolic.mrExcessPostExerciseActivityLevel(1, :);
                    if any(abExactTime)
                        iTime = find(abExactTime);
                    else
                        abLowerTime = (this.oTimer.fTime - this.fPostExerciseStartTime) < this.toChildren.Metabolic.mrExcessPostExerciseActivityLevel(1, :);
                        iTime = find(abLowerTime, 1, 'last' );
                    end
                    
                    rActivityLevel = this.toChildren.Metabolic.mrExcessPostExerciseActivityLevel(2,iTime);
                    
                    this.toChildren.Metabolic.setActivityLevel(rActivityLevel, false, true);
                end
            end
            
            % Eating
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

                    fEnergyDemand = 0.2 * this.toChildren.Metabolic.fRestingDailyEnergyExpenditure + this.toChildren.Metabolic.fAdditionalFoodEnergyDemand;
                    
                    this.toChildren.Digestion.Eat(fEnergyDemand, 5*60);
                    
                    this.toChildren.Metabolic.resetAdditionalFoodEnergyDemand();
                    
                elseif this.oTimer.fTime >= this.txCrewPlaner.tMealTimes.Lunch

                    % move the next Lunch time one day ahead
                    this.txCrewPlaner.tMealTimes.Lunch = this.txCrewPlaner.tMealTimes.Lunch + 86400;

                    fEnergyDemand = 0.5 * this.toChildren.Metabolic.fRestingDailyEnergyExpenditure + this.toChildren.Metabolic.fAdditionalFoodEnergyDemand;
                    
                    this.toChildren.Digestion.Eat(fEnergyDemand, 10*60);
                    
                    this.toChildren.Metabolic.resetAdditionalFoodEnergyDemand();
                    
                elseif this.oTimer.fTime >= this.txCrewPlaner.tMealTimes.Dinner

                    % move the next Dinner time one day ahead
                    this.txCrewPlaner.tMealTimes.Dinner = this.txCrewPlaner.tMealTimes.Dinner + 86400;

                    fEnergyDemand = 0.3 * this.toChildren.Metabolic.fRestingDailyEnergyExpenditure + this.toChildren.Metabolic.fAdditionalFoodEnergyDemand;
                    
                    this.toChildren.Digestion.Eat(fEnergyDemand, 5*60);
                    
                    this.toChildren.Metabolic.resetAdditionalFoodEnergyDemand();
                end
            end
            
            this.bindUpdate();
        end
    end
end