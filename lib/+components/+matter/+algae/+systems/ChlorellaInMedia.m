classdef ChlorellaInMedia < vsys
    %CHLORELLAINMEDIA is the representation of the dynamic Chlorella
    %Vulgaris model in a growth medium. This class connects the growth
    %chamber matter phases with the calculation modules to simulate algal
    %growth.  It is called by a photobioreactor parent system, which sets
    %important operational and geometry parameters
    
    properties
        %phase contents
        oBBMComposition                 %object that calculates the initial composition of Bold's Basal Medium
        tfGrowthChamberComponents       %struct of [Kg] that contains all components of growth chamber: BBM + Initial Chlorella Mass
        fInitialChlorellaMass           %[kg], initial mass of chlorella added to the growth medium
        
        %calculation modules
        oGrowthRateCalculationModule    %object that represents the Growth  Rate Calculation Module, calculates growth rate
        oPhotosynthesisModule           %object that represents the Photosynthesis Module, calculates stoichiometric chlorella growth
        oPARModule                      %object that represents the Photosynthetically Active Radiation Module, calculates aailability of PAR in the growth medium
        oHeatFromPAR                    %heater object, that induces a heat load of absorbed PAR
        oMediumCooler                   %cooler object to keep temperature constant
       
        %Refill logic for solvers
        bUseUrine                       %boolean to say if urine should be used at all. set from PBR parent sys
        bNO3Refill                      %boolean to say if nitrate should be refilled. no urine used
        bNitrogenRefill                 %boolean to say if nitrogen should be refilled as nitrate or urine
        fStartNitrogenEquivalent;       %[mol] of nitrogen to which the medium should be refilled with either nitrate or urine
        fCurrentNitrogenEquivalent;     %[mol] of nitrogen to which the medium should be refilled
        bH2ORefill                      %boolean to say if water should be refilled
        
        %current phase density calculated here because needed by multiple
        %parts of sim. only needs to be calculated once in each iteration. 
        fCurrentGrowthMediumDensity     %[kg/m^3]
        
        oUrinePhase;

    end
    
    methods
        function this = ChlorellaInMedia (oParent, sName)
            this@vsys(oParent, sName, 30);
            eval(this.oRoot.oCfgParams.configCode(this));
            
            %initially set refill parameters to false for solver control logic.
            this.bNO3Refill = false;
            this.bH2ORefill = false;
            this.bUseUrine = this.oParent.bUseUrine;
            
            %initially set to 1000 kg/m3, will be calculated in first
            %calculation step.
            this.fCurrentGrowthMediumDensity = 1000; %[kg/m3]
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% calculation objects no. 1 (that provide Info to system)
            this.oGrowthRateCalculationModule = components.matter.algae.CalculationModules.GrowthRateCalculationModule.GrowthRateCalculationModule(this);
            this.oPhotosynthesisModule = components.matter.algae.CalculationModules.PhotosynthesisModule.PhotosynthesisModule(this, this.oMT);

            %% Growth Chamber Phase
            % Store volume increased slightly to accomodate density
            % differences from the mixture composition
            matter.store(this, 'GrowthChamber',this.oParent.fGrowthVolume+0.1);
            %the BBMComposition helper function sets the composition of the
            %growth medium phase according to a volume
           
            %determine growth chamber components
            this.oBBMComposition = components.matter.algae.CalculationModules.GrowthMediumModule.BBMCompositionCalculation(this.oParent.fGrowthVolume, this.oMT, this);       
            this.fStartNitrogenEquivalent = 2.9 * this.oParent.fGrowthVolume; % mol/m3 * m3 = moles of Nitrogen (no matter if urea (2N), urine solids (2N) or no3 (1N) in the medium (2N counts double when calculating the current equivalent). 2.9 mol/m3 is based on the BBM composition
            %calculate initial chlorella biomass
            this.fInitialChlorellaMass = components.matter.algae.CalculationModules.GrowthMediumModule.ChlorellaContentCalculation(this);
            %include create growth chamber content struct from BBM struct and include chlorella!
            this.tfGrowthChamberComponents = this.oBBMComposition.tfBBMComposition;
            this.tfGrowthChamberComponents.Chlorella = this.fInitialChlorellaMass;

            matter.phases.mixture(this.toStores.GrowthChamber, 'GrowthMedium', 'liquid', this.tfGrowthChamberComponents, 303, 1e5);
            
            this.toStores.GrowthChamber.createPhase('gas', 'AirInGrowthChamber', 0.05 ,struct('O2',5000, 'CO2', 59000), 293, 0.5);
            
            
            %% Air Connection to Photobioreactor Air Supply in PBR Parent System 
            %connects the air in growth chamber to where the air comes from
            %(eg. cabin air)
            %inlet flow
            matter.procs.exmes.gas(this.toStores.GrowthChamber.toPhases.AirInGrowthChamber, 'From_Outside');
            components.matter.pipe(this, 'Air_In', 0.1, 0.01); %length, diameter
            matter.branch(this, 'GrowthChamber.From_Outside', {'Air_In'}, 'Air_Inlet', 'Air_to_GrowthChamber');
            
            %outlet flow
            matter.procs.exmes.gas(this.toStores.GrowthChamber.toPhases.AirInGrowthChamber, 'To_Outside');
            components.matter.pipe(this, 'Air_Out', 0.1, 0.01); %length, diameter
            matter.branch(this, 'GrowthChamber.To_Outside', {'Air_Out'}, 'Air_Outlet', 'Air_from_GrowthChamber');
            
            %% Medium Connection to Operations Module in PBR Parent System (harvest and nutrient/water supply)
            %outlet flow of growth medium phase in algae module
            matter.procs.exmes.mixture(this.toStores.GrowthChamber.toPhases.GrowthMedium, 'To_Harvest');
            matter.branch(this, 'GrowthChamber.To_Harvest', {}, 'Medium_Outlet', 'Medium_to_Harvester');
            
            %inlet flow of growth medium phase in algae module
            matter.procs.exmes.mixture(this.toStores.GrowthChamber.toPhases.GrowthMedium,'From_Harvest');
            components.matter.pipe(this, 'Pipe', 0.1, 0.1, 2e-3);
            matter.branch(this, 'GrowthChamber.From_Harvest', {'Pipe'}, 'Medium_Inlet', 'Medium_from_Harvester');
            %  matter.branch(this, 'Medium_Inlet', {'Medium_In'}, 'GrowthChamber.From_Harvest', 'Medium_from_Harvester');
            
            %NO3 Supply
            matter.procs.exmes.mixture(this.toStores.GrowthChamber.toPhases.GrowthMedium, 'NO3_In');
            matter.branch(this, 'GrowthChamber.NO3_In', {}, 'NO3_Inlet', 'NO3_from_Maintenance');

            
            %Urine Supply
            matter.procs.exmes.mixture(this.toStores.GrowthChamber.toPhases.GrowthMedium, 'Urine_In');
            matter.branch(this, 'GrowthChamber.Urine_In', {}, 'Urine_PBR', 'Urine_from_PBR');
            
            %Water Supply
            matter.procs.exmes.mixture(this.toStores.GrowthChamber.toPhases.GrowthMedium, 'H2O_In');
            matter.branch(this, 'GrowthChamber.H2O_In', {}, 'H2O_Inlet', 'H2O_from_Maintenance');
            
            
            %% P2P
            %define exmes for p2p processors
            matter.procs.exmes.gas(this.toStores.GrowthChamber.toPhases.AirInGrowthChamber, 'CO2_to_Medium');
            matter.procs.exmes.mixture(this.toStores.GrowthChamber.toPhases.GrowthMedium, 'CO2_from_Air');
            
            matter.procs.exmes.gas(this.toStores.GrowthChamber.toPhases.AirInGrowthChamber, 'O2_from_Medium');
            matter.procs.exmes.mixture(this.toStores.GrowthChamber.toPhases.GrowthMedium, 'O2_to_Air');
            
            %create stationary p2p               oStore                         sName              sPhaseOut(if flow pos)             sPhaseIn(if flow pos)       sSubstance
            components.matter.algae.P2P.AtmosphericGasExchange(this.toStores.GrowthChamber, 'CO2_Water_In_Out', 'AirInGrowthChamber.CO2_to_Medium', 'GrowthMedium.CO2_from_Air', 'CO2');
            components.matter.algae.P2P.AtmosphericGasExchange(this.toStores.GrowthChamber, 'O2_Water_In_Out', 'AirInGrowthChamber.O2_from_Medium', 'GrowthMedium.O2_to_Air', 'O2');
            
            %% Manipulator
            %create manipulators
            %growth medium changes consists of all components that are
            %either used or generated in the system including a detailed pH
            %calculation
            components.matter.algae.manipulators.GrowthMediumChanges('GrowthMediumChanges_Manip', this.toStores.GrowthChamber.toPhases.GrowthMedium);
            
            
            %% more calculation objects no. 2 (that need Info from system)
            %set relative growth calculation objects in the growth rate calculation module that need
            %input from the system
            this.oGrowthRateCalculationModule.oTemperatureLimitation = components.matter.algae.CalculationModules.GrowthRateCalculationModule.TemperatureLimitation(this.toStores.GrowthChamber.toPhases.GrowthMedium);
            this.oGrowthRateCalculationModule.oPhLimitation = components.matter.algae.CalculationModules.GrowthRateCalculationModule.PHLimitation(this.toStores.GrowthChamber.toPhases.GrowthMedium);
            this.oGrowthRateCalculationModule.oO2Limitation = components.matter.algae.CalculationModules.GrowthRateCalculationModule.OxygenLimitation(this.toStores.GrowthChamber.toPhases.GrowthMedium);
            this.oGrowthRateCalculationModule.oCO2Limitation = components.matter.algae.CalculationModules.GrowthRateCalculationModule.CarbonDioxideLimitation(this.toStores.GrowthChamber.toPhases.GrowthMedium);
            this.oGrowthRateCalculationModule.oPARLimitation = components.matter.algae.CalculationModules.GrowthRateCalculationModule.PARLimitation(this.toStores.GrowthChamber.toPhases.GrowthMedium);
            
            %create PAR Module
            this.oPARModule = components.matter.algae.CalculationModules.PARModule.PARModule(this);
            %connect PAR Module with PAR limitation calculation object
            this.oGrowthRateCalculationModule.oPARLimitation.oPARModule = this.oPARModule;
        end
        
        %interface to PBR sys
        function setIfFlows(this, sAir_Inlet, sAir_Outlet, sMedium_Outlet, sMedium_Inlet, sNO3_Inlet, sH2O_Inlet, sUrine_PBR)
            %this function connects the system and subsystem level branches
            %with each other. it uses the connectIf function provided by
            %the matter.container class
            
            this.connectIF('Air_Inlet', sAir_Inlet);
            this.connectIF('Air_Outlet', sAir_Outlet);
            this.connectIF('Medium_Outlet', sMedium_Outlet);
            this.connectIF('Medium_Inlet', sMedium_Inlet);
            this.connectIF('NO3_Inlet', sNO3_Inlet);
            this.connectIF('H2O_Inlet', sH2O_Inlet);
            this.connectIF('Urine_PBR', sUrine_PBR);
        end
        
        
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %% air connection
            solver.matter.manual.branch(this.toBranches.Air_to_GrowthChamber);
            solver.matter.residual.branch(this.toBranches.Air_from_GrowthChamber);
            
            %Since interfaces always have to be on the right side in the subsystem branches that are supposed to transport matter into the subsystem always have a negative flow rate.
            
            this.toBranches.Air_to_GrowthChamber.oHandler.setFlowRate(-0.1);

            
            %% medium to harvest
            solver.matter.manual.branch(this.toBranches.Medium_to_Harvester);
            solver.matter_multibranch.iterative.branch(this.toBranches.Medium_from_Harvester, 'complex');
            
            this.toBranches.Medium_to_Harvester.oHandler.setVolumetricFlowRate(this.oParent.fVolumetricFlowToHarvester); %equals to 25ml/min as referenced in tobias paper @IAC18

            this.oUrinePhase = this.toBranches.Urine_from_PBR.coExmes{2}.oPhase;
            
            %% NO3, Urine, Phosphate and Water Supply
            solver.matter.manual.branch(this.toBranches.NO3_from_Maintenance);
            solver.matter.manual.branch(this.toBranches.H2O_from_Maintenance);
            %Urine Supply from PBR
            solver.matter.manual.branch(this.toBranches.Urine_from_PBR);
            this.setThermalSolvers();
        end
        %%
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            %% heat sources
            % PAR module
            % Create a heat source with 0W of thermal power beeing
            % generated. Positive values increase the temperature of the
            % capacity, negative values reduce it. Power changed from exec.
            this.oHeatFromPAR = thermal.heatsource('Heater', 0);
            % Add the heat source to the capacity
            this.toStores.GrowthChamber.toPhases.GrowthMedium.oCapacity.addHeatSource(this.oHeatFromPAR);
            
            %Add cooler to maintain temperature in medium
            this.oMediumCooler = thermal.heatsource('Cooler', 0);
            this.toStores.GrowthChamber.toPhases.GrowthMedium.oCapacity.addHeatSource(this.oMediumCooler);
            
        end
        
    end
    
    methods (Access = protected)
        function exec(this, ~)
            %calculate current growth medium density
            %currently deactivated because causes error after a certain sim time ( Cell
            %contents indices must be greater than 0, Error in matter.table/calculateDensity (line 175), tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};)
            this.fCurrentGrowthMediumDensity = this.oMT.calculateDensity(this.toStores.GrowthChamber.toPhases.GrowthMedium);
            
            %% Update Modules
            %update PAR Module
            this.oPARModule.update;
            %calculate possible growth rate (could think about updating
            %that from within the PS to chlorella fucntion in the Growth
            %medium changes manip
            this.oGrowthRateCalculationModule.update;
            %photosynthesis and pH calculation in medium are automatically
            %udpated through manipulator. P2P through pases.
            
            %% heat
            %from light
            % Set the heat flow of the heat source to what is passed back
            % from the light module. For now, cooler just takes away that
            % heat power. could implement something more complex
            this.oHeatFromPAR.setHeatFlow(this.oPARModule.fHeatPower);
            this.oMediumCooler.setHeatFlow(-this.oPARModule.fHeatPower);
            
            %% nitrogen resupply logic
            %depends if urine should be used or not.
            
            if this.bUseUrine == false
                %NO3 Supply, No Urine
                %NO3 supply
                %if only 10 % of the initial NO3 mass are left, start
                %refilling and stop when full only NO3 supply with hysteresis behavior through boolean
                if this.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.NO3) < 0.1 * this.tfGrowthChamberComponents.NO3
                    %start refilling nitrate when it is low
                    this.bNO3Refill = true;
                    this.toBranches.NO3_from_Maintenance.oHandler.setFlowRate((-this.tfGrowthChamberComponents.NO3)/(5*this.fTimeStep)); %[kg/s]designed so it will refill the NO3 within 5 timesteps.
                elseif this.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.NO3) >=  this.tfGrowthChamberComponents.NO3
                    this.bNO3Refill = false;
                    this.toBranches.NO3_from_Maintenance.oHandler.setFlowRate(0); %set to 0 when target is reached or surpassed
                end
                
                if this.bNO3Refill == true
                    this.toBranches.NO3_from_Maintenance.oHandler.setFlowRate((-this.fStartNitrogenEquivalent * this.oMT.ttxMatter.NO3.fMolarMass)/(5*this.fTimeStep)); %designed so it will refill the NO3 within 10 timesteps.
                elseif this.bNO3Refill == false
                    this.toBranches.NO3_from_Maintenance.oHandler.setFlowRate(0);
                end
                
                
                
            else
                %urine supply with added NO3 Supply if urine is not enough

                %determine nitrogen equivalent based on amout of nitrogen
                %in different nitrogen sources (urea has 2, nitrate only 1
                %nitrogen atom)
                this.fCurrentNitrogenEquivalent = (this.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.NO3)/this.oMT.ttxMatter.NO3.fMolarMass) + (2*this.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.C2H6O2N2)/this.oMT.ttxMatter.C2H6O2N2.fMolarMass) + (2*this.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.(this.oMT.tsN2S.Urea))/this.oMT.ttxMatter.(this.oMT.tsN2S.Urea).fMolarMass);
                if this.fCurrentNitrogenEquivalent < 0.1 * this.fStartNitrogenEquivalent
                    this.bNitrogenRefill = true;
                    
                elseif this.fCurrentNitrogenEquivalent > this.fStartNitrogenEquivalent
                    this.bNitrogenRefill = false;
                end
                
                %hysteresis behaior through boolean
                if this.bNitrogenRefill == true
                    %check if enough urine is available without running into
                    %mass losses. if not, use no3 to refill.
                    if this.oUrinePhase.fMass > 0.1
                        %refill with urine as long as its available
                        this.toBranches.NO3_from_Maintenance.oHandler.setFlowRate(0);
                        this.toBranches.Urine_from_PBR.oHandler.setVolumetricFlowRate(-0.8*this.oParent.fVolumetricFlowToHarvester); %0.8 is used to make it smaller than the harvesting flow, to not cause any mass loss problems.
                    else
                        %refill with nitrate when no urine is available
                        this.toBranches.Urine_from_PBR.oHandler.setFlowRate(0);
                        fRequiredNitrateMass = this.fStartNitrogenEquivalent * this.oMT.ttxMatter.NO3.fMolarMass;
                        fRequiredPotassium   = this.fStartNitrogenEquivalent * this.oMT.ttxMatter.Kplus.fMolarMass;
                        
                        this.toBranches.NO3_from_Maintenance.oHandler.setFlowRate((-(fRequiredNitrateMass + fRequiredPotassium))/(5*this.fTimeStep)); %designed so it will refill the NO3 within 10 timesteps.
                    end
                   
                elseif this.bNitrogenRefill == false
                    %when nitrogen is refilled (no matter if nitrate or
                    %urine), then stop flows.
                    this.toBranches.Urine_from_PBR.oHandler.setFlowRate(0); %[kg/s]
                    this.toBranches.NO3_from_Maintenance.oHandler.setFlowRate(0); %[kg/s]
                end
            end
                      
            %% H2O resupply logic 
            %fresh H2O will be hardly used when urine is used.
            %if less than 95 % of the initial H2O Mass are available,
            %refill with hysteresis behaior through boolean.
            
            if this.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.H2O) < 0.95 * this.tfGrowthChamberComponents.H2O
                this.bH2ORefill = true;
            elseif this.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.H2O) >= this.tfGrowthChamberComponents.H2O
                this.bH2ORefill = false;
            end
            
            if this.bH2ORefill == true
                this.toBranches.H2O_from_Maintenance.oHandler.setFlowRate(-this.tfGrowthChamberComponents.H2O/(5*this.fTimeStep)); %[kg/s] designed so it will refill the H2O within 5 timesteps.
            elseif this.bH2ORefill == false
                this.toBranches.H2O_from_Maintenance.oHandler.setFlowRate(0); %[kg/s] set to 0 when target is reached or surpassed
            end

            %% update everything
            exec@vsys(this)
            
            
        end
    end
    
    
end
