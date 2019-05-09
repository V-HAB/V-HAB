classdef (Abstract) phase < base & matlab.mixin.Heterogeneous & event.source
    %PHASE Phase with isotropic properties (abstract class)
    %   This class represents a matter phase with homogeneous mass
    %   distribution and thus isotropic properties. It is not meant to be
    %   used directly, use e.g. |matter.phases.gas| instead.
    
    properties (Abstract, Constant)
        % State of matter in phase (e.g. gas, liquid, solid), used for
        % example by the EXMEs to check compatibility.
        sType;
    end

    properties (SetAccess = protected, GetAccess = public)
        % Basic parameters:

        % Mass of every substance in phase
        afMass;       % [kg]

        % Temperature of phase
        fTemperature; % [K]
        
        % Mean Density of mixture; not updated by this class, has to be
        % handled by a deriving class.
        fDensity; % [kg/m^3]

        % Total negative masses per substance encountered during mass
        % update. This data is only kept for debugging/logging purposes.
        % If a branch requests more mass of a substance than stored in the
        % phase, there is currently no way to tell the branch about this
        % issue. Instead of throwing an error or setting a negative value
        % for the substance mass, the mass is set to zero and the absolute
        % 'generated' mass is added to this vector. (Generated because of
        % we overwrite a negative mass value with 0 we actually ad mass to
        % the system)
        afMassGenerated;

        % Mass fraction of every substance in phase
        arPartialMass; % [%]

        % Total mass of phase
        fMass;         % [kg]

        % Molar mass of mixture in phase
        fMolarMass;    % [kg/mol]
        
        % Length of the current time step for this phase
        fTimeStep;
        
        % Do we need to trigger the massupdate/update events? These
        % properties were implement to improve simulation speed for cases
        % where these triggers are not used
        bTriggerSetMassUpdateCallbackBound = false;
        bTriggerSetUpdateCallbackBound = false;
        
        % Properties to decide when the specific heat capacity has to be
        % recalculated
        fPressureLastHeatCapacityUpdate    = 0;
        fTemperatureLastHeatCapacityUpdate = 0;
        arPartialMassLastHeatCapacityUpdate;
        
        % For very small phases, bFlow can be set to true. With that, the
        % outflowing matter properties will be set to the sum of the
        % inflowing matter, taking p2ps/manip.substance into account. Also,
        % properties like molar mass and heat capacity are calculated on 
        % the fly.
        % should only be reset by the child class glow node!
        bFlow = false;
        
        % For very large phases which model e.g. the enviroment boundary
        % phases can be used. This parameter decides if the phase is a
        % boundary phase or not
        bBoundary = false;
        
        % Last time the phase mass was updated. Is NOT an actual update!
        % Only the mass is changed not all other properties, e.g. Pressure
        % and Temperature remain the same.
        fLastMassUpdate = -10;

        % Time step between the last mass updates
        fMassUpdateTimeStep = 0;

        % Current total incoming or (if negative value) outgoing mass flow,
        % for all substances combined. Used to improve pressure estimation
        % in ExMe processors.
        fCurrentTotalMassInOut = 0;
    end

    properties (SetAccess = private, GetAccess = public)

        % Associated matter store object
        oStore;

        % Matter table object
        oMT;

        % Timer object
        oTimer;

        % Capacity object
        oCapacity;
        
        % User-defined name of phase
        sName;

        % List of Extract/Merge processors added to the phase: Key of
        % struct is set to the processor's name and can be used to retrieve
        % that object.
        toProcsEXME = struct();

        % Cache: List and count of ExMe objects, used in |this.update()|
        coProcsEXME;
        iProcsEXME;

        % Cache: List and count of all p2p flow processor objects (i.e.
        % |matter.procs.p2ps|) that are connected to an ExMe of this
        % phase. Used to quickly access the objects in |this.massupdate()|;
        % created in |this.seal()|.
        coProcsP2P;
        iProcsP2P = 0;
        
        % List and number of manipulators added to the phase
        toManips = struct('volume', [], 'temperature', [], 'substance', []);
        iManipulators = 0;
        
        
        % Storage - preserve the values calculated during calculateTimeStep
        % to improve performance:
        % Vektor containing the partial mass flowrates from all ExMes
        % (which includes alls branches and P2Ps, but NOT the manips!)
        afCurrentTotalInOuts;
        
        % The current flow details including further information like
        % temperature etc.
        mfCurrentInflowDetails;
        
        % We need to remember when the last call to the update() method
        % was. This is to prevent multiple updates per tick. 
        fLastUpdate = -10;
        
        % Last time branches were set oudated
        fLastSetOutdated = -10;
        
        % Maximum allowed percentage change in the total mass of the phase
        rMaxChange = 1e-3;
        
        % Maximum allowed percentage change in the partial mass of the
        % phase (one entry for every substance, zero represents substances
        % that are not of interest to the user)
        arMaxChange;
        
        % boolean to decide if any values for arMaxChange are set, if not
        % this is false and the respective calculations are skipped to save
        % calculation time
        bHasSubstanceSpecificMaxChangeValues = false;
        
        % Maximum time step in seconds
        fMaxStep   = 20;
        
        % Minimum time step in seconds
        fMinStep;
        
        % Fixed (constant) time step in seconds, if this property is set
        % all other time step properties will be ignored and the set time
        % step will be used
        fFixedTimeStep;
        
        % Precision with which mass changes are considered during time step
        % calculation
        iTimeStepPrecision = 7;
        
        % Maximum factor with which rMaxChange is decreased
        rHighestMaxChangeDecrease = 0;
        
        % Masses in phase at last update.
        fMassLastUpdate;
        afMassLastUpdate;
        
        % Log mass and time steps which are used to influence rMaxChange
        afMassLog;
        afLastUpd;
    end

    properties (SetAccess = protected, GetAccess = protected)
        setTimeStep;
        % function handle to bind a post tick update of the massupdate
        % function of this phase. The handle is created while registering
        % the post tick at the timer and contains all necessary inputs
        % already. The same is true for the other two handles below.
        hBindPostTickMassUpdate
        % Handle to bind a post tick update of this phase
        hBindPostTickUpdate
        % Handle to bind a post tick time step calculation of this phase
        hBindPostTickTimeStep
    end
    
    properties (Access = public)
        % If true, massupdate triggers all branches to re-calculate their
        % flow rates. Use when volumes of phase compared to flow rates are
        % small!
        bSynced = false;
    end

    methods

        function this = phase(oStore, sName, tfMass, fTemperature, sCaller)
            % Constructor for the |matter.phase| class. Input parameters
            % can be provided to define the contained masses and
            % temperature, additionally the internal, merge and extract
            % processors.
            %
            % phase parameters:
            %   oStore        - object reference to the store, matter table also
            %                   received from there
            %   sName         - name of the phase
            %   aoPorts       - ports (exme procs instances); can be empty or not
            %                   provided, but then no mass can be extracted or
            %                   merged.
            %   tfMass        - optional. Struct containing the initial masses.
            %                   Keys refer to the name of the according substance
            %   fTemperature  - temperature of the initial mass, has to be given
            %                   if  tfMass is provided
            %   sCaller       - only internally used to decide which
            %                   capactiy should be added to the phase

            % Parent has to be a or derive from matter.store
            if ~isa(oStore, 'matter.store'), this.throw('phase', 'Provided oStore parameter has to be a matter.store'); end

            % Set name
            this.sName = sName;

            % Parent store - FIRST call addPhase on parent, THEN set the
            % store as the parent - matter.store.addPhase only does that if
            % the oStore attribute here is empty!
            %CHECK changed, see connector_store, need oStore already set
            this.oStore = oStore;
            this.oStore.addPhase(this);
            
            % Set matter table / timer shorthands, register phase in MT
            this.oMT    = this.oStore.oMT;
            this.oTimer = this.oStore.oTimer;
            
            % Preset masses
            this.afMass = zeros(1, this.oMT.iSubstances);
            this.arPartialMass = zeros(1, this.oMT.iSubstances);
            this.arPartialMassLastHeatCapacityUpdate = this.arPartialMass;
            this.fMinStep = this.oTimer.fMinimumTimeStep;
            
            % Mass provided?
            if (nargin >= 3) && ~isempty(tfMass) && ~isempty(fieldnames(tfMass))
                % If tfMass is provided, fTemperature also has to be there
                if nargin < 4 || isempty(fTemperature) || ~isnumeric(fTemperature) || (fTemperature <= 0)
                    this.throw('phase', 'If tfMass is provided, the fTemperature parameter also has to be provided (Kelvin, non-empty number, greater than zero).');
                end

                % Extract initial masses from tfMass and set to afMass
                csKeys = fieldnames(tfMass);

                for iI = 1:length(csKeys)
                    sKey = csKeys{iI};

                    sName = sKey;

                    % Throw an error if the matter substance is not in the
                    % matter table. Valid inputs are either full name or
                    % shortcut of the substance
                    if ~isfield(this.oMT.tiN2I, sKey)
                        bFoundMatterProperty = false;
                        for iSubstance = 1:this.oMT.iSubstances
                            if strcmpi(this.oMT.ttxMatter.(this.oMT.csSubstances{iSubstance}).sName, sKey)
                                sKey = this.oMT.csSubstances{iSubstance};
                                bFoundMatterProperty = true;
                                break
                            end
                        end
                        
                        if ~bFoundMatterProperty
                            this.throw('phase', 'Matter type %s unkown to matter.table', sKey);
                        end
                    end

                    this.afMass(this.oMT.tiN2I.(sKey)) = tfMass.(sName);
                end

                % Calculate total mass
                this.fMass = sum(this.afMass);


                % Calculate the partial masses
                if this.fMass > 0
                    this.arPartialMass = this.afMass / this.fMass;
                else
                    this.arPartialMass = this.afMass; % afMass is just zeros
                end

            else
                % Set this to zero to handle empty phases
                this.fMass = 0;
                % Partials also to zeros
                this.arPartialMass = this.afMass;
            end

            this.fMolarMass            = this.oMT.calculateMolarMass(this.afMass);
             
            % Mass
            this.fMass = sum(this.afMass);
            this.afMassGenerated = zeros(1, this.oMT.iSubstances);

            % add a thermal capacity to this phase to handle thermal
            % calculations 
            if nargin > 4 && strcmp(sCaller, 'boundary')
                this.oCapacity = thermal.capacities.boundary(this, fTemperature);
            else
                this.oCapacity = thermal.capacity(this, fTemperature);
            end
            % Now update the matter properties
            this.oCapacity.updateSpecificHeatCapacity();
               
            % Preset the cached masses (see calculateTimeStep)
            this.fMassLastUpdate  = 0;
            this.afMassLastUpdate = zeros(1, this.oMT.iSubstances);
            
            %% Register post tick callbacks for massupdate and update
            % This is only done once and permanently registers the post
            % ticks at the timer, which provides the necessary function to
            % bind post tick updates. These functions are stored as
            % properties and can then simply be called with e.g. 
            % this.hBindPostTickMassUpdate();
            this.hBindPostTickMassUpdate  = this.oTimer.registerPostTick(@this.massupdate,        'matter',        'phase_massupdate');
            this.hBindPostTickUpdate      = this.oTimer.registerPostTick(@this.update,            'matter',        'phase_update');
            this.hBindPostTickTimeStep    = this.oTimer.registerPostTick(@this.calculateTimeStep, 'post_physics' , 'timestep');
        end

        function this = registerMassupdate(this, ~)
            % To simplify debugging registering a massupdate must be done
            % using this function. That way it is possible to set
            % breakpoints here to see what binds massupdates for the phase
            this.hBindPostTickMassUpdate();
        end
        
        function this = registerUpdate(this)
            % A phase update is called, which means the
            % pressure etc changed so much that a recalculation is required
            this.hBindPostTickUpdate();
            
            % therefore we also update the mass of this phase
            this.registerMassupdate();
            
            % and trigger branch solver updates in post tick for all
            % branches because their boundary conditions changed
            this.setBranchesOutdated();
            
            % We also tell the P2Ps and manips to update
            this.setP2PsAndManipsOutdated();
            
            % We also ensure that the time step is recalculated
            this.setOutdatedTS();
        end
        
        function setTemperature(this, oCaller, fTemperature)
            % This function can only be called from the ascociated capacity
            % (TO DO: Implement the check) and ensure that the temperature
            % calculated in the thermal capacity is identical to the phase
            % temperature (by using a set function in the capacity that
            % always calls this function as well)
            if ~isa(oCaller, 'thermal.capacity')
                this.throw('setTemperature', 'The setTemperature function of the phase class can only be used by capacity objects. Please do not try to set the temperature directly, as this would lead to errors in the thermal solver');
            end
                
            this.fTemperature = fTemperature;
            
        end
        %% Setting of time step properties
        function setTimeStepProperties(this, tTimeStepProperties)
            % currently the possible time step properties that can be set
            % by the user are:
            %
            % rMaxChange:   Maximum allowed percentage change in the total
            %               mass of the phase
            % arMaxChange:  Maximum allowed percentage change in the partial
            %               mass of the phase (one entry for every
            %               substance, zero represents substances that are
            %               not of interest to the user)
            % trMaxChange:  Alterantive Input instead of arMaxChange that
            %               contains a struct reference for the maximum 
            %               allowed partial mass change.
            %               For example tTimeStepProperties.trMaxChange = struct('H2O', 0.0001, 'CO2', 0.01)
            % fMaxStep:     Maximum time step in seconds
            % fMinStep:     Minimum time step in seconds
            % fFixedTimeStep:     Fixed (constant) time step in seconds, if this
            %               property is set all other time step properties
            %               will be ignored and the set time step will be
            %               used
            % iTimeStepPrecision:   Precision for the rounding of mass
            %               values during time step calculation. Values
            %               smaller than 10^-iPrecision will be rounded to
            %               0 and not result in smaller time steps
            %
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            csPossibleFieldNames = {'rMaxChange', 'arMaxChange', 'fMaxStep', 'fMinStep', 'fFixedTimeStep', 'iTimeStepPrecision'};
            
            % In case the struct reference for the partial mass change is
            % used the arMaxChange vector for the internal calculations has
            % to be created based on the provided struct
            if isfield(tTimeStepProperties, 'trMaxChange')
                csSubstances = fieldnames(tTimeStepProperties.trMaxChange);
                arMaxChangeTemp = zeros(1,this.oMT.iSubstances);
                for iSubstance = 1:length(csSubstances)
                    arMaxChangeTemp(this.oMT.tiN2I.(csSubstances{iSubstance})) = tTimeStepProperties.trMaxChange.(csSubstances{iSubstance});
                end
                tTimeStepProperties.arMaxChange = arMaxChangeTemp;
                % removes the struct field as it has now been replaced by
                % the arMaxChange vector
                tTimeStepProperties = rmfield(tTimeStepProperties, 'trMaxChange');
            end
            
            % Gets the fieldnames of the struct to easier loop through them
            csFieldNames = fieldnames(tTimeStepProperties);
            
            for iProp = 1:length(csFieldNames)
                sField = csFieldNames{iProp};

                % If the current properties is any of the defined possible
                % properties the function will overwrite the value,
                % otherwise it will throw an error
                if ~any(strcmp(sField, csPossibleFieldNames))
                    error(['The function setTimeStepProperties was provided the unknown input parameter: ', sField, ' please view the help of the function for possible input parameters']);
                end
                

                % checks the type of the input to ensure that the
                % correct type is used.
                xProperty = tTimeStepProperties.(sField);

                if ~isfloat(xProperty)
                    error(['The ', sField,' value provided to the setTimeStepProperties function is not defined correctly as it is not a (scalar, or vector of) float']);
                end

                if strcmp(sField, 'arMaxChange') && (length(xProperty) ~= this.oMT.iSubstances)
                    error('The arMaxChange value provided to the setTimeStepProperties function is not defined correctly. It has the wrong length');
                end

                this.(sField) = tTimeStepProperties.(sField);
            end

            
            % In case that partial mass changes are of interest set the
            % boolean to true to activate these calculations, otherwise set
            % to false to skip them and save calculation time
            if ~isempty(this.arMaxChange) && any(this.arMaxChange)
                this.bHasSubstanceSpecificMaxChangeValues = true;
            else
                this.bHasSubstanceSpecificMaxChangeValues = false;
            end
            
            % Since the time step properties have changed, the time step
            % has to be recalculated, which is performed in the post tick
            % operations through this call.
            this.setOutdatedTS();
        end
        
        % Catch 'bind' calls, so we can set a specific boolean property to
        % true so the .trigger() method will only be called if there are
        % callbacks registered.
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % Only do for set
            if strcmp(sType, 'massupdate_post')
                this.bTriggerSetMassUpdateCallbackBound = true;
            elseif strcmp(sType, 'update_post')
                this.bTriggerSetUpdateCallbackBound = true;
            end
        end
    end

    %% Methods for handling manipulators
    methods

        function hRemove = addManipulator(this, oManip)

            sManipType = [];

            if     isa(oManip, 'matter.manips.volume'),               sManipType = 'volume';
            elseif isa(oManip, 'matter.manips.temperature'),          sManipType = 'temperature';
            elseif isa(oManip, 'matter.manips.substance.flow'),       sManipType = 'substance';
            elseif isa(oManip, 'matter.manips.substance.stationary'), sManipType = 'substance';
            end

            if ~isempty(this.toManips.(sManipType))
                this.throw('addManipulator', 'A manipulator of type %s is already set for phase %s (store %s)', sManipType, this.sName, this.oStore.sName);
            end

            % Set manipulator
            this.toManips.(sManipType) = oManip;
            
            % Increment the number of manipulators
            this.iManipulators = this.iManipulators + 1;

            % Remove fct call to detach manipulator
            hRemove = @() this.detachManipulator(sManipType);

        end
    end

    %% Methods for adding ports, getting flow information etc
    % The EXME procs get an instance to this object on construction and
    % call the addProcEXME here, therefore not protected - but checks
    % the store's bSealed attr, so nothing can be changed later.
    methods
        function addProcEXME(this, oProcEXME)
            % Adds a exme proc, i.e. a port. Returns a function handle to
            % the this.setAttribute method (actually the one of the derived
            % class) which allows manipulation of all set protected
            % attributes within the phase.

            if this.oStore.bSealed
                this.throw('addProcEXME', 'The store to which this phase belongs is sealed, so no ports can be added any more.');
            end

            if ~isa(oProcEXME, [ 'matter.procs.exmes.' this.sType ])
                this.throw('addProcEXME', [ 'Provided object ~isa matter.procs.exmes.' this.sType ]);
            elseif ~isempty(oProcEXME.oPhase)
                this.throw('addProcEXME', 'Processor has already a phase set as parent.');
            elseif isfield(this.toProcsEXME, oProcEXME.sName)
                this.throw('addProcEXME', 'Proc %s already exists.', oProcEXME.sName);
            elseif strcmp(oProcEXME.sName, 'default')
                this.throw('addProcEXME', 'Default EXMEs are not allowed any more!');
            end

            this.toProcsEXME.(oProcEXME.sName) = oProcEXME;
        end

        % Moved to public methods, sometimes external access required
        function [ afTotalInOuts, mfInflowDetails ] = getTotalMassChange(this)
            % Get vector with total mass change through all EXME flows in
            % [kg/s].
            %
            % The second output parameter is a matrix containing all inflow
            % rates, temperatures and heat capacities for calculating the
            % inflowing enthalpy/inner energy
            %
            % IMPORTANT: The afTotalInOuts parameter contains the total
            %            flow rate PER SUBSTANCE. The mfInflowDetails
            %            parameter contains the flow rate, temperature and
            %            heat capacity PER INFLOW EXME. 

            % Total flows - one row (see below) for each EXME, number of
            % columns is the number of substances (partial masses)
            mfTotalFlows = zeros(this.iProcsEXME, this.oMT.iSubstances);

            % Each row: flow rate, temperature, heat capacity
            mfInflowDetails = zeros(this.iProcsEXME, 3);
            
            % Creating an array to log which of the flows are not in-flows
            aiOutFlows = ones(this.iProcsEXME, 1);
            
            % Get flow rates and partials from EXMEs
            for iI = 1:this.iProcsEXME
                % The fFlowRate parameter is the flow rate at the exme,
                % with a negative flow rate being an extraction!
                % arFlowPartials is a vector, with the partial mass ratios
                % at the exme for each substance. 
                % afProperties contains the temperature and heat capacity
                % of the exme.
                oExme = this.coProcsEXME{iI};
                [ fFlowRate, arFlowPartials, afProperties ] = oExme.getFlowData();
                
                % If the flow rate is empty, then the exme is not
                % connected, so we can skip it and move on to the next one.
                if isempty(fFlowRate), continue; end
                
                % Now we add the total mass flows per substance to the
                % mfTotalFlows matrix.
                mfTotalFlows(iI, :) = fFlowRate * arFlowPartials;
                
                % Only the inflowing exme values are saved to the
                % mfInflowDetails parameter
                if fFlowRate > 0
                    mfInflowDetails(iI,:) = [ fFlowRate, afProperties(1), afProperties(2) ];
                    
                    % This flow is an in-flow, so we set the field in the
                    % array to zero.
                    aiOutFlows(iI) = 0;
                end
            end
            
            % Now we delete all of the rows in the mfInflowDetails matrix
            % that belong to out-flows.
            if any(aiOutFlows)
                mfInflowDetails(logical(aiOutFlows),:) = [];
            end
            % Now sum up in-/outflows over all EXMEs
            afTotalInOuts = sum(mfTotalFlows, 1);
            
            % Checking for NaNs. It is necessary to do this here so the
            % origin of NaNs can be found easily during debugging.
            if any(isnan(afTotalInOuts))
                error('Error in phase ''%s''. The flow rate of EXME ''%s'' is NaN.', this.sName, this.coProcsEXME{isnan(afTotalInOuts)}.sName);
            end
        end
        
    end


    %% Finalize methods
    methods

        function seal(this)
            
            % Preset mass and time step logging attributes
            % iPrecision ^ 2 is more or less arbitrary
            iStore = this.oTimer.iPrecision ^ 2;
            
            % Bind the .update method to the timer, with a time step of 0
            % (i.e. smallest step), will be adapted after each .update
            %this.setTimeStep = this.oTimer.bind(@(~) this.update(), 0);
            this.setTimeStep = this.oTimer.bind(@(~) this.registerUpdate(), 0, struct(...
                'sMethod', 'update', ...
                'sDescription', 'The .update method of a phase', ...
                'oSrcObj', this ...
            ));
            
            this.afMassLog = ones(1, iStore) * this.fMass;
            this.afLastUpd = 0:(1/(iStore-1)):1;%ones(1, iStore) * 0.00001;
            
            this.rHighestMaxChangeDecrease = this.oStore.oContainer.tSolverParams.rHighestMaxChangeDecrease;
            
            % Max time step
            this.fMaxStep = this.oStore.oContainer.tSolverParams.fMaxTimeStep;
            
            if ~this.oStore.bSealed
                this.coProcsEXME = struct2cell(this.toProcsEXME)';
                this.iProcsEXME  = length(this.coProcsEXME);
                
                % Get all p2p flow processors on EXMEs
                this.coProcsP2P = {};
                this.iProcsP2P  = 0;

                for iE = 1:this.iProcsEXME
                    % Get number and references for connected P2Ps
                    if ~isempty(this.coProcsEXME{iE}.oFlow) 
                        if this.coProcsEXME{iE}.bFlowIsAProcP2P
                            this.iProcsP2P = this.iProcsP2P + 1;

                            this.coProcsP2P{this.iProcsP2P} = this.coProcsEXME{iE}.oFlow;
                        end
                    else
                        this.throw('seal','Phase ''%s'' in store ''%s'' has an unconnected exme processor: ''%s''',this.sName, this.oStore.sName, this.coProcsEXME{iE}.sName);
                    end
                end
            end
            
            % Preset
            [ afChange, mfDetails ] = this.getTotalMassChange();

            this.afCurrentTotalInOuts = afChange;
            this.mfCurrentInflowDetails = mfDetails;
            
        end
    end

    %% Internal, protected methods
    methods (Access = protected)

        function this = massupdate(this, ~)
            % This method updates the mass and temperature related
            % properties of the phase. It takes into account all in- and
            % outflowing matter streams via the exme processors connected
            % to the phase, including the ones associated with p2p
            % processors. It also gets the mass changes from substance
            % manipulators. The new temperature is based on the thermal
            % energy of the in- and outflow. After completing the update of
            % fMass, afMass and fTemperature this method sets the phase's timestep
            % outdated, so it will be recalculated during the post-tick.
            % Additionally, if this phase is set as 'sycned', this method
            % will set all branches connected to exmes connected to this
            % phase to outdated, also causing a recalculation in the
            % post-tick.
            
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastMassUpdate;
            
            % Return if no time has passed
            if fLastStep == 0
                % This is necessary to ensure the TS is set outdated for
                % cases where flow phases are handled (as they can change
                % their partial mass composition after the solvers are
                % updated, which is after the initial mass updates)
                this.setOutdatedTS();
                return;
            end
            
            if ~base.oDebug.bOff, this.out(tools.debugOutput.INFO, 1, 'exec', 'Execute massupdate in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end

            % Immediately set fLastMassUpdate, so if there's a recursive call
            % to massupdate, e.g. by a p2ps.flow, nothing happens!
            this.fLastMassUpdate     = fTime;
            this.fMassUpdateTimeStep = fLastStep;
            
            % All in-/outflows in [kg/s] and multiply with curernt time
            % step, also get the inflow rates / temperature / heat capacity
            %SPEED OPT - value saved in last calculateTimeStep, still valid
            %[ afTotalInOuts, mfInflowDetails ] = this.getTotalMassChange();
            afTotalInOuts = this.afCurrentTotalInOuts;
            
            if ~base.oDebug.bOff, this.out(1, 2, 'total-fr', 'Total flow rate in %s-%s: %.20f', { this.oStore.sName, this.sName, sum(afTotalInOuts) }); end
            
            % Check manipulator
            if ~isempty(this.toManips.substance) && ~isempty(this.toManips.substance.afPartialFlows)
                % Add the changes from the manipulator to the total inouts
                afTotalInOuts = afTotalInOuts + this.toManips.substance.afPartialFlows;
                
                if ~base.oDebug.bOff, this.out(tools.debugOutput.MESSAGE, 1, 'manip-substance', 'Has substance manipulator'); end % directly follows message above, so don't output name
            end
            
            % Cache total mass in/out so the EXMEs can use that
            this.fCurrentTotalMassInOut = sum(afTotalInOuts);
            
            % Multiply with current time step
            afTotalInOuts = afTotalInOuts * fLastStep;
            
            % Do the actual adding/removing of mass.
            this.afMass =  this.afMass + afTotalInOuts;

            % Now we check if any of the masses has become negative. This
            % can happen for two reasons, the first is just MATLAB rounding
            % errors causing barely negative numbers (e-14 etc.) The other
            % is an error in the programming of one of the procs/solvers.
            % In any case, we don't interrupt the simulation for this, we
            % just log the negative masses and set them to zero in the
            % afMass array. The sum of all mass lost is shown in the
            % command window in the post simulation summary.
            abNegative = this.afMass < 0;

            if any(abNegative)
                this.afMassGenerated(abNegative) = this.afMassGenerated(abNegative) - this.afMass(abNegative);
                this.afMass(abNegative) = 0;
                
                if ~base.oDebug.bOff
                    this.out(tools.debugOutput.NOTICE, 1, 'negative-mass', 'Got negative mass, added to mass lost.', {}); % directly follows message above, so don't output name
                    this.out(3, 2, 'negative-mass', '%s\t', this.oMT.csI2N(abNegative));
                end
                
            end

            %%%% Now calculate the new total heat capacity for the
            %%%% asscociated capacity
            this.oCapacity.setTotalHeatCapacity(this.fMass * this.oCapacity.fSpecificHeatCapacity);
            
            % Update total mass
            this.fMass = sum(this.afMass);
            
            % Partial masses
            if ~this.bFlow
                if this.fMass > 0
                    this.arPartialMass = this.afMass / this.fMass;
                else
                    this.arPartialMass = this.afMass; % afMass is just zeros
                end
            else
                this.trigger('update_partials');
            end
            
            this.setBranchesOutdated([],true);
            
            this.setP2PsAndManipsOutdated();
            
            % Phase sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
            
            
            if this.bTriggerSetMassUpdateCallbackBound
            	this.trigger('massupdate_post');
            end
        end
        
        function this = update(this)
            % Only update if not yet happened at the current time.
            if (this.oTimer.fTime <= this.fLastUpdate) || (this.oTimer.fTime < 0)
                if ~base.oDebug.bOff, this.out(2, 1, 'update', 'Skip update in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end
                
                return;
            end
            
            if ~base.oDebug.bOff, this.out(2, 1, 'update', 'Execute update in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end
            
            % Store update time
            this.fLastUpdate = this.oTimer.fTime;
            
            % Cache current fMass / afMass so they represent the values at
            % the last phase update. Needed in phase time step calculation.
            this.fMassLastUpdate  = this.fMass;
            this.afMassLastUpdate = this.afMass;

            % Now update the matter properties
            this.fMolarMass = this.oMT.calculateMolarMass(this.afMass);
            
            % If this update was triggered by the changeInnerEnergy()
            % method, then we already have calculated the current specific
            % heat capacity of this phase. So we don't have to do the
            % calculation again, we check against the timestep and only do
            % the calculation if it hasn't been done before.
            %
            % See getTotalHeatCapacity --> only recalculated if at least
            % the minimal time difference between calculations, as
            % specified in the fMinimalTimeBetweenHeatCapacityUpdates
            % property, has passed. So we'll also include that here!
            if ~isempty(this.oCapacity.fMinimalTimeBetweenHeatCapacityUpdates) && (this.oTimer.fTime >= (this.oCapacity.fLastTotalHeatCapacityUpdate + this.oCapacity.fMinimalTimeBetweenHeatCapacityUpdates))
                bRecalculate = true;
            elseif isempty(this.oCapacity.fMinimalTimeBetweenHeatCapacityUpdates) && ~(this.oTimer.fTime == this.oCapacity.fLastTotalHeatCapacityUpdate)
                bRecalculate = true;
            else
                bRecalculate = false;
            end

            if bRecalculate
                % Our checks have concluded, that we have to recalculate
                % the specific heat capacity for this phase. To do that, we
                % call a phase type specific method. 
                this.oCapacity.updateSpecificHeatCapacity();
            end
            
            if this.bFlow
            	this.trigger('update_partials');
            end
            
            if this.bTriggerSetUpdateCallbackBound
            	this.trigger('update_post');
            end
            
        end
        
        function detachManipulator(this, sManip)
            
            %CHECK several manipulators possible?
            this.toManips.(sManip) = [];
            
        end

        function setBranchesOutdated(this, ~, bSynced)
            
            if nargin < 3
                bSynced = false;
            end
            
            % If the phase is synced, it can be a flow_node for which we
            % have to set the outflows outdated even if they have already
            % been set outdated in this tick! Since the input branches can
            % change the partial mass composition of the flow nodes and the
            % execution order between input and output branches is
            % initially not defined
            if this.fLastSetOutdated >= this.oTimer.fTime
                if bSynced
                    bUpdateOutFlow = true;
                else
                    return;
                end
            else
                bUpdateOutFlow = false;
            end
            
            this.fLastSetOutdated = this.oTimer.fTime;
            
            
            % Loop through exmes / flows and set outdated, i.e. request
            % recalculation of flow rate.
            for iE = 1:this.iProcsEXME
                oExme   = this.coProcsEXME{iE};
                oBranch = oExme.oFlow.oBranch;
                
                % Make sure it's not a p2ps.flow - their update method
                % is called in updateProcessorsAndManipulators method
                if bUpdateOutFlow
                    if ~oExme.bFlowIsAProcP2P
                        if oExme.iSign * oExme.oFlow.fFlowRate <= 0
                            % Tell branch to recalculate flow rate (done after
                            % the current tick, in timer post tick).
                            oBranch.setOutdated();
                        end
                    end
                elseif isa(oBranch, 'matter.branch')
                    % We can't directly set this oBranch as outdated if
                    % it is just connected to an interface, because the
                    % solver is assigned to the 'leftest' branch.
                    while ~isempty(oBranch.coBranches{1})
                        oBranch = oBranch.coBranches{1};
                    end
                    
                    % Tell branch to recalculate flow rate (done after
                    % the current tick, in timer post tick).
                    oBranch.setOutdated();
                end
            end
        end
        
        function setP2PsAndManipsOutdated(this, ~)
            
            if this.iProcsP2P > 0 || this.iManipulators > 0
                
                if ~isempty(this.toManips.substance)
                    this.toManips.substance.registerUpdate();
                end

                % Call p2ps.flow update methods (if not yet called)
                for iP = 1:this.iProcsP2P
                    % That check would make more sense within the flow p2p
                    % update method - however, that method will be overloaded
                    % in p2ps to include the model to derive the flow rate, so
                    % would have to be manually added in each derived p2p ...
                    if this.coProcsP2P{iP}.fLastUpdate < this.fLastMassUpdate
                        % Triggers the .massupdate of both connected phases
                        % which is ok, because the fTimeStep == 0 check above
                        % will prevent this .massupdate from re-executing.
                        this.coProcsP2P{iP}.registerUpdate();
                    end
                end
                
            end

        end
        
        function setOutdatedTS(this)
            % Setting this to true multiple times in the timer is no
            % problem, therefore no check required
            this.hBindPostTickTimeStep();
        end

        function setAttribute(this, sAttribute, xValue)
            % Internal method that needs to be copied to every child.
            % Required to enable the phase class to adapt values on the
            % child through processors.

            this.(sAttribute) = xValue;
        end

        function [ bSuccess, txValues ] = setParameter(this, sParamName, xNewValue)
            % Helper for executing internal processors.
            %
            % setParameter parameters:
            %   sParamName  - attr/param to set
            %   xNewValue   - value to set param to
            %   setValue    - function handle to set the struct returned by
            %                 the processor (params key, value).
            
            bSuccess = false;
            txValues = [];
            
            this.setAttribute(sParamName, xNewValue);
            this.registerUpdate();

        end
    end

    %% Implementation-specific methods
    methods (Sealed)
        % Seems like we need to do that for heterogeneous, if we want to
        % compare the objects in the mixin array with one object ...
        function varargout = eq(varargin)
            varargout{:} = eq@base(varargin{:});
        end
    end
end