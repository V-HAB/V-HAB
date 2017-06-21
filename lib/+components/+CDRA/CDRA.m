classdef CDRA < vsys
    %% Carbon Dioxide Removal Assembly (CDRA) Subsystem File
    % Alternative Name: 4BMS or 4 Bed Molecular Sieve
    %
    % The ISS uses two CDRAs as part of the US life support systems. One is
    % located in Node 3 and the other in the US Lab (normally only one CDRA
    % is working at the same time). Each CDRA gets air from a Common Cabin
    % Air Assembly (CCAA) that has first passed through a condesing heat
    % exchanger to remove most of the humidity in the air. This is done
    % because the adsorption of water and CO2 on zeolite would favor wator
    % instead of CO2. The CDRA itself consists of 4 adsorber beds of which
    % 2 are used to remove CO2 while the others are used to remove the
    % remaining humidity before the CO2 adsorbing beds.
    
    properties
        %% Properties
        %The maximum power in watt for the electrical heaters that are used
        %to increase the zeolite temperature during the CO2 scrubbing.
        % In ICES-2015-160 the heater power is mentioned to be 480 per
        % heater string with two heater strings beeing used
        fMaxHeaterPower = 980;          % [W] 
        
        %Target temperature the zeolite is supposed to reach during the
        %desorption of CO2
        TargetTemperature = 477.15;     % [K]
        
        %Number of active cycle (can be 1 or 2, so either cycle 1 is active
        %or cycle 2)
        iCycleActive = 1;
        
        %Mass flow rate for the air that is passing through the system.
        %If the subsystem is a CDRA this depends on the value set by the
        %CCAA, but if it is a Vozdukh the values is based on a volumetric
        %flow rate.
        fFlowrateMain = 0;                  % [kg/s]
        
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
        
        % Initialitation time for the pressure to reach "nominal"
        % conditions after a CDRA cycle switch
        fInitTime = 10;                 % [s]
        
        % Number of steps taken within the initialitation time to built up
        % the pressure
        iInitStep = 250;                % [-]
        
        % Subsystem name for the CCAA that is connected to this CDRA
        sAsscociatedCCAA;
        
        % Object of the phase to which this Subsystem is connected.
        % Required to calculate the mass flow based on the volumetric flow
        % rate for Vozdukh
        oAtmosphere;
        
        % struct to initialize the atmosphere within CDRA itself
        tAtmosphere;
        
        % Boolean property to decide if this CDRA is used as Vozdukh
        % imitation (since no data on Vozdukh is available)
        bVozdukh = false;
        
        % Number of cells within the current adsorption cycle (THIS DOES
        % NOT INLCUDE THE CELLS IN THE BED CURRENTLY DESORBING!)
        iCells;
        
        % The Geometry struct contains information about the geometry of
        % the beds (either order by bed in the substructs or order by cell
        % in the vectors)
        tGeometry;
        
        % Struct that contains information about the thermal network, for
        % example the name of the conductor/capacities for the cells, or
        % the heat flows of each cell etc.
        tThermalNetwork;
        
        % Struct that contains the phases,branches, absorbers etc order
        % according to the order in which they are located in CDRA for the
        % different cycles
        tMassNetwork;
        
        % As it sounde, the minimum  and maximum timestep used for the system
        fMinimumTimeStep        = 1e-5;
        fMaximumTimeStep        = 5;
        
        % This variable decides by how much percent the mass in any one cell
        % is allowed to change within one tick (increasing this does not
        % necessarily speed up the simulation, but you can try)
        rMaxChange              = 0.1;
        % Defines the maximum partial mass change (e.g. of H2O) within the
        % numerical calculation of CDRA
        arMaxPartialMassChange;
        
        % Sturct to store properties from the last recalculation of phases
        % to decide if they have to be recalculated or not
        tLastUpdateProps;
        
        % Struct containing information on the time steps of the individual
        % subcalculations and the last execution time of these
        % subcalculations
        tTimeProperties;
        
    end
    
    methods
        function this = CDRA(oParent, sName, tAtmosphere, sAsscociatedCCAA)
            this@vsys(oParent, sName, 1e-12);
            
            this.sAsscociatedCCAA = sAsscociatedCCAA;
            
            this.tAtmosphere = tAtmosphere;
            
            %Setting of the cycle time and air safe time depending on which
            %system is simulated
            this.fCycleTime = 144*60;
            this.fAirSafeTime = 10*60;
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            % Minimum time step has to be reduced, not because it is used
            % in the system but to prevent flowrates from beeing rounded
            % to zero
            this.oTimer.setMinStep(1e-12)
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% Initialization of properties
            this.tMassNetwork.aoBranchesCycleOne = matter.branch.empty();
            this.tMassNetwork.aoBranchesCycleTwo = matter.branch.empty();

            this.tMassNetwork.aoPhasesCycleOne = matter.phase.empty;
            this.tMassNetwork.aoPhasesCycleTwo = matter.phase.empty;

            this.tMassNetwork.aoAbsorberCycleOne = matter.procs.p2p.empty;
            this.tMassNetwork.aoAbsorberCycleTwo = matter.procs.p2p.empty;

            this.tMassNetwork.aoAbsorberPhases = matter.phase.empty;

            %% Creating the initialization data used for the individual filter beds
            %
            % geometrical data:
            % CDRA Adsorber Bed Cross Section
            fCrossSection = (0.195)^2;  %value now according to Benni Portners discussion von Jim Knox
            
            this.tGeometry.Zeolite5A.fCrossSection       = fCrossSection;
            this.tGeometry.Sylobead.fCrossSection        = fCrossSection;
            this.tGeometry.Zeolite13x.fCrossSection      = fCrossSection;
            
            % Length for the individual filter material within CDRA
            % according to ICES-2014-160
            this.tGeometry.Zeolite5A.fLength         =  16.68        *2.54/100;
            this.tGeometry.Sylobead.fLength          =  6.13         *2.54/100;
            this.tGeometry.Zeolite13x.fLength        = (5.881+0.84)  *2.54/100;
            
            %From ICES-2014-168 Table 2 e_sorbent
            this.tGeometry.Zeolite13x.rVoidFraction      = 0.457;
            this.tGeometry.Zeolite5A.rVoidFraction       = 0.445;
            this.tGeometry.Sylobead.rVoidFraction        = 0.348;
            
            this.tGeometry.Zeolite13x.fAbsorberVolume        =   (1-this.tGeometry.Zeolite13x.rVoidFraction)        * fCrossSection * this.tGeometry.Zeolite13x.fLength;
            this.tGeometry.Sylobead.fAbsorberVolume          =   (1-this.tGeometry.Sylobead.rVoidFraction)          * fCrossSection * this.tGeometry.Sylobead.fLength;
            this.tGeometry.Zeolite5A.fAbsorberVolume         =   (1-this.tGeometry.Zeolite5A.rVoidFraction)         * fCrossSection * this.tGeometry.Zeolite5A.fLength;
            
            % From ICES-2015-160
            fMassZeolite13x     = 5.164;
            fMassSylobead       = 5.38 + 6.32; %(WS and Sylobead)
            fMassZeolite5A      = 12.383;
            
            % These are the correct estimates for the flow volumes of each
            % bed which are used in the filter adsorber proc for
            % calculations. 
            this.tGeometry.Zeolite13x.fVolumeFlow          =        (this.tGeometry.Zeolite13x.fCrossSection 	* this.tGeometry.Zeolite13x.fLength      * this.tGeometry.Zeolite13x.rVoidFraction);
            this.tGeometry.Sylobead.fVolumeFlow            =        (this.tGeometry.Sylobead.fCrossSection  	* this.tGeometry.Sylobead.fLength        * this.tGeometry.Sylobead.rVoidFraction);
            this.tGeometry.Zeolite5A.fVolumeFlow           =        (this.tGeometry.Zeolite5A.fCrossSection  	* this.tGeometry.Zeolite5A.fLength       * this.tGeometry.Zeolite5A.rVoidFraction);
            
        	tInitialization.Zeolite13x.tfMassAbsorber  =   struct('Zeolite13x',fMassZeolite13x);
            tInitialization.Zeolite13x.fTemperature    =   281.25;
            
        	tInitialization.Sylobead.tfMassAbsorber  =   struct('Sylobead_B125',fMassSylobead);
            tInitialization.Sylobead.fTemperature    =   281.25;
            
        	tInitialization.Zeolite5A.tfMassAbsorber  =   struct('Zeolite5A',fMassZeolite5A);
            tInitialization.Zeolite5A.fTemperature    =   281.25;
            
            % Aside from the absorber mass itself the initial values of
            % absorbed substances (like H2O and CO2) can be set. Since the
            % loading is not equal over the cells they have to be defined
            % for each cell (the values can obtained by running the
            % simulation for a longer time without startvalues and set them
            % according to the values once the simulation is repetetive)
        	tInitialization.Zeolite13x.mfInitialCO2             = [0.01, 0.01, 0.01  0.01, 0.01];
        	tInitialization.Zeolite13x.mfInitialH2O             = [   0,    0,    0,    0,    0];
            
        	tInitialization.Sylobead.mfInitialCO2               = [   0,    0,    0,    0,    0];
        	tInitialization.Sylobead.mfInitialH2OAbsorb         = [ 0.4, 0.24, 0.13, 0.08, 0.05]; % Only set for the bed that just finished absorbing
        	tInitialization.Sylobead.mfInitialH2ODesorb         = [0.17, 0.05,    0,    0,    0]; % Only set for the bed that just finished desorbing
            
        	tInitialization.Zeolite5A.mfInitialCO2              = [   0,    0,    0,    0,    0];
        	tInitialization.Zeolite5A.mfInitialH2O              = [   0,    0,    0,    0,    0];
            
            % Sets the cell numbers used for the individual filters
            tInitialization.Zeolite13x.iCellNumber = 3;
            tInitialization.Sylobead.iCellNumber = 3;
            tInitialization.Zeolite5A.iCellNumber = 5;
            
            % Values for the mass transfer coefficient can be found in the
            % paper ICES-2014-168. Here the values for Zeolite5A are used
            % assuming that the coefficients for 5A and 5A-RK38 are equal.
            mfMassTransferCoefficient = zeros(1,this.oMT.iSubstances);
            mfMassTransferCoefficient(this.oMT.tiN2I.CO2)   = 0.003;
            mfMassTransferCoefficient(this.oMT.tiN2I.H2O)   = 0.0007;
            tInitialization.Zeolite5A.mfMassTransferCoefficient     =   mfMassTransferCoefficient;
            tInitialization.Zeolite13x.mfMassTransferCoefficient    =   mfMassTransferCoefficient;
            
            mfMassTransferCoefficient(this.oMT.tiN2I.CO2)   = 0;
            mfMassTransferCoefficient(this.oMT.tiN2I.H2O)   = 0.002;
            tInitialization.Sylobead.mfMassTransferCoefficient    =   mfMassTransferCoefficient;
            
            % The thermal conductivity of zeolite, has to be used to
            % generate the nodal network for the thermal solver
            % Thermal conductivity values were taken from technical data
            % sheet of grace.com for sylobeads and zeolites
            % https://grace.com/general-industrial/en-us/Documents/sylobead_br_E_2010_f100222_web.pdf
            % 
            % mention in any papers that these values depend a lot on the
            % structure/size of the beads etc, so the values are not
            % accurate
            tInitialization.Zeolite13x.fConductance         = 0.12;
            tInitialization.Sylobead.fConductance           = 0.14;
            tInitialization.Zeolite5A.fConductance          = 0.12;
            
            % The hydraulic diameter is calculated from area and
            % circumfence using the void fraction to reduce it to account
            % for the area blocked by absorbent (best option right now, the
            % flow rates are not the values of primary interest, but the
            % calculation is necessary to equalize phase masses and
            % pressures for variying temperatures etc.)
            this.tGeometry.Zeolite13x.fD_Hydraulic           = (4*this.tGeometry.Zeolite13x.fCrossSection/(4*0.195))* this.tGeometry.Zeolite13x.rVoidFraction;
            this.tGeometry.Sylobead.fD_Hydraulic             = (4*this.tGeometry.Sylobead.fCrossSection/(4*0.195))* this.tGeometry.Sylobead.rVoidFraction;
            this.tGeometry.Zeolite5A.fD_Hydraulic            = (4*this.tGeometry.Zeolite5A.fCrossSection/(4*0.195))* this.tGeometry.Zeolite13x.rVoidFraction;
            
            % The surface area is required to calculate the thermal
            % exchange between the absorber and the gas flow. It is
            % calculated (approximatly) by assuming the asborbent is
            % spherical and using absorbent mass and the mass of each
            % sphere to calculate the number of spheres, then multiply this
            % with the area of each sphere!
            %
            % According to ICES-2014-168 the diameter of the pellets for
            % 13x is 2.19 mm --> the volume of each sphere is
            % 4/3*pi*(2.19/2)^3 = 5.5 mm3, while the area is 
            % 4*pi*(2.19/2)^2 = 15 mm2
            nSpheres_13x = (tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 5.5e-9));
            this.tGeometry.Zeolite13x.fAbsorberSurfaceArea      = (15e-6)*nSpheres_13x;
            % For Sylobead the average diameter is mentioned to be 2.25 mm:
            % 4/3*pi*(2.25/2)^3 = 5.96 mm3, while the area is 
            % 4*pi*(2.25/2)^2 = 15.9 mm2
            nSpheres_Sylobead = (tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 5.96e-9));
            this.tGeometry.Sylobead.fAbsorberSurfaceArea        = (15.9e-6)*nSpheres_Sylobead;
            % For 5a the average diameter is mentioned to be 2.21 mm:
            % 4/3*pi*(2.1/2)^3 = 4.85 mm3, while the area is 
            % 4*pi*(2.1/2)^2 = 13.85 mm2
            nSpheres_5A = (tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 4.85e-9));
            this.tGeometry.Zeolite5A.fAbsorberSurfaceArea       = (13.85e-6)*nSpheres_5A;
            
            % For the thermal calculations during which nothing flow the
            % free gas distance is necessary as value. This is assumed to
            % be half the diameter of the spheres
            this.iCells = 2*tInitialization.Sylobead.iCellNumber + 2*tInitialization.Zeolite13x.iCellNumber + tInitialization.Zeolite5A.iCellNumber;
            
            this.tGeometry.mfAbsorbentRadius = zeros(this.iCells+tInitialization.Zeolite5A.iCellNumber,1);
            this.tGeometry.mfAbsorbentRadius(1:tInitialization.Sylobead.iCellNumber) = 2.25e-3/2;
            
            iCurrentCell = tInitialization.Sylobead.iCellNumber+1;
            this.tGeometry.mfAbsorbentRadius(iCurrentCell : iCurrentCell+tInitialization.Zeolite13x.iCellNumber) = 2.19e-3/2;
            
            iCurrentCell = tInitialization.Sylobead.iCellNumber + tInitialization.Zeolite13x.iCellNumber + 1;
            this.tGeometry.mfAbsorbentRadius(iCurrentCell:iCurrentCell+tInitialization.Zeolite5A.iCellNumber) = 2.21e-3/2;
            
            iCurrentCell = tInitialization.Sylobead.iCellNumber + tInitialization.Zeolite13x.iCellNumber + tInitialization.Zeolite5A.iCellNumber + 1;
            this.tGeometry.mfAbsorbentRadius(iCurrentCell:iCurrentCell+tInitialization.Zeolite13x.iCellNumber) = 2.19e-3/2;
            
            iCurrentCell = tInitialization.Sylobead.iCellNumber + 2*tInitialization.Zeolite13x.iCellNumber + tInitialization.Zeolite5A.iCellNumber + 1;
            this.tGeometry.mfAbsorbentRadius(iCurrentCell:iCurrentCell+tInitialization.Sylobead.iCellNumber) = 2.25e-3/2;
            
            iCurrentCell = 2*tInitialization.Sylobead.iCellNumber + 2*tInitialization.Zeolite13x.iCellNumber + tInitialization.Zeolite5A.iCellNumber + 1;
            this.tGeometry.mfAbsorbentRadius(iCurrentCell:iCurrentCell+tInitialization.Zeolite5A.iCellNumber) = 2.21e-3/2;
            
            % Now all values to create the system are defined and the 6
            % absorbers can be defined. There will be 6 absorbers because
            % the dessicant beds to remove humidity have a layer of
            % sylobead and 13x which are modelled as individual absorber
            % beds in this model.
            
            %% Generating the Filters:
            % In order to create the 6 filter beds for loops are used to
            % generate all necessary INTERNAL stores, p2ps, and branches of
            % the different filters. The connections and interfaces of the
            % filters have to be created individually later on
            
            csTypes = {'Zeolite13x', 'Sylobead', 'Zeolite5A'};
            for iType = 1:3
                % The filter and flow phase total masses struct have to be
                % divided by the number of cells to obtain the tfMass struct
                % for each phase of each cell. Currently the assumption here is
                % that each cell has the same size.
                fAbsorberVolume         = this.tGeometry.(csTypes{iType}).fAbsorberVolume;
                fFlowVolume             = this.tGeometry.(csTypes{iType}).fVolumeFlow;
                iCellNumber             = tInitialization.(csTypes{iType}).iCellNumber;
                fTemperatureFlow        = tInitialization.(csTypes{iType}).fTemperature;
                fTemperatureAbsorber    = tInitialization.(csTypes{iType}).fTemperature;
                fPressure               = this.tAtmosphere.fPressure;
                fConductance            = tInitialization.(csTypes{iType}).fConductance * (this.tGeometry.(csTypes{iType}).fLength / iCellNumber);
                mfMassTransferCoefficient = tInitialization.(csTypes{iType}).mfMassTransferCoefficient;

                % Adds two stores (filter stores), containing sylobead
                % A special filter store has to be used for the filter to
                % prevent the gas phase volume from beeing overwritten since
                % more than one gas phase is used to implement several cells
                components.filter.components.FilterStore(this, [(csTypes{iType}), '_1'], (fFlowVolume + fAbsorberVolume));
                components.filter.components.FilterStore(this, [(csTypes{iType}), '_2'], (fFlowVolume + fAbsorberVolume));
                
                % Since there are two filters of each type a for loop over the
                % two filters is used as well
                for iFilter = 1:2
                    sName               = [(csTypes{iType}),'_',num2str(iFilter)];
                    % Now the phases, exmes, p2ps and branches and thermal
                    % representation for the filter model can be created. A for
                    % loop is used to allow any number of cells from 2 upwards.
                    moCapacity = cell(iCellNumber,2);

                    for iCell = 1:iCellNumber
                        % The absorber phases contain the material that removes
                        % certain substances from the gas phase which is
                        % represented in the flow phases. To better track these the
                        % Phase names contain the cell number at the end.
                    
                        clear tfMassesAbsorber;
                        clear tfMassesFlow;
                        
                        csAbsorberSubstances = fieldnames(tInitialization.(csTypes{iType}).tfMassAbsorber);
                        for iK = 1:length(csAbsorberSubstances)
                            tfMassesAbsorber.(csAbsorberSubstances{iK}) = tInitialization.(csTypes{iType}).tfMassAbsorber.(csAbsorberSubstances{iK})/iCellNumber;
                        end
                        tfMassesAbsorber.CO2 = tInitialization.(csTypes{iType}).mfInitialCO2(iCell);
                        % For sylobead the h2o mass is only set for the bed
                        % that just finished absorbing (as the other bed
                        % has a mass of zero)
                        if this.iCycleActive == 1 
                            if strcmp(sName, 'Sylobead_1')
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2OAbsorb(iCell);
                            elseif strcmp(sName, 'Sylobead_2')
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2ODesorb(iCell);
                            else
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2O(iCell);
                            end
                        else
                            if strcmp(sName, 'Sylobead_1')
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2ODesorb(iCell);
                            elseif strcmp(sName, 'Sylobead_2')
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2OAbsorb(iCell);
                            else
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2O(iCell);
                            end
                        end
                        
                        if this.iCycleActive == 1 
                            if ~strcmp(sName, 'Zeolite5A_2')
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), fTemperatureFlow, 0, this.tAtmosphere.fPressure);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), fTemperatureAbsorber, fPressure);
                                oFlowPhase = components.CDRA.components.FilterFlowPhase(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), fTemperatureFlow, oFilterPhase.fTotalHeatCapacity);
                            else
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0, 100);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), this.TargetTemperature, fPressure);
                                oFlowPhase = components.CDRA.components.FilterFlowPhase(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), this.TargetTemperature, oFilterPhase.fTotalHeatCapacity);
                            end
                        else
                            if ~strcmp(sName, 'Zeolite5A_1')
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), fTemperatureFlow, 0, this.tAtmosphere.fPressure);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), fTemperatureAbsorber, fPressure);
                                oFlowPhase = components.CDRA.components.FilterFlowPhase(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), fTemperatureFlow, oFilterPhase.fTotalHeatCapacity);
                            else
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0, 100);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), this.TargetTemperature, fPressure);
                                oFlowPhase = components.CDRA.components.FilterFlowPhase(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), this.TargetTemperature, oFilterPhase.fTotalHeatCapacity);
                            end
                        end
                        % An individual orption and desorption Exme and P2P is
                        % required because it is possible that a few substances are
                        % beeing desorbed at the same time as others are beeing
                        % adsorbedads
                        matter.procs.exmes.mixture(oFilterPhase, ['Adsorption_',num2str(iCell)]);
                        matter.procs.exmes.mixture(oFilterPhase, ['Desorption_',num2str(iCell)]);
                        
                        % for the flow phase two addtional exmes for the gas flow
                        % through the filter are required
                        matter.procs.exmes.gas(oFlowPhase, ['Adsorption_',num2str(iCell)]);
                        matter.procs.exmes.gas(oFlowPhase, ['Desorption_',num2str(iCell)]);
                        matter.procs.exmes.gas(oFlowPhase, ['Inflow_',num2str(iCell)]);
                        matter.procs.exmes.gas(oFlowPhase, ['Outflow_',num2str(iCell)]);

                        % in order to correctly create the thermal interface a heat
                        % source is added to each of the phases
                        oHeatSource = thermal.heatsource(this, ['AbsorberHeatSource_',num2str(iCell)], 0);
                        moCapacity{iCell,1} = this.addCreateCapacity(oFilterPhase, oHeatSource);

                        oHeatSource = thermal.heatsource(this, ['FlowHeatSource_',num2str(iCell)], 0);
                        moCapacity{iCell,2} = this.addCreateCapacity(oFlowPhase, oHeatSource);

                        % adding two P2P processors, one for desorption and one for
                        % adsorption. Two independent P2Ps are required because it
                        % is possible that one substance is currently absorber
                        % while another is desorbing which results in two different
                        % flow directions that can occur at the same time.
                        components.filter.components.Desorption_P2P(this.toStores.(sName), ['DesorptionProcessor_',num2str(iCell)], ['Absorber_',num2str(iCell),'.Desorption_',num2str(iCell)], ['Flow_',num2str(iCell),'.Desorption_',num2str(iCell)]);
                        components.filter.components.Adsorption_P2P(this.toStores.(sName), ['AdsorptionProcessor_',num2str(iCell)], ['Flow_',num2str(iCell),'.Adsorption_',num2str(iCell)], ['Absorber_',num2str(iCell),'.Adsorption_',num2str(iCell)], mfMassTransferCoefficient);

                        % Each cell is connected to the next cell by a branch, the
                        % first and last cell also have the inlet and outlet branch
                        % attached that connects the filter to the parent system
                        %
                        % Note: Only the branches in between the cells of
                        % the currently generated filter are created here!
                        if iCell == 1
                            %
                        elseif iCell == iCellNumber
                            % branch between the current and the previous cell
                            matter.branch(this, [sName,'.','Outflow_',num2str(iCell-1)], {}, [sName,'.','Inflow_',num2str(iCell)], [sName, 'Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);

                        else
                            % branch between the current and the previous cell
                            matter.branch(this, [sName,'.','Outflow_',num2str(iCell-1)], {}, [sName,'.','Inflow_',num2str(iCell)], [sName, 'Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                            % Create and add linear conductors between each cell
                            % absorber material to reflect the thermal conductance
                            % of the absorber material
                            this.addConductor(thermal.conductors.linear(this, moCapacity{iCell-1,2}, moCapacity{iCell,2}, fConductance));
                        end
                        
                        % this factor times the mass flow^2 will decide the pressure
                        % loss. In this case the pressure loss will be 1 bar at a
                        % flowrate of 0.01 kg/s
                        this.tGeometry.(csTypes{iType}).mfFrictionFactor(iCell) = 5e7/iCellNumber;
                    
                    end
                    this.tGeometry.(csTypes{iType}).iCellNumber   = iCellNumber;
                end
            end
            
            %% Definition of interface branches
            
            % Sylobead branches
            % Inlet of sylobed one (the outlet requires another interface
            % because the location from which the air is supplied is
            % different
            matter.branch(this, 'Sylobead_1.Inflow_1', {}, 'CDRA_Air_In_1', 'CDRA_Air_In_1');
            
            oFlowPhase = this.toStores.Sylobead_1.toPhases.Flow_1;
            matter.procs.exmes.gas(oFlowPhase, 'Outlet');
            matter.branch(this, 'Sylobead_1.Outlet', {}, 'CDRA_Air_Out_2', 'CDRA_Air_Out_2');
            
            iCellNumber = tInitialization.Sylobead.iCellNumber;
            matter.branch(this, ['Sylobead_1.Outflow_',num2str(iCellNumber)], {}, 'Zeolite13x_1.Inflow_1', 'Sylobead1_to_13x1');
            
            matter.branch(this, 'Sylobead_2.Inflow_1', {}, 'CDRA_Air_In_2', 'CDRA_Air_In_2');
            
            oFlowPhase = this.toStores.Sylobead_2.toPhases.Flow_1;
            matter.procs.exmes.gas(oFlowPhase, 'Outlet');
            matter.branch(this, 'Sylobead_2.Outlet', {}, 'CDRA_Air_Out_1', 'CDRA_Air_Out_1');
            
            iCellNumber = tInitialization.Sylobead.iCellNumber;
            matter.branch(this, ['Sylobead_2.Outflow_',num2str(iCellNumber)], {}, 'Zeolite13x_2.Inflow_1', 'Sylobead2_to_13x2');
            
            % Interface between 13x and 5A zeolite absorber beds 
            iCellNumber = tInitialization.Zeolite13x.iCellNumber;
            
            components.Temp_Dummy(this, 'PreCooler_5A1', 285, 1000);
            components.Temp_Dummy(this, 'PreCooler_5A2', 285, 1000);
            
            matter.branch(this, ['Zeolite13x_1.Outflow_',num2str(iCellNumber)], {'PreCooler_5A1'}, 'Zeolite5A_1.Inflow_1', 'Zeolite13x1_to_5A1');
            matter.branch(this, ['Zeolite13x_2.Outflow_',num2str(iCellNumber)], {'PreCooler_5A2'}, 'Zeolite5A_2.Inflow_1', 'Zeolite13x2_to_5A2');
            
            
            oFlowPhase = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCellNumber)]);
            matter.procs.exmes.gas(oFlowPhase, 'Inlet');
            
            oFlowPhase = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCellNumber)]);
            matter.procs.exmes.gas(oFlowPhase, 'Inlet');
            
            iCellNumber = tInitialization.Zeolite5A.iCellNumber;
            
            matter.branch(this, ['Zeolite5A_1.Outflow_',num2str(iCellNumber)], {}, 'Zeolite13x_2.Inlet', 'Zeolite5A1_to_13x2');
            matter.branch(this, ['Zeolite5A_2.Outflow_',num2str(iCellNumber)], {}, 'Zeolite13x_1.Inlet', 'Zeolite5A2_to_13x1');

            
            % 5A to Vacuum connection branches
            oFlowPhase = this.toStores.Zeolite5A_1.toPhases.(['Flow_',num2str(iCellNumber)]);
            matter.procs.exmes.gas(oFlowPhase, 'OutletVacuum');
            matter.procs.exmes.gas(oFlowPhase, 'OutletAirSafe');
            matter.branch(this, 'Zeolite5A_1.OutletVacuum', {}, 'CDRA_Vent_2', 'CDRA_Vent_2');
            matter.branch(this, 'Zeolite5A_1.OutletAirSafe', {}, 'CDRA_AirSafe_2', 'CDRA_AirSafe_2');
            
            oFlowPhase = this.toStores.Zeolite5A_2.toPhases.(['Flow_',num2str(iCellNumber)]);
            matter.procs.exmes.gas(oFlowPhase, 'OutletVacuum');
            matter.procs.exmes.gas(oFlowPhase, 'OutletAirSafe');
            matter.branch(this, 'Zeolite5A_2.OutletVacuum', {}, 'CDRA_Vent_1', 'CDRA_Vent_1');
            matter.branch(this, 'Zeolite5A_2.OutletAirSafe', {}, 'CDRA_AirSafe_1', 'CDRA_AirSafe_1');
            
            
            %% For easier handling the branches are ordered in the order through which the flow goes for each of the two cycles
            % Cycle One
            iSize = this.iCells + 1;
            
            this.tMassNetwork.miNegativesCycleOne = ones(iSize,1);
            
            this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.CDRA_Air_In_1;
            this.tMassNetwork.miNegativesCycleOne(1) = -1; % Inlet branch has to be negative to be an inlet
            
            for iCell = 1:(tInitialization.Sylobead.iCellNumber-1)
                this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Sylobead_1Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.Sylobead1_to_13x1;
            
            for iCell = 1:(tInitialization.Zeolite13x.iCellNumber-1)
                this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Zeolite13x_1Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.Zeolite13x1_to_5A1;
            
            for iCell = 1:(tInitialization.Zeolite5A.iCellNumber-1)
                this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Zeolite5A_1Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.Zeolite5A1_to_13x2;
            
            for iCell = tInitialization.Zeolite13x.iCellNumber:-1:2
                this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Zeolite13x_2Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                this.tMassNetwork.miNegativesCycleOne(length(this.tMassNetwork.aoBranchesCycleOne)) = -1;
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.Sylobead2_to_13x2;
            this.tMassNetwork.miNegativesCycleOne(length(this.tMassNetwork.aoBranchesCycleOne)) = -1;
            
            for iCell = tInitialization.Sylobead.iCellNumber:-1:2
                this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Sylobead_2Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                this.tMassNetwork.miNegativesCycleOne(length(this.tMassNetwork.aoBranchesCycleOne)) = -1;
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleOne(end+1,1) = this.toBranches.CDRA_Air_Out_1;
            
            % cycle 2
            
            this.tMassNetwork.miNegativesCycleTwo = ones(iSize,1);
            
            this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.CDRA_Air_In_2;
            this.tMassNetwork.miNegativesCycleTwo(1) = -1; % Inlet branch has to be negative to be an inlet
            
            for iCell = 1:(tInitialization.Sylobead.iCellNumber-1)
                this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Sylobead_2Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.Sylobead2_to_13x2;
            
            for iCell = 1:(tInitialization.Zeolite13x.iCellNumber-1)
                this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Zeolite13x_2Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.Zeolite13x2_to_5A2;
            
            for iCell = 1:(tInitialization.Zeolite5A.iCellNumber-1)
                this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Zeolite5A_2Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.Zeolite5A2_to_13x1;
            
            for iCell = tInitialization.Zeolite13x.iCellNumber:-1:2
                this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Zeolite13x_1Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                this.tMassNetwork.miNegativesCycleTwo(length(this.tMassNetwork.aoBranchesCycleTwo)) = -1;
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.Sylobead1_to_13x1;
            this.tMassNetwork.miNegativesCycleTwo(length(this.tMassNetwork.aoBranchesCycleTwo)) = -1;
            
            for iCell = tInitialization.Sylobead.iCellNumber:-1:2
                this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Sylobead_1Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                this.tMassNetwork.miNegativesCycleTwo(length(this.tMassNetwork.aoBranchesCycleTwo)) = -1;
            end
            % Connection Branch
            this.tMassNetwork.aoBranchesCycleTwo(end+1,1) = this.toBranches.CDRA_Air_Out_2;
            
            % initializes the adsorption heat flow property
            iThermalCells = this.iCells+tInitialization.Zeolite5A.iCellNumber;
            this.tThermalNetwork.mfAdsorptionHeatFlow 	= zeros(iThermalCells,1);
            this.tMassNetwork.mfAdsorptionFlowRate      = zeros(iThermalCells,1);
            this.tThermalNetwork.mfHeaterPower          = zeros(iThermalCells,1);
            
            this.tLastUpdateProps.mfDensity              = zeros(iThermalCells,1);
            this.tLastUpdateProps.mfFlowSpeed            = zeros(iThermalCells,1);
            this.tLastUpdateProps.mfSpecificHeatCapacity = zeros(iThermalCells,1);

            this.tLastUpdateProps.mfDynamicViscosity     = zeros(iThermalCells,1);
            this.tLastUpdateProps.mfThermalConductivity  = zeros(iThermalCells,1);
            
            this.tThermalNetwork.miRecalcFailed          = zeros(iThermalCells,1);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            csBranches = fieldnames(this.toBranches);
            
            % Only the air in flows are manual branches, they will be used
            % to set the primary flowrate through CDRA
            for iB = 1:length(csBranches)
                if regexp(csBranches{iB}, 'CDRA_Air_In')
                    solver.matter.manual.branch(this.toBranches.(csBranches{iB}));
                elseif regexp(csBranches{iB}, 'CDRA_AirSafe')
                    solver.matter.manual.branch(this.toBranches.(csBranches{iB}));
                else
                    solver.matter.residual.branch(this.toBranches.(csBranches{iB}));
                end
            end
            
            csStores = fieldnames(this.toStores);
            % sets numerical properties for the phases of CDRA
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    if regexp(oPhase.sName, 'Flow')
                        oPhase.rMaxChange = 0.1;
                        oPhase.arMaxChange(this.oMT.tiN2I.H2O) = 1;
                        oPhase.arMaxChange(this.oMT.tiN2I.CO2) = 1;
                        oPhase.fMaxStep = 60;
                        oPhase.fMinStep = 1e-3;
                    else
                        oPhase.rMaxChange = 0.1;
                        oPhase.arMaxChange(this.oMT.tiN2I.H2O) = 1;
                        oPhase.arMaxChange(this.oMT.tiN2I.CO2) = 1;
                        oPhase.fMaxStep = 60;
                        oPhase.fMinStep = 1e-3;
                    end
                end
            end
            oPhase = this.tMassNetwork.aoBranchesCycleOne(1).coExmes{2}.oPhase;
            oPhase.rMaxChange = 0.5;
            oPhase.arMaxChange(this.oMT.tiN2I.H2O) = 1;
            oPhase.arMaxChange(this.oMT.tiN2I.CO2) = 1;
            oPhase.fMaxStep = 60;
            oPhase.fMinStep = 1e-3;
            
            
            % Sets the rMaxChange of the System
            this.arMaxPartialMassChange = zeros(this.iCells,this.oMT.iSubstances);
            this.arMaxPartialMassChange(:,this.oMT.tiN2I.CO2) = 0.6;
            this.arMaxPartialMassChange(:,this.oMT.tiN2I.H2O) = 0.6;
            
            % adds the lumped parameter thermal solver to calculate the
            % convective and conductive heat transfer
            this.oThermalSolver = solver.thermal.lumpedparameter(this);
            
            % sets the minimum time step that can be used by the thermal
            % solver
            this.oThermalSolver.fMinimumTimeStep = 0.01;
            
            this.tTimeProperties.AdsorptionLastExec = -10;
            this.tTimeProperties.AdsorptionStep = -1;
            this.tTimeProperties.DesorptionLastExec = -10;
            this.tTimeProperties.DesorptionStep = 1;
            
            this.tTimeProperties.fLastCycleSwitch = -10000;
            
            this.tMassNetwork.mfMassDiff = zeros(this.iCells+1,1);
            
            % Initialize residual branches to be inactive
            csCycle = {'One', 'Two'};
            for iCycle = 1:2
                for iBranch = 2:(length(this.tMassNetwork.(['aoBranchesCycle', csCycle{iCycle}])))
                    this.tMassNetwork.(['aoBranchesCycle', csCycle{iCycle}])(iBranch).oHandler.setActive(false);
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
            
            %% Additional to the branches the phases are also stored in an array according to the order of the flow within the CDRA
            % Cycle One
            mfFrictionFactor        = zeros(this.iCells,1);
            mfLength                = zeros(this.iCells,1);
            mfAbsorberSurfaceArea   = zeros(this.iCells,1);
            mfD_Hydraulic           = zeros(this.iCells,1);
            
            csNodes_Absorber_CycleOne       = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            csConductors_Flow_CycleOne      = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            csNodes_Absorber_CycleTwo       = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            csConductors_Flow_CycleTwo      = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            
            csNodes_Flow_CycleOne     = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            csNodes_Flow_CycleTwo     = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            
            for iCell = 1:this.tGeometry.Sylobead.iCellNumber
                this.tMassNetwork.aoPhasesCycleOne(end+1,1)   = this.toStores.Sylobead_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Sylobead_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Sylobead.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)               = this.tGeometry.Sylobead.fLength/this.tGeometry.Sylobead.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1)  = this.tGeometry.Sylobead.fAbsorberSurfaceArea/this.tGeometry.Sylobead.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)          = this.tGeometry.Sylobead.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Sylobead_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1}     = [this.sName ,'__Sylobead_1__Flow_',num2str(iCell)];
                csConductors_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Sylobead_1ConvectiveConductor_', num2str(iCell)];
                
            end
                
            for iCell = 1:this.tGeometry.Zeolite13x.iCellNumber
                this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite13x_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite13x.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)                = this.tGeometry.Zeolite13x.fLength/this.tGeometry.Zeolite13x.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite13x.fAbsorberSurfaceArea/this.tGeometry.Zeolite13x.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)           = this.tGeometry.Zeolite13x.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Zeolite13x_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1}     = [this.sName ,'__Zeolite13x_1__Flow_',num2str(iCell)];
                
                csConductors_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Zeolite13x_1ConvectiveConductor_', num2str(iCell)];
                
            end
            
            for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite5A_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite5A.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)                = this.tGeometry.Zeolite5A.fLength/this.tGeometry.Zeolite5A.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite5A.fAbsorberSurfaceArea/this.tGeometry.Zeolite5A.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)     	  = this.tGeometry.Zeolite5A.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Zeolite5A_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1}     = [this.sName ,'__Zeolite5A_1__Flow_',num2str(iCell)];
                
                csConductors_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Zeolite5A_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tGeometry.Zeolite13x.iCellNumber:-1:1
                this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite13x_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite13x.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)              = this.tGeometry.Zeolite13x.fLength/this.tGeometry.Zeolite13x.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1) = this.tGeometry.Zeolite13x.fAbsorberSurfaceArea/this.tGeometry.Zeolite13x.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)    	 = this.tGeometry.Zeolite13x.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Zeolite13x_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1}     = [this.sName ,'__Zeolite13x_2__Flow_',num2str(iCell)];
                
                csConductors_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Zeolite13x_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tGeometry.Sylobead.iCellNumber:-1:1
                this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toStores.Sylobead_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Sylobead_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Sylobead.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)              = this.tGeometry.Sylobead.fLength/this.tGeometry.Sylobead.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1) = this.tGeometry.Sylobead.fAbsorberSurfaceArea/this.tGeometry.Sylobead.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)    	 = this.tGeometry.Sylobead.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Sylobead_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1}     = [this.sName ,'__Sylobead_2__Flow_',num2str(iCell)];
                
                csConductors_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Sylobead_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                csNodes_Absorber_CycleOne{this.iCells + iCell,1} = [this.sName ,'__Zeolite5A_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{this.iCells + iCell,1} = [this.sName ,'__Zeolite5A_2__Flow_',num2str(iCell)];
                csConductors_Flow_CycleOne{this.iCells + iCell,1} = ['Zeolite5A_2ConvectiveConductor_', num2str(iCell)];
                mfAbsorberSurfaceArea(this.iCells + iCell,1) = this.tGeometry.Sylobead.fAbsorberSurfaceArea/this.tGeometry.Sylobead.iCellNumber;
            end
            
            this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toBranches.CDRA_Air_Out_1.coExmes{2}.oPhase;
            
%             for iPhase = 1:length(this.tMassNetwork.aoPhasesCycleOne)
%                 this.tMassNetwork.aoPhasesCycleOne(iPhase).oOriginPhase = this.oAtmosphere;
%             end
            
            this.tThermalNetwork.csNodes_Absorber_CycleOne  = csNodes_Absorber_CycleOne;
            this.tThermalNetwork.csNodes_Flow_CycleOne      = csNodes_Flow_CycleOne;
            this.tThermalNetwork.csConductors_Flow_CycleOne = csConductors_Flow_CycleOne;
            
            this.tGeometry.mfLength                 = mfLength;
            this.tGeometry.mfAbsorberSurfaceArea    = mfAbsorberSurfaceArea;
            this.tGeometry.mfD_Hydraulic            = mfD_Hydraulic;
            
            % Cycle Two
            for iCell = 1:this.tGeometry.Sylobead.iCellNumber
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Sylobead_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Sylobead_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Sylobead_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1}     = [this.sName ,'__Sylobead_2__Flow_',num2str(iCell)];
                
                csConductors_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Sylobead_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tGeometry.Zeolite13x.iCellNumber
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite13x_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Zeolite13x_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1}     = [this.sName ,'__Zeolite13x_2__Flow_',num2str(iCell)];
                
                csConductors_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Zeolite13x_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite5A_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Zeolite5A_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1}     = [this.sName ,'__Zeolite5A_2__Flow_',num2str(iCell)];
                
                csConductors_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Zeolite5A_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tGeometry.Zeolite13x.iCellNumber:-1:1
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite13x_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Zeolite13x_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1}     = [this.sName ,'__Zeolite13x_1__Flow_',num2str(iCell)];
                
                csConductors_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Zeolite13x_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tGeometry.Sylobead.iCellNumber:-1:1
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Sylobead_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Sylobead_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Sylobead_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1}     = [this.sName ,'__Sylobead_1__Flow_',num2str(iCell)];
                
                csConductors_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Sylobead_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                csNodes_Absorber_CycleTwo{this.iCells + iCell,1} = [this.sName ,'__Zeolite5A_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{this.iCells + iCell,1} = [this.sName ,'__Zeolite5A_1__Flow_',num2str(iCell)];
                csConductors_Flow_CycleTwo{this.iCells + iCell,1} = ['Zeolite5A_1ConvectiveConductor_', num2str(iCell)];
            end
            
            this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toBranches.CDRA_Air_Out_2.coExmes{2}.oPhase;
            
%             for iPhase = 1:length(this.tMassNetwork.aoPhasesCycleTwo)
%                 this.tMassNetwork.aoPhasesCycleTwo(iPhase).oOriginPhase = this.oAtmosphere;
%             end
            
            this.tThermalNetwork.csNodes_Absorber_CycleTwo  = csNodes_Absorber_CycleTwo;
            this.tThermalNetwork.csNodes_Flow_CycleTwo      = csNodes_Flow_CycleTwo;
            this.tThermalNetwork.csConductors_Flow_CycleTwo = csConductors_Flow_CycleTwo;
            
            this.tGeometry.mfFrictionFactor = mfFrictionFactor;
           
        end
        function setReferencePhase(this, oPhase)
            this.oAtmosphere = oPhase;
            
            % assumed heat transfer cooefficient between CDRA and
            % atmosphere: 0.195
            
            % Well internal area assumed to be equal to external
            fArea5A         =     this.tGeometry.Zeolite5A.fCrossSection  * this.tGeometry.Zeolite5A.fLength    / this.tGeometry.Zeolite13x.iCellNumber;
            fAreaSylobead   =     this.tGeometry.Sylobead.fCrossSection   * this.tGeometry.Sylobead.fLength     / this.tGeometry.Sylobead.iCellNumber;
            fArea13x        =     this.tGeometry.Zeolite13x.fCrossSection * this.tGeometry.Zeolite13x.fLength   / this.tGeometry.Zeolite5A.iCellNumber;
            
            fThermalConductivity = this.oMT.calculateThermalConductivity(oPhase);
            
            % Note: Transfer coefficient for the V-HAB thermal solver has
            % to be in W/K which means it is U*A or in this case
            % 1/sum(R_th): With R_th = s/(lambda * A)
            % Assumes                            20 cm of air and                                 2 cm of AL                     + 10cm of zeolite, conductivity values from "Thermal Conducivity and melting Point Measurements on Paraffin Zeolite Mixtures" 
            mfTransferCoefficient(1)   	= 1 / ( (0.2/(fThermalConductivity .* fArea13x))       + (0.02/(237 .* fArea13x))      + (0.1/(0.07 .* fArea13x)));
            mfTransferCoefficient(2)    = 1 / ( (0.2/(fThermalConductivity .* fAreaSylobead))  + (0.02/(237 .* fAreaSylobead)) + (0.1/(0.07 .* fArea13x))); % asssumed conducitivty of 13x
            mfTransferCoefficient(3)   	= 1 / ( (0.2/(fThermalConductivity .* fArea5A))        + (0.02/(237 .* fArea5A))       + (0.1/(0.104 .* fArea13x)));
            
            % adds a boundary node for the atmosphere around CDRA
            oAtmosphereCapacity = this.addCreateCapacity(oPhase);

            csTypes = {'Zeolite13x', 'Sylobead', 'Zeolite5A'};
            % Since there are two filters of each type a for loop over the
            % two filters is used as well
            for iType = 1:3
                for iFilter = 1:2
                    sName = [(csTypes{iType}),'_',num2str(iFilter)];
                    for iCell = 1:this.tGeometry.(csTypes{iType}).iCellNumber
                        
                        % Note that absorber and flow capacities are
                        % treated as one, and the flow is used in all
                        % instances (the temperature of the absorber is
                        % then simply set to the same temperature as the
                        % flow)
                        sAbsorberCapacity   = [this.sName,'__',(csTypes{iType}),'_',num2str(iFilter),'__','Flow_',num2str(iCell)];

                        oCapacityAbsorber = this.poCapacities(sAbsorberCapacity);

                        this.addConductor(thermal.conductors.linear(this, oCapacityAbsorber, oAtmosphereCapacity, mfTransferCoefficient(iType), [sName, '_CabinConductor_', num2str(iCell)]));
                        
                    end
                end
            end

        end
        
        function setHeaterPower(this, mfPower)
            % this function is used to set the power of the electrical
            % heaters inside the filter. If no heaters are used just leave
            % this property at zero at all times.
            this.tThermalNetwork.mfHeaterPower = mfPower;
            
            % in case that a new heater power was set the function to
            % recalculate the thermal properties of the filter has to be
            % called to ensure that the change is recoginzed by the model
%             this.calculateThermalProperties();
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            % in order to keep it somewhat transpart what is calculated
            % when (and to allow individual parts of the code the be called
            % individually) the necessary calculations for the filter are
            % split up into several subfunctions
            
            if this.bVozdukh == 1
                % Main flow rate through the Vozdukh (source P.Plötner page 32 "...the amount of processed air is known with circa 27m^3 per hour, ...");
                %therefore this volumetric flowrate is transformed into a mass
                %flow based on the current atmosphere conditions.
                this.fFlowrateMain = (27/3600) * this.oAtmosphere.fDensity;
            else
                %for the CDRA/4BMS the main flow rate is the one supplied
                %by the CCAA
                % TO DO: Check when the flowrate from CCAA is smaller!
                this.fFlowrateMain  = this.oParent.toChildren.(this.sAsscociatedCCAA).fCDRA_FlowRate;
%                 this.fFlowrateMain  = this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.CHX_CDRA.oHandler.fRequestedFlowRate;
            end
            
            %% Cycle Change handling:
            % in case the cycle is switched a number of changes has to be
            % made to the flowrates, which are only necessary ONCE!
            % (setting the flowrates of all branches to zero, and only then
            % recalculate the filter)
            if this.oTimer.fTime > (this.tTimeProperties.fLastCycleSwitch + this.fCycleTime)
                % the currently active cycle is the "old" cycle which will
                % be deactivated by this logic
                if this.iCycleActive == 1
                    iOldCycle = 1;
                    iNewCycle = 2;
                    sOldCycle = 'One';
                    sNewCycle = 'Two';
                else
                    iOldCycle = 2;
                    iNewCycle = 1;
                    sOldCycle = 'Two';
                    sNewCycle = 'One';
                end
                
                % On cycle change all flow rates are momentarily set to zero
                this.tMassNetwork.(['aoBranchesCycle', sOldCycle])(1).oHandler.setFlowRate(0);
                for iBranch = 2:length(this.tMassNetwork.(['aoBranchesCycle', sOldCycle]))
                    this.tMassNetwork.(['aoBranchesCycle', sOldCycle])(iBranch).oHandler.setAllowedFlowRate(0);
                    this.tMassNetwork.(['aoBranchesCycle', sOldCycle])(iBranch).oHandler.setActive(false);
                end
                this.toBranches.(['CDRA_Vent_',num2str(iOldCycle)]).oHandler.setActive(false);
                this.toBranches.(['CDRA_AirSafe_',num2str(iOldCycle)]).oHandler.setFlowRate(0);
                
                this.tTimeProperties.fLastCycleSwitch = this.oTimer.fTime;
                
                % In order to get the flow rate calculation to higher
                % speeds at each cycle change the phases are preset to
                % contain pressures close to the final pressure (after the
                % initial flowrate setup)
                mfPressureDiff = this.tGeometry.mfFrictionFactor .* (this.oParent.toChildren.(this.sAsscociatedCCAA).fCDRA_FlowRate)^2;
                mfPressurePhase = zeros(this.iCells+1,1);
                for iPhase = 1:length(this.tMassNetwork.(['aoPhasesCycle', sNewCycle]))
                    mfPressurePhase(iPhase) = this.tMassNetwork.(['aoPhasesCycle', sNewCycle])(end).fPressure + sum(mfPressureDiff(iPhase:end));
                end
                % The time step for the cycle change case is set to ONE
                % second, therefore the calculated mass difference is
                % directly the required flow rate that has to go into the
                % phase to reach the desired mass
                this.tMassNetwork.mfMassDiff = ((mfPressurePhase .* [this.tMassNetwork.(['aoPhasesCycle', sNewCycle]).fVolume]') ./ (287.1 .* 295)) - [this.tMassNetwork.(['aoPhasesCycle', sNewCycle]).fMass]';
                this.tMassNetwork.mfMassDiff(end) = 0;
                
                % Now the mass difference required in the phases is
                % translated into massflows for the branches for the next
                % second
                mfMassChangeRate = zeros(this.iCells+1,1);
                this.tMassNetwork.(['aoBranchesCycle', sNewCycle])(1).oHandler.setFlowRate(-this.fFlowrateMain);
                for iBranch = 2:(length(this.tMassNetwork.(['aoBranchesCycle', sNewCycle])))
                    this.tMassNetwork.(['aoBranchesCycle', sNewCycle])(iBranch).oHandler.setPositiveFlowDirection(this.tMassNetwork.(['miNegativesCycle', sNewCycle])(iBranch) == 1);
                    this.tMassNetwork.(['aoBranchesCycle', sNewCycle])(iBranch).oHandler.setActive(true);
                    
                    mfMassChangeRate(iBranch) = this.tMassNetwork.mfMassDiff(iBranch)/this.fInitTime;
                    this.tMassNetwork.(['aoBranchesCycle', sNewCycle])(iBranch).oHandler.setAllowedFlowRate(mfMassChangeRate(iBranch-1));
                end
                
                % Sets the correct cells for the adsorption P2Ps to store
                % their values
                for iP2P = 1:length(this.tMassNetwork.(['aoAbsorberCycle', sNewCycle]))
                    this.tMassNetwork.(['aoAbsorberCycle', sNewCycle])(iP2P).iCell = iP2P;
                end
                for iP2P = 1:this.tGeometry.Zeolite5A.iCellNumber
                    this.toStores.(['Zeolite5A_', num2str(iOldCycle)]).toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).iCell = this.iCells + iP2P;
                    % TO DO: check if it is correct that only the desorbing
                    % cells are stored here
                    this.tMassNetwork.aoAbsorberPhases(iP2P) = this.toStores.(['Zeolite5A_', num2str(iOldCycle)]).toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).oOut.oPhase;
                end
                
                this.setTimeStep(this.fInitTime/this.iInitStep);
                
                for iPhase = 1:length(this.tMassNetwork.(['aoPhasesCycle', sNewCycle]))
                   this.tMassNetwork.(['aoPhasesCycle', sNewCycle])(iPhase).fFixedTS = this.fInitTime/this.iInitStep;
                   this.tMassNetwork.(['aoAbsorberPhases',sNewCycle])(iPhase).fFixedTS = this.fInitTime/this.iInitStep;
                end
                
                this.iCycleActive = iNewCycle;
                
            elseif mod(this.oTimer.fTime, this.fCycleTime) < this.fInitTime
            
                if this.iCycleActive == 1
                    sCycle = 'One';
                else
                    sCycle = 'Two';
                end
                aoPhases = this.tMassNetwork.(['aoPhasesCycle', sCycle]);
                aoBranches =  this.tMassNetwork.(['aoBranchesCycle', sCycle]);
                aoAbsorber  = this.tMassNetwork.(['aoAbsorberCycle',sCycle]);
                
                mfPressureDiff = this.tGeometry.mfFrictionFactor .* (this.oParent.toChildren.(this.sAsscociatedCCAA).fCDRA_FlowRate)^2;
                mfPressurePhase = zeros(this.iCells+1,1);
                for iPhase = 1:length(aoPhases)
                    mfPressurePhase(iPhase) = aoPhases(end).fPressure + sum(mfPressureDiff(iPhase:end));
                end
                mfCellPressure(:,1)     = [aoPhases.fPressure];
                
                abFinished = abs(mfCellPressure - mfPressurePhase) < 500;
                for iPhase = 1:length(abFinished)-1
                    if abFinished(iPhase)
                        aoBranches(iPhase+1).oHandler.setAllowedFlowRate(0);
                    end
                end
                
                for iAbsorber = 1:length(aoAbsorber)
                    aoAbsorber(iAbsorber).ManualUpdate(this.fInitTime/this.iInitStep);
                end
                
                if (this.fInitTime - mod(this.oTimer.fTime, this.fCycleTime)) <= (this.fInitTime/this.iInitStep) 
                    
                    if this.iCycleActive == 1
                        sCycle = 'One';
                    else
                        sCycle = 'Two';
                    end
                    for iPhase = 1:length(this.tMassNetwork.(['aoPhasesCycle', sCycle]))
                       this.tMassNetwork.(['aoPhasesCycle', sCycle])(iPhase).fFixedTS = [];
                       this.tMassNetwork.(['aoAbsorberPhases',sCycle])(iPhase).fFixedTS = [];
                    end
                end
            elseif mod(this.oTimer.fTime, this.fCycleTime) >= this.fInitTime
                % the flowrate update function is only called if no cycle
                % change is occuring in this tick!
                if this.fFlowrateMain == 0
                    % Main flowrate is 0 --> CDRA is shut down --> set all
                    % flowrates to zero and do not use dynamic calculation
                    for iBranch = 1:length(this.aoBranches)
                        this.aoBranches(iBranch).oHandler.setFlowRate(0);
                        if this.bVozdukh
                            this.setTimeStep(this.oParent.fTimeStep);
                        else
                            this.setTimeStep(this.oParent.toChildren.(this.sAsscociatedCCAA).fTimeStep);
                        end
                    end
                else
                    % If the cycle is not currently changing the normal
                    % calculation for the flowrates in continous operation
                    % are used
                    if ((this.tTimeProperties.AdsorptionLastExec + this.tTimeProperties.AdsorptionStep) - this.oTimer.fTime) <= 0
                        this.updateFlowratesAdsorption()
                    end
                    if ((this.tTimeProperties.DesorptionLastExec + this.tTimeProperties.DesorptionStep) - this.oTimer.fTime) <= 0
                        this.updateFlowratesDesorption()
                    end
                    
                    % The overall timestep of the system is set to the
                    % minimum timestep from the two calculations. However
                    % the calculations themself are executed using their
                    % individual time steps
                    fAdsorptionStep = (this.tTimeProperties.AdsorptionLastExec + this.tTimeProperties.AdsorptionStep) - this.oTimer.fTime;
                    fDesorptionStep = (this.tTimeProperties.DesorptionLastExec + this.tTimeProperties.DesorptionStep) - this.oTimer.fTime;
                    
                    this.setTimeStep(min([fAdsorptionStep, fDesorptionStep]));
                end
            end
            
            this.calculateThermalProperties();
            
            % since the thermal solver currently only has constant time
            % steps it currently uses the same time step as the filter
            % model.
            this.oThermalSolver.setTimestep(this.fTimeStep);
        end
        function updateFlowratesAdsorption(this, ~)
            
            if this.iCycleActive == 1
                sCycle = 'One';
            else
                sCycle = 'Two';
            end
            
            %% Adsorption Flow Rate Calculiation
            % here only the flowrates in the current adsorption cycle are
            % recalculated
            aoBranches  = this.tMassNetwork.(['aoBranchesCycle',sCycle]);
            aoPhases    = this.tMassNetwork.(['aoPhasesCycle',sCycle]);
            aoAbsorber  = this.tMassNetwork.(['aoAbsorberCycle',sCycle]);
            
            % The logic used to calculate the flow rates is as follows:
            %
            % The required phase pressures are easily calculated from the
            % flow rate that should go through CDRA, from there we can
            % calculate the required mass within the phases. Now
            % calculating the differenc between that mass and the current
            % mass allows us to calculate flowrate adaptions to the overall
            % flowrate to achieve the specified mass and pressure values.
            % The temperature changes are accounter for by using the mass
            % to pressure variable which accounts for the current phase
            % temperature!.
           	mfCellPressure(:,1)     = [aoPhases.fPressure];
           	mfCellMass(:,1)         = [aoPhases.fMass];
            mrPartialMasses         = reshape([aoPhases.arPartialMass], this.oMT.iSubstances, [])';
            mfFlowRates(:,1)        = [aoBranches.fFlowRate];
            mfAbsorberFlows         = reshape([aoAbsorber.mfFlowRatesProp], this.oMT.iSubstances, [])';

            % In order to get the flow rate calculation to higher
            % speeds at each cycle change the phases are preset to
            % contain pressures close to the final pressure (after the
            % initial flowrate setup)
            mfPressureDiff = this.tGeometry.mfFrictionFactor .* this.fFlowrateMain^2;
            mfPressurePhase = zeros(this.iCells+1,1);
            for iCell = 1:length(aoPhases)
                mfPressurePhase(iCell) = aoPhases(end).fPressure + sum(mfPressureDiff(iCell:end));
            end
            mfDeviation = (mfPressurePhase - mfCellPressure) ./ mfPressurePhase;
            
            % First branch has to be supply the main flowrate (in case it
            % was changed)
            aoBranches(1).oHandler.setFlowRate(- this.fFlowrateMain);
            
            % assumes that the mass change will take place over one second
            mfMassChangeRate = (0.1 .* mfCellMass .* mfDeviation);
            for iBranch = 2:length(aoBranches)
            % The reduction in flow rate from the P2Ps has to be given to
            % all the following branches as well
                aoBranches(iBranch).oHandler.setAllowedFlowRate(mfMassChangeRate(iBranch-1));
            end
            
       	    mfPartialFlowRates = mrPartialMasses .* mfFlowRates;
            mfPartialMassChange = mfPartialFlowRates(1:end-1,:) - mfPartialFlowRates(2:end,:) - mfAbsorberFlows;
            
            mfCellPartialMass = mfCellMass .* mrPartialMasses;
            
            mfCellPartialMass(mfCellPartialMass < 1e-5) = 1e-5;
            arPartialChangeToPartials = abs(mfPartialMassChange ./ tools.round.prec(mfCellPartialMass(1:end-1,:), this.oTimer.iPrecision));
            arPartialChangeToPartials(mfCellPartialMass(1:end-1,:) == 0) = 0;

            afNewStepPartialChangeToPartials = this.arMaxPartialMassChange ./ arPartialChangeToPartials;
            afNewStepPartialChangeToPartials(this.arMaxPartialMassChange == 0) = inf;

            fNewStepPartialChangeToPartials = min(min(afNewStepPartialChangeToPartials));
            
            % Now the time step can be calculated by using the maximum
            % allowable mass change within one step (Basically the time
            % step is 1/ Times Max Mass Change. For large mass changes it
            % therefore is small and for small mass changes it is large ;)
            fTimeStep = min(min(abs(this.rMaxChange ./ mfDeviation)), fNewStepPartialChangeToPartials);

            if fTimeStep > this.fMaximumTimeStep
                fTimeStep = this.fMaximumTimeStep;
            elseif fTimeStep  <= this.fMinimumTimeStep
                fTimeStep = this.fMinimumTimeStep;
            end
            
%             for iPhase = 1:length(aoPhases)
%                aoPhases(iPhase).fFixedTS = fTimeStep;
%             end

            % Manual update of the adsorption P2Ps with this time step!
            for iAbsorber = 1:length(aoAbsorber)
                aoAbsorber(iAbsorber).ManualUpdate(fTimeStep);
            end
            
            % Usefull code for debugging :)
            % Intended new cell masses on next tick, if this is not the
            % case use for debugging ;)
