classdef PlantModule < vsys
    %Subsystem that hosts the plant modularity.
     
     %%% Notice: This PlantModule version runs properly with V-HAB 2.0 from January 19, 2015
     
     %%% A complete and detailed explanation can be found in:
     %%%  "Dynamic Modeling and Simulation of a Lunar Base Greenhouse";
     %%%   Bachelor thesis; May 2015; Keller Florian
     %%%   Institute of Aastronautics - Technische Universitaet Muenchen
     
    
    properties
         % General properties for the class PlantModule

          % ---------------------------------------------------------------
            % When setting up a new simulation, all preferences and
            % adaptions should be done in the tagged sections in the method section below.
                
            
                %Reference for loading the plant setup
                        PlantEng;
                %Database with nominal plant growth parameters 
                        fPlant;
                %Objects of Branches (For interface-ports PlantModule)
                        oInputAirBranch;
                        oOutputAirBranch;
                        oInputWaterBranch;                        
                        oOutputFoodBranch;
                        oOutputWasteBranch;
                %Time variable
                        fTime;
                %Available Water
                        fWaterAvailable;
                %Flowrates
                        fFlowRate;
                        fFlowrateO2In;
                        fFlowrateH2OIn;

            %Variables for processing different simulation setups
                %These are just the properties
                %The setup assignment of the system is done in the function part below
                     %Variables of "measured" LSS conditions      
                        fCO2ppm_Measured;
                        fRH_Measured;
                        fP_atm_Measured;
                     %Variables for predefing simulation conditions
                      % Set to default values
                        fCO2ppm_Predefined      = 1000;
                        fRH_day_Predefined      = 0.65;
                        fRH_night_Predefined    = 0.70;
                        fP_atm_Predefined       = 101300;

                    %Variables used for actual calculating after the simulation settings are processed
                     % Set to default values    
                        fCO2ppm     = 1000;
                        fPPF        = 300;
                        fRH_day     = 0.50;
                        fRH_night   = 0.50;
                        fP_atm      = 101300;
                        fH          = 17;
                        fTemp_light = 20.5;
                        fTemp_dark  = 20.5; % Changing temperatures may not be compatible with parts of the plant model
        
            %Object variables to handle diverse manipulators and phase-to-phase processors
                %Object of biomass creating manipulator
                            oManip_Create_Biomass;
                %Gas exchange:
                        %Phase-to-phase processor representing H2O exchange, plants phase <-> air phase
                            oProc_Plants_H2OGasExchange;
                        %Phase-to-phase processor representing  O2 exchange, plants phase <-> air phase
                            oProc_Plants_O2GasExchange;
                        %Phase-to-phase processor representing CO2 exchange, plants phase <-> air phase
                            oProc_Plants_CO2GasExchange;
                %Harvest processors  
                        %Extracting the plant components (edible and inedible parts, respectivly dry and fresh) from the plants phase
                            oProc_Harvest_InedibleBiomass;
                            oProc_Harvest_EdibleBiomass;
                        %Transforming the above mentioned extracted plant parts to food (edible part) and waste (inedible part)
                            oManip_Process_InediblePlantsToWaste;
                            oManip_Process_EdiblePlantsToFood;
                            
          % ---------------------------------------------------------------
          % End of properties
    end
    
    methods
        function this = PlantModule(oParent, sName)
        % Call of the supercalls constructor
           %                   Attention!
           % The last parameter is the frequency of processing
           % the update part. For proper computation itt is a necessity 
           %  to use 60 [s]. 
           % (Due to the approach regarding "integration" in the PlantModule)
              this@vsys(oParent, sName, 60);
                
                global bUseLSSConditions
                global bUseGlobalPlantConditions
                
        %% -Simulation Settings PlantModule-
                
              
    %       THIS SECTION CAN BE ADAPTED WHEN APPLYING A NEW SYSTEM        %         
    %       (ADAPTIONS 1 of 3)
    % --------------------------------------------------------------------%
    % --------------------------------------------------------------------%

     % Decision between simulation conditions
        bUseLSSConditions           = 1;
            % If bUseLSSConditions == 1:
            %       the growth conditions prevailing in the LSS are
            %       used for computation
            % If bUseLSSConditions == 0:
            %       the preset values, which can be set below, are
            %       considered for computation


        bUseGlobalPlantConditions           = 1;
            % If bUseGlobalPlantConditions == 1:
            %       the same global conditions for all cultures are
            %       used
            % If bUseGlobalPlantConditions == 0:
            %       specific growth conditions from the culture
            %       setups (PlantEng) are used for computation -->
            %       '...components.PlantModule.setups...'.
            %       This concerns the following conditions:
            %        Photosynthetic photon flux (PPF), CO2 level ppm (CO2)
            %        and the Photoperiod (H)



     % Setting plant growth parameters
         %Always necessary to set
          % Mean air temperature
            this.fTemp_light            = 20.5;     % [°C]
            this.fTemp_dark             = 20.5;     % [°C]
          % Reference for loading the plant setup from "PlantEng"
            this.PlantEng =                                             ...        
             load(strrep(                                               ...
             'components\+PlantModule\+setups\PlantEng.mat', ...
             '\', ...   %PlantEng: Setup containing several plant cultures
             filesep));
         
         %...only necessary, when   bUseLSSConditions == 0
            this.fCO2ppm_Predefined     = 1000;     % [µmol/mol]
            this.fRH_day_Predefined     = 0.65;     % ratio 
            this.fRH_night_Predefined   = 0.70;     % ratio
            this.fP_atm_Predefined      = 101300;   % [Pa]

         %...necessary, when        bUseGlobalPlantConditions == 1
            this.fH                     = 17;       % [hours/day]
            this.fPPF                   = 300;      % [µmol/m^2/s]
                
    % --------------------------------------------------------------------%
    % --------------------------------------------------------------------%                
                    
                    
            %Referencing general plant parameters for growth calculations
                this.fPlant             = ...
                    components.PlantModule.PlantParameters();
           
            
            
        %% -PlantModule Structure-
        
            % Creating the filter, last parameter is the filter capacity in kg.
                this.addStore(matter.store(this, 'PlantCultivationStore', 32));
            
            %Adding Air Phase:   -> aoPhases(1); Cultivation Store
                oAerationPhase = matter.phases.gas(this.toStores.PlantCultivationStore, ...                     %Store in which the phase is located
                    'air', ...                                                                                  %Phase name
                    struct('O2', 0.5584,'N2', 1.8508,'CO2', 0.003493,'H2O', 0.0169), ...                        %Phase contents
                    2, ...                                                                                      %Phase volume
                    293.15);                                                                                    %Phase temperature
            % creating exmes:
                matter.procs.exmes.gas(oAerationPhase,  'p1');
                matter.procs.exmes.gas(oAerationPhase,  'p2');
                matter.procs.exmes.gas(oAerationPhase,  'p3');  %Air phase
                matter.procs.exmes.gas(oAerationPhase,  'p9');  %Air phase
                matter.procs.exmes.gas(oAerationPhase,  'p11'); %Air phase 
            
            
            %Adding Plants:     -> aoPhases(2); Cultivation Store
                oPlants = matter.phases.liquid(this.toStores.PlantCultivationStore, ...     %Store in which the phase is located
                    'Plants', ...                                                           %Phase name
                    struct('H2O', 0.1,'CO2', 0.1,'O2', 0.1), ...                            %Phase contents
                    10, ...                                                                %Phase volume
                    293.15, ...                                                             %Phase temperature
                    101325);                                                                %Phase pressure
            


            % Adding a default extract/merge processor to the phase
                matter.procs.exmes.liquid(oPlants, 'p4'); %Plants phase
                matter.procs.exmes.liquid(oPlants, 'p5');
                matter.procs.exmes.liquid(oPlants, 'p8'); %Plants phase
                matter.procs.exmes.liquid(oPlants, 'p10'); %Plants phase

                matter.procs.exmes.liquid(oPlants, 'p12');
                matter.procs.exmes.liquid(oPlants, 'p13');
            
            
            
            % Adding HarvestInedible:  -> aoPhases(3); Cultivation Store
            oHarvestInedible = matter.phases.liquid(this.toStores.PlantCultivationStore, ...    %Store in which the phase is located
                'HarvestInedible', ...                                                          %Phase name
                struct('Waste',0.1), ...                                    %Phase contents
                10, ...                                                                         %Phase volume
                293.15, ...                                                             %Phase temperature
                101325);                                                                %Phase pressure    
            
            % Adding a default extract/merge processor to the phase            
            matter.procs.exmes.liquid(oHarvestInedible, 'p14');
            matter.procs.exmes.liquid(oHarvestInedible, 'p15');
            
            
            %Adding HarvestEdible:     -> aoPhases(4); Cultivation Store
            oHarvestEdible = matter.phases.liquid(this.toStores.PlantCultivationStore, ...   Store in which the phase is located
                'HarvestEdible', ...         Phase name
                struct('Food',0.1), ...      Phase contents
                10, ...                 Phase volume
                293.15, ...             %Phase temperature
                101325);               %Phase pressure
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.liquid(oHarvestEdible, 'p16');
            matter.procs.exmes.liquid(oHarvestEdible, 'p17');
            
            
            
            
            
        %Initializing manipulator for creating biomass and handling gas exchanges
            this.oManip_Create_Biomass                                  ...    % Object name       
                = components.PlantModule.Create_Biomass(                ...    % Path to class constructor
                                            ... %-Input Parameters_
                                                this,                   ...    % Forwarding current object     
                                                'PlantReactor',         ...    % Name of manipulator     
                                                oPlants,                ...    % Plants-phase
                                                this.PlantEng,          ...    % Culture setups
                                                this.fPlant,            ...    % Plant parameters
                                                this.fWaterAvailable,   ...    % Water mass available       [kg]
                                                this.fP_atm,            ...    % Pressure                   [Pa]
                                                this.fRH_day,           ...    % Relative humidity day      [-]
                                                this.fRH_night,         ...    % Relative humidity night    [-]
                                                this.fPPF,              ...    % Photosynthetic photon flux [µmol/m^2/s]
                                                this.fCO2ppm,           ...    % CO2 level                  [µmol/mol]
                                                this.fCO2ppm_Measured,  ...    % CO2 level in LSS           [µmol/mol]
                                                this.fH,                ...    % Photoperiod per day        [h/d]     
                                                this.fTemp_light,       ...    % Mean air temperature       [°C]
                                                this.fTemp_dark);             % Mean air temperature       [°C]

            
         %Gas exchange p2p-processors    PlantCultivationStore: Plants-phase <-> air-phase
           %Initializing the processor for exchanging water (transpiration)
            this.oProc_Plants_H2OGasExchange                                ... % Object name
                = components.PlantModule.Set_Plants_H2OGasExchange(         ... % Path to class constructor
                this.toStores.PlantCultivationStore,                        ... % Store of treated phases
                'filterproc',                                               ... % Name of processor
                'Plants.p4',                                                ... % Input phase
                'air.p3',                                                   ... % Output phase
                'H2O');                                                         % Matter to process
           %Initializing the processor for exchanging oxygen
            this.oProc_Plants_O2GasExchange                                 ... % Object name
                = components.PlantModule.Set_Plants_O2GasExchange(          ... % Path to class constructor
                this.toStores.PlantCultivationStore,                        ... % Store of treated phases
                'filterproc2',                                              ... % Name of processor
                'Plants.p8',                                                ... % Input phase
                'air.p9',                                                   ... % Output phase
                'O2');                                                          % Matter to process
           %Initializing the processor for exchanging carbon dioxide
            this.oProc_Plants_CO2GasExchange                                ... % Object name
                = components.PlantModule.Set_Plants_CO2GasExchange(         ... % Path to class constructor
                this.toStores.PlantCultivationStore,                        ... % Store of treated phases
                'filterproc3',                                              ... % Name of processor
                'air.p11',                                                  ... % Input phase
                'Plants.p10',                                               ... % Output phase
                'CO2');                                                         % Matter to process
            
            
            
         %Harvest p2p-processors  
           %Initializing the processor that extracts inedible biomass from
           %Plants-phase to the HarvestInedible-Phase inside of the PlantCultivationStore
            this.oProc_Harvest_InedibleBiomass                              ... % Object name
                = components.PlantModule.Harvest_InedibleBiomass(           ... % Path to class constructor
                this.toStores.PlantCultivationStore,                        ... % Store of treated phases
                'filterproc4',                                              ... % Name of processor
                'Plants.p12',                                               ... % Input phase
                'HarvestInedible.p14');                                         % Output phase
            
           %Initializing the processor that extracts edible biomass from
           %Plants-phase to the HarvestEdible-Phase inside of the PlantCultivationStore
            this.oProc_Harvest_EdibleBiomass                                ... % Object name
                = components.PlantModule.Harvest_EdibleBiomass(             ... % Path to class constructor
                this.toStores.PlantCultivationStore,                        ... % Store of treated phases
                'filterproc5',                                              ... % Name of processor
                'Plants.p13',                                               ... % Input phase
                'HarvestEdible.p16');                                           % Output phase
            
            
       %Initializing manipulators for tranforming plant specific biomass 
           %Initializing the manipulator for tranforming plant specific
           %inedible biomass to waste
            this.oManip_Process_InediblePlantsToWaste                           ... % Object name
                = components.PlantModule.Process_InediblePlantsToWaste(         ... % Path to class constructor
                'InedibleHarvestReactor',                                       ... % Name of manipulator
                oHarvestInedible);                                                  % Treated phase
           %Initializing the manipulator for tranforming plant specific
           %edible biomass to food
            this.oManip_Process_EdiblePlantsToFood                              ... % Object name
                = components.PlantModule.Process_EdiblePlantsToFood(            ... % Path to class constructor
                'EdibleHarvestReactor',                                         ... % Name of manipulator
                oHarvestEdible);                                                    % Treated phase
                     
            
            
            
        %% -Connections- 
        
            % Adding pipes to connect the components
                this.addProcF2F(components.pipe('Pipe_1', 0.5, 0.01));
                this.addProcF2F(components.pipe('Pipe_2', 0.5, 0.01));
                this.addProcF2F(components.pipe('Pipe_3', 0.5, 0.01));
                this.addProcF2F(components.pipe('Pipe_4', 0.5, 0.01));
                this.addProcF2F(components.pipe('Pipe_5', 0.5, 0.01));
            
            
            % Creating the flowpath (=branch) between the components
                oInput_Air_Branch       = this.createBranch('PlantCultivationStore.p1',     { 'Pipe_1' }, 'FromLSSAirIN');
                oOutput_Air_Branch      = this.createBranch('PlantCultivationStore.p2',     { 'Pipe_2' }, 'ToLSSAirOUT');
                oInput_Water_Branch     = this.createBranch('PlantCultivationStore.p5',     { 'Pipe_3' }, 'WaterSupply');
                oOutput_Food_Branch     = this.createBranch('PlantCultivationStore.p17',    { 'Pipe_4' }, 'FoodOUT');
                oOutput_Waste_Branch    = this.createBranch('PlantCultivationStore.p15',    { 'Pipe_5' }, 'WasteOUT');
            
            
            
            
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            
            
            %Assigning the subsystem interface branches to the manual solver
                this.oInputAirBranch    = solver.matter.manual.branch(oInput_Air_Branch);
                this.oOutputAirBranch   = solver.matter.manual.branch(oOutput_Air_Branch);
                this.oInputWaterBranch  = solver.matter.manual.branch(oInput_Water_Branch);
                this.oOutputFoodBranch  = solver.matter.manual.branch(oOutput_Food_Branch);
                this.oOutputWasteBranch = solver.matter.manual.branch(oOutput_Waste_Branch);
            

            %Setting fixed timestep for phases of PlantCultivationStore
                aoPhases = this.toStores.PlantCultivationStore.aoPhases;
                    %air-phase
                        aoPhases(1).fFixedTS = 15;
                    %Plants-phase
                        aoPhases(2).fFixedTS = 15;
                    %Inedible-phase
                        aoPhases(3).fFixedTS = 15;
                    %Edible-phase
                        aoPhases(4).fFixedTS = 15;
            
            %Setting the pressure of PlantCultivationStore's Plants-phase
