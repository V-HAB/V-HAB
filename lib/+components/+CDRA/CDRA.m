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
        
        %% New props: To do Explain
        bVozdukh = false;
        
        oThermalSolver;
        
        tSylobead;
        tZeolite13x;
        tZeolite5A;
        
        miNegativesCycleOne;
        miNegativesCycleTwo;
        aoBranchesCycleOne = matter.branch.empty();
        aoBranchesCycleTwo = matter.branch.empty();
        
        aoPhasesCycleOne = matter.phase.empty;
        aoPhasesCycleTwo = matter.phase.empty;
        
        aoAbsorberCycleOne = matter.procs.p2p.empty;
        aoAbsorberCycleTwo = matter.procs.p2p.empty;
        
        iCells;
        
        mfAdsorptionHeatFlow;
        mfAdsorptionFlowRate;

        iInternalSteps          = 200;
        fMinimumTimeStep        = 1e-10;
        fMaximumTimeStep        = 60;
        rMaxChange              = 0.05;
        rMaxPartialChange       = 0.05/200;
        fMaxPartialTimeStep     = 60/200;
        fMinPartialTimeStep     = 1e-10/200;
        
        bPressureInitialization = false;
        
        mfFrictionFactor;
        mfHelper1;
        
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
            
            tGeometry.Zeolite5A.fCrossSection       = fCrossSection;
            tGeometry.Sylobead.fCrossSection = fCrossSection;
            tGeometry.Zeolite13x.fCrossSection      = fCrossSection;
            
            % Length for the individual filter material within CDRA
            % according to ICES-2014-160
            tGeometry.Zeolite5A.fLength         =  16.68        *2.54/100;
            tGeometry.Sylobead.fLength   =  6.13         *2.54/100;
            tGeometry.Zeolite13x.fLength        = (5.881+0.84)  *2.54/100;
            
            %From ICES-2014-168 Table 2 e_sorbent
            tGeometry.Zeolite13x.rVoidFraction      = 0.457;
            tGeometry.Zeolite5A.rVoidFraction       = 0.445;
            tGeometry.Sylobead.rVoidFraction = 0.348;
            
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
            
            tGeometry.Zeolite13x.fAbsorberVolume        =   (1-tGeometry.Zeolite13x.rVoidFraction)        * fCrossSection * tGeometry.Zeolite13x.fLength;
            tGeometry.Sylobead.fAbsorberVolume          =   (1-tGeometry.Sylobead.rVoidFraction)   * fCrossSection * tGeometry.Sylobead.fLength;
            tGeometry.Zeolite5A.fAbsorberVolume         =   (1-tGeometry.Zeolite5A.rVoidFraction)         * fCrossSection * tGeometry.Zeolite5A.fLength;
            
            fMassZeolite13x         = tGeometry.Zeolite13x.fAbsorberVolume        * this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density;
            fMassSylobead           = tGeometry.Sylobead.fAbsorberVolume   * this.oMT.ttxMatter.Sylobead_B125.ttxPhases.tSolid.Density;
            fMassZeolite5A          = tGeometry.Zeolite5A.fAbsorberVolume         * this.oMT.ttxMatter.Zeolite5A_RK38.ttxPhases.tSolid.Density;
            
            % this factor times the
            % These are the correct estimates for the flow volumes of each
            % bed which are used in the filter adsorber proc for
            % calculations. 
            tGeometry.Zeolite13x.fVolumeFlow          =        (tGeometry.Zeolite13x.fCrossSection 	* tGeometry.Zeolite13x.fLength      * tGeometry.Zeolite13x.rVoidFraction);
            tGeometry.Sylobead.fVolumeFlow            =        (tGeometry.Sylobead.fCrossSection  	* tGeometry.Sylobead.fLength * tGeometry.Sylobead.rVoidFraction);
            tGeometry.Zeolite5A.fVolumeFlow           =        (tGeometry.Zeolite5A.fCrossSection  	* tGeometry.Zeolite5A.fLength       * tGeometry.Zeolite5A.rVoidFraction);