%             this.tMassNetwork.mfIntendedCellMass = mfCellMass + mfMassDiff;
            
%             iCell = 25;
%             ActualMassDiffLast = aoPhases(iCell).fMass - aoPhases(iCell).fMassLastUpdate;
%              
%             ActualMassDiffNow = fTimeStep * (abs(this.tMassNetwork.(['aoBranchesCycle',sCycle])(iCell).oHandler.fRequestedFlowRate) - abs(this.tMassNetwork.(['aoBranchesCycle',sCycle])(iCell+1).oHandler.fRequestedFlowRate) - this.tMassNetwork.mfAdsorptionFlowRate(iCell));
%             
%             this.tMassNetwork.(['aoBranchesCycle',sCycle])(iCell).oHandler.fRequestedFlowRate
%             this.tMassNetwork.(['aoBranchesCycle',sCycle])(iCell+1).oHandler.fRequestedFlowRate
%             this.tMassNetwork.mfAdsorptionFlowRate(iCell)
            
            this.tTimeProperties.AdsorptionLastExec = this.oTimer.fTime;
            this.tTimeProperties.AdsorptionStep = fTimeStep;
            
        end
        function updateFlowratesDesorption(this, ~)
            
            %% Desorption Flow Rate Calculiation
            % here only the flowrates in the current desorption cycle are
            % recalculated
            
            % TBD: How to implement the desorption calculation? I could use
            % the previous incompressible pressure based solver, and see
            % how well that works, then setting the smaller timestep as the
            % overall system step but keeping two seperate time steps for
            % desorption part and adsorption part
            
            % First air safe mode, during which a specific pressure is
            % created by the pump to remove air from CDRA and back into the
            % cabin during the 10 minute duration. The parameter that has
            % to be fitted to test data is the pressure created by the pump
            %
            % After that the actual desorption starts, for that the
            % pressure at the outlet should be set close to zero (do not
            % take the exit phase pressure) and the calculation should
            % simply decide what the flowrate is. Once the pressure in the
            % phase is low enough the calculation can switch to a simpler
            % calculation that just keeps the phase masses constant.
            
            if this.iCycleActive == 1
                sCycle = 'Two';
            else
                sCycle = 'One';
            end
            this.tTimeProperties.DesorptionLastExec = this.oTimer.fTime;
            
            iDesorbCells = this.tGeometry.Zeolite5A.iCellNumber;
            iStartCell = 1+(this.tGeometry.Sylobead.iCellNumber + this.tGeometry.Zeolite13x.iCellNumber);

            aoPhases = this.tMassNetwork.(['aoPhasesCycle',sCycle])(iStartCell:iStartCell+iDesorbCells-1);
            aoBranches = this.tMassNetwork.(['aoBranchesCycle',sCycle])(iStartCell+1:iStartCell+iDesorbCells-1);
            aoAbsorbers = this.tMassNetwork.(['aoAbsorberCycle',sCycle])(iStartCell:iStartCell+iDesorbCells-1);
            
            mfCellMass(:,1)     = [aoPhases.fMass];
            mfCellPressure(:,1) = [aoPhases.fPressure];
            
            abHighPressure = (mfCellPressure > 1);
            mfMassChangeRate = zeros(length(aoPhases),1);
            % Faktor of 2.5 chosen through try and error ( Cell mass is
            % going down over time, so we need to empty it faster,
            % simulates an exponential decline, that asymptotically tends
            % towards zero)
            mfMassChangeRate(abHighPressure) = -mfCellMass(abHighPressure)./(this.fAirSafeTime/2.5);
            
            if (mod(this.oTimer.fTime, this.fCycleTime)) < this.fAirSafeTime
                this.toBranches.(['CDRA_Vent_',num2str(this.iCycleActive)]).oHandler.setActive(false);
                aoBranches(end+1) = this.toBranches.(['CDRA_AirSafe_',num2str(this.iCycleActive)]);
                
                for iBranch = 1:length(aoBranches)-1
                    if ~aoBranches(iBranch).oHandler.bActive
                        aoBranches(iBranch).oHandler.setActive(true);
                    end
                    if ~aoBranches(iBranch).oHandler.bPositiveFlowDirection
                        aoBranches(iBranch).oHandler.setPositiveFlowDirection(true);
                    end
                    aoBranches(iBranch).oHandler.setAllowedFlowRate(mfMassChangeRate(iBranch));
                end
                aoBranches(end).oHandler.setFlowRate(-sum(mfMassChangeRate));
            else
                aoBranches(end+1) = this.toBranches.(['CDRA_Vent_',num2str(this.iCycleActive)]);
                
                if ~this.toBranches.(['CDRA_Vent_',num2str(this.iCycleActive)]).oHandler.bActive
                    this.toBranches.(['CDRA_Vent_',num2str(this.iCycleActive)]).oHandler.setActive(true);
                end
                
                for iBranch = 1:length(aoBranches)
                    aoBranches(iBranch).oHandler.setAllowedFlowRate(mfMassChangeRate(iBranch));
                end
                if this.toBranches.(['CDRA_AirSafe_',num2str(this.iCycleActive)]).fFlowRate ~= 0
                    this.toBranches.(['CDRA_AirSafe_',num2str(this.iCycleActive)]).oHandler.setFlowRate(0);
                end
            end
            
            %% Set the heater power for the desorption cells
            % Check cell temperature of the desorber cells
            
            mfCellTemperature(:,1)     = [aoPhases.fTemperature];
            mfCellHeatCap(:,1)         = [aoPhases.fTotalHeatCapacity];

            mfPowerDesorbCells = this.tThermalNetwork.mfHeaterPower(this.iCells+1:end);

            mbTempReached = (mfCellTemperature > (this.TargetTemperature - 1));
            mfPowerDesorbCells(mbTempReached) = 0;
            mfPowerDesorbCells(~mbTempReached) = ((this.TargetTemperature - mfCellTemperature(~mbTempReached)).* mfCellHeatCap(~mbTempReached))/this.fAirSafeTime;
                
            if (mod(this.oTimer.fTime, this.fCycleTime)) > this.fAirSafeTime
                mfPowerDesorbCells(mfPowerDesorbCells > this.fMaxHeaterPower) = this.fMaxHeaterPower/this.tGeometry.Zeolite5A.iCellNumber;
            else
                % during air safe mode only half of the heater power is
                % used
                mfPowerDesorbCells(mfPowerDesorbCells > this.fMaxHeaterPower) = (this.fMaxHeaterPower/this.tGeometry.Zeolite5A.iCellNumber)/2;
            end
            mfPower = zeros(this.iCells+this.tGeometry.Zeolite5A.iCellNumber,1);
            mfPower(this.iCells+1:end) = mfPowerDesorbCells;

            this.setHeaterPower(mfPower);
                
