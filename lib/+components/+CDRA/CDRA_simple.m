classdef CDRA_simple < vsys
    
    
    %% Carbon Dioxide Removal Assembly (CDRA) Subsystem File
    %
    % TO DO: re-verify the CDRA_simple lib component (since some changes
    % have been made to it)
    %
    % Alternative Name: 4BMS or 4 Bed Molecular Sieve
    %
    % The ISS uses two CDRAs as part of the US life support systems. One is
    % located in Node 3 and the other in the US Lab. Each CDRA gets air from 
    % a Common Cabin Air Assembly (CCAA) that has first passed through a
    % condesing heat exchanger to remove most of the humidity in the air.
    % This is done because the adsorption of water and CO2 on zeolite would
    % favor wator instead of CO2. The CDRA itself consists of 4 adsorber 
    % beds of which 2 are used to remove CO2 while the others are used to 
    % remove the remaining humidity before the CO2 adsorbing beds.
    %
    % Because insufficent data was available for the Russian systems the
    % CDRA subsystem file is also used to generate the Russian CO2
    % scrubber, which is called Vozdukh. The values for CDRA (like cycle
    % time etc) are adapted to match Vozdukh. However in "Overview of 
    % Carbon Dioxide Control Issues During International Space Station/Space 
    % Shuttle Joint Docked Operations" Christopher M Matty
    % it is mentioned that vozdukh uses amine based adsorbent instead of
    % zeolite and therefore Vozdukh should be given an idependent model
    % that is at least based on amine.
    
    properties
        %The maximum power in watt for the electrical heaters that are used
        %to increase the zeolite temperature during the CO2 scrubbing.
        fMaxHeaterPower = 900;          % [W]
        
        %Target temperature the zeolite is supposed to reach during the
        %desorption of CO2
        TargetTemperature = 477.15;     % [K]
        
        %Number of active cycle (can be 1 or 2, so either cycle 1 is active
        %or cycle 2)
        iCycleActive = 2;
        
        %Mass flow rate for the air that is passing through the system.
        %If the subsystem is a CDRA this depends on the value set by the
        %CCAA, but if it is a Vozdukh the values is based on a volumetric
        %flow rate.
        fFlowrateMain;                  % [kg/s]
        
        %Mass of filtered CO2 at the beginning of the desorption process.
        %This is required to set the correct flowrates for the manual
        %branches.
        fInitialFilterMass;             % [kg]
        
        %Total time a cycle is active before switching to the other one.
        %This is also called half cycle sometimes with a full cycle beeing
        %considered the time it takes for both cycles to finish once. For
        %CDRA this is 144 minutes and for Vozdukh it is 30 minutes
        fCycleTime;                     % [s]
        
        %The amount of time that is spent in the air safe mode at the
        %beginning of the CO2 desorption phase. During the air safe vacuum
        %pumps are used to pump the air (and some CO2) within the adsorber 
        %bed back into the cabin before the bed is connected to vacuum.
        fAirSafeTime;                   % [s]

        %Boolean Variable to decide if this system is supposed to be a
        %Vozdukh (in which case it is 1, in every other case it is 0)
        bVozdukh;
        
        % Subsystem name for the CCAA that is connected to this CDRA
        sAsscociatedCCAA;
        
        % Object of the phase to which this Subsystem is connected.
        % Required to calculate the mass flow based on the volumetric flow
        % rate for Vozdukh
        oAtmosphere;
        
        tAtmosphere;
    end
    
    methods
        function this = CDRA_simple(oParent, sName, fTimeStep, tAtmosphere, sAsscociatedCCAA, bVozdukh)
            this@vsys(oParent, sName, fTimeStep);
            
            this.sAsscociatedCCAA = sAsscociatedCCAA;
            
            this.tAtmosphere = tAtmosphere;
        
            %If the inputs for the subsystem file indicate that this system
            %is Vozdukh the required properties are set. Otherwise the
            %bVozdukh variable is set to 0 to indicate that this is a CDRA.
            if nargin > 6
                this.bVozdukh = bVozdukh;
            else
                this.bVozdukh = 0;
            end
            %Setting of the cycle time and air safe time depending on which
            %system is simulated
            if this.bVozdukh == 1
                this.fCycleTime = 30*60;
                this.fAirSafeTime = 2*60;
            else
                this.fCycleTime = 144*60;
                this.fAirSafeTime = 10*60;
            end
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            fPressure = 101325;
            fCO2Percent = 0.0038;
            
            %% Creating the stores  
            % CDRA Adsorber Bed Cross Section
            % quadratic cross section with ~16 channels of~13mm length according to a presentation at the comsol conference 2015
            % "Multi-Dimensional Simulation of Flows Inside Polydisperse Packed Beds"
            % download link https://www.google.de/url?sa=t&rct=j&q=&esrc=s&source=web&cd=6&cad=rja&uact=8&ved=0ahUKEwjwstb2-OfKAhXEoQ4KHdkUAC8QFghGMAU&url=https%3A%2F%2Fwww.comsol.com%2Fconference2015%2Fdownload-presentation%2F29402&usg=AFQjCNERyzJcfMautp6BfFFUERc1FvISNw&bvm=bv.113370389,d.bGg
            % sorry couldn't find a better one.
            fCrossSection = (16*13E-3)^2; 
            
            tGeometry5A.fCrossSection       = fCrossSection;
            
            % Length for the individual filter material within CDRA
            % according to ICES-2014-160
            tGeometry5A.fLength         =  16.68        *2.54/100;
            
            %From ICES-2014-168 Table 2 e_sorbent
            tGeometry5A.rVoidFraction       = 0.445;
            
            % Assuming a human produces ~ 1kg of CO2 per day and CDRA is
            % sized for 6 humans at 400 Pascal partial pressure of CO2 then
            % each CDRA has to absorb (1/(24*60))*144*6 = 600g CO2 per
            % cycle (144 min cycle time, 6 humans). However that does not
            % yet take into account that CDRA (through the air safe mode
            % used at the beginning of the desorption) also releases some
            % of the CO2 back into the cabin. Test data for CDRA
            % (00ICES-234 'International Space Station Carbon Dioxide
            % Removal Assembly Testing' James C. Knox) shows that this
            % release back into the cabin is ~60 Pascal of Partial Pressure
            % for a Volume of ~100m³. Using the ideal gas law with room
            % temperature this release of CO2 back into the cabin can be
            % calculate to about 110g per cycle. This means that the
            % capacity has to be at least 710g. But the maximum capacity is
            % hard to reach and it is save to assume that each bed requires
            % a capacity of ~800g to 900g of CO2 at 400 Pa partial
            % pressure. At that partial pressure the zeolite capacity is
            % ~35g CO2 for each kg of zeolite. Therefore the zeolite mass
            % has to be around 23 to 26 kg. (current calculation results in
            % ~25kg)
            fMassZeolite5A          = fCrossSection * tGeometry5A.fLength       * this.oMT.ttxMatter.Zeolite5A_RK38.ttxPhases.tSolid.Density;
            
            
            % Creating the Filter_13X_1 (H2O filter)
            % TO DO:
            % Should use Zeolite13x for the afMass struct but no matter data
            % for that zeolite is saved in the matter table at the moment.
            % Therefore zeolite 5A is used as an approximation. Also the
            % value used for the zeolite mass is not correct
            tfMasses = struct('H2O', 0, 'Zeolite5A', 4);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter_13X_1', 0.084557+fSolidVolume);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Filter_13X_1, 0.084557, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, this.tAtmosphere.fRelHumidity, fPressure);
            oInput = matter.phases.gas(this.toStores.Filter_13X_1, 'PhaseIn', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter_13X_1, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Zeolite5A'); 
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In_1');
            matter.procs.exmes.gas(oInput, 'Flow_In_2');
            matter.procs.exmes.gas(oInput, 'Flow_Out_1');
            matter.procs.exmes.gas(oInput, 'Flow_Out_2');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            
            % Create the Filterproc
            if this.bVozdukh == 1
                components.CDRA.components.Filter(this.toStores.Filter_13X_1, 'Filter_13X_1_proc', 'PhaseIn.filterport', 'FilteredPhase.filterport', 'Filter_13x', (this.fCycleTime));                
            else
                components.CDRA.components.Filter(this.toStores.Filter_13X_1, 'Filter_13X_1_proc', 'PhaseIn.filterport', 'FilteredPhase.filterport', 'Filter_13x', (this.fCycleTime));
            end
            
            % Creating the Filter_13X_2 (H2O filter)
            
            % TO DO:
            % Should use Zeolite13x for the afMass struct but no matter data
            % for that zeolite is saved in the matter table at the moment.
            % Therefore zeolite 5A is used as an approximation. Also the
            % value used for the zeolite mass is not correct
            tfMasses = struct('H2O', 0.031, 'Zeolite5A', 4);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter_13X_2', 0.084557+fSolidVolume);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Filter_13X_2, 0.084557, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, this.tAtmosphere.fRelHumidity, fPressure);
            oInput = matter.phases.gas(this.toStores.Filter_13X_2, 'PhaseIn', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter_13X_2, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Zeolite5A');
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In_1');
            matter.procs.exmes.gas(oInput, 'Flow_In_2');
            matter.procs.exmes.gas(oInput, 'Flow_Out_1');
            matter.procs.exmes.gas(oInput, 'Flow_Out_2');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            % Create the Filterproc
            if this.bVozdukh == 1
                components.CDRA.components.Filter(this.toStores.Filter_13X_2, 'Filter_13X_2_proc', 'PhaseIn.filterport', 'FilteredPhase.filterport', 'Filter_13x', (this.fCycleTime));
            else
                components.CDRA.components.Filter(this.toStores.Filter_13X_2, 'Filter_13X_2_proc', 'PhaseIn.filterport', 'FilteredPhase.filterport', 'Filter_13x', (this.fCycleTime));
            end
            
            % Creating the Filter5A_1 (CO2 filter)
            tfMasses = struct('CO2', 0.05, 'Zeolite5A', fMassZeolite5A);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter5A_1', 0.084557+fSolidVolume);
            % Input phase
            tCO2.sSubstance = 'CO2';
            tCO2.sProperty = 'Density';
            tCO2.sFirstDepName = 'Pressure';
            tCO2.fFirstDepValue = 101325;
            tCO2.sSecondDepName = 'Temperature';
            tCO2.fSecondDepValue = this.tAtmosphere.fTemperature;
            tCO2.sPhaseType = 'gas';
            fDensityCO2 = this.oMT.findProperty(tCO2);
            
            oInput = matter.phases.gas(this.toStores.Filter5A_1, ...
                          'PhaseIn', ...                            % Phase name
                          struct('CO2', fDensityCO2*0.084557), ...  % Phase contents
                          0.084557, ...                             % Phase volume
                          this.tAtmosphere.fTemperature);                      % Phase temperature 
            
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter5A_1, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Zeolite5A');
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In');
            matter.procs.exmes.gas(oInput, 'Flow_Out_1');
            matter.procs.exmes.gas(oInput, 'Flow_Out_2');
            matter.procs.exmes.gas(oInput, 'Flow_Out_AirSafe');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            
            % Create the Filterproc
            if this.bVozdukh == 1
                oFilter1 = components.CDRA.components.Filter(this.toStores.Filter5A_1, 'Filter5A_1_proc', 'PhaseIn.filterport', 'FilteredPhase.filterport', 'Filter_5A', (this.fCycleTime), this.fAirSafeTime);
            else
                oFilter1 = components.CDRA.components.Filter(this.toStores.Filter5A_1, 'Filter5A_1_proc', 'PhaseIn.filterport', 'FilteredPhase.filterport', 'Filter_5A', (this.fCycleTime), this.fAirSafeTime);
            end
            
            % Creating the Filter5A_2 (CO2 filter)
            tfMasses = struct('CO2', 0, 'Zeolite5A', fMassZeolite5A);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter5A_2', 0.084557+fSolidVolume);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Filter5A_2, 0.084557, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, this.tAtmosphere.fRelHumidity, fPressure);
            oInput = matter.phases.gas(this.toStores.Filter5A_2, 'PhaseIn', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter5A_2, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Zeolite5A');
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In');
            matter.procs.exmes.gas(oInput, 'Flow_Out_1');
            matter.procs.exmes.gas(oInput, 'Flow_Out_2');
            matter.procs.exmes.gas(oInput, 'Flow_Out_AirSafe');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            % Create the Filterproc
            if this.bVozdukh == 1
                oFilter2 = components.CDRA.componentsFilter(this.toStores.Filter5A_2, 'Filter5A_2_proc', 'PhaseIn.filterport', 'FilteredPhase.filterport', 'Filter_5A', (this.fCycleTime), this.fAirSafeTime);
            else
                oFilter2 = components.CDRA.components.Filter(this.toStores.Filter5A_2, 'Filter5A_2_proc', 'PhaseIn.filterport', 'FilteredPhase.filterport', 'Filter_5A', (this.fCycleTime),this.fAirSafeTime);
            end
            
            % Adding the Precoolers which are used to decrease the air
            % temperature before it enters the CO2 adsorber beds to
            % increase the adsorption efficiency.
            components.Temp_Dummy(this, 'Precooler_1', 283); 
            components.Temp_Dummy(this, 'Precooler_2', 283);
            % previously CDRA used the colder temperature of 276 K for the
            % pre coolers but at that temperature the humidity that is
            % reinserted into the air stream after the CO2 adsorption would
            % condense resulting in matter table errors
            
            % Adding two times eight pipes to connect the components
            % Two sets are necessary to create both cycles
            components.pipe(this, 'Pipe_1', 1, 0.1);
            components.pipe(this, 'Pipe_2', 1, 0.1);
            components.pipe(this, 'Pipe_3', 1, 0.1);
            components.pipe(this, 'Pipe_4', 1, 0.1);
            components.pipe(this, 'Pipe_5', 1, 0.1);
            components.pipe(this, 'Pipe_6', 1, 0.1);
            components.pipe(this, 'Pipe_1_2', 1, 0.1);
            components.pipe(this, 'Pipe_2_2', 1, 0.1);
            components.pipe(this, 'Pipe_3_2', 1, 0.1);
            components.pipe(this, 'Pipe_4_2', 1, 0.1);
            components.pipe(this, 'Pipe_5_2', 1, 0.1);
            components.pipe(this, 'Pipe_6_2', 1, 0.1);
            
            %Since the zeolite changes in temperature for the desorption
            %process f2f procs are necessary to model the impact of the
            %cold air flowing past the hot zeolite.
            oF2F_1 = components.CDRA.components.Filter5A_f2f(this, 'Filter5A_1_f2f', this.toStores.Filter5A_1);
            oFilter1.setF2F(oF2F_1)
            oF2F_2 = components.CDRA.components.Filter5A_f2f(this, 'Filter5A_2_f2f', this.toStores.Filter5A_2);
            oFilter2.setF2F(oF2F_2)
            
            %Vozdukh additionally uses heaters to increase the air
            %temperature before it enters the H2O filter bed that is
            %currently desorbing. This increases the amount of water that
            %can be desorbed into the air stream.
            if this.bVozdukh == 1
                components.Heater(this, 'Heater_1', 250);
                components.Heater(this, 'Heater_2', 250);
            end
            
            %% Creating the flowpath into, between and out of this subsystem
            % Branch for flowpath into/out of a subsystem: ('store.exme', {'f2f-processor', 'f2f-processor'}, 'system level port name')
            
            % Cycle one
            matter.branch(this, 'Filter_13X_1.Flow_In_1', {'Pipe_1'}, 'CDRA_Air_In_1', 'Filter_13x1_In');           % Creating the flowpath into this subsystem
            matter.branch(this, 'Filter_13X_1.Flow_Out_1', {'Pipe_2', 'Precooler_1'}, 'Filter5A_2.Flow_In', 'Filter13x1_to_Filter5A2');
            
            if this.bVozdukh == 1
                matter.branch(this, 'Filter5A_2.Flow_Out_1', {'Filter5A_2_f2f', 'Pipe_3', 'Heater_1'}, 'Filter_13X_2.Flow_In_1', 'Filter5A2_to_Filter13x2');
            else
                matter.branch(this, 'Filter5A_2.Flow_Out_1', {'Filter5A_2_f2f', 'Pipe_3'}, 'Filter_13X_2.Flow_In_1', 'Filter5A2_to_Filter13x2');
            end
            
            matter.branch(this, 'Filter_13X_2.Flow_Out_1', {'Pipe_4'}, 'CDRA_Air_Out_1', 'Filter13x2_to_CHX');     % Air to CDRA1 to CCAA2 connection tank
            matter.branch(this, 'Filter5A_1.Flow_Out_1', {'Pipe_5'}, 'CDRA_Vent_1', 'Filter5A1_to_Vent');                      % CO2 to vacuum

            % Cycle two
            matter.branch(this, 'Filter_13X_2.Flow_In_2', {'Pipe_1_2'}, 'CDRA_Air_In_2', 'Filter13x2_In');         % Creating the flowpath into this subsystem
            matter.branch(this, 'Filter_13X_2.Flow_Out_2', {'Pipe_2_2', 'Precooler_2'}, 'Filter5A_1.Flow_In', 'Filter13x2_to_Filter5A1');
           
            if this.bVozdukh == 1
                matter.branch(this, 'Filter5A_1.Flow_Out_2', {'Filter5A_1_f2f', 'Pipe_3_2', 'Heater_2'}, 'Filter_13X_1.Flow_In_2', 'Filter5A1_to_Filter13x1');
            else
                matter.branch(this, 'Filter5A_1.Flow_Out_2', {'Filter5A_1_f2f', 'Pipe_3_2'}, 'Filter_13X_1.Flow_In_2', 'Filter5A1_to_Filter13x1');
            end
            
            matter.branch(this, 'Filter_13X_1.Flow_Out_2',{'Pipe_4_2'}, 'CDRA_Air_Out_2', 'Filter13x1_to_CHX');  % Air to CDRA1 to CCAA2 connection tank
            matter.branch(this, 'Filter5A_2.Flow_Out_2', {'Pipe_5_2'}, 'CDRA_Vent_2', 'Filter5A2_to_Vent');                  % CO2 to vacuum

            %Branches for the Airsafe functionality that pumps out the air
            %from the absorber bed before it is connected to the vacuum.
            matter.branch(this, 'Filter5A_1.Flow_Out_AirSafe', {'Pipe_6'}, 'CDRA_AirSafe_1', 'Filter5A1_AirSafe');
            matter.branch(this, 'Filter5A_2.Flow_Out_AirSafe', {'Pipe_6_2'}, 'CDRA_AirSafe_2', 'Filter5A2_AirSafe');
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Cycle one
            solver.matter.manual.branch(this.aoBranches(1,1));
            solver.matter.manual.branch(this.aoBranches(2,1));
            solver.matter.manual.branch(this.aoBranches(3,1));
            solver.matter.manual.branch(this.aoBranches(4,1));
            solver.matter.manual.branch(this.aoBranches(5,1));

            % Cycle two
            solver.matter.manual.branch(this.aoBranches(6,1));
            solver.matter.manual.branch(this.aoBranches(7,1));
           	solver.matter.manual.branch(this.aoBranches(8,1));
            solver.matter.manual.branch(this.aoBranches(9,1));
            solver.matter.manual.branch(this.aoBranches(10,1));

            %Branches for the Airsafe functionality that pumps out the air
            %from the absorber bed before it is connected to the vacuum.
            solver.matter.manual.branch(this.aoBranches(11,1));
            solver.matter.manual.branch(this.aoBranches(12,1));
            
            
            %All phases except the human air phase work with a 60s time
            %step
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    oPhase.fFixedTS = 5;
                end
            end
        end           
        
        %% Function to connect the system and subsystem level branches with each other
        function setIfFlows(this, sInterface1, sInterface2, sInterface3, sInterface4, sInterface5, sInterface6, sInterface7, sInterface8)
            if nargin == 9
                this.connectIF('CDRA_Air_In_1' , sInterface1);
                this.connectIF('CDRA_Air_In_2' , sInterface2);
                this.connectIF('CDRA_Air_Out_1', sInterface3);
                this.connectIF('CDRA_Air_Out_2', sInterface4);
                this.connectIF('CDRA_Vent_1', sInterface5);
                this.connectIF('CDRA_Vent_2', sInterface6);
                this.connectIF('CDRA_AirSafe_1', sInterface7);
                this.connectIF('CDRA_AirSafe_2', sInterface8);
            else
                error('CDRA Subsystem was given a wrong number of interfaces')
            end
        end
        function setReferencePhase(this, oPhase)
                this.oAtmosphere = oPhase;
        end
        
        function update(this)
            
            % Flow rates of the filtered matter (needed to calculate the following flow rates of the branches)
            fFlowRate13X_1 = this.toStores.Filter_13X_1.toProcsP2P.Filter_13X_1_proc.fFlowRate;
            fFlowRate13X_2 = this.toStores.Filter_13X_2.toProcsP2P.Filter_13X_2_proc.fFlowRate;
            fFlowRate5A_1 = this.toStores.Filter5A_1.toProcsP2P.Filter5A_1_proc.fFlowRate;
            fFlowRate5A_2 = this.toStores.Filter5A_2.toProcsP2P.Filter5A_2_proc.fFlowRate;
            
            if this.bVozdukh == 1
                % Main flow rate through the Vozdukh (source P.Plötner page 32 "...the amount of processed air is known with circa 27m^3 per hour, ...");
                %therefore this volumetric flowrate is transformed into a mass
                %flow based on the current atmosphere conditions.
                this.fFlowrateMain = (27/3600) * this.oAtmosphere.fDensity;
            else
                %for the CDRA/4BMS the main flow rate is the one supplied
                %by the CCAA
                this.fFlowrateMain  = this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.CHX_CDRA.oHandler.fRequestedFlowRate;
            end
            
            % Control mechanism and setting of fixed flow rates
            % Cycle one
            if mod(this.oTimer.fTime, this.fCycleTime * 2) < (this.fCycleTime)
                if this.iCycleActive == 2
                    % Set cycle one filter modes
                    this.toStores.Filter_13X_1.toProcsP2P.Filter_13X_1_proc.setFilterMode('absorb');
                    this.toStores.Filter_13X_2.toProcsP2P.Filter_13X_2_proc.setFilterMode('desorb');
                    this.toStores.Filter5A_2.toProcsP2P.Filter5A_2_proc.setFilterMode('absorb');
                    this.toStores.Filter5A_1.toProcsP2P.Filter5A_1_proc.setFilterMode('desorb');
                    this.iCycleActive = 1;
                    
                    % Set cycle one f2f-procs aktive
                    this.toProcsF2F.Precooler_1.setActive(true, this.oTimer.fTime)
                    
                    % Set cycle two f2f-procs inaktive to increase simulation speed
                    this.toProcsF2F.Precooler_2.setActive(false)
                    
                    % Setting cycle two flow rates zero
                    this.toBranches.Filter13x2_In.oHandler.setFlowRate(0);
                    this.toBranches.Filter13x2_to_Filter5A1.oHandler.setFlowRate(0);
                    this.toBranches.Filter5A1_to_Filter13x1.oHandler.setFlowRate(0);
                    this.toBranches.Filter13x1_to_CHX.oHandler.setFlowRate(0);
                    this.toBranches.Filter5A2_to_Vent.oHandler.setFlowRate(0);
                    
                    this.fInitialFilterMass = this.toStores.Filter5A_1.aoPhases(1,1).fMass;
                end
               
                % Setting cycle one flow rates
                this.toBranches.Filter_13x1_In.oHandler.setFlowRate(-this.fFlowrateMain);
                this.toBranches.Filter13x1_to_Filter5A2.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate13X_1);
                %Since the beds go through a pressure swing where they go
                %from normal pressure to vacuum it is required to refill
                %them first after they enter the adsorption mode.
                if this.toStores.Filter5A_2.aoPhases(1,1).fPressure < 1e5
                    %Actually the inlet flowrates should probably be
                    %changed for the initial refill but no data was
                    %available so here it is assumed that just nothing
                    %flows out until the bed reaches 1 bar pressure
                    this.toBranches.Filter5A2_to_Filter13x2.oHandler.setFlowRate(0);
                    this.toBranches.Filter13x2_to_CHX.oHandler.setFlowRate(0);
                else
                    this.toBranches.Filter5A2_to_Filter13x2.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate5A_2 - fFlowRate13X_1);
                    this.toBranches.Filter13x2_to_CHX.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate13X_2 - fFlowRate5A_2 - fFlowRate13X_1);
                end
                %Desorbing Filter:
                %The CO2 filter that is not used in the active cycle is
                %connected to the vacuum so that it can desorb CO2, but
                %only after the air from the filter has been pumped out
                %back into the cabin (10 minute air safe phase)
                if mod(this.oTimer.fTime, this.fCycleTime * 2) < (this.fAirSafeTime)
                    %assuming that the air safe pump can achieve a pressure
                    %of 5 Pa
                    if this.toStores.Filter5A_1.aoPhases(1,1).fPressure > 500
                        %This whole process should be modelled better but
                        %no data on the flow rates could be found. So here
                        %the flow rate was simply set to ensure that the
                        %phase actually reaches the minimum pressure of 5
                        %Pa during the air safe time
                        this.toBranches.Filter5A1_AirSafe.oHandler.setFlowRate((this.fInitialFilterMass/(this.fAirSafeTime))-fFlowRate5A_1);
                    end
                else
                    %negative value because the filter flow rate during
                    %desorption is negative.
                    this.toBranches.Filter5A1_to_Vent.oHandler.setFlowRate(-fFlowRate5A_1);
                	this.toBranches.Filter5A1_AirSafe.oHandler.setFlowRate(0);
                end
            end
            
            % Cycle two
            if  mod(this.oTimer.fTime, this.fCycleTime * 2) >= (this.fCycleTime)
                if this.iCycleActive == 1
                    % Set cycle two filter modes
                    this.toStores.Filter_13X_1.toProcsP2P.Filter_13X_1_proc.setFilterMode('desorb');
                    this.toStores.Filter_13X_2.toProcsP2P.Filter_13X_2_proc.setFilterMode('absorb');
                    this.toStores.Filter5A_2.toProcsP2P.Filter5A_2_proc.setFilterMode('desorb');
                    this.toStores.Filter5A_1.toProcsP2P.Filter5A_1_proc.setFilterMode('absorb');
                    this.iCycleActive = 2;
                    
                    % Set cycle one f2f-procs inaktive to increase simulation speed
                    this.toProcsF2F.Precooler_1.setActive(false)
                    
                    % Set cycle two f2f-procs aktive
                    this.toProcsF2F.Precooler_2.setActive(true, this.oTimer.fTime)
                    
                    % Setting cycle one flow rates zero
                    this.toBranches.Filter_13x1_In.oHandler.setFlowRate(0);
                    this.toBranches.Filter13x1_to_Filter5A2.oHandler.setFlowRate(0);
                    this.toBranches.Filter5A2_to_Filter13x2.oHandler.setFlowRate(0);
                    this.toBranches.Filter13x2_to_CHX.oHandler.setFlowRate(0);
                    this.toBranches.Filter5A1_to_Vent.oHandler.setFlowRate(0); % Zusatz
                    
                    this.fInitialFilterMass = this.toStores.Filter5A_2.aoPhases(1,1).fMass;
                end
                                
                % Setting cycle two flow rates
                this.toBranches.Filter13x2_In.oHandler.setFlowRate(-this.fFlowrateMain); % Zusatz
                this.toBranches.Filter13x2_to_Filter5A1.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate13X_2);
                %Since the beds go through a pressure swing where they go
                %from normal pressure to vacuum it is required to refill
                %them first after they enter the adsorption mode.
                if this.toStores.Filter5A_1.aoPhases(1,1).fPressure < 1e5
                    %Actually the inlet flowrates should probably be
                    %changed for the initial refill but no data was
                    %available so here it is assumed that just nothing
                    %flows out until the bed reaches 1 bar pressure
                    this.toBranches.Filter5A1_to_Filter13x1.oHandler.setFlowRate(0);
                    this.toBranches.Filter13x1_to_CHX.oHandler.setFlowRate(0);
                else
                    this.toBranches.Filter5A1_to_Filter13x1.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate5A_1 - fFlowRate13X_2);
                    this.toBranches.Filter13x1_to_CHX.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate13X_1 - fFlowRate5A_1 - fFlowRate13X_2);
                end
                %Desorbing Filter:
                %The CO2 filter that is not used in the active cycle is
                %connected to the vacuum so that it can desorb CO2, but
                %only after the air from the filter has been pumped out
                %back into the cabin (10 minute air safe phase)
                if mod(this.oTimer.fTime, this.fCycleTime * 2) < (this.fCycleTime + this.fAirSafeTime)
                    %assuming that the air safe pump can achieve a pressure
                    %of 5 Pa
                    if this.toStores.Filter5A_2.aoPhases(1,1).fPressure > 500
                        %This whole process should be modelled better but
                        %no data on the flow rates could be found. So here
                        %the flow rate was simply set to ensure that the
                        %phase actually reaches the minimum pressure of 5
                        %Pa during the air safe time
                        this.toBranches.Filter5A2_AirSafe.oHandler.setFlowRate((this.fInitialFilterMass/(this.fAirSafeTime))-fFlowRate5A_2);
                    end
                else
                    %negative value because the filter flow rate during
                    %desorption is negative.
                    this.toBranches.Filter5A2_to_Vent.oHandler.setFlowRate(-fFlowRate5A_2);
                   	this.toBranches.Filter5A2_AirSafe.oHandler.setFlowRate(0);
                end
            end
            
            % Filter heater control logic. Activates the heater if the
            % filter is in desorption mode and below the target temperature
            % and deactivates it if it has reached the target temperature
            % or is in adsorption mode
            if mod(this.oTimer.fTime, this.fCycleTime * 2) < this.fCycleTime
                if this.toStores.Filter5A_1.toPhases.FilteredPhase.fTemperature > this.TargetTemperature
                   this.toStores.Filter5A_1.toProcsP2P.Filter5A_1_proc.setHeaterPower(0);
                elseif this.toStores.Filter5A_1.toPhases.FilteredPhase.fTemperature < (this.TargetTemperature * 0.99)
                    this.toStores.Filter5A_1.toProcsP2P.Filter5A_1_proc.setHeaterPower(this.fMaxHeaterPower);
                end
            else
                this.toStores.Filter5A_1.toProcsP2P.Filter5A_1_proc.setHeaterPower(0);
            end
            
            if mod(this.oTimer.fTime, this.fCycleTime * 2) > this.fCycleTime
                if this.toStores.Filter5A_2.toPhases.FilteredPhase.fTemperature > this.TargetTemperature
                    this.toStores.Filter5A_2.toProcsP2P.Filter5A_2_proc.setHeaterPower(0);
                elseif this.toStores.Filter5A_2.toPhases.FilteredPhase.fTemperature  < (this.TargetTemperature * 0.99)
                    this.toStores.Filter5A_2.toProcsP2P.Filter5A_2_proc.setHeaterPower(this.fMaxHeaterPower);
                end
            else
                this.toStores.Filter5A_2.toProcsP2P.Filter5A_2_proc.setHeaterPower(0);
            end
            
             % sets the interface flowrate for the CCAA (from CDRA to CCAA)
            fIF_Flow = this.toBranches.Filter13x2_to_CHX.oHandler.fRequestedFlowRate + this.toBranches.Filter13x1_to_CHX.oHandler.fRequestedFlowRate;
            this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.CDRA_TCCV.oHandler.setFlowRate(-fIF_Flow);
            
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            this.update();
        end
	end
end