%             tGeometry.Zeolite13x.fVolumeFlow    = 0.1;
%             tGeometry.Sylobead.fVolumeFlow      = 0.1;
%             tGeometry.Zeolite5A.fVolumeFlow     = 0.1;
            
        	tInitialization.Zeolite13x.tfMassAbsorber  =   struct('Zeolite13x',fMassZeolite13x);
            tInitialization.Zeolite13x.fTemperature    =   293;
            tInitialization.Zeolite13x.iCellNumber     =   20;
            
        	tInitialization.Sylobead.tfMassAbsorber  =   struct('Sylobead_B125',fMassSylobead);
            tInitialization.Sylobead.fTemperature    =   293;
            tInitialization.Sylobead.iCellNumber     =   20;
            
        	tInitialization.Zeolite5A.tfMassAbsorber  =   struct('Zeolite5A',fMassZeolite5A);
            tInitialization.Zeolite5A.fTemperature    =   293;
            tInitialization.Zeolite5A.iCellNumber     =   20;
            
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
            tGeometry.Zeolite13x.fD_Hydraulic           = (4*tGeometry.Zeolite13x.fCrossSection/(4*18*13E-3))* tGeometry.Zeolite13x.rVoidFraction;
            tGeometry.Sylobead.fD_Hydraulic             = (4*tGeometry.Sylobead.fCrossSection/(4*18*13E-3))* tGeometry.Sylobead.rVoidFraction;
            tGeometry.Zeolite5A.fD_Hydraulic            = (4*tGeometry.Zeolite5A.fCrossSection/(4*18*13E-3))* tGeometry.Zeolite13x.rVoidFraction;
            
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
            tGeometry.Zeolite13x.fAbsorberSurfaceArea      = (15e-6)*(tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 5.5e-9));
            % For Sylobead the average diameter is mentioned to be 2.25 mm:
            % 4/3*pi*(2.25/2)^3 = 5.96 mm3, while the area is 
            % 4*pi*(2.25/2)^2 = 15.9 mm2
            tGeometry.Sylobead.fAbsorberSurfaceArea        = (15.9e-6)*(tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 5.96e-9));
            % For 5a the average diameter is mentioned to be 2.2.1 mm:
            % 4/3*pi*(2.1/2)^3 = 4.85 mm3, while the area is 
            % 4*pi*(2.1/2)^2 = 13.85 mm2
            tGeometry.Zeolite5A.fAbsorberSurfaceArea       = (13.85e-6)*(tInitialization.Zeolite13x.tfMassAbsorber.Zeolite13x/(this.oMT.ttxMatter.Zeolite13x.ttxPhases.tSolid.Density * 4.85e-9));
            
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
                fAbsorberVolume         = tGeometry.(csTypes{iType}).fAbsorberVolume;
                fFlowVolume             = tGeometry.(csTypes{iType}).fVolumeFlow;
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
            this.oThermalSolver.fMinimumTimeStep = 1e-1;
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
            
            for iCell = 1:this.tSylobead.Bed_1.iCellNumber
                this.aoPhasesCycleOne(end+1,1)   = this.toStores.Sylobead_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Sylobead_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tSylobead.Bed_1.mfFrictionFactor(iCell);
                this.mfHelper1(end+1,1)          = this.tSylobead.Bed_1.mfHelper1(iCell);
            end
                
            for iCell = 1:this.tZeolite13x.Bed_1.iCellNumber
                this.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite13x_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tZeolite13x.Bed_1.mfFrictionFactor(iCell);
                this.mfHelper1(end+1,1)          = this.tZeolite13x.Bed_1.mfHelper1(iCell);
            end
            
            for iCell = 1:this.tZeolite5A.Bed_1.iCellNumber
                this.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite5A_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tZeolite5A.Bed_1.mfFrictionFactor(iCell);
                this.mfHelper1(end+1,1)          = this.tZeolite5A.Bed_1.mfHelper1(iCell);
            end
            
            for iCell = this.tZeolite13x.Bed_2.iCellNumber:-1:1
                this.aoPhasesCycleOne(end+1,1) = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Zeolite13x_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tZeolite13x.Bed_2.mfFrictionFactor(iCell);
                this.mfHelper1(end+1,1)          = this.tZeolite13x.Bed_2.mfHelper1(iCell);
            end
            
            for iCell = this.tSylobead.Bed_2.iCellNumber:-1:1
                this.aoPhasesCycleOne(end+1,1) = this.toStores.Sylobead_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleOne(end+1,1) = this.toStores.Sylobead_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
                this.mfFrictionFactor(end+1,1)   = this.tSylobead.Bed_2.mfFrictionFactor(iCell);
                this.mfHelper1(end+1,1)          = this.tSylobead.Bed_2.mfHelper1(iCell);
            end
            
            this.aoPhasesCycleOne(end+1,1) = this.toBranches.CDRA_Air_Out_1.coExmes{2}.oPhase;
            
            % Cycle Two
            for iCell = 1:this.tSylobead.Bed_2.iCellNumber
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Sylobead_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Sylobead_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
            end
            
            for iCell = 1:this.tZeolite13x.Bed_2.iCellNumber
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite13x_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite13x_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
            end
            
            for iCell = 1:this.tZeolite5A.Bed_2.iCellNumber
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite5A_2.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
            end
            
            for iCell = this.tZeolite13x.Bed_1.iCellNumber:-1:1
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Zeolite13x_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Zeolite13x_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
            end
            
            for iCell = this.tSylobead.Bed_1.iCellNumber:-1:1
                this.aoPhasesCycleTwo(end+1,1) = this.toStores.Sylobead_1.toPhases.(['Flow_',num2str(iCell)]);
                this.aoAbsorberCycleTwo(end+1,1) = this.toStores.Sylobead_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iCell)]);
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
                    mfFlowRate(iBranch) = this.miNegativesCycleOne(iBranch) * sum(mfMassDiff(iBranch:end-1));
                    this.aoBranchesCycleOne(iBranch).oHandler.setFlowRate(mfFlowRate(iBranch));
                end
                
                % TO DO
                % Somewhere the flowrate of the first branch is overwritten
                % with 0...
                % --> Mass of the phase got to 0 --> check FR from CCAA and
                % that CCAA is updated AFTER CDRA!
                
                
                this.iCycleActive = 1;
                % Sets the correct cells for the adsorption P2Ps to store
                % their values
                for iP2P = 1:length(this.aoAbsorberCycleOne)
                    this.aoAbsorberCycleOne(iP2P).iCell = iP2P;
                end
                for iP2P = 1:this.tZeolite5A.Bed_2.iCellNumber
                    this.toStores.Zeolite5A_2.toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).iCell = this.iCells + iP2P;
                end
                
                this.setTimeStep(1+this.oTimer.fMinimumTimeStep);
                this.toStores.Sylobead_1.setNextTimeStep(1);
                this.toStores.Sylobead_2.setNextTimeStep(1);
                this.toStores.Zeolite13x_1.setNextTimeStep(1);
                this.toStores.Zeolite13x_2.setNextTimeStep(1);
                this.toStores.Zeolite5A_1.setNextTimeStep(1);
                this.toStores.Zeolite5A_2.setNextTimeStep(1);
                
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
                    mfFlowRate(iBranch) = this.miNegativesCycleTwo(iBranch) * sum(mfMassDiff(iBranch:(end-1)));
                    this.aoBranchesCycleTwo(iBranch).oHandler.setFlowRate(mfFlowRate(iBranch));
                end
                
                this.iCycleActive = 2;
                
                for iP2P = 1:length(this.aoAbsorberCycleOne)
                    this.aoAbsorberCycleTwo(iP2P).iCell = iP2P;
                end
                for iP2P = 1:this.tZeolite5A.Bed_1.iCellNumber
                    this.toStores.Zeolite5A_1.toProcsP2P.(['AdsorptionProcessor_',num2str(iP2P)]).iCell = this.iCells + iP2P;
                end
                
                this.setTimeStep(1+this.oTimer.fMinimumTimeStep);
                this.toStores.Sylobead_1.setNextTimeStep(1);
                this.toStores.Sylobead_2.setNextTimeStep(1);
                this.toStores.Zeolite13x_1.setNextTimeStep(1);
                this.toStores.Zeolite13x_2.setNextTimeStep(1);
                this.toStores.Zeolite5A_1.setNextTimeStep(1);
                this.toStores.Zeolite5A_2.setNextTimeStep(1);
                
                this.bPressureInitialization = true;
                
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
            
            this.oParent.toChildren.(this.sAsscociatedCCAA).toChildren.CCAA_CHX.update()
            
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
            
            % this.calculateThermalProperties()
            % since the thermal solver currently only has constant time
            % steps it currently uses the same time step as the filter
            % model.
            this.oThermalSolver.setTimestep(this.fTimeStep);
        end
    end
    
    methods (Access = protected)
        function updateInterCellFlowrates(this, ~)
            % this function is used to calculate the flowrates between the
            % cells of the filter model. It uses a simplified
            % incompressible solution algorithm that was adopted
            % specifically to work for the one dimensional filter model
            % case.
            
            % initialization of the required vectors and matrices, this
            % actually depends on what cycle is currently active, since
            % that changes how the beds are connected
            
            if this.iCycleActive == 1
                mfCellPressure  = zeros(this.iCells+1,   this.iInternalSteps);
                mfMassChange    = zeros(this.iCells+1,   this.iInternalSteps);
                mfFlowRates     = zeros(this.iCells+1,   this.iInternalSteps);

                mfCellMass      = zeros(this.iCells,     this.iInternalSteps);
                mfPressureLoss  = zeros(this.iCells,     this.iInternalSteps);
                mfDeltaFlowRate = zeros(this.iCells,     this.iInternalSteps);

                mfTimeStep      = zeros(1, this.iInternalSteps);

                mfCellMass(:,1)   	= [this.aoPhasesCycleOne(2:end).fMass];
                mfCellPressure(:,1)	= [this.aoPhasesCycleOne.fPressure];
                mfFlowRates(:,1)    = this.miNegativesCycleOne.*[this.aoBranchesCycleOne.fFlowRate]';
                
            else
                mfCellPressure  = zeros(this.iCells+1,   this.iInternalSteps);
                mfMassChange    = zeros(this.iCells+1,   this.iInternalSteps);
                mfFlowRates     = zeros(this.iCells+1,   this.iInternalSteps);

                mfCellMass      = zeros(this.iCells,     this.iInternalSteps);
                mfPressureLoss  = zeros(this.iCells,     this.iInternalSteps);
                mfDeltaFlowRate = zeros(this.iCells,     this.iInternalSteps);

                mfTimeStep      = zeros(1, this.iInternalSteps);

                mfCellMass(:,1)   	= [this.aoPhasesCycleTwo(1:end-1).fMass];
                mfCellPressure(:,1)	= [this.aoPhasesCycleTwo.fPressure];
                mfFlowRates(:,1)    = this.miNegativesCycleTwo.*[this.aoBranchesCycleTwo.fFlowRate]';
            end
            
            % TO DO: The negative part of the cells and the flows do not
            % match (the cell numbering has to be changed to match the
            % flows)
            if this.bPressureInitialization
                mfFlowRates(:,1) = ones(this.iCells+1,1) .* this.fFlowrateMain;
                mfFlowRates(2:end,1) = mfFlowRates(2:end,1) + this.mfAdsorptionFlowRate(1:this.iCells);
                this.bPressureInitialization = false;
            else
                % Sets the inlet flow condition!
                mfFlowRates(1,1) = this.fFlowrateMain;
            end
            
            % Now the internal steps can be performed. Note that this
            % is not an iteration (it would be possible to add that as
            % well) but just an internal calculation with smaller
            % timesteps
            for iStep = 1:this.iInternalSteps
                % pressure loss is calculated by multiplying the
                % friction factor with the mass flow^2. An alternative
                % way to calculate this would be the pressure loss
                % calculation for pipes using a specified length and
                % hydraulic diameter
                mfPressureLoss(:,iStep)  = this.mfFrictionFactor .* abs(mfFlowRates(2:end,iStep)).^2;

                % the overall pressure difference between the cells is
                % defined as the difference between the two cell
                % pressures and from that the pressure loss is
                % subtracted (times the sign of the mass flow to ensure
                % it always acts against it)
                mfDeltaPressure = (mfCellPressure(1:end-1, iStep) - mfCellPressure(2:end, iStep)) - sign(mfFlowRates(2:end,iStep)).*mfPressureLoss(:,iStep);

                % With the pressure difference between the cells the
                % difference of the mass flow per time can be
                % calculated for each cell:
                mfDeltaFlowRate(:,iStep) = (mfDeltaPressure .* this.mfHelper1);
                
                % The following equations are used in the calculation of the new mass flow:
                % F = m*a --> P*A = V_cell*rho*a
                % massflow(t+delta_t) = massflow(t) + rho*A*delta_flowspeed
                % delta_flowspeed = a*delta_t
                % massflow(t+delta_t) = massflow(t) + rho*A*(P*A/V_cell*rho)*delta_t
                % massflow(t+delta_t) = massflow(t) + A*(P*A/V_cell)*delta_t
                % --> DeltaMassFlow = (P*A^2/V_cell)*delta_t 
                % --> A^2/V_cell = fHelper1

                % the highest possible internal time step can now be
                % calculated based on the current mass change for each
                % cell and the current cell mass
                mfTimeStep(1,iStep) = min(abs((this.rMaxPartialChange .* mfCellMass(:,iStep))./((mfFlowRates(1:end-1, iStep) - mfFlowRates(2:end, iStep))))); 

                % in case the time step is outside of the defined
                % boundaries it is reset to these boundaries
                if mfTimeStep(1,iStep) > this.fMaxPartialTimeStep
                    mfTimeStep(1,iStep) = this.fMaxPartialTimeStep;
                elseif isnan(mfTimeStep(1,iStep))
                    mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                elseif mfTimeStep(1,iStep)  <= this.fMinPartialTimeStep
                    mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                end

                % now the new flow rates can be calculated based on the
                % equation derived above
                % massflow(t+delta_t) = massflow(t) + A*(P*A/V_cell)*delta_t
                mfNewInterimFlowRate = mfFlowRates(2:end, iStep) + mfTimeStep(1,iStep) .* mfDeltaFlowRate(:,iStep);

                % another limiting factor for the time step is the fact
                % that the pressure loss should not be allowed to act as
                % a driving force. Therefore, it is necessary to reduce
                % the time step far enough that no sign switch of the
                % flowrate occurs within one timestep
                bDirectionSwitch = sign(mfNewInterimFlowRate) ~= (sign(mfFlowRates(2:end, iStep)));
                % the sign functions also calls a change if 0 is
                % changed to positive or negative value. These cases
                % should not be considered sign changes for this logic
                bDirectionSwitch(mfFlowRates(2:end, iStep) == 0) = false;
                
                mfInterimFlowRate = mfFlowRates(2:end, iStep);

                fMaxTimeStepDirectionChange = min(abs(0.1.*mfInterimFlowRate(bDirectionSwitch)./mfDeltaFlowRate(bDirectionSwitch,iStep)));
                if mfTimeStep(1,iStep) > fMaxTimeStepDirectionChange
                    mfTimeStep(1,iStep) = fMaxTimeStepDirectionChange;

                    if mfTimeStep(1,iStep) > this.fMaxPartialTimeStep
                        mfTimeStep(1,iStep) = this.fMaxPartialTimeStep;
                    elseif isnan(mfTimeStep(1,iStep))
                        mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                    elseif mfTimeStep(1,iStep)  <= this.fMinPartialTimeStep
                        mfTimeStep(1,iStep) = this.fMinPartialTimeStep;
                    end

                    mfNewInterimFlowRate = mfFlowRates(2:end, iStep) + mfTimeStep(1,iStep) .* mfDeltaFlowRate(:,iStep);
                end

                mfNewInterimFlowRate(mfNewInterimFlowRate > this.mfAdsorptionFlowRate(1:this.iCells)) = mfNewInterimFlowRate(mfNewInterimFlowRate > this.mfAdsorptionFlowRate(1:this.iCells)) - this.mfAdsorptionFlowRate(mfNewInterimFlowRate > this.mfAdsorptionFlowRate(1:this.iCells));

                if any(isnan(mfNewInterimFlowRate)) || any(isinf(mfNewInterimFlowRate))
                    keyboard()
                end
                mfFlowRates(2:end, iStep+1) = mfNewInterimFlowRate;

                % since one boundary condition is a flow rate this
                % flowrate is simply kept constant for all steps
                mfFlowRates(1, iStep+1) = mfFlowRates(1, iStep);

                % now an estimate for the new cell mass after this step
                % can be calculated
                mfCellMass(:,iStep+1) = mfCellMass(:,iStep) + ((mfFlowRates(1:end-1, iStep) - mfFlowRates(2:end, iStep)) * mfTimeStep(1,iStep));

               	% and from this an estimate for the new cell pressure
                mfCellPressure(1:end-1,iStep+1) = (mfCellMass(:,iStep+1)./mfCellMass(:,iStep)).*mfCellPressure(1:end-1,iStep);
                % the second boundary condition is the pressure which
              	% is set here
                mfCellPressure(end, iStep+1) = mfCellPressure(end, iStep);

                % to simplify the calculation of the overall flowrate
                % the mass change for each internal step is calculated
                mfMassChange(:,iStep) = mfFlowRates(:,iStep) * mfTimeStep(iStep);
            end
            
            % check if steady state simplification can be used
            if max(abs((mfFlowRates(:, this.iInternalSteps) - mfFlowRates(:, 1))./mfFlowRates(:, 1)) - abs(this.fMaxSteadyStateFlowRateChange.*mfFlowRates(:, 1))) < 0
                % Steady State case: Small discrepancies between the
                % flowrates will always remain in a dynamic calculation.
                % But if the differences are small enough this calculation
                % is used to set the correct steady state flow rates at
                % which the phase mass will no longer change. Of course
                % other effects like temperature changes will remain and
                % therefore the timestep in this case cannot be infinite
                
