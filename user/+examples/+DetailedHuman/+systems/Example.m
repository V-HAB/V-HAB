classdef Example < vsys
    %EXAMPLE Example simulation for a human model in V-HAB 2.0
    
    properties (SetAccess = protected, GetAccess = public)
        iNumberOfCrewMembers;
        
        bHumanMoved = false;
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
            this.iNumberOfCrewMembers = 1;
            
            % Number of days that events shall be planned goes here:
            iLengthOfMission = 10; % [d]
            
            ctEvents = cell(iLengthOfMission, this.iNumberOfCrewMembers);
            
            %% Nominal Operation
            
            tMealTimes.Breakfast = 0.1*3600;
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
                
                components.matter.DetailedHuman.Human(this, ['Human_', num2str(iCrewMember)], txCrewPlaner, 60);
                
                clear txCrewPlaner;
            end
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creates the cabin store that contains the main habitat
            % atmosphere
            matter.store(this, 'Cabin', 50);
            
            fAmbientTemperature = 294.15;
            fDensityH2O = this.oMT.calculateDensity('liquid', struct('H2O', 1), fAmbientTemperature, 101325);
            
            % Adding a phase to the store 'Cabin', 48 m^3 air
            oCabinPhase         = this.toStores.Cabin.createPhase(  'gas', 'boundary',   'CabinAir',  48, struct('N2', 5.554e4, 'O2', 1.476e4, 'CO2', 40),  	fAmbientTemperature,          0.506);
            oCondensatePhase    = matter.phases.liquid(this.toStores.Cabin, 'Condensate', struct('H2O', fDensityH2O * 0.5 * 1),             fAmbientTemperature, 101325);
            oCO2                = this.toStores.Cabin.createPhase( 'gas',   'CO2',  1, struct('CO2', 1e5),          fAmbientTemperature,          0);
            
            matter.store(this, 'Cabin2', 50);
            oCabinPhase2        = this.toStores.Cabin2.createPhase( 'gas', 'boundary',   'CabinAir',  48, struct('N2', 5.554e4, 'O2', 1.476e4, 'CO2', 40),  	fAmbientTemperature,          0.506);
            oCondensatePhase2   = matter.phases.liquid(this.toStores.Cabin2, 'Condensate', struct('H2O', fDensityH2O * 0.5 * 1),            fAmbientTemperature, 101325);
            oCO2_2              = this.toStores.Cabin2.createPhase( 'gas',   'CO2',  1, struct('CO2', 1e5),          fAmbientTemperature,          0);
            
            matter.store(this, 'O2', 100);
            oO2 = this.toStores.O2.createPhase( 'gas',   'O2',  100, struct('O2', 200e5),          fAmbientTemperature,          0);
            
            % Creates a store for the potable water reserve
            % Potable Water Store
            fWaterStorageVolume = 10;
            matter.store(this, 'PotableWaterStorage', fWaterStorageVolume);
            
            % fWaterMol  = fWaterMass / this.oMT.afMolarMass(this.oMT.tiN2I.H2O);
            
            % Concentration of Sodium in ISS potable water
            % From Appendix 1, "International Space Station Potable Water
            % Characterization for 2013", John E. Straub II, Debrah K.
            % Plumlee, and John R. Schultz, Paul D. Mudgett, 44th
            % International Conference on Environmental Systems, 13-17 July
            % 2014, Tucson, Arizona
            fSodiumMass = 4e-6 * (0.9 * fWaterStorageVolume * 1000);
            fSodiumMol = fSodiumMass / this.oMT.afMolarMass(this.oMT.tiN2I.Naplus);
            fChlorideMass = fSodiumMol * this.oMT.afMolarMass(this.oMT.tiN2I.Clminus);
            
            oPotableWaterPhase = matter.phases.liquid(this.toStores.PotableWaterStorage, 'PotableWater', struct('H2O', fDensityH2O * 0.9 * fWaterStorageVolume, 'Naplus', fSodiumMass, 'Clminus', fChlorideMass), fAmbientTemperature, 101325);
            
            % Creates a store for the urine
            matter.store(this, 'UrineStorage', 10);
            oUrinePhase = matter.phases.mixture(this.toStores.UrineStorage, 'Urine', 'liquid', struct('Urine', 1.6), 295, 101325); 
            
            
            % Creates a store for the feces storage            
            matter.store(this, 'FecesStorage', 10);
            oFecesPhase = matter.phases.mixture(this.toStores.FecesStorage, 'Feces', 'solid', struct('Feces', 0.132), 295, 101325); 
            
            % Adds a food store to the system
            tfFood = struct('Food', 100, 'Carrots', 10);
            oFoodStore = components.matter.FoodStore(this, 'FoodStore', 100, tfFood);
            
            matter.branch(this, oO2, {}, oCabinPhase,   'O2_to_Cabin');
            matter.branch(this, oO2, {}, oCabinPhase2,  'O2_to_Cabin2');
            
            oCondensateP2P = components.matter.P2Ps.ManualP2P( this.toStores.Cabin,  'Condensate',  oCabinPhase,  oCondensatePhase);
            components.matter.P2Ps.ManualP2P( this.toStores.Cabin2,  'Condensate', oCabinPhase2, oCondensatePhase2);
            
            oCO2P2P = components.matter.P2Ps.ManualP2P( this.toStores.Cabin,  'CO2',  oCabinPhase,  oCO2);
            components.matter.P2Ps.ManualP2P( this.toStores.Cabin2,  'CO2', oCabinPhase2, oCO2_2);
            
            afCondensateFlow = zeros(1, this.oMT.iSubstances);
            % Using the BVAD value of 1.9 kf of Perspiration and
            % Respiration water to keep the atmosphere about constant in
            % humidity
            afCondensateFlow(this.oMT.tiN2I.H2O) = this.iNumberOfCrewMembers * 1.5 / (24 * 3600);
            oCondensateP2P.setFlowRate(afCondensateFlow)
            
            afCO2Flow = zeros(1, this.oMT.iSubstances);
            % Using the BVAD value of 1.04 kg of CO2 to keep the atmosphere
            % about constant
            afCO2Flow(this.oMT.tiN2I.CO2) = this.iNumberOfCrewMembers * 1.04 / (24 * 3600);
            oCO2P2P.setFlowRate(afCO2Flow)
            
            for iHuman = 1:this.iNumberOfCrewMembers
                % Add Exmes for each human
                matter.procs.exmes.gas(oCabinPhase,             ['AirOut',      num2str(iHuman)]);
                matter.procs.exmes.gas(oCabinPhase,             ['AirIn',       num2str(iHuman)]);
                matter.procs.exmes.liquid(oPotableWaterPhase,   ['DrinkingOut', num2str(iHuman)]);
                matter.procs.exmes.mixture(oFecesPhase,         ['Feces_In',    num2str(iHuman)]);
                matter.procs.exmes.mixture(oUrinePhase,         ['Urine_In',    num2str(iHuman)]);
                matter.procs.exmes.gas(oCabinPhase,             ['Perspiration',num2str(iHuman)]);

                % Add interface branches for each human
                matter.branch(this, ['Air_Out',         num2str(iHuman)],  	{}, [oCabinPhase.oStore.sName,             '.AirOut',      num2str(iHuman)]);
                matter.branch(this, ['Air_In',          num2str(iHuman)], 	{}, [oCabinPhase.oStore.sName,             '.AirIn',       num2str(iHuman)]);
                matter.branch(this, ['Feces',           num2str(iHuman)],  	{}, [oFecesPhase.oStore.sName,             '.Feces_In',    num2str(iHuman)]);
                matter.branch(this, ['PotableWater',    num2str(iHuman)], 	{}, [oPotableWaterPhase.oStore.sName,      '.DrinkingOut', num2str(iHuman)]);
                matter.branch(this, ['Urine',           num2str(iHuman)], 	{}, [oUrinePhase.oStore.sName,             '.Urine_In',    num2str(iHuman)]);
                matter.branch(this, ['Perspiration',    num2str(iHuman)], 	{}, [oCabinPhase.oStore.sName,             '.Perspiration',num2str(iHuman)]);


                % register each human at the food store
                requestFood = oFoodStore.registerHuman(['Solid_Food_', num2str(iHuman)]);
                this.toChildren.(['Human_', num2str(iHuman)]).toChildren.Digestion.bindRequestFoodFunction(requestFood);

                % Set the interfaces for each human
                this.toChildren.(['Human_',         num2str(iHuman)]).setIfFlows(...
                                ['Air_Out',         num2str(iHuman)],...
                                ['Air_In',          num2str(iHuman)],...
                                ['PotableWater',    num2str(iHuman)],...
                                ['Solid_Food_',     num2str(iHuman)],...
                                ['Feces',           num2str(iHuman)],...
                                ['Urine',           num2str(iHuman)],...
                                ['Perspiration',    num2str(iHuman)]);
            end
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
               
            for iHuman = 1:this.iNumberOfCrewMembers
                % Add thermal IF for humans
                oCabinPhase = this.toStores.Cabin.toPhases.CabinAir;
                thermal.procs.exme(oCabinPhase.oCapacity, ['SensibleHeatOutput_Human_',    num2str(iHuman)]);
                
                thermal.branch(this, ['SensibleHeatOutput_Human_',    num2str(iHuman)], {}, [oCabinPhase.oStore.sName '.SensibleHeatOutput_Human_',    num2str(iHuman)], ['SensibleHeatOutput_Human_',    num2str(iHuman)]);
                
                this.toChildren.(['Human_',         num2str(iHuman)]).setThermalIF(...
                                ['SensibleHeatOutput_Human_',    num2str(iHuman)]);
            end
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Cabin_Constant_Temperature');
            this.toStores.Cabin.toPhases.CabinAir.oCapacity.addHeatSource(oHeatSource);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Cabin2_Constant_Temperature');
            this.toStores.Cabin2.toPhases.CabinAir.oCapacity.addHeatSource(oHeatSource);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.O2_to_Cabin);
            solver.matter.manual.branch(this.toBranches.O2_to_Cabin2);
            
            this.toBranches.O2_to_Cabin.oHandler.setFlowRate(0.816/(24*3600));
            
            csStores = fieldnames(this.toStores);
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    
                    tTimeStepProperties = struct();
                    
                    tTimeStepProperties.fMaxStep = 60;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                    
                    oPhase.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
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
            
            if this.oTimer.fTime > 3*24*3600 && ~this.bHumanMoved
                
                for iCrewMember = 1:this.iNumberOfCrewMembers
                    this.toChildren.(['Human_', num2str(iCrewMember)]).moveHuman(this.toStores.Cabin2.toPhases.CabinAir)
                end
                
                this.toBranches.O2_to_Cabin.oHandler.setFlowRate(0);
                this.toBranches.O2_to_Cabin2.oHandler.setFlowRate(0.816/(24*3600));
                
                afCondensateFlow = zeros(1, this.oMT.iSubstances);
                this.toStores.Cabin.toProcsP2P.Condensate.setFlowRate(afCondensateFlow);
                
                afCondensateFlow(this.oMT.tiN2I.H2O) = this.iNumberOfCrewMembers * 1.5 / (24 * 3600);
                this.toStores.Cabin2.toProcsP2P.Condensate.setFlowRate(afCondensateFlow);

                afCO2Flow = zeros(1, this.oMT.iSubstances);
                this.toStores.Cabin.toProcsP2P.CO2.setFlowRate(afCO2Flow);
                afCO2Flow(this.oMT.tiN2I.CO2) = this.iNumberOfCrewMembers * 1.04 / (24 * 3600);
                this.toStores.Cabin2.toProcsP2P.CO2.setFlowRate(afCO2Flow)
            
            end
            
            this.oTimer.synchronizeCallBacks();
        end
     end
    
end

