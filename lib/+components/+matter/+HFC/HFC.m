classdef HFC < vsys
    %% Hollow Fiber Contactor (HFC) Subsystem File
    % This subsystem is a work in progress ***
    %
    % A hollow fiber contactor is a large tube filled with many, narrow
    % fibers. Inside the fibers, called the "lumen" side, can be either a
    % liquid or a gas flow. Because experiments the this subsystem are
    % based on used air (i.e. air from a cabin or CO2-laden air) on the
    % lumen side of the fibers, this subsystem model does the same. Outside
    % the fibers but inside the tube, called the "shell" side, ionic liquid
    % flows. The fibers are porous and hydrophobic, allowing gas to
    % exchange into the ionic liquid on the shell side from the gas on the
    % lumen side. This set-up is used to remove CO2 from supplied gas. 
    
    properties
        %% Properties
        
        % The Geometry struct contains information about the geometry of
        % the beds
        tGeometry;
        
        % Input atmosphere
        tAtmosphere;
        
        % Struct that contains the phases, branches, absorbers etc order
        % according to the order in which they are located in HFC for the
        % different cycles
        tMassNetwork;
        
        % Struct that allows the user to specify any value defined during
        % the constructor in the initialization struct. Please view to
        % constructor for more information on what field can be set!
        tInitializationOverwrite;
        
        tEquilibriumCurveFits;
        
        fEstimatedMassTransferCoefficient;
        
        tEstimate;
        
        txInput;
    end
    
    methods
        function this = HFC(oParent, sName, fTimeStep, txInput, tInitializationOverwrite)
                       
           this@vsys(oParent, sName, fTimeStep);
           
           % adding the inputs to the HFC system
           this.fEstimatedMassTransferCoefficient = this.oParent.fEstimatedMassTransferCoefficient;
           this.tAtmosphere.fPressure      = txInput.fPressure;
           this.tAtmosphere.fTemperature    = txInput.fTemperature;
           this.tAtmosphere.rRelHumidity    = txInput.rRelHumidity;
           this.tAtmosphere.fCO2Percent     = txInput.fCO2Percent;
           
           if nargin >= 5
               this.tInitializationOverwrite = tInitializationOverwrite;