%             for iCell = this.iCells+1:length(this.tThermalNetwork.mfAdsorptionHeatFlow)
%                 oCapacity = this.poCapacities(this.tThermalNetwork.(['csNodes_Flow_Cycle',sCycle]){iCell,1});
%                 fHeatFlow = this.tThermalNetwork.mfHeaterPower(iCell) + this.tThermalNetwork.mfAdsorptionHeatFlow(iCell);
%                 oCapacity.oHeatSource.setPower(fHeatFlow);
%             end
            
            for iPhase = 1:length(aoPhases)
               aoPhases(iPhase).fFixedTS = this.tTimeProperties.DesorptionStep;
               aoAbsorbers(iPhase).ManualUpdate(this.tTimeProperties.DesorptionStep);
            end
            
        end
        function calculateThermalProperties(this)
            
            % Sets the flow temperature to the absorbers as well
            for iCell = 1:this.iCells
                fEnergyChange = (this.tMassNetwork.aoPhasesCycleOne(iCell).fTemperature - this.tMassNetwork.aoAbsorberCycleOne(iCell).oOut.oPhase.fTemperature) * this.tMassNetwork.aoAbsorberCycleOne(iCell).oOut.oPhase.fTotalHeatCapacity;
                this.tMassNetwork.aoAbsorberCycleOne(iCell).oOut.oPhase.changeInnerEnergy(fEnergyChange);
            end

            for iCell = 1:this.iCells
                fEnergyChange = (this.tMassNetwork.aoPhasesCycleTwo(iCell).fTemperature - this.tMassNetwork.aoAbsorberCycleTwo(iCell).oOut.oPhase.fTemperature) * this.tMassNetwork.aoAbsorberCycleTwo(iCell).oOut.oPhase.fTotalHeatCapacity;
                this.tMassNetwork.aoAbsorberCycleTwo(iCell).oOut.oPhase.changeInnerEnergy(fEnergyChange);
            end
        end
	end
end