classdef ISS_ARS_MultiStore < vsys
    %% Simulation for the ISS Air Revitalization System (ARS) with 10 individual Modules
    % This is the model of the ISS which consists of 10 different modules
    % as well as all ARS systems. Some of them are not active.
    % In addition, a atmospherically open plant growth chamber is modeled.
    % The user can decide via an input parameter in the exec function in
    % which module the plants are located. Only one location can be chosen at a time.
    
    properties
        %Struct that contains the manual branches of the subsystem. Each
        %branch is given a specific name which makes setting the flow rates
        %easier and also makes the calls to them independent from new
        %branches that might be added later on.
        toSolverBranches;     
        
        %Property to save the flow rate of H2 that is supplied to the SCRA
        %system
        fFlowRateH2SCRA = 0;        % [kg/s]
        %Property to save the flow rate of CO2 that is supplied to the SCRA
        %system
        fFlowRateCO2SCRA = 0;       % [kg/s]
        
        %Number of Crew Members used for this simulation
        iCrewMembers = 6; % [human] ;)
        
        aoNominalCrewMemberLocations;
        mbCrewMemberCurrentlyInNode3;
        
        fControlTimeStep;
        
        % Property to decide between different cases for the simulation
        tbCases;
        
        % Property to decide between different Plant Module Locations
        sPlantLocation
        
        % Property to save the dew point of each module
        % Order: 'Node1', 'Node2', 'Node3', 'PMM', 'FGM', 'Airlock', 'SM', 'US_Lab' 'JEM', 'Columbus'
        afDewPointModules = zeros(1,10);
        
    
        % All the properties for the Plant Module. If you want to add one
        % of the plants, increase the area of the plant to the desired
        % value in the mfPlantArea struct. Currently an ISPR based PGC with
        % 4 Lettuce compartments and 4 Tomato compartments where each
        % compartment has 0.231 m^2 area is modelled.
        %
        % The values for lighting etc are based on BVAD table 4-117 and 4.96
        % Areas are assumed per crew member and are designed to supply a
        % nearly closed diet for the crew. 0 days emerge time are assumed
        % because sprouts are assumed to be grown outside the PGC and then
        % be transplanted once emerged
        iAssumedPreviousPlantGrowthDays = 78;
        csPlants        = {'Sweetpotato',   'Whitepotato',  'Rice'  , 'Drybean' , 'Soybean' , 'Tomato'  , 'Peanut'  , 'Lettuce' ,	'Wheat'};
        mfPlantArea     = [ 0           ,   0            ,  0       , 0         , 0         , 0.924     , 0         , 0.924     ,   0];       	% m^2
        mfHarvestTime   = [ 120         ,   138          ,  88      , 63        , 86        , 80        , 110       , 30        ,   62];        % days
        miSubcultures   = [ 1           ,   1            ,  1       , 1         , 1         , 4         , 1         , 4         ,   1];       	% -
        mfPhotoperiod   = [ 18          ,   12           ,  12      , 12        , 12        , 12        , 12        , 16        ,   20];      	% h/day
        mfPPFD          = [ 650         ,   650          ,  764     , 370       , 650       , 625       , 625       , 295       ,   1330];   	% micromol/m^2 s
        mfEmergeTime    = [ 0           ,   0            ,  0       , 0         , 0         , 0         , 0         , 0         ,   0];      	% days
        
        tfPlantControlParameters;
    end
    
    methods
        function this = ISS_ARS_MultiStore (oParent, sName, fControlTimeStep, tbCases, sPlantLocation)
            this@vsys(oParent, sName, -1);
            this.fControlTimeStep = fControlTimeStep;
            
            this.tbCases.ACLS           = false;
            this.tbCases.SimpleCDRA     = false;
            this.tbCases.IronRing1      = false;
            this.tbCases.IronRing2      = false;
            this.tbCases.PlantChamber   = false;
            this.tbCases.ModelInactiveSystems   = false;
            
            this.mbCrewMemberCurrentlyInNode3 = false(1,this.iCrewMembers);
            this.mbCrewMemberCurrentlyInNode3(2) = true;
            
            % Minimum time step has to be reduced, not because it is used
            % in the system but to prevent flowrates from beeing rounded
            % to zero
            this.oTimer.setMinStep(1e-12)
            
            if isfield(tbCases, 'ACLS')
                this.tbCases.ACLS = tbCases.ACLS;
            end

            if isfield(tbCases, 'SimpleCDRA')
                this.tbCases.SimpleCDRA = tbCases.SimpleCDRA;
            end

            if isfield(tbCases, 'IronRing1')
                this.tbCases.IronRing1 = tbCases.IronRing1;
            end
            
            if isfield(tbCases, 'IronRing2')
                this.tbCases.IronRing2 = tbCases.IronRing2;
            end
            
            if isfield(tbCases, 'PlantChamber')
                this.tbCases.PlantChamber = tbCases.PlantChamber;
            end
            
            if isfield(tbCases, 'ModelInactiveSystems')
                this.tbCases.ModelInactiveSystems = tbCases.ModelInactiveSystems;
            end
            
            if this.tbCases.PlantChamber
                this.sPlantLocation = sPlantLocation;
            end
            %% Adding the subsystems
            
            % Informtation received directly from people working at JSC:
            % nominally on station only one CDRA is running (Node 3 because
            % that has the sabatier) and only one CCAA in the US Lab is
            % running.
            
            % Setting of the ambient temperature used in nearly every
            % component to calculate the temperature exchange
            fAmbientTemperature = 295.35;
            %ICES 2015-27: "...history shows that the crew generally keeps 
            %the temperature inside the USOS at or above 22.2C (72F)..."
            %Here assumption that this is the nominal temperature used
            %throughout ISS 
            
            %initial relative humidity that is going to be used for every
            %air phase in the ACLS is assumed to be ~40% (nominal value
            %according to BVAD table 4.1)
            fRelHumidity = 0.4;
            
            % Temperature is from ICES-2015-27: Low temperature loop in US lab 
            % has a temperature between 4.4°c and 9.4°C.But also a document from
            % Boeing about the ECLSS states: "The LTL is designed to operate at 40° F (4° C).."
            % From Active Thermal Control System (ATCS) Overview:
            % http://www.nasa.gov/pdf/473486main_iss_atcs_overview.pdf
          	fCoolantTemperature = 277.55;
            
            % According to ICES-2017-36 "Status of ISS Water Management and
            % Recovery", Carter et. al, only one CHX is operational at the
            % same time in the US segment
            
            tAtmosphere.fTemperature = fAmbientTemperature;
            tAtmosphere.rRelHumidity = fRelHumidity;
            tAtmosphere.fPressure    = 1e5;
           	tAtmosphere.fCO2Percent  = 0.0038;
            
            % OGAs
            components.matter.OGA.OGA(this,             'OGA_Node3',    fControlTimeStep, fAmbientTemperature);
            components.matter.OGA.OGA(this,             'OGA_SM',       fControlTimeStep, 353, 1);
            
            % CCAAs
            components.matter.CCAA.CCAA(this,           'CCAA_Node3',   fControlTimeStep, fCoolantTemperature, tAtmosphere, 'CDRA_Node3');
            components.matter.CCAA.CCAA(this,           'CCAA_SM',      fControlTimeStep, fCoolantTemperature, tAtmosphere, 'Vozdukh'); 
            
            % According to ICES 2004-01-2386 paper: "Summary of Resources
            % for the International Space Station Environmental Control and
            % Life Support System for Core Complete Modules" these are
            % actual additional CCAAs that are identical to the normal US
            % However, as stated in  "Status of ISS Water Management and
            % Recovery", Carter et. al, 2016, ICES-2016-036 only of CHX in
            % the USOS is active at any given time
            if this.tbCases.ModelInactiveSystems
                components.matter.CCAA.CCAA(this,           'CCAA_USLab',   fControlTimeStep, fCoolantTemperature, tAtmosphere, 'CDRA_USLab', 0);
                components.matter.CCAA.CCAA(this,           'CCAA_Airlock', fControlTimeStep, fCoolantTemperature, tAtmosphere);
                components.matter.CCAA.CCAA(this,           'CCAA_Node2',   fControlTimeStep, fCoolantTemperature, tAtmosphere);
                components.matter.CCAA.CCAA(this,           'CCAA_USLab2',  fControlTimeStep, fCoolantTemperature, tAtmosphere);
            end
            
            % TO DO: At the moment just modeled as another CCAA but should
            % be an independant model
            components.matter.CCAA.CCAA(this,           'CCAA_JEM',         fControlTimeStep, fCoolantTemperature, tAtmosphere);
            components.matter.CCAA.CCAA(this,           'CCAA_Columbus',    fControlTimeStep, fCoolantTemperature, tAtmosphere);
            
            % CDRAs
            components.matter.CDRA.CDRA(this,           'CDRA_Node3',   tAtmosphere, [], fControlTimeStep);
            components.matter.CDRA.CDRA(this,           'CDRA_USLab',   tAtmosphere, [], fControlTimeStep); 
            components.matter.CDRA.CDRA(this,           'Vozdukh',      tAtmosphere, [], fControlTimeStep);
            
            % SCRA
            components.matter.SCRA.SCRA(this,           'SCRA_Node3',   fControlTimeStep, fCoolantTemperature);
            
            % Adding the WPA
            components.matter.WPA.WPA(this,             'WPA');
            
            % Adding UPA
            components.matter.UPA.UPA(this,             'UPA');
            
            % Adding BPA
            components.matter.BPA.BPA(this,             'BPA');
            
            if this.tbCases.ACLS
                
                %in http://www.nasa.gov/pdf/473486main_iss_atcs_overview.pdf
                %the temperature of the medium temperature loop that is used
                %for ACLS is mentioned to be 17°C
                fCoolantWaterTemp = 290.1500;

                %ACLS
                puda.ACLS.systems.ACLS_Subsystem(this, 'ACLS', fRelHumidity, 293.15, fCoolantWaterTemp);

            end
            
            %% Adding the crew members
            
            % Number of days that events shall be planned goes here:
            iLengthOfMission = 10; % [d]
            
            ctEvents = cell(iLengthOfMission, this.iCrewMembers);
            
            %% Nominal Operation
            
            tMealTimes.Breakfast = 0.1*3600;
            tMealTimes.Lunch = 6*3600;
            tMealTimes.Dinner = 15*3600;
            
            for iCrewMember = 1:this.iCrewMembers
                
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
            
            for iCrewMember = 1:this.iCrewMembers
                
                txCrewPlaner.ctEvents = ctEvents(:, iCrewMember);
                txCrewPlaner.tMealTimes = tMealTimes;
                
                components.matter.DetailedHuman.Human(this, ['Human_', num2str(iCrewMember)], txCrewPlaner, 60);
                
                clear txCrewPlaner;
            end
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                   PLANT MODULE                          %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if this.tbCases.PlantChamber
                tInput = struct();
                abEmptyPlants = false(1, length(this.csPlants));
                for iPlant = 1:length(this.csPlants)
                    % The subcultures are evenly spread over the harvest
                    % time of plants. 
                    mfFirstSowTimeInit = 0 : this.mfHarvestTime(iPlant) / this.miSubcultures(iPlant) : this.mfHarvestTime(iPlant);
                    mfFirstSowTimeInit = mfFirstSowTimeInit - this.iAssumedPreviousPlantGrowthDays;
                    mfFirstSowTimeInit(end) = [];
                    mfPlantTimeInit     = zeros(length(mfFirstSowTimeInit),1);
                    mfPlantTimeInit(mfFirstSowTimeInit < 0) = -mfFirstSowTimeInit(mfFirstSowTimeInit < 0);

                    mfPlantTimeInit = mod(mfPlantTimeInit, this.mfHarvestTime(iPlant));
                    
                    for iSubculture = 1:this.miSubcultures(iPlant)
                        if this.mfPlantArea(iPlant) == 0
                            abEmptyPlants(iPlant) = true;
                            continue
                        end
                        % Custom name you want to give this specific culture, select a 
                        % name that is easy for you to identify
                        tInput(iPlant, iSubculture).sName            = [this.csPlants{iPlant}, '_', num2str(iSubculture)];
                        % Name of the plant species, has to fit the names defined in 
                        % lib/+components/*PlantModule/+plantparameters/PlantParameters.csv
                        tInput(iPlant, iSubculture).sPlantSpecies    = this.csPlants{iPlant};
                        % The growth area defines how many plants are used in the
                        % culture. Please note that depending on your application you
                        % have to set the area to represent the number of plants (see
                        % the plant density parameter in lib/+components/*PlantModule/+plantparameters/PlantParameters.csv
                        % for information on that parameter) and not the actual area.
                        % The area depends on the density of plants and can vary by
                        % some degree! (for very high density shadowing effects will
                        % come into effect)
                        tInput(iPlant, iSubculture).fGrowthArea      = this.mfPlantArea(iPlant) ./ this.miSubcultures(iPlant); % m^2
                        % time after which the plants are harvested
                        tInput(iPlant, iSubculture).fHarvestTime     = this.mfHarvestTime(iPlant); % days
                        % The time after which the first part of the plant can be seen
                        tInput(iPlant, iSubculture).fEmergeTime      = this.mfEmergeTime(iPlant); % days
                        % Particle Photon Flux Density, which is ony value to define
                        % the intensity of the light the plants receive
                        tInput(iPlant, iSubculture).fPPFD            = this.mfPPFD(iPlant); % micromol/m^2s
                        % Photoperiod in hours (time per day that the plants receive
                        % light)
                        tInput(iPlant, iSubculture).fPhotoperiod     = this.mfPhotoperiod(iPlant); % h
                        % This parameter defines how many generations of this culture
                        % are planted in succession. Here we want continoues
                        % plantation and therefore divide the mission duration
                        % with the plant harvest time and roundup
                        tInput(iPlant, iSubculture).iConsecutiveGenerations      = 1 + ceil(iLengthOfMission / this.mfHarvestTime(iPlant));
                        tInput(iPlant, iSubculture).mfSowTime        = zeros(1, tInput(iPlant, iSubculture).iConsecutiveGenerations);
                        
                        components.matter.PlantModule.PlantCulture(...
                                this, ...                   % parent system reference
                                tInput(iPlant, iSubculture).sName,...
                                this.fControlTimeStep,...          % Time step initially used for this culture in [s]
                                tInput(iPlant, iSubculture),...
                                mfPlantTimeInit(iSubculture)); % Time at which the growth of this culture is intialized
                    end
                end

                this.csPlants(abEmptyPlants)        = [];
                this.mfPlantArea(abEmptyPlants)     = [];
                this.mfHarvestTime(abEmptyPlants)   = [];
                this.miSubcultures(abEmptyPlants)   = [];
                this.mfPhotoperiod(abEmptyPlants)   = [];
                this.mfPPFD(abEmptyPlants)          = [];
                this.mfEmergeTime(abEmptyPlants)    = [];
            end
            
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            %% Creating the stores  
            % The ISS is split into seven stores for this simulation!
            % Assuming 100 cfm of inter module air flow in each direction
            
            
            % Setting of the ambient temperature used in nearly every
            % component to calculate the temperature exchange
            fAmbientTemperature = 295.35;
            %ICES 2015-27: "...history shows that the crew generally keeps 
            %the temperature inside the USOS at or above 22.2C (72F)..."
            %Here assumption that this is the nominal temperature used
            %throughout ISS 
            
            %initial relative humidity that is going to be used for every
            %air phase in the ACLS is assumed to be ~40% (nominal value
            %according to BVAD table 4.1)
            fRelHumidity = 0.4;
            
            % Temperature is from ICES-2015-27: Low temperature loop in US lab 
            % has a temperature between 4.4°c and 9.4°C.But also a document from
            % Boeing about the ECLSS states: "The LTL is designed to operate at 40° F (4° C).."
            % From Active Thermal Control System (ATCS) Overview:
            % http://www.nasa.gov/pdf/473486main_iss_atcs_overview.pdf
          	fLTL_CoolantTemperature = 277.55;
            
            %Medium Temperature Loop Coolant Temperature
            %in http://www.nasa.gov/pdf/473486main_iss_atcs_overview.pdf
            %the temperature of the medium temperature loop that is used
            %for ACLS is mentioned to be 17°C
            fMTL_CoolantTemperature = 290.15;
            
            % These are the assumed initial partial pressures for the
            % atmosphere in the ISS in Pa:
            fPP_CO2 = 400;
            fPP_O2  = 2.1e4;
            fPP_N2  = 8e4;
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                  ISS Modules                            %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            %% US Lab has 1 CDRA and 2 CCAA and ACLS
            % Assumed that 1 human is in US Lab
            fUS_LabVolume = 97.71; %according to P.Plötners Thesis
            matter.store(this, 'US_Lab', fUS_LabVolume); 
            oUSLab = this.toStores.US_Lab.createPhase(  'gas',   'US_Lab_Phase',   fUS_LabVolume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Node 1, NO LSS
            % Assumed that no human is in Node 1
            fNode1_Volume = 55.16 + 2*1.33; %according to P.Plötners Thesis with vetibules and PMA etc
            matter.store(this, 'Node1', fNode1_Volume); 
            oNode1 = this.toStores.Node1.createPhase(  'gas',   'Node1_Phase',   fNode1_Volume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Airlock, NO LSS only buffer tanks
            % Assumed that no human is in Airlock
            fAirlock_Volume = 31.38; %according to P.Plötners Thesis
            matter.store(this, 'Airlock', fAirlock_Volume); 
            oAirlock = this.toStores.Airlock.createPhase(  'gas',   'Airlock_Phase',   fAirlock_Volume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Node 3, 1 CDRA, 1 CCAA, 1 OGA, 1 SCRA
            % Assumed that one human is in Node 3
            fNode3_Volume = 62.01+1.68; %according to P.Plötners Thesis
            matter.store(this, 'Node3', fNode3_Volume); 
            oNode3 = this.toStores.Node3.createPhase(  'gas',   'Node3_Phase',   fNode3_Volume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Functional Cargo Module (FGM), NO LSS
            % Assumed that one human is in FGM
            %             FGM + MRM-1 + Vest + Soyuz + PMA + Vest(Soyuz)
            fFGM_Volume = 61  + 12.49 + 0.91 + 10.28 + 5.3 + 0.25; %according to P.Plötners Thesis
            matter.store(this, 'FGM', fFGM_Volume); 
            oFGM = this.toStores.FGM.createPhase(  'gas',   'FGM_Phase',   fFGM_Volume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Sevice Module (SM), 1 Elektron VM, 1 Vozdukh, 1 CCAA
            % Assumed that one human is in SM
            fSM_Volume = 90.53+0.91+12.49; %according to P.Plötners Thesis
            matter.store(this, 'SM', fSM_Volume); 
            oSM = this.toStores.SM.createPhase(  'gas',   'SM_Phase',   fSM_Volume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Node 2
            % Assumed that no humans are in this compartment
            %               Node2 + Vest + 2*PMA
            fNode2_Volume = 62.01 + 1.33 + 2*5.3; %according to P.Plötners Thesis
            matter.store(this, 'Node2', fNode2_Volume); 
            oNode2 = this.toStores.Node2.createPhase(  'gas',   'Node2_Phase',   fNode2_Volume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Columbus
            % Assumed that one human is in this compartment
            %                   Col  + Vest
            fColumbus_Volume = 64.02 + 1.33; %according to P.Plötners Thesis
            matter.store(this, 'Columbus', fColumbus_Volume); 
            oColumbus = this.toStores.Columbus.createPhase(  'gas',   'Columbus_Phase',   fColumbus_Volume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Japanese Experiment Module (JEM)
            % Assumed that one human is in this compartment
            %             JEM PM + JEMP PLS + 2*Vest
            fJEM_Volume = 126.66 + 39.35    + 2*1.33; %according to P.Plötners Thesis
            matter.store(this, 'JEM', fJEM_Volume); 
            oJEM = this.toStores.JEM.createPhase(  'gas',   'JEM_Phase',   fJEM_Volume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Permanent Multipurpose Module (PMM)
            % Assumed that two humans are in this compartment
            fPMM_Volume = 45.02+1.33; %according to P.Plötners Thesis
            matter.store(this, 'PMM', fPMM_Volume); 
            oPPM = this.toStores.PMM.createPhase(  'gas',   'PMM_Phase',   fPMM_Volume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            %% Creating the 'Vacuum'
            matter.store(this, 'Vacuum', 100000); % CO2, H2 and CH4 to vacuum
            oVacuum = this.toStores.Vacuum.createPhase(  'gas', 'boundary',  'Vacuum_Phase',   100000, struct('N2', 3), 3, 0);
            
            %% Creating other tanks
            % Creating the N2 tank
            fN2_TankVolume = 2;
            matter.store(this, 'N2_Tank', fN2_TankVolume); % N2 tank
            oN2 = this.toStores.N2_Tank.createPhase(  'gas',   'N2_Phase',   fN2_TankVolume, struct('N2', 100e5), fAmbientTemperature, 0);
            
            % Creating the O2 tank
            fO2_TankVolume = 2;
            matter.store(this, 'O2_Tank', fO2_TankVolume); % O2 tank
            oO2 = this.toStores.O2_Tank.createPhase(  'gas',   'O2_Tank_Phase',   fO2_TankVolume, struct('O2', 100e5), fAmbientTemperature, 0);
            
            % Creating the potable water tank of the ISS:
            % See: https://www.nasa.gov/feature/proposed-station-water-system-looks-to-retired-shuttles
            % For the information that the WSS provides about 600 l of
            % water storage capacity. Also information on this system is
            % provided in ICES-2019-36, "Status of ISSWater Management and
            % Recovery", Carter et. al. 2019
            %
            % The potable water bus pressure is mentioned to be 230 to 280
            % kPa in the same paper.
            %
            % In addition the WPA has a potable water tank of 150 lb
            % Capacity according to "Performance Qualification Test of the
            % ISS Water Processor Assembly (WPA) Expendables", Carter et.
            % al, 2005
            % For simplicity reasons that water tank is currently included
            % in the WSS store, and the whole potable water storage system
            % is assumed to be at 80% capacity at the beginning of the
            % simulation
            fWaterPressure = 230000;
            fPressure = 1e5;
            fWSSVolume = 0.6 + 0.068;
            matter.store(this, 'WSS', fWSSVolume);
            oWSS = this.toStores.WSS.createPhase(	'liquid', 'WSSWater', fWSSVolume, struct('H2O', 0.8), fAmbientTemperature, fWaterPressure);
            
            %coolant water store
            fCoolantStoreVolume = 0.01;
            matter.store(this, 'CoolantStore', fCoolantStoreVolume);
            oLTLCoolant = this.toStores.CoolantStore.createPhase(	'liquid', 'CoolantWater', fCoolantStoreVolume, struct('H2O', 1), fLTL_CoolantTemperature, fPressure);
           
            %Columbus Coolant Water is set to 7°C according to TO DO write citation!
            fColumbusCoolantTemperature = 280.15;
            fCoolantStoreVolume = 0.01;
            matter.store(this, 'ColumbusCoolantStore', fCoolantStoreVolume);
            oColumbusCoolant = this.toStores.ColumbusCoolantStore.createPhase(	'liquid', 'CoolantWater', fCoolantStoreVolume, struct('H2O', 1), fColumbusCoolantTemperature, fPressure);
           
            %Creating the Medium Temperature Loop Coolant for ACLS
            %Store for the Coolant Water branch. This is required only
            %because V-HAB does not allow a branch in a subsystem that
            %comes from the parent system and goes back to it.
            fVolumeCoolant = 0.01;
            matter.store(this, 'MTL_CoolantWaterStore', fVolumeCoolant);
            oMTL_Phase = this.toStores.MTL_CoolantWaterStore.createPhase(	'liquid', 'CoolantWater', fVolumeCoolant, struct('H2O', 1), fMTL_CoolantTemperature, fPressure);
           
            % Creating the Air connection store between CCAA 2 and CDRA 1 alias CDRA (Node 3)
            fConnectionVolume = 1e-6;
            matter.store(this, 'Node3_CCAA_CDRA', fConnectionVolume);
            oConnectionNode3_CCAA_CDRA              = this.toStores.Node3_CCAA_CDRA.createPhase(            'gas', 'flow',   'Node3_CCAA_CDRA_Phase',           fConnectionVolume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
           
            % Creating the Air connection store between CCAA 3 and CDRA 2 alias CDRA 2 (US LAB)
            matter.store(this, 'USLab_CCAA_CDRA', fConnectionVolume);
            oConnectionUSLab_CCAA_CDRA              = this.toStores.USLab_CCAA_CDRA.createPhase(            'gas', 'flow',   'USLab_CCAA_CDRA_Phase',           fConnectionVolume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            % Creating the Air connection store between CCAA and Vozdukh
            matter.store(this, 'CCAA_Vozdukh_Connection', fConnectionVolume);
            oConnectionCCAA_Vozdukh_Connection      = this.toStores.CCAA_Vozdukh_Connection.createPhase(    'gas', 'flow',   'CCAA_Vozdukh_Connection_Phase',   fConnectionVolume, struct('N2', fPP_N2, 'O2', fPP_O2, 'CO2', fPP_CO2), fAmbientTemperature, fRelHumidity);
            
            % Creating the H2 connection store between OGA and SCRA
            matter.store(this, 'H2_Connection', fConnectionVolume); % H2 from OGA to SCRA
            oConnectionH2                           = this.toStores.H2_Connection.createPhase(              'gas', 'flow',   'H2_Connection_Phase',             fConnectionVolume, struct('H2', 1e5), fAmbientTemperature, 0);
            
            % Creating the CO2 Connection tank between CDRA and SCRA Note
            % that in "Integrated Test and Evaluation of a 4-Bed Molecular
            % Sieve (4BMS) Carbon Dioxide Removal System (CDRA), Mechanical
            % Compressor Engineering Development Unit (EDU), and Sabatier
            % Engineering Development Unit (EDU)", Knox et. al., 2005 ICES
            % 2005-01-2864 the SCRA is mentioned to have a 0.73 ft^3
            % accumulator tank, which is located in the subsystem!
            matter.store(this, 'CO2_Connection', fConnectionVolume); % CO2 from CDRA to SCRA
            oConnectionCO2                          = this.toStores.CO2_Connection.createPhase(             'gas', 'flow',   'CO2_Connection_Phase',            fConnectionVolume, struct('CO2', 1e5), fAmbientTemperature, 0);
            
            % Creating the water tank between CCAA 1 and Elektron VM
            matter.store(this,'SM_Water', 10);               % H2O from CHX
            oSMWater = this.toStores.SM_Water.createPhase(	'liquid', 'SM_Water_Phase', 10, struct('H2O', 1), fAmbientTemperature, fWaterPressure);
            
            %% Creating the stores to gather the water produced by SCRA or recovered by CCAAs
            % According to ICES-2019-36, "Status of ISSWater Management and
            % Recovery", Carter et. al., 2019 the condensate from SCRA and
            % all CCAAs is delivered either to the US Lab condensate tank,
            % or directly to the WPA waste water tank. 
            % 
            % According to "International Space Station Water
            % Balance Operations", Barry et. al. 2005 
            % https://ntrs.nasa.gov/archive/nasa/casi.ntrs.nasa.gov/20110012703.pdf
            % Water can only be taken manually out of the US Lab condensate
            % tank. Therefore, we currently do not model that tank
            matter.store(this, 'WPA_WasteWater_Inlet', fConnectionVolume);
            oWPA_WasteWater_Inlet = this.toStores.WPA_WasteWater_Inlet.createPhase( 'liquid', 'flow', 'WPA_WasteWater_Inlet', fConnectionVolume, struct('H2O', 1), fAmbientTemperature, fPressure);
            
            %% inter module ventilation branche (IMV)
            %ICES 2005-01-2794 paper "Integrated Computational Fluid 
            %Dynamics Ventilation Model for the International Space
            %Station" Chang H. Son, Evgueni M. Smirnov, Nikolay G. Ivanov and Denis S. Telnov 
            %was used as source for the basic configuration since no
            %newer source for it could be found
            %
            % In a discussion following the paper presentation at ICES 2016
            % with Chang Son the information that the current IMV is set up
            % differently and some insight into the current setup was
            % obtained. Therefore the Setup was changed to reflect these
            % values
            matter.branch(this, oUSLab,     {}, oNode1,     'IMV_USLabToNode1');
            matter.branch(this, oUSLab,     {}, oNode2,     'IMV_USLabToNode2');
            matter.branch(this, oNode2,     {}, oUSLab,     'IMV_Node2ToUSLab');
            matter.branch(this, oNode3,     {}, oUSLab,     'IMV_Node3ToUSLab');
            matter.branch(this, oAirlock,   {}, oNode1,     'IMV_AirlockToNode1');
            matter.branch(this, oNode1,     {}, oAirlock,   'IMV_Node1ToAirlock');
            matter.branch(this, oNode1,     {}, oFGM,       'IMV_Node1ToFGM');
            matter.branch(this, oFGM,       {}, oSM,     	'IMV_FGMToSM');
            matter.branch(this, oSM,        {}, oNode3,  	'IMV_SMToNode3');
            matter.branch(this, oNode3,     {}, oPPM,       'IMV_Node3ToPMM');
            matter.branch(this, oPPM,       {}, oNode3,   	'IMV_PMMToNode3');
            matter.branch(this, oColumbus,  {}, oNode2,     'IMV_ColumbusToNode2');
            matter.branch(this, oNode2,     {}, oColumbus,  'IMV_Node2ToColumbus');
            matter.branch(this, oJEM,       {}, oNode2,   	'IMV_JEMToNode2');
            matter.branch(this, oNode2,     {}, oJEM,       'IMV_Node2ToJEM');
            matter.branch(this, oNode1,     {}, oNode3,     'IMV_Node1ToNode3');
            
            %% Creating the flowpaths between the Components
            matter.branch(this, oN2,     	{}, oAirlock,	'N2Tank_Airlock');
            matter.branch(this, oO2,      	{}, oAirlock, 	'O2Tank_Airlock');
            
            %Leak Branches
            matter.branch(this, oUSLab,    {},     oVacuum,         'Leak_USLab');
            matter.branch(this, oNode1,    {},     oVacuum,         'Leak_Node1');
            matter.branch(this, oNode2,    {},     oVacuum,         'Leak_Node2');
            matter.branch(this, oNode3,    {},     oVacuum,         'Leak_Node3');
            matter.branch(this, oFGM,      {},     oVacuum,     	'Leak_FGM');
            matter.branch(this, oSM,       {},     oVacuum,         'Leak_SM');
            matter.branch(this, oAirlock,  {},     oVacuum,         'Leak_Airlock');
            matter.branch(this, oPPM,      {},     oVacuum,         'Leak_PMM');
            matter.branch(this, oColumbus, {},     oVacuum,         'Leak_Columbus');
            matter.branch(this, oJEM,      {},     oVacuum,         'Leak_JEM');
            
            %% Creating the flowpath into the subsystems
            % CDRAs
            matter.branch(this, 'CDRA_Node3_Air_In',   	{}, oConnectionNode3_CCAA_CDRA);
            matter.branch(this, 'CDRA_Node3_Air_Out', 	{}, oNode3);
            matter.branch(this, 'CDRA_Node3_Vacuum',  	{}, oConnectionCO2);
            this.toChildren.CDRA_Node3.setIfFlows('CDRA_Node3_Air_In', 'CDRA_Node3_Air_Out', 'CDRA_Node3_Vacuum');
            
            matter.branch(this, 'CDRA_USLab_Air_In',   	{}, oConnectionUSLab_CCAA_CDRA);
            matter.branch(this, 'CDRA_USLab_Air_Out', 	{}, oUSLab);
            matter.branch(this, 'CDRA_USLab_Vacuum',  	{}, oVacuum);
            this.toChildren.CDRA_USLab.setIfFlows('CDRA_USLab_Air_In', 'CDRA_USLab_Air_Out', 'CDRA_USLab_Vacuum');
            
            matter.branch(this, 'Vozdukh_Air_In',   	{}, oConnectionCCAA_Vozdukh_Connection);
            matter.branch(this, 'Vozdukh_Air_Out',      {}, oSM);
            matter.branch(this, 'Vozdukh_Vacuum',       {}, oVacuum);
            this.toChildren.Vozdukh.setIfFlows('Vozdukh_Air_In', 'Vozdukh_Air_Out', 'Vozdukh_Vacuum');
            
            % SCRA
            matter.branch(this, 'SCRA_H2_In',           {}, oConnectionH2);
            matter.branch(this, 'SCRA_CO2_In',          {}, oConnectionCO2);
            matter.branch(this, 'SCRA_DryGas_Out',      {}, oVacuum);
            matter.branch(this, 'SCRA_Condensate_Out', 	{}, oWPA_WasteWater_Inlet);
            matter.branch(this, 'SCRA_CoolantIn',   	{}, oLTLCoolant);
            matter.branch(this, 'SCRA_CoolantOut',   	{}, oLTLCoolant);
            this.toChildren.SCRA_Node3.setIfFlows('SCRA_H2_In', 'SCRA_CO2_In', 'SCRA_DryGas_Out', 'SCRA_Condensate_Out', 'SCRA_CoolantIn', 'SCRA_CoolantOut');
            
            % OGA
            matter.branch(this, 'OGA_Water_In',         {}, oWSS);
            matter.branch(this, 'OGA_O2_Out',           {}, oNode3);
            matter.branch(this, 'OGA_H2_Out',           {}, oConnectionH2);
            this.toChildren.OGA_Node3.setIfFlows('OGA_Water_In', 'OGA_O2_Out', 'OGA_H2_Out');
             
            matter.branch(this, 'Elektron_Water_In',   	{}, oSMWater);
            matter.branch(this, 'Elektron_O2_Out',    	{}, oSM);
            matter.branch(this, 'Elektron_H2_Out',   	{}, oVacuum);
            this.toChildren.OGA_SM.setIfFlows('Elektron_Water_In', 'Elektron_O2_Out', 'Elektron_H2_Out');
            
            % CCAAs
            if this.tbCases.ModelInactiveSystems
                csCCAA      = {'Node3', 'USLab',    'SM',   'Airlock',  'Node2',    'JEM',  'USLab2',   'Columbus'};
                aoCabins    = [oNode3,  oUSLab,     oSM,    oAirlock,   oNode2,     oJEM,   oUSLab,     oColumbus];
                aoConnection= [oConnectionNode3_CCAA_CDRA,  oConnectionUSLab_CCAA_CDRA,     oConnectionCCAA_Vozdukh_Connection];
            else
                csCCAA      = {'Node3',    'SM',   'JEM', 'Columbus'};
                aoCabins    = [oNode3,     oSM,    oJEM,   oColumbus];
                aoConnection= [oConnectionNode3_CCAA_CDRA,  oConnectionCCAA_Vozdukh_Connection];
            end
            for iCCAA = 1:length(csCCAA)
            
                if strcmp(csCCAA, 'Columbus')
                    oCoolant = oColumbusCoolant;
                else
                    oCoolant = oLTLCoolant;
                end
                sCCAA = (['CCAA_', csCCAA{iCCAA}]);
                
                matter.branch(this, ['CCAA_Input_',          	csCCAA{iCCAA}],   	{}, aoCabins(iCCAA));
                matter.branch(this, ['CCAA_Output_',          	csCCAA{iCCAA}],  	{}, aoCabins(iCCAA));
                matter.branch(this, ['CCAA_CondensateOutput_',	csCCAA{iCCAA}],   	{}, oWPA_WasteWater_Inlet);
                matter.branch(this, ['CCAA_CoolantInput_',     	csCCAA{iCCAA}],  	{}, oCoolant);
                matter.branch(this, ['CCAA_CoolantOutput_',  	csCCAA{iCCAA}],     {}, oCoolant);
                
                csInterfaces = {['CCAA_Input_',                 csCCAA{iCCAA}],...
                             	['CCAA_Output_',                csCCAA{iCCAA}],...
                              	['CCAA_CondensateOutput_',      csCCAA{iCCAA}],...
                                ['CCAA_CoolantInput_',          csCCAA{iCCAA}],...
                              	['CCAA_CoolantOutput_',         csCCAA{iCCAA}]};
                            
                if ~isempty(this.toChildren.(sCCAA).sCDRA)
                    matter.branch(this,   ['CCAA_CDRA_',        csCCAA{iCCAA}],     {}, aoConnection(iCCAA));
                    csInterfaces{end+1} = ['CCAA_CDRA_',        csCCAA{iCCAA}]; %#ok
                end
                % now the interfaces between this system and the CCAA subsystem
                % are defined
                this.toChildren.(sCCAA).setIfFlows(csInterfaces{:});
            end
            
            % WPA
            matter.branch(this, 'InletWPA',        {}, oWPA_WasteWater_Inlet);
            matter.branch(this, 'OutletWPA',       {}, oWSS);
            matter.branch(this, 'AirInletWPA',     {}, oUSLab);
            matter.branch(this, 'AirOutletWPA',    {}, oUSLab);
            
            this.toChildren.WPA.setIfFlows('InletWPA', 'OutletWPA', 'AirInletWPA', 'AirOutletWPA');
            
            % Waste Management
            % Creates a store for the urine
            matter.store(this, 'UrineStorage', 0.1);
            oUrinePhase = matter.phases.mixture(this.toStores.UrineStorage, 'Urine', 'liquid', struct('Urine', 1.6), 295, 101325); 
            
            % Creates a store for the feces storage            
            matter.store(this, 'FecesStorage', 10);
            oFecesPhase = matter.phases.mixture(this.toStores.FecesStorage, 'Feces', 'solid', struct('Feces', 0.132), 295, 101325); 
            
            matter.store(this, 'BrineStorage', 0.1);
            oBrinePhase = matter.phases.mixture(this.toStores.BrineStorage, 'Brine', 'liquid', struct('Brine', 0.01), 295, 101325); 
            
            % UPA
            matter.branch(this, 'InletUPA',        {}, oUrinePhase);
            matter.branch(this, 'OutletUPA',       {}, oWPA_WasteWater_Inlet);
            matter.branch(this, 'BrineOutletUPA',  {}, oBrinePhase);
            this.toChildren.UPA.setIfFlows('InletUPA', 'OutletUPA', 'BrineOutletUPA');
            
            % BPA
            matter.branch(this, 'BrineInletBPA',    {}, oBrinePhase);
            matter.branch(this, 'AirInletBPA',    	{}, oNode3);
            matter.branch(this, 'AirOutletBPA',     {}, oNode3);
            this.toChildren.BPA.setIfFlows('BrineInletBPA', 'AirInletBPA', 'AirOutletBPA');
            
            %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                        CREW SYSTEM                      %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Adds a food store to the system
            tfFood = struct('Food', 1000);
            oFoodStore = components.matter.FoodStore(this, 'FoodStore', 100, tfFood);
            
            oPotableWaterPhase = oWSS;
            if this.tbCases.IronRing1 || this.tbCases.IronRing2
                this.aoNominalCrewMemberLocations = [oJEM, oJEM, oJEM, oJEM, oJEM, oJEM];
            else
                this.aoNominalCrewMemberLocations = [oUSLab, oNode3, oColumbus, oFGM, oJEM, oSM];
            end
            
            for iHuman = 1:this.iCrewMembers
                oCabinPhase = this.aoNominalCrewMemberLocations(iHuman);
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
            
            %% Changing things in case of non nominal cases:
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                   PLANT MODULE                          %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % All the infrastructure needed for the plant module to work.
            % Nutrients and Water consumed by the Plants are delivered via
            % two external tanks (WaterSupply) as well as (NutrientSupply).
            % When it is time to harvest a crop, the biomass is put into a
            % split buffer store (BiomassSplit), where the mass is split
            % into Edible and Inedible Mass.
            if this.tbCases.PlantChamber
                % Check where the plant chamber shall be located:
                oCabinPhase = this.toStores.(this.sPlantLocation).toPhases.([this.sPlantLocation, '_Phase']);
                
                % Nutrient Supply
                
                % This store is the connection to the plant NFT system. It
                % receives potable water from the potable water store and CROP
                % output solution
                oStore = matter.store(this,     'NutrientSupply',    0.1);
                fN_Mol_Concentration = 1; % mol/m^3
                fN_Mass = fN_Mol_Concentration * 0.1 * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);
                fWaterMass = 0.1 * 998;
                rNRatio = fN_Mass ./ (fN_Mass + fWaterMass);
                oNutrientSupply 	= oStore.createPhase(	'liquid',               'NutrientSupply',    	oStore.fVolume,	struct('H2O', 1-rNRatio, 'NO3', rNRatio),	oCabinPhase.fTemperature,	oCabinPhase.fPressure);
                
                this.tfPlantControlParameters.InitialWater  = oNutrientSupply.afMass(this.oMT.tiN2I.H2O);
                this.tfPlantControlParameters.InitialNO3    = oNutrientSupply.afMass(this.oMT.tiN2I.NO3);
                
                oStore = matter.store(this,     'BackupNutrientSupply',    0.1);
                fN_Mol_Concentration = 100; % mol/m^3
                fN_Mass = fN_Mol_Concentration * 0.1 * this.oMT.afMolarMass(this.oMT.tiN2I.NO3);
                fWaterMass = 0.1 * 998;
                rNRatio = fN_Mass ./ (fN_Mass + fWaterMass);
                oBackupNutrientSupply = oStore.createPhase( 'liquid',   'boundary', 'NutrientSupply',   	oStore.fVolume,	struct('H2O', 1-rNRatio, 'NO3', rNRatio),	oCabinPhase.fTemperature,	oCabinPhase.fPressure);

                oStore = matter.store(this,     'Plant_Preparation',    0.1);
                oInedibleSplit   	= oStore.createPhase(	'mixture',  'flow',    	'Inedible',	'solid', 0.5*oStore.fVolume, struct('H2O', 0),              oCabinPhase.fTemperature,	oCabinPhase.fPressure);
                oEdibleSplit        = oStore.createPhase(	'mixture',  'flow',    	'Edible',  	'solid', 0.5*oStore.fVolume, struct('H2O', 0),          	oCabinPhase.fTemperature,	oCabinPhase.fPressure);
                
                csInedibleBiomass = cell(length(this.csPlants));
                for iPlant = 1:length(this.csPlants)
                    csInedibleBiomass{iPlant} = [this.toChildren.([this.csPlants{iPlant},'_1']).txPlantParameters.sPlantSpecies, 'Inedible'];
                end

                matter.procs.exmes.mixture(oInedibleSplit,  'Plant_Preparation_Out');
                matter.procs.exmes.mixture(oEdibleSplit,    'Plant_Preparation_In');
                components.matter.P2Ps.ConstantMassP2P(this.toStores.Plant_Preparation, 'Plant_Preparation', 'Inedible.Plant_Preparation_Out', 'Edible.Plant_Preparation_In', csInedibleBiomass, 1);

                % Now add branches to resupply the NFT store with water and
                % nutrients and the branch for the edible biomass to be
                % consumed by humans
                matter.branch(this, oPotableWaterPhase,             	{}, oNutrientSupply,                        'PotableWater_to_NFT');
                matter.branch(this, oBackupNutrientSupply,             	{}, oNutrientSupply,                        'BackupNutrient_to_NFT');
                
                matter.branch(this, oEdibleSplit,        {}, oFoodStore.toPhases.Food, 	'Plants_to_Foodstore');
                
                for iPlant = 1:length(this.csPlants)
                    for iSubculture = 1:this.miSubcultures(iPlant)
                        sCultureName = [this.csPlants{iPlant},'_', num2str(iSubculture)];

                        matter.procs.exmes.gas(oCabinPhase,             [sCultureName, '_AtmosphereCirculation_Out']);
                        matter.procs.exmes.gas(oCabinPhase,             [sCultureName, '_AtmosphereCirculation_In']);
                        matter.procs.exmes.liquid(oNutrientSupply,     	[sCultureName, '_to_NFT']);
                        matter.procs.exmes.liquid(oNutrientSupply,    	[sCultureName, '_from_NFT']);
                        matter.procs.exmes.mixture(oEdibleSplit,     	[sCultureName, '_Biomass_In']);

                        matter.branch(this, [sCultureName, '_Atmosphere_ToIF_Out'],      {}, [oCabinPhase.oStore.sName,         '.',	sCultureName, '_AtmosphereCirculation_Out']);
                        matter.branch(this, [sCultureName, '_Atmosphere_FromIF_In'],     {}, [oCabinPhase.oStore.sName,         '.',  	sCultureName, '_AtmosphereCirculation_In']);
                        matter.branch(this, [sCultureName, '_WaterSupply_ToIF_Out'],     {}, [oNutrientSupply.oStore.sName,     '.',    sCultureName, '_to_NFT']);
                        matter.branch(this, [sCultureName, '_NutrientSupply_ToIF_Out'],  {}, [oNutrientSupply.oStore.sName,     '.',    sCultureName, '_from_NFT']);
                        matter.branch(this, [sCultureName, '_Biomass_FromIF_In'],        {}, [oEdibleSplit.oStore.sName,        '.',    sCultureName, '_Biomass_In']);

                        this.toChildren.(sCultureName).setIfFlows(...
                            [sCultureName, '_Atmosphere_ToIF_Out'], ...
                            [sCultureName ,'_Atmosphere_FromIF_In'], ...
                            [sCultureName ,'_WaterSupply_ToIF_Out'], ...
                            [sCultureName ,'_NutrientSupply_ToIF_Out'], ...
                            [sCultureName ,'_Biomass_FromIF_In']);
                    end
                end
            end

            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                         ACLS                            %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if this.tbCases.ACLS
                matter.store(this,'ACLS_Water', 10);               % H2O for ACLS
                cWaterHelper = matter.helper.phase.create.water(this.toStores.CoolantStore, 10, fAmbientTemperature, fWaterPressure);
                oLiquid2 = matter.phases.liquid(this.toStores.ACLS_Water, 'ACLS_Water_Phase', cWaterHelper{1}, cWaterHelper{2}, cWaterHelper{3}, cWaterHelper{4});
                matter.procs.exmes.liquid(oLiquid2, 'Port_Out_ACLS_OGA');
                matter.procs.exmes.liquid(oLiquid2, 'Port_Out_ACLS_CCA');

                matter.procs.exmes.gas(oUSLabAtmosphere, 'Port_To_ACLS');
                matter.procs.exmes.gas(oUSLabAtmosphere, 'Port_From_ACLS');
                matter.procs.exmes.gas(oUSLabAtmosphere, 'Port_O2_From_ACLS');

                matter.procs.exmes.gas(oVacuum, 'ACLS_Vent');

                matter.procs.exmes.liquid(oMTL_Phase, 'Coolant_In');
                matter.procs.exmes.liquid(oMTL_Phase, 'Coolant_Out');

                matter.branch(this, 'ACLS_Air_In',      {}, 'US_Lab.Port_To_ACLS');
                matter.branch(this, 'ACLS_OGA_H2O',     {}, 'ACLS_Water.Port_Out_ACLS_OGA');
                matter.branch(this, 'ACLS_CCA_H2O',     {}, 'ACLS_Water.Port_Out_ACLS_CCA');
                matter.branch(this, 'ACLS_Air_Out',     {}, 'US_Lab.Port_From_ACLS');
                matter.branch(this, 'ACLS_O2_Out',      {}, 'US_Lab.Port_O2_From_ACLS');
                matter.branch(this, 'ACLS_VentIF',      {}, 'Vacuum.ACLS_Vent');
                matter.branch(this, 'ACLS_Coolant_In',  {}, 'MTL_CoolantWaterStore.Coolant_Out');
                matter.branch(this, 'ACLS_Coolant_Out', {}, 'MTL_CoolantWaterStore.Coolant_In');

                this.toChildren.ACLS.setReferencePhase(oUSLabAtmosphere);

                %Interface Definition
                this.toChildren.ACLS.setIfFlows('ACLS_Air_In', 'ACLS_OGA_H2O', 'ACLS_CCA_H2O', 'ACLS_Air_Out', 'ACLS_O2_Out', 'ACLS_VentIF', 'ACLS_Coolant_In', 'ACLS_Coolant_Out');

            end
        end
        
        
        function createThermalStructure(this)
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('CoolantConstantTemperature');
            this.toStores.CoolantStore.toPhases.CoolantWater.oCapacity.addHeatSource(oHeatSource);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('ColumbusCoolantConstantTemperature');
            this.toStores.ColumbusCoolantStore.toPhases.CoolantWater.oCapacity.addHeatSource(oHeatSource);
            
            % payload thermal load
            csModule = {'US_Lab', 'Node2', 'Columbus', 'JEM', 'Node3', 'FGM', 'SM'};
            
            tModuleHeatLoad.US_Lab = 500;
            tModuleHeatLoad.Node2 = 150;
            tModuleHeatLoad.Columbus = 100;
            tModuleHeatLoad.JEM = 500;
            tModuleHeatLoad.Node3 = 100;
            tModuleHeatLoad.FGM = 0;
            tModuleHeatLoad.SM = 250;
            
            for iModule = 1:length(csModule)
                oHeatSource = thermal.heatsource('PayloadHeat', tModuleHeatLoad.(csModule{iModule}));
                this.toStores.(csModule{iModule}).toPhases.([csModule{iModule}, '_Phase']).oCapacity.addHeatSource(oHeatSource);
            end
            
            this.toChildren.CDRA_Node3.setReferencePhase(this.toStores.Node3.toPhases.Node3_Phase);
            this.toChildren.CDRA_USLab.setReferencePhase(this.toStores.US_Lab.toPhases.US_Lab_Phase, 2);
            this.toChildren.Vozdukh.setReferencePhase(this.toStores.SM.toPhases.SM_Phase, 3);
            
            for iHuman = 1:this.iCrewMembers
                % Add thermal IF for humans
                oCabinPhase = this.aoNominalCrewMemberLocations(iHuman);
                thermal.procs.exme(oCabinPhase.oCapacity, ['SensibleHeatOutput_Human_',    num2str(iHuman)]);
                
                thermal.branch(this, ['SensibleHeatOutput_Human_',    num2str(iHuman)], {}, [oCabinPhase.oStore.sName '.SensibleHeatOutput_Human_',    num2str(iHuman)], ['SensibleHeatOutput_Human_',    num2str(iHuman)]);
                
                this.toChildren.(['Human_',         num2str(iHuman)]).setThermalIF(['SensibleHeatOutput_Human_',    num2str(iHuman)]);
            end
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %% Create the solver
            this.toSolverBranches.N2Buffer                      = solver.matter.manual.branch(this.toBranches.N2Tank_Airlock);
            this.toSolverBranches.O2Buffer                      = solver.matter.manual.branch(this.toBranches.O2Tank_Airlock);
            
            this.toSolverBranches.ISS_Leakage(1) = solver.matter.manual.branch(this.toBranches.Leak_USLab);
            this.toSolverBranches.ISS_Leakage(2) = solver.matter.manual.branch(this.toBranches.Leak_Node1);
            this.toSolverBranches.ISS_Leakage(3) = solver.matter.manual.branch(this.toBranches.Leak_Node2);
            this.toSolverBranches.ISS_Leakage(4) = solver.matter.manual.branch(this.toBranches.Leak_Node3);
            this.toSolverBranches.ISS_Leakage(5) = solver.matter.manual.branch(this.toBranches.Leak_FGM);
            this.toSolverBranches.ISS_Leakage(6) = solver.matter.manual.branch(this.toBranches.Leak_SM);
            this.toSolverBranches.ISS_Leakage(7) = solver.matter.manual.branch(this.toBranches.Leak_Airlock);
            this.toSolverBranches.ISS_Leakage(8) = solver.matter.manual.branch(this.toBranches.Leak_PMM);
            this.toSolverBranches.ISS_Leakage(9) = solver.matter.manual.branch(this.toBranches.Leak_Columbus);
            this.toSolverBranches.ISS_Leakage(10) = solver.matter.manual.branch(this.toBranches.Leak_JEM);
            
            solver.matter.manual.branch(this.toBranches.IMV_USLabToNode1);
            solver.matter.manual.branch(this.toBranches.IMV_USLabToNode2);
            solver.matter.manual.branch(this.toBranches.IMV_Node2ToUSLab);
            solver.matter.manual.branch(this.toBranches.IMV_Node3ToUSLab);
            solver.matter.manual.branch(this.toBranches.IMV_AirlockToNode1);
            solver.matter.manual.branch(this.toBranches.IMV_Node1ToAirlock);
            solver.matter.manual.branch(this.toBranches.IMV_Node1ToFGM);
            solver.matter.manual.branch(this.toBranches.IMV_FGMToSM);
            solver.matter.manual.branch(this.toBranches.IMV_SMToNode3);
            solver.matter.manual.branch(this.toBranches.IMV_Node3ToPMM);
            solver.matter.manual.branch(this.toBranches.IMV_PMMToNode3);
            solver.matter.manual.branch(this.toBranches.IMV_JEMToNode2);
            solver.matter.manual.branch(this.toBranches.IMV_Node2ToJEM);
            solver.matter.manual.branch(this.toBranches.IMV_ColumbusToNode2);
            solver.matter.manual.branch(this.toBranches.IMV_Node2ToColumbus);
            solver.matter.manual.branch(this.toBranches.IMV_Node1ToNode3);
            
            %set the flow rate for the intermodule ventilation
            %1 cfm = 0.000471947443 m³/s. Note that this also results in a
            %pressure equalization since the density in a store with lower
            %pressure is smaller than in a store with higher pressure the
            %mass flow leaving it is also smaller thus increasing the mass
            %and the pressure in the store with the smaller pressure
            
            %The actual values used for the IMV is based on ICES-2015-27
            %paper "Inter-Module Ventilation Changes to the International Space 
            %Station Vehicle to support integration of the International 
            %Docking Adapter and Commercial Crew Vehicles" Dwight E. Link, Steven F. Balistreri
            %stating that IMV fan provides 140 cfm flowrate. This about matches
            %the value from ICES 2005-01-2794 paper "Integrated Computational 
            %Fluid Dynamics Ventilation Model for the International Space
            %Station" Chang H. Son, Evgueni M. Smirnov, Nikolay G. Ivanov and Denis S. Telnov 
            %which was used as source for the basic configuration since no
            %newer source for it could be found (ICES-2015-27 only
            %mentiones a very specific part of the IMV)
            %
            % Updated IMV based on data received from Mr. Chang Son of the
            % Boeing Company, which is dated to 2015 post relocation
            % (likely refering to the relocation described in ICES-2015-27)
            
            % 0.000471947443 is the factor for cfm to m^3/s (the first value is cfm and the second one is the factor to make it m^3/s)
            % US Lab to Node 1 IMV with 126 cfm
            fVolumetricFlowRate = 126*0.000471947443;
            this.toBranches.IMV_USLabToNode1.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);    
            
            % US Lab to Node 2 with 120 cfm
            fVolumetricFlowRate = 120*0.000471947443;
            this.toBranches.IMV_USLabToNode2.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);    
            
            % Node 2 to US Lab with 120 cfm
            fVolumetricFlowRate = 120*0.000471947443;
            this.toBranches.IMV_Node2ToUSLab.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % Node 2 to Col with 110 cfm
            fVolumetricFlowRate = 110*0.000471947443;
            this.toBranches.IMV_Node2ToColumbus.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % Node 3 to US Lab with 126 cfm
            fVolumetricFlowRate = 126*0.000471947443;
            this.toBranches.IMV_Node3ToUSLab.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % Node 3 to PMM with 60 cfm
            fVolumetricFlowRate = 60*0.000471947443;
            this.toBranches.IMV_Node3ToPMM.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % Node 1 to Airlock with 115 cfm
            % Note there is no air flow specified in the IMV, but without
            % any backflow the current model would empty the airlock! The
            % IMV is set to the same amount to prevent a large pressure
            % difference from developing
            fVolumetricFlowRate = 115*0.000471947443;
            this.toBranches.IMV_Node1ToAirlock.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % Node 1 to FGM with 96 cfm
            fVolumetricFlowRate = 96*0.000471947443;
            this.toBranches.IMV_Node1ToFGM.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % Airlock to Node 1 with 115 cfm
            fVolumetricFlowRate = 115*0.000471947443;
            this.toBranches.IMV_AirlockToNode1.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % FGM to SM with 96 cfm
            fVolumetricFlowRate = 96*0.000471947443;
            this.toBranches.IMV_FGMToSM.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % SM to Node 3 with 96 cfm
            fVolumetricFlowRate = 96*0.000471947443;
            this.toBranches.IMV_SMToNode3.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % PMM to Node 3 with 60 cfm
            % Note there is no air flow specified in the IMV, but without
            % any backflow the current model would empty the PMM! The
            % IMV is set to the same amount to prevent a large pressure
            % difference from developing
            fVolumetricFlowRate = 60*0.000471947443;
            this.toBranches.IMV_PMMToNode3.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            if this.tbCases.IronRing2
                % Node 2 to JEM with 110 cfm
                fVolumetricFlowRate = 80*0.000471947443;
                this.toBranches.IMV_Node2ToJEM.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);

                % JEM to Node 2 with 110 cfm
                fVolumetricFlowRate = 80*0.000471947443;
                this.toBranches.IMV_JEMToNode2.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
                
            else
                % Node 2 to JEM with 110 cfm
                fVolumetricFlowRate = 110*0.000471947443;
                this.toBranches.IMV_Node2ToJEM.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);

                % JEM to Node 2 with 110 cfm
                fVolumetricFlowRate = 110*0.000471947443;
                this.toBranches.IMV_JEMToNode2.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            end
            % Col to Node 2 with 110 cfm
            fVolumetricFlowRate = 110*0.000471947443;
            this.toBranches.IMV_ColumbusToNode2.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            % Node 1 to Node 3 with 30 cfm
            fVolumetricFlowRate = 30*0.000471947443;
            this.toBranches.IMV_Node1ToNode3.oHandler.setVolumetricFlowRate(fVolumetricFlowRate);
            
            %% Setting of fixed flow rates
            % Setting the flow rate of the ISS leak to the vacuum based on
            % values from P.Plötners Diplomarbeit page 45.
            
            %US Lab
            mLeakage(1) = 0.002722/86400;
            %Node1
            %               Node1   + 2* Vest
            mLeakage(2) = (0.002268 + 2*0.000122)/86400;
            %Node2
            %               Node 2  + 2*PMA      + Vest
            mLeakage(3) = (0.000707 + 2*0.000404 + 0.000001)/86400;
            %Node3
            %               Node 3  + Cupola
            mLeakage(4) = (0.002268 + 0.00003)/86400;
            %FGB
            %               FGB    + PMA      + 2*Vest     + MRM-1    + Soyuz    + Vest(Soyuz)
            mLeakage(5) = (0.00029 + 0.000404 + 2*0.000363 + 0.000003 + 0.000056 + 0.000363)/86400;
            %SM
            %               SM      + MRM-2    + Vest     + SM Tansfer Funnel 
            mLeakage(6) = (0.000009 + 0.000003 + 0.000363 + 0.000063)/86400;
            %Airlock
            mLeakage(7) = 0.000052/86400;
            %PMM
            %               PMM     + Vest
            mLeakage(8) = (0.000771 + 0.000122)/86400;
            %Columbus
            %              Columbus + Vest
            mLeakage(9) = (0.003022 + 0.000001)/86400;
            %JEM
            %               JEM PM   + JEM PLS  + 2*Vest
            mLeakage(10) = (0.000148 + 0.000168 + 2*0.000001)/86400;
            
            for k = 1:length(this.toSolverBranches.ISS_Leakage)
                this.toSolverBranches.ISS_Leakage(k).setFlowRate(mLeakage(k));
            end
            
            % The base value is 600 lb/hr, but e.g. in US Lab and Hab the
            % flowrate is 1230 lb/hr see:
            % "Living together in space: the design and operation of the
            % life support systems on the International Space Station",
            % Wieland, Paul O., 1998, page 104
            % In Figure 3 of the source the USOS ECLSS is described, and
            % Node 3 is called Hab there.
            this.toChildren.CCAA_Node3.setCoolantFlowRate(557.91862 / 3600);
            
            % However, as stated in  "Status of ISS Water Management and
            % Recovery", Carter et. al, 2016, ICES-2016-036 only of CHX in
            % the USOS is active at any given time. Here we assume this to
            % be the Node 3 CCAA since that CDRA is also assumed to be
            % active
            if this.tbCases.ModelInactiveSystems
                this.toChildren.CCAA_USLab.setCoolantFlowRate(557.91862 / 3600);
                this.toChildren.CCAA_USLab.setActive(false);
                this.toChildren.CCAA_USLab2.setActive(false);
                this.toChildren.CCAA_Airlock.setActive(false);
                this.toChildren.CCAA_Node2.setActive(false);
            end
            
            if this.tbCases.PlantChamber
                solver.matter.residual.branch(this.toBranches.Plants_to_Foodstore);
            
                solver.matter.manual.branch(this.toBranches.PotableWater_to_NFT);
                solver.matter.manual.branch(this.toBranches.BackupNutrient_to_NFT);
            end
            
            this.setThermalSolvers();
            
            %% Set CCAA numeric properties
            tProperties.fSearchStepTemperatureDifference    = 2;
            tProperties.iMaximumNumberOfSearchSteps         = 30;
            tProperties.rMaxError                           = 0.2;
            
            for iChild = 1: this.iChildren
                if ~isempty(regexp(this.csChildren{iChild}, 'CCAA', 'once'))
                    this.toChildren.(this.csChildren{iChild}).toChildren.CCAA_CHX.setNumericProperties(tProperties);
                end
            end
            %% Allocates the time step properties to all phases
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    tTimeStepProperties.fMaxStep = this.fControlTimeStep * 5;

                    oPhase.setTimeStepProperties(tTimeStepProperties);

                    tTimeStepProperties = struct();
                    tTimeStepProperties.fMaxStep = this.fControlTimeStep * 5;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            % ISS System
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    
                    arMaxChange = zeros(1,this.oMT.iSubstances);
                    arMaxChange(this.oMT.tiN2I.H2O) = 0.75;
                    arMaxChange(this.oMT.tiN2I.CO2) = 0.75;
                    tTimeStepProperties.arMaxChange = arMaxChange;

                    oPhase.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            %Other Subsystems except ACLS since ACLS uses a different TS
            csChildNames = fieldnames(this.toChildren);
            for iChildren = 1:length(csChildNames)
                if ~strcmp(csChildNames{iChildren}, 'ACLS') && ~strcmp(csChildNames{iChildren}, 'CDRA')
                    csStoreNames = fieldnames(this.toChildren.(csChildNames{iChildren}).toStores);
                    for iStore = 1:length(csStoreNames)
                        for iPhase = 1:length(this.toChildren.(csChildNames{iChildren}).toStores.(csStoreNames{iStore}).aoPhases)
                            oPhase = this.toChildren.(csChildNames{iChildren}).toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                            
                            arMaxChange = zeros(1,this.oMT.iSubstances);
                            arMaxChange(this.oMT.tiN2I.H2O) = 0.75;
                            arMaxChange(this.oMT.tiN2I.CO2) = 0.75;
                            tTimeStepProperties.arMaxChange = arMaxChange;

                            oPhase.setTimeStepProperties(tTimeStepProperties);

                        end
                    end
                end
            end
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = inf;
            tTimeStepProperties.fMaxStep = this.fControlTimeStep;

            this.toStores.UrineStorage.toPhases.Urine.setTimeStepProperties(tTimeStepProperties);
            this.toStores.BrineStorage.toPhases.Brine.setTimeStepProperties(tTimeStepProperties);
            this.toStores.FecesStorage.toPhases.Feces.setTimeStepProperties(tTimeStepProperties);
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);

            %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%              Crew Metabolism Simulator                  %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % this section sets the correct values for the humans according
            % to their current state and also takes care of automatic
            % transitions to follow up states (like recovery after
            % exercise)
            
            %%%%%%%%%%%%%% Crew Movement Simulation%%%% %%%%%%%%%%%%%%%%%%% 
            % automatically moves the crew to Node 3 for exercise and back
            % after exercise
            for iCM = 1:this.iCrewMembers
                % If the crewmember is exercising move to Node3 if that was
                % not already done:
                if this.toChildren.(['Human_', num2str(iCM)]).iState == 2 && ~this.mbCrewMemberCurrentlyInNode3(iCM)
                    this.mbCrewMemberCurrentlyInNode3(iCM) = true;
                    this.toChildren.(['Human_', num2str(iCM)]).moveHuman(this.toStores.Node3.toPhases.Node3_Phase);
                elseif this.toChildren.(['Human_', num2str(iCM)]).iState == 4 && this.mbCrewMemberCurrentlyInNode3(iCM)
                    this.mbCrewMemberCurrentlyInNode3(iCM) = false;
                    this.toChildren.(['Human_', num2str(iCM)]).moveHuman(this.aoNominalCrewMemberLocations(iCM));
                end
            end
            
            %% Other flow rate settings
            % Setting the flow rates for the N2 tank connected to the habitat
            %According to ICES-2015-146 "Report on ISS O2 Production, 
            %Gas Supply & Partial Pressure Management" Ryan N. Schaezler, Anthony J. Cook
            %The lower pressure limit is 14 psi or 96526 Pa (set point is a
            %bit higher)
            if this.toStores.Airlock.aoPhases(1,1).fPressure < 96600                 
                this.toSolverBranches.N2Buffer.setFlowRate(2.1601742588888333e-4);        % P.Plötner used 0.0129610455533333, because he simulated minutes
            else
                this.toSolverBranches.N2Buffer.setFlowRate(0);
            end
            
            % Setting the flow rates for the O2 tank connected to the habitat
            if this.oTimer.iTick ~= 0 %had to be added because afPP is only set in the phase update function and this is executed before the phase update
                %According to ICES-2015-146 "Report on ISS O2 Production, 
                %Gas Supply & Partial Pressure Management" Ryan N. Schaezler, Anthony J. Cook
                %The lower O2 limit is 2.82 psi or 19443 Pa
                if this.toStores.Airlock.aoPhases(1,1).afPP(this.oMT.tiN2I.O2) < 19445 
                    this.toSolverBranches.O2Buffer.setFlowRate(0.00529610455533333/60);       % 1.3972e-3*1.05 (per minute) is used by P. Plötner (this result in 2.4451e-5/second), but his commend is: %adapted to ppO2 ISS flight data tech.Flowrate =0.00529610455533333; (this would result in 0.00529610455533333/60 per second)
                else
                    this.toSolverBranches.O2Buffer.setFlowRate(0);
                end
            end
            
            % BPA flowrate
            if ~this.toChildren.BPA.bProcessing &&  ~this.toChildren.BPA.bDisposingConcentratedBrine && ~this.toChildren.BPA.toBranches.BrineInlet.oHandler.bMassTransferActive && ~(this.toChildren.BPA.toStores.Bladder.toPhases.Brine.fMass >= this.toChildren.BPA.fActivationFillBPA)
                if this.toStores.BrineStorage.toPhases.Brine.fMass > this.toChildren.BPA.fActivationFillBPA
                    this.toChildren.BPA.toBranches.BrineInlet.oHandler.setMassTransfer(-(this.toChildren.BPA.fActivationFillBPA), 300);
                end
            end
            
            if this.tbCases.PlantChamber
                fWaterDifference = this.tfPlantControlParameters.InitialWater - this.toStores.NutrientSupply.toPhases.NutrientSupply.afMass(this.oMT.tiN2I.H2O);
                fNutrientDifference = this.tfPlantControlParameters.InitialNO3 - this.toStores.NutrientSupply.toPhases.NutrientSupply.afMass(this.oMT.tiN2I.NO3);
                if fWaterDifference > 0.1 && ~this.toBranches.PotableWater_to_NFT.oHandler.bMassTransferActive
                    this.toBranches.PotableWater_to_NFT.oHandler.setMassTransfer(fWaterDifference, this.fControlTimeStep);
                end
                if fNutrientDifference > 1e-3 && ~this.toBranches.BackupNutrient_to_NFT.oHandler.bMassTransferActive
                    this.toBranches.BackupNutrient_to_NFT.oHandler.setMassTransfer(fNutrientDifference, this.fControlTimeStep);
                end
            end
            
            this.oTimer.synchronizeCallBacks();
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                 Dew Point Calculation                   %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Dew Point Calculation for each Module in order to Plot Values:
            
           % Order: 'Node1', 'Node2', 'Node3', 'PMM', 'FGM', 'Airlock', 'SM', 'US_Lab' 'JEM', 'Columbus'
           
            this.afDewPointModules(1)  = this.oMT.convertHumidityToDewpoint(this.toStores.Node1.toPhases.Node1_Phase);
            this.afDewPointModules(2)  = this.oMT.convertHumidityToDewpoint(this.toStores.Node2.toPhases.Node2_Phase);
            this.afDewPointModules(3)  = this.oMT.convertHumidityToDewpoint(this.toStores.Node3.toPhases.Node3_Phase);
            this.afDewPointModules(4)  = this.oMT.convertHumidityToDewpoint(this.toStores.PMM.toPhases.PMM_Phase);
            this.afDewPointModules(5)  = this.oMT.convertHumidityToDewpoint(this.toStores.FGM.toPhases.FGM_Phase);
            this.afDewPointModules(6)  = this.oMT.convertHumidityToDewpoint(this.toStores.Airlock.toPhases.Airlock_Phase);
            this.afDewPointModules(7)  = this.oMT.convertHumidityToDewpoint(this.toStores.SM.toPhases.SM_Phase);
            this.afDewPointModules(8)  = this.oMT.convertHumidityToDewpoint(this.toStores.US_Lab.toPhases.US_Lab_Phase);
            this.afDewPointModules(9)  = this.oMT.convertHumidityToDewpoint(this.toStores.JEM.toPhases.JEM_Phase);
            this.afDewPointModules(10) = this.oMT.convertHumidityToDewpoint(this.toStores.Columbus.toPhases.Columbus_Phase);
            
        end
    end
end