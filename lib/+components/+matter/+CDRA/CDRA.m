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
        
        % Struct that allows the user to specify any value defined during
        % the constructor in the initialization struct. Please view to
        % constructor for more information on what field can be set!
        tInitializationOverwrite;
        
        fCurrentPowerConsumption = 0;
        
        % Array to store the branches that shall use the multi branch
        % solver will be stored in
        aoThermalMultiSolverBranches;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Boolean to turn CDRA on/off
        bActive = true;
        
        % Property to store the time that CDRA was turned off
        fCDRA_InactiveTime = 0;
        
        fLastExecutionTime = 0;
    end
    
    methods
        function this = CDRA(oParent, sName, tAtmosphere, tInitializationOverwrite, fTimeStep)
            if nargin < 5
                fTimeStep = 60;
            end
            this@vsys(oParent, sName, fTimeStep);
            
            if isempty(tAtmosphere)
                this.tAtmosphere.fTemperature = this.oMT.Standard.Temperature;
                this.tAtmosphere.fRelHumidity = 0.5;
                this.tAtmosphere.fPressure    = this.oMT.Standard.Pressure;
                this.tAtmosphere.fCO2Percent  = 0.0062;
            else
                this.tAtmosphere = tAtmosphere;
            end
            
            %Total time a cycle is active before switching to the other one.
            %This is also called half cycle sometimes with a full cycle beeing
            %considered the time it takes for both cycles to finish once. For
            %CDRA this is 144 minutes and for Vozdukh it is 30 minutes
            this.tTimeProperties.fCycleTime = 144*60;
            
            %The amount of time that is spent in the air safe mode at the
            %beginning of the CO2 desorption phase. During the air safe vacuum
            %pumps are used to pump the air (and some CO2) within the adsorber 
            %bed back into the cabin before the bed is connected to vacuum.
            this.tTimeProperties.fAirSafeTime = 10*60; % [s]
            this.tTimeProperties.fLastCycleSwitch = -10000;
            
            if nargin >= 4
                this.tInitializationOverwrite = tInitializationOverwrite;
            end
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
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
            this.tGeometry.Zeolite5A.fLength         =  18.68        *2.54/100;
            this.tGeometry.Sylobead.fLength          =  6.13         *2.54/100;
            this.tGeometry.Zeolite13x.fLength        = (5.881+0.84)  *2.54/100;
            
            %From ICES-2014-168 Table 2 e_sorbent
            this.tGeometry.Zeolite13x.rVoidFraction      = 0.457;
            this.tGeometry.Zeolite5A.rVoidFraction       = 0.445;
            this.tGeometry.Sylobead.rVoidFraction        = 0.348;
            
            % From ICES-2015-160 Table 1. Values from the table are per bed
            fMassZeolite13x     = 5.164;
            fMassSylobead       = 5.38; % + 0.632WS
            fMassZeolite5A      = 12.383;
            
            this.tGeometry.Zeolite13x.fAbsorberVolume        =   this.oMT.calculateDensity('solid', struct('Zeolite13x', 1))        * fMassZeolite13x;
            this.tGeometry.Sylobead.fAbsorberVolume          =   this.oMT.calculateDensity('solid', struct('Sylobead_B125', 1))     * fMassSylobead;
            this.tGeometry.Zeolite5A.fAbsorberVolume         =   this.oMT.calculateDensity('solid', struct('Zeolite5A', 1))         * fMassZeolite5A;
            
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
            fAluminiumMassPerBed = 5;
            fAluminiumMass13x = fAluminiumMassPerBed * (this.tGeometry.Zeolite13x.fLength / (this.tGeometry.Zeolite13x.fLength + this.tGeometry.Sylobead.fLength));
            
        	tInitialization.Zeolite13x.tfMassAbsorber  =   struct('Zeolite13x',fMassZeolite13x, 'Al', fAluminiumMass13x);
            tInitialization.Zeolite13x.fTemperature    =   281.25;
            
        	tInitialization.Sylobead.tfMassAbsorber  =   struct('Sylobead_B125',fMassSylobead, 'Al', fAluminiumMassPerBed - fAluminiumMass13x);
            tInitialization.Sylobead.fTemperature    =   281.25;
            
        	tInitialization.Zeolite5A.tfMassAbsorber  =   struct('Zeolite5A',fMassZeolite5A, 'Al', fAluminiumMassPerBed);
            tInitialization.Zeolite5A.fTemperature    =   281.25;
            
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
            
            % The initialization struct is now finished, so we overwrite
            % any value the user defined differently with the user defined
            % value!
            if ~isempty(this.tInitializationOverwrite)
                csFields = fieldnames(this.tInitializationOverwrite);
                for iField = 1:length(csFields)
                    % The subfields are the individual adsorber beds
                    csSubFields = fieldnames(this.tInitializationOverwrite.(csFields{iField}));
                    
                    for iSubfield = 1:length(csSubFields)
                        % now replace the value from the predefined init
                        % struct with the new value!
                        tInitialization.(csFields{iField}).(csSubFields{iSubfield}) = this.tInitializationOverwrite.(csFields{iField}).(csSubFields{iSubfield});
                    end
                end
            end
            
            % Aside from the absorber mass itself the initial values of
            % absorbed substances (like H2O and CO2) can be set. Since the
            % loading is not equal over the cells they have to be defined
            % for each cell (the values can obtained by running the
            % simulation for a longer time without startvalues and set them
            % according to the values once the simulation is repetetive)
            tStandardInit.Zeolite13x.mfInitialCO2             = zeros(tInitialization.Zeolite13x.iCellNumber,1);
            tStandardInit.Sylobead.mfInitialCO2               = zeros(tInitialization.Sylobead.iCellNumber,1);
            tStandardInit.Zeolite5A.mfInitialCO2              = zeros(tInitialization.Zeolite5A.iCellNumber,1);
            
            tStandardInit.Zeolite13x.mfInitialCO2Desorb       = zeros(tInitialization.Zeolite13x.iCellNumber,1);
            tStandardInit.Sylobead.mfInitialCO2Desorb         = zeros(tInitialization.Sylobead.iCellNumber,1);
            tStandardInit.Zeolite5A.mfInitialCO2Desorb        = zeros(tInitialization.Zeolite5A.iCellNumber,1);
        	
            % 0.16 is the value derived from running simulations, 5 was the
            % cell number during the simulation. The adsorbed in the
            % calculation can be reduced since it is both in the
            % denominator and numerator
            fLoadingFirstCell13x            = 5e-3 / tInitialization.Zeolite13x.iCellNumber;
            tStandardInit.Zeolite13x.mfInitialH2O          = fLoadingFirstCell13x : -fLoadingFirstCell13x/(tInitialization.Zeolite13x.iCellNumber - 1) : 0;
           	
            fLoadingFirstCellSylobeadAbsorb = 0.6 / tInitialization.Sylobead.iCellNumber;
            tStandardInit.Sylobead.mfInitialH2OAbsorb         = fLoadingFirstCellSylobeadAbsorb : -fLoadingFirstCellSylobeadAbsorb/(tInitialization.Sylobead.iCellNumber - 1) : 0;
            
            fLoadingFirstCellSylobeadDesorb = 0.01 / tInitialization.Sylobead.iCellNumber;
            tStandardInit.Sylobead.mfInitialH2ODesorb         = fLoadingFirstCellSylobeadDesorb : -fLoadingFirstCellSylobeadDesorb/(tInitialization.Sylobead.iCellNumber - 1) : 0;
            
