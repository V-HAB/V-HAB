classdef Photobioreactor < vsys
    %PHOTOBIOREACTOR is the class that sets operational and geometric
    %boundaries for the device in which the Chlorella vulgaris algae grow.
    %The reactor size is defined by setting the growth volume and depth
    %below surface (important parameter for the photosynthetically active
    %radiation module) for the algal culture. The membrane surface and
    %thickness, as well as the membrane type (different commercially
    %available membranes available to select from) are defined. The
    %radiation conditions are set by defining the photosynthetic photon
    %flux density on the reactor surface and the light color. Furthermore,
    %the use of urine to supply nutrients can be activated. The PBR system
    %is a child system to a cabin in which it is integrated and holds a
    %chlorella in media system (i.e. dynamic alage model) as a child
    %system.
    
    properties (SetAccess = protected, GetAccess = public)
        
        %size properties
        fGrowthVolume               %[m3] PBR medium Volume
        sLightColor                 %string that specifies the radiation source. can be chosen from selection in PAR module class constructor
        fDepthBelowSurface          %[m] depth of the photobioreactor below the irradiated surface
        fSurfacePPFD                %[µmol/m2s]
        fNominalSurfacePPFD
        
        %membrane properties
        fMembraneSurface            %[m2]
        fMembraneThickness          %[m]
        sMembraneMaterial           %string to select which membrane shall be used. options are specified in the air exchange P2P
        
        %maintenance properties
        fCirculationVelocity;       %how fast is medium circulating
        fCirculationVolumetricFlowPerFilter; %[m3/s]
        fNumberOfParallelFilters;   %how many filters for Chlorella separation
        fVolumetricFlowToHarvester; % [m3/s]
        bUseUrine;                  %boolean to specify if urine shall be used
        
        fTotalProcessedUrine;       %[kg]
        fTotalProducedWater;        %[kg]calculated in water harvester P2p
        
        fPower = 0;                 % [W] current power demand of the PBR
        
        % This boolean can be used to decide whether the system should
        % automatically try to get the urine if it is required or if the
        % user will specify a urine supply logic in the parent system
        bManualUrineSupply      = false;
        % Nitrate can be supplied instead of urine, but  the reactor will
        % use urine if available. Set urine supply to manual to prevent
        % that
        bManualNitrateSupply    = false;
        bManualWaterSupply      = false;
        
        tControlParameters;
    end
    
    methods
        function this = Photobioreactor(oParent, sName,txPhotobioreactorProperties)
            %two or three inputs are allowed. If third input is specified,
            %it has to be a struct.
            if ~exist('txPhotobioreactorProperties','var')
                %if input is not specified, create an empty struct
               txPhotobioreactorProperties =struct(); 
            end
            
            if ~isstruct(txPhotobioreactorProperties)
                %throw an error if input was specified but is not a struct.
                error('The third input must be a structure.')
            end
   
            if isfield(txPhotobioreactorProperties, 'fTimeStep') && isnumeric(txPhotobioreactorProperties.fTimeStep)
                fTimeStep = txPhotobioreactorProperties.fTimeStep;
            else
                fTimeStep = 30;
            end
            this@vsys(oParent, sName, fTimeStep)
            eval(this.oRoot.oCfgParams.configCode(this));
            
            %% set Photobioreactor properties by checking if an input is specified
            
            % lighting properties
            if isfield(txPhotobioreactorProperties, 'sLightColor') && ischar(txPhotobioreactorProperties.sLightColor)
                this.sLightColor = txPhotobioreactorProperties.sLightColor;
            else
                this.sLightColor = 'RedExperimental'; %options:Red, Blue, Yellow, Green, Daylight, RedExperimental
            end
            
            if isfield(txPhotobioreactorProperties, 'fSurfacePPFD') && ~isnan(txPhotobioreactorProperties.fSurfacePPFD)
                this.fSurfacePPFD = txPhotobioreactorProperties.fSurfacePPFD; %[µmol/m2s] best performance when selecting a value at or just below inhibition -> maximum of PBR in saturated growth zone. Above inhibition growth would be inhibited
            else
                this.fSurfacePPFD = 400; %[µmol/m2s] best performance when selecting a value at or just below inhibition -> maximum of PBR in saturated growth zone. Above inhibition growth would be inhibited
            end
            this.fNominalSurfacePPFD = this.fSurfacePPFD;
            
            % size properties
            if isfield(txPhotobioreactorProperties, 'fGrowthVolume') && ~isnan(txPhotobioreactorProperties.fGrowthVolume)
                this.fGrowthVolume = txPhotobioreactorProperties.fGrowthVolume;
            else
                this.fGrowthVolume = 0.5;     %[m3]
            end
            
            if isfield(txPhotobioreactorProperties, 'fDepthBelowSurface') && ~isnan(txPhotobioreactorProperties.fDepthBelowSurface)
                this.fDepthBelowSurface = txPhotobioreactorProperties.fDepthBelowSurface;  %[m]
            else
                this.fDepthBelowSurface = 0.0025;  %[m]
            end
            
            
            % Air to and from PBR, Interface Properties
            %define interface to where Algae should take air from (pass
            %object into Exme)
            if isfield(txPhotobioreactorProperties, 'fMembraneSurface') && ~isnan(txPhotobioreactorProperties.fMembraneSurface)
                this.fMembraneSurface = txPhotobioreactorProperties.fMembraneSurface;
            else
                this.fMembraneSurface = 10; %[m2]
            end
            
            if isfield(txPhotobioreactorProperties, 'fMembraneThickness') && ~isnan(txPhotobioreactorProperties.fMembraneThickness)
                this.fMembraneThickness = txPhotobioreactorProperties.fMembraneThickness;
            else
                this.fMembraneThickness = 0.0001; %[m]
            end
            
            if isfield(txPhotobioreactorProperties, 'sMembraneMaterial') && ischar(txPhotobioreactorProperties.sMembraneMaterial)
                this.sMembraneMaterial = txPhotobioreactorProperties.sMembraneMaterial;
            else
                this.sMembraneMaterial = 'SSP-M823 Silicone'; %other option is 'none' or 'Cole Parmer Silicone'
            end
            
            
            % Operational and Harvesting Parameters        
            if isfield(txPhotobioreactorProperties, 'fCirculationVolumetricFlowPerFilter') && ~isnan(txPhotobioreactorProperties.fCirculationVolumetricFlowPerFilter)
                this.fCirculationVolumetricFlowPerFilter = txPhotobioreactorProperties.fCirculationVolumetricFlowPerFilter; %[m3/s]
            else
                this.fCirculationVolumetricFlowPerFilter = 4.167*10^-7; %[m3/s] equal to 25ml/min. from Niederwieser 2018 (thesis reference [5])  with reference to E. H. Gomez, ?DEVELOPMENT OF A CONTINUOUS FLOW ULTRASONIC HARVESTING SYSTEM FOR MICROALGAE,? PhD Thesis, Colorado State University, Fort Collins, CO, 2014. Thesis Reference [110]
            end
            
            if isfield(txPhotobioreactorProperties, 'fNumberOfParallelFilters') && ~isnan(txPhotobioreactorProperties.fNumberOfParallelFilters)
                this.fNumberOfParallelFilters = txPhotobioreactorProperties.fNumberOfParallelFilters; %number
            else
                this.fNumberOfParallelFilters = 30; %number
            end
            
            if isfield(txPhotobioreactorProperties, 'bUseUrine') && islogical(txPhotobioreactorProperties.bUseUrine)
                this.bUseUrine = true; %should urine be used for supply or just nitrate (then set to false).
            else
                this.bUseUrine = true; %should urine be used for supply or just nitrate (then set to false).
            end
            this.fVolumetricFlowToHarvester = this.fCirculationVolumetricFlowPerFilter * this.fNumberOfParallelFilters; %%[m3/s]
          
            
            % Calculate power demands based on "Dynamic Simulation of
            % Performance and Mass, Power, and Volume prediction of an
            % Algal Life Support System", Ruck et. al, 2019, ICES-2019-207
            % Here we use linear scaling for the light and linear scaling
            % for all other power consumptions based on growth volume and
            % light
            fLightPowerDemand = (this.fSurfacePPFD/400) * 4000;
            fBasePowerDemandOther = (this.fSurfacePPFD/400) * (this.fGrowthVolume/0.5) * 3300;
            % It is not considered feasible to turn the PBR off, as that
            % would require modelling how to do that and what a minimal
            % operating mode would be to maintain algae and start it up
            % again
            this.fPower = fBasePowerDemandOther + fLightPowerDemand;
            
            %% set initial values to 0
            this.fTotalProducedWater = 0; %[kg]
            this.fTotalProcessedUrine = 0; %[kg]
            
            
            %% instantiate Chlorella In Media System Object
            components.matter.algae.systems.ChlorellaInMedia(this, 'ChlorellaInMedia');
            
            
        end
        
        function setUrineSupplyToManual(this, bManualUrineSupply)
            this.bManualUrineSupply = bManualUrineSupply;
        end
        function setNitrateSupplyToManual(this, bManualNitrateSupply)
            this.bManualNitrateSupply = bManualNitrateSupply;
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% create Air in PBR Phase
            matter.store(this, 'ReactorAir',1);
            %interface to cabin air
            this.toStores.ReactorAir.createPhase('gas', 'flow', 'CabinAirFlow', 0.001, struct('N2',8e4, 'O2',2e4, 'CO2', 50), 293, 0.5);
            %high carbon dioxide content air for better transport through
            %membrane into medium. Be aware of possibly too high
            %concentrations of carbon dioxide.
            this.toStores.ReactorAir.createPhase('gas', 'HighCO2Air', 0.5, struct('O2',5000, 'CO2', 59000), 293, 0.5);
            
            %% air interfaces
            % air interface to cabin
            matter.procs.exmes.gas(this.toStores.ReactorAir.toPhases.CabinAirFlow, 'From_Cabin');
            matter.procs.exmes.gas(this.toStores.ReactorAir.toPhases.CabinAirFlow, 'To_Cabin');
            matter.branch(this, 'ReactorAir.From_Cabin', {}, 'Air_Inlet', 'Air_From_Cabin');
            
            components.matter.pipe(this, 'Pipe', 0.1, 0.1, 2e-3);
            matter.branch(this,'ReactorAir.To_Cabin', {'Pipe'}, 'Air_Outlet', 'Air_To_Cabin');
            
            %exmes for CO2 to high co2 content and o2 (P2P connection
            matter.procs.exmes.gas(this.toStores.ReactorAir.toPhases.CabinAirFlow, 'CO2_to_High');
            matter.procs.exmes.gas(this.toStores.ReactorAir.toPhases.CabinAirFlow, 'O2_from_High');
            matter.procs.exmes.gas(this.toStores.ReactorAir.toPhases.HighCO2Air, 'CO2_from_Cabin');
            matter.procs.exmes.gas(this.toStores.ReactorAir.toPhases.HighCO2Air, 'O2_to_Cabin');
            
            %pumps that regulate the partial pressures in the growth
            %chamber
            components.matter.PBR.P2P.CO2Pump(this.toStores.ReactorAir, 'CO2Pump', 'CabinAirFlow.CO2_to_High', 'HighCO2Air.CO2_from_Cabin', this);
            components.matter.PBR.P2P.O2Pump(this.toStores.ReactorAir, 'O2Pump', 'HighCO2Air.O2_to_Cabin', 'CabinAirFlow.O2_from_High', this);
            
            % create Interface to algae module (parent to child system connection)
            %flow to algae module
            matter.procs.exmes.gas(this.toStores.ReactorAir.toPhases.HighCO2Air, 'Air_to_Algae');
            matter.branch(this, 'Air_to', {}, 'ReactorAir.Air_to_Algae');
            
            %flow from algae module
            matter.procs.exmes.gas(this.toStores.ReactorAir.toPhases.HighCO2Air, 'Air_from_Algae');
            matter.branch(this, 'Air_from', {}, 'ReactorAir.Air_from_Algae');
            
            %% create medium maintenance (store with nutrients and water)
            matter.store(this, 'MediumMaintenance', 1 + this.fGrowthVolume);
            %NO3 is currently defined as liquid because it can only exist in solution. should this be changed?
            
            fMolNO3    =  2.9 * this.fGrowthVolume; % 2.9 mol/m³
            fMassNO3   = fMolNO3 * this.oMT.afMolarMass(this.oMT.tiN2I.NO3); % kg/kg/mol = mol
            fMassKplus = fMolNO3 * this.oMT.ttxMatter.Kplus.fMolarMass; % kg
            
            % assume highly concentrated nitrate
            fWaterMass = 0.1 * fMassNO3;
            
            matter.phases.mixture(this.toStores.MediumMaintenance, 'NO3Supply','solid', struct('H2O', fWaterMass, 'NO3',fMassNO3, 'Kplus', fMassKplus), 293, 1e5); %only nitrate added since Na would just remain in water adn wouldn't be used by the algae model or any of its calculations
            % Sufficient water to refill the growth volume once
            matter.phases.liquid(this.toStores.MediumMaintenance, 'WaterSupply', struct('H2O', 1.1 * this.fGrowthVolume), 293, 1e5); %take temperature and pressure from somewhere else?
            matter.phases.mixture(this.toStores.MediumMaintenance, 'UrineSupplyBuffer', 'liquid', struct('CH4N2O', 0.1475 * this.fGrowthVolume, 'H2O', 4 * this.fGrowthVolume), 295, 101325);
            
            this.tControlParameters.fInitialMassNO3Supply   = this.toStores.MediumMaintenance.toPhases.NO3Supply.fMass;
            this.tControlParameters.fInitialMassWaterSupply = this.toStores.MediumMaintenance.toPhases.WaterSupply.fMass;
            this.tControlParameters.fInitialMassUrineBuffer = this.toStores.MediumMaintenance.toPhases.UrineSupplyBuffer.fMass;
            
            %exmes to growth medium
            matter.procs.exmes.mixture(this.toStores.MediumMaintenance.toPhases.NO3Supply, 'NO3_to_Medium');
            matter.procs.exmes.mixture(this.toStores.MediumMaintenance.toPhases.NO3Supply, 'NO3_Inlet');
            matter.branch(this, 'NO3_Medium',                       {}, 'MediumMaintenance.NO3_to_Medium');
            matter.branch(this, 'MediumMaintenance.NO3_Inlet',      {}, 'NO3_Inlet',                        'NO3_Inlet');
            
            matter.procs.exmes.liquid(this.toStores.MediumMaintenance.toPhases.WaterSupply, 'Water_to_Medium');
            matter.procs.exmes.liquid(this.toStores.MediumMaintenance.toPhases.WaterSupply, 'Water_Inlet');
            matter.branch(this, 'Water_Medium',                     {}, 'MediumMaintenance.Water_to_Medium');
            matter.branch(this, 'MediumMaintenance.Water_Inlet', 	{}, 'Water_Inlet',                      'Water_Inlet');
            
            %urine exme and branch to parent sys (urine store in cabin)
            matter.procs.exmes.mixture(this.toStores.MediumMaintenance.toPhases.UrineSupplyBuffer, 'UrineFromParent');
            matter.branch(this,'MediumMaintenance.UrineFromParent',{}, 'Urine_Cabin', 'Urine_from_Cabin');
            
            %urine exme and branch into medium
            %urine exme and branch to child sys (urine store in cabin)
            matter.procs.exmes.mixture(this.toStores.MediumMaintenance.toPhases.UrineSupplyBuffer, 'UrineToMedium');
            matter.branch(this, 'Urine_Outlet', {}, 'MediumMaintenance.UrineToMedium');
            
            %% create Operations Interface (nutrient/watersupply, harvest)
            matter.store(this, 'Harvester', 0.1);
            
            matter.phases.flow.mixture(this.toStores.Harvester, 'FlowThrough', 'liquid', struct('H2O', 1), 303, 1e5); %flow through phase which is connected to the growth medium and used for harvesting. medium constantly circulated between this flow phase and the growth chamber.
            
            this.toStores.Harvester.createPhase('liquid',  'flow', 'WaterHarvest',               0.001, struct('H2O', 1), 293, 1e5);
            this.toStores.Harvester.createPhase('mixture', 'flow', 'ChlorellaHarvest', 'liquid', 0.001, struct('Chlorella', 1), 293, 1e5);
            
            %interface to growth medium phase
            matter.procs.exmes.mixture(this.toStores.Harvester.toPhases.FlowThrough, 'Liquid_from_Medium');
            matter.branch(this, 'From_Medium', {}, 'Harvester.Liquid_from_Medium');
            
            matter.procs.exmes.mixture(this.toStores.Harvester.toPhases.FlowThrough, 'Liquid_to_Medium');
            matter.branch(this, 'To_Medium', {}, 'Harvester.Liquid_to_Medium');
            
            % P2P for harvest of chlorella
            matter.procs.exmes.mixture(this.toStores.Harvester.toPhases.FlowThrough, 'Harvest_ChlorellaFlow');
            matter.procs.exmes.mixture(this.toStores.Harvester.toPhases.ChlorellaHarvest, 'Harvest_Chlorella');
            components.matter.PBR.P2P.ChlorellaHarvest(this.toStores.Harvester, 'Chlorella_Harvest_P2P', 'FlowThrough.Harvest_ChlorellaFlow', 'ChlorellaHarvest.Harvest_Chlorella', this.toChildren.ChlorellaInMedia);
            
            % P2P for harvest of water
            matter.procs.exmes.mixture(this.toStores.Harvester.toPhases.FlowThrough, 'Harvest_WaterFlow');
            matter.procs.exmes.liquid(this.toStores.Harvester.toPhases.WaterHarvest, 'Harvest_Water');
            components.matter.PBR.P2P.WaterHarvest(this.toStores.Harvester, 'Water_Harvest_P2P', 'FlowThrough.Harvest_WaterFlow','WaterHarvest.Harvest_Water', this.toChildren.ChlorellaInMedia);
            
            
            %exme and branch for water harvest to potable water in cabin
            matter.procs.exmes.liquid(this.toStores.Harvester.toPhases.WaterHarvest, 'Water_to_Cabin');
            matter.branch(this, 'Harvester.Water_to_Cabin', {}, 'To_Potable', 'WaterHarvest_to_Potable');
            
            %exme and branch for chlorella harvest to food store in cabin
            matter.procs.exmes.mixture(this.toStores.Harvester.toPhases.ChlorellaHarvest, 'Chlorella_to_Cabin');
            matter.branch(this, 'Harvester.Chlorella_to_Cabin', {}, 'Chlorella_Outlet', 'ChlorellaHarvest_to_Cabin');
            
            % calls function in child system to connect the two phases
            this.toChildren.ChlorellaInMedia.setIfFlows('Air_to', 'Air_from','From_Medium', 'To_Medium', 'NO3_Medium', 'Water_Medium', 'Urine_Outlet');
            
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            %% heat sources
            % Maintain a constant temperature for the CO2 air:
            oHeatSource = components.thermal.heatsources.ConstantTemperature('CO2_Air_TemperatureControl');
            % Add the heat source to the capacity
            this.toStores.ReactorAir.toPhases.HighCO2Air.oCapacity.addHeatSource(oHeatSource);
            
            
        end
        
        %be aware of naming convention:the outlet of the cabin is connected
        %to the inlet of the PBR
        function setIfFlows(this, sAir_Inlet, sAir_Outlet, sWater_Outlet, sUrine_Inlet, sChlorella_Outlet, sNitrateInlet, sWaterInlet)
            this.connectIF( 'Air_Inlet',        sAir_Inlet);
            this.connectIF( 'Air_Outlet',       sAir_Outlet);
            this.connectIF( 'To_Potable',       sWater_Outlet);
            this.connectIF( 'Urine_Cabin',      sUrine_Inlet);
            this.connectIF( 'Chlorella_Outlet', sChlorella_Outlet);
            this.connectIF( 'NO3_Inlet',        sNitrateInlet);
            this.connectIF( 'Water_Inlet',     	sWaterInlet);
            
        end
        
        function setOperatingMode(this, bMinimalMode)
            if bMinimalMode
                % in minimal operating mode, we limit the maximum amount of
                % CO2 that the reactor is supplied to limit algae growth
                % while keeping a valid culture alive
                this.toChildren.ChlorellaInMedia.toBranches.Air_from_GrowthChamber.oHandler.setFlowRate(1e-3);
                % Light intensity is also reduced to reduce power
                % consumption:
                this.fSurfacePPFD = 0.01 * this.fNominalSurfacePPFD;
                % We reduce the CO2 flow to 1%, so we can also assume the
                % remaining base power demand to drop, here it is assumed
                % that it drops to 10%
                fOtherPowerDemandPerVolume = 330;
            else
                this.toChildren.ChlorellaInMedia.toBranches.Air_from_GrowthChamber.oHandler.setFlowRate(0.1);
                
                this.fSurfacePPFD = this.fNominalSurfacePPFD;
                fOtherPowerDemandPerVolume = 3300;
            end
            
            % Calculate power demands based on "Dynamic Simulation of
            % Performance and Mass, Power, and Volume prediction of an
            % Algal Life Support System", Ruck et. al, 2019, ICES-2019-207
            % Here we use linear scaling for the light and linear scaling
            % for all other power consumptions based on growth volume and
            % light
            fLightPowerDemand = (this.fSurfacePPFD/400) * 4000;
            fBasePowerDemandOther = (this.fSurfacePPFD/400) * (this.fGrowthVolume/0.5) * fOtherPowerDemandPerVolume;
            % It is not considered feasible to turn the PBR off, as that
            % would require modelling how to do that and what a minimal
            % operating mode would be to maintain algae and start it up
            % again
            this.fPower = fBasePowerDemandOther + fLightPowerDemand;
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %air supply from cabin, constant flow
            solver.matter.manual.branch(this.toBranches.Air_From_Cabin);
            this.toBranches.Air_From_Cabin.oHandler.setFlowRate(-0.1);
            
            %air back to cabin. changed from flwo to PBR through consumed CO2 or
            %produced oxygen
            solver.matter_multibranch.iterative.branch([this.toBranches.Air_To_Cabin, this.toBranches.ChlorellaHarvest_to_Cabin, this.toBranches.WaterHarvest_to_Potable], 'complex');
            
            %urine supply from cabin to PBR and passed to Chlorella in
            %media system.
            solver.matter.manual.branch(this.toBranches.Urine_from_Cabin); 
            solver.matter.manual.branch(this.toBranches.NO3_Inlet); 
            solver.matter.manual.branch(this.toBranches.Water_Inlet); 
            
            arMaxChange = zeros(1,this.oMT.iSubstances);
            arMaxChange(this.oMT.tiN2I.H2O) = 0.1;
            arMaxChange(this.oMT.tiN2I.CO2) = 0.1;
            arMaxChange(this.oMT.tiN2I.O2)  = 0.1;
            tTimeStepProperties.arMaxChange = arMaxChange;
            tTimeStepProperties.rMaxChange  = 0.05;
            
            this.toStores.ReactorAir.toPhases.HighCO2Air.setTimeStepProperties(tTimeStepProperties)
            
            tTimeStepProperties = struct();
            tTimeStepProperties.fFixedTimeStep = this.fTimeStep;
            
            this.toStores.MediumMaintenance.toPhases.NO3Supply.setTimeStepProperties(tTimeStepProperties);
            this.toStores.MediumMaintenance.toPhases.WaterSupply.setTimeStepProperties(tTimeStepProperties);
            this.toStores.MediumMaintenance.toPhases.UrineSupplyBuffer.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;

                    oPhase.setTimeStepProperties(tTimeStepProperties);

                    tTimeStepProperties = struct();
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                end
            end
        end
    end
    
    methods (Access = protected)
        function exec(this,~)
            
            % Resupply urine if that is not set to manual
            if ~this.bManualUrineSupply && this.toStores.MediumMaintenance.toPhases.UrineSupplyBuffer.fMass < 0.7 * this.tControlParameters.fInitialMassUrineBuffer
                fDesiredResupply = this.tControlParameters.fInitialMassUrineBuffer - this.toStores.MediumMaintenance.toPhases.UrineSupplyBuffer.fMass;
                if this.toBranches.Urine_from_Cabin.coExmes{2}.oPhase.fMass > fDesiredResupply && ~this.toBranches.Urine_from_Cabin.oHandler.bMassTransferActive
                    this.toBranches.Urine_from_Cabin.oHandler.setMassTransfer(-fDesiredResupply, 60);
                elseif ~this.toBranches.Urine_from_Cabin.oHandler.bMassTransferActive
                    this.toBranches.Urine_from_Cabin.oHandler.setMassTransfer(-0.7 * this.toBranches.Urine_from_Cabin.coExmes{2}.oPhase.fMass, 60);
                end
            end
            
            if ~this.bManualNitrateSupply && this.toStores.MediumMaintenance.toPhases.NO3Supply.fMass < 0.7 * this.tControlParameters.fInitialMassNO3Supply
                fDesiredResupply = this.tControlParameters.fInitialMassNO3Supply - this.toStores.MediumMaintenance.toPhases.NO3Supply.fMass;
                if this.toBranches.NO3_Inlet.coExmes{2}.oPhase.fMass > fDesiredResupply && ~this.toBranches.NO3_Inlet.oHandler.bMassTransferActive
                    this.toBranches.NO3_Inlet.oHandler.setMassTransfer(-fDesiredResupply, 60);
                elseif ~this.toBranches.NO3_Inlet.oHandler.bMassTransferActive
                    this.toBranches.NO3_Inlet.oHandler.setMassTransfer(-0.7 * this.toBranches.NO3_Inlet.coExmes{2}.oPhase.fMass, 60);
                end
            end
            
            if ~this.bManualWaterSupply && this.toStores.MediumMaintenance.toPhases.WaterSupply.fMass < this.tControlParameters.fInitialMassWaterSupply
                fDesiredResupply = this.tControlParameters.fInitialMassWaterSupply - this.toStores.MediumMaintenance.toPhases.WaterSupply.fMass;
                if this.toBranches.Water_Inlet.coExmes{2}.oPhase.fMass > fDesiredResupply && ~this.toBranches.Water_Inlet.oHandler.bMassTransferActive
                    this.toBranches.Water_Inlet.oHandler.setMassTransfer(-fDesiredResupply, 60);
                elseif ~this.toBranches.Water_Inlet.oHandler.bMassTransferActive
                    this.toBranches.Water_Inlet.oHandler.setMassTransfer(-0.7 * this.toBranches.Water_Inlet.coExmes{2}.oPhase.fMass, 60);
                end
            end
            
            % Resupply nitrate if that is not set to manual
            if ~this.bManualNitrateSupply && this.toStores.MediumMaintenance.toPhases.NO3Supply.fMass < 0.3
                if this.toBranches.NO3_Inlet.coExmes{2}.oPhase.fMass > 0.3 && ~this.toBranches.NO3_Inlet.oHandler.bMassTransferActive
                    this.toBranches.NO3_Inlet.oHandler.setMassTransfer(-0.2, 60);
                end
            end
            %track how mcuh urine and water are consumed/produced. Not
            %equal, because urine is not just water!
            if this.fTimeStep>0
                this.fTotalProcessedUrine = this.fTotalProcessedUrine - this.toBranches.Urine_from_Cabin.aoFlows.fFlowRate * this.fTimeStep; %[kg]
                this.fTotalProducedWater = this.fTotalProducedWater + this.toBranches.WaterHarvest_to_Potable.aoFlows.fFlowRate * this.fTimeStep; %[kg]
            end
            
            exec@vsys(this);
        end
    end
    
end
