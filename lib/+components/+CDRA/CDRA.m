classdef CDRA < vsys
    
    
    %% Carbon Dioxide Removal Assembly (CDRA) Subsystem File
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
    
    properties
        %The maximum power in watt for the electrical heaters that are used
        %to increase the zeolite temperature during the CO2 scrubbing.
        % TO DO: didnt find an actual reference so for now using a values
        % that seems plausible
        fMaxHeaterPower = 2000;          % [W] 
        
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
        
        % Subsystem name for the CCAA that is connected to this CDRA
        sAsscociatedCCAA;
        
        toCDRA_Heaters;
        
        % Object of the phase to which this Subsystem is connected.
        % Required to calculate the mass flow based on the volumetric flow
        % rate for Vozdukh
        oAtmosphere;
        
        tAtmosphere;
    end
    
    methods
        function this = CDRA(oParent, sName, tAtmosphere, sAsscociatedCCAA)
            this@vsys(oParent, sName, 5);
            
            this.sAsscociatedCCAA = sAsscociatedCCAA;
            
            this.tAtmosphere = tAtmosphere;
        
            %Setting of the cycle time and air safe time depending on which
            %system is simulated
            this.fCycleTime = 144*60;
            this.fAirSafeTime = 10*60;
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            fPressure = 101325;
            fCO2Percent = 0.0054;
            
            %% Creating the stores  
            % CDRA Adsorber Bed Cross Section
            % quadratic cross section with ~16 channels of~13mm length according to a presentation at the comsol conference 2015
            % "Multi-Dimensional Simulation of Flows Inside Polydisperse Packed Beds"
            % download link https://www.google.de/url?sa=t&rct=j&q=&esrc=s&source=web&cd=6&cad=rja&uact=8&ved=0ahUKEwjwstb2-OfKAhXEoQ4KHdkUAC8QFghGMAU&url=https%3A%2F%2Fwww.comsol.com%2Fconference2015%2Fdownload-presentation%2F29402&usg=AFQjCNERyzJcfMautp6BfFFUERc1FvISNw&bvm=bv.113370389,d.bGg
            % sorry couldn't find a better one.
            fCrossSection = (16*13E-3)^2; 
            
            tGeometry5A.fCrossSection       = fCrossSection;
            tGeometrySylobead.fCrossSection = fCrossSection;
            tGeometry13x.fCrossSection      = fCrossSection;
            
            % Length for the individual filter material within CDRA
            % according to ICES-2014-160
            tGeometry5A.fLength         =  16.68        *2.54/100;
            tGeometrySylobead.fLength   =  6.13         *2.54/100;
            tGeometry13x.fLength        = (5.881+0.84)  *2.54/100;
            
            %From ICES-2014-168 Table 2 e_sorbent
            tGeometry13x.rVoidFraction      = 0.457;
            tGeometry5A.rVoidFraction       = 0.445;
            tGeometrySylobead.rVoidFraction = 0.348;
            
            fMassZeolite13x         = fCrossSection * tGeometry13x.fLength      *  (1 - tGeometry13x.rVoidFraction)       * this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density;
            fMassSylobead           = fCrossSection * tGeometrySylobead.fLength *  (1 - tGeometrySylobead.rVoidFraction)  * this.oMT.ttxMatter.Sylobead_B125.ttxPhases.tSolid.Density;
            fMassZeolite5A          = fCrossSection * tGeometry5A.fLength       *  (1 - tGeometry5A.rVoidFraction)        * this.oMT.ttxMatter.Zeolite5A_RK38.ttxPhases.tSolid.Density;
            
            % These are the correct estimates for the flow volumes of each
            % bed which are used in the filter adsorber proc for
            % calculations. Factor of 0.1 used to fit the behaviour to CDRA
            % test data.
            tGeometry13x.fVolumeFlow          = 0.25 * tGeometry13x.fCrossSection        * tGeometry13x.fLength      * tGeometry13x.rVoidFraction;
            tGeometrySylobead.fVolumeFlow     = 0.25 * tGeometrySylobead.fCrossSection   * tGeometrySylobead.fLength * tGeometrySylobead.rVoidFraction;
            tGeometry5A.fVolumeFlow           = 0.25 * tGeometry5A.fCrossSection         * tGeometry5A.fLength       * tGeometry5A.rVoidFraction;
            
            % But the volume used for the V-HAB is larger to allow faster
            % calculation times
            fVolumeFlow = 0.1;
            
            % Creating the Sylobead Filter (H2O filter) Note that this
            % filter and the 13x filter are actually one filter within CDRA
            % but since it is not possible to geometrically model the
            % location of the adsorbents within one store the two had to be
            % seperated
            tfMasses = struct('H2O', 0, 'Sylobead_B125', fMassSylobead);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter_Sylobead_1', fVolumeFlow + fSolidVolume, 1, tGeometrySylobead);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Filter_Sylobead_1, fVolumeFlow, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, 0, fPressure);
            oInput = matter.phases.gas(this.toStores.Filter_Sylobead_1, 'FlowPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter_Sylobead_1, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Sylobead_B125'); 
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In_1');
            matter.procs.exmes.gas(oInput, 'Flow_In_2');
            matter.procs.exmes.gas(oInput, 'Flow_Out_1');
            matter.procs.exmes.gas(oInput, 'Flow_Out_2');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            matter.procs.exmes.gas(oInput, 'filterport2');
            matter.procs.exmes.absorber(oFiltered, 'filterport2');
            components.filter.FilterProc_deso(this.toStores.Filter_Sylobead_1, 'DesorptionProcessor', 'FlowPhase.filterport2', 'FilteredPhase.filterport2');
            components.filter.FilterProc_sorp(this.toStores.Filter_Sylobead_1, 'Filter_Sylobead_1_proc', 'FlowPhase.filterport', 'FilteredPhase.filterport', 'Sylobead');
            
            % Creating the Filter_13X_1 (H2O filter)
            tfMasses = struct('H2O', 0, 'Zeolite13x', fMassZeolite13x);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter_13X_1', fVolumeFlow +fSolidVolume, 1, tGeometry13x);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Filter_13X_1, fVolumeFlow, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, 0, fPressure);
            oInput = matter.phases.gas(this.toStores.Filter_13X_1, 'FlowPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter_13X_1, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Zeolite13x'); 
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In_1');
            matter.procs.exmes.gas(oInput, 'Flow_In_2');
            matter.procs.exmes.gas(oInput, 'Flow_Out_1');
            matter.procs.exmes.gas(oInput, 'Flow_Out_2');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            matter.procs.exmes.gas(oInput, 'filterport2');
            matter.procs.exmes.absorber(oFiltered, 'filterport2');
            components.filter.FilterProc_deso(this.toStores.Filter_13X_1, 'DesorptionProcessor', 'FlowPhase.filterport2', 'FilteredPhase.filterport2');
            components.filter.FilterProc_sorp(this.toStores.Filter_13X_1, 'Filter_13X_1_proc', 'FlowPhase.filterport', 'FilteredPhase.filterport', '13x');
             
            % Creating the Sylobead Filter (H2O filter) Note that this
            % filter and the 13x filter are actually one filter within CDRA
            % but since it is not possible to geometrically model the
            % location of the adsorbents within one store the two had to be
            % seperated
            tfMasses = struct('H2O', 0, 'Sylobead_B125', fMassSylobead);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter_Sylobead_2', fVolumeFlow+fSolidVolume, 1, tGeometrySylobead);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Filter_Sylobead_2, fVolumeFlow, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, 0, fPressure);
            oInput = matter.phases.gas(this.toStores.Filter_Sylobead_2, 'FlowPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter_Sylobead_2, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Sylobead_B125'); 
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In_1');
            matter.procs.exmes.gas(oInput, 'Flow_In_2');
            matter.procs.exmes.gas(oInput, 'Flow_Out_1');
            matter.procs.exmes.gas(oInput, 'Flow_Out_2');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            matter.procs.exmes.gas(oInput, 'filterport2');
            matter.procs.exmes.absorber(oFiltered, 'filterport2');
            components.filter.FilterProc_deso(this.toStores.Filter_Sylobead_2, 'DesorptionProcessor', 'FlowPhase.filterport2', 'FilteredPhase.filterport2');
            components.filter.FilterProc_sorp(this.toStores.Filter_Sylobead_2, 'Filter_Sylobead_2_proc', 'FlowPhase.filterport', 'FilteredPhase.filterport', 'Sylobead');
               
            % Creating the Filter_13X_2 (H2O filter)
            tfMasses = struct('H2O', 0, 'Zeolite13x', fMassZeolite13x);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter_13X_2', fVolumeFlow+fSolidVolume, 1, tGeometry13x);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Filter_13X_2, fVolumeFlow, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, 0, fPressure);
            oInput = matter.phases.gas(this.toStores.Filter_13X_2, 'FlowPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter_13X_2, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Zeolite13x');
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In_1');
            matter.procs.exmes.gas(oInput, 'Flow_In_2');
            matter.procs.exmes.gas(oInput, 'Flow_Out_1');
            matter.procs.exmes.gas(oInput, 'Flow_Out_2');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            matter.procs.exmes.gas(oInput, 'filterport2');
            matter.procs.exmes.absorber(oFiltered, 'filterport2');
            components.filter.FilterProc_deso(this.toStores.Filter_13X_2, 'DesorptionProcessor', 'FlowPhase.filterport2', 'FilteredPhase.filterport2');
            components.filter.FilterProc_sorp(this.toStores.Filter_13X_2, 'Filter_13X_2_proc', 'FlowPhase.filterport', 'FilteredPhase.filterport', '13x');
                
            % Creating the Filter5A_1 (CO2 filter)
            tfMasses = struct('CO2', 0, 'Zeolite5A', fMassZeolite5A);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter5A_1', fVolumeFlow+fSolidVolume, 1, tGeometry5A);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Filter5A_1, fVolumeFlow, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, 0, fPressure);
            oInput = matter.phases.gas(this.toStores.Filter5A_1, 'FlowPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter5A_1, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Zeolite5A');
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In');
            matter.procs.exmes.gas(oInput, 'Vent');
            matter.procs.exmes.gas(oInput, 'Flow_Out_2');
            matter.procs.exmes.gas(oInput, 'AirSafe');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            matter.procs.exmes.gas(oInput, 'filterport2');
            matter.procs.exmes.absorber(oFiltered, 'filterport2');
            components.filter.FilterProc_deso(this.toStores.Filter5A_1, 'DesorptionProcessor', 'FlowPhase.filterport2', 'FilteredPhase.filterport2');
            components.filter.FilterProc_sorp(this.toStores.Filter5A_1, 'Filter_5A_1_proc', 'FlowPhase.filterport', 'FilteredPhase.filterport', '5A-RK38');
            
            this.toCDRA_Heaters.Filter5A_1 = components.CDRA.components.CDRA_Heater(this.toStores.Filter5A_1, 'Filter5A_1_Heater');
            
            % Creating the Filter5A_2 (CO2 filter)
            tfMasses = struct('CO2', 0, 'Zeolite5A', fMassZeolite5A );
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, this.tAtmosphere.fTemperature, true);
            
            matter.store(this, 'Filter5A_2', fVolumeFlow+fSolidVolume, 1, tGeometry5A);
            % Input phase
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Filter5A_2, fVolumeFlow, struct('CO2', fCO2Percent), this.tAtmosphere.fTemperature, 0, fPressure);
            oInput = matter.phases.gas(this.toStores.Filter5A_2, 'FlowPhase', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            % Filtered phase
            oFiltered = matter.phases.absorber(this.toStores.Filter5A_2, 'FilteredPhase', tfMasses, this.tAtmosphere.fTemperature, 'solid', 'Zeolite5A');
            
            % Creating the ports
            matter.procs.exmes.gas(oInput, 'Flow_In');
            matter.procs.exmes.gas(oInput, 'Flow_Out_1');
            matter.procs.exmes.gas(oInput, 'Vent');
            matter.procs.exmes.gas(oInput, 'AirSafe');
            matter.procs.exmes.gas(oInput, 'filterport');
            matter.procs.exmes.absorber(oFiltered, 'filterport');
            matter.procs.exmes.gas(oInput, 'filterport2');
            matter.procs.exmes.absorber(oFiltered, 'filterport2');
            components.filter.FilterProc_deso(this.toStores.Filter5A_2, 'DesorptionProcessor', 'FlowPhase.filterport2', 'FilteredPhase.filterport2');
            components.filter.FilterProc_sorp(this.toStores.Filter5A_2, 'Filter_5A_2_proc', 'FlowPhase.filterport', 'FilteredPhase.filterport', '5A-RK38');
            
            this.toCDRA_Heaters.Filter5A_2 = components.CDRA.components.CDRA_Heater(this.toStores.Filter5A_2, 'Filter5A_2_Heater');
            
            % binding update function to of p2p procs to call update
            % function for CDRA as well
            this.toStores.Filter_Sylobead_1.toProcsP2P.Filter_Sylobead_1_proc.bind('update', @(~) this.update());
            this.toStores.Filter_Sylobead_2.toProcsP2P.Filter_Sylobead_2_proc.bind('update', @(~) this.update());
            
            this.toStores.Filter_13X_1.toProcsP2P.Filter_13X_1_proc.bind('update', @(~) this.update());
            this.toStores.Filter_13X_2.toProcsP2P.Filter_13X_2_proc.bind('update', @(~) this.update());
            
            this.toStores.Filter5A_1.toProcsP2P.Filter_5A_1_proc.bind('update', @(~) this.update());
            this.toStores.Filter5A_2.toProcsP2P.Filter_5A_2_proc.bind('update', @(~) this.update());
            
            
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
            components.pipe(this, 'Pipe_7', 1, 0.1);
            components.pipe(this, 'Pipe_8', 1, 0.1);
            components.pipe(this, 'Pipe_1_2', 1, 0.1);
            components.pipe(this, 'Pipe_2_2', 1, 0.1);
            components.pipe(this, 'Pipe_3_2', 1, 0.1);
            components.pipe(this, 'Pipe_4_2', 1, 0.1);
            components.pipe(this, 'Pipe_5_2', 1, 0.1);
            components.pipe(this, 'Pipe_6_2', 1, 0.1);
            components.pipe(this, 'Pipe_7_2', 1, 0.1);
            components.pipe(this, 'Pipe_8_2', 1, 0.1);
            
            %% Creating the flowpath into, between and out of this subsystem
            % Branch for flowpath into/out of a subsystem: ('store.exme', {'f2f-processor', 'f2f-processor'}, 'system level port name')
            
            % Cycle one
            matter.branch(this, 'Filter_Sylobead_1.Flow_In_1', {'Pipe_1'}, 'CDRA_Air_In_1', 'CDRA_In_1');           % Creating the flowpath into this subsystem
            
            matter.branch(this, 'Filter_Sylobead_1.Flow_Out_1', {'Pipe_2'}, 'Filter_13X_1.Flow_In_1', 'Sylobead1_Z13x1');           % Creating the flowpath into this subsystem
            
            matter.branch(this, 'Filter_13X_1.Flow_Out_1', {'Pipe_3', 'Precooler_1'}, 'Filter5A_2.Flow_In', 'Filter13x1_to_Filter5A2');
            
            matter.branch(this, 'Filter5A_2.Flow_Out_1', {'Pipe_4'}, 'Filter_13X_2.Flow_In_1', 'Filter5A2_to_Filter13x2');
            
            matter.branch(this, 'Filter_13X_2.Flow_Out_1', {'Pipe_5'}, 'Filter_Sylobead_2.Flow_In_1', 'Z13x2_Sylobead2');   
            
            matter.branch(this, 'Filter_Sylobead_2.Flow_Out_1', {'Pipe_6'}, 'CDRA_Air_Out_1', 'CDRA_to_CHX_1');     % Air to CDRA1 to CCAA2 connection tank
            
            matter.branch(this, 'Filter5A_1.Vent', {'Pipe_7'}, 'CDRA_Vent_1', 'Filter5A1_to_Vent');                      % CO2 to vacuum

            % Cycle two
            matter.branch(this, 'Filter_Sylobead_2.Flow_In_2', {'Pipe_1_2'}, 'CDRA_Air_In_2', 'CDRA_In_2');           % Creating the flowpath into this subsystem
            
            matter.branch(this, 'Filter_Sylobead_2.Flow_Out_2', {'Pipe_2_2'}, 'Filter_13X_2.Flow_In_2', 'Sylobead2_Z13x2');           % Creating the flowpath into this subsystem
            
            matter.branch(this, 'Filter_13X_2.Flow_Out_2', {'Pipe_3_2', 'Precooler_2'}, 'Filter5A_1.Flow_In', 'Filter13x2_to_Filter5A1');
            
            matter.branch(this, 'Filter5A_1.Flow_Out_2', {'Pipe_4_2'}, 'Filter_13X_1.Flow_In_2', 'Filter5A1_to_Filter13x1');
            
            matter.branch(this, 'Filter_13X_1.Flow_Out_2', {'Pipe_5_2'}, 'Filter_Sylobead_1.Flow_In_2', 'Z13x1_Sylobead1');   
            
            matter.branch(this, 'Filter_Sylobead_1.Flow_Out_2', {'Pipe_6_2'}, 'CDRA_Air_Out_2', 'CDRA_to_CHX_2');     % Air to CDRA1 to CCAA2 connection tank
            
            matter.branch(this, 'Filter5A_2.Vent', {'Pipe_7_2'}, 'CDRA_Vent_2', 'Filter5A2_to_Vent');                  % CO2 to vacuum

            %Branches for the Airsafe functionality that pumps out the air
            %from the absorber bed before it is connected to the vacuum.
            matter.branch(this, 'Filter5A_1.AirSafe', {'Pipe_8'}, 'CDRA_AirSafe_1', 'Filter5A1_AirSafe');
            matter.branch(this, 'Filter5A_2.AirSafe', {'Pipe_8_2'}, 'CDRA_AirSafe_2', 'Filter5A2_AirSafe');
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Cycle one
            for k = 1:length(this.aoBranches)
                solver.matter.manual.branch(this.aoBranches(k));
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
            fFlowRateSylobead_1 = this.toStores.Filter_Sylobead_1.toProcsP2P.Filter_Sylobead_1_proc.fFlowRate + this.toStores.Filter_Sylobead_1.toProcsP2P.DesorptionProcessor.fFlowRate;
            fFlowRateSylobead_2 = this.toStores.Filter_Sylobead_2.toProcsP2P.Filter_Sylobead_2_proc.fFlowRate + this.toStores.Filter_Sylobead_2.toProcsP2P.DesorptionProcessor.fFlowRate;
            
            fFlowRate13X_1 = this.toStores.Filter_13X_1.toProcsP2P.Filter_13X_1_proc.fFlowRate  + this.toStores.Filter_13X_1.toProcsP2P.DesorptionProcessor.fFlowRate;
            fFlowRate13X_2 = this.toStores.Filter_13X_2.toProcsP2P.Filter_13X_2_proc.fFlowRate  + this.toStores.Filter_13X_2.toProcsP2P.DesorptionProcessor.fFlowRate;
            
            fFlowRate5A_1 = this.toStores.Filter5A_1.toProcsP2P.Filter_5A_1_proc.fFlowRate  + this.toStores.Filter5A_1.toProcsP2P.DesorptionProcessor.fFlowRate;
            fFlowRate5A_2 = this.toStores.Filter5A_2.toProcsP2P.Filter_5A_2_proc.fFlowRate  + this.toStores.Filter5A_2.toProcsP2P.DesorptionProcessor.fFlowRate;
            
            this.fFlowrateMain  = this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.CHX_CDRA.oHandler.fRequestedFlowRate;
            
            % Control mechanism and setting of fixed flow rates
            % Cycle one
            if mod(this.oTimer.fTime, this.fCycleTime * 2) < (this.fCycleTime)
                if this.iCycleActive == 2
                    
                    this.iCycleActive = 1;
                    
                    % Set cycle one f2f-procs aktive
                    this.toProcsF2F.Precooler_1.setActive(true, this.oTimer.fTime)
                    
                    % Set cycle two f2f-procs inaktive to increase simulation speed
                    this.toProcsF2F.Precooler_2.setActive(false)
                    
                    % Setting cycle two flow rates zero
                    this.toBranches.CDRA_In_2.oHandler.setFlowRate(0);
                    this.toBranches.Sylobead2_Z13x2.oHandler.setFlowRate(0);
                    this.toBranches.Filter13x2_to_Filter5A1.oHandler.setFlowRate(0);
                    this.toBranches.Filter5A1_to_Filter13x1.oHandler.setFlowRate(0);
                    this.toBranches.Z13x1_Sylobead1.oHandler.setFlowRate(0);
                    this.toBranches.CDRA_to_CHX_2.oHandler.setFlowRate(0);
                    this.toBranches.Filter5A2_to_Vent.oHandler.setFlowRate(0);
                    
                    this.fInitialFilterMass = this.toStores.Filter5A_1.toPhases.FlowPhase.fMass;
                end
               
                % Setting cycle one flow rates
                this.toBranches.CDRA_In_1.oHandler.setFlowRate(-this.fFlowrateMain);
                
                this.toBranches.Sylobead1_Z13x1.oHandler.setFlowRate(this.fFlowrateMain - fFlowRateSylobead_1);
                
                this.toBranches.Filter13x1_to_Filter5A2.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate13X_1 - fFlowRateSylobead_1);
                
                %Since the beds go through a pressure swing where they go
                %from normal pressure to vacuum it is required to refill
                %them first after they enter the adsorption mode.
                if this.toStores.Filter5A_2.toPhases.FlowPhase.fPressure < 1e5
                    %Actually the inlet flowrates should probably be
                    %changed for the initial refill but no data was
                    %available so here it is assumed that just nothing
                    %flows out until the bed reaches 1 bar pressure
                    this.toBranches.Filter5A2_to_Filter13x2.oHandler.setFlowRate(0);
                    this.toBranches.Z13x2_Sylobead2.oHandler.setFlowRate(0);
                    this.toBranches.CDRA_to_CHX_1.oHandler.setFlowRate(0);
                else
                    this.toBranches.Filter5A2_to_Filter13x2.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate5A_2 - fFlowRate13X_1 - fFlowRateSylobead_1);
                    this.toBranches.Z13x2_Sylobead2.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate13X_2 - fFlowRate5A_2 - fFlowRate13X_1 - fFlowRateSylobead_1);
                    this.toBranches.CDRA_to_CHX_1.oHandler.setFlowRate(this.fFlowrateMain - fFlowRateSylobead_2 - fFlowRate13X_2 - fFlowRate5A_2 - fFlowRate13X_1 - fFlowRateSylobead_1);
                end
                %Desorbing Filter:
                %The CO2 filter that is not used in the active cycle is
                %connected to the vacuum so that it can desorb CO2, but
                %only after the air from the filter has been pumped out
                %back into the cabin (10 minute air safe phase)
                if mod(this.oTimer.fTime, this.fCycleTime * 2) < (this.fAirSafeTime)
                    %assuming that the air safe pump can achieve a pressure
                    %of 5 Pa
                    if this.toStores.Filter5A_1.toPhases.FlowPhase.fPressure > 5000
                        %This whole process should be modelled better but
                        %no data on the flow rates could be found. So here
                        %the flow rate was simply set to ensure that the
                        %phase actually reaches the minimum pressure of 5
                        %Pa during the air safe time
                        if fFlowRate5A_1 < 0
                            this.toBranches.Filter5A1_AirSafe.oHandler.setFlowRate((this.fInitialFilterMass/(this.fAirSafeTime))-fFlowRate5A_1);
                        else
                            this.toBranches.Filter5A1_AirSafe.oHandler.setFlowRate((this.fInitialFilterMass/(this.fAirSafeTime)));
                        end
                    else
                        this.toBranches.Filter5A1_AirSafe.oHandler.setFlowRate(-fFlowRate5A_1);
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
                    
                    this.iCycleActive = 2;
                    
                    % Set cycle one f2f-procs inaktive to increase simulation speed
                    this.toProcsF2F.Precooler_1.setActive(false)
                    
                    % Set cycle two f2f-procs aktive
                    this.toProcsF2F.Precooler_2.setActive(true, this.oTimer.fTime)
                    
                    % Setting cycle one flow rates zero
                    this.toBranches.CDRA_In_1.oHandler.setFlowRate(0);
                    this.toBranches.Sylobead1_Z13x1.oHandler.setFlowRate(0);
                    this.toBranches.Filter13x1_to_Filter5A2.oHandler.setFlowRate(0);
                    this.toBranches.Filter5A2_to_Filter13x2.oHandler.setFlowRate(0);
                    this.toBranches.Z13x2_Sylobead2.oHandler.setFlowRate(0);
                    this.toBranches.CDRA_to_CHX_1.oHandler.setFlowRate(0);
                    this.toBranches.Filter5A1_to_Vent.oHandler.setFlowRate(0);
                    
                    this.fInitialFilterMass = this.toStores.Filter5A_2.toPhases.FlowPhase.fMass;
                end
               
                % Setting cycle one flow rates
                this.toBranches.CDRA_In_2.oHandler.setFlowRate(-this.fFlowrateMain);
                
                this.toBranches.Sylobead2_Z13x2.oHandler.setFlowRate(this.fFlowrateMain - fFlowRateSylobead_2);
                
                this.toBranches.Filter13x2_to_Filter5A1.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate13X_2 - fFlowRateSylobead_2);
                
                %Since the beds go through a pressure swing where they go
                %from normal pressure to vacuum it is required to refill
                %them first after they enter the adsorption mode.
                if this.toStores.Filter5A_1.toPhases.FlowPhase.fPressure < 1e5
                    %Actually the inlet flowrates should probably be
                    %changed for the initial refill but no data was
                    %available so here it is assumed that just nothing
                    %flows out until the bed reaches 1 bar pressure
                    this.toBranches.Filter5A1_to_Filter13x1.oHandler.setFlowRate(0);
                    this.toBranches.Z13x1_Sylobead1.oHandler.setFlowRate(0);
                    this.toBranches.CDRA_to_CHX_2.oHandler.setFlowRate(0);
                else
                    this.toBranches.Filter5A1_to_Filter13x1.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate5A_1 - fFlowRate13X_2 - fFlowRateSylobead_2);
                    this.toBranches.Z13x1_Sylobead1.oHandler.setFlowRate(this.fFlowrateMain - fFlowRate13X_1 - fFlowRate5A_1 - fFlowRate13X_2 - fFlowRateSylobead_2);
                    this.toBranches.CDRA_to_CHX_2.oHandler.setFlowRate(this.fFlowrateMain - fFlowRateSylobead_1 - fFlowRate13X_1 - fFlowRate5A_1 - fFlowRate13X_2 - fFlowRateSylobead_2);
                end
                %Desorbing Filter:
                %The CO2 filter that is not used in the active cycle is
                %connected to the vacuum so that it can desorb CO2, but
                %only after the air from the filter has been pumped out
                %back into the cabin (10 minute air safe phase)
                if mod(this.oTimer.fTime, this.fCycleTime * 2) < (this.fCycleTime + this.fAirSafeTime)
                    %assuming that the air safe pump can achieve a pressure
                    %of 5 Pa
                    if this.toStores.Filter5A_2.toPhases.FlowPhase.fPressure > 5000
                        %This whole process should be modelled better but
                        %no data on the flow rates could be found. So here
                        %the flow rate was simply set to ensure that the
                        %phase actually reaches the minimum pressure of 5
                        %Pa during the air safe time
                        if fFlowRate5A_2 < 0
                            this.toBranches.Filter5A2_AirSafe.oHandler.setFlowRate((this.fInitialFilterMass/(this.fAirSafeTime))-fFlowRate5A_2);
                        else
                            this.toBranches.Filter5A2_AirSafe.oHandler.setFlowRate((this.fInitialFilterMass/(this.fAirSafeTime)));
                        end
                    else
                        this.toBranches.Filter5A2_AirSafe.oHandler.setFlowRate(-fFlowRate5A_2);
                    end
                else
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
                    this.toCDRA_Heaters.Filter5A_1.setHeaterPower(0);
                elseif this.toStores.Filter5A_1.toPhases.FilteredPhase.fTemperature < (this.TargetTemperature * 0.99)
                    this.toCDRA_Heaters.Filter5A_1.setHeaterPower(this.fMaxHeaterPower);
                end
            else
                this.toCDRA_Heaters.Filter5A_1.setHeaterPower(0);
            end
            
            if mod(this.oTimer.fTime, this.fCycleTime * 2) > this.fCycleTime
                if this.toStores.Filter5A_2.toPhases.FilteredPhase.fTemperature > this.TargetTemperature
                    this.toCDRA_Heaters.Filter5A_2.setHeaterPower(0);
                elseif this.toStores.Filter5A_2.toPhases.FilteredPhase.fTemperature  < (this.TargetTemperature * 0.99)
                    this.toCDRA_Heaters.Filter5A_2.setHeaterPower(this.fMaxHeaterPower);
                end
            else
                this.toCDRA_Heaters.Filter5A_2.setHeaterPower(0);
            end
            % updates the filter procs
            this.toCDRA_Heaters.Filter5A_1.update();
            this.toCDRA_Heaters.Filter5A_2.update();
            
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            this.update();
        end
        
	end
end