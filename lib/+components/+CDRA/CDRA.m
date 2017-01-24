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
        %% Old Props: TO DO Check if they still apply
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
        iCycleActive = 2;
        
        %Mass flow rate for the air that is passing through the system.
        %If the subsystem is a CDRA this depends on the value set by the
        %CCAA, but if it is a Vozdukh the values is based on a volumetric
        %flow rate.
        fFlowrateMain = 0;                  % [kg/s]
        
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
        
        % Property to save the original time step specified by the user.
        % CDRA will have to reduce its time step based on its current state
        % (for example if the heater is activated or during air safe)
        fOriginalTimeStep;
        
        % struct that contains three fields to decide if and how the time
        % step has to be reduced. The fields are Heater, AirSafe and
        % PressureEq and contain the value true if the respective process
        % is currently running and the time step has to be reduced because
        % of it. At the end of the update function this information is then
        % used to set the correct time step. This is necessary to prevent
        % one effect from increasing the time step again while another one
        % still requires a smaller step.
        tbReduceTimeStep;
        
        %% New props: To do Explain, cleanup, put everything into nicer properties
        bVozdukh = false;
        
        oThermalSolver;
        
        tSylobead;
        tZeolite13x;
        tZeolite5A;
        
        miNegativesCycleOne;
        miNegativesCycleTwo;
        
        csThermalNetwork_Absorber_CycleOne;
        csThermalNetwork_Absorber_CycleTwo;
        csThermalNetwork_Flow_CycleOne;
        csThermalNetwork_Flow_CycleTwo;
                
        aoBranchesCycleOne = matter.branch.empty();
        aoBranchesCycleTwo = matter.branch.empty();
        
        aoPhasesCycleOne = matter.phase.empty;
        aoPhasesCycleTwo = matter.phase.empty;
        
        aoAbsorberCycleOne = matter.procs.p2p.empty;
        aoAbsorberCycleTwo = matter.procs.p2p.empty;
        
        iCells;
        
        mfAdsorptionHeatFlow;
        mfAdsorptionFlowRate;

        fMinimumTimeStep        = 1e-2;
        fMaximumTimeStep        = 60;
        rMaxChange              = 0.05;
        
        tGeometry;
        
        mfHeaterPower;
        
        mfFrictionFactor;
        
        tLastUpdateProps;
        
        fSteadyStateTimeStep    = 10;
        % deactivated steady state simplification under all
        % circumstances
        fMaxSteadyStateFlowRateChange = 0;
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
            
            this.oTimer.setMinStep(1e-12)
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% Creating the initialization data used for the individual filter beds
            %
            % geometrical data:
            % CDRA Adsorber Bed Cross Section
            % quadratic cross section with ~16 channels of~13mm length according to a presentation at the comsol conference 2015
            % "Multi-Dimensional Simulation of Flows Inside Polydisperse Packed Beds"
            % download link https://www.google.de/url?sa=t&rct=j&q=&esrc=s&source=web&cd=6&cad=rja&uact=8&ved=0ahUKEwjwstb2-OfKAhXEoQ4KHdkUAC8QFghGMAU&url=https%3A%2F%2Fwww.comsol.com%2Fconference2015%2Fdownload-presentation%2F29402&usg=AFQjCNERyzJcfMautp6BfFFUERc1FvISNw&bvm=bv.113370389,d.bGg
            % sorry couldn't find a better one.
            fCrossSection = (18*13E-3)^2; 
            
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
            % TO DO: 13x was previously just adsorbing H2O all the time,
            % currently trying to reduce its mass to get it to desorb as
            % well
            
            this.tGeometry.Zeolite13x.fAbsorberVolume        =   (1-this.tGeometry.Zeolite13x.rVoidFraction)        * fCrossSection * this.tGeometry.Zeolite13x.fLength;
            this.tGeometry.Sylobead.fAbsorberVolume          =   (1-this.tGeometry.Sylobead.rVoidFraction)          * fCrossSection * this.tGeometry.Sylobead.fLength;
            this.tGeometry.Zeolite5A.fAbsorberVolume         =   (1-this.tGeometry.Zeolite5A.rVoidFraction)         * fCrossSection * this.tGeometry.Zeolite5A.fLength;
            
            fMassZeolite13x         = this.tGeometry.Zeolite13x.fAbsorberVolume        * this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density;
            fMassSylobead           = this.tGeometry.Sylobead.fAbsorberVolume          * this.oMT.ttxMatter.Sylobead_B125.ttxPhases.tSolid.Density;
            fMassZeolite5A          = this.tGeometry.Zeolite5A.fAbsorberVolume         * this.oMT.ttxMatter.Zeolite5A_RK38.ttxPhases.tSolid.Density;
            
            % These are the correct estimates for the flow volumes of each
            % bed which are used in the filter adsorber proc for
            % calculations. 
            this.tGeometry.Zeolite13x.fVolumeFlow          =        (this.tGeometry.Zeolite13x.fCrossSection 	* this.tGeometry.Zeolite13x.fLength      * this.tGeometry.Zeolite13x.rVoidFraction);
            this.tGeometry.Sylobead.fVolumeFlow            =        (this.tGeometry.Sylobead.fCrossSection  	* this.tGeometry.Sylobead.fLength * this.tGeometry.Sylobead.rVoidFraction);
            this.tGeometry.Zeolite5A.fVolumeFlow           =        (this.tGeometry.Zeolite5A.fCrossSection  	* this.tGeometry.Zeolite5A.fLength       * this.tGeometry.Zeolite5A.rVoidFraction);
            
        	tInitialization.Zeolite13x.tfMassAbsorber  =   struct('Zeolite13x',fMassZeolite13x);
            tInitialization.Zeolite13x.fTemperature    =   285;
            
        	tInitialization.Sylobead.tfMassAbsorber  =   struct('Sylobead_B125',fMassSylobead);
            tInitialization.Sylobead.fTemperature    =   285;
            
        	tInitialization.Zeolite5A.tfMassAbsorber  =   struct('Zeolite5A',fMassZeolite5A);
            tInitialization.Zeolite5A.fTemperature    =   285;
            
            % Sets the cell numbers used for the individual filters
            tInitialization.Zeolite13x.iCellNumber = 5;
            tInitialization.Sylobead.iCellNumber = 5;
            tInitialization.Zeolite5A.iCellNumber = 10;
            
            % Values for the mass transfer coefficient can be found in the
            % paper ICES-2014-268. Here the values for Zeolite5A are used
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
            this.tGeometry.Zeolite13x.fAbsorberSurfaceArea      = (15e-6)*(tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 5.5e-9));
            % For Sylobead the average diameter is mentioned to be 2.25 mm:
            % 4/3*pi*(2.25/2)^3 = 5.96 mm3, while the area is 
            % 4*pi*(2.25/2)^2 = 15.9 mm2
            this.tGeometry.Sylobead.fAbsorberSurfaceArea        = (15.9e-6)*(tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 5.96e-9));
            % For 5a the average diameter is mentioned to be 2.2.1 mm:
            % 4/3*pi*(2.1/2)^3 = 4.85 mm3, while the area is 
            % 4*pi*(2.1/2)^2 = 13.85 mm2
            this.tGeometry.Zeolite5A.fAbsorberSurfaceArea       = (13.85e-6)*(tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 4.85e-9));
            
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
                fTemperatureFlow        = this.tAtmosphere.fTemperature;
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

                fDensityAir = 1.2; % at 20°C and 1 atm
                cAirHelper = matter.helper.phase.create.air_custom(this.toStores.([(csTypes{iType}), '_1']), fFlowVolume, struct('CO2', (fFlowVolume*fDensityAir*this.tAtmosphere.fCO2Percent)), this.tAtmosphere.fTemperature, 0, this.tAtmosphere.fPressure);

                % The filter and flow phase total masses provided in the
                % tInitialization struct have to be divided by the number of
                % cells to obtain the tfMass struct for each phase of each
                % cell. Currently the assumption here is that each cell has the
                % same size.
                csAbsorberSubstances = fieldnames(tInitialization.(csTypes{iType}).tfMassAbsorber);
                for iK = 1:length(csAbsorberSubstances)
                    tfMassesAbsorber.(csAbsorberSubstances{iK}) = tInitialization.(csTypes{iType}).tfMassAbsorber.(csAbsorberSubstances{iK})/iCellNumber;
                end
                csFlowSubstances = fieldnames(cAirHelper{1});
                for iK = 1:length(csFlowSubstances)
                    tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                end

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
                        oFilterPhase = matter.phases.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(fAbsorberVolume/iCellNumber), fTemperatureAbsorber, fPressure);

                        oFlowPhase = matter.phases.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow,(fFlowVolume/iCellNumber), fTemperatureFlow);

                        % An individual adsorption and desorption Exme and P2P is
                        % required because it is possible that a few substances are
                        % beeing desorbed at the same time as others are beeing
                        % adsorbed
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
                        this.(['t',(csTypes{iType})]).(['Bed_',num2str(iFilter)]).mfFrictionFactor(iCell) = 1e8/iCellNumber;
                    
                    end
                    this.(['t',(csTypes{iType})]).(['Bed_',num2str(iFilter)]).iCellNumber   = iCellNumber;

                    this.(['t',(csTypes{iType})]).(['Bed_',num2str(iFilter)]).mfCellVolume(:,1)   = [this.toStores.(sName).aoPhases(2:2:end).fVolume];

                    this.(['t',(csTypes{iType})]).(['Bed_',num2str(iFilter)]).mfDensitiesOld(:,1) = [this.toStores.(sName).aoPhases(2:2:end).fDensity]; 

                    % in order to save calculation steps this helper is only
                    % calculated once and then used in all iterations since it
                    % remains constant.
                    this.(['t',(csTypes{iType})]).(['Bed_',num2str(iFilter)]).mfHelper1 = ((fCrossSection^2) ./ this.(['t',(csTypes{iType})]).(['Bed_',num2str(iFilter)]).mfCellVolume);
                    
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
            matter.branch(this, 'Zeolite5A_1.OutletVacuum', {}, 'CDRA_Vent_1', 'CDRA_Vent_1');
            matter.branch(this, 'Zeolite5A_1.OutletAirSafe', {}, 'CDRA_AirSafe_1', 'CDRA_AirSafe_1');
            
            oFlowPhase = this.toStores.Zeolite5A_2.toPhases.(['Flow_',num2str(iCellNumber)]);
            matter.procs.exmes.gas(oFlowPhase, 'OutletVacuum');
            matter.procs.exmes.gas(oFlowPhase, 'OutletAirSafe');
            matter.branch(this, 'Zeolite5A_2.OutletVacuum', {}, 'CDRA_Vent_2', 'CDRA_Vent_2');
            matter.branch(this, 'Zeolite5A_2.OutletAirSafe', {}, 'CDRA_AirSafe_2', 'CDRA_AirSafe_2');
            
            
            %% For easier handling the branches are ordered in the order through which the flow goes for each of the two cycles
            % Cycle One
            this.iCells = 2*tInitialization.Sylobead.iCellNumber + 2*tInitialization.Zeolite13x.iCellNumber + tInitialization.Zeolite5A.iCellNumber;
            iSize = this.iCells + 1;
            
            this.miNegativesCycleOne = ones(iSize,1);
            
            this.aoBranchesCycleOne(end+1,1) = this.toBranches.CDRA_Air_In_1;
            this.miNegativesCycleOne(1) = -1; % Inlet branch has to be negative to be an inlet
            
            for iCell = 1:(tInitialization.Sylobead.iCellNumber-1)
                this.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Sylobead_1Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.aoBranchesCycleOne(end+1,1) = this.toBranches.Sylobead1_to_13x1;
            
            for iCell = 1:(tInitialization.Zeolite13x.iCellNumber-1)
                this.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Zeolite13x_1Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.aoBranchesCycleOne(end+1,1) = this.toBranches.Zeolite13x1_to_5A1;
            
            for iCell = 1:(tInitialization.Zeolite5A.iCellNumber-1)
                this.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Zeolite5A_1Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.aoBranchesCycleOne(end+1,1) = this.toBranches.Zeolite5A1_to_13x2;
            
            for iCell = tInitialization.Zeolite13x.iCellNumber:-1:2
                this.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Zeolite13x_2Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                this.miNegativesCycleOne(length(this.aoBranchesCycleOne)) = -1;
            end
            % Connection Branch
            this.aoBranchesCycleOne(end+1,1) = this.toBranches.Sylobead2_to_13x2;
            this.miNegativesCycleOne(length(this.aoBranchesCycleOne)) = -1;
            
            for iCell = tInitialization.Sylobead.iCellNumber:-1:2
                this.aoBranchesCycleOne(end+1,1) = this.toBranches.(['Sylobead_2Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                this.miNegativesCycleOne(length(this.aoBranchesCycleOne)) = -1;
            end
            % Connection Branch
            this.aoBranchesCycleOne(end+1,1) = this.toBranches.CDRA_Air_Out_1;
            
            % cycle 2
            
            this.miNegativesCycleTwo = ones(iSize,1);
            
            this.aoBranchesCycleTwo(end+1,1) = this.toBranches.CDRA_Air_In_2;
            this.miNegativesCycleTwo(1) = -1; % Inlet branch has to be negative to be an inlet
            
            for iCell = 1:(tInitialization.Sylobead.iCellNumber-1)
                this.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Sylobead_2Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.aoBranchesCycleTwo(end+1,1) = this.toBranches.Sylobead2_to_13x2;
            
            for iCell = 1:(tInitialization.Zeolite13x.iCellNumber-1)
                this.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Zeolite13x_2Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.aoBranchesCycleTwo(end+1,1) = this.toBranches.Zeolite13x2_to_5A2;
            
            for iCell = 1:(tInitialization.Zeolite5A.iCellNumber-1)
                this.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Zeolite5A_2Flow',num2str(iCell),'toFlow',num2str(iCell+1)]);
            end
            % Connection Branch
            this.aoBranchesCycleTwo(end+1,1) = this.toBranches.Zeolite5A2_to_13x1;
            
            for iCell = tInitialization.Zeolite13x.iCellNumber:-1:2
                this.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Zeolite13x_1Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                this.miNegativesCycleTwo(length(this.aoBranchesCycleTwo)) = -1;
            end
            % Connection Branch
            this.aoBranchesCycleTwo(end+1,1) = this.toBranches.Sylobead1_to_13x1;
            this.miNegativesCycleTwo(length(this.aoBranchesCycleTwo(end,1))) = -1;
            
            for iCell = tInitialization.Sylobead.iCellNumber:-1:2
                this.aoBranchesCycleTwo(end+1,1) = this.toBranches.(['Sylobead_2Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                this.miNegativesCycleTwo(length(this.aoBranchesCycleTwo)) = -1;
            end
            % Connection Branch
            this.aoBranchesCycleTwo(end+1,1) = this.toBranches.CDRA_Air_Out_2;
            
            % initializes the adsorption heat flow property
            this.mfAdsorptionHeatFlow 	= zeros(this.iCells+tInitialization.Zeolite5A.iCellNumber,1);
            this.mfAdsorptionFlowRate 	= zeros(this.iCells+tInitialization.Zeolite5A.iCellNumber,1);
            this.mfHeaterPower          = zeros(this.iCells+tInitialization.Zeolite5A.iCellNumber,1);
            
            this.tLastUpdateProps.mfDensity              = zeros(this.iCells,1);
            this.tLastUpdateProps.mfFlowSpeed            = zeros(this.iCells,1);
            this.tLastUpdateProps.mfSpecificHeatCapacity = zeros(this.iCells,1);

            this.tLastUpdateProps.mfDynamicViscosity     = zeros(this.iCells,1);
            this.tLastUpdateProps.mfThermalConductivity  = zeros(this.iCells,1);
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
                end
            end
            
            % adds the lumped parameter thermal solver to calculate the
            % convective and conductive heat transfer
            this.oThermalSolver = solver.thermal.lumpedparameter(this);
            
            % sets the minimum time step that can be used by the thermal
            % solver
            this.oThermalSolver.fMinimumTimeStep = 0.01;
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
            mfLength = zeros(this.iCells,1);
            mfAbsorberSurfaceArea = zeros(this.iCells,1);
            mfD_Hydraulic = zeros(this.iCells,1);
            
            for iCell = 1:this.tSylobead.Bed_1.iCellNumber
                this.aoPhasesCycleOne(end+1,1)   = this.toStores.Sylobead_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Sylobead_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tSylobead.Bed_1.mfFrictionFactor(iCell);
                
                mfLength(length(this.aoPhasesCycleOne),1)               = this.tGeometry.Sylobead.fLength/this.tSylobead.Bed_1.iCellNumber;
                mfAbsorberSurfaceArea(length(this.aoPhasesCycleOne),1)  = this.tGeometry.Sylobead.fAbsorberSurfaceArea/this.tSylobead.Bed_1.iCellNumber;
                mfD_Hydraulic(length(this.aoPhasesCycleOne),1)          = this.tGeometry.Sylobead.fD_Hydraulic;
                
                this.csThermalNetwork_Absorber_CycleOne{end+1,1} = [this.sName ,'__Sylobead_1__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleOne{end+1,1} = ['Sylobead_1ConvectiveConductor_', num2str(iCell)];
                
            end
                
            for iCell = 1:this.tZeolite13x.Bed_1.iCellNumber
                this.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite13x_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tZeolite13x.Bed_1.mfFrictionFactor(iCell);
                
                mfLength(length(this.aoPhasesCycleOne),1)                = this.tGeometry.Zeolite13x.fLength/this.tZeolite13x.Bed_1.iCellNumber;
                mfAbsorberSurfaceArea(length(this.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite13x.fAbsorberSurfaceArea/this.tZeolite13x.Bed_1.iCellNumber;
                mfD_Hydraulic(length(this.aoPhasesCycleOne),1)           = this.tGeometry.Zeolite13x.fD_Hydraulic;
                
                this.csThermalNetwork_Absorber_CycleOne{end+1,1} = [this.sName ,'__Zeolite13x_1__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleOne{end+1,1} = ['Zeolite13x_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tZeolite5A.Bed_1.iCellNumber
                this.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite5A_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tZeolite5A.Bed_1.mfFrictionFactor(iCell);
                
                mfLength(length(this.aoPhasesCycleOne),1)                = this.tGeometry.Zeolite5A.fLength/this.tZeolite5A.Bed_1.iCellNumber;
                mfAbsorberSurfaceArea(length(this.aoPhasesCycleOne),1)   = this.tGeometry.Zeolite5A.fAbsorberSurfaceArea/this.tZeolite5A.Bed_1.iCellNumber;
                mfD_Hydraulic(length(this.aoPhasesCycleOne),1)     	  = this.tGeometry.Zeolite5A.fD_Hydraulic;
                
                this.csThermalNetwork_Absorber_CycleOne{end+1,1} = [this.sName ,'__Zeolite5A_1__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleOne{end+1,1} = ['Zeolite5A_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tZeolite13x.Bed_2.iCellNumber:-1:1
                this.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite13x_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tZeolite13x.Bed_2.mfFrictionFactor(iCell);
                
                mfLength(length(this.aoPhasesCycleOne),1)              = this.tGeometry.Zeolite13x.fLength/this.tZeolite13x.Bed_2.iCellNumber;
                mfAbsorberSurfaceArea(length(this.aoPhasesCycleOne),1) = this.tGeometry.Zeolite13x.fAbsorberSurfaceArea/this.tZeolite13x.Bed_2.iCellNumber;
                mfD_Hydraulic(length(this.aoPhasesCycleOne),1)    	 = this.tGeometry.Zeolite13x.fD_Hydraulic;
                
                this.csThermalNetwork_Absorber_CycleOne{end+1,1} = [this.sName ,'__Zeolite13x_2__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleOne{end+1,1} = ['Zeolite13x_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tSylobead.Bed_2.iCellNumber:-1:1
                this.aoPhasesCycleOne(end+1,1) = this.toStores.Sylobead_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Sylobead_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tSylobead.Bed_2.mfFrictionFactor(iCell);
                
                mfLength(length(this.aoPhasesCycleOne),1)              = this.tGeometry.Sylobead.fLength/this.tSylobead.Bed_2.iCellNumber;
                mfAbsorberSurfaceArea(length(this.aoPhasesCycleOne),1) = this.tGeometry.Sylobead.fAbsorberSurfaceArea/this.tSylobead.Bed_2.iCellNumber;
                mfD_Hydraulic(length(this.aoPhasesCycleOne),1)    	 = this.tGeometry.Sylobead.fD_Hydraulic;
                
                this.csThermalNetwork_Absorber_CycleOne{end+1,1} = [this.sName ,'__Sylobead_2__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleOne{end+1,1} = ['Sylobead_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tZeolite5A.Bed_2.iCellNumber
                this.csThermalNetwork_Absorber_CycleOne{end+1,1} = [this.sName ,'__Zeolite5A_1__Absorber_',num2str(iCell)];
            end
            
            this.aoPhasesCycleOne(end+1,1) = this.toBranches.CDRA_Air_Out_1.coExmes{2}.oPhase;
            
            this.tGeometry.mfLength                 = mfLength;
            this.tGeometry.mfAbsorberSurfaceArea    = mfAbsorberSurfaceArea;
            this.tGeometry.mfD_Hydraulic            = mfD_Hydraulic;
            
            % Cycle Two
            for iCell = 1:this.tSylobead.Bed_2.iCellNumber
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Sylobead_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Sylobead_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                this.csThermalNetwork_Absorber_CycleTwo{end+1,1} = [this.sName ,'__Sylobead_2__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleTwo{end+1,1} = ['Sylobead_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tZeolite13x.Bed_2.iCellNumber
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite13x_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                this.csThermalNetwork_Absorber_CycleTwo{end+1,1} = [this.sName ,'__Zeolite13x_2__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleTwo{end+1,1} = ['Zeolite13x_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tZeolite5A.Bed_2.iCellNumber
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite5A_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                this.csThermalNetwork_Absorber_CycleTwo{end+1,1} = [this.sName ,'__Zeolite5A_2__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleTwo{end+1,1} = ['Zeolite5A_2ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tZeolite13x.Bed_1.iCellNumber:-1:1
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite13x_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                this.csThermalNetwork_Absorber_CycleTwo{end+1,1} = [this.sName ,'__Zeolite13x_1__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleTwo{end+1,1} = ['Zeolite13x_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = this.tSylobead.Bed_1.iCellNumber:-1:1
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Sylobead_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Sylobead_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                
                this.csThermalNetwork_Absorber_CycleTwo{end+1,1} = [this.sName ,'__Sylobead_1__Absorber_',num2str(iCell)];
                this.csThermalNetwork_Flow_CycleTwo{end+1,1} = ['Sylobead_1ConvectiveConductor_', num2str(iCell)];
            end
            
            for iCell = 1:this.tZeolite5A.Bed_2.iCellNumber
                this.csThermalNetwork_Absorber_CycleTwo{end+1,1} = [this.sName ,'__Zeolite5A_1__Absorber_',num2str(iCell)];
            end
            
            this.aoPhasesCycleTwo(end+1,1) = this.toBranches.CDRA_Air_Out_2.coExmes{2}.oPhase;
            
            
           
        end
        function setReferencePhase(this, oPhase)
                this.oAtmosphere = oPhase;
        end
        
        function setHeaterPower(this, fPower)
            % this function is used to set the power of the electrical
            % heaters inside the filter. If no heaters are used just leave
            % this property at zero at all times.
            this.fHeaterPower = fPower;
            
            % in case that a new heater power was set the function to
            % recalculate the thermal properties of the filter has to be
            % called to ensure that the change is recoginzed by the model
            this.calculateThermalProperties();
        end
        
        function setNumericProperties(this,rMaxChange,fMinimumTimeStep,fMaximumTimeStep, iInternalSteps)
            % in order to only recalculate these properties when they are
            % actually reset a specific function has to be used to set them
            
            this.rMaxChange = rMaxChange;

            this.fMinimumTimeStep = fMinimumTimeStep;

            this.fMaximumTimeStep = fMaximumTimeStep;
            
            this.iInternalSteps = iInternalSteps;
            
            % the numerical properties of the filter give the overall
            % allowed changes and timesteps over one complete step. In
            % order to increase the maximum allowable timestep the solver
            % divides this into several internal steps (if the user chose
            % this option)
            this.rMaxPartialChange   = this.rMaxChange/this.iInternalSteps;
            this.fMaxPartialTimeStep = this.fMaximumTimeStep/this.iInternalSteps;
            this.fMinPartialTimeStep = this.fMinimumTimeStep/this.iInternalSteps;
        end
        function update(this,~)
            
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
            
            fInitTimeStep = 10;
            %% Cycle Change handling:
            % in case the cycle is switched a number of changes has to be
            % made to the flowrates, which are only necessary ONCE!
            % (setting the flowrates of all branches to zero, and only then
            % recalculate the filter)
            if (this.iCycleActive == 2) && (mod(this.oTimer.fTime, this.fCycleTime * 2) < (this.fCycleTime)) && (this.oTimer.iTick ~= 0)
                % On cycle change all flow rates are momentarily set to zero
                for iBranch = 1:length(this.aoBranchesCycleTwo)
                    this.aoBranchesCycleTwo(iBranch).oHandler.setFlowRate(0);
                end
                
                % In order to get the flow rate calculation to higher
                % speeds at each cycle change the phases are preset to
                % contain pressures close to the final pressure (after the
                % initial flowrate setup)
                mfPressureDiff = this.mfFrictionFactor .* (this.oParent.toChildren.(this.sAsscociatedCCAA).fCDRA_FlowRate)^2;
                mfPressurePhase = zeros(this.iCells+1,1);
                for iPhase = 1:length(this.aoPhasesCycleOne)
                    mfPressurePhase(iPhase) = this.aoPhasesCycleOne(end).fPressure + sum(mfPressureDiff(iPhase:end));
                end
                % The time step for the cycle change case is set to ONE
                % second, therefore the calculated mass difference is
                % directly the required flow rate that has to go into the
                % phase to reach the desired mass
                mfMassDiff = (mfPressurePhase - [this.aoPhasesCycleOne.fPressure]')./[this.aoPhasesCycleOne.fMassToPressure]';
                
                % Now the mass difference required in the phases is
                % translated into massflows for the branches for the next
                % second
                mfFlowRate = zeros(this.iCells,1);
                for iBranch = 1:(length(this.aoBranchesCycleOne)-1)
                    mfFlowRate(iBranch) = this.miNegativesCycleOne(iBranch) * sum(mfMassDiff(iBranch:end-1))/fInitTimeStep;
                    this.aoBranchesCycleOne(iBranch).oHandler.setFlowRate(mfFlowRate(iBranch));
                end
                
                this.iCycleActive = 1;
                % Sets the correct cells for the adsorption P2Ps to store
                % their values
                for iP2P = 1:length(this.aoAbsorberCycleOne)
                    this.aoAbsorberCycleOne(iP2P).iCell = iP2P;
                end
                for iP2P = 1:this.tZeolite5A.Bed_2.iCellNumber
                    this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).iCell = this.iCells + iP2P;
                end
                
                this.setTimeStep(fInitTimeStep);
                
                % TO DO: Heaters, Airsafe, desorption!
                
            elseif (this.iCycleActive == 1) && (mod(this.oTimer.fTime, this.fCycleTime * 2) >= (this.fCycleTime)) && (this.oTimer.iTick ~= 0)
                % On cycle change all flow rates are momentarily set to zero
                for iBranch = 1:length(this.aoBranchesCycleOne)
                    this.aoBranchesCycleOne(iBranch).oHandler.setFlowRate(0);
                end
                
                % In order to get the flow rate calculation to higher
                % speeds at each cycle change the phases are preset to
                % contain pressures close to the final pressure (after the
                % initial flowrate setup)
                mfPressureDiff = this.mfFrictionFactor .* (this.oParent.toChildren.(this.sAsscociatedCCAA).fCDRA_FlowRate)^2;
                mfPressurePhase = zeros(this.iCells+1,1);
                for iPhase = 1:length(this.aoPhasesCycleTwo)
                    mfPressurePhase(iPhase) = this.aoPhasesCycleTwo(end).fPressure + sum(mfPressureDiff(iPhase:end));
                end
                % The time step for the cycle change case is set to ONE
                % second, therefore the calculated mass difference is
                % directly the required flow rate that has to go into the
                % phase to reach the desired mass
                mfMassDiff = (mfPressurePhase - [this.aoPhasesCycleTwo.fPressure]')./[this.aoPhasesCycleTwo.fMassToPressure]';
                
                % Now the mass difference required in the phases is
                % translated into massflows for the branches for the next
                % second
                mfFlowRate = zeros(this.iCells,1);
                for iBranch = 1:(length(this.aoBranchesCycleTwo)-1)
                    mfFlowRate(iBranch) = this.miNegativesCycleTwo(iBranch) * sum(mfMassDiff(iBranch:(end-1)))/fInitTimeStep;
                    this.aoBranchesCycleTwo(iBranch).oHandler.setFlowRate(mfFlowRate(iBranch));
                end
                
                this.iCycleActive = 2;
                
                for iP2P = 1:length(this.aoAbsorberCycleOne)
                    this.aoAbsorberCycleTwo(iP2P).iCell = iP2P;
                end
                for iP2P = 1:this.tZeolite5A.Bed_1.iCellNumber
                    this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).iCell = this.iCells + iP2P;
                end
                
                this.setTimeStep(fInitTimeStep);
                
                % TO DO: Heaters, Airsafe, desorption!
                
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
                    this.updateInterCellFlowrates()
                end
            end
            
            % Handling the flowrates of the asscoiated CCAA. Hm so there
            % are a few options for this:
            % Option 1: CCAA also receives dynamic flow rates
            % Option 2: CCAA flowrates are adapted here based on the
            % dynamic flowrates of CDRA
            %
            % Overall regarding the dynamic flowrates. The filter will work
            % without dynamic flowrates (just setting a constant FR and
            % subtracting all absorber FRs) if the thermal part of the
            % model is not included
            if this.iCycleActive == 1                
                % Flow going out of CCAA into CDRA
                fFlowRate_CCAA_CDRA = -this.aoBranchesCycleOne(1).oHandler.fRequestedFlowRate;
                % Flow rate going from CDRA back to the CCAA
                fFlowRate_CDRA_CCAA = this.aoBranchesCycleOne(end).oHandler.fRequestedFlowRate;
            else
                % Flow going out of CCAA into CDRA
                fFlowRate_CCAA_CDRA = this.aoBranchesCycleTwo(1).oHandler.fRequestedFlowRate;
                % Flow rate going from CDRA back to the CCAA
                fFlowRate_CDRA_CCAA = this.aoBranchesCycleTwo(end).oHandler.fRequestedFlowRate;
            end
            
            % TO DO: TS without large changes is currently limited to
            % ~0.035s tickdelta over 100 ticks. Maybe use the logic to
            % calculate the inital mass within the phases to get the
            % flowrates?
            
            % TO DO: For larger volumes the CHX crashes because the
            % flowrate through the CHX is increased abnormally by this
            % logic. How can this be solved? The mass entering CDRA should
            % pass through the CHX first to remove the humidity....
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
            
            this.calculateThermalProperties()
            % since the thermal solver currently only has constant time
            % steps it currently uses the same time step as the filter
            % model.
            this.oThermalSolver.setTimestep(this.fTimeStep);
        end
    end
    
    methods (Access = protected)
        function updateInterCellFlowrates(this, ~)
            
            if this.iCycleActive == 1
                sCycle = 'One';
            else
                sCycle = 'Two';
            end
            % well the phase pressures have not been updated ( the
            % rMaxChange was set to inf) in order to do controlled updates
            % now
            for iPhase = 1:length(this.(['aoPhasesCycle',sCycle]))
                this.(['aoPhasesCycle',sCycle])(iPhase).update();
            end
                
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
            mfCellMass(:,1)   	= [this.(['aoPhasesCycle',sCycle])(2:end).fMass];
%            	mfCellPressure(:,1)	= [this.(['aoPhasesCycle',sCycle]).fPressure];
            
            mfFlowRates(:,1) = ones(this.iCells+1,1) .* this.fFlowrateMain;
            mfFlowRates(2:end,1) = mfFlowRates(2:end,1) - this.mfAdsorptionFlowRate(1:this.iCells);
            
            % In order to get the flow rate calculation to higher
            % speeds at each cycle change the phases are preset to
            % contain pressures close to the final pressure (after the
            % initial flowrate setup)
            mfPressureDiff = this.mfFrictionFactor .* (this.oParent.toChildren.(this.sAsscociatedCCAA).fCDRA_FlowRate)^2;
            mfPressurePhase = zeros(this.iCells+1,1);
            for iPhase = 1:length(this.(['aoPhasesCycle',sCycle]))
                mfPressurePhase(iPhase) = this.(['aoPhasesCycle',sCycle])(end).fPressure + sum(mfPressureDiff(iPhase:end));
            end
            % The time step for the cycle change case is set to ONE
            % second, therefore the calculated mass difference is
            % directly the required flow rate that has to go into the
            % phase to reach the desired mass
            mfMassDiff = (mfPressurePhase - [this.(['aoPhasesCycle',sCycle]).fPressure]')./[this.(['aoPhasesCycle',sCycle]).fMassToPressure]';

            % Now the time step can be calculated by using the maximum
            % allowable mass change within one step
            fTimeStep = min(1./(abs(mfMassDiff(1:end-1)) ./ (this.rMaxChange .* mfCellMass)));
            if fTimeStep > this.fMaximumTimeStep
                fTimeStep = this.fMaximumTimeStep;
            elseif fTimeStep  <= this.fMinimumTimeStep
                fTimeStep = this.fMinimumTimeStep;
            end
            
            abReduceMassDiff = abs(mfMassDiff(1:end-1)) > (this.rMaxChange .* mfCellMass);
            mfMassDiff(abReduceMassDiff) = sign(mfMassDiff(abReduceMassDiff)).*(this.rMaxChange .* mfCellMass(abReduceMassDiff));
            
            % Now the mass difference required in the phases is
            % translated into massflows for the branches for the next
            % second
            mfFlowRatesNew = zeros(this.iCells+1,1);
            for iBranch = 1:(length(this.(['aoBranchesCycle',sCycle])))
                mfFlowRatesNew(iBranch) = this.(['miNegativesCycle',sCycle])(iBranch) * (mfFlowRates(iBranch) + (sum(mfMassDiff(iBranch:end))/fTimeStep));
                
                this.(['aoBranchesCycle',sCycle])(iBranch).oHandler.setFlowRate(mfFlowRatesNew(iBranch));
            end

            this.setTimeStep(fTimeStep);
        end
        
        function calculateThermalProperties(this)
            
            if this.iCycleActive == 1
                sCycle = 'One';
            else
                sCycle = 'Two';
            end
            
            iTotalCells = length(this.mfAdsorptionHeatFlow);
            % Sets the heat source power in the absorber material as a
            % combination of the heat of absorption and the heater power.
            % Note that the heater power can also be negative resulting in
            % cooling.
            mfHeatFlow              = this.mfAdsorptionHeatFlow + this.mfHeaterPower;
            for iCell = 1:iTotalCells                                           
                oCapacity = this.poCapacities(this.(['csThermalNetwork_Absorber_Cycle',sCycle]){iCell,1});
                oCapacity.oHeatSource.setPower(mfHeatFlow(iCell));
            end
            
            % Now the convective heat transfer between the absorber material
            % and the flow phases has to be calculated, this is only done
            % for the phases currently within the active cycle
            
            % alternative solution for the case without flowspeed? Use
            % just thermal conductivity of fluid and the MaxFreeDistance to
            % calculate a HeatTransferCoeff?
            % D_Hydraulic and fLength defined in geometry struct
            mfDensity                       = zeros(this.iCells,1);
            mfFlowSpeed                     = zeros(this.iCells,1);
            mfSpecificHeatCapacity          = zeros(this.iCells,1);
            mfHeatTransferCoefficient       = zeros(this.iCells,1);
            aoPhases                        = this.(['aoPhasesCycle',sCycle]);
            aoBranches                      = this.(['aoBranchesCycle',sCycle]);
            % gets the required properties for each cell and stores them in
            % variables for easier access
          	for iCell = 1:this.iCells
                mfDensity(iCell)                = aoPhases.fDensity;
                mfFlowSpeed(iCell)              = (abs(aoBranches(iCell).fFlowRate) + abs(aoBranches(iCell+1).fFlowRate))/(2*mfDensity(iCell));
                mfSpecificHeatCapacity(iCell)   = aoPhases(iCell).fSpecificHeatCapacity;
            end
            
            % In order to limit the recalculation of the convective heat
            % exchange coefficient to a manageable degree they are only
            % recalculated if any relevant property changed by at least 1%
            mbRecalculate = (abs(this.tLastUpdateProps.mfDensity - mfDensity)                            > (1e-2 * mfDensity)) +...
                            (abs(this.tLastUpdateProps.mfFlowSpeed - mfFlowSpeed)                        > (1e-2 * mfFlowSpeed)) + ...
                            (abs(this.tLastUpdateProps.mfSpecificHeatCapacity - mfSpecificHeatCapacity)  > (1e-2 * mfSpecificHeatCapacity));
            
            mbRecalculate = (mbRecalculate ~= 0);
            
            if any(mbRecalculate)
                for iCell = 1:this.iCells
                    if mbRecalculate(iCell)
                        if (abs(this.tLastUpdateProps.mfDensity(iCell) - mfDensity(iCell))  > (1e-1 * mfDensity(iCell)))
                            this.tLastUpdateProps.mfDynamicViscosity(iCell)     = this.oMT.calculateDynamicViscosity(aoPhases(iCell));
                            this.tLastUpdateProps.mfThermalConductivity(iCell)  = this.oMT.calculateThermalConductivity(aoPhases(iCell));
                        end
                        fConvectionCoeff               = components.filter.functions.convection_pipe(this.tGeometry.mfD_Hydraulic(iCell), this.tGeometry.mfLength(iCell),...
                                                          mfFlowSpeed(iCell), this.tLastUpdateProps.mfDynamicViscosity(iCell), mfDensity(iCell), this.tLastUpdateProps.mfThermalConductivity(iCell), mfSpecificHeatCapacity(iCell), 1);
                        mfHeatTransferCoefficient(iCell)= fConvectionCoeff * this.tGeometry.mfAbsorberSurfaceArea(iCell);

                        % in case that this was actually recalculated store the
                        % current properties in the LastUpdateProps struct to
                        % decide when the next recalculation is required
                        this.tLastUpdateProps.mfDensity(iCell)              = mfDensity(iCell);
                        this.tLastUpdateProps.mfFlowSpeed(iCell)            = mfFlowSpeed(iCell);
                        this.tLastUpdateProps.mfSpecificHeatCapacity(iCell) = mfSpecificHeatCapacity(iCell);
                        
                        % now the calculated coefficients have to be set to the
                        % conductor of each cell
                        oConductor = this.poLinearConductors(this.(['csThermalNetwork_Flow_Cycle',sCycle]){iCell,1});
                        oConductor.setConductivity(mfHeatTransferCoefficient(iCell));
                    end
                end
            end
            % TO DO: alternative case if the flowrate is 0, currently no
            % heat exchange takes place when the flow rate is zero. For
            % this case the heat exchange would be based on conduction and
            % diffusion. Probably the assumption that only conduction is
            % occuring makes sense and for that case the maximum distance
            % of free gas and the conductivity of the gas could be used to
            % calculate the heat exchange coefficient.
%             this.this.tGeometry.fMaximumFreeGasDistance
            
        end
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            this.update();
        end
	end
end