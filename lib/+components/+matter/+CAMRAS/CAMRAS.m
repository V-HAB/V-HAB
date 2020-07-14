classdef CAMRAS < vsys
    
    %% Development of a CAMRAS Model for CO2 reduction that will be used on the ORION Spacecraft
    
    
    properties
        
        %Number of active cycle (can be 1 or 2, so either cycle 1 is active
        %or cycle 2)
        iCycleActive = 2;
        
        % Between each cycle a pressure compensation between the two
        % filters is performed in order to minimize air losses.
        % fPressureCompensationTime is the time period after which the
        % equalization is done!
        fPressureCompensationTime; %[s]
        
        % Time during whicht the vacuum in the desorbing bed is created.
        % Only after this time the desorbing process takes place
        fVacuumTime; % [s]
        
        % Mass Flow Rate into the Filter. 
        fFlowrateMain;                  % [kg/s]
        
        % Volumetric Flowrate into the Filter. Multiplied with the current
        % density this is the fFlowrateMain that is set for the manual
        % solver
        fVolumetricFlowrateMain;
        
%         %Mass of filtered CO2 at the beginning of the desorption process.
%         %This is required to set the correct flowrates for the manual
%         %branches.
%         fInitialFilterMass;             % [kg]
        
        
        % In the control logic, the mass that needs to be pushed into the
        % vacuum in order to create a vacuum in the phase itself is
        % calculated
        fMassToVacuum;
        
        % In the control logic, the mass that needs to be pushed from one
        % filter into the other in order to create a vacuum is calculated
        fMassToEqualize;
        
        %Total time a cycle is active before switching to the other one.
        %This is also called half cycle sometimes with a full cycle beeing
        %considered the time it takes for both cycles to finish once.
        fCycleTime;                     % [s]
        
        % Atmosphere of the filter phases
        tCAMRASFilterAtmosphere;
        
        % Atmosphere of the Habitat
        oAtmosphere;
        
        % Timestep during nominal phase
        fInitialTimeStep;
        
        % In order to calculate a mass at a certain point in time and not
        % recalculate it afterwoods in the same cycleperiod again a counter
        % variable is used
        iCounter;
        
        % Crew state that can be set by the user: Available: Nominal,
        % Exercise, Sleep 
        sCase;
        
        % Internal Cycle time. Is set to zero at the beginning of each full
        % cycle (at beginning of cycle one)
        fInternalTime = 0;
        
        % Gets true if the case should be changed into another state
        bUpdateCase;
        
        % Time when the last full cycle switch took place
        fTimeCycleChange = 0;
        
        % Variable needed to calculate the right Massflow 
        fTime;
        
        % Variable indicating wheter the system is on 
        iOn = 0;
        
        % Variable indicating wheter the system is off 
        iOff = 0;
        
        % Variable needed in order to ensure that the subsystem is only
        % shut off if both filter phases are desorbed and therefore empty
        iCounterOff =0;
    end
    
    methods
        function this = CAMRAS(oParent, sName, fTimeStep, fVolumetricFlowrateMain, sCase)
            this@vsys(oParent, sName, fTimeStep);
            
            this.fInitialTimeStep = fTimeStep;
            this.fCycleTime =  6.5 * 60;        % [s] exercise case is the default case
            this.fVacuumTime = 20;              % [s] By try and error what works the best
            this.fPressureCompensationTime = 2; % [s] personal communication with Dr. Jeff Sweterlitch            
            this.fVolumetricFlowrateMain = fVolumetricFlowrateMain; 
            this.sCase = sCase;
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            % Initial CAMRAS Filter Atmosphere Values
            this.tCAMRASFilterAtmosphere.fTemperature = 293.15; % Bed Temperature of absorbing bed ~ 20°C (CAMRAS 4A Test Data)
            this.tCAMRASFilterAtmosphere.fRelHumidity = 0.4;
            this.tCAMRASFilterAtmosphere.fPressure = 101325;
            this.tCAMRASFilterAtmosphere.fCO2Percent = 0.0038;

            
            %% Filter A
            
            % Creating the Filter_H2O_A (H2O filter)
            % According to personal communication with Jeff Sweterlitch the total mass of SA9T for both beds are 3.5 kg --> one bed has 1,75 kg
            fAdsorbentMassCAMRAS = 1.75;
            
            arMass = zeros(1, this.oMT.iSubstances);
            arMass(this.oMT.tiN2I.Zeolite5A) = 1;
            fDensity5A = this.oMT.calculateDensity('solid', arMass, this.tCAMRASFilterAtmosphere.fTemperature, ones(1, this.oMT.iSubstances) .* this.tCAMRASFilterAtmosphere.fPressure);
            
            fSolidVolume = fAdsorbentMassCAMRAS / fDensity5A;
            
            fGasVolume = 0.006399; % Calculated from ISS Test Air Loss over 1000h of operations
            
            matter.store(this, 'Filter_A', fGasVolume+fSolidVolume);
            % Input phase
            oInput    	= this.toStores.Filter_A.createPhase(       'gas',	'PhaseIn',  fGasVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),          this.tCAMRASFilterAtmosphere.fTemperature,          this.tCAMRASFilterAtmosphere.fRelHumidity);
            
            % Both the H2O Phase and the CO2 phase get the same amount of
            % adsorbent
            oFilteredH2O = this.toStores.Filter_A.createPhase(	'mixture',	'FilteredPhaseH2O', 'solid',        fSolidVolume/2,      struct('Zeolite5A', 1),       this.tCAMRASFilterAtmosphere.fTemperature, this.tCAMRASFilterAtmosphere.fPressure);
            oFilteredCO2 = this.toStores.Filter_A.createPhase(	'mixture',	'FilteredPhaseCO2', 'solid',        fSolidVolume/2,      struct('Zeolite5A', 1),       this.tCAMRASFilterAtmosphere.fTemperature, this.tCAMRASFilterAtmosphere.fPressure);
            
            % Creating the ports && setting CAMRAS Filter Temperature
            % constant
            matter.procs.exmes.gas(oInput, 'Flow_In');
            matter.procs.exmes.gas(oInput, 'Flow_Out');
            matter.procs.exmes.gas(oInput, 'AdsorbedH2O');
            matter.procs.exmes.gas(oInput, 'AdsorbedCO2');
            matter.procs.exmes.gas(oInput, 'PressureCompensationPortA');
            matter.procs.exmes.gas(oInput, 'Flow_Out_Vacuum');
            matter.procs.exmes.gas(oInput, 'Flow_Out_Desorb');
            matter.procs.exmes.mixture(oFilteredH2O, 'filterportH2O');
            matter.procs.exmes.mixture(oFilteredCO2, 'filterportCO2');
            
            
            % Create the Filterproc
            components.matter.CAMRAS.components.Filter(this.toStores.Filter_A, 'FilterAH2O', 'PhaseIn.AdsorbedH2O', 'FilteredPhaseH2O.filterportH2O', 'H2O', this.fCycleTime, this.fVacuumTime,this.fPressureCompensationTime, this.sCase);
            components.matter.CAMRAS.components.Filter(this.toStores.Filter_A, 'FilterACO2', 'PhaseIn.AdsorbedCO2', 'FilteredPhaseCO2.filterportCO2', 'CO2', this.fCycleTime, this.fVacuumTime,this.fPressureCompensationTime, this.sCase);
            
            
            %% Filter B
            
            matter.store(this, 'Filter_B', fGasVolume+fSolidVolume);
            
            oInput    	= this.toStores.Filter_B.createPhase(       'gas',	'PhaseIn',  fGasVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),          this.tCAMRASFilterAtmosphere.fTemperature,          this.tCAMRASFilterAtmosphere.fRelHumidity);
            
            % Both the H2O Phase and the CO2 phase get the same amount of
            % adsorbent
            oFilteredH2O = this.toStores.Filter_B.createPhase(	'mixture',	'FilteredPhaseH2O', 'solid',        fSolidVolume/2,      struct('Zeolite5A', 1),       this.tCAMRASFilterAtmosphere.fTemperature, this.tCAMRASFilterAtmosphere.fPressure);
            oFilteredCO2 = this.toStores.Filter_B.createPhase(	'mixture',	'FilteredPhaseCO2', 'solid',        fSolidVolume/2,      struct('Zeolite5A', 1),       this.tCAMRASFilterAtmosphere.fTemperature, this.tCAMRASFilterAtmosphere.fPressure);
            
            % Creating the ports && setting CAMRAS Filter Temperature
            % constant
            matter.procs.exmes.gas(oInput, 'Flow_In');
            matter.procs.exmes.gas(oInput, 'Flow_Out');
            matter.procs.exmes.gas(oInput, 'AdsorbedH2O');
            matter.procs.exmes.gas(oInput, 'AdsorbedCO2');
            matter.procs.exmes.gas(oInput, 'PressureCompensationPortB');
            matter.procs.exmes.gas(oInput, 'Flow_Out_Vacuum');
            matter.procs.exmes.gas(oInput, 'Flow_Out_Desorb');
            matter.procs.exmes.mixture(oFilteredH2O, 'filterportH2O');
            matter.procs.exmes.mixture(oFilteredCO2, 'filterportCO2');
            
            
            % Create the Filterproc
            components.matter.CAMRAS.components.Filter(this.toStores.Filter_B, 'FilterBH2O', 'PhaseIn.AdsorbedH2O', 'FilteredPhaseH2O.filterportH2O', 'H2O', this.fCycleTime, this.fVacuumTime,this.fPressureCompensationTime, this.sCase);
            components.matter.CAMRAS.components.Filter(this.toStores.Filter_B, 'FilterBCO2', 'PhaseIn.AdsorbedCO2', 'FilteredPhaseCO2.filterportCO2', 'CO2', this.fCycleTime, this.fVacuumTime,this.fPressureCompensationTime,this.sCase);
            
            
            
            %% Creating the flowpath into, between and out of this subsystem
            % Branch for flowpath into/out of a subsystem: ('store.exme', {'f2f-processor', 'f2f-processor'}, 'system level port name')
            
            % Cycle one
            matter.branch(this, 'Filter_A.Flow_In',          {},                   'CAMRAS_Air_In_C1',           'CAMRAS_Air_In_C1');
            matter.branch(this, 'Filter_B.Flow_Out_Desorb',  {},                   'CAMRAS_to_Vaccum_B_Desorb',  'Filter_B_Desorb');
            matter.branch(this, 'Filter_B.Flow_Out_Vacuum',  {},                   'CAMRAS_to_Vaccum_B',         'Filter_B_Vacuum');
            matter.branch(this, 'Filter_A.Flow_Out',         {},                   'CAMRAS_Air_Out_C1',          'CAMRAS_Air_Out_C1');
            
            
            % Cycle two
            matter.branch(this, 'Filter_B.Flow_In',          {},                  'CAMRAS_Air_In_C2',           'CAMRAS_Air_In_C2');
            matter.branch(this, 'Filter_A.Flow_Out_Desorb',  {},                  'CAMRAS_to_Vaccum_A_Desorb',  'Filter_A_Desorb');
            matter.branch(this, 'Filter_A.Flow_Out_Vacuum',  {},                  'CAMRAS_to_Vaccum_A',         'Filter_A_Vacuum');
            matter.branch(this, 'Filter_B.Flow_Out',         {},                  'CAMRAS_Air_Out_C2',          'CAMRAS_Air_Out_C2');
            
            %Pressure compensation
            matter.branch(this, 'Filter_A.PressureCompensationPortA',  {},  'Filter_B.PressureCompensationPortB', 'PressureCompensation');
            
            
        end
        
        function createThermalStructure(this)
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            oHeatSource = components.thermal.heatsources.ConstantTemperature('FilterA_ConstantTemperature');
            this.toStores.Filter_A.toPhases.PhaseIn.oCapacity.addHeatSource(oHeatSource);
            oHeatSource = components.thermal.heatsources.ConstantTemperature('FilterB_ConstantTemperature');
            this.toStores.Filter_B.toPhases.PhaseIn.oCapacity.addHeatSource(oHeatSource);
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Cycle one
            solver.matter.manual.branch(this.toBranches.CAMRAS_Air_In_C1);
            solver.matter.manual.branch(this.toBranches.Filter_B_Vacuum);
            solver.matter.residual.branch(this.toBranches.Filter_B_Desorb);
            solver.matter.residual.branch(this.toBranches.CAMRAS_Air_Out_C1);
            
            
            %Cycle 2
            solver.matter.manual.branch(this.toBranches.CAMRAS_Air_In_C2);
            solver.matter.manual.branch(this.toBranches.Filter_A_Vacuum);
            solver.matter.residual.branch(this.toBranches.Filter_A_Desorb);
            solver.matter.residual.branch(this.toBranches.CAMRAS_Air_Out_C2);
            
            % Pressure Swing
            solver.matter.manual.branch(this.toBranches.PressureCompensation);
            
            this.setThermalSolvers();
        end
        
        %% Function to connect the system and subsystem level branches with each other
        function setIfFlows(this, sInterface1, sInterface2, sInterface3, sInterface4, sInterface5, sInterface6, sInterface7, sInterface8)
            if nargin == 9
                this.connectIF('CAMRAS_Air_In_C1'  , sInterface1);
                this.connectIF('CAMRAS_Air_Out_C1' , sInterface2);
                this.connectIF('CAMRAS_Air_In_C2'  , sInterface3);
                this.connectIF('CAMRAS_Air_Out_C2' , sInterface4);
                this.connectIF('CAMRAS_to_Vaccum_A', sInterface5);
                this.connectIF('CAMRAS_to_Vaccum_B', sInterface6);
                this.connectIF('CAMRAS_to_Vaccum_A_Desorb', sInterface7);
                this.connectIF('CAMRAS_to_Vaccum_B_Desorb', sInterface8);
            else
                error('CAMRAS Subsystem was given a wrong number of interfaces')
            end
        end
        
        function setReferencePhase(this, oPhase)
            this.oAtmosphere = oPhase;
            
        end
        
        function setCase(this, sCase)
            this.sCase = sCase;
            this.bUpdateCase = 'true';
            
            
        end
        
        function setOff(this)
            this.iOff = 1;
            this.iOn = 0;
            this.iCounterOff = 0;
            
            
        end
        
        function setOn(this)
            this.iOn  = 1;
            this.iOff = 0;
            this.toStores.Filter_A.toProcsP2P.FilterAH2O.setOn();
            this.toStores.Filter_A.toProcsP2P.FilterACO2.setOn();
            this.toStores.Filter_B.toProcsP2P.FilterBH2O.setOn();
            this.toStores.Filter_B.toProcsP2P.FilterBCO2.setOn();
            this.iCycleActive = 2;
            this.fTimeCycleChange = this.oTimer.fTime;
        end
        
        
        
        function update(this)
            
            
            % Calculate internal CAMRAS Time (is set to zero at the
            % beginning of Cycle 1
            
            this.fInternalTime = this.oTimer.fTime - this.fTimeCycleChange;
            
            if this.fFlowrateMain == 0
                
                if this.iOn ~= 1
                    
                    % Cycle 1
                    this.toBranches.CAMRAS_Air_In_C1.oHandler.setFlowRate(0);
                    this.toBranches.Filter_B_Vacuum.oHandler.setFlowRate(0);
                    this.toBranches.Filter_B_Desorb.oHandler.setActive(false);
                    this.toBranches.CAMRAS_Air_Out_C1.oHandler.setActive(false);
                    
                    % Cycle 2
                    this.toBranches.CAMRAS_Air_In_C2.oHandler.setFlowRate(0);
                    this.toBranches.Filter_A_Vacuum.oHandler.setFlowRate(0);
                    this.toBranches.Filter_A_Desorb.oHandler.setActive(false);
                    this.toBranches.CAMRAS_Air_Out_C2.oHandler.setActive(false);
                    
                    % Pressure Compensation
                    this.toBranches.PressureCompensation.oHandler.setFlowRate(0);
                    return
                end
            end
            
            %% Cycle one
            if mod(this.fInternalTime, this.fCycleTime * 2) < this.fCycleTime
                if this.iCycleActive == 2
                    
                    % This section is only entered at the beginning of
                    % cycle one and therefore everything that needs to be
                    % done at this point in time is done here!
                    
                    
                    % Takes care of the shutting off process. Both phases
                    % will be getting desorbed first before real shutting
                    % off process takes place
                    if this.iOff == 1
                        this.toStores.Filter_A.toProcsP2P.FilterAH2O.setOff();
                        this.toStores.Filter_A.toProcsP2P.FilterACO2.setOff();
                        this.toStores.Filter_B.toProcsP2P.FilterBH2O.setOff();
                        this.toStores.Filter_B.toProcsP2P.FilterBCO2.setOff();
                        
                        if this.iOn ~=1
                            if this.iCounterOff == 0
                                this.iCounterOff = 1;
                            elseif this.iCounterOff == 2
                                this.iCounterOff = 3;
                            elseif this.iCounterOff == 4
                                this.fFlowrateMain = 0;
                                this.iCounterOff = 0;
                                return
                            end
                        end
                    end
                    
                    
                    % Set cycle one filter modes
                    this.toStores.Filter_A.toProcsP2P.FilterAH2O.setFilterMode('absorb');
                    this.toStores.Filter_A.toProcsP2P.FilterACO2.setFilterMode('absorb');
                    this.toStores.Filter_B.toProcsP2P.FilterBH2O.setFilterMode('desorb');
                    this.toStores.Filter_B.toProcsP2P.FilterBCO2.setFilterMode('desorb');
                    this.iCycleActive = 1;
                    
                    % Setting cycle two flow rates zero
                    this.toBranches.CAMRAS_Air_In_C2.oHandler.setFlowRate(0);
                    this.toBranches.Filter_A_Vacuum.oHandler.setFlowRate(0);
                    this.toBranches.Filter_A_Desorb.oHandler.setActive(false);
                    this.toBranches.CAMRAS_Air_Out_C2.oHandler.setActive(false);
                    
                    % Calculate Mass that needs to be moved to equalize the
                    % pressure between Bed A and Bed B
                    fMassFilterAEqualize = this.toStores.Filter_A.aoPhases(1,1).fMass;
                    fMassFilterBEqualize = this.toStores.Filter_B.aoPhases(1,1).fMass;
                    this.fMassToEqualize = 0.5 * (fMassFilterBEqualize-fMassFilterAEqualize);
                    
                    this.iCounter = 0;
                    this.fTimeCycleChange = this.oTimer.fTime;
                    
                    
                    % Meachanism to change cycle times and flow rates based
                    % on crew state. 
                    if strcmp(this.bUpdateCase, 'true') || this.iOn == 1
                        if strcmp(this.sCase, 'nominal')
                            this.fCycleTime =  10 * 60; % 10 min
                            this.fVolumetricFlowrateMain = 0.0070792; %equals 15 cfm
                        elseif strcmp(this.sCase, 'exercise')
                            this.fCycleTime =  6.5 * 60; % 6,5 min
                            this.fVolumetricFlowrateMain = 0.0122706; % equals 26 cfm
                        elseif strcmp(this.sCase, 'sleep')
                            this.fCycleTime =  15 * 60; % 15 min
                            this.fVolumetricFlowrateMain = 0.00471946; % equals 10 cfm
                        elseif strcmp(this.sCase, 'off')
                        else
                            keyboard();
                        end
                        
                        
                        this.fInternalTime = 0;
                        
                        this.toStores.Filter_A.toProcsP2P.FilterAH2O.setCase(this.sCase);
                        this.toStores.Filter_A.toProcsP2P.FilterACO2.setCase(this.sCase);
                        this.toStores.Filter_B.toProcsP2P.FilterBH2O.setCase(this.sCase);
                        this.toStores.Filter_B.toProcsP2P.FilterBCO2.setCase(this.sCase);
                        this.toStores.Filter_A.toProcsP2P.FilterAH2O.setCycleTime(this.fCycleTime);
                        this.toStores.Filter_A.toProcsP2P.FilterACO2.setCycleTime(this.fCycleTime);
                        this.toStores.Filter_B.toProcsP2P.FilterBH2O.setCycleTime(this.fCycleTime);
                        this.toStores.Filter_B.toProcsP2P.FilterBCO2.setCycleTime(this.fCycleTime);
                        
                        
                        this.bUpdateCase = 'false';
                    end
                    
                    this.fFlowrateMain = this.fVolumetricFlowrateMain * this.oAtmosphere.fDensity;
                end
                
                
                %%%%%%%%%%%%%%%%% Absorbing Filter:
                
                % Pressure Equalization: During this time only this process takes place and therefore
                % the inflow is set to zero
                if this.fInternalTime < (this.fPressureCompensationTime)
                    
                    this.toBranches.CAMRAS_Air_Out_C1.oHandler.setActive(false);
                    this.toBranches.CAMRAS_Air_In_C1.oHandler.setFlowRate(0);
                    
                else
                    
                    
                    this.toBranches.CAMRAS_Air_Out_C1.oHandler.setActive(true);
                    
                    if this.toStores.Filter_A.toPhases.PhaseIn.fPressure < 1e5
                        %Actually the inlet flowrates should probably be
                        %changed for the initial refill but no data was
                        %available so here it is assumed that just nothing
                        %flows out until the bed reaches 1 bar pressure
                        this.toBranches.CAMRAS_Air_In_C1.oHandler.setFlowRate(-this.fFlowrateMain);
                        this.toBranches.CAMRAS_Air_Out_C1.oHandler.setAllowedFlowRate(3e-2 * this.fFlowrateMain);
%                         this.setTimeStep(0.1);
                    elseif this.toStores.Filter_A.toPhases.PhaseIn.fPressure > 1.5e5
                        this.toBranches.CAMRAS_Air_In_C1.oHandler.setFlowRate(-this.fFlowrateMain);
                        this.toBranches.CAMRAS_Air_Out_C1.oHandler.setAllowedFlowRate(-3e-2 * this.fFlowrateMain);
%                         this.setTimeStep(0.1);
                    else
                        
                        this.toBranches.CAMRAS_Air_In_C1.oHandler.setFlowRate(-this.fFlowrateMain);
                        this.toBranches.CAMRAS_Air_Out_C1.oHandler.setAllowedFlowRate(0);
                        this.setTimeStep(this.fInitialTimeStep);
                    end
                end
                
                
                %%%%%%%%%%%%%%%%% Desorbing Filter:
                
                %The CO2 filter that is not used in the active cycle is
                %connected to the vacuum so that it can desorb CO2
                
                % Pressure Equalization Process
                if this.fInternalTime < this.fPressureCompensationTime
                    
                    
                    tTimeStepProperties.rMaxChange = inf;
                    tTimeStepProperties.fFixedTimeStep = 1;
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    this.toStores.Filter_A.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    this.toStores.Filter_B.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    
                    if this.toStores.Filter_A.aoPhases(1,1).fPressure < this.toStores.Filter_B.aoPhases(1,1).fPressure
                        this.toBranches.PressureCompensation.oHandler.setFlowRate(-1.0 *(this.fMassToEqualize/(this.fPressureCompensationTime)));
                        this.toBranches.Filter_B_Desorb.oHandler.setActive(false);
                        this.toBranches.Filter_B_Vacuum.oHandler.setFlowRate(0);
                        
                    end
                    
                % Creating the Vacuum in the Filter Phase    
                elseif this.fInternalTime > (this.fPressureCompensationTime) && this.fInternalTime < (this.fVacuumTime)
                    
                    this.toBranches.PressureCompensation.oHandler.setFlowRate(0);
                    
                    tTimeStepProperties.fFixedTimeStep = 1;
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    this.toStores.Filter_A.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    
                    tTimeStepProperties.rMaxChange = 0.1;
                    tTimeStepProperties.fFixedTimeStep = [];
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    this.toStores.Filter_B.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    
                    if this.iCounter == 0 && this.toStores.Filter_B.toPhases.PhaseIn.fPressure <= this.toStores.Filter_A.toPhases.PhaseIn.fPressure
                        fSpecificGasConstant = (this.oMT.Const.fUniversalGas/this.toStores.Filter_B.toPhases.PhaseIn.fMolarMass);
                        this.fMassToVacuum = (this.toStores.Filter_B.toPhases.PhaseIn.fVolume/(fSpecificGasConstant*this.toStores.Filter_B.toPhases.PhaseIn.fTemperature))*(this.toStores.Filter_B.toPhases.PhaseIn.fPressure - 500);
                        this.iCounter =1;
                        this.fTime = this.fInternalTime;
                    end
                    
                    if this.toStores.Filter_B.toPhases.PhaseIn.fPressure > 500 && this.iCounter == 1
                        fFlowRateToVaccum = (this.fMassToVacuum/((this.fVacuumTime)-(this.fTime)));
                        this.toBranches.Filter_B_Vacuum.oHandler.setFlowRate(fFlowRateToVaccum);
                        this.toBranches.Filter_B_Desorb.oHandler.setActive(false);
                        this.toBranches.PressureCompensation.oHandler.setFlowRate(0);
                    else
                        fFlowRateToVaccum = 0;
                        this.toBranches.Filter_B_Vacuum.oHandler.setFlowRate(fFlowRateToVaccum);
                    end
                    
                    
                % Actuall desorbing process takes place    
                else
                    
                    tTimeStepProperties.rMaxChange = 0.1;
                    tTimeStepProperties.fFixedTimeStep = [];
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    this.toStores.Filter_A.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.CO2) = 0.3;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.H2O) = 0.3;
                    tTimeStepProperties.fMinStep = 0.1;
                    tTimeStepProperties.rMaxChange = 1;
                    tTimeStepProperties.fFixedTimeStep = [];
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    this.toStores.Filter_B.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    
                    this.toBranches.Filter_B_Desorb.oHandler.setActive(true);
                    this.toBranches.PressureCompensation.oHandler.setFlowRate(0);
                    this.toBranches.Filter_B_Vacuum.oHandler.setFlowRate(0);
                    
                end
            end
            
            
            %% Cycle two
            if this.fInternalTime > this.fCycleTime
                if this.iCycleActive == 1
                                        
                    % This section is only entered at the beginning of
                    % cycle one and therefore everything that needs to be
                    % done at this point in time is done here!
                    
                    % Set cycle one filter modes
                    this.toStores.Filter_A.toProcsP2P.FilterAH2O.setFilterMode('desorb');
                    this.toStores.Filter_A.toProcsP2P.FilterACO2.setFilterMode('desorb');
                    this.toStores.Filter_B.toProcsP2P.FilterBH2O.setFilterMode('absorb');
                    this.toStores.Filter_B.toProcsP2P.FilterBCO2.setFilterMode('absorb');
                    this.iCycleActive = 2;
                    
                    % Setting cycle two flow rates zero
                    this.toBranches.CAMRAS_Air_In_C1.oHandler.setFlowRate(0);
                    this.toBranches.Filter_B_Vacuum.oHandler.setFlowRate(0);
                    this.toBranches.Filter_B_Desorb.oHandler.setActive(false);
                    this.toBranches.CAMRAS_Air_Out_C1.oHandler.setActive(false);
                    
                    
                    % Calculate Mass that needs to be moved to equalize the
                    % pressure between Bed A and Bed B
                    fMassFilterAEqualize = this.toStores.Filter_A.aoPhases(1,1).fMass;
                    fMassFilterBEqualize = this.toStores.Filter_B.aoPhases(1,1).fMass;
                    this.fMassToEqualize = 0.5 * (fMassFilterAEqualize-fMassFilterBEqualize);
                    
                    this.iCounter = 0;
                    
                    this.fFlowrateMain = this.fVolumetricFlowrateMain * this.oAtmosphere.fDensity;
                    
                    
                    if this.iCounterOff == 1
                        this.iCounterOff = 2;
                    elseif this.iCounterOff == 3
                        this.iCounterOff = 4;
                    end
                    
                end
                
                %%%%%%%%%%%%%%%%%% Absorbing Filter:
                
                if this.fInternalTime < (this.fPressureCompensationTime + this.fCycleTime)
                    
                    this.toBranches.CAMRAS_Air_Out_C2.oHandler.setActive(false);
                    this.toBranches.CAMRAS_Air_In_C2.oHandler.setFlowRate(0);
                else
                    this.toBranches.CAMRAS_Air_Out_C2.oHandler.setActive(true);
                    
                    if this.toStores.Filter_B.toPhases.PhaseIn.fPressure < 1e5
                        %Actually the inlet flowrates should probably be
                        %changed for the initial refill but no data was
                        %available so here it is assumed that just nothing
                        %flows out until the bed reaches 1 bar pressure
                        this.toBranches.CAMRAS_Air_In_C2.oHandler.setFlowRate(-this.fFlowrateMain);
                        this.toBranches.CAMRAS_Air_Out_C2.oHandler.setAllowedFlowRate(3e-2 * this.fFlowrateMain);