%                this.tInitializationOverwrite = tInputParameters.tInitializationOverwrite;
           end
           
           this.txInput = txInput;
           
           eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% Creating initialization data used for the individual bed
            %
            % geometrical data:
            % HFC bed length is assumed to be the same for tube and fibers
            % NOTE: this does not accurately represent thermal mass or
            % exact geomtries of the beds tested, but is a decent first
            % order estimate from the final report of the X-Hab team,
            % "X-Hab CO2 Removal Final Report 2017"
            
            % hardcoded input parameters / design choice
            % FIBERS (inside the fibers is the "Lumen")
            % NOTE: if accessing other research papers, they may word the
            % "Lumen" as the "Tube" side.            
            this.tGeometry.Fiber.fCount             = this.txInput.Fiber.fCount;            % #
            this.tGeometry.Fiber.fInnerDiameter     = this.txInput.Fiber.fInnerDiameter;    % [m]
            this.tGeometry.Fiber.fThickness         = this.txInput.Fiber.fThickness;        % [m]
            this.tGeometry.Fiber.fLength            = this.txInput.Fiber.fLength;           % [m] (length of HFC tubes and fibers)
            this.tGeometry.Fiber.fPorosity          = this.txInput.Fiber.fPorosity;         % [ratio]
            
            % TUBE (inside the tube but outside of the fibers is the "Shell")
            this.tGeometry.Tube.fCount              = this.txInput.Tube.fCount;             % #
            this.tGeometry.Tube.fInnerDiameter      = this.txInput.Tube.fInnerDiameter;     % [m]
            this.tGeometry.Tube.fThickness          = this.txInput.Tube.fThickness;         % [m]
            
            % GEOMETRY CELL-WISE DISCRETIZATION
            iCellNumber = this.txInput.iCellNumber;     % # of length-wise computational cells
            iTubeNumber = this.txInput.iTubeNumber;     % THIS SHOULD ALWAYS BE 2 PER SUBSYSTEM
                                                        % 1 tube to absorb, the 2nd to desorb
            
            tInitialization.Shell.fTemperature = 303.15;    % [K]
            % Assumed water mol fraction initialization
            rWaterVolFraction = this.txInput.rWaterVolFraction;        % vol water / vol mixture
            fReservoirSizeIncreaseFactor = this.txInput.fReservoirSizeIncreaseFactor; 
            % the reservoir must be bigger than the total absorber volume
            % by at least a factor of 2 (2 tubes). This factor determines
            % the overall mass of liquid present and how quickly
            % concentration of CO2 or H2O in the IL changes (a larger
            % reservoir causes a slower change)
            
            % Define the standard values used for pipes of BRANCHES
            % NOTE: These values have not been verified or considered at all
            fPipeLength         = this.txInput.fPipelength;
            fPipeDiameter       = this.txInput.fPipeDiameter;
            fFrictionFactor     = this.txInput.fFrictionFactor;
            
            %% INTERNAL CALCULATIONS
            % DISCRETIZATION
            this.tGeometry.iCellNumber = iCellNumber;
            tInitialization.Shell.iCellNumber = iCellNumber;
            tInitialization.Lumen.iCellNumber = iCellNumber;
            
            % NOTE: Average length of particle travel across contactor (from X-Hab) fLengthTube = 0.0315;
            this.tGeometry.Tube.fLength = this.tGeometry.Fiber.fLength./2;  % [m]
            
            % defining simple geometric components based on input variables
            this.tGeometry.Fiber.fOuterDiameter  = this.tGeometry.Fiber.fInnerDiameter + 2*this.tGeometry.Fiber.fThickness;       % [m]
            this.tGeometry.Fiber.fCrossSectionLumen   = (pi/4) * this.tGeometry.Fiber.fInnerDiameter^2;                           % [m^2]
            this.tGeometry.Fiber.fCrossSectionLumenTotal = this.tGeometry.Fiber.fCrossSectionLumen * this.tGeometry.Fiber.fCount; % [m^2]
            this.tGeometry.Fiber.fCrossSectionFiber = (pi/4) * this.tGeometry.Fiber.fOuterDiameter^2;                             % [m^2]
            this.tGeometry.Fiber.fCrossSectionFiberTotal = this.tGeometry.Fiber.fCrossSectionFiber * this.tGeometry.Fiber.fCount; % [m^2]
            this.tGeometry.Fiber.fSurfaceAreaShell = pi*this.tGeometry.Fiber.fOuterDiameter * this.tGeometry.Fiber.fLength;       % [m^2]
            this.tGeometry.Fiber.fSurfaceAreaShellTotal = this.tGeometry.Fiber.fSurfaceAreaShell * this.tGeometry.Fiber.fCount;   % [m^2]
            this.tGeometry.Fiber.fVolumeLumen         = this.tGeometry.Fiber.fCrossSectionLumen * this.tGeometry.Fiber.fLength;   % [m^3]
            % fVolumeLumenTotal is the fluid volume in all of the fibers on
            % the lumen side for flow volume calculations
            this.tGeometry.Fiber.fVolumeLumenTotal    = this.tGeometry.Fiber.fVolumeLumen * this.tGeometry.Fiber.fCount;          % [m^3]
            this.tGeometry.Fiber.fVolumeFiber         = this.tGeometry.Fiber.fCrossSectionFiber * this.tGeometry.Fiber.fLength;   % [m^3]
            this.tGeometry.Fiber.fVolumeFiberTotal    = this.tGeometry.Fiber.fVolumeFiber * this.tGeometry.Fiber.fCount;          % [m^3]
            
            this.tGeometry.Tube.fOuterDiameter      = this.tGeometry.Tube.fInnerDiameter + 2*this.tGeometry.Tube.fThickness;      % [m]
            this.tGeometry.Tube.fCrossSectionInlet  = 2*((pi/4)*((0.364)*2.54/100)^2);                                            % [m^2]
            this.tGeometry.Tube.fHydraulicDiameter  = (this.tGeometry.Tube.fInnerDiameter^2 - (this.tGeometry.Fiber.fCount * (this.tGeometry.Fiber.fOuterDiameter^2))) / (this.tGeometry.Fiber.fCount * (this.tGeometry.Fiber.fOuterDiameter));
            % this.tGeometry.Tube.fCrossSectionInlet  = 6.33e-5; [m^2]
            % cross section area of two inlet ports to shell (alternative
            % area estimate)
            this.tGeometry.Tube.fCrossSectionShell  = (pi/4)*this.tGeometry.Tube.fInnerDiameter^2 - this.tGeometry.Fiber.fCrossSectionFiberTotal;   % m^2
            % fVolumeShell is the fluid in the shell for flow volume calculations
            this.tGeometry.Tube.fVolumeShell        = this.tGeometry.Tube.fCrossSectionShell * this.tGeometry.Fiber.fLength;      % [m^3]
                        
            % fiber porosity is defined as a percentage of the outside
            % diameter surface area of the fiber that is void space to
            % allow for air to exchange through
            this.tGeometry.Fiber.fPackingFactor = this.tGeometry.Fiber.fCount * (this.tGeometry.Fiber.fOuterDiameter^2) / (this.tGeometry.Tube.fInnerDiameter^2);
            this.tGeometry.Fiber.fPackingDensity = 4 * this.tGeometry.Fiber.fCount * this.tGeometry.Fiber.fOuterDiameter / (this.tGeometry.Tube.fInnerDiameter^2);            
            this.tGeometry.Fiber.fContactArea = this.tGeometry.Fiber.fPorosity * this.tGeometry.Fiber.fSurfaceAreaShellTotal;

            % Set the initial amount of IL and water
            fILVolume = this.tGeometry.Tube.fVolumeShell * (1 - rWaterVolFraction);     % [m^3]
            fWaterVolume = this.tGeometry.Tube.fVolumeShell * rWaterVolFraction;        % [m^3]
            fILDensity = this.oMT.calculateDensity('liquid', struct('BMIMAc', 1), this.tAtmosphere.fTemperature, this.tAtmosphere.fPressure); % [kg/m^3] density of [BMIM][Ac]
            fWaterDensity = this.oMT.calculateDensity('liquid', struct('H2O', 1), this.tAtmosphere.fTemperature, this.tAtmosphere.fPressure); % [kg/m^3]
            fILMass = fILDensity * fILVolume;               % [kg]
            fWaterMass = fWaterDensity * fWaterVolume;      % [kg]
            tInitialization.Shell.tfMassAbsorber = struct('BMIMAc', fILMass, 'H2O', fWaterMass);
              
            % generate reservoir for the IL between the absorber/desorber
            % matt.store(oParent, sName, fVolume): 
            % Reservoir volume - must be bigger than process   
            matter.store(this, 'Reservoir', this.tGeometry.Tube.fVolumeShell * fReservoirSizeIncreaseFactor);
            oReservoir = matter.phases.mixture(this.toStores.Reservoir, ... % oStore: Name of parent store
                'IonicLiquid',   ...                                        % sName: Name of phase
                'liquid', ...                                               % sPhaseType: Main phase of the mixture
                struct('BMIMAc', fILMass * fReservoirSizeIncreaseFactor, 'H2O', fWaterMass * fReservoirSizeIncreaseFactor, 'CO2', 0), ... % tfMasses: Struct containing mass value for each species
                this.tAtmosphere.fTemperature, ...                          % fTemperature: Temperature of matter in phase
                this.tAtmosphere.fPressure);                                % fPressure: Pressure of matter in phase

            % check to see which IL is being used, [BMIM][Ac] or [EMIM][Ac]
            if oReservoir.arPartialMass(this.oMT.tiN2I.BMIMAc) > 0 && oReservoir.arPartialMass(this.oMT.tiN2I.EMIMAc) == 0
                fTypeIL = 1;
            elseif oReservoir.arPartialMass(this.oMT.tiN2I.EMIMAc) > 0 && oReservoir.arPartialMass(this.oMT.tiN2I.BMIMAc) == 0
                fTypeIL = 2;
            else
                error('IL mixtures are not supported')
            end
            % load the proper curve fits to equilibrium data for the IL
            this.tEquilibriumCurveFits = components.matter.HFC.functions.calculateEquilibriumCurveFits(fTypeIL);

            mfMassTransferCoefficient = zeros(1,this.oMT.iSubstances);
            tInitialization.Shell.mfMassTransferCoefficient = mfMassTransferCoefficient;
            this.tGeometry.mfMassTransferCoefficient = mfMassTransferCoefficient;

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
            %
            % These have been set to zero assuming pure IL with no water
            % present and not previously used for CO2 absorption, i.e.
            % first run of the system.
            tStandardInit.Lumen.mfInitialCO2 = zeros(tInitialization.Shell.iCellNumber,1);
            tStandardInit.Lumen.mfInitialH2O = zeros(tInitialization.Shell.iCellNumber,1);
            tStandardInit.Shell.mfInitialCO2 = zeros(tInitialization.Shell.iCellNumber,1);
            tStandardInit.Shell.mfInitialH2O = zeros(tInitialization.Shell.iCellNumber,1);
            
            tInitialization.Shell.mfInitialCO2 = tStandardInit.Shell.mfInitialCO2;
            tInitialization.Shell.mfInitialH2O = tStandardInit.Shell.mfInitialH2O;
        	
            % friction factor times the mass flow^2 dictates the pressure
            % loss in the tube or fiber (ACTUAL FRICTION FACTOR UNKNOWN)
            this.tGeometry.Tube.mfFrictionFactor = 1e8 / tInitialization.Shell.iCellNumber * ones(tInitialization.Shell.iCellNumber,1);
            this.tGeometry.Fiber.mfFrictionFactor = 1e9 / tInitialization.Lumen.iCellNumber * ones(tInitialization.Lumen.iCellNumber,1);
                        
            % All values to create the system should be defined above. The
            % subsystem consists of the Shell and the Lumen sides of a
            % Hollow Fiber Contactor, where the Shell side is filled with
            % circulating IL and the Lumen side is provided with CO2-laden
            % air from a dummy cabin (AETHER) gas provision rig
            
            % abbreviated local variables for clarity of code
            fAbsorberVolume = this.tGeometry.Tube.fVolumeShell;     % [m^3]
            fFlowVolume = this.tGeometry.Fiber.fVolumeLumenTotal;   % [m^3]
            fPressure = this.tAtmosphere.fPressure;                 % [Pa]
            % TODO: Change this upon implementation of thermal factors
            fTemperatureAbsorber = this.tAtmosphere.fTemperature;   % [K]
    
            % There are ALWAYS two tubes to an HFC system:
            % Tube 1: Absorption tube - CO2 is extracted from process gas
            % Tube 2: Desorption tube - CO2 is exhausted from process IL
            % nomenclature:
            % Flow = gas flow inside lumens
            % Absorber = liquid flow inside shell
            for iTube = 1:iTubeNumber
                
                sName = ['Tube_',num2str(iTube)];
                matter.store(this, sName, fAbsorberVolume * 1.1);
                % NOTE: there is a minor inconsistency in store volume and
                % phase volumes for the IL absorber volume. The factor 1.1
                % is added in arbitrarily to avoid throwing an error.
                
                % Each Cell represents a discretized piece of the absorbing
                % or desorbing Tube.
                for iCell = 1:iCellNumber
                    % The filter and flow phase total masses struct have to be
                    % divided by the number of cells to obtain the tfMass struct
                    % for each phase of each cell. Currently the assumption here is
                    % that each cell has the same size (uniform)

                    clear tfMassesAbsorber;
                    clear tfMassesFlow;

                    % Initialize the masses of substances present in the
                    % Absorber (filter phase), i.e. the Ionic Liquid
                    csAbsorberSubstances = fieldnames(tInitialization.Shell.tfMassAbsorber);
                    for iK = 1:length(csAbsorberSubstances)
                        tfMassesAbsorber.(csAbsorberSubstances{iK}) = tInitialization.Shell.tfMassAbsorber.(csAbsorberSubstances{iK})/iCellNumber;
                    end
                    tfMassesAbsorber.CO2 = tInitialization.Shell.mfInitialCO2(iCell);

                    % Initialize the masses of substances present in the
                    % Air stream (flow phase), i.e. the CO2 laden cabin air
                    cAirHelper = matter.helper.phase.create.air_custom(this.toStores.(sName), fFlowVolume/iCellNumber, struct('CO2', this.tAtmosphere.fCO2Percent), this.tAtmosphere.fTemperature, 0, fPressure);

                    csFlowSubstances = fieldnames(cAirHelper{1});
                    for iK = 1:length(csFlowSubstances)
                        tfMassesFlow.(csFlowSubstances{iK}) = cAirHelper{1}.(csFlowSubstances{iK})/iCellNumber;
                    end

                    % Create a FLOW phase for the gas flow in each cell of
                    % the absorber or desorber tube.
                    oFlowPhase = matter.phases.flow.gas(this.toStores.(sName), ['Flow_',num2str(iCell)], tfMassesFlow, (fFlowVolume/iCellNumber), this.tAtmosphere.fTemperature);

                    %% Add the ExMes, Branches, and Processors
                    % An individual sorption and desorption Exme and P2P is
                    % required for both the absorber and the desorber 
                    % because it is possible that a few substances are
                    % being desorbed at the same time as others are being
                    % adsorbed (i.e. water desorbing from IL in a dry gas
                    % stream laden with CO2, where CO2 is being absorbed
                    % into the IL)
                    %
                    % the ratio of the masses in tfMassesAbsorber are only
                    % relevant in the initial calculation of the flow
                    % phase.
                    if strcmp(sName, 'Tube_1')
                        oFilterPhase = matter.phases.flow.mixture(this.toStores.(sName), ['Absorber_',num2str(iCell)], 'liquid', tfMassesAbsorber, fTemperatureAbsorber, fPressure);
                        matter.procs.exmes.mixture(oFilterPhase, [sName, '_Absorber_Adsorption_',num2str(iCell)]);
                        matter.procs.exmes.mixture(oFilterPhase, [sName, '_Absorber_Desorption_',num2str(iCell)]);
                    else
                        oFilterPhase = matter.phases.flow.mixture(this.toStores.(sName), ['Desorber_',num2str(iCell)], 'liquid', tfMassesAbsorber, fTemperatureAbsorber, fPressure);
                        matter.procs.exmes.mixture(oFilterPhase, [sName, '_Desorber_Adsorption_',num2str(iCell)]);
                        matter.procs.exmes.mixture(oFilterPhase, [sName, '_Desorber_Desorption_',num2str(iCell)]);
                    end
                    matter.procs.exmes.mixture(oFilterPhase, ['Filter_Inflow_',num2str(iCell)]);
                    matter.procs.exmes.mixture(oFilterPhase, ['Filter_Outflow_',num2str(iCell)]);
                    
                    % Two additional ExMes are required to connect the gas
                    % flow with the filter phases. The inflow and outflow
                    % are connected to the gas streams that ultimately link
                    % with the parent system.
                    matter.procs.exmes.gas(oFlowPhase, [sName, '_Flow_Adsorption_',num2str(iCell)]);
                    matter.procs.exmes.gas(oFlowPhase, [sName, '_Flow_Desorption_',num2str(iCell)]);
                    matter.procs.exmes.gas(oFlowPhase, ['Flow_Inflow_',num2str(iCell)]);
                    matter.procs.exmes.gas(oFlowPhase, ['Flow_Outflow_',num2str(iCell)]);

                    % Two P2P processors, one for desorption and one for
                    % absorption. Two independent P2Ps are required for 
                    % each Absorber and Desorber (making 4 P2Ps in total)
                    % because it is possible that one substance is currently 
                    % absorbing while another is desorbing which results 
                    % in two different flow directions that can occur at 
                    % the same time, i.e. dry CO2 or wet, CO2-free air.
                    if strcmp(sName, 'Tube_1')
                        % Include the Adsorption_P2Ps to handle BOTH
                        % Adsorption and Desorption processes.
                        % Assignments for Tube_1
                        oP2P.(sName).Desorber = components.matter.HFC.components.Adsorption_P2P(this.toStores.(sName), ...
                                ['DesorptionProcessor_',num2str(iCell)], ...                                            % DesorptionProcessor_1
                                ['Flow_',num2str(iCell),'.', sName, '_Flow_Desorption_',num2str(iCell)], ...            % Flow_1.Tube_1_Flow_Desorption_1
                                ['Absorber_',num2str(iCell),'.', sName, '_Absorber_Desorption_',num2str(iCell)], ...    % Absorber_1.Tube_1_Absorber_Desorption_1
                                this.tGeometry, this.tEquilibriumCurveFits, this.fEstimatedMassTransferCoefficient);               
                        oP2P.(sName).Adsorber =  components.matter.HFC.components.Adsorption_P2P(this.toStores.(sName), ...
                                ['AdsorptionProcessor_',num2str(iCell)], ...                                            % AbsorptionProcessor_1
                                ['Flow_',num2str(iCell),'.', sName, '_Flow_Adsorption_',num2str(iCell)], ...            % Flow_1.Tube_1_Flow_Adsorption_1
                                ['Absorber_',num2str(iCell),'.', sName, '_Absorber_Adsorption_',num2str(iCell)], ...    % Absorber_1.Tube_1_Absorber_Adsorption_1
                                 this.tGeometry, this.tEquilibriumCurveFits, this.fEstimatedMassTransferCoefficient);
                        oP2P.(sName).Desorber.iCell = iCell;
                        oP2P.(sName).Desorber.bDesorption = false;
                        oP2P.(sName).Adsorber.iCell = iCell;
                        oP2P.(sName).Adsorber.bDesorption = false;
                    
                    else
                        % Assignments for Tube_2
                        oP2P.(sName).Desorber = components.matter.HFC.components.Adsorption_P2P(this.toStores.(sName), ...
                                ['DesorptionProcessor_',num2str(iCell)], ...                                            % DesorptionProcessor_1
                                ['Flow_',num2str(iCell),'.', sName, '_Flow_Desorption_',num2str(iCell)], ...            % Flow_1.Tube_2_Flow_Desorption_1
                                ['Desorber_',num2str(iCell),'.', sName, '_Desorber_Desorption_',num2str(iCell)], ...    % Desorber_1.Tube_2_Desorber_Desorption_1
                                this.tGeometry, this.tEquilibriumCurveFits, this.fEstimatedMassTransferCoefficient);               
                        oP2P.(sName).Adsorber =  components.matter.HFC.components.Adsorption_P2P(this.toStores.(sName), ...
                                ['AdsorptionProcessor_',num2str(iCell)], ...                                            % AdsorptionProcessor_1
                                ['Flow_',num2str(iCell),'.', sName, '_Flow_Adsorption_',num2str(iCell)], ...            % Flow_1.Tube_2_Flow_Adsorption_1
                                ['Desorber_',num2str(iCell),'.', sName, '_Desorber_Adsorption_',num2str(iCell)], ...    % Desorber_1.Tube_2_Desorber_Adsorption_1
                                this.tGeometry, this.tEquilibriumCurveFits, this.fEstimatedMassTransferCoefficient);
                        oP2P.(sName).Desorber.iCell = iCell;
                        oP2P.(sName).Desorber.bDesorption = true;
                        oP2P.(sName).Adsorber.iCell = iCell;
                        oP2P.(sName).Adsorber.bDesorption = false;
                    end

                    % Each cell is connected to the next cell by a branch, the
                    % first and last cell also have the inlet and outlet branch
                    % attached that connects the HFC to the parent system
                    %
                    % Note: Only the branches in between the cells of
                    % the currently generated HFC are created here!
                    %                    
                    % This loop creates the internal branches and pressure
                    % drops between the branches (though pressure drops are
                    % not known exactly from experiments).
                    if iCell > 1
                        % branch between the current and the previous cell
                        % for the FLOW flow nodes
                        components.matter.HFC.components.Filter_F2F(this, [sName,'_Flow_FrictionProc_',num2str(iCell)], this.tGeometry.Fiber.mfFrictionFactor(iCell));
                        oBranch = matter.branch(this, [sName,'.Flow_Outflow_',num2str(iCell-1)], {[sName, '_Flow_FrictionProc_',num2str(iCell)]}, [sName,'.Flow_Inflow_',num2str(iCell)], [sName, '_Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                        this.tMassNetwork.(['InternalGasBranches_', sName])(iCell-1) = oBranch;
                        
                        % branch between the current and previous cell for
                        % the FILTER flow nodes (Absorber)
                        components.matter.HFC.components.Filter_F2F(this, [sName,'_Filter_FrictionProc_',num2str(iCell)], this.tGeometry.Tube.mfFrictionFactor(iCell));
                        oBranch = matter.branch(this, [sName,'.Filter_Outflow_',num2str(iCell-1)], {[sName, '_Filter_FrictionProc_',num2str(iCell)]}, [sName,'.Filter_Inflow_',num2str(iCell)], [sName, '_Filter',num2str(iCell-1),'toFilter',num2str(iCell)]);
                        this.tMassNetwork.(['InternalLiquidBranches_', sName])(iCell-1) = oBranch;
                    end
                end
            
            end
            %% DEFINITION OF INTERFACE BRANCHES
                       
            % apparently there needs to be a pipe present in each branch
            components.matter.pipe(this, 'Pipe_HFC_Inflow', fPipeLength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_HFC_Outflow', fPipeLength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_Vacuum_Inflow', fPipeLength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_Vacuum_Outflow', fPipeLength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_IL_Return', fPipeLength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_IL_Recirculation', fPipeLength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_IL_Outflow', fPipeLength, fPipeDiameter, fFrictionFactor);
            
            % Processed air inlet (CO2-laden) and outlet (CO2-free)
            sBranchName = 'HFC_Air_Out_1';
            oBranch = matter.branch(this, ['Tube_1.Flow_Outflow_',num2str(iCellNumber)],  {'Pipe_HFC_Outflow'}, 'HFC_Air_Out_1', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            sBranchName = 'HFC_Air_In_1';
            oBranch = matter.branch(this, 'Tube_1.Flow_Inflow_1', {'Pipe_HFC_Inflow'}, 'HFC_Air_In_1', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            % Vacuum ports (for desorbing CO2)
            sBranchName = 'VacuumRemoval';
            oBranch = matter.branch(this, ['Tube_2.Flow_Outflow_',num2str(iCellNumber)],  {'Pipe_Vacuum_Outflow'}, 'VacuumRemoval', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            sBranchName = 'VacuumSupply';
            oBranch = matter.branch(this, 'Tube_2.Flow_Inflow_1', {'Pipe_Vacuum_Inflow'}, 'VacuumSupply', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            % IL Recirculation
            sBranchName = 'Reservoir_IL_Return';
            oBranch = matter.branch(this, ['Tube_2.Filter_Outflow_',num2str(iCellNumber)], {'Pipe_IL_Return'}, oReservoir, sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
            
            sBranchName = 'IL_Recirculation';
            oBranch = matter.branch(this, ['Tube_1.Filter_Outflow_',num2str(iCellNumber)], {'Pipe_IL_Recirculation'}, 'Tube_2.Filter_Inflow_1', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;
                        
            sBranchName = 'Reservoir_IL_Out';
            oBranch = matter.branch(this, oReservoir, {'Pipe_IL_Outflow'}, 'Tube_1.Filter_Inflow_1', sBranchName);
            this.tMassNetwork.InterfaceBranches.(sBranchName) = oBranch;            
            
            % values for estimation of mass transfer coefficient from data
            this.tEstimate.afMassTransferCoefficientExperimental = zeros(1051,1);
            yCO2Up = this.oParent.tTestData.afUpCO2 ./ 1000000; % ppm to ratio conversion
            yCO2Dn = this.oParent.tTestData.afDnCO2 ./ 1000000; % ppm to ratio conversion
            fVolumetricFlowRate = zeros(length(yCO2Up),1);
            for ii = 1:length(yCO2Up)
                if ii < 365
                    % bypass flow mode of the experiment
                    fVolumetricFlowRate(ii,1) = 0;
                elseif ii >= 365 && ii < 638
                    % 0.2 SLPM (from experiment) conversion to non-standard
                    % atmosphere. Actual units: [m^3/s]
                    fVolumetricFlowRate(ii,1) = (0.2*(this.tAtmosphere.fTemperature/273.15)*(101325/this.tAtmosphere.fPressure))/60000;
                elseif ii >= 638 && ii < 803
                    % 0.3 SLPM (from experiment) conversion to non-standard
                    % atmosphere. Actual units: [m^3/s]
                    fVolumetricFlowRate(ii,1) = (0.3*(this.tAtmosphere.fTemperature/273.15)*(101325/this.tAtmosphere.fPressure))/60000;
                elseif ii >= 803
                    % 0.4 SLPM (from experiment) conversion to non-standard
                    % atmosphere. Actual units: [m^3/s]
                    fVolumetricFlowRate(ii,1) = (0.4*(this.tAtmosphere.fTemperature/273.15)*(101325/this.tAtmosphere.fPressure))/60000;
                end
            end
            
            CCO2Up = yCO2Up .* fPressure ./ this.oMT.Const.fUniversalGas ./ this.tAtmosphere.fTemperature;  % [mol/m^3]
            CCO2Dn = yCO2Dn .* fPressure ./ this.oMT.Const.fUniversalGas ./ this.tAtmosphere.fTemperature;  % [mol/m^3]
            % [mol/m^2/s]
            this.tEstimate.afMassTransferCoefficientExperimental = log(yCO2Up./yCO2Dn) ./ (yCO2Up-yCO2Dn) ./ fPressure .* this.oMT.Const.fUniversalGas .* this.tAtmosphere.fTemperature .* fVolumetricFlowRate./this.tGeometry.Fiber.fContactArea .* (CCO2Up-CCO2Dn);
        end

        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Set the incoming gas flow rate and the recirulating IL flow
            % rate with the manual solver. Gas rate is updated by the
            % parent system, but the internal recirculation loop of the IL
            % from the Absorber to the Desorber to the Reservoir and back
            % is set here manually.
            %
            % Gases
            % CABIN --> *HFC --> Tube 1 Flow --> HFC --> CABIN
            %
            % Ionic liquid
            % *Reservoir --> Tube 1 Filter --> Tube 2 Filter --> Reservoir
            %
            % Vacuum / CO2 Save
            % CABIN/VACUUM --> HFC --> Tube 2 Flow --> HFC --> VACUUM/CABIN
            % 
            % * = location where flowrate is set
            %
            solver.matter.manual.branch(this.toBranches.HFC_Air_In_1);
            solver.matter.manual.branch(this.toBranches.Reservoir_IL_Out);
            solver.matter.manual.branch(this.toBranches.VacuumSupply);
            % TO DO: set to the proper value or add a pump
            this.toBranches.Reservoir_IL_Out.oHandler.setVolumetricFlowRate(1.51e-6);   % [m^3/s]
            this.toBranches.VacuumSupply.oHandler.setVolumetricFlowRate(1e-4);          % [m^3/s]
            
            % Set solver properties
            tSolverProperties.fMaxError = 1e-3;
            tSolverProperties.iMaxIterations = 500;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 200;

            % Find the manually set branches and remove them from the
            % multibranch solver object
            abMultiBranches = ~(this.aoBranches == this.toBranches.HFC_Air_In_1);
            abIndex = this.aoBranches == this.toBranches.Reservoir_IL_Out;
            abIndex2 = this.aoBranches == this.toBranches.VacuumSupply;
            abMultiBranches(abIndex) = false;
            abMultiBranches(abIndex2) = false;
            aoMultiSolverBranches = this.aoBranches(abMultiBranches);
            
            % Set all other branches to the complex multibranch solver
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);

            % No thermal properties included in calculations yet, so let
            % VHAB set the solver & properties itself to let the program
            % compile properly
            % TO DO: Update heat of absorption, desorption, heat capacity
            this.setThermalSolvers();
        end
    
        function setIfFlows(this, sInterface1, sInterface2, sInterface3, sInterface4)
            if nargin < 6
                % Connections to the Parent System
                this.connectIF('HFC_Air_In_1', sInterface1);
                this.connectIF('HFC_Air_Out_1', sInterface2);
                this.connectIF('VacuumSupply', sInterface3);
                this.connectIF('VacuumRemoval', sInterface4);
            else
                error('HFC Sybsystem was given a wrong number of interfaces')
            end
        end
        
        %% setIfThermal -- still haven't added
        %% setReferencePhase -- still haven't added
        
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
        end
    end
end