%             mfFlowRates(:,1) = ones(this.iCells+1,1) .* this.fFlowrateMain;
%             mfFlowRates(2:end,1) = mfFlowRates(2:end,1) + this.mfAdsorptionFlowRate(1:this.iCells);
                if this.bNegativeFlow
                    fInletFlowRate = mfFlowRates(end,1);
                    for iK = 2:length(mfFlowRates(:,1))-1
                        % TO DO: maybe bind this calculation/part of it to
                        % the update functions of the P2Ps?
                        fFlowRate = fInletFlowRate + this.mfAdsorptionFlowRate(iK-1);
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                    end
                    fFlowRate = abs(fInletFlowRate + this.mfAdsorptionFlowRate(iK-1));
                    this.aoBranches(1).oHandler.setFlowRate(fFlowRate);
                else
                    fInletFlowRate = mfFlowRates(1,1);
                    for iK = 2:length(mfFlowRates(:,1))
                        % TO DO: maybe bind this calculation/part of it to
                        % the update functions of the P2Ps?
                        fFlowRate = fInletFlowRate - this.mfAdsorptionFlowRate(iK-1);
                        this.aoBranches(iK).oHandler.setFlowRate(fFlowRate);
                    end
                end
                keyboard()
                this.setTimeStep(this.fSteadyStateTimeStep);
            else
                % dynamic case where the flow rates that were calculated by
                % the dynamic flow rate calculation are set. 
                
                % The overall timestep is the sum over all partial time steps.
                this.setTimeStep(sum(mfTimeStep));
                % The overall flow rate that has to be set is the sum over
                % all internally calculated time steps multiplied with each
                % internal time step and then divided with the overall
                % time step to calculate the time averaged flow rate that
                % results in the same mass changes as the integral over all
                % internal flow rates
                mfFlowRatesNew = sum(mfMassChange,2)/this.fTimeStep;
                
                % for negative and positive flow cases the boundary
                % condition changes the sides and therefore the location of
                % the flow that does not have to be set changes sides
                mfFlowRatesNew = this.miNegativesCycleOne.*mfFlowRatesNew;
                
                if any(isnan(mfFlowRatesNew))
                    keyboard()
                end
                for iBranch = 1:(length(this.aoBranchesCycleOne))
                    this.aoBranchesCycleOne(iBranch).oHandler.setFlowRate(mfFlowRatesNew(iBranch));
                end
            end
            
            % sets the update of the store and phases to be in tune with
            % the updated flow rates. Otherwise changes in the flow rate
            % will be reflected in the pressures too slow
            % TO DO: this should be optimizable by setting the rMaxChange
            % of each phase, however when i tested that it did not work as
            % well. So for now this version will be used as it definitly
            % works
            this.toStores.Sylobead_1.setNextTimeStep(this.fTimeStep);
            this.toStores.Sylobead_2.setNextTimeStep(this.fTimeStep);
            this.toStores.Zeolite13x_1.setNextTimeStep(this.fTimeStep);
            this.toStores.Zeolite13x_2.setNextTimeStep(this.fTimeStep);
            this.toStores.Zeolite5A_1.setNextTimeStep(this.fTimeStep);
            this.toStores.Zeolite5A_2.setNextTimeStep(this.fTimeStep);
        end
        
        function calculateThermalProperties(this)
            
            % TO DO: CHECK THIS, was copied from filter!!!
            
            % Sets the heat source power in the absorber material as a
            % combination of the heat of absorption and the heater power.
            % Note that the heater power can also be negative resulting in
            % cooling.
            mfHeatFlow              = zeros(this.iCells,1);
            for iCell = 1:this.iCells
                mfHeatFlow(iCell)              = this.mfAdsorptionHeatFlow(iCell) + this.fHeaterPower/this.iCells;
                
                                              % Subsystem ,     , Store,                                              
                oCapacity = this.poCapacities([this.sName ,'__',this.sName,'__Absorber_',num2str(iCell)]);
                oCapacity.oHeatSource.setPower(mfHeatFlow(iCell));
            end
            
            % Now the convective heat transfer between the absorber material
            % and the flow phases has to be calculated
            
            % alternative solution for the case without flowspeed? Use
            % just thermal conductivity of fluid and the MaxFreeDistance to
            % calculate a HeatTransferCoeff?
            % D_Hydraulic and fLength defined in geometry struct
            mfDensity                       = zeros(this.iCells,1);
            mfFlowSpeed                     = zeros(this.iCells,1);
            mfSpecificHeatCapacity          = zeros(this.iCells,1);
            mfHeatTransferCoefficient       = zeros(this.iCells,1);
            aoPhase                         = cell(this.iCells,1);
            fLength = (this.tGeometry.fFlowVolume/this.tGeometry.fD_Hydraulic)/this.iCells;
            
            % gets the required properties for each cell and stores them in
            % variables for easier access
          	for iCell = 1:this.iCells
                mfDensity(iCell)                = this.toStores.(this.sName).aoPhases(iCell*2).fDensity;
                mfFlowSpeed(iCell)              = (abs(this.aoBranches(iCell).fFlowRate) + abs(this.aoBranches(iCell+1).fFlowRate))/(2*mfDensity(iCell));
                mfSpecificHeatCapacity(iCell)   = this.toStores.(this.sName).aoPhases(iCell*2).fSpecificHeatCapacity;
                
                aoPhase{iCell} = this.toStores.(this.sName).aoPhases(iCell*2);
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

                        fDynamicViscosity              = this.oMT.calculateDynamicViscosity(aoPhase{iCell});
                        fThermalConductivity           = this.oMT.calculateThermalConductivity(aoPhase{iCell});
                        fConvectionCoeff               = components.filter.functions.convection_pipe(this.tGeometry.fD_Hydraulic, fLength,...
                                                          mfFlowSpeed(iCell), fDynamicViscosity, mfDensity(iCell), fThermalConductivity, mfSpecificHeatCapacity(iCell), 1);
                        mfHeatTransferCoefficient(iCell)= fConvectionCoeff * (this.tGeometry.fAbsorberSurfaceArea/this.iCells);

                        % in case that this was actually recalculated store the
                        % current properties in the LastUpdateProps struct to
                        % decide when the next recalculation is required
                        this.tLastUpdateProps.mfDensity(iCell)              = mfDensity(iCell);
                        this.tLastUpdateProps.mfFlowSpeed(iCell)            = mfFlowSpeed(iCell);
                        this.tLastUpdateProps.mfSpecificHeatCapacity(iCell) = mfSpecificHeatCapacity(iCell);

                        
                        % now the calculated coefficients have to be set to the
                        % conductor of each cell
                        oConductor = this.poLinearConductors(['ConvectiveConductor_', num2str(iCell)]);
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
%             this.tGeometry.fMaximumFreeGasDistance
            
        end
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            this.update();
        end
	end
end