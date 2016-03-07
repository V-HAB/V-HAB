classdef Example < vsys
    %EXAMPLE Example simulation for a human model in V-HAB 2.0
    
    properties (SetAccess = protected, GetAccess = public)
        tCurrentFoodRequest;
        cScheduledFoodRequest = cell(0,0);
        fFoodPrepTime = 3*60; %assumes that it take 3 minutes to prepare the food
        
        fInitialFoodPrepMass;
    end
    
    methods
        function this = Example(oParent, sName)
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName, -1);
            
            %% sleep events
            %sleep from 00:22:00 to 01:06:00
            sEventSleep = struct();
            sEventSleep.State = 'sleep';
            sEventSleep.Start =    16*3600; 
            sEventSleep.End =      24*3600;
            sEventSleep.Started = false;
            sEventSleep.Ended = false;
            sEventSleep.bRepeat = true;
            
            %workout
            sEventExercise1 = struct();
            sEventExercise1.State = 'exercise015';
            sEventExercise1.Start =    3*3600; 
            sEventExercise1.End =      4*3600;
            sEventExercise1.Started = false;
            sEventExercise1.Ended = false;
            sEventExercise1.bRepeat = true;
            
            sEventExercise2 = struct();
            sEventExercise2.State = 'exercise015';
            sEventExercise2.Start =    6*3600; 
            sEventExercise2.End =      7*3600;
            sEventExercise2.Started = false;
            sEventExercise2.Ended = false;
            sEventExercise2.bRepeat = true;
            
            sEventExercise3 = struct();
            sEventExercise3.State = 'exercise015';
            sEventExercise3.Start =    9*3600; 
            sEventExercise3.End =      10*3600;
            sEventExercise3.Started = false;
            sEventExercise3.Ended = false;
            sEventExercise3.bRepeat = true;
            
            tCrewPlaner.cMetabolism{1,1} = sEventExercise1;
            tCrewPlaner.cMetabolism{1,2} = sEventSleep;
            
            tCrewPlaner.cMetabolism{2,1} = sEventExercise2;
            tCrewPlaner.cMetabolism{2,2} = sEventSleep;
            
            tCrewPlaner.cMetabolism{3,1} = sEventExercise3;
            tCrewPlaner.cMetabolism{3,2} = sEventSleep;
            
            tCrewPlaner2.cMetabolism{1,1} = sEventExercise2;
            tCrewPlaner2.cMetabolism{1,2} = sEventSleep;
            
            tMealTimes.Breakfast = 0*3600;
            tMealTimes.Lunch = 6*3600;
            tMealTimes.Dinner = 15*3600;
            
            % Or to let it simulate only one human, in which case the
            % restroom events are based on internal calculations
            vman.human.main(this, 'One_Human', 1, tCrewPlaner2, tMealTimes);
            
            % Also if the simulation for the habitat uses discretization
            % itr is necessary for each human subsystem to represent only
            % one human (because otherwise the impact of the human on the
            % atmosphere would be incorrect since all humans would share
            % one lung)
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creates the cabin store that contains the main habitat
            % atmosphere
            matter.store(this, 'Cabin', 48);
            
            fAmbientTemperature = 295;
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            fCO2Percent = 0.0062;
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 48, struct('CO2', fCO2Percent),  fAmbientTemperature, 0.4, 1e5);
               
            % Adding a phase to the store 'Cabin', 48 m^3 air
            oCabinPhase = matter.phases.gas(this.toStores.Cabin, 'CabinAir', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            %Human Exmes
            matter.procs.exmes.gas(oCabinPhase, 'AirOut');
            matter.procs.exmes.gas(oCabinPhase, 'AirIn');
            
            % Creates a store for the potable water reserve
            % Potable Water Store
            matter.store(this, 'PotableWaterStorage', 1);
            
            oPotableWaterPhase = matter.phases.liquid(this.toStores.PotableWaterStorage, 'PotableWater', struct('H2O', 100), 1, 295, 101325);
            matter.procs.exmes.liquid(oPotableWaterPhase, 'PotableWaterDrinkingOut');
            matter.procs.exmes.liquid(oPotableWaterPhase, 'PotableWaterFoodPrepOut');
            
            % Creates a store for the dry food storage
            % Dry Food Storage
            tfMasses = struct('C', 20);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, 295, true);
            
            matter.store(this, 'DryFoodStorage', fSolidVolume);
            oDryFoodPhase = matter.phases.solid(this.toStores.DryFoodStorage, 'DryFood', tfMasses, [], 295); 
            
            matter.procs.exmes.solid(oDryFoodPhase, 'DryFoodOut');
            
            % Creates a store for the dry food preperation (dry food and
            % water are combined to create edible food)
            % Food Preperation
            tfMasses = struct('C', 0.1);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, 295, true);
            
            matter.store(this, 'FoodPreperation', fSolidVolume + 1e-4);
            oPreparedFoodPhase = matter.phases.solid(this.toStores.FoodPreperation, 'PreparedFood',  tfMasses, [], 295);
            
            this.fInitialFoodPrepMass = oPreparedFoodPhase.fMass;
            
            matter.procs.exmes.solid(oPreparedFoodPhase, 'DryFoodIn');
            matter.procs.exmes.solid(oPreparedFoodPhase, 'H2O_In');
            matter.procs.exmes.solid(oPreparedFoodPhase, 'PreparedFoodOut');
            % if plants or fresh food are also used an additional EXME
            % could be used to put that food into the preperation store
            
            % since the food preperation basically takes water and dry food
            % and creates food, the food preperation store requires two
            % phases, one solid and one liquid and a p2p proc to move the
            % liquid potable water into the solid phase
            oFoodPreperationWater = matter.phases.liquid(this.toStores.FoodPreperation, 'PotableWater', struct('H2O', 0.1), 1e-4, 295, 101325);
            
            matter.procs.exmes.liquid(oFoodPreperationWater, 'PotableWaterIn');
            matter.procs.exmes.liquid(oFoodPreperationWater, 'H2O_Out');
            
            % assumes that 1/3 of the dry food mass has to be added in
            % water for preperation
            tutorials.human_model.components.Food_H2O_Addition(this.toStores.FoodPreperation, 'FoodPrepP2P', 'PotableWater.H2O_Out', 'PreparedFood.H2O_In');
            
            % Creates a store for the urine
            matter.store(this, 'UrineStorage', 1e-4);
            
            oUrinePhase = matter.phases.liquid(this.toStores.UrineStorage, 'Urine', struct('H2O', 0.1), 1e-4, 295, 101325);
            matter.procs.exmes.liquid(oUrinePhase, 'Urine_In');
            
            % Creates a store for the feces storage
            tfMasses = struct('C', 1);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, 295, true);
            
            matter.store(this, 'FecesStorage', fSolidVolume);
            oFecesPhase = matter.phases.solid(this.toStores.FecesStorage, 'Feces', tfMasses, [], 295); 
            
            matter.procs.exmes.solid(oFecesPhase, 'Feces_In');
            
            matter.branch(this, 'DryFoodStorage.DryFoodOut', {}, 'FoodPreperation.DryFoodIn', 'DryFood_To_Preperation');
            matter.branch(this, 'FoodPreperation.PotableWaterIn', {}, 'PotableWaterStorage.PotableWaterFoodPrepOut', 'PotableWater_For_FoodPrep');
            
            matter.branch(this, 'Air_Out', {}, 'Cabin.AirOut');
            matter.branch(this, 'Air_In', {}, 'Cabin.AirIn');
            matter.branch(this, 'Solid_Food_Out', {}, 'FoodPreperation.PreparedFoodOut');
            matter.branch(this, 'Feces_In', {}, 'FecesStorage.Feces_In');
            matter.branch(this, 'Liquid_Food_Out', {}, 'PotableWaterStorage.PotableWaterDrinkingOut');
            matter.branch(this, 'Urine_In', {}, 'UrineStorage.Urine_In');
            
            this.toChildren.One_Human.setIfFlows('Air_Out', 'Air_In', 'Solid_Food_Out', 'Feces_In', 'Liquid_Food_Out', 'Urine_In');
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.residual.branch(this.toBranches.PotableWater_For_FoodPrep);
            
            solver.matter.manual.branch(this.toBranches.DryFood_To_Preperation);
            
            
            %All phases except the human air phase work with a 60s time
            %step
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    if ~strcmp(this.toStores.(csStoreNames{iStore}).aoPhases(iPhase).sName, 'CabinAir')
                        oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                        oPhase.rMaxChange = 10;
                    end
                end
            end
        end
        function requestFood(this, sHumanModelName, tEvent)
            % start preparing food for the crew member that requested food.
            % Then once the food is prepared give it to the crew member
            if isempty(this.tCurrentFoodRequest)
                this.tCurrentFoodRequest.sHumanModelName = sHumanModelName;
                this.tCurrentFoodRequest.tEvent = tEvent;
            else
                % if the food processor is currently busy schedule the
                % event and execute it once the preperator is finished
                tFoodRequest.sHumanModelName = sHumanModelName;
                tFoodRequest.tEvent = tEvent;
                this.cScheduledFoodRequest{end+1} = tFoodRequest;
                % to remove event: cScheduledFoodRequestTest =
                % cScheduledFoodRequest(2:end) and then just always execute
                % the first elemt from the schedule
            end
            
        end
        function deleteFoodRequest(this,~)
            if ~isempty(this.tCurrentFoodRequest)
                this.tCurrentFoodRequest = [];
            end
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            %% food preperation
            if ~isempty(this.tCurrentFoodRequest)
                if ~isfield(this.tCurrentFoodRequest, 'fStartTime')
                    this.tCurrentFoodRequest.fStartTime = this.oTimer.fTime;
                
                    % Assuming that food preperation takes 2 minutes, and
                    % that the food contains 42% water and 58% solids
                    fDryFoodFlowRate = 0.58 * this.tCurrentFoodRequest.tEvent.fConsumption/(this.fFoodPrepTime);
                    fWaterForFoodFlowRate = 0.42 * this.tCurrentFoodRequest.tEvent.fConsumption/(this.fFoodPrepTime);

                    this.toBranches.DryFood_To_Preperation.oHandler.setFlowRate(fDryFoodFlowRate);
                    
                    this.toStores.FoodPreperation.toProcsP2P.FoodPrepP2P.setFlowRate( fWaterForFoodFlowRate );
                    
                    this.setTimeStep(1);
                    
                elseif ((this.oTimer.fTime - this.tCurrentFoodRequest.fStartTime) >= this.fFoodPrepTime) && (this.toChildren.(this.tCurrentFoodRequest.sHumanModelName).fEatStartTime == inf)
                    % food preperation is finished:
                    this.toBranches.DryFood_To_Preperation.oHandler.setFlowRate(0);
                    % it is assumed that the end product of food contains 0.42%
                    % water. That means for each kg of dry food 0.724 kg of water
                    % have to be added
                    this.toStores.FoodPreperation.toProcsP2P.FoodPrepP2P.setFlowRate(0);
                    
                    % And the human who requested the food eats it:
                    this.toChildren.(this.tCurrentFoodRequest.sHumanModelName).consumeFood(this.toStores.FoodPreperation.toPhases.PreparedFood.fMass - this.fInitialFoodPrepMass);
                    
                    this.setTimeStep(-1);
                end
                
            elseif ~isempty(this.cScheduledFoodRequest)
                % if currently no food is prepared but another event is in
                % the scheduler it will be set as current event and is then
                % deleted from the scheduler
                this.tCurrentFoodRequest = this.cScheduledFoodRequest{1};
                this.cScheduledFoodRequest = this.cScheduledFoodRequest(2:end);
            end
        end
     end
    
end

