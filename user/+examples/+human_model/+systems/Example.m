classdef Example < vsys
    %EXAMPLE Example simulation for a human model in V-HAB 2.0
    
    properties (SetAccess = protected, GetAccess = public)
        tCurrentFoodRequest;
        cScheduledFoodRequest = cell(0,0);
        fFoodPrepTime = 3*60; %assumes that it take 3 minutes to prepare the food
        
        fInitialFoodPrepMass;
        
        iNumberOfCrewMembers;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            %% crew planer
            % Since the crew schedule follows the same pattern every day,
            % it was changed to a loop. Thereby, longer mission durations
            % can easily be set just by changing the iLengthOfMission
            % parameter. Currently, 10 days are set. If the number is
            % higher tan the actual simulation time, this does not make any
            % difference. If it is too short, the impact of the humans
            % stops somewhen during the simulation time and the simulation
            % is not usable. So make sure to ajust the parameter properly.         
            
            %Number of CrewMember goes here:
            this.iNumberOfCrewMembers = 2;
            
            % Number of days that events shall be planned goes here:
            iLengthOfMission = 10; % [d]
            
            ctEvents = cell(iLengthOfMission, this.iNumberOfCrewMembers);
            
            %% Nominal Operation
            
            tMealTimes.Breakfast = 0*3600;
            tMealTimes.Lunch = 6*3600;
            tMealTimes.Dinner = 15*3600;
            
            for iCrewMember = 1:this.iNumberOfCrewMembers
                
                iEvent = 1;
                
                for iDay = 1:iLengthOfMission
                    if iCrewMember == 1 || iCrewMember == 4
                        
                        ctEvents{iEvent, iCrewMember}.State = 2;
                        ctEvents{iEvent, iCrewMember}.Start = ((iDay-1) * 24 +  1) * 3600;
                        ctEvents{iEvent, iCrewMember}.End = ((iDay-1) * 24 +  1.5) * 3600;
                        ctEvents{iEvent, iCrewMember}.Started = false;
                        ctEvents{iEvent, iCrewMember}.Ended = false;
                        ctEvents{iEvent, iCrewMember}.VO2_percent = 0.75;
                        
                    elseif iCrewMember==2 || iCrewMember ==5
                        ctEvents{iEvent, iCrewMember}.State = 2;
                        ctEvents{iEvent, iCrewMember}.Start = ((iDay-1) * 24 +  5) * 3600;
                        ctEvents{iEvent, iCrewMember}.End = ((iDay-1) * 24 +  5.5) * 3600;
                        ctEvents{iEvent, iCrewMember}.Started = false;
                        ctEvents{iEvent, iCrewMember}.Ended = false;
                        ctEvents{iEvent, iCrewMember}.VO2_percent = 0.75;
                        
                    elseif iCrewMember ==3 || iCrewMember == 6
                        ctEvents{iEvent, iCrewMember}.State = 2;
                        ctEvents{iEvent, iCrewMember}.Start = ((iDay-1) * 24 +  9) * 3600;
                        ctEvents{iEvent, iCrewMember}.End = ((iDay-1) * 24 +  9.5) * 3600;
                        ctEvents{iEvent, iCrewMember}.Started = false;
                        ctEvents{iEvent, iCrewMember}.Ended = false;
                        ctEvents{iEvent, iCrewMember}.VO2_percent = 0.75;
                    end
                    
                    iEvent = iEvent + 1;
                    
                    ctEvents{iEvent, iCrewMember}.State = 0;
                    ctEvents{iEvent, iCrewMember}.Start =   ((iDay-1) * 24 +  14) * 3600;
                    ctEvents{iEvent, iCrewMember}.End =     ((iDay-1) * 24 +  22) * 3600;
                    ctEvents{iEvent, iCrewMember}.Started = false;
                    ctEvents{iEvent, iCrewMember}.Ended = false;
                    
                    iEvent = iEvent + 1;
                end
            end
            
            for iCrewMember = 1:this.iNumberOfCrewMembers
                
                txCrewPlaner.ctEvents = ctEvents(:, iCrewMember);
                txCrewPlaner.tMealTimes = tMealTimes;
                
                components.matter.Human(this, ['Human_', num2str(iCrewMember)], true, 40, 82, 1.829, txCrewPlaner);
                
                clear txCrewPlaner;
            end
            
            
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
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Cabin_Constant_Temperature');
            oCabinPhase.oCapacity.addHeatSource(oHeatSource);
            
            % Creates a store for the potable water reserve
            % Potable Water Store
            matter.store(this, 'PotableWaterStorage', 10);
            
            oPotableWaterPhase = matter.phases.liquid(this.toStores.PotableWaterStorage, 'PotableWater', struct('H2O', 1000), 295, 101325);
            
            
            % Creates a store for the urine
            matter.store(this, 'UrineStorage', 10);
            
            oUrinePhase = matter.phases.mixture(this.toStores.UrineStorage, 'Urine', 'liquid', struct('C2H6O2N2', 0.059, 'H2O', 1.6), 295, 101325); 
            
            
            % Creates a store for the feces storage            
            matter.store(this, 'FecesStorage', 10);
            oFecesPhase = matter.phases.mixture(this.toStores.FecesStorage, 'Feces', 'solid', struct('C42H69O13N5', 0.032, 'H2O', 0.1), 295, 101325); 
            
            % Adds a food store to the system
            tfFood = struct('Food', 100, 'CarrotsEdibleWet', 10);
            oFoodStore = components.matter.FoodStore(this, 'FoodStore', 100, tfFood);
            
            
            for iHuman = 1:this.iNumberOfCrewMembers
                % Add Exmes for each human
                matter.procs.exmes.gas(oCabinPhase,             ['AirOut',      num2str(iHuman)]);
                matter.procs.exmes.gas(oCabinPhase,             ['AirIn',       num2str(iHuman)]);
                matter.procs.exmes.liquid(oPotableWaterPhase,   ['DrinkingOut', num2str(iHuman)]);
                matter.procs.exmes.mixture(oFecesPhase,         ['Feces_In',    num2str(iHuman)]);
                matter.procs.exmes.mixture(oUrinePhase,         ['Urine_In',    num2str(iHuman)]);

                % Add interface branches for each human
                matter.branch(this, ['Air_Out',         num2str(iHuman)],  	{}, [oCabinPhase.oStore.sName,             '.AirOut',      num2str(iHuman)]);
                matter.branch(this, ['Air_In',          num2str(iHuman)], 	{}, [oCabinPhase.oStore.sName,             '.AirIn',       num2str(iHuman)]);
                matter.branch(this, ['Feces',           num2str(iHuman)],  	{}, [oFecesPhase.oStore.sName,             '.Feces_In',    num2str(iHuman)]);
                matter.branch(this, ['PotableWater',    num2str(iHuman)], 	{}, [oPotableWaterPhase.oStore.sName,      '.DrinkingOut', num2str(iHuman)]);
                matter.branch(this, ['Urine',           num2str(iHuman)], 	{}, [oUrinePhase.oStore.sName,             '.Urine_In',	num2str(iHuman)]);


                % register each human at the food store
                requestFood = oFoodStore.registerHuman(['Solid_Food_', num2str(iHuman)]);
                this.toChildren.(['Human_', num2str(iHuman)]).bindRequestFoodFunction(requestFood);

                % Set the interfaces for each human
                this.toChildren.(['Human_',         num2str(iHuman)]).setIfFlows(...
                                ['Air_Out',         num2str(iHuman)],...
                                ['Air_In',          num2str(iHuman)],...
                                ['PotableWater',    num2str(iHuman)],...
                                ['Solid_Food_',     num2str(iHuman)],...
                                ['Feces',           num2str(iHuman)],...
                                ['Urine',           num2str(iHuman)]);
            end
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % set a fixed time step for the phases where the change rates
            % are not of interest
            tTimeStepProperties.fFixedTimeStep = this.fTimeStep;
            
            this.toStores.PotableWaterStorage.toPhases.PotableWater.setTimeStepProperties(tTimeStepProperties);
            this.toStores.UrineStorage.toPhases.Urine.setTimeStepProperties(tTimeStepProperties);
            this.toStores.FecesStorage.toPhases.Feces.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            this.oTimer.synchronizeCallBacks();
        end
     end
    
end