%                 this.toStores.PlantCultivationStore.aoPhases(2).setPressure(101325);

            %Default setting of the interface flowrates
                this.oInputAirBranch.setFlowRate(0);
                this.oOutputAirBranch.setFlowRate(0);
                this.oInputWaterBranch.setFlowRate(0);
                this.oOutputFoodBranch.setFlowRate(0);
                this.oOutputWasteBranch.setFlowRate(0);
                
        end
        
        function setIfFlows(this, sFromLSSAirIN, sToLSSAirOUT, sWaterSupply, sFoodOUT, sWasteOUT)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
                this.connectIF('FromLSSAirIN'   ,   sFromLSSAirIN);
                this.connectIF('ToLSSAirOUT'    ,   sToLSSAirOUT);
                this.connectIF('WaterSupply'    ,   sWaterSupply);
                this.connectIF('FoodOUT'        ,   sFoodOUT);
                this.connectIF('WasteOUT'       ,   sWasteOUT);
            
            
        end
    end
    
    
    %% -Updating-
    methods (Access = protected)
        
        function exec(this, ~)

            exec@vsys(this);
            

            global bUseLSSConditions

            if bUseLSSConditions == 1 
                
                        if this.oParent.oParent.oData.oTimer.fTime > 1 % condition necessary for initialization
   
    %     THIS SECTION NEEDS TO BE ADAPTED WHEN APPLYING A NEW SYSTEM     %         
    %                       (ADAPTIONS 2 of 3)                            %
    % ------------------------------------------------------------------- %
    % ------------------------------------------------------------------- %

    %  The object paths to the "measured" LSS growth conditions should be %
    %  stated here - They are specific for your system                    %
    
    % TODO The temperature should also be taken from he phase or store this
    % plant module is located in. Has massive implications for other,
    % lower-level classes of the plant module and requires massive
    % refactoring.
    
        % CO2 level air-phase, parts per million
            this.fCO2ppm_Measured   ...                     % [µmol/mol]
                = this.oParent.fCO2ppm_Measured;                          
        % Relative Humidity air-phase
            this.fRH_Measured       ...                     % [-]
                = this.oParent.toStores.GH_Unit.aoPhases(1).rRelHumidity; 
        % Atmospheric pressure air-phase
            this.fP_atm_Measured    ...                     % [Pa]
                = this.oParent.toStores.GH_Unit.aoPhases(1).fPressure;    
 
    % ------------------------------------------------------------------- %
    % ------------------------------------------------------------------- %                    
                        
                        end
                    

                
                
                
                this.fCO2ppm    = this.fCO2ppm_Measured;
                this.fRH_day    = this.fRH_Measured;
                this.fRH_night  = this.fRH_Measured;
                this.fP_atm     = this.fP_atm_Measured;
                
            else % If bUseLSSConditions == 0 -> predefined growth conditions are used
                
                this.fCO2ppm    = this.fCO2ppm_Predefined;
                this.fRH_day    = this.fRH_day_Predefined;
                this.fRH_night  = this.fRH_night_Predefined;
                this.fP_atm     = this.fP_atm_Predefined;
                
            end 
            
            
            
    %     THIS SECTION NEEDS TO BE ADAPTED WHEN APPLYING A NEW SYSTEM     %         
    %                       (ADAPTIONS 3 of 3)                            %
    % ------------------------------------------------------------------- %
    % ------------------------------------------------------------------- %

    %  The object paths to the "measured" LSS growth conditions should be %
    %  stated here - They are specific for your system                    %
            
            if this.oParent.oParent.oData.oTimer.fTime > 1 
        % CO2 level air-phase, parts per million
            this.fCO2ppm_Measured   ...                     % [µmol/mol]
                = this.oParent.fCO2ppm_Measured;

            end
        % Mass of available water for plant growth
            this.fWaterAvailable    ...                     % [kg]
                = this.oParent.toStores.WaterTank.aoPhases(1).fMass;
            
    % ------------------------------------------------------------------- %
    % ------------------------------------------------------------------- %           
            
            



            %Updating parameters in the 'Create_Biomass' manipulator                
                this.oManip_Create_Biomass.fWaterAvailable      = this.fWaterAvailable;
                this.oManip_Create_Biomass.fP_atm               = this.fP_atm;
                this.oManip_Create_Biomass.fRH_day              = this.fRH_day;
                this.oManip_Create_Biomass.fRH_night            = this.fRH_night;                
                this.oManip_Create_Biomass.fCO2ppm_Measured     = this.fCO2ppm_Measured;
                this.oManip_Create_Biomass.fH                   = this.fH;
            
                
            %Forwarding the gas exchange rates calculated by the plant model to the corresponding absorbers 
                this.oProc_Plants_H2OGasExchange.fwater_exchange    = this.oManip_Create_Biomass.fwater_exchange;
                this.oProc_Plants_CO2GasExchange.fCO2_exchange      = this.oManip_Create_Biomass.fCO2_exchange;
                this.oProc_Plants_O2GasExchange.fO2_exchange        = this.oManip_Create_Biomass.fO2_exchange;
            
                
            %Updating the matter specific masses of Plants-phase inside the inside the harvest processors
                this.oProc_Harvest_InedibleBiomass.afMass   = this.toStores.PlantCultivationStore.aoPhases(1,2).afMass;
                this.oProc_Harvest_EdibleBiomass.afMass     = this.toStores.PlantCultivationStore.aoPhases(1,2).afMass;
                
                
            %Setting gas/water exchange rates:  Greenhouse <-> PlantModule
                % Gas exchange, 'air'-phases
                    % Greenhouse  -> PlantModule
                    this.oInputAirBranch.setFlowRate(-0.03);  % [kg/s]
                    % PlantModule -> Greenhouse
                    this.oOutputAirBranch.setFlowRate(0.03 + this.oProc_Plants_H2OGasExchange.fFlowRate + this.oProc_Plants_O2GasExchange.fFlowRate - this.oProc_Plants_CO2GasExchange.fFlowRate);  % [kg/s]
                % Water supply flowrate
                    this.oInputWaterBranch.setFlowRate(-this.oManip_Create_Biomass.fWaterNeed);  % [kg/s]

            
            %Harvesting - Produced biomass in PlantModule is extracted to
            %biomass stores (food/waste) located in the connected LSS main system
                %Inedible Biomass
                   if this.toStores.PlantCultivationStore.aoPhases(3).fMass > 0.1
                        this.oOutputWasteBranch.setFlowRate(0.001);
                   else
                       this.oOutputWasteBranch.setFlowRate(0);
                   end;
                %Edible Biomass
                    if this.toStores.PlantCultivationStore.aoPhases(4).fMass > 0.1
                        this.oOutputFoodBranch.setFlowRate(0.001);
                   else
                       this.oOutputFoodBranch.setFlowRate(0);
                   end;
            
            
        end
        
    end
    
end

