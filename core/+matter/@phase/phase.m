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

    % These properties (including the mass vlaues) are not private because
    % the subclasses for flow and boundary phases must have access to them
    % and be allowed to change them according to their needs
    properties (SetAccess = protected, GetAccess = public)
        % Basic parameters:

        % Mass vector of every substance in phase. Contains an entry for
        % every substance defined in V-HAB, even if that substance is not
        % used. If a specific substance mass is of interest that can be
        % accessed by using the matter table to identify the corresponding
        % index. For example by using afMass(this.oMT.tiN2I.H2O) the
        % partial mass of water within the phase could be identified
        afMass;       % [kg]

        % Temperature of phase, only here for information reasons, the
        % actual temperature calculation is performed in the thermal domain
        % capacity
        fTemperature; % [K]
        
        % Volume in m^3
        fVolume; %[m^3]
        
        % Coefficient for pressure = COEFF * mass,  depends on current 
        % matter properties
        fMassToPressure; % [Pa/kg]
        
        % Mean Density of mixture; not updated by this class, has to be
        % handled by a deriving class.
        fDensity; % [kg/m^3]

        % Total mass of each substance that was generated because too much
        % mass was taken from this phase
        % If a branch requests more mass of a substance than stored in the
        % phase, the mass is set to zero and the absolute 'generated' mass
        % is added to this vector. (Generated because of we overwrite a
        % negative mass value with 0 we actually ad mass to the system).
        % The time step calculation of the phase limits this to 1e-8 kg per
        % tick and substance.
        afMassGenerated;

        % Mass fraction of every substance in phase. The sum of this vector
        % is always 1 and represent afMass ./ fMass. Accessing individual
        % values for specific substance is analogous to afMass
        arPartialMass; % [%]

        % Total mass of phase
        fMass;         % [kg]

        % Molar mass of mixture in phase
        fMolarMass;    % [kg/mol]
        
        % Length of the current time step for this phase
        fTimeStep;     % [s]
        
        % booleans used to check if anything is bound to the events
        % informing other object/functions about a finished
        % massupdate/update. These properties were implement to improve
        % simulation speed for cases where these triggers are not used
        bTriggerSetMassUpdateCallbackBound = false;
        bTriggerSetUpdateCallbackBound = false;
        
        % Very small phases can be modelled as flow phases (see child class
        % flow.m and its derviatives) which assumes that the phase does not
        % contain any mass.
        % should only be reset by the child class matter.phases.flow.flow.m!
        bFlow = false;
        
        % For very large phases which model e.g. the enviroment boundary
        % phases can be used. This parameter decides if the phase is a
        % boundary phase or not
        % should only be reset by the child class matter.phases.boundary.boundary.m!
        bBoundary = false;
        
        % To easier identify mixture phases, all phases have this boolean
        % property, which is normally false and only set to true by the
        % mixture subclass
        bMixture = false;
        
        % Last time the phase mass was updated. Is NOT an actual update!
        % Only the mass is changed not all other properties, e.g. Pressure
        % and Temperature remain the same.
        fLastMassUpdate = -10;

        % Time step between the last mass updates. Note that this is NOT
        % the time to the next mass update, as we cannot know that!
        fMassUpdateTimeStep = 0;

        % Current total incoming or (if negative value) outgoing mass flow,
        % for all substances combined. Used to improve pressure estimation
        % in ExMe processors.
        fCurrentTotalMassInOut = 0;

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

        % struct list of Extract/Merge processors added to the phase.
        % The names of the exmes are used as fieldnames for the structs and
        % the exme can be accessed through this struct with its name
        toProcsEXME = struct();

        % Cell array of all exmes for this phase. Used as alternative
        % reference of the exmes and is usefull if a for loop over all
        % exmes is performed.
        coProcsEXME;
        % Integer value of the number of exmes within this phase (can be
        % used for for-loops)
        iProcsEXME;

        % Cache: List and count of all p2p flow processor objects (i.e.
        % |matter.procs.p2ps|) that are connected to an ExMe of this
        % phase. Used to quickly access the objects in |this.massupdate()|;
        % created in |this.seal()|.
        coProcsP2P;
        iProcsP2P = 0;
        
        % List and number of manipulators added to the phase
        toManips = struct('volume', [], 'temperature', [], 'substance', []);
        iVolumeManipulators = 0;
        iSubstanceManipulators = 0;
        
        
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
        
        % This property sets the maximum mass that is generated per tick
        % when too much mass of a specific substance is taken out of the
        % phase. Lower limits will reduce the afMassGenerated value but
        % slow down the simulation!
        fMassErrorLimit = 1e-8;
        
        % This value sets the maximum mass that will initally enter a phase
        % after its mass was zero. If e.g. a storeroom is modelled which
        % frequently is completly emptied and then many kg of mass are
        % added again to the empty storeroom this value should be high, as
        % otherwise a slow ramp up of the time step will occur
        fMaximumInitialMass = 0.1;
        
        % This boolean property allows other components to check whether
        % this phase will be updated in the corresponding post tick group
        % or not. Used for example in the (in)compressibleMedium volume
        % manipulators to only update them if the phase update will execute
        bUpdateRegistered = false;
        
        % Masses in phase at last update.
        fMassLastUpdate;
        afMassLastUpdate;
    end

    properties (Dependent)
        % Pressure in Pa. This is a dependent property because it is
        % calculated on demand from fMassToPressure * fMass. That is a
        % linearization approach and yields the pressure for the current
        % mass. The fMassToPressure parameter is updated in the update
        % function of the phase
        fPressure;
    end
    
    % These properties are private because changing them would change the
    % update order, which is a significant change of the core and should
    % not be allowed without a certain hurdle. If it is necessary at some
    % point for a child class to change the execution order, this should be
    % discussed in depth and then a solution for this should be found (e.g.
    % using a intermediare function that only allows that child class
    % access to these properties)
    properties (SetAccess = private, GetAccess = protected)
        % function handle registered at the timer object that allows this
        % phase to set a time step, which is then enforced by the timer
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
    
    methods

        function this = phase(oStore, sName, tfMass, fTemperature, sCaller)
            %% Phase Class Constructor
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

            % Parent has to be or derive from matter.store
            if ~isa(oStore, 'matter.store'), this.throw('phase', 'Provided oStore parameter has to be a matter.store'); end

            % Set name
            this.sName = sName;

            % Parent store - FIRST set the store as the parent, THEN call
            % addPhase on parent -
            this.oStore = oStore;
            this.oStore.addPhase(this);
            
            % Set matter table / timer shorthands
            this.oMT    = this.oStore.oMT;
            this.oTimer = this.oStore.oTimer;
            
            % Preset masses
            this.afMass = zeros(1, this.oMT.iSubstances);
            this.arPartialMass = zeros(1, this.oMT.iSubstances);
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

            this.fMolarMass = this.oMT.calculateMolarMass(this.afMass);
             
            % Mass
            this.fMass = sum(this.afMass);
            this.afMassGenerated = zeros(1, this.oMT.iSubstances);

            this.fMassToPressure = this.fPressure / this.fMass;
            
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
            %% registerMassupdate
            % To simplify debugging registering a massupdate must be done
            % using this function. That way it is possible to set
            % breakpoints here to see what binds massupdates for the phase
            this.hBindPostTickMassUpdate();
        end
        
        function this = registerUpdate(this)
            %% registerUpdate
            % A phase update is called, which means the pressure etc
            % changed so much that a recalculation is required. However,
            % the update is not executed directly. Instead the required
            % functions are bound to the post tick. Note that the order in
            % which the functions are executed does not depend on the order
            % of the code here, but is instead defined in the post tick
            % order (see also
            % https://wiki.tum.de/display/vhab/5.+Timer+and+Execution+Order
            % for more information on the execution order)
            
            % Bind execution of the update function to the post tick
            this.hBindPostTickUpdate();
            
            % if we want to update the phase, we also have to update the
            % mass within the phase, in case that is not triggered by
            % anything else
            this.registerMassupdate();
            
            % and trigger branch solver updates in post tick for all
            % branches because their boundary conditions changed (e.g. the
            % pressure of this phase changed, thus changing the boundary
            % condition and overall delta pressure for the branches)
            this.setBranchesOutdated();
            
            % We also tell the P2Ps and manips to update
            this.setP2PsAndManipsOutdated();
            
            % We also ensure that the time step is recalculated
            this.setOutdatedTS();
            
            % set the boolean falg to true that this phase will be updated
            % in the post tick
            this.bUpdateRegistered = true;
        end
        
        function setTemperature(this, oCaller, fTemperature)
            %% SetTemperature
            % INTERNAL FUNCTION!
            % This function can only be called from the ascociated capacity
            % to set the temperature of the phase!
            if ~(oCaller == this.oCapacity)
                this.throw('setTemperature', 'The setTemperature function of the phase class can only be used by capacity objects. Please do not try to set the temperature directly, as this would lead to errors in the thermal solver');
            end
            
            this.fTemperature = fTemperature;
        end
        
        function setTimeStepProperties(this, tTimeStepProperties)
            %% Setting of time step properties
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
            % fMassErrorLimit:  sets the maximum mass that is generated per
            %               tick when too much mass of a specific substance
            %               is taken out of the phase. Lower limits will
            %               reduce the afMassGenerated value but slow down
            %               the simulation!
            % fMaximumInitialMass:  This value sets the maximum mass that
            %               will initally enter a phase after its mass was
            %               zero. If e.g. a storeroom is modelled which
            %               frequently is completly emptied and then many
            %               kg of mass are added again to the empty
            %               storeroom this value should be high, as
            %               otherwise a slow ramp up of the time step will
            %               occur
            %
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            csPossibleFieldNames = {'rMaxChange', 'arMaxChange', 'fMaxStep', 'fMinStep', 'fFixedTimeStep', 'iTimeStepPrecision', 'fMassErrorLimit', 'fMaximumInitialMass'};
            
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
        
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            %% bind
            % Catch 'bind' calls, so we can set a specific boolean property
            % to true so the .trigger() method will only be called if there
            % are callbacks registered.
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % for the triggers specific to phases we set the corresponding
            % boolean properties to true if anything binds anything to
            % them. Only if the boolean for the event is true the event is
            % actually triggered
            if strcmp(sType, 'massupdate_post')
                this.bTriggerSetMassUpdateCallbackBound = true;
            elseif strcmp(sType, 'update_post')
                this.bTriggerSetUpdateCallbackBound = true;
            end
        end
        
        
        function fPressure = get.fPressure(this)
            %% get.fPressure
            % Since the pressure is a dependent property but some child
            % classes require a different calculation approach for
            % the pressure this function only defines the function name
            % which is used to calculate the pressure (since child classes
            % cannot overload this function).
            fPressure = this.get_fPressure();
        end
    end

    %% Methods for handling manipulators
    methods
        function hRemove = addManipulator(this, oManip)
            %% addManipulator
            % function to add a manipulator to this phase. The necessary
            % inputs are:
            % oManip: a valid manipulator object
            % The outputs are:
            % hRemove: a handle which can be used to remove the manipulator
            % from the phase

            sManipType = [];

            if	isa(oManip, 'matter.manips.volume')
                sManipType = 'volume';
                % Increment the number of manipulators
                this.iVolumeManipulators = this.iVolumeManipulators + 1;
            elseif isa(oManip, 'matter.manips.substance')
                sManipType = 'substance';
                % Increment the number of manipulators
                this.iSubstanceManipulators = this.iSubstanceManipulators + 1;
            end

            if ~isempty(this.toManips.(sManipType))
                this.throw('addManipulator', 'A manipulator of type %s is already set for phase %s (store %s)', sManipType, this.sName, this.oStore.sName);
            end

            % Set manipulator
            this.toManips.(sManipType) = oManip;
            

            % Remove fct call to detach manipulator
            hRemove = @() this.detachManipulator(sManipType);

        end
        
        function [ hSetProperty ] = bindSetProperty(this, sPropertyName)
            %% bindSetProperty
            % INTERNAL FUNCTION! is called by the manips to allow them
            % access to otherwise protected phase properties.
            % This function is used to provide access to the internal
            % Properties of a phase, which allows to overwrite parameters.
            % Since overwriting parameters can lead to inconsistencies if
            % done incorrectly the setProperty function itself is private
            % and this function checks whether the parameter that is
            % supposed to be set is a valid parameter. Valid parameters
            % which can be overwritten by manipulators are:
            % fVolume, fPressure, fDensity
            %
            % The temperature specifically cannot be changed by this
            % function because it is a thermal domain property!
            csValidProperties = {'fVolume', 'fMassToPressure', 'fDensity'};
            if ~any(strcmp(sPropertyName, csValidProperties))
                 error(['The function BindSetProperty was provided the unknown input parameter: ', sPropertyName, ' please view the help of the function for possible input parameters']);
            end
                
            hSetProperty = @(xNewValue) this.setProperty(sPropertyName, xNewValue);
        end
    end

    %% Methods for adding ports, getting flow information etc
    % The EXME procs get an instance to this object on construction and
    % call the addProcEXME here, therefore not protected - but checks
    % the store's bSealed attr, so nothing can be changed later.
    methods
        function addProcEXME(this, oProcEXME)
            %% addProcEXME
            % Adds a exme proc, i.e. a port. Returns a function handle to
            % the this.setAttribute method (actually the one of the derived
            % class) which allows manipulation of all set protected
            % attributes within the phase.

            if this.oStore.bSealed
                this.throw('addProcEXME', 'The store to which this phase belongs is sealed, so no ports can be added any more.');
            end

            if ~isa(oProcEXME, [ 'matter.procs.exmes.' this.sType ])
                % check if the exme is of the correct type to connect with
                % this phase
                this.throw('addProcEXME', [ 'Provided object ~isa matter.procs.exmes.' this.sType ]);
            elseif ~isempty(oProcEXME.oPhase)
                % check if the exme is already connected to another phase
                this.throw('addProcEXME', 'Processor has already a phase set as parent.');
            elseif isfield(this.toProcsEXME, oProcEXME.sName)
                % check if an exme with this name is already present
                this.throw('addProcEXME', 'Proc %s already exists.', oProcEXME.sName);
            end

            this.toProcsEXME.(oProcEXME.sName) = oProcEXME;
        end

        function [ afTotalInOuts, mfInflowDetails ] = getTotalMassChange(this)
            %% getTotalMassChange
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
        
        function seal(this)
            %% seal
            % INTERNAL METHOD! This is called by the sealMatterStructure
            % function of the container
            % Seales the phase and prevents further changes to it regarding
            % exmes etc. Only IF exmes are allowed to change after this, to
            % allow e.g. a human to move through a habitat.
            
            % Bind the .update method to the timer, with a time step of 0
            % (i.e. smallest step), will be adapted after each .update
            this.setTimeStep = this.oTimer.bind(@(~) this.registerUpdate(), 0, struct(...
                'sMethod', 'update', ...
                'sDescription', 'The .update method of a phase', ...
                'oSrcObj', this ...
            ));
            
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
    % These methods can only be called by the phase or its child classes.
    % This is necessary because calling them from somewhere else could lead
    % to inconsistent results
    methods (Access = protected)

        function this = massupdate(this, ~)
            %% massupdate
            % INTERNAL METHOD! This method can only be executed in the post
            % tick, if a user wants to execute a massupdate the
            % registerMassupdate function of the phase should be used to
            % trigger the post tick update in the current tick!
            %
            % This method updates the mass related properties of the phase.
            % It takes into account all in- and outflowing matter streams
            % via the exme processors connected to the phase, including the
            % ones associated with p2p processors. It also gets the mass
            % changes from substance manipulators. After completing the
            % update of fMass, afMass, arPartialMass and other related
            % properties this method sets the phase's timestep outdated, so
            % it will be recalculated during the post-tick. Additionally,
            % if this phase is set as 'sycned', this method will set all
            % branches connected to exmes of this phase to outdated, also
            % causing a recalculation in the post-tick.
            % Note that the temperature will not be updated here, as the
            % update of the temperature is handled in the thermal domain.
            % However, since a change in a mass branch triggers a mass
            % update and a temperature update in the thermal domain, the
            % temperature will be update if a mass update is called (but
            % there is no direct connection between the two domains)
            
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastMassUpdate;
            
            % Return if no time has passed. Since the mass transfer is
            % always a flowrate multiplied with an elapsed time we do not
            % have to recalculate everything
            if fLastStep == 0
                % This is necessary to ensure the TS is set outdated for
                % cases where flow phases are handled (as they can change
                % their partial mass composition after the solvers are
                % updated, which is after the initial mass updates)
                this.setOutdatedTS();
                return;
                % Note that also setting branches outdated here would lead
                % to infinite loops within the timer and is therefore not
                % possible!
            end
            
            if ~base.oDebug.bOff, this.out(tools.debugOutput.INFO, 1, 'exec', 'Execute massupdate in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end

            % Immediately set fLastMassUpdate, so if there's a recursive call
            % to massupdate, e.g. by a p2ps.flow, nothing happens!
            this.fLastMassUpdate     = fTime;
            this.fMassUpdateTimeStep = fLastStep;
            
            % All in-/outflows in [kg/s] and multiply with curernt time
            % step, also get the inflow rates / temperature / heat capacity
            %SPEED OPT - value saved in last calculateTimeStep are still
            % valid as any change in these values would trigger a time step
            % recalculation. Also if they did change (which can trigger
            % this update) we still want to use the old values, because we
            % first have to move the mass according to the old values. See
            % https://wiki.tum.de/display/vhab/6.+Mass+Balance for detailed
            % information on this
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
            % can happen when more mass of a specific substance is taken
            % out of the phase than is currently present within it. The
            % calculateTimeStep function limits this effect to 1e-8 kg per
            % tick.            
            % In any case, we don't interrupt the simulation for this, we
            % just log the masses and set them to zero in the afMass array.
            % Since overwriting a negative mass with zero effectivly
            % generates mass the generated mass values are stored in
            % afMassGenerated and provided as output at the end of the
            % simulation
            abNegative = this.afMass < 0;
            if any(abNegative)
                this.afMassGenerated(abNegative) = this.afMassGenerated(abNegative) - this.afMass(abNegative);
                this.afMass(abNegative) = 0;
                
                if ~base.oDebug.bOff
                    this.out(tools.debugOutput.NOTICE, 1, 'negative-mass', 'Got negative mass, added to mass lost.', {}); % directly follows message above, so don't output name
                    this.out(3, 2, 'negative-mass', '%s\t', this.oMT.csI2N(abNegative));
                end
                
            end
            % Update total mass
            this.fMass = sum(this.afMass);

            % Now calculate the new total heat capacity for the
            % asscociated capacity (the specific heat capacity is updated
            % based on changes in pressure/tenperature etc as it is only
            % indirectly influenced by the mass)
            this.oCapacity.setTotalHeatCapacity(this.fMass * this.oCapacity.fSpecificHeatCapacity);
            
            % Update the partial masses. In case this is a normal phase the
            % partial masses are simply this.afMass/this.fMass. Otherwise
            % we trigger the event update_partials which is handled in the
            % subclass matter.phases.flow.flow and calculates the partial
            % mass based on the current inflows
            if ~this.bFlow
                if this.fMass > 0
                    this.arPartialMass = this.afMass / this.fMass;
                else
                    this.arPartialMass = this.afMass; % afMass is just zeros
                end
            else
                this.trigger('update_partials');
            end
            
            % we set all branches connected with this phase to outdated
            this.setBranchesOutdated();
            
            this.setP2PsAndManipsOutdated();
            
            % Phase sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
            
            
            if this.bTriggerSetMassUpdateCallbackBound
            	this.trigger('massupdate_post');
            end
        end
        
        function this = update(this)
            %% update
            % INTERNAL FUNCTION! This method can only be executed in the
            % post tick, if a user wants to execute an update the
            % registerUpdate function of the phase should be used to
            % trigger the post tick update in the current tick!
            %
            % This function updates matte related properties of the phase,
            % like the pressure and the molar mass. More specific update
            % functions for specific phases can be included in child
            % classes (e.g. the matter.phases.gas class implements specific
            % update calculation)
            
            % Only update if not yet happened at the current time.
            if (this.oTimer.fTime <= this.fLastUpdate) || (this.oTimer.fTime < 0)
                if ~base.oDebug.bOff, this.out(2, 1, 'update', 'Skip update in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end
                
                return;
            end
            
            if ~base.oDebug.bOff, this.out(2, 1, 'update', 'Execute update in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end
            
            % save the update time to a property to check if we already
            % update at this time
            this.fLastUpdate = this.oTimer.fTime;
            
            % If it is a flow phase, we also trigger an update of the
            % partial masses to ensure that they are correct
            if this.bFlow
            	this.trigger('update_partials');
            end
            
            % Cache current fMass / afMass so they represent the values at
            % the last phase update. Needed in phase time step calculation.
            this.fMassLastUpdate  = this.fMass;
            this.afMassLastUpdate = this.afMass;

            % Now update the matter properties
            this.fMolarMass = this.oMT.calculateMolarMass(this.afMass);
            
            % we check against the timestep and only do the calculation if
            % it hasn't been done before. Additional checks if the matter
            % properties changed sufficiently to make a matter table update
            % of the property necessary are performed within the function
            if ~(this.oTimer.fTime == this.oCapacity.fLastTotalHeatCapacityUpdate)
                this.oCapacity.updateSpecificHeatCapacity();
            end
            
            % The update is finished, therefore we set the flag to false
            % that this phase will be updated in the post tick
            this.bUpdateRegistered = false;
            
            % Now we trigger an update_post event which allows other
            % objects/functions to bind themself to the update of this
            % phase
            if this.bTriggerSetUpdateCallbackBound
            	this.trigger('update_post');
            end
            
        end
        
        function detachManipulator(this, sManip)
            %% detachManipulator
            % INTERNAL FUNCTION! This function cannot be accessed directly,
            % as it is created and passed out on the creation of the manip,
            % to ensure that the correct manip is removed!
            %
            % this function can be used to remove a manipulator from the
            % system. It is returned as function handle with the necessary
            % inputs upon adding the manipulator to the phase, therefore
            % the function is protected and cannot be accessed any other
            % way
            this.toManips.(sManip) = [];
        end

        function setBranchesOutdated(this)
            %% setBranchesOutdated
            % INTERNAL FUNCTION! This is triggered by the massupdate
            % function of the phase and triggering it through other means
            % as well could (depending on the use case) lead to infinite
            % loops in the execution. Therefore access is restricted, but
            % the user can trigger a massupdate using the
            % registerMassUpdate function also if the branches should be
            % outdated!
            %
            % This function is used to set the Branches connected to this
            % phase outdated in case relevant phase parameters have changed            
            
            % If the phase is a flow phase it can be necessary to set the
            % outgoing branches outdated even if this has already happened
            % before in this tick! Since the input branches can change the
            % partial mass composition of the flow nodes and the execution
            % order between input and output branches is initially not
            % defined
            if this.fLastSetOutdated >= this.oTimer.fTime
                if this.bFlow
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
        
        function setP2PsAndManipsOutdated(this)
            %% setP2PsAndManipsOutdated
            % INTERNAL FUNCTION! This is triggered by the massupdate
            % function of the phase and triggering it through other means
            % as well could (depending on the use case) lead to infinite
            % loops in the execution. Therefore access is restricted, but
            % the user can trigger a massupdate using the
            % registerMassUpdate function also if the P2Ps/Manips should be
            % outdated!
            %
            % this function is used to set all manipualtors and P2Ps
            % outdated, which tells them to perform a post tick update
            
            % To improve sim speed for phases without any manip we check
            % the iManipualtors property
            if this.iSubstanceManipulators > 0
                this.toManips.substance.registerUpdate();
            end
            if this.iVolumeManipulators > 0
                this.toManips.volume.registerUpdate();
            end
            % same as for the manips, for improved sim speed we first check
            % if there are P2Ps
            if this.iProcsP2P > 0
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
            %% setOutdatedTS
            % INTERNAL FUNCTION! This function is called by the
            % registerUpdate function
            %
            % Setting this to true multiple times in the timer is no
            % problem, therefore no check required
            this.hBindPostTickTimeStep();
        end
        
        % since the fPressure property is accessed by get.fPressure this
        % function should be protected as it should not be used directly.
        % It cannot be private because that prevent the function from
        % beeing overwritten by child classes
        function fPressure = get_fPressure(this)
            %% get_fPressure
            % defines how to calculate the dependent fPressure property.
            % Can be overloaded by child classes which require a different
            % calculation (e.g. flow phases)
            fMassSinceUpdate = this.fCurrentTotalMassInOut * (this.oStore.oTimer.fTime - this.fLastMassUpdate);
            
            fPressure = this.fMassToPressure * (this.fMass + fMassSinceUpdate);
        end
    end
    methods (Access = private)
        % Only the phase itself should have access to this function. Access
        % by other functions is handled through specific bind/unbind
        % callbacks
        function setProperty(this, sPropertyName, xNewValue)
            %% setProperty
            % INTERNAL FUNCTION! Can only be used by manips and for those
            % the access is provided through the bindSetProperty function!
            %
            % This function can be used to set otherwise internal
            % parameters of a phase. This is necessary for example to
            % adjust the volume of phases (e.g. if a gas, liquid, solid
            % phase are all in one store and more liquid is added etc).
            % This function can in principle be used to set any property,
            % however the call necessary 
            %
            % setParameter parameters:
            %   sPropertyName   - name of the property that should be set
            %                     (e.g. fVolume)
            %   xNewValue       - value to which the property should be set
            
            this.(sPropertyName) = xNewValue;
            % if a parameter of the phase changed, we must recalculate
            % everything else
            this.registerUpdate();
        end
    end
end