%            tStandardInit.Zeolite13x.mfInitialH2O           = zeros(tInitialization.Zeolite13x.iCellNumber,1);
%            tStandardInit.Sylobead.mfInitialH2OAbsorb     	= zeros(tInitialization.Sylobead.iCellNumber,1);
%            tStandardInit.Sylobead.mfInitialH2ODesorb       = zeros(tInitialization.Sylobead.iCellNumber,1);

            tStandardInit.Zeolite5A.mfInitialH2O            = zeros(tInitialization.Zeolite5A.iCellNumber,1);

            
            csTypes = {'Zeolite13x', 'Sylobead', 'Zeolite5A'};
            % Check whether the standard definition for the initial masses
            % should be used or if the user specified anything (Note the
            % definition of this had to be after the init struct was
            % overwrite in case the cell numbers changed)
            for iType = 1:length(csTypes)
                if ~isfield(tInitialization.(csTypes{iType}), 'mfInitialCO2')
                    tInitialization.(csTypes{iType}).mfInitialCO2 = tStandardInit.(csTypes{iType}).mfInitialCO2;
                end
                
                if ~isfield(tInitialization.(csTypes{iType}), 'mfInitialCO2Desorb')
                    tInitialization.(csTypes{iType}).mfInitialCO2Desorb = tStandardInit.(csTypes{iType}).mfInitialCO2Desorb;
                end
                
                if strcmp(csTypes{iType}, 'Sylobead')
                    if ~isfield(tInitialization.(csTypes{iType}), 'mfInitialH2OAbsorb')
                        tInitialization.(csTypes{iType}).mfInitialH2OAbsorb = tStandardInit.(csTypes{iType}).mfInitialH2OAbsorb;
                    end
                    if ~isfield(tInitialization.(csTypes{iType}), 'mfInitialH2ODesorb')
                        tInitialization.(csTypes{iType}).mfInitialH2ODesorb = tStandardInit.(csTypes{iType}).mfInitialH2ODesorb;
                    end
                else
                    if ~isfield(tInitialization.(csTypes{iType}), 'mfInitialH2O')
                        tInitialization.(csTypes{iType}).mfInitialH2O = tStandardInit.(csTypes{iType}).mfInitialH2O;
                    end
                end
            end
            
            % this factor times the mass flow^2 will decide the pressure
            % loss.
            this.tGeometry.Zeolite13x.mfFrictionFactor  = 1e7   /tInitialization.Zeolite13x.iCellNumber * ones(tInitialization.Zeolite13x.iCellNumber,1);
            this.tGeometry.Sylobead.mfFrictionFactor  	= 1e7   /tInitialization.Sylobead.iCellNumber   * ones(tInitialization.Sylobead.iCellNumber,1);
            this.tGeometry.Zeolite5A.mfFrictionFactor   = 1e8   /tInitialization.Zeolite5A.iCellNumber  * ones(tInitialization.Zeolite5A.iCellNumber,1);
            
            % The surface area is required to calculate the thermal
            % exchange between the absorber and the gas flow. It is
            % calculated (approximatly) by assuming the asborbent is
            % spherical and using absorbent mass and the mass of each
            % sphere to calculate the number of spheres, then multiply this
            % with the area of each sphere!
            %            
            % Effective Particle Diameter De = 4*As/P = Dp for spheres
            % Sphericity = (6/De)/(As/V) = 1.0 for spheres
            % If the sorbent bed uses non-spherical pellets, then one must 
            % calculate both the Particle Effective Diameter and Sphericity 
            %
            % According to ICES-2014-168 the diameter of the pellets for
            % 13x is 2.19 mm --> the volume of each sphere is
            % 4/3*pi*(2.19/2)^3 = 5.5 mm3, while the area is 
            % 4*pi*(2.19/2)^2 = 15 mm2
            this.tGeometry.Zeolite13x.fAdsorbentParticleDiameter = 2.19e-3; % [m]
            this.tGeometry.Zeolite13x.fSphericity = 1.0; % 
            nSpheres_13x = (tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 5.5e-9));
            this.tGeometry.Zeolite13x.fAbsorberSurfaceArea      = (15e-6)*nSpheres_13x;
            
            % For Sylobead the average diameter is mentioned to be 2.25 mm:
            % 4/3*pi*(2.25/2)^3 = 5.96 mm3, while the area is 
            % 4*pi*(2.25/2)^2 = 15.9 mm2
            this.tGeometry.Sylobead.fAdsorbentParticleDiameter = 2.25e-3; % [m]
            this.tGeometry.Sylobead.fSphericity = 1.0; % spherical particles
            nSpheres_Sylobead = (tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 5.96e-9));
            this.tGeometry.Sylobead.fAbsorberSurfaceArea        = (15.9e-6)*nSpheres_Sylobead;
            
            % For 5a the average diameter is mentioned to be 2.21 mm:
            % 4/3*pi*(2.1/2)^3 = 4.85 mm3, while the area is 
            % 4*pi*(2.1/2)^2 = 13.85 mm2
            this.tGeometry.Zeolite5A.fAdsorbentParticleDiameter = 2.21e-3; % [m]
            this.tGeometry.Zeolite5A.fSphericity = 1.0; % spherical particles
            nSpheres_5A = (tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 4.85e-9));
            this.tGeometry.Zeolite5A.fAbsorberSurfaceArea       = (13.85e-6)*nSpheres_5A;
            
            % Define the standard values used for pipes
            fPipelength         = 1;
            fPipeDiameter       = 0.05;
            fFrictionFactor     = 2e-4;
            
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
                
                %define modified Ergun parameters
                tModifiedErgunInput.fAdsorbentParticleDiameter = this.tGeometry.(csTypes{iType}).fAdsorbentParticleDiameter;
                tModifiedErgunInput.fSphericity = this.tGeometry.(csTypes{iType}).fSphericity;
                tModifiedErgunInput.fCellLength = this.tGeometry.(csTypes{iType}).fLength/iCellNumber;
                tModifiedErgunInput.rVoidFraction = this.tGeometry.(csTypes{iType}).rVoidFraction;
                tModifiedErgunInput.fCrossSection = this.tGeometry.(csTypes{iType}).fCrossSection;
                
                % Adds two stores (filter stores), containing sylobead
                % A special filter store has to be used for the filter to
                % prevent the gas phase volume from beeing overwritten since
                % more than one gas phase is used to implement several cells
                matter.store(this, [(csTypes{iType}), '_1'], (2*fFlowVolume + fAbsorberVolume));
                matter.store(this, [(csTypes{iType}), '_2'], (2*fFlowVolume + fAbsorberVolume));
                
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
                            if strcmp(sName, 'Zeolite5A_2')
                                tfMassesAbsorber.CO2 = tInitialization.(csTypes{iType}).mfInitialCO2Desorb(iCell);
                            else
                                tfMassesAbsorber.CO2 = tInitialization.(csTypes{iType}).mfInitialCO2(iCell);
                            end
                        else
                            if strcmp(sName, 'Sylobead_1')
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2ODesorb(iCell);
                            elseif strcmp(sName, 'Sylobead_2')
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2OAbsorb(iCell);
                            else
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2O(iCell);
                            end
                            if strcmp(sName, 'Zeolite5A_1')
                                tfMassesAbsorber.CO2 = tInitialization.(csTypes{iType}).mfInitialCO2Desorb(iCell);
                            else
                                tfMassesAbsorber.CO2 = tInitialization.(csTypes{iType}).mfInitialCO2(iCell);
                            end
                        end
                        
                        if this.iCycleActive == 1 
                            if ~strcmp(sName, 'Zeolite5A_2')
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), fTemperatureFlow, 0, this.tAtmosphere.fPressure);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber, fTemperatureAbsorber, fPressure);
                                oFlowPhase = matter.phases.flow.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), fTemperatureFlow);
                                
                            else
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0, 100);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber, this.TargetTemperature, fPressure);
                                oFlowPhase =  matter.phases.flow.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), this.TargetTemperature);
                            end
                        else
                            if ~strcmp(sName, 'Zeolite5A_1')
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), fTemperatureFlow, 0, this.tAtmosphere.fPressure);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber, fTemperatureAbsorber, fPressure);
                                oFlowPhase =  matter.phases.flow.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), fTemperatureFlow);
                            else
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0, 100);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber, this.TargetTemperature, fPressure);
                                oFlowPhase =  matter.phases.flow.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), this.TargetTemperature);
                            end
                        end
                        % The absorber material thermal handling uses a
                        % multi branch solver to allow for larger time
                        % steps
                        % oFilterPhase.makeThermalNetworkNode();
                        
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
                                components.matter.CDRA.components.Desorption_P2P(this.toStores.(sName), ['DesorptionProcessor_',num2str(iCell)], ['Absorber_',num2str(iCell),'.', sName, '_Absorber_Desorption_',num2str(iCell)], ['Flow_',num2str(iCell),'.', sName, '_Flow_Desorption_',num2str(iCell)]);
                        oP2P =  components.matter.CDRA.components.Adsorption_P2P(this.toStores.(sName), ['AdsorptionProcessor_',num2str(iCell)], ['Flow_',num2str(iCell),'.', sName, '_Flow_Adsorption_',num2str(iCell)], ['Absorber_',num2str(iCell),'.', sName, '_Absorber_Adsorption_',num2str(iCell)], mfMassTransferCoefficient);
                        oP2P.iCell = iCell;
                        
                        % Each cell is connected to the next cell by a branch, the
                        % first and last cell also have the inlet and outlet branch
                        % attached that connects the filter to the parent system
                        %
                        % Note: Only the branches in between the cells of
                        % the currently generated filter are created here!
                        if iCell ~= 1
                            %components.matter.CDRA.components.Filter_F2F(this, [sName, '_FrictionProc_',num2str(iCell)], this.tGeometry.(csTypes{iType}).mfFrictionFactor(iCell));
                            components.matter.CDRA.components.ModifiedErgun_F2F(this, [sName, '_FrictionProc_',num2str(iCell)], tModifiedErgunInput);
                            % branch between the current and the previous cell
                            oBranch = matter.branch(this, [sName,'.','Outflow_',num2str(iCell-1)], {[sName, '_FrictionProc_',num2str(iCell)]}, [sName,'.','Inflow_',num2str(iCell)], [sName, 'Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                            
                            this.tMassNetwork.(['InternalBranches_', sName])(iCell-1) = oBranch;
                        end
                    end
                    this.tGeometry.(csTypes{iType}).iCellNumber   = iCellNumber;
                    
                    if strcmp(sName, 'Zeolite5A_2') || strcmp(sName, 'Zeolite5A_1')
                        % Adds a phase to the 5A Buffer to enable the air
                        % save fan (multi branch solver requires a gas flow
                        % node on each side of the fan)
                        for iK = 1:length(csFlowSubstances)
                            tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK});
                        end

                        if (this.iCycleActive == 1 && strcmp(sName, 'Zeolite5A_2')) || (this.iCycleActive == 2 && strcmp(sName, 'Zeolite5A_1'))
                            oAirSaveFlow = matter.phases.flow.gas(this.toStores.(sName), 'AirSaveFlow', tfMassesFlow,fFlowVolume, this.TargetTemperature);
                        else
                            oAirSaveFlow = matter.phases.flow.gas(this.toStores.(sName), 'AirSaveFlow', tfMassesFlow,fFlowVolume, fTemperatureFlow);
                        end
                        
                        matter.procs.exmes.gas(oAirSaveFlow, 'AirSave_Inlet');
                        matter.procs.exmes.gas(oAirSaveFlow, 'AirSave_Outlet');
                    end
                end
            end
            
            % Definition of Interface stores and phases
            matter.store(this, 'AirInlet', 1e-6);
            oAirInlet = this.toStores.AirInlet.createPhase('air', 'flow', 1e-6, 293, 0.5, 1e5);
            
            matter.store(this, 'AirOutlet', 1e-6);
            oAirOutlet = this.toStores.AirOutlet.createPhase('air', 'flow', 1e-6, 293, 0.5, 1e5);
            
            matter.store(this, 'VacuumInterface', 1e-6);
            oVacuumInterface = this.toStores.VacuumInterface.createPhase('air', 'flow', 1e-6, 293, 0.5, 1e5);
            
            matter.store(this, 'DessicantThreeWayValve', 1e-6);
            oDessicantThreeWay = this.toStores.DessicantThreeWayValve.createPhase('air', 'flow', 1e-6, 293, 0.5, 1e5);
            
            matter.store(this, 'AdsorberThreeWayValve', 1e-6);
            oAdsorberThreeWay = this.toStores.AdsorberThreeWayValve.createPhase('air', 'flow', 1e-6, 293, 0.5, 1e5);
            
            matter.store(this, 'FanStore', 1e-6);
            oFanPhase = this.toStores.FanStore.createPhase('air', 'flow', 1e-6, 293, 0.5, 1e5);
            
            %% Definition of interface branches
            
            % Sylobead branches
            % Inlet of sylobed one (the outlet requires another interface
            % because the location from which the air is supplied is
            % different
            fInterfacePipeLength = 0.1;
            
            components.matter.pipe(this, 'InletPipe', fInterfacePipeLength, fPipeDiameter, fFrictionFactor);
            sBranchName = 'CDRA_Air_In';
            oBranch = matter.branch(this, oAirInlet, {'InletPipe'}, 'CDRA_Air_In', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            components.matter.pipe(this, 'OutletPipe', fInterfacePipeLength, fPipeDiameter, fFrictionFactor);
            components.matter.CDRA.components.Filter_F2F(this, 'OutletFilter');
            sBranchName = 'CDRA_Air_Out';
            oBranch = matter.branch(this, oAirOutlet, {'OutletPipe', 'OutletFilter'}, 'CDRA_Air_Out', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            components.matter.CDRA.components.CDRA_VacuumPipe(this, 'VacuumPipe', fInterfacePipeLength, fPipeDiameter, fFrictionFactor);
            sBranchName = 'CDRA_Vacuum';
            oBranch = matter.branch(this, oVacuumInterface, {'VacuumPipe'}, 'CDRA_Vacuum', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            
            components.matter.valve(this, 'Cycle_One_InletValve', 0);
            components.matter.pipe(this, 'Cycle_One_InletPipe', fPipelength, fPipeDiameter, fFrictionFactor);
            
            sBranchName = 'CDRA_Air_In_1';
            oBranch = matter.branch(this, oAirInlet, {'Cycle_One_InletValve', 'Cycle_One_InletPipe'}, 'Sylobead_1.Inflow_1', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            oFlowPhase = this.toStores.Sylobead_1.toPhases.Flow_1;
            matter.procs.exmes.gas(oFlowPhase, 'Outlet');
            
            components.matter.valve(this, 'Cycle_Two_OutletValve', 0);
            components.matter.pipe(this, 'Cycle_Two_OutletPipe', fPipelength, fPipeDiameter, fFrictionFactor);
            
            sBranchName = 'CDRA_Air_Out_2';
            oBranch = matter.branch(this, 'Sylobead_1.Outlet', {'Cycle_Two_OutletValve', 'Cycle_Two_OutletPipe'}, oAirOutlet, sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
             
            components.matter.pipe(this, 'Sylobead_1_to_13x1_Pipe', fPipelength, fPipeDiameter, fFrictionFactor);
            
            sBranchName = 'Sylobead1_to_13x1';
            oBranch = matter.branch(this, ['Sylobead_1.Outflow_', num2str(this.tGeometry.Sylobead.iCellNumber)], {'Sylobead_1_to_13x1_Pipe'}, 'Zeolite13x_1.Inflow_1', sBranchName);
            this.tMassNetwork.InternalBranches_Sylobead_1(end+1) = oBranch;
            
            components.matter.valve(this, 'Cycle_Two_InletValve', 0);
            components.matter.pipe(this, 'Cycle_Two_InletPipe', fPipelength, fPipeDiameter, fFrictionFactor);
            
            sBranchName = 'CDRA_Air_In_2';
            oBranch = matter.branch(this, oAirInlet, {'Cycle_Two_InletValve', 'Cycle_Two_InletPipe'}, 'Sylobead_2.Inflow_1', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            oFlowPhase = this.toStores.Sylobead_2.toPhases.Flow_1;
            matter.procs.exmes.gas(oFlowPhase, 'Outlet');
            components.matter.valve(this, 'Cycle_One_OutletValve', 0);
            components.matter.pipe(this, 'Cycle_One_OutletPipe', fPipelength, fPipeDiameter, fFrictionFactor);
            
            sBranchName = 'CDRA_Air_Out_1';
            oBranch = matter.branch(this, 'Sylobead_2.Outlet', {'Cycle_One_OutletValve', 'Cycle_One_OutletPipe'}, oAirOutlet, sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            components.matter.pipe(this, 'Sylobead_2_to_13x2_Pipe', fPipelength, fPipeDiameter, fFrictionFactor);
            
            sBranchName = 'Sylobead2_to_13x2';
            oBranch = matter.branch(this, ['Sylobead_2.Outflow_', num2str(this.tGeometry.Sylobead.iCellNumber)], {'Sylobead_2_to_13x2_Pipe'}, 'Zeolite13x_2.Inflow_1', sBranchName);
            this.tMassNetwork.InternalBranches_Sylobead_2(end+1) = oBranch;
            
            %% Interface between 13x and 5A zeolite absorber beds
            components.matter.Temp_Dummy(this, 'PreCooler', 281, 1000);
            components.matter.valve(this, 'Valve_13x1_to_Fan', 0);
            components.matter.valve(this, 'Valve_13x2_to_Fan', 0);
            components.matter.pipe(this, 'Pipe_13x_to_5A', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.CDRA.components.CDRA_Fan(this, 'CDRA_Fan');
            
            sBranchName = 'Zeolite13x1_to_5A1';
            oBranch = matter.branch(this, ['Zeolite13x_1.Outflow_', num2str(this.tGeometry.Zeolite13x.iCellNumber)], {'Valve_13x1_to_Fan'}, oDessicantThreeWay, sBranchName);
            this.tMassNetwork.InternalBranches_Zeolite13x_1(end+1) = oBranch;
            
            sBranchName = 'Zeolite13x2_to_5A2';
            oBranch = matter.branch(this, ['Zeolite13x_2.Outflow_', num2str(this.tGeometry.Zeolite13x.iCellNumber)], {'Valve_13x2_to_Fan'}, oDessicantThreeWay, sBranchName);
            this.tMassNetwork.InternalBranches_Zeolite13x_2(end+1) = oBranch;
            
            
            sBranchName = 'CDRA_Fan';
            oBranch = matter.branch(this, oDessicantThreeWay, {'CDRA_Fan'}, oFanPhase, sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            sBranchName = 'CDRA_PostFan';
            oBranch = matter.branch(this, oFanPhase, {'PreCooler', 'Pipe_13x_to_5A'}, oAdsorberThreeWay, sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            components.matter.valve(this, 'Valve_Fan_to_5A_1', 0);
            components.matter.valve(this, 'Valve_Fan_to_5A_2', 0);
            
            sBranchName = 'Fan_to_5A_1';
            oBranch = matter.branch(this, oAdsorberThreeWay , {'Valve_Fan_to_5A_1'}, 'Zeolite5A_1.Inflow_1', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            sBranchName = 'Fan_to_5A_2';
            oBranch = matter.branch(this, oAdsorberThreeWay , {'Valve_Fan_to_5A_2'}, 'Zeolite5A_2.Inflow_1', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            oFlowPhase = this.toStores.Zeolite13x_1.toPhases.(['Flow_', num2str(this.tGeometry.Zeolite13x.iCellNumber)]);
            matter.procs.exmes.gas(oFlowPhase, 'Inlet_From_5A2');
            oFlowPhase = this.toStores.Zeolite13x_2.toPhases.(['Flow_', num2str(this.tGeometry.Zeolite13x.iCellNumber)]);
            matter.procs.exmes.gas(oFlowPhase, 'Inlet_From_5A1');
            
            % Add valves
            components.matter.valve(this, 'Valve_5A_1_to_13x2', 0);
            components.matter.valve(this, 'Valve_5A_2_to_13x1', 0);
            components.matter.pipe(this, 'Pipe_5A_1_to_13x2', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_5A_2_to_13x1', fPipelength, fPipeDiameter, fFrictionFactor);
            
            this.tGeometry.Zeolite5A.iCellNumber   = iCellNumber;
            
            sBranchName = 'Zeolite5A1_to_13x2';
            oBranch = matter.branch(this, ['Zeolite5A_1.Outflow_',num2str(iCellNumber)] , {'Pipe_5A_1_to_13x2', 'Valve_5A_1_to_13x2'}, 'Zeolite13x_2.Inlet_From_5A1', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            sBranchName = 'Zeolite5A2_to_13x1';
            oBranch = matter.branch(this, ['Zeolite5A_2.Outflow_',num2str(iCellNumber)] , {'Pipe_5A_2_to_13x1', 'Valve_5A_2_to_13x1'}, 'Zeolite13x_1.Inlet_From_5A2', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            
            %% 5A to Vacuum connection branches
            oFlow1 = this.toStores.Zeolite5A_1.toPhases.Flow_1;
            oFlow2 = this.toStores.Zeolite5A_2.toPhases.Flow_1;

            matter.procs.exmes.gas(oFlow1, 'OutletVacuum');
            matter.procs.exmes.gas(oFlow1, 'OutletAirsave');
            matter.procs.exmes.gas(oFlow2, 'OutletVacuum');
            matter.procs.exmes.gas(oFlow2, 'OutletAirsave');
            
            components.matter.valve(this, 'Valve_5A_1_Airsave', 0);
            components.matter.valve(this, 'Valve_5A_1_Vacuum', 0);
            components.matter.valve(this, 'Valve_5A_2_Airsave', 0);
            components.matter.valve(this, 'Valve_5A_2_Vacuum', 0);
            components.matter.fan_simple(this, 'AirsaveFanOne', 1*10^5);
            components.matter.fan_simple(this, 'AirsaveFanTwo', 1*10^5);
            components.matter.CDRA.components.CDRA_VacuumPipe(this, 'Pipe_5A_1_Vacuum', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.CDRA.components.CDRA_VacuumPipe(this, 'Pipe_5A_2_Vacuum', fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_5A_1_Airsave', fPipelength, 0.01, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_5A_2_Airsave', fPipelength, 0.01, fFrictionFactor);
            
            sBranchName = 'CDRA_Vent_1';
            oBranch = matter.branch(this, 'Zeolite5A_2.OutletVacuum',  {'Valve_5A_2_Vacuum', 'Pipe_5A_2_Vacuum'}, oVacuumInterface, sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            sBranchName = 'CDRA_AirSafe_1_Fan';
            oBranch = matter.branch(this, 'Zeolite5A_2.OutletAirsave', {'AirsaveFanTwo'}, 'Zeolite5A_2.AirSave_Inlet', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            sBranchName = 'CDRA_AirSafe_1';
            oBranch = matter.branch(this, 'Zeolite5A_2.AirSave_Outlet', {'Valve_5A_2_Airsave', 'Pipe_5A_2_Airsave'}, oAirOutlet, sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            sBranchName = 'CDRA_Vent_2';
            oBranch = matter.branch(this, 'Zeolite5A_1.OutletVacuum',  {'Valve_5A_1_Vacuum', 'Pipe_5A_1_Vacuum'}, oVacuumInterface, sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            
            sBranchName = 'CDRA_AirSafe_2_Fan';
            oBranch = matter.branch(this, 'Zeolite5A_1.OutletAirsave', {'AirsaveFanOne'}, 'Zeolite5A_1.AirSave_Inlet', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            sBranchName = 'CDRA_AirSafe_2';
            oBranch = matter.branch(this, 'Zeolite5A_1.AirSave_Outlet', {'Valve_5A_1_Airsave', 'Pipe_5A_1_Airsave'}, oAirOutlet, sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            this.tMassNetwork.aoActiveValvesCycleOne(1) = this.toProcsF2F.Cycle_One_InletValve;
            this.tMassNetwork.aoActiveValvesCycleOne(2) = this.toProcsF2F.Cycle_One_OutletValve;
            this.tMassNetwork.aoActiveValvesCycleOne(3) = this.toProcsF2F.Valve_13x1_to_Fan;
            this.tMassNetwork.aoActiveValvesCycleOne(4) = this.toProcsF2F.Valve_Fan_to_5A_1;
            this.tMassNetwork.aoActiveValvesCycleOne(5) = this.toProcsF2F.Valve_5A_1_to_13x2;
            this.tMassNetwork.aoActiveValvesCycleOne(6) = this.toProcsF2F.Valve_5A_2_Airsave;
            
            this.tMassNetwork.aoActiveValvesCycleTwo(1) = this.toProcsF2F.Cycle_Two_InletValve;
            this.tMassNetwork.aoActiveValvesCycleTwo(2) = this.toProcsF2F.Cycle_Two_OutletValve;
            this.tMassNetwork.aoActiveValvesCycleTwo(3) = this.toProcsF2F.Valve_13x2_to_Fan;
            this.tMassNetwork.aoActiveValvesCycleTwo(4) = this.toProcsF2F.Valve_Fan_to_5A_2;
            this.tMassNetwork.aoActiveValvesCycleTwo(5) = this.toProcsF2F.Valve_5A_2_to_13x1;
            this.tMassNetwork.aoActiveValvesCycleTwo(6) = this.toProcsF2F.Valve_5A_1_Airsave;
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            csTypes = {'Zeolite13x', 'Sylobead', 'Zeolite5A'};
            mfConductivity(1) = this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.ThermalConductivity;
            mfConductivity(2) = this.oMT.ttxMatter.Sylobead_B125.ttxPhases.tSolid.ThermalConductivity;
            mfConductivity(3) = this.oMT.ttxMatter.Zeolite5A_RK38.ttxPhases.tSolid.ThermalConductivity;
            
            iMultiSolverBranch = 1;
            this.aoThermalMultiSolverBranches = thermal.branch.empty();
            
            for iType = 1:3
                
                iCellNumber             = this.tGeometry.(csTypes{iType}).iCellNumber;
                fConductance            = mfConductivity(iType) * (this.tGeometry.(csTypes{iType}).fLength / iCellNumber);
                fFilterMaterialArea     = this.tGeometry.(csTypes{iType}).fCrossSection * (1-this.tGeometry.(csTypes{iType}).rVoidFraction);
                fMaterialResistivity   = (this.tGeometry.(csTypes{iType}).fLength/iCellNumber) / (fFilterMaterialArea * fConductance);
                
                for iFilter = 1:2
                    sName               = [(csTypes{iType}),'_',num2str(iFilter)];

                    for iCell = 1:iCellNumber
                        oAbsorberPhase  = this.toStores.(sName).toPhases.(['Absorber_',num2str(iCell)]);
                        oFlowPhase      = this.toStores.(sName).toPhases.(['Flow_',num2str(iCell)]);
                        
                        % in order to correctly create the thermal interface a heat
                        % source is added to each of the phases
                        oHeatSourceAbsorber = thermal.heatsource(['AbsorberHeatSource_',num2str(iCell)], 0);
                        oAbsorberPhase.oCapacity.addHeatSource(oHeatSourceAbsorber);
                        
                        oHeatSourceAbsorber = thermal.heatsource(['AbsorberHeater_',num2str(iCell)], 0);
                        oAbsorberPhase.oCapacity.addHeatSource(oHeatSourceAbsorber);
                        
                        % Add a thermal branch of infinite conduction to
                        % represent the convective heat transfer
                        thermal.procs.exme(oAbsorberPhase.oCapacity,  ['Solid_InfiniteConductor_', num2str(iCell)]);
                        thermal.procs.exme(oFlowPhase.oCapacity,    ['Flow_InfiniteConductor_', num2str(iCell)]);
                        thermal.branch(this, [sName,'.Flow_InfiniteConductor_', num2str(iCell)], {}, [sName,'.Solid_InfiniteConductor_', num2str(iCell)], [sName, '_Infinite_Conductor', num2str(iCell)]);
                                            
                    end
                    
                    for iCell = 1:iCellNumber-1
                        oAbsorberPhase1      = this.toStores.(sName).toPhases.(['Absorber_',num2str(iCell)]);
                        oAbsorberPhase2      = this.toStores.(sName).toPhases.(['Absorber_',num2str(iCell+1)]);
                        
                        sPort1 = [sName, '_ConductionTo_', num2str(iCell+1)];
                        thermal.procs.exme(oAbsorberPhase1.oCapacity, sPort1);
                        sPort2 = [sName, '_ConductionFrom_', num2str(iCell)];
                        thermal.procs.exme(oAbsorberPhase2.oCapacity, sPort2);
                        
                        sConductorName = [sName, '_Material_Conductor_', num2str(iCell), '_', num2str(iCell+1)];
                        thermal.procs.conductors.conductive(this, sConductorName, fMaterialResistivity);
                        
                        this.aoThermalMultiSolverBranches(iMultiSolverBranch) = thermal.branch(this, [sName,'.', sPort1], {sConductorName}, [sName,'.', sPort2], [sName, '_Conduction_Cell_', num2str(iCell), '_to_Cell_', num2str(iCell+1)]);
                        iMultiSolverBranch = iMultiSolverBranch + 1;
                    end
                end
            end
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Outcommented code can be used to set a multi solver for each
            % bed specifically, which helps with debugging. Additional the
            % full system results in close to singular matrix, which might
            % lead to issues.
            tSolverProperties.fMaxError = 1e-4;
            tSolverProperties.iMaxIterations = 1000;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 200;
            
            oSolver = solver.matter_multibranch.iterative.branch(this.aoBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            solver.thermal.multi_branch.basic.branch(this.aoThermalMultiSolverBranches);
            
            csStores = fieldnames(this.toStores);
            % sets numerical properties for the phases of CDRA
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    if ~isempty(regexp(oPhase.sName, 'Absorber', 'once'))
                        tTimeStepProperties = struct();
                        arMaxChange = zeros(1,this.oMT.iSubstances);
                        arMaxChange(this.oMT.tiN2I.H2O) = 0.2;
                        arMaxChange(this.oMT.tiN2I.CO2) = 0.2;
                        tTimeStepProperties.arMaxChange = arMaxChange;
                        tTimeStepProperties.rMaxChange = 0.1;
                        tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                        tTimeStepProperties.fMinStep = this.fTimeStep * 0.5;
                        
                        oPhase.setTimeStepProperties(tTimeStepProperties);
                        
                        tTimeStepProperties = struct();
                        tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                        tTimeStepProperties.rMaxChange = 0.1;
                        tTimeStepProperties.fMaxTemperatureChange = 10;
                        tTimeStepProperties.fMinimumTemperatureForTimeStep = 275;
                        oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                        
                        % The absorber phase/capacity updates also trigger a solver
                        % update. The capacity is necessary because the
                        % temperature influences the adsorption process and
                        % otherwise unrealistically low temperatures are
                        % possible
                        oPhase.bind('update_post', @oSolver.registerUpdate);
                        oPhase.oCapacity.bind('updateTemperature_post', @oSolver.registerUpdate);
                        
                    else
                        tTimeStepProperties = struct();
                        tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                        oPhase.setTimeStepProperties(tTimeStepProperties);
                    end
                end
            end
            
            % Initialize valve open/close state
            if this.iCycleActive == 1
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
            
            
            this.setThermalSolvers();
        end           
        
        %% Function to connect the system and subsystem level branches with each other
        function setIfFlows(this, CDRA_Air_In, CDRA_Air_Out, CDRA_Vacuum)
            if nargin == 4
                this.connectIF('CDRA_Air_In' ,  CDRA_Air_In);
                this.connectIF('CDRA_Air_Out',  CDRA_Air_Out);
                this.connectIF('CDRA_Vacuum',   CDRA_Vacuum);
            else
                error('CDRA Subsystem was given a wrong number of interfaces')
            end
        end
        
        function setIfThermal(this, varargin)
            for iIF = 1:length(varargin)
                this.connectThermalIF(varargin{iIF},  varargin{iIF});
            end
        end
        
        function setReferencePhase(this, oCabinPhase, iCDRA)
            this.oAtmosphere = oCabinPhase;
            
            if nargin < 3
                iCDRA = 1;
            end
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
            mfResistance(1,1)   	= 0.5/(fThermalConductivity .* fArea13x);
            mfResistance(1,2)       = 0.1/(237 .* fArea13x);
            mfResistance(1,3)       = 0.1/(0.147 .* fArea13x);
            
            mfResistance(2,1)       = 0.5/(fThermalConductivity .* fAreaSylobead);
            mfResistance(2,2)       = 0.1/(237 .* fAreaSylobead);
            mfResistance(2,3)       = 0.1/(0.151 .* fAreaSylobead); % asssumed conducitivty of 13x
            
            mfResistance(3,1)       = 0.5/(fThermalConductivity .* fArea5A);
            mfResistance(3,2)       = 0.1/(237 .* fArea5A);
            mfResistance(3,3)       = 0.1/(0.152 .* fArea5A);
            
            csTypes = {'Zeolite13x', 'Sylobead', 'Zeolite5A'};
            % Since there are two filters of each type a for loop over the
            % two filters is used as well
            csThermalInterfaces = cell(this.tGeometry.Zeolite13x.iCellNumber * 2 + this.tGeometry.Sylobead.iCellNumber * 2 + this.tGeometry.Zeolite5A.iCellNumber * 2,1);
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
                        oAbsorberPhase = this.toStores.(sName).toPhases.(['Absorber_',num2str(iCell)]);
                        
                        sPort1 = ['ConductionCabin_', num2str(iCell)];
                        thermal.procs.exme(oAbsorberPhase.oCapacity, sPort1);
                        
                        sPort2 = [sName, '_ConductionCDRA_', num2str(iCell+1)];
                        thermal.procs.exme(oCabinPhase.oCapacity, sPort2);
                        
                        sConductorName1 = [sName, '_Cabin_Conductor_Air_', num2str(iCell), '_', num2str(iCell+1)];
                        thermal.procs.conductors.conductive(this, sConductorName1, mfResistance(iType, 1));
                        
                        sConductorName2 = [sName, '_Cabin_Conductor_Al_', num2str(iCell), '_', num2str(iCell+1)];
                        thermal.procs.conductors.conductive(this, sConductorName2, mfResistance(iType, 2));
                        
                        sConductorName3 = [sName, '_Cabin_Conductor_Adsorber_', num2str(iCell), '_', num2str(iCell+1)];
                        thermal.procs.conductors.conductive(this, sConductorName3, mfResistance(iType, 3));
                        
                        csThermalInterfaces{iIF} = ['CDRA', num2str(iCDRA),'_ThermalIF_', sPort2];
                        thermal.branch(this, [sName,'.', sPort1], {sConductorName1, sConductorName2, sConductorName3}, csThermalInterfaces{iIF}, [sName, '_CabinConduction_Cell_', num2str(iCell)]);
                        
                        thermal.branch(this.oParent, csThermalInterfaces{iIF}, {}, [oCabinPhase.oStore.sName,'.', sPort2], ['CDRA', num2str(iCDRA),'_', sName, '_CabinConduction_Cell_', num2str(iCell)]);
                        
                        iIF = iIF + 1;
                        
                    end
                end
            end
            
            this.setIfThermal(csThermalInterfaces{:});
        end
        
        function setActive(this, bActive)
            % This can be used to turn CDRA off. However, note that you
            % have to turn off the supply air as well, as that is not
            % handled by CDRA internally but in the ISS configuration is
            % done by the CCAA. If you use a CCAA with CDRA you can set the
            % property fCDRA_FlowRate of the connected CCAA to 0. You have
            % to do so in the parent system of both CCAA and CDRA and it
            % might look like this:
            % this.toChildren.MyCCAAName.fCDRA_FlowRate = 0;
            
            if ~bActive
                % Turn heaters off
                for iBed = 1:2
                    for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                        oCapacity = this.toStores.(['Zeolite5A_', num2str(iBed)]).toPhases.(['Absorber_', num2str(iCell)]).oCapacity;
                        oCapacity.toHeatSources.(['AbsorberHeater_', num2str(iCell)]).setHeatFlow(0);
                    end
                end
            end
            
            this.bActive = bActive;
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            if this.bActive
                fCDRA_OperationTime = this.oTimer.fTime - this.fCDRA_InactiveTime;

                %% Cycle Change handling:
                % in case the cycle is switched a number of changes has to be
                % made to the flowrates, which are only necessary ONCE!
                % (setting the flowrates of all branches to zero, and only then
                % recalculate the filter)
                if fCDRA_OperationTime > (this.tTimeProperties.fLastCycleSwitch + this.tTimeProperties.fCycleTime)

                    if this.iCycleActive == 1
                        this.iCycleActive = 2;
                    else
                        this.iCycleActive = 1;
                    end

                     if this.iCycleActive == 1
                        for iValve = 1:length(this.tMassNetwork.aoActiveValvesCycleOne)
                            this.tMassNetwork.aoActiveValvesCycleOne(iValve).setOpen(true);
                            this.tMassNetwork.aoActiveValvesCycleTwo(iValve).setOpen(false);
                        end
                        this.toProcsF2F.Valve_5A_1_Vacuum.setOpen(false);
                        this.toProcsF2F.Valve_5A_2_Vacuum.setOpen(false);

                        % Aside from the valves we also set the property of the
                        % adsorption procs in the 5A phases to use the buffer
                        % partial pressure in case of desorption, or the
                        % inflowing pressures in case of adsorption
                        for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                            this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_', num2str(iCell)]).bDesorption = false;
                            this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_', num2str(iCell)]).bDesorption = true;
                        end
                    else
                        for iValve = 1:length(this.tMassNetwork.aoActiveValvesCycleOne)
                            this.tMassNetwork.aoActiveValvesCycleOne(iValve).setOpen(false);
                            this.tMassNetwork.aoActiveValvesCycleTwo(iValve).setOpen(true);
                        end
                        this.toProcsF2F.Valve_5A_1_Vacuum.setOpen(false);
                        this.toProcsF2F.Valve_5A_2_Vacuum.setOpen(false);

                        for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                            this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_', num2str(iCell)]).bDesorption = true;
                            this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_', num2str(iCell)]).bDesorption = false;
                        end
                     end

                    this.tTimeProperties.fLastCycleSwitch = fCDRA_OperationTime;
                end

                % Change Airsave to vacuum desorption
                if fCDRA_OperationTime > (this.tTimeProperties.fLastCycleSwitch + this.tTimeProperties.fAirSafeTime)
                    if this.iCycleActive == 1
                        iBed = 2;
                    else
                        iBed = 1;
                    end
                    fWaterMass = 0;
                    for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                        fWaterMass = fWaterMass + this.toStores.(['Zeolite5A_', num2str(iBed)]).toPhases.(['Absorber_', num2str(iCell)]).afMass(this.oMT.tiN2I.H2O);
                    end
                    % Only deactivate air safe if the water mass is small
                    % that would otherwise be lost:
                    if fWaterMass < 0.25
                        this.toProcsF2F.(['Valve_5A_', num2str(iBed),'_Airsave']).setOpen(false);
                        this.toProcsF2F.(['Valve_5A_', num2str(iBed),'_Vacuum']).setOpen(true);
                    end
                end

                % handle the heaters in the currently desorbing Zeolite 5A bed
                if this.iCycleActive == 1
                    iBed = 2;
                else
                    iBed = 1;
                end

                % Only start heating the beds after the air save time, but
                % before than prevent freezing conditions
                if (fCDRA_OperationTime - this.tTimeProperties.fLastCycleSwitch) > this.tTimeProperties.fAirSafeTime
                    fZeoliteTargetTemperature = this.TargetTemperature;
                else
                    fZeoliteTargetTemperature = 285;
                end
                for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                    oCapacity = this.toStores.(['Zeolite5A_', num2str(iBed)]).toPhases.(['Absorber_', num2str(iCell)]).oCapacity;
                    if oCapacity.fTemperature < this.TargetTemperature
                        % 10 second time step maximum for this exec: Reduce
                        % heat flow if target temperature is reached within
                        % 10 seconds
                        fRequiredThermalEnergy = oCapacity.fTotalHeatCapacity * (fZeoliteTargetTemperature - oCapacity.fTemperature);
                        fRequiredHeatFlow = fRequiredThermalEnergy / this.fTimeStep;
                        if fRequiredHeatFlow < (this.fMaxHeaterPower / this.tGeometry.Zeolite5A.iCellNumber)
                            fHeaterPower = fRequiredHeatFlow;
                        else
                            fHeaterPower = (this.fMaxHeaterPower / this.tGeometry.Zeolite5A.iCellNumber);
                        end
                        oCapacity.toHeatSources.(['AbsorberHeater_', num2str(iCell)]).setHeatFlow(fHeaterPower);
                    else
                        oCapacity.toHeatSources.(['AbsorberHeater_', num2str(iCell)]).setHeatFlow(0);
                    end
                end
                
                fTotalHeatFlow = 0;
                for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                    oCapacity = this.toStores.(['Zeolite5A_', num2str(iBed)]).toPhases.(['Absorber_', num2str(iCell)]).oCapacity;
                    fTotalHeatFlow = fTotalHeatFlow + oCapacity.toHeatSources.(['AbsorberHeater_', num2str(iCell)]).fHeatFlow;
                end
                % The CDRA datime power consumption I received from ESA state
                % 1070 W, since the heater consume at most 960 W we assume here
                % that the average power demand for the remaining components
                % from  "Living together in space: the design and operation of the
                % life support systems on the International Space Station" P.O.
                % Wieland, 1998, page 132 is necessary in addition to the
                % heater power
                this.fCurrentPowerConsumption = fTotalHeatFlow + 107;
            else
                this.fCDRA_InactiveTime = this.fCDRA_InactiveTime + (this.oTimer.fTime - this.fLastExecutionTime);
                
                this.fCurrentPowerConsumption = 0;
            end
            this.fLastExecutionTime = this.oTimer.fTime;
        end
	end
end