%                         this.setTimeStep(0.1);
                    elseif this.toStores.Filter_B.toPhases.PhaseIn.fPressure > 1.5e5
                        this.toBranches.CAMRAS_Air_In_C2.oHandler.setFlowRate(-this.fFlowrateMain);
                        this.toBranches.CAMRAS_Air_Out_C2.oHandler.setAllowedFlowRate(-3e-2 * this.fFlowrateMain);
%                         this.setTimeStep(0.1);
                    else
                        
                        this.toBranches.CAMRAS_Air_In_C2.oHandler.setFlowRate(-this.fFlowrateMain);
                        this.toBranches.CAMRAS_Air_Out_C2.oHandler.setAllowedFlowRate(0);
                        this.setTimeStep(this.fInitialTimeStep);
                    end
                end
                
                %%%%%%%%%%%%%%%%% Desorbing Filter:
                
                %The CO2 filter that is not used in the active cycle is
                %connected to the vacuum so that it can desorb CO2
                
                % Pressure Equalization Process
                if this.fInternalTime < (this.fPressureCompensationTime + this.fCycleTime)
                    
                    tTimeStepProperties.rMaxChange = inf;
                    tTimeStepProperties.fFixedTimeStep = 1;
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    this.toStores.Filter_A.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    this.toStores.Filter_B.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    
                    if this.toStores.Filter_B.toPhases.PhaseIn.fPressure < this.toStores.Filter_A.toPhases.PhaseIn.fPressure
                        
                        this.toBranches.PressureCompensation.oHandler.setFlowRate(1.0 * (this.fMassToEqualize/(this.fPressureCompensationTime)));
                        this.toBranches.Filter_A_Desorb.oHandler.setActive(false);
                        this.toBranches.Filter_A_Vacuum.oHandler.setFlowRate(0);
                        
                    else
                        this.toBranches.PressureCompensation.oHandler.setFlowRate(0);
                    end
                    
                % Creating the vacuum in the filter phase    
                elseif this.fInternalTime > (this.fPressureCompensationTime + this.fCycleTime) && this.fInternalTime < (this.fVacuumTime + this.fCycleTime)
                    
                    this.toBranches.PressureCompensation.oHandler.setFlowRate(0);
                    
                    tTimeStepProperties.fFixedTimeStep = 1;
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    this.toStores.Filter_B.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    
                    tTimeStepProperties.rMaxChange = 0.1;
                    tTimeStepProperties.fFixedTimeStep = [];
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    this.toStores.Filter_A.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    
                    if this.iCounter == 0 && this.toStores.Filter_A.toPhases.PhaseIn.fPressure <= this.toStores.Filter_B.toPhases.PhaseIn.fPressure
                        fSpecificGasConstant = (this.oMT.Const.fUniversalGas/this.toStores.Filter_A.toPhases.PhaseIn.fMolarMass);
                        this.fMassToVacuum = (this.toStores.Filter_A.toPhases.PhaseIn.fVolume/(fSpecificGasConstant*this.toStores.Filter_A.toPhases.PhaseIn.fTemperature))*(this.toStores.Filter_A.toPhases.PhaseIn.fPressure - 500);
                        this.fTime = this.fInternalTime;
                        this.iCounter =1;
                    end
                    
                    if this.toStores.Filter_A.toPhases.PhaseIn.fPressure > 500 && this.iCounter == 1
                        fFlowRateToVaccum = (this.fMassToVacuum/((this.fVacuumTime)-(this.fTime-this.fCycleTime)));
                        this.toBranches.Filter_A_Vacuum.oHandler.setFlowRate(fFlowRateToVaccum);
                        this.toBranches.Filter_A_Desorb.oHandler.setActive(false);
                        this.toBranches.PressureCompensation.oHandler.setFlowRate(0);
                    else
                        fFlowRateToVaccum = 0;
                        this.toBranches.Filter_A_Vacuum.oHandler.setFlowRate(fFlowRateToVaccum);
                    end
                   
                    
                % Actual desorbing process takes place    
                else
                    
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.CO2) = 0.3;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.H2O) = 0.3;
                    tTimeStepProperties.fMinStep = 0.1;
                    tTimeStepProperties.rMaxChange = 1;
                    tTimeStepProperties.fFixedTimeStep   = [];
                    this.toStores.Filter_A.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    tTimeStepProperties = struct();
                    tTimeStepProperties.rMaxChange = 0.01;
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    this.toStores.Filter_B.toPhases.PhaseIn.setTimeStepProperties(tTimeStepProperties);
                    
                    this.toBranches.Filter_A_Desorb.oHandler.setActive(true);
                    this.toBranches.PressureCompensation.oHandler.setFlowRate(0);
                    this.toBranches.Filter_A_Vacuum.oHandler.setFlowRate(0);
                    
                end
            end
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            this.update();
        end
    end
end