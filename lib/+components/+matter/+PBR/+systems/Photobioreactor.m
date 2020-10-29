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
   
            if isfield(txPhotobioreactorProperties, 'sLightColor') && ischar(txPhotobioreactorProperties.fTimeStep)
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
          
            
            %% set initial values to 0
            this.fTotalProducedWater = 0; %[kg]
            this.fTotalProcessedUrine = 0; %[kg]
            
            
            %% instantiate Chlorella In Media System Object
            components.matter.algae.systems.ChlorellaInMedia(this, 'ChlorellaInMedia');
            
            
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
            matter.store(this, 'MediumMaintenance', 1);
            %NO3 is currently defined as liquid because it can only exist in solution. should this be changed?
            
            fMassNO3 = 100;
            fMolNO3 = fMassNO3 / this.oMT.ttxMatter.NO3.fMolarMass; % kg/kg/mol = mol
            fMassKplus = fMolNO3 * this.oMT.ttxMatter.Kplus.fMolarMass; % kg
            
            matter.phases.mixture(this.toStores.MediumMaintenance, 'NO3Supply','solid', struct('NO3',fMassNO3, 'Kplus', fMassKplus), 293, 1e5); %only nitrate added since Na would just remain in water adn wouldn't be used by the algae model or any of its calculations
            
            matter.phases.liquid(this.toStores.MediumMaintenance, 'WaterSupply', struct('H2O', 100), 293, 1e5); %take temperature and pressure from somewhere else?
            matter.phases.mixture(this.toStores.MediumMaintenance, 'UrineSupplyBuffer', 'liquid', struct('C2H6O2N2', 0.01475, 'H2O', 0.4), 295, 101325);
            
            
            %exmes to growth medium
            matter.procs.exmes.mixture(this.toStores.MediumMaintenance.toPhases.NO3Supply, 'NO3_to_Medium');
            matter.branch(this, 'NO3_Medium', {}, 'MediumMaintenance.NO3_to_Medium');
            
            matter.procs.exmes.liquid(this.toStores.MediumMaintenance.toPhases.WaterSupply, 'Water_to_Medium');
            matter.branch(this, 'Water_Medium',{}, 'MediumMaintenance.Water_to_Medium');
            
            %urine exme and branch to parent sys (urine store in cabin)
            matter.procs.exmes.mixture(this.toStores.MediumMaintenance.toPhases.UrineSupplyBuffer, 'UrineFromParent');
            matter.branch(this,'MediumMaintenance.UrineFromParent',{}, 'Urine_Cabin', 'Urine_from_Cabin');
            
            %urine exme and branch into medium
            %urine exme and branch to child sys (urine store in cabin)
            matter.procs.exmes.mixture(this.toStores.MediumMaintenance.toPhases.UrineSupplyBuffer, 'UrineToMedium');
            matter.branch(this, 'Urine_Outlet', {}, 'MediumMaintenance.UrineToMedium');
            
            %% create Operations Interface (nutrient/watersupply, harvest)
            matter.store(this, 'Harvester', 0.1);
            
            matter.phases.flow.mixture(this.toStores.Harvester, 'FlowThrough', 'liquid', struct('H2O', 1), 303, 1e5); %flow through pase which is connected to the growth medium and used for harvesting. medium constantly circulated between this flow phase and the growth chamber.
            matter.phases.liquid(this.toStores.Harvester, 'WaterHarvest', struct('H2O', 10), 293, 1e5); %phase where harvested water goes to
            matter.phases.mixture(this.toStores.Harvester, 'ChlorellaHarvest','liquid', struct('Chlorella', 0.1), 293,1e5); %phase where harvested chlorella goes to. Program is extremely slow if solid is used for this
            
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
        
        %be aware of naming convention:the outlet of the cabin is connected
        %to the inlet of the PBR
        function setIfFlows(this, sAir_Inlet, sAir_Outlet, sWater_Outlet, sUrine_Inlet, sChlorella_Outlet)
            this.connectIF( 'Air_Inlet',sAir_Inlet);
            this.connectIF( 'Air_Outlet',sAir_Outlet);
            this.connectIF('To_Potable', sWater_Outlet);
            this.connectIF('Urine_Cabin', sUrine_Inlet);
            this.connectIF( 'Chlorella_Outlet',sChlorella_Outlet);
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %air supply from cabin, constant flow
            solver.matter.manual.branch(this.toBranches.Air_From_Cabin);
            this.toBranches.Air_From_Cabin.oHandler.setFlowRate(-0.1);
            
            %air back to cabin. changed from flwo to PBR through consumed CO2 or
            %produced oxygen
            solver.matter_multibranch.iterative.branch(this.toBranches.Air_To_Cabin, 'complex');
            
            %potable water that is produced by aglae is directly pushed to
            %cabin potable water phase
            solver.matter.residual.branch(this.toBranches.WaterHarvest_to_Potable);
            
            %Chlorella harvest
            solver.matter.manual.branch(this.toBranches.ChlorellaHarvest_to_Cabin);
            
            %urine supply from cabin to PBR and passed to Chlorella in
            %media system.
            solver.matter.manual.branch(this.toBranches.Urine_from_Cabin); %residual does not seem to work here. workaround with two manuals that are set equally.
            
            arMaxChange = zeros(1,this.oMT.iSubstances);
            arMaxChange(this.oMT.tiN2I.H2O) = 0.1;
            arMaxChange(this.oMT.tiN2I.CO2) = 0.1;
            arMaxChange(this.oMT.tiN2I.O2)  = 0.1;
            tTimeStepProperties.arMaxChange =arMaxChange;
            tTimeStepProperties.rMaxChange = 0.05;
            
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
            
            %since residual solver does not work on this buffer phase, this
            %manual solver (parent to this) just uses the same flow rate as
            %its corresponding branch to the child sys (this to child)
            if this.toStores.MediumMaintenance.toPhases.UrineSupplyBuffer.fMass < 0.3
                if this.toBranches.Urine_from_Cabin.coExmes{2}.oPhase.fMass > 0.3 && ~this.toBranches.Urine_from_Cabin.oHandler.bMassTransferActive
                    this.toBranches.Urine_from_Cabin.oHandler.setMassTransfer(-0.1, 60);
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
