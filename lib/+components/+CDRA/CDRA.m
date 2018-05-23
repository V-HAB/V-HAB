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
        fMaxHeaterPower = 960;          % [W] 
        
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
        % TO DO: Implement, but does this even make sense?
        bVozdukh = false;
        
        % Number of cells within the current adsorption cycle (THIS DOES
        % NOT INLCUDE THE CELLS IN THE BED CURRENTLY DESORBING!)
        iCells;
        
        % The Geometry struct contains information about the geometry of
        % the beds (either order by bed in the substructs or order by cell
        % in the vectors)
        tGeometry;
        
        % Struct that contains the phases,branches, absorbers etc order
        % according to the order in which they are located in CDRA for the
        % different cycles
        tMassNetwork;
        
        % Struct containing information on the time steps of the individual
        % subcalculations and the last execution time of these
        % subcalculations
        tTimeProperties;
        
    end
    
    methods
        function this = CDRA(oParent, sName, tAtmosphere, sAsscociatedCCAA)
            this@vsys(oParent, sName, 10);
            
            this.sAsscociatedCCAA = sAsscociatedCCAA;
            
            this.tAtmosphere = tAtmosphere;
            
            %Total time a cycle is active before switching to the other one.
            %This is also called half cycle sometimes with a full cycle beeing
            %considered the time it takes for both cycles to finish once. For
            %CDRA this is 144 minutes and for Vozdukh it is 30 minutes
            this.tTimeProperties.fCycleTime = 144*60;
            this.tTimeProperties.fAirSafeTime = 10*60;
            this.tTimeProperties.fLastCycleSwitch = -10000;
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
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
            fMassSylobead       = 5.38 + 0.632; %(WS and Sylobead)
            fMassZeolite5A      = 12.383;
            
            % These are the correct estimates for the flow volumes of each
            % bed which are used in the filter adsorber proc for
            % calculations. 
            this.tGeometry.Zeolite13x.fVolumeFlow          =        (this.tGeometry.Zeolite13x.fCrossSection 	* this.tGeometry.Zeolite13x.fLength      * this.tGeometry.Zeolite13x.rVoidFraction);
            this.tGeometry.Sylobead.fVolumeFlow            =        (this.tGeometry.Sylobead.fCrossSection  	* this.tGeometry.Sylobead.fLength        * this.tGeometry.Sylobead.rVoidFraction);
            this.tGeometry.Zeolite5A.fVolumeFlow           =        (this.tGeometry.Zeolite5A.fCrossSection  	* this.tGeometry.Zeolite5A.fLength       * this.tGeometry.Zeolite5A.rVoidFraction);
            
            % it is assumed that the structure of CDRA consists of mainly
            % aluminium and in total has 5 kg of al, per absorber bed that
            % is added to the absorber mass for additional thermal capacity
            % based on their length
            fAluminiumMass13x = 2 * (this.tGeometry.Zeolite13x.fLength / (this.tGeometry.Zeolite13x.fLength + this.tGeometry.Sylobead.fLength));
            
        	tInitialization.Zeolite13x.tfMassAbsorber  =   struct('Zeolite13x',fMassZeolite13x, 'Al', fAluminiumMass13x);
            tInitialization.Zeolite13x.fTemperature    =   281.25;
            
        	tInitialization.Sylobead.tfMassAbsorber  =   struct('Sylobead_B125',fMassSylobead, 'Al', 2 - fAluminiumMass13x);
            tInitialization.Sylobead.fTemperature    =   281.25;
            
        	tInitialization.Zeolite5A.tfMassAbsorber  =   struct('Zeolite5A',fMassZeolite5A, 'Al', 2);
            tInitialization.Zeolite5A.fTemperature    =   281.25;
            
            % Aside from the absorber mass itself the initial values of
            % absorbed substances (like H2O and CO2) can be set. Since the
            % loading is not equal over the cells they have to be defined
            % for each cell (the values can obtained by running the
            % simulation for a longer time without startvalues and set them
            % according to the values once the simulation is repetetive)
        	tInitialization.Zeolite13x.mfInitialCO2             = [0.01,  0.01,  0.01,  0.01,  0.01,  0.01,  0.01,  0.01,  0.01,  0.01];
        	tInitialization.Zeolite13x.mfInitialH2O             = [0.06, 0.018, 0.005,     0,     0,     0,     0,     0,     0,     0];
            
        	tInitialization.Sylobead.mfInitialCO2               = [   0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0];
        	tInitialization.Sylobead.mfInitialH2OAbsorb         = [ 0.4, 0.24, 0.13, 0.08, 0.05,    0,    0,    0,    0,    0,    0]; % Only set for the bed that just finished absorbing
        	tInitialization.Sylobead.mfInitialH2ODesorb         = [0.17, 0.05,    0,    0,    0,    0,    0,    0,    0,    0,    0]; % Only set for the bed that just finished desorbing
            
        	tInitialization.Zeolite5A.mfInitialCO2              = [   0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0];
        	tInitialization.Zeolite5A.mfInitialH2O              = [   0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0];
            
            % Sets the cell numbers used for the individual filters
            tInitialization.Zeolite13x.iCellNumber  = 5;
            tInitialization.Sylobead.iCellNumber    = 5;
            tInitialization.Zeolite5A.iCellNumber   = 5;
            
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
                mfMassTransferCoefficient = tInitialization.(csTypes{iType}).mfMassTransferCoefficient;

                % Adds two stores (filter stores), containing sylobead
                % A special filter store has to be used for the filter to
                % prevent the gas phase volume from beeing overwritten since
                % more than one gas phase is used to implement several cells
                if strcmp(csTypes{iType}, 'Zeolite5A')
                    components.filter.components.FilterStore(this, [(csTypes{iType}), '_1'], (2*fFlowVolume + fAbsorberVolume));
                    components.filter.components.FilterStore(this, [(csTypes{iType}), '_2'], (2*fFlowVolume + fAbsorberVolume));
                else
                    components.filter.components.FilterStore(this, [(csTypes{iType}), '_1'], (fFlowVolume + fAbsorberVolume));
                    components.filter.components.FilterStore(this, [(csTypes{iType}), '_2'], (fFlowVolume + fAbsorberVolume));
                end
                % Since there are two filters of each type a for loop over the
                % two filters is used as well
                for iFilter = 1:2
                    sName               = [(csTypes{iType}),'_',num2str(iFilter)];
                    
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
                                oFlowPhase = matter.phases.gas_flow_node(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), fTemperatureFlow);
                            else
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0, 100);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), this.TargetTemperature, fPressure);
                                oFlowPhase =  matter.phases.gas_flow_node(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), this.TargetTemperature);
                            end
                        else
                            if ~strcmp(sName, 'Zeolite5A_1')
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), fTemperatureFlow, 0, this.tAtmosphere.fPressure);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), fTemperatureAbsorber, fPressure);
                                oFlowPhase =  matter.phases.gas_flow_node(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), fTemperatureFlow, oFilterPhase.fTotalHeatCapacity);
                            else
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0, 100);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), this.TargetTemperature, fPressure);
                                oFlowPhase =  matter.phases.gas_flow_node(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), this.TargetTemperature, oFilterPhase.fTotalHeatCapacity);
                            end
                        end
                        % An individual orption and desorption Exme and P2P is
                        % required because it is possible that a few substances are
                        % beeing desorbed at the same time as others are beeing
                        % adsorbedads
                        matter.procs.exmes.mixture(oFilterPhase, [sName, '_Absorber_Adsorption_',num2str(iCell)]);
                        matter.procs.exmes.mixture(oFilterPhase, [sName, '_Absorber_Desorption_',num2str(iCell)]);
                        
                        % for the flow phase two addtional exmes for the gas flow
                        % through the filter are required
                        matter.procs.exmes.gas(oFlowPhase, [sName, '_Flow_Adsorption_',num2str(iCell)]);
                        matter.procs.exmes.gas(oFlowPhase, [sName, '_Flow_Desorption_',num2str(iCell)]);
                        matter.procs.exmes.gas(oFlowPhase, ['Inflow_',num2str(iCell)]);
                        matter.procs.exmes.gas(oFlowPhase, ['Outflow_',num2str(iCell)]);

                        % adding two P2P processors, one for desorption and one for
                        % adsorption. Two independent P2Ps are required because it
                        % is possible that one substance is currently absorber
                        % while another is desorbing which results in two different
                        % flow directions that can occur at the same time.
                                components.filter.components.Desorption_P2P(this.toStores.(sName), [sName, '_DesorptionProcessor_',num2str(iCell)], ['Absorber_',num2str(iCell),'.', sName, '_Absorber_Desorption_',num2str(iCell)], ['Flow_',num2str(iCell),'.', sName, '_Flow_Desorption_',num2str(iCell)]);
                        oP2P =  components.filter.components.Adsorption_P2P(this.toStores.(sName), [sName, '_AdsorptionProcessor_',num2str(iCell)], ['Flow_',num2str(iCell),'.', sName, '_Flow_Adsorption_',num2str(iCell)], ['Absorber_',num2str(iCell),'.', sName, '_Absorber_Adsorption_',num2str(iCell)], mfMassTransferCoefficient);
                        oP2P.iCell = iCell;
                        
                        sPipeName = ['Pipe_', sName, '_', num2str(iCell)];
                        components.pipe(this, sPipeName, 0.01, 0.02, 2e-3);
                        
                        % Each cell is connected to the next cell by a branch, the
                        % first and last cell also have the inlet and outlet branch
                        % attached that connects the filter to the parent system
                        %
                        % Note: Only the branches in between the cells of
                        % the currently generated filter are created here!
                        if iCell ~= 1
                            % branch between the current and the previous cell
                            matter.branch(this, [sName,'.','Outflow_',num2str(iCell-1)], {sPipeName}, [sName,'.','Inflow_',num2str(iCell)], [sName, 'Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                            
                        end
                        
                        % this factor times the mass flow^2 will decide the pressure
                        % loss. In this case the pressure loss will be 1 bar at a
                        % flowrate of 0.01 kg/s
                        this.tGeometry.(csTypes{iType}).mfFrictionFactor(iCell) = 5e7/iCellNumber;
                    
                    end
                    this.tGeometry.(csTypes{iType}).iCellNumber   = iCellNumber;
                    
                    % Adds a phase that actually contains mass to the 5A
                    % zeolith to correctly represent the air save etc.
                    if this.iCycleActive == 1 
                        if strcmp(sName, 'Zeolite5A_1')
                            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), fTemperatureFlow, 0, this.tAtmosphere.fPressure);

                            csFlowSubstances = fieldnames(cAirHelper{1});
                            for iK = 1:length(csFlowSubstances)
                                tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK});
                            end
                            matter.phases.gas_flow_node(this.toStores.(sName), 'MassBuffer', tfMassesFlow,fFlowVolume, fTemperatureFlow);
                        end
                        if strcmp(sName, 'Zeolite5A_2')
                            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_2']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0, 100);

                            csFlowSubstances = fieldnames(cAirHelper{1});
                            for iK = 1:length(csFlowSubstances)
                                tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK});
                            end
                            matter.phases.gas(this.toStores.(sName), 'MassBuffer', tfMassesFlow, fFlowVolume, this.TargetTemperature);
                        end
                    else
                        if strcmp(sName, 'Zeolite5A_2')
                            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_2']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), fTemperatureFlow, 0, this.tAtmosphere.fPressure);

                            csFlowSubstances = fieldnames(cAirHelper{1});
                            for iK = 1:length(csFlowSubstances)
                                tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK});
                            end
                            matter.phases.gas_flow_node(this.toStores.(sName), 'MassBuffer', tfMassesFlow, fFlowVolume, fTemperatureFlow);
                        end
                        if strcmp(sName, 'Zeolite5A_1')
                            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0, 100);

                            csFlowSubstances = fieldnames(cAirHelper{1});
                            for iK = 1:length(csFlowSubstances)
                                tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK});
                            end
                            matter.phases.gas(this.toStores.(sName), 'MassBuffer', tfMassesFlow, fFlowVolume, this.TargetTemperature);
                        end
                    end
                end
            end
            
            %% Definition of interface branches
            
            % Sylobead branches
            % Inlet of sylobed one (the outlet requires another interface
            % because the location from which the air is supplied is
            % different
            components.valve_closable(this, 'Cycle_One_InletValve', 0);
            
            matter.branch(this, 'Sylobead_1.Inflow_1', {'Cycle_One_InletValve'}, 'CDRA_Air_In_1', 'CDRA_Air_In_1');
            
            oFlowPhase = this.toStores.Sylobead_1.toPhases.Flow_1;
            matter.procs.exmes.gas(oFlowPhase, 'Outlet');
            
            components.valve_closable(this, 'Cycle_Two_OutletValve', 0);
            matter.branch(this, 'Sylobead_1.Outlet', {'Cycle_Two_OutletValve'}, 'CDRA_Air_Out_2', 'CDRA_Air_Out_2');
            
            iCellNumber = tInitialization.Sylobead.iCellNumber;
            matter.branch(this, ['Sylobead_1.Outflow_',num2str(iCellNumber)], {}, 'Zeolite13x_1.Inflow_1', 'Sylobead1_to_13x1');
            
            components.valve_closable(this, 'Cycle_Two_InletValve', 0);
            matter.branch(this, 'Sylobead_2.Inflow_1', {'Cycle_Two_InletValve'}, 'CDRA_Air_In_2', 'CDRA_Air_In_2');
            
            oFlowPhase = this.toStores.Sylobead_2.toPhases.Flow_1;
            matter.procs.exmes.gas(oFlowPhase, 'Outlet');
            components.valve_closable(this, 'Cycle_One_OutletValve', 0);
            matter.branch(this, 'Sylobead_2.Outlet', {'Cycle_One_OutletValve'}, 'CDRA_Air_Out_1', 'CDRA_Air_Out_1');
            
            iCellNumber = tInitialization.Sylobead.iCellNumber;
            matter.branch(this, ['Sylobead_2.Outflow_',num2str(iCellNumber)], {}, 'Zeolite13x_2.Inflow_1', 'Sylobead2_to_13x2');
            
            % Interface between 13x and 5A zeolite absorber beds 
            iCellNumber = tInitialization.Zeolite13x.iCellNumber;
            
            components.Temp_Dummy(this, 'PreCooler_5A1', 285, 1000);
            components.Temp_Dummy(this, 'PreCooler_5A2', 285, 1000);
            components.valve_closable(this, 'Valve_13x1_to_5A_1', 0);
            components.valve_closable(this, 'Valve_13x2_to_5A_2', 0);
            
            matter.branch(this, ['Zeolite13x_1.Outflow_',num2str(iCellNumber)], {'PreCooler_5A1', 'Valve_13x1_to_5A_1'}, 'Zeolite5A_1.Inflow_1', 'Zeolite13x1_to_5A1');
            matter.branch(this, ['Zeolite13x_2.Outflow_',num2str(iCellNumber)], {'PreCooler_5A2', 'Valve_13x2_to_5A_2'}, 'Zeolite5A_2.Inflow_1', 'Zeolite13x2_to_5A2');
            
            
            oFlowPhase = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCellNumber)]);
            matter.procs.exmes.gas(oFlowPhase, 'Inlet');
            
            oFlowPhase = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCellNumber)]);
            matter.procs.exmes.gas(oFlowPhase, 'Inlet');
            
            iCellNumber = tInitialization.Zeolite5A.iCellNumber;
            
            % Adds exmes to the buffer phases
            oMassBuffer1 = this.toStores.Zeolite5A_1.toPhases.MassBuffer;
            oMassBuffer2 = this.toStores.Zeolite5A_2.toPhases.MassBuffer;
            
            matter.procs.exmes.gas(oMassBuffer1, 'Buffer_Inlet');
            matter.procs.exmes.gas(oMassBuffer1, 'Buffer_Outlet');
            matter.procs.exmes.gas(oMassBuffer2, 'Buffer_Inlet');
            matter.procs.exmes.gas(oMassBuffer2, 'Buffer_Outlet');
            
            matter.branch(this, ['Zeolite5A_1.Outflow_',num2str(iCellNumber)], {}, 'Zeolite5A_1.Buffer_Inlet', 'Zeolite5A1_to_Buffer');
            matter.branch(this, ['Zeolite5A_2.Outflow_',num2str(iCellNumber)], {}, 'Zeolite5A_2.Buffer_Inlet', 'Zeolite5A2_to_Buffer');

            % Add valves
            components.valve_closable(this, 'Valve_5A_1_to_13x2', 0);
            components.valve_closable(this, 'Valve_5A_2_to_13x1', 0);
            
            matter.branch(this, 'Zeolite5A_1.Buffer_Outlet', {'Valve_5A_1_to_13x2'}, 'Zeolite13x_2.Inlet', 'Zeolite5A1_to_13x2');
            matter.branch(this, 'Zeolite5A_2.Buffer_Outlet', {'Valve_5A_2_to_13x1'}, 'Zeolite13x_1.Inlet', 'Zeolite5A2_to_13x1');
            
            % 5A to Vacuum connection branches
            matter.procs.exmes.gas(oMassBuffer1, 'Buffer_OutletVacuum');
            matter.procs.exmes.gas(oMassBuffer1, 'Buffer_OutletAirsave');
            matter.procs.exmes.gas(oMassBuffer2, 'Buffer_OutletVacuum');
            matter.procs.exmes.gas(oMassBuffer2, 'Buffer_OutletAirsave');
            
            components.valve_closable(this, 'Valve_5A_1_Airsave', 0);
            components.valve_closable(this, 'Valve_5A_1_Vacuum', 0);
            components.valve_closable(this, 'Valve_5A_2_Airsave', 0);
            components.valve_closable(this, 'Valve_5A_2_Vacuum', 0);
            components.fan_simple(this, 'AirsaveFanOne', 2*10^5);
            components.fan_simple(this, 'AirsaveFanTwo', 2*10^5);
            
            matter.branch(this, 'Zeolite5A_1.Buffer_OutletVacuum',  {'Valve_5A_1_Vacuum'}, 'CDRA_Vent_2', 'CDRA_Vent_2');
            matter.branch(this, 'Zeolite5A_1.Buffer_OutletAirsave', {'Valve_5A_1_Airsave', 'AirsaveFanOne'}, 'CDRA_AirSafe_2', 'CDRA_AirSafe_2');
            
            matter.branch(this, 'Zeolite5A_2.Buffer_OutletVacuum',  {'Valve_5A_2_Vacuum'}, 'CDRA_Vent_1', 'CDRA_Vent_1');
            matter.branch(this, 'Zeolite5A_2.Buffer_OutletAirsave', {'Valve_5A_2_Airsave', 'AirsaveFanTwo'}, 'CDRA_AirSafe_1', 'CDRA_AirSafe_1');
            
            this.tMassNetwork.aoActiveValvesCycleOne(1) = this.toProcsF2F.Cycle_One_InletValve;
            this.tMassNetwork.aoActiveValvesCycleOne(2) = this.toProcsF2F.Cycle_One_OutletValve;
            this.tMassNetwork.aoActiveValvesCycleOne(3) = this.toProcsF2F.Valve_13x1_to_5A_1;
            this.tMassNetwork.aoActiveValvesCycleOne(4) = this.toProcsF2F.Valve_5A_1_to_13x2;
            this.tMassNetwork.aoActiveValvesCycleOne(5) = this.toProcsF2F.Valve_5A_2_Airsave;
            
            this.tMassNetwork.aoActiveValvesCycleTwo(1) = this.toProcsF2F.Cycle_Two_InletValve;
            this.tMassNetwork.aoActiveValvesCycleTwo(2) = this.toProcsF2F.Cycle_Two_OutletValve;
            this.tMassNetwork.aoActiveValvesCycleTwo(3) = this.toProcsF2F.Valve_13x2_to_5A_2;
            this.tMassNetwork.aoActiveValvesCycleTwo(4) = this.toProcsF2F.Valve_5A_2_to_13x1;
            this.tMassNetwork.aoActiveValvesCycleTwo(5) = this.toProcsF2F.Valve_5A_1_Airsave;
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            csTypes = {'Zeolite13x', 'Sylobead', 'Zeolite5A'};
            mfConductivity(1) = this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.ThermalConductivity;
            mfConductivity(2) = this.oMT.ttxMatter.Sylobead_B125.ttxPhases.tSolid.ThermalConductivity;
            mfConductivity(3) = this.oMT.ttxMatter.Zeolite5A_RK38.ttxPhases.tSolid.ThermalConductivity;
            
            for iType = 1:3
                
                iCellNumber             = this.tGeometry.(csTypes{iType}).iCellNumber;
                fConductance            = mfConductivity(iType) * (this.tGeometry.(csTypes{iType}).fLength / iCellNumber);
                fFilterMaterialArea     = this.tGeometry.(csTypes{iType}).fCrossSection * this.tGeometry.(csTypes{iType}).rVoidFraction;
                fMaterialConductivity   = (fFilterMaterialArea * fConductance)/(this.tGeometry.Zeolite5A.fLength/iCellNumber);

                for iFilter = 1:2
                    sName               = [(csTypes{iType}),'_',num2str(iFilter)];
                    
                    for iCell = 1:iCellNumber
                        oAbsorberPhase  = this.toStores.(sName).toPhases.(['Absorber_',num2str(iCell)]);
                        oFlowPhase      = this.toStores.(sName).toPhases.(['Flow_',num2str(iCell)]);
                        
                        % in order to correctly create the thermal interface a heat
                        % source is added to each of the phases
                        oHeatSourceAbsorber = thermal.heatsource(['AbsorberHeatSource_',num2str(iCell)], 0);
                        oAbsorberPhase.oCapacity.addHeatSource(oHeatSourceAbsorber);
                        
                        oHeatSourceFlow = thermal.heatsource(['FlowHeatSource_',num2str(iCell)], 0);
                        oFlowPhase.oCapacity.addHeatSource(oHeatSourceFlow);
                        
                    end
                    
                    for iCell = 1:iCellNumber-1
                        oAbsorberPhase1      = this.toStores.(sName).toPhases.(['Absorber_',num2str(iCell)]);
                        oAbsorberPhase2      = this.toStores.(sName).toPhases.(['Absorber_',num2str(iCell+1)]);
                        
                        sPort1 = [sName, '_ConductionTo_', num2str(iCell+1)];
                        thermal.procs.exme(oAbsorberPhase1.oCapacity, sPort1);
                        sPort2 = [sName, '_ConductionFrom_', num2str(iCell)];
                        thermal.procs.exme(oAbsorberPhase2.oCapacity, sPort2);
                        
                        sConductorName = [sName, '_Material_Conductor_', num2str(iCell), '_', num2str(iCell+1)];
                        thermal.procs.conductors.conduction(this, sConductorName, fMaterialConductivity);
                        
                        thermal.branch(this, [sName,'.', sPort1], {sConductorName}, [sName,'.', sPort2], [sName, '_Conduction_Cell_', num2str(iCell), '_to_Cell_', num2str(iCell+1)]);
                    end
                end
            end
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            csBranches = fieldnames(this.toBranches);
            
            % Only the air in flows are manual branches, they will be used
            % to set the primary flowrate through CDRA
            iMultiBranch = 1;
            for iB = 1:length(csBranches)
                if regexp(csBranches{iB}, 'CDRA_Air_In')
                    solver.matter.manual.branch(this.toBranches.(csBranches{iB}));
                elseif regexp(csBranches{iB}, 'CDRA_AirSafe')
                    solver.matter.interval.branch(this.toBranches.(csBranches{iB}));
                elseif regexp(csBranches{iB}, 'CDRA_Vent')
                    solver.matter.interval.branch(this.toBranches.(csBranches{iB}));
                else
                    aoMultiSolverBranches(iMultiBranch) = this.toBranches.(csBranches{iB});
                    iMultiBranch = iMultiBranch + 1;
                end
            end
            
            solver.matter_multibranch.laminar_incompressible.branch(aoMultiSolverBranches(:), 'complex');
            
            csStores = fieldnames(this.toStores);
            % sets numerical properties for the phases of CDRA
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    if ~regexp(oPhase.sName, 'Flow')
                        arMaxChange = zeros(1,this.oMT.iSubstances);
                        arMaxChange(this.oMT.tiN2I.H2O) = 0.9;
                        arMaxChange(this.oMT.tiN2I.CO2) = 0.9;
                        tTimeStepProperties.arMaxChange = arMaxChange;
                        tTimeStepProperties.rMaxChange = 0.1;
                        tTimeStepProperties.fMaxStep = 60;
                        tTimeStepProperties.fMinStep = 1e-3;
                        
                        oPhase.setTimeStepProperties(tTimeStepProperties);
                    end
                end
            end
            
            % Initialize valve open/close state
            if this.iCycleActive
                for iValve = 1:length(this.tMassNetwork.aoActiveValvesCycleOne)
                    this.tMassNetwork.aoActiveValvesCycleOne(iValve).setOpen(true);
                    this.tMassNetwork.aoActiveValvesCycleTwo(iValve).setOpen(false);
                end
                this.toProcsF2F.Valve_5A_1_Vacuum.setOpen(false);
                this.toProcsF2F.Valve_5A_2_Vacuum.setOpen(false);
            else
                for iValve = 1:length(this.tMassNetwork.aoActiveValvesCycleOne)
                    this.tMassNetwork.aoActiveValvesCycleOne(iValve).setOpen(false);
                    this.tMassNetwork.aoActiveValvesCycleTwo(iValve).setOpen(true);
                end
                this.toProcsF2F.Valve_5A_1_Vacuum.setOpen(false);
                this.toProcsF2F.Valve_5A_2_Vacuum.setOpen(false);
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
        
        function setIfThermal(this, varargin)
            for iIF = 1:length(varargin)
                this.connectThermalIF(varargin{iIF},  varargin{iIF});
            end
        end
        
        function setReferencePhase(this, oCabinPhase)
            this.oAtmosphere = oCabinPhase;
            
            % assumed heat transfer cooefficient between CDRA and
            % atmosphere: 0.195
            
            % Well internal area assumed to be equal to external
            fArea5A         =     this.tGeometry.Zeolite5A.fCrossSection  * this.tGeometry.Zeolite5A.fLength    / this.tGeometry.Zeolite13x.iCellNumber;
            fAreaSylobead   =     this.tGeometry.Sylobead.fCrossSection   * this.tGeometry.Sylobead.fLength     / this.tGeometry.Sylobead.iCellNumber;
            fArea13x        =     this.tGeometry.Zeolite13x.fCrossSection * this.tGeometry.Zeolite13x.fLength   / this.tGeometry.Zeolite5A.iCellNumber;
            
            fThermalConductivity = this.oMT.calculateThermalConductivity(oCabinPhase);
            
            % Note: Transfer coefficient for the V-HAB thermal solver has
            % to be in W/K which means it is U*A or in this case
            % 1/sum(R_th): With R_th = s/(lambda * A)
            % Assumes                            50 cm of air and                                 10 cm of AL                     + 10cm of zeolite, conductivity values from ICES 2014-168 
            mfTransferCoefficient(1)   	= 1 / ( (0.5/(fThermalConductivity .* fArea13x))       + (0.1/(237 .* fArea13x))      + (0.1/(0.147 .* fArea13x)));
            mfTransferCoefficient(2)    = 1 / ( (0.5/(fThermalConductivity .* fAreaSylobead))  + (0.1/(237 .* fAreaSylobead)) + (0.1/(0.151 .* fAreaSylobead))); % asssumed conducitivty of 13x
            mfTransferCoefficient(3)   	= 1 / ( (0.5/(fThermalConductivity .* fArea5A))        + (0.1/(237 .* fArea5A))       + (0.1/(0.152 .* fArea5A)));
            
            csTypes = {'Zeolite13x', 'Sylobead', 'Zeolite5A'};
            % Since there are two filters of each type a for loop over the
            % two filters is used as well
            csInterfaces = cell(this.tGeometry.Zeolite13x.iCellNumber * 2 + this.tGeometry.Sylobead.iCellNumber * 2 + this.tGeometry.Zeolite5A.iCellNumber * 2);
            iIF = 1;
            for iType = 1:3
                for iFilter = 1:2
                    sName = [(csTypes{iType}),'_',num2str(iFilter)];
                    for iCell = 1:this.tGeometry.(csTypes{iType}).iCellNumber
                        
                        % Note that absorber and flow capacities are
                        % treated as one, and the flow is used in all
                        % instances (the temperature of the absorber is
                        % then simply set to the same temperature as the
                        % flow)
                        oAbsorberPhase      = this.toStores.(sName).toPhases.(['Absorber_',num2str(iCell)]);
                        
                        sPort1 = ['ConductionCabin_', num2str(iCell)];
                        thermal.procs.exme(oAbsorberPhase.oCapacity, sPort1);
                        
                        sPort2 = [sName, '_ConductionCDRA_', num2str(iCell+1)];
                        thermal.procs.exme(oCabinPhase.oCapacity, sPort2);
                        
                        sConductorName = [sName, '_Cabin_Conductor_', num2str(iCell), '_', num2str(iCell+1)];
                        thermal.procs.conductors.conduction(this, sConductorName, mfTransferCoefficient(iType));
                        
                        csInterfaces{iIF} = ['CDRA_ThermalIF_', sPort2];
                        thermal.branch(this, [sName,'.', sPort1], {sConductorName}, csInterfaces{iIF}, [sName, '_CabinConduction_Cell_', num2str(iCell)]);
                        
                        thermal.branch(oCabinPhase.oStore.oParent, csInterfaces{iIF}, {}, [oCabinPhase.oStore.sName, '.', sPort2], [sName, '_CabinConduction_Cell_', num2str(iCell)]);
                        iIF = iIF + 1;
                        
                    end
                end
            end
            
            this.setIfThermal(this, csInterfaces{:});
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            %% Cycle Change handling:
            % in case the cycle is switched a number of changes has to be
            % made to the flowrates, which are only necessary ONCE!
            % (setting the flowrates of all branches to zero, and only then
            % recalculate the filter)
            if this.oTimer.fTime > (this.tTimeProperties.fLastCycleSwitch + this.tTimeProperties.fCycleTime)
                
                if this.iCycleActive == 1
                    this.iCycleActive = 2;
                else
                    this.iCycleActive = 1;
                end
                
                if this.iCycleActive
                    for iValve = 1:length(this.tMassNetwork.aoActiveValvesCycleOne)
                        this.tMassNetwork.aoActiveValvesCycleOne(iValve).setOpen(true);
                        this.tMassNetwork.aoActiveValvesCycleTwo(iValve).setOpen(false);
                    end
                    this.toProcsF2F.Valve_5A_1_Vacuum.setOpen(false);
                    this.toProcsF2F.Valve_5A_2_Vacuum.setOpen(false);
                else
                    for iValve = 1:length(this.tMassNetwork.aoActiveValvesCycleOne)
                        this.tMassNetwork.aoActiveValvesCycleOne(iValve).setOpen(false);
                        this.tMassNetwork.aoActiveValvesCycleTwo(iValve).setOpen(true);
                    end
                    this.toProcsF2F.Valve_5A_1_Vacuum.setOpen(false);
                    this.toProcsF2F.Valve_5A_2_Vacuum.setOpen(false);
                end
                
                this.tTimeProperties.fLastCycleSwitch = this.oTimer.fTime;
            end
            
            % Change Airsave to vacuum desorption
            if this.oTimer.fTime > (this.tTimeProperties.fLastCycleSwitch + this.tTimeProperties.fAirSafeTime)
                
                this.toProcsF2F.Valve_5A_1_Airsave.setOpen(false);
                this.toProcsF2F.Valve_5A_2_Airsave.setOpen(false);
                
                this.toProcsF2F.Valve_5A_1_Vacuum.setOpen(true);
                this.toProcsF2F.Valve_5A_2_Vacuum.setOpen(true);
            end
        end
	end
end