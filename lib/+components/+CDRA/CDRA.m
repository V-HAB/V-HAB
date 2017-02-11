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
        % TO DO: didnt find an actual reference so for now using a values
        % that seems plausible
        fMaxHeaterPower = 10000;          % [W] 
        
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
        iInitStep = 100;                % [-]
        
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
        fMinimumTimeStep        = 1e-2;
        fMaximumTimeStep        = 10;
        
        % This variable decides by how much percent the mass in any one cell
        % is allowed to change within one tick (increasing this does not
        % necessarily speed up the simulation, but you can try)
        rMaxChange              = 0.001;
        
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
            % quadratic cross section with ~16 channels of~13mm length according to a presentation at the comsol conference 2015
            % "Multi-Dimensional Simulation of Flows Inside Polydisperse Packed Beds"
            % download link https://www.google.de/url?sa=t&rct=j&q=&esrc=s&source=web&cd=6&cad=rja&uact=8&ved=0ahUKEwjwstb2-OfKAhXEoQ4KHdkUAC8QFghGMAU&url=https%3A%2F%2Fwww.comsol.com%2Fconference2015%2Fdownload-presentation%2F29402&usg=AFQjCNERyzJcfMautp6BfFFUERc1FvISNw&bvm=bv.113370389,d.bGg
            % sorry couldn't find a better one.
            % However I am a bit unsure if that actually is correct. The
            % zeolite mass using those value would be ~14 kg thus CDRA
            % would not be able to take in enough CO2 to actually remove
            % the CO2 of 6 humans:
            %
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
            % ~23.5 kg)
            fCrossSection = (16*13E-3)^2; 
            
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
            
            fMassZeolite13x         = 0.49  *   this.tGeometry.Zeolite13x.fAbsorberVolume        * this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density;
            fMassSylobead           =           this.tGeometry.Sylobead.fAbsorberVolume          * this.oMT.ttxMatter.Sylobead_B125.ttxPhases.tSolid.Density;
            fMassZeolite5A          =           this.tGeometry.Zeolite5A.fAbsorberVolume         * this.oMT.ttxMatter.Zeolite5A_RK38.ttxPhases.tSolid.Density;
            
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
        	tInitialization.Zeolite13x.mfInitialCO2             = [   0,    0,    0,    0,    0]; %[0.06, 0.06, 0.06, 0.06, 0.06];
        	tInitialization.Zeolite13x.mfInitialH2O             = [   0,    0,    0,    0,    0]; %[0.15, 0.13, 0.08, 0.05,    0];
            
        	tInitialization.Sylobead.mfInitialCO2               = [   0,    0,    0,    0,    0];
        	tInitialization.Sylobead.mfInitialH2O               = [   1, 0.75, 0.55,  0.4,  0.2]; % Only set for the bed that just finished absorbing
            
        	tInitialization.Zeolite5A.mfInitialCO2              = [   0,    0,    0,    0,    0];
        	tInitialization.Zeolite5A.mfInitialH2O              = [   0,    0,    0,    0,    0]; %[0.01, 0.004, 0.002, 0.0005,    0];
            
            % Sets the cell numbers used for the individual filters
            tInitialization.Zeolite13x.iCellNumber = 5;
            tInitialization.Sylobead.iCellNumber = 5;
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
            this.tGeometry.Zeolite13x.fD_Hydraulic           = (4*this.tGeometry.Zeolite13x.fCrossSection/(4*18*13E-3))* this.tGeometry.Zeolite13x.rVoidFraction;
            this.tGeometry.Sylobead.fD_Hydraulic             = (4*this.tGeometry.Sylobead.fCrossSection/(4*18*13E-3))* this.tGeometry.Sylobead.rVoidFraction;
            this.tGeometry.Zeolite5A.fD_Hydraulic            = (4*this.tGeometry.Zeolite5A.fCrossSection/(4*18*13E-3))* this.tGeometry.Zeolite13x.rVoidFraction;
            
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
                fConductance            = tInitialization.(csTypes{iType}).fConductance;
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
                            if ~strcmp(sName, 'Sylobead_2')
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2O(iCell);
                            end
                        else
                            if ~strcmp(sName, 'Sylobead_1')
                                tfMassesAbsorber.H2O = tInitialization.(csTypes{iType}).mfInitialH2O(iCell);
                            end
                        end
                        
                        if this.iCycleActive == 1 
                            if ~strcmp(sName, 'Zeolite5A_2')
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), fTemperatureFlow, 0.1, this.tAtmosphere.fPressure);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), fTemperatureAbsorber, fPressure);
                                oFlowPhase = matter.phases.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), fTemperatureFlow);
                            else
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0.1, 100);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), this.TargetTemperature, fPressure);
                                oFlowPhase = matter.phases.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), this.TargetTemperature);
                            end
                        else
                            if ~strcmp(sName, 'Zeolite5A_1')
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), fTemperatureFlow, 0.1, this.tAtmosphere.fPressure);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), fTemperatureAbsorber, fPressure);
                                oFlowPhase = matter.phases.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), fTemperatureFlow);
                            else
                                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', this.tAtmosphere.fCO2Percent), this.TargetTemperature, 0.1, 100);
                
                                csFlowSubstances = fieldnames(cAirHelper{1});
                                for iK = 1:length(csFlowSubstances)
                                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                                end
                                
                                oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), this.TargetTemperature, fPressure);
                                oFlowPhase = matter.phases.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), this.TargetTemperature);
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
                            % for the first cell only the conductor between the
                            % absorber and the flow phase has to be defined
                            this.addConductor(thermal.conductors.linear(this, moCapacity{iCell,1}, moCapacity{iCell,2}, 0, [sName, 'ConvectiveConductor_', num2str(iCell)]));
                        elseif iCell == iCellNumber
                            % branch between the current and the previous cell
                            matter.branch(this, [sName,'.','Outflow_',num2str(iCell-1)], {}, [sName,'.','Inflow_',num2str(iCell)], [sName, 'Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                            % for the last cell only the conductor between the
                            % absorber and the flow phase has to be defined
                            this.addConductor(thermal.conductors.linear(this, moCapacity{iCell,1}, moCapacity{iCell,2}, 0, [sName, 'ConvectiveConductor_', num2str(iCell)]));

                        else
                            % branch between the current and the previous cell
                            matter.branch(this, [sName,'.','Outflow_',num2str(iCell-1)], {}, [sName,'.','Inflow_',num2str(iCell)], [sName, 'Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                            % Create and add linear conductors between each cell
                            % absorber material to reflect the thermal conductance
                            % of the absorber material
                            this.addConductor(thermal.conductors.linear(this, moCapacity{iCell-1,1}, moCapacity{iCell,1}, fConductance));
                            % and also add a conductor between the absorber
                            % material and the flow phase for each cell to
                            % implement the convective heat transfer
                            this.addConductor(thermal.conductors.linear(this, moCapacity{iCell,1}, moCapacity{iCell,2}, 0, [sName, 'ConvectiveConductor_', num2str(iCell)]));
                        end
                        
                        % this factor times the mass flow^2 will decide the pressure
                        % loss. In this case the pressure loss will be 1 bar at a
                        % flowrate of 0.01 kg/s
                        this.tGeometry.(csTypes{iType}).mfFrictionFactor(iCell) = 1e8/iCellNumber;
                    
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
            matter.branch(this, ['Zeolite13x_1.Outflow_',num2str(iCellNumber)], {}, 'Zeolite5A_1.Inflow_1', 'Zeolite13x1_to_5A1');
            matter.branch(this, ['Zeolite13x_2.Outflow_',num2str(iCellNumber)], {}, 'Zeolite5A_2.Inflow_1', 'Zeolite13x2_to_5A2');
            
            
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
            
            for iB = 1:length(this.aoBranches)
                solver.matter.manual.branch(this.aoBranches(iB));
            end
            
            csStores = fieldnames(this.toStores);
            
            % The flowrate solver will handle the update times for the phases
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    oPhase.rMaxChange = inf;
                    oPhase.fMaxStep = inf;
                end
            end
            oPhase = this.tMassNetwork.aoBranchesCycleOne(1).coExmes{2}.oPhase;
            oPhase.rMaxChange = inf;
            oPhase.fMaxStep = inf;
            
            % adds the lumped parameter thermal solver to calculate the
            % convective and conductive heat transfer
            this.oThermalSolver = solver.thermal.lumpedparameter(this);
            
            % sets the minimum time step that can be used by the thermal
            % solver
            this.oThermalSolver.fMinimumTimeStep = 0.01;
            
            
            this.tTimeProperties.AdsorptionLastExec = -10;
            this.tTimeProperties.AdsorptionStep = -1;
            this.tTimeProperties.DesorptionLastExec = -10;
            this.tTimeProperties.DesorptionStep = -1;
            this.tTimeProperties.DesorptionThermalLastExec = -10;
            this.tTimeProperties.DesorptionThermalStep = -1;
            
            this.tMassNetwork.mfMassDiff = zeros(this.iCells+1,1);
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
            
            csNodes_Absorber_CycleOne = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            csNodes_Flow_CycleOne     = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            csNodes_Absorber_CycleTwo = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            csNodes_Flow_CycleTwo     = cell(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
            
            for iCell = 1:this.tGeometry.Sylobead.iCellNumber
                this.tMassNetwork.aoPhasesCycleOne(end+1,1)   = this.toStores.Sylobead_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Sylobead_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Sylobead.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)               = this.tGeometry.Sylobead.fLength/this.tGeometry.Sylobead.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1)  = this.tGeometry.Sylobead.fAbsorberSurfaceArea/this.tGeometry.Sylobead.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)          = this.tGeometry.Sylobead.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Sylobead_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Sylobead_1ConvectiveConductor_', num2str(iCell)];
                
            end
                
            for iCell = 1:this.tGeometry.Zeolite13x.iCellNumber
                this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite13x_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite13x.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)                = this.tGeometry.Zeolite13x.fLength/this.tGeometry.Zeolite13x.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite13x.fAbsorberSurfaceArea/this.tGeometry.Zeolite13x.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)           = this.tGeometry.Zeolite13x.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Zeolite13x_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Zeolite13x_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite5A_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite5A.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)                = this.tGeometry.Zeolite5A.fLength/this.tGeometry.Zeolite5A.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite5A.fAbsorberSurfaceArea/this.tGeometry.Zeolite5A.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)     	  = this.tGeometry.Zeolite5A.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Zeolite5A_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Zeolite5A_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tGeometry.Zeolite13x.iCellNumber:-1:1
                this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite13x_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite13x.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)              = this.tGeometry.Zeolite13x.fLength/this.tGeometry.Zeolite13x.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1) = this.tGeometry.Zeolite13x.fAbsorberSurfaceArea/this.tGeometry.Zeolite13x.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)    	 = this.tGeometry.Zeolite13x.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Zeolite13x_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Zeolite13x_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tGeometry.Sylobead.iCellNumber:-1:1
                this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toStores.Sylobead_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleOne(end+1,1) = this.toStores.Sylobead_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                mfFrictionFactor(length(this.tMassNetwork.aoPhasesCycleOne),1)   = this.tGeometry.Sylobead.mfFrictionFactor(iCell);
                
                mfLength(length(this.tMassNetwork.aoPhasesCycleOne),1)              = this.tGeometry.Sylobead.fLength/this.tGeometry.Sylobead.iCellNumber;
                mfAbsorberSurfaceArea(length(this.tMassNetwork.aoPhasesCycleOne),1) = this.tGeometry.Sylobead.fAbsorberSurfaceArea/this.tGeometry.Sylobead.iCellNumber;
                mfD_Hydraulic(length(this.tMassNetwork.aoPhasesCycleOne),1)    	 = this.tGeometry.Sylobead.fD_Hydraulic;
                
                csNodes_Absorber_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = [this.sName ,'__Sylobead_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{length(this.tMassNetwork.aoPhasesCycleOne),1} = ['Sylobead_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                csNodes_Absorber_CycleOne{this.iCells + iCell,1} = [this.sName ,'__Zeolite5A_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleOne{this.iCells + iCell,1} = ['Zeolite5A_2ConvectiveConductor_', num2str(iCell)];
                mfAbsorberSurfaceArea(this.iCells + iCell,1) = this.tGeometry.Sylobead.fAbsorberSurfaceArea/this.tGeometry.Sylobead.iCellNumber;
            end
            
            this.tMassNetwork.aoPhasesCycleOne(end+1,1) = this.toBranches.CDRA_Air_Out_1.coExmes{2}.oPhase;
            
            for iPhase = 1:length(this.tMassNetwork.aoPhasesCycleOne)
                this.tMassNetwork.aoPhasesCycleOne(iPhase).oOriginPhase = this.oAtmosphere;
            end
            
            this.tThermalNetwork.csNodes_Absorber_CycleOne = csNodes_Absorber_CycleOne;
            this.tThermalNetwork.csNodes_Flow_CycleOne = csNodes_Flow_CycleOne;
            
            this.tGeometry.mfLength                 = mfLength;
            this.tGeometry.mfAbsorberSurfaceArea    = mfAbsorberSurfaceArea;
            this.tGeometry.mfD_Hydraulic            = mfD_Hydraulic;
            
            % Cycle Two
            for iCell = 1:this.tGeometry.Sylobead.iCellNumber
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Sylobead_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Sylobead_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Sylobead_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Sylobead_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tGeometry.Zeolite13x.iCellNumber
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite13x_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Zeolite13x_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Zeolite13x_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite5A_2.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Zeolite5A_2__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Zeolite5A_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tGeometry.Zeolite13x.iCellNumber:-1:1
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite13x_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Zeolite13x_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Zeolite13x_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tGeometry.Sylobead.iCellNumber:-1:1
                this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toStores.Sylobead_1.toPhases.(['Flow_',num2str(iCell)]);
                this.tMassNetwork.aoAbsorberCycleTwo(end+1,1) = this.toStores.Sylobead_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                csNodes_Absorber_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = [this.sName ,'__Sylobead_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{length(this.tMassNetwork.aoPhasesCycleTwo),1} = ['Sylobead_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                csNodes_Absorber_CycleTwo{this.iCells + iCell,1} = [this.sName ,'__Zeolite5A_1__Absorber_',num2str(iCell)];
                csNodes_Flow_CycleTwo{this.iCells + iCell,1} = ['Zeolite5A_1ConvectiveConductor_', num2str(iCell)];
            end
            
            this.tMassNetwork.aoPhasesCycleTwo(end+1,1) = this.toBranches.CDRA_Air_Out_2.coExmes{2}.oPhase;
            
            for iPhase = 1:length(this.tMassNetwork.aoPhasesCycleTwo)
                this.tMassNetwork.aoPhasesCycleTwo(iPhase).oOriginPhase = this.oAtmosphere;
            end
            
            this.tThermalNetwork.csNodes_Absorber_CycleTwo = csNodes_Absorber_CycleTwo;
            this.tThermalNetwork.csNodes_Flow_CycleTwo = csNodes_Flow_CycleTwo;
            
            this.tGeometry.mfFrictionFactor = mfFrictionFactor;
           
        end
        function setReferencePhase(this, oPhase)
                this.oAtmosphere = oPhase;
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
            
            this.calculateThermalProperties()
            
            %% Cycle Change handling:
            % in case the cycle is switched a number of changes has to be
            % made to the flowrates, which are only necessary ONCE!
            % (setting the flowrates of all branches to zero, and only then
            % recalculate the filter)
            if (this.iCycleActive == 2) && (mod(this.oTimer.fTime, this.fCycleTime * 2) >= (this.fCycleTime)) && (this.oTimer.iTick ~= 0)
                % On cycle change all flow rates are momentarily set to zero
                for iBranch = 1:length(this.tMassNetwork.aoBranchesCycleTwo)
                    this.tMassNetwork.aoBranchesCycleTwo(iBranch).oHandler.setFlowRate(0);
                end
                
                this.toBranches.(['CDRA_Vent_',num2str(this.iCycleActive)]).oHandler.setFlowRate(0);
                this.toBranches.(['CDRA_AirSafe_',num2str(this.iCycleActive)]).oHandler.setFlowRate(0);
                
                this.tTimeProperties.fLastCycleSwitch = this.oTimer.fTime;
                
                aoAbsorber = this.tMassNetwork.aoAbsorberCycleOne;
                for iAbsorber = 1:length(aoAbsorber)
                    aoAbsorber(iAbsorber).setFlowRateToZero();
                    aoAbsorber(iAbsorber).oOut.oPhase.update();
                end
                aoAbsorber = this.tMassNetwork.aoAbsorberCycleTwo;
                for iAbsorber = 1:length(aoAbsorber)
                    aoAbsorber(iAbsorber).setFlowRateToZero();
                    aoAbsorber(iAbsorber).oOut.oPhase.update();
                end
                this.tMassNetwork.mfAdsorptionFlowRate = zeros(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
                
                aoPhases = this.tMassNetwork.aoPhasesCycleOne;
                for iCell = 1:this.iCells
                    aoPhases(iCell).update();
                end
                aoPhases = this.tMassNetwork.aoPhasesCycleTwo;
                for iCell = 1:this.iCells
                    aoPhases(iCell).update();
                end
                % In order to get the flow rate calculation to higher
                % speeds at each cycle change the phases are preset to
                % contain pressures close to the final pressure (after the
                % initial flowrate setup)
                mfPressureDiff = this.tGeometry.mfFrictionFactor .* (this.oParent.toChildren.(this.sAsscociatedCCAA).fCDRA_FlowRate)^2;
                mfPressurePhase = zeros(this.iCells+1,1);
                for iPhase = 1:length(this.tMassNetwork.aoPhasesCycleOne)
                    mfPressurePhase(iPhase) = this.tMassNetwork.aoPhasesCycleOne(end).fPressure + sum(mfPressureDiff(iPhase:end));
                end
                % The time step for the cycle change case is set to ONE
                % second, therefore the calculated mass difference is
                % directly the required flow rate that has to go into the
                % phase to reach the desired mass
                this.tMassNetwork.mfMassDiff = (mfPressurePhase - [this.tMassNetwork.aoPhasesCycleOne.fPressure]')./[this.tMassNetwork.aoPhasesCycleOne.fMassToPressure]';
                
                % Now the mass difference required in the phases is
                % translated into massflows for the branches for the next
                % second
                mfFlowRate = zeros(this.iCells+1,1);
                for iBranch = 1:(length(this.tMassNetwork.aoBranchesCycleOne))
                    mfFlowRate(iBranch) = this.tMassNetwork.miNegativesCycleOne(iBranch) * (this.fFlowrateMain + sum(this.tMassNetwork.mfMassDiff(iBranch:end))/this.fInitTime);
                    this.tMassNetwork.aoBranchesCycleOne(iBranch).oHandler.setFlowRate(mfFlowRate(iBranch));
                end
                
                % Sets the correct cells for the adsorption P2Ps to store
                % their values
                for iP2P = 1:length(this.tMassNetwork.aoAbsorberCycleOne)
                    this.tMassNetwork.aoAbsorberCycleOne(iP2P).iCell = iP2P;
                end
                for iP2P = 1:this.tGeometry.Zeolite5A.iCellNumber
                    this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).iCell = this.iCells + iP2P;
                    this.tMassNetwork.aoAbsorberPhases(iP2P) = this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).oOut.oPhase;
                end
                
                this.setTimeStep(this.fInitTime/this.iInitStep);
                this.updateCCAA();
                
                this.iCycleActive = 1;
                
            elseif ((this.iCycleActive == 1) && (mod(this.oTimer.fTime, this.fCycleTime * 2) < (this.fCycleTime)) && (this.oTimer.iTick ~= 0))
                % On cycle change all flow rates are momentarily set to zero
                for iBranch = 1:length(this.tMassNetwork.aoBranchesCycleOne)
                    this.tMassNetwork.aoBranchesCycleOne(iBranch).oHandler.setFlowRate(0);
                end
                
                this.toBranches.(['CDRA_Vent_',num2str(this.iCycleActive)]).oHandler.setFlowRate(0);
                this.toBranches.(['CDRA_AirSafe_',num2str(this.iCycleActive)]).oHandler.setFlowRate(0);
                
                this.tTimeProperties.fLastCycleSwitch = this.oTimer.fTime;
                
                aoAbsorber = this.tMassNetwork.aoAbsorberCycleOne;
                for iAbsorber = 1:length(aoAbsorber)
                    aoAbsorber(iAbsorber).setFlowRateToZero();
                    aoAbsorber(iAbsorber).oOut.oPhase.update();
                end
                aoAbsorber = this.tMassNetwork.aoAbsorberCycleTwo;
                for iAbsorber = 1:length(aoAbsorber)
                    aoAbsorber(iAbsorber).setFlowRateToZero();
                    aoAbsorber(iAbsorber).oOut.oPhase.update();
                end
                this.tMassNetwork.mfAdsorptionFlowRate = zeros(this.iCells + this.tGeometry.Zeolite5A.iCellNumber,1);
                
                aoPhases = this.tMassNetwork.aoPhasesCycleOne;
                for iCell = 1:this.iCells
                    aoPhases(iCell).update();
                end
                aoPhases = this.tMassNetwork.aoPhasesCycleTwo;
                for iCell = 1:this.iCells
                    aoPhases(iCell).update();
                end
                % In order to get the flow rate calculation to higher
                % speeds at each cycle change the phases are preset to
                % contain pressures close to the final pressure (after the
                % initial flowrate setup)
                mfPressureDiff = this.tGeometry.mfFrictionFactor .* (this.oParent.toChildren.(this.sAsscociatedCCAA).fCDRA_FlowRate)^2;
                mfPressurePhase = zeros(this.iCells+1,1);
                for iPhase = 1:length(this.tMassNetwork.aoPhasesCycleTwo)
                    mfPressurePhase(iPhase) = this.tMassNetwork.aoPhasesCycleTwo(end).fPressure + sum(mfPressureDiff(iPhase:end));
                end
                % The time step for the cycle change case is set to ONE
                % second, therefore the calculated mass difference is
                % directly the required flow rate that has to go into the
                % phase to reach the desired mass
                this.tMassNetwork.mfMassDiff = (mfPressurePhase - [this.tMassNetwork.aoPhasesCycleTwo.fPressure]')./[this.tMassNetwork.aoPhasesCycleTwo.fMassToPressure]';
                
                % Now the mass difference required in the phases is
                % translated into massflows for the branches for the next
                % second
                mfFlowRate = zeros(this.iCells+1,1);
                for iBranch = 1:(length(this.tMassNetwork.aoBranchesCycleTwo))
                    mfFlowRate(iBranch) = this.tMassNetwork.miNegativesCycleTwo(iBranch) * (this.fFlowrateMain + sum(this.tMassNetwork.mfMassDiff(iBranch:end))/this.fInitTime);
                    this.tMassNetwork.aoBranchesCycleTwo(iBranch).oHandler.setFlowRate(mfFlowRate(iBranch));
                end
                
                for iP2P = 1:length(this.tMassNetwork.aoAbsorberCycleOne)
                    this.tMassNetwork.aoAbsorberCycleTwo(iP2P).iCell = iP2P;
                end
                for iP2P = 1:this.tGeometry.Zeolite5A.iCellNumber
                    this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).iCell = this.iCells + iP2P;
                    this.tMassNetwork.aoAbsorberPhases(iP2P) = this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).oOut.oPhase;
                end
                
                this.setTimeStep(this.fInitTime/this.iInitStep);
                this.updateCCAA();
                
                this.iCycleActive = 2;
                
            elseif mod(this.oTimer.fTime, this.fCycleTime) < this.fInitTime
                
                % The flowrates for the initilization are only set once and
                % then used for the rest of the init time,
                aoPhases = this.tMassNetwork.aoPhasesCycleOne;
                for iCell = 1:this.iCells
                    aoPhases(iCell).update();
                end
                aoPhases = this.tMassNetwork.aoPhasesCycleTwo;
                for iCell = 1:this.iCells
                    aoPhases(iCell).update();
                end
                
                if this.iCycleActive == 1
                    sCycle = 'One';
                else
                    sCycle = 'Two';
                end
                
                % Now the mass difference required in the phases is
                % translated into massflows for the branches for the next
                % second
                aoBranches(:,1) = this.tMassNetwork.(['aoBranchesCycle',sCycle]);
                mfFlowRate(:,1) = [aoBranches.fFlowRate];
                
                aoAbsorber = this.tMassNetwork.(['aoAbsorberCycle',sCycle]);
                aoAbsorber(1).ManualUpdate(this.fInitTime/this.iInitStep, mfFlowRate(1) .* aoBranches(1).coExmes{2}.oPhase.arPartialMass);
                aoAbsorber(1).oOut.oPhase.update();
                    
                for iAbsorber = 2:length(aoAbsorber)
                    aoAbsorber(iAbsorber).ManualUpdate(this.fInitTime/this.iInitStep, mfFlowRate(iAbsorber) .* aoAbsorber(iAbsorber).oIn.oPhase.arPartialMass);
                    aoAbsorber(iAbsorber).oOut.oPhase.update();
                end
                
                for iBranch = 1:(length(mfFlowRate))
                    mfFlowRate(iBranch) = this.tMassNetwork.miNegativesCycleTwo(iBranch) * ((this.fFlowrateMain + sum(this.tMassNetwork.mfMassDiff(iBranch:end))/this.fInitTime) -  - sum(this.tMassNetwork.mfAdsorptionFlowRate(1:iBranch-1)));
                    aoBranches(iBranch).oHandler.setFlowRate(mfFlowRate(iBranch));
                end
                
                this.updateCCAA();
                
            elseif (this.oTimer.iTick ~= 0)
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
            
            % since the thermal solver currently only has constant time
            % steps it currently uses the same time step as the filter
            % model.
            this.oThermalSolver.setTimestep(this.fTimeStep);
        end
        function updateCCAA(this,~)
            %% Handling the flowrates of the associated CCAA
            % The CCAA flowrates are adapted here based on the dynamic
            % flowrates of CDRA. This way the CCAA can still work with the
            % simpler flow rate calculations as that should be fine for the
            % CCAA (at least at the moment)
            if this.iCycleActive == 1                
                % Flow going out of CCAA into CDRA
                fFlowRate_CCAA_CDRA = -this.tMassNetwork.aoBranchesCycleOne(1).oHandler.fRequestedFlowRate;
                % Flow rate going from CDRA back to the CCAA
                fFlowRate_CDRA_CCAA = this.tMassNetwork.aoBranchesCycleOne(end).oHandler.fRequestedFlowRate;
            else
                % Flow going out of CCAA into CDRA
                fFlowRate_CCAA_CDRA = -this.tMassNetwork.aoBranchesCycleTwo(1).oHandler.fRequestedFlowRate;
                % Flow rate going from CDRA back to the CCAA
                fFlowRate_CDRA_CCAA = this.tMassNetwork.aoBranchesCycleTwo(end).oHandler.fRequestedFlowRate;
            end
            
            this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.CHX_CDRA.oHandler.setFlowRate(fFlowRate_CCAA_CDRA);
            this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.CDRA_TCCV.oHandler.setFlowRate(-fFlowRate_CDRA_CCAA);

            fCurrentFlowRate_CHX_Cabin = this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.CHX_Cabin.oHandler.fRequestedFlowRate;                
            fFlowRate_CCAA_Condensate = this.oParent.toChildren.(this.sAsscociatedCCAA).toStores.CHX.toProcsP2P.CondensingHX.fFlowRate;

            % Sets the new flowrate from TCCV to CHX inside CCAA
            fNewFlowRate_TCCV_CHX = fFlowRate_CCAA_CDRA + fCurrentFlowRate_CHX_Cabin + fFlowRate_CCAA_Condensate;
            this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.TCCV_CHX.oHandler.setFlowRate(fNewFlowRate_TCCV_CHX);

            fCurrentFlowRate_TCCV_Cabin = this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.TCCV_Cabin.oHandler.fRequestedFlowRate;

            % Sets the new flowrate from Cabin to TCCV inside CCAA
            fNewFlowRate_Cabin_TCCV = fNewFlowRate_TCCV_CHX + fCurrentFlowRate_TCCV_Cabin - fFlowRate_CDRA_CCAA; 
            this.oParent.toChildren.(this.sAsscociatedCCAA).toBranches.CCAA_In_FromCabin.oHandler.setFlowRate(-fNewFlowRate_Cabin_TCCV);
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
            aoAbsorber = this.tMassNetwork.(['aoAbsorberCycle',sCycle])(1:this.iCells);
            
            % well the phase pressures have not been updated ( the
            % rMaxChange was set to inf) in order to do controlled updates
            % now
            for iCell = 1:this.iCells
                aoPhases(iCell).update();
                aoAbsorber(iCell).oOut.oPhase.update();
            end
            aoBranches(1).coExmes{2}.oPhase.update();
            
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
            mfCellMass(:,1)         = [aoPhases.fMass];
           	mfCellPressure(:,1)     = [aoPhases.fPressure];
            
            % In order to get the flow rate calculation to higher
            % speeds at each cycle change the phases are preset to
            % contain pressures close to the final pressure (after the
            % initial flowrate setup)
            mfPressureDiff = this.tGeometry.mfFrictionFactor .* (this.oParent.toChildren.(this.sAsscociatedCCAA).fCDRA_FlowRate)^2;
            mfPressurePhase = zeros(this.iCells+1,1);
            for iCell = 1:length(aoPhases)
                mfPressurePhase(iCell) = aoPhases(end).fPressure + sum(mfPressureDiff(iCell:end));
            end
            % The time step for the cycle change case is set to ONE
            % second, therefore the calculated mass difference is
            % directly the required flow rate that has to go into the
            % phase to reach the desired mass
            mfMassDiff = (mfPressurePhase - mfCellPressure)./[aoPhases.fMassToPressure]';
            
            % if the phase is empty the mass to pressure value will be 0
            % and the calculation would fail. Instead the ideal gas law is
            % used in that case. Note that in the future this caluclation
            % could be used to also predict temperature influences and
            % increase the speed of the calculation because of better
            % prediction.
            % p V = m R T ; m = p V / R T
            if any(isinf(mfMassDiff)) || any(isnan(mfMassDiff)) 
                mfCellVolume(:,1)       = [aoPhases.fVolume];
                mfCellTemperature(:,1)	= [aoPhases.fTemperature];
                bNAN = (isnan(mfMassDiff)) | (isinf(mfMassDiff));
                mfMassDiff(bNAN) = ((mfPressurePhase(bNAN) .* mfCellVolume(bNAN)) ./ (287.1 .* mfCellTemperature(bNAN)) - mfCellMass(bNAN));
            end
            
            % Now the time step can be calculated by using the maximum
            % allowable mass change within one step (Basically the time
            % step is 1/ Times Max Mass Change. For large mass changes it
            % therefore is small and for small mass changes it is large ;)
            fTimeStep = min(1./(abs(mfMassDiff) ./ (this.rMaxChange .* mfCellMass)));
            
            if fTimeStep > this.fMaximumTimeStep
                fTimeStep = this.fMaximumTimeStep;
            elseif fTimeStep  <= this.fMinimumTimeStep
                fTimeStep = this.fMinimumTimeStep;
            end
            
            % Well this actually enforces the percental mass change limit
            % imposed by rMaxChange (as the timestep in this case does not
            % do this since absolute masses are calculated)
            abReduceMassDiff = abs(mfMassDiff) > (this.rMaxChange .* mfCellMass);
            if any(abReduceMassDiff)
                % factor by which the mass change currently exceeds the
                % allowed mass change for each cell
                mfFactor = abs(mfMassDiff(abReduceMassDiff))./(this.rMaxChange .* mfCellMass(abReduceMassDiff));
                % The mass changes all have to be divided with the maximum
                % factor, to keep the relative change of mass between the
                % cells as intended
                mfMassDiff = mfMassDiff./max(mfFactor);
            end
            
            % Intended new cell masses on next tick, if this is not the
            % case use for debugging ;)
            this.tMassNetwork.mfIntendedCellMass = mfCellMass + mfMassDiff;
            
            % Now the mass difference required in the phases is
            % translated into massflows for the branches for the next
            % second
            mfMassDiff = mfMassDiff./fTimeStep;
            
            mfFlowRatesNew = zeros(this.iCells+1,1);
            
            for iBranch = 1:length(aoBranches)
            % The reduction in flow rate from the P2Ps has to be given to
            % all the following branches as well
                mfFlowRatesNew(iBranch) = this.tMassNetwork.(['miNegativesCycle',sCycle])(iBranch) * (this.fFlowrateMain + (sum(mfMassDiff(iBranch:end))));
            end
            
            % In order to ensure that the flow rates considered during this
            % calculation are also the ones actually used by the P2P a
            % manual update function that is only called here is used for
            % the P2Ps. It is given the timestep and Inflow to prevent the
            % P2P from removing more mass than is actually available
          	aoAbsorber(1).ManualUpdate(fTimeStep, abs(mfFlowRatesNew(1) .* aoBranches(1).coExmes{2}.oPhase.arPartialMass));
            for iAbsorber = 2:length(aoAbsorber)
                aoAbsorber(iAbsorber).ManualUpdate(fTimeStep, abs(mfFlowRatesNew(iAbsorber) .* aoPhases(iAbsorber-1).arPartialMass));
            end
            
            % First branch has to be handled differently
            iBranch = 1;
            mfFlowRatesNew(iBranch) = this.tMassNetwork.(['miNegativesCycle',sCycle])(iBranch) * (this.fFlowrateMain + (sum(mfMassDiff(iBranch:end))));            
            aoBranches(iBranch).oHandler.setFlowRate(mfFlowRatesNew(iBranch));
            
            for iBranch = 2:length(aoBranches)
            % The reduction in flow rate from the P2Ps has to be given to
            % all the following branches as well
                mfFlowRatesNew(iBranch) = this.tMassNetwork.(['miNegativesCycle',sCycle])(iBranch) * (this.fFlowrateMain + (sum(mfMassDiff(iBranch:end))) - sum(this.tMassNetwork.mfAdsorptionFlowRate(1:iBranch-1)));
                aoBranches(iBranch).oHandler.setFlowRate(mfFlowRatesNew(iBranch));
            end
            
            % Usefull code for debugging :)
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
            
            % Updates the atmosphere
            this.oAtmosphere.update();
            
            aoTCCV = this.oParent.toChildren.(this.sAsscociatedCCAA).toStores.TCCV.aoPhases;
            for iPhase = 1:length(aoTCCV)
                aoTCCV(iPhase).update();
            end
            
            aoCHX = this.oParent.toChildren.(this.sAsscociatedCCAA).toStores.CHX.aoPhases;
            for iPhase = 1:length(aoCHX)
                aoCHX(iPhase).update();
            end
            
            % Updates the CCAA flowrates
            this.updateCCAA();
            
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
            aoAbsorber = this.tMassNetwork.(['aoAbsorberCycle',sCycle])(iStartCell:iStartCell+iDesorbCells-1);
            aoBranches = this.tMassNetwork.(['aoBranchesCycle',sCycle])(iStartCell+1:iStartCell+iDesorbCells-1);

            for iPhase = 1:length(aoPhases)
                aoPhases(iPhase).update();
                aoAbsorber(iPhase).oOut.oPhase.update();
            end

            mfCellMass(:,1)     = [aoPhases.fMass];
            mfCellPressure(:,1) = [aoPhases.fPressure];

            if (mod(this.oTimer.fTime, this.fCycleTime)) < this.fAirSafeTime
                aoBranches(end+1) = this.toBranches.(['CDRA_AirSafe_',num2str(this.iCycleActive)]);
            else
                aoBranches(end+1) = this.toBranches.(['CDRA_Vent_',num2str(this.iCycleActive)]);
                this.toBranches.(['CDRA_AirSafe_',num2str(this.iCycleActive)]).oHandler.setFlowRate(0);
            end

            abHighPressure = (mfCellPressure > 100);

            mfMassDiff = zeros(length(aoPhases),1);
            mfMassDiff(abHighPressure) = -mfCellMass(abHighPressure)./(this.fAirSafeTime/2.5);
            
            fTimeStep = min(abs((this.rMaxChange .* mfCellMass) ./ mfMassDiff));
            
            if fTimeStep > this.fMaximumTimeStep
                fTimeStep = this.fMaximumTimeStep;
            elseif fTimeStep  <= this.fMinimumTimeStep
                fTimeStep = this.fMinimumTimeStep;
            end
            
            for iAbsorber = 1:length(aoAbsorber)
                aoAbsorber(iAbsorber).ManualUpdate(fTimeStep, zeros(1,this.oMT.iSubstances));
                % Disable adsorption during the desorption phase, this is
                % only necessary because the calculation of the branch
                % flowrates is not able to cope with this
                if -this.tMassNetwork.mfAdsorptionFlowRate(this.iCells+iAbsorber) < 0
                    aoAbsorber(iAbsorber).setFlowRateToZero();
                    this.tMassNetwork.mfAdsorptionFlowRate(this.iCells+iAbsorber) = 0;
                end
            end

            mfDesorptionFlowRate = -this.tMassNetwork.mfAdsorptionFlowRate(this.iCells+1:end);
            
            mfFlowRatesNew = zeros(length(aoBranches),1);
            for iBranch = 1:(length(aoBranches))
                mfFlowRatesNew(iBranch) = (-sum(mfMassDiff(1:iBranch))) + sum(mfDesorptionFlowRate(1:iBranch));
                aoBranches(iBranch).oHandler.setFlowRate(mfFlowRatesNew(iBranch));
            end

            this.tTimeProperties.DesorptionStep = fTimeStep;
            
            %% Set the heater power for the desorption cells
            % Check cell temperature of the desorber cells
            
            if (mod(this.oTimer.fTime, this.fCycleTime)) > this.fAirSafeTime
                mfCellTemperature(:,1)     = [this.tMassNetwork.aoAbsorberPhases.fTemperature];
                mfCellHeatCap(:,1)         = [this.tMassNetwork.aoAbsorberPhases.fSpecificHeatCapacity] .* [this.tMassNetwork.aoAbsorberPhases.fMass];

                mfPowerDesorbCells = this.tThermalNetwork.mfHeaterPower(this.iCells+1:end);
                
                mbTempReached = abs(mfCellTemperature - this.TargetTemperature) < 1;
                mfPowerDesorbCells(mbTempReached) = 0;
                mfPowerDesorbCells(~mbTempReached) = ((this.TargetTemperature - mfCellTemperature(~mbTempReached)).* mfCellHeatCap(~mbTempReached))/this.fAirSafeTime;
                mfPowerDesorbCells(mfPowerDesorbCells > this.fMaxHeaterPower) = this.fMaxHeaterPower/this.tGeometry.Zeolite5A.iCellNumber;
                mfPower = zeros(this.iCells+this.tGeometry.Zeolite5A.iCellNumber,1);
                mfPower(this.iCells+1:end) = mfPowerDesorbCells;
                this.setHeaterPower(mfPower);
            else
                mfPower = zeros(this.iCells+this.tGeometry.Zeolite5A.iCellNumber,1);
                this.setHeaterPower(mfPower);
            end
%             % timestep set to allow at most 1 K temperature change within
%             % one step
%             fTimeStep = min(abs(mfPowerDesorbCells./(mfCellHeatCap.*1)));
%             
%             if fTimeStep > this.fMaximumTimeStep
%                 fTimeStep = this.fMaximumTimeStep;
%             elseif fTimeStep  <= this.fMinimumTimeStep
%                 fTimeStep = this.fMinimumTimeStep;
%             end
%             this.tTimeProperties.DesorptionThermalStep = fTimeStep;
%             this.tTimeProperties.DesorptionThermalLastExec = this.oTimer.fTime;
        end
        
        function calculateThermalProperties(this)
            
            if this.iCycleActive == 1
                sCycle = 'One';
                sDesorbingBed = 'Zeolite5A_2';
            else
                sCycle = 'Two';
                sDesorbingBed = 'Zeolite5A_1';
            end
            
            iTotalCells = length(this.tThermalNetwork.mfAdsorptionHeatFlow);
            % Sets the heat source power in the absorber material as a
            % combination of the heat of absorption and the heater power.
            % Note that the heater power can also be negative resulting in
            % cooling.
            mfHeatFlow              = this.tThermalNetwork.mfAdsorptionHeatFlow + this.tThermalNetwork.mfHeaterPower;
            for iCell = 1:iTotalCells                                           
                oCapacity = this.poCapacities(this.tThermalNetwork.(['csNodes_Absorber_Cycle',sCycle]){iCell,1});
                oCapacity.oHeatSource.setPower(mfHeatFlow(iCell));
            end
            
            % Now the convective heat transfer between the absorber material
            % and the flow phases has to be calculated, this is only done
            % for the phases currently within the active cycle
            
            % alternative solution for the case without flowspeed? Use
            % just thermal conductivity of fluid and the MaxFreeDistance to
            % calculate a HeatTransferCoeff?
            % D_Hydraulic and fLength defined in geometry struct
            mfHeatTransferCoefficient       = zeros(iTotalCells,1);
            mfFlowSpeed                     = zeros(iTotalCells,1);
            aoPhases                        = this.tMassNetwork.(['aoPhasesCycle',sCycle]);
            aoBranches                      = this.tMassNetwork.(['aoBranchesCycle',sCycle]);
            
            for iCell = 1:this.tGeometry.Zeolite5A.iCellNumber
                aoPhases(this.iCells+iCell) = this.toStores.(sDesorbingBed).toPhases.(['Flow_',num2str(iCell)]);
            end
            % gets the required properties for each cell and stores them in
            % variables for easier access
            mfDensity                  = [aoPhases.fDensity]';
            mfSpecificHeatCapacity     = [aoPhases.fSpecificHeatCapacity]';
            mfMass                     = [aoPhases.fMass]';
            % Flow speed for desorbing cells is assumed to be zero
            mfFlowSpeed(1:this.iCells) = (abs([aoBranches(1:end-1).fFlowRate]') + abs([aoBranches(2:end).fFlowRate]')./(2*mfDensity(1:this.iCells)));
            mfFlowSpeed(mfDensity == 0) = 0;
            
            % In order to limit the recalculation of the convective heat
            % exchange coefficient to a manageable degree they are only
            % recalculated if any relevant property changed by at least 1%
            mbRecalculate = (abs(this.tLastUpdateProps.mfDensity - mfDensity)                            > (1e-2 * mfDensity)) +...
                            (abs(this.tLastUpdateProps.mfFlowSpeed - mfFlowSpeed)                        > (1e-2 * mfFlowSpeed)) + ...
                            (abs(this.tLastUpdateProps.mfSpecificHeatCapacity - mfSpecificHeatCapacity)  > (1e-2 * mfSpecificHeatCapacity));
            
            mbRecalculate = (mbRecalculate ~= 0);
            
            if any(mbRecalculate)
                for iCell = 1:iTotalCells
                    if mbRecalculate(iCell) && mfMass(iCell) > 0
                        if (abs(this.tLastUpdateProps.mfDensity(iCell) - mfDensity(iCell))  > (1e-1 * mfDensity(iCell)))
                            try
                                this.tLastUpdateProps.mfDynamicViscosity(iCell)     = this.oMT.calculateDynamicViscosity(aoPhases(iCell));
                                this.tLastUpdateProps.mfThermalConductivity(iCell)  = this.oMT.calculateThermalConductivity(aoPhases(iCell));
                                this.tThermalNetwork.miRecalcFailed(iCell) = 0;
                            catch
                                % The internal condensation counter of the
                                % phase will prevent this from happening
                                % too often in a row (some short high
                                % humidity is allowed to give the system
                                % time to react to it and remove it) For
                                % safety an additional check is used here
                                if this.tThermalNetwork.miRecalcFailed(iCell) < 5
                                    this.tThermalNetwork.miRecalcFailed(iCell) = this.tThermalNetwork.miRecalcFailed(iCell) + 1;
                                else
                                    error('Condensation occurs in CDRA')
                                end
                            end
                        end
                        if mfFlowSpeed(iCell) ~= 0
                            fConvectionCoeff               = components.filter.functions.convection_pipe(this.tGeometry.mfD_Hydraulic(iCell), this.tGeometry.mfLength(iCell),...
                                                              mfFlowSpeed(iCell), this.tLastUpdateProps.mfDynamicViscosity(iCell), mfDensity(iCell), this.tLastUpdateProps.mfThermalConductivity(iCell), mfSpecificHeatCapacity(iCell), 1);
                            mfHeatTransferCoefficient(iCell)= fConvectionCoeff * this.tGeometry.mfAbsorberSurfaceArea(iCell);

                        else
                            % In this case the flow speed is zero and
                            % therefore no convection will occur to improve
                            % the heat transfer. Instead only diffusion and
                            % conduction will transport heat (there is no
                            % free convection in space ;)
                            %
                            % The Basic equation for several conductive
                            % thermal resistances in a row is
                            % U = 1/[(s_2/lambda_2)+(s_2/lambda_2)]
                            % Q_dot = U * A * delta_T
                            % In the current calculation the free gas
                            % distance and the radius of the spheres is
                            % identical
                            fAbsorbentConductivity = 0.12; % TO DO: Get value
                            mfHeatTransferCoefficient(iCell) = 1/((this.tGeometry.mfAbsorbentRadius(iCell)/fAbsorbentConductivity) + (this.tGeometry.mfAbsorbentRadius(iCell)/this.tLastUpdateProps.mfThermalConductivity(iCell))) * this.tGeometry.mfAbsorberSurfaceArea(iCell);
                        end
                        
                        % Now there remains only one issue with the current
                        % thermal solver. Phases that are evacuated and
                        % therefore have very low mass result in extremly
                        % high temperature changes (obviously) and the
                        % thermal solver current does not have a logic to
                        % simply solve large changes by equalizing the
                        % temperature between the two connected phases
                        % where such a large change occurs. (simply take
                        % current temperature and heat capacity and
                        % calculate the resulting temperature of the two
                        % phases from that). Therefore the conductance
                        % between the absorbers and the flows for flows
                        % with a pressure below 0.1 bar are set to 0.
                        if aoPhases(iCell).fPressure < 10000
                            mfHeatTransferCoefficient(iCell) = 0;
                        end
                        % in case that this was actually recalculated store the
                        % current properties in the LastUpdateProps struct to
                        % decide when the next recalculation is required
                        this.tLastUpdateProps.mfDensity(iCell)              = mfDensity(iCell);
                        this.tLastUpdateProps.mfFlowSpeed(iCell)            = mfFlowSpeed(iCell);
                        this.tLastUpdateProps.mfSpecificHeatCapacity(iCell) = mfSpecificHeatCapacity(iCell);
                        % now the calculated coefficients have to be set to the
                        % conductor of each cell
                        oConductor = this.poLinearConductors(this.tThermalNetwork.(['csNodes_Flow_Cycle',sCycle]){iCell,1});
                        oConductor.setConductivity(mfHeatTransferCoefficient(iCell));
                    end
                end
            end
        end
	end
end