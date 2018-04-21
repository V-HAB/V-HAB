classdef (Abstract) phase < base & matlab.mixin.Heterogeneous & event.source
    %PHASE Phase with isotropic properties (abstract class)
    %   This class represents a matter phase with homogeneous mass
    %   distribution and thus isotropic properties. It is not meant to be
    %   used directly, use e.g. |matter.phases.gas| instead.
    %
    %TODO: rename to |IsotropicPhase| or |HomogeneousPhase|
    %
    %TODO: refactor some of this code out to a new |Mass| class and inherit
    %      from it??
    %
    %TODO (further ideas)
    %   * conduct (mass)update calculations for all phases scheduled for
    %     current tick in a single post-tick (before solvers/timesteps)
    %     callback simultaneously
    %   * manipulators for volume - package matter.manips.volume, different
    %     base classes for isobaric, isochoric etc. volume changes
    %     -> how to handle the store (which distributes the volume equally
    %        throughout gas phases)? How to treat volume changes due to
    %        inflowing matter?
    %   * method .setHeatSource(oHeatSource), see thermal solver
    %   * post-tick priorities / execution groups: separate update of flow
    %     p2ps and manips - first post-tick callback - from the time step
    %     calculation - second post-tick callback. In post tick, first
    %     exec phase properties update methods (mass, molar mass etc), then
    %     the solver flow rates. Then the phase manips/p2ps can update and
    %     finally the phases can calculate their time steps. Each p2p/manip
    %     should add itself to post-tick - if already done, not done again.

    properties (Abstract, Constant)

        % State of matter in phase (e.g. gas, liquid, solid), used for
        % example by the EXMEs to check compatibility.
        %TODO: rename to |sMatterState|
        %TODO: drop this and let the code check for |isa(oObj, 'matter.phase.gas')| ?
        % @type string
        sType;

    end

    properties (SetAccess = protected, GetAccess = public)
        % Basic parameters:

        % Mass of every substance in phase
        %TODO: rename to |afMasses| or better
        % @type array
        % @types float
        afMass;       % [kg]

        % Temperature of phase
        % @type float
        fTemperature; % [K]
    end

    properties (SetAccess = protected, GetAccess = public) %(Dependent, ?Access???)
        % Dependent variables:
        %TODO: investigate making them dependent + using accessors methods

        % (Mean?) Density of mixture; not updated by this class, has to be
        % handled by a deriving class.
        % @type float
        fDensity = -1; % [kg/m^3]

        % Total negative masses per substance encountered during mass
        % update. This data is only kept for debugging/logging purposes.
        % If a branch requests more mass of a substance than stored in the
        % phase, there is currently no way to tell the branch about this
        % issue. Instead of throwing an error or setting a negative value
        % for the substance mass, the mass is set to zero and the absolute
        % 'lost' (negative) mass is added to this vector.
        %TODO implement check in matter.branch setFlowRate for this issue?
        %     What if several branches request too much mass?
        % @type array
        % @types float
        afMassLost;

        % Mass fraction of every substance in phase
        %TODO: rename to |arMassFractions|
        % @type array
        % @types float
        arPartialMass; % [%]

        % Total mass of phase
        %TODO: rename to |fTotalMass|
        % @type float
        fMass;         % [kg]

        % Molar mass of mixture in phase
        % @type float
        fMolarMass;    % [kg/mol]
        
    end

    properties (SetAccess = protected, GetAccess = public)
        % Internal properties, part 1:
        %TODO: investigate if this block can be merged with other ones

        % Length of the last time step (??)
        fTimeStep;
        
        % Do we need to trigger the massupdate/update events? These
        % properties were implement to improve simulation speed for cases
        % where these triggers are not used
        bTriggerSetMassUpdateCallbackBound = false;
        bTriggerSetUpdateCallbackBound = false;
    end

    properties (SetAccess = private, GetAccess = public)
        % Internal properties, part 2:
        %TODO: investigate if this block can be merged with other ones

        % Associated matter store object
        %TODO: rename because everything must be new now >:-]
        oStore;

        % Matter table object
        oMT;

        % Timer object
        oTimer;

        % Capacity object
        oCapacity;
        
        % User-defined name of phase
        % @type string
        %TODO: rename to |sIdent|??
        %TODO: auto-generate name???
        sName;

        % List of Extract/Merge processors added to the phase: Key of
        % struct is set to the processor's name and can be used to retrieve
        % that object.
        %TODO: rename to |toExMePorts|, |toExMeProcessors|, etc.; or ?
        %TODO: use map and rename to |poExMeProcessors|?
        % @type struct
        % @types object
        toProcsEXME = struct();

        % Cache: List and count of ExMe objects, used in |this.update()|
        %NOTE: cf. |toProcsEXME| property
        %TODO: investigate if we need this or data can be stored
        %      differently, e.g. in a general cache property
        %TODO: rename to something more fitting
        coProcsEXME;
        iProcsEXME;

        % Cache: List and count of all p2p flow processor objects (i.e.
        % |matter.procs.p2ps.flow|) that are connected to an ExMe of this
        % phase. Used to quickly access the objects in |this.massupdate()|;
        % created in |this.seal()|.
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        coProcsP2Pflow;
        iProcsP2Pflow;
        
        % List and number of manipulators added to the phase
        % @type struct
        % @types object
        toManips = struct('volume', [], 'temperature', [], 'substance', []);
        iManipulators = 0;
        
        
        
        % Multi-heat-source to allow temperature changes - also used by the
        % thermal solver.
        oMultiHeatSource;
        bMultiHeatSourceAdded = false;
        
        

        % Last time the phase was updated (??)
        % @type float
        fLastMassUpdate = -10;

        % Time step in last massupdate (???)
        % @type float
        fMassUpdateTimeStep = 0;

        % Current total incoming or (if negative value) outgoing mass flow,
        % for all substances combined. Used to improve pressure estimation
        % in ExMe processors.
        % @type float
        fCurrentTotalMassInOut = 0;
        
        % Storage - preserve those props from .calcTS!
        afCurrentTotalInOuts;
        mfCurrentInflowDetails;
        

        % We need to remember when the last call to the update() method
        % was. This is to prevent multiple updates per tick. 
        fLastUpdate = -10;
        
        % Last time branches were set oudated
        fLastSetOutdated = -10;
        
    end

    properties (Access = protected)

        % Boolean indicator of an outdated time step
        %TODO rename to bOutdatedTimeStep
        bOutdatedTS = false;

    end

    properties (Access = public)
        % If true, massupdate triggers all branches to re-calculate their
        % flow rates. Use when volumes of phase compared to flow rates are
        % small!
        bSynced = false;
        
        % For very small phases, bFlow can be set to true. With that, the
        % outflowing matter properties will be set to the sum of the
        % inflowing matter, taking p2ps/manip.substance into account. Also,
        % properties like molar mass and heat capacity are calculated on 
        % the fly.
        % NOTE this is experimental and was not tested in all possible confi-
        %      gurations, e.g. when using p2ps and a substance manipulator.
        %      Also, as various properties are calculated on the fly, there
        %      might be situations where this is slower.
        bFlow = false;
        
        
        
        % Properties to decide when the specific heat capacity has to be
        % recalculated
        fPressureLastHeatCapacityUpdate    = 0;
        fTemperatureLastHeatCapacityUpdate = 0;
        arPartialMassLastHeatCapacityUpdate;
       
    end

    properties (SetAccess = private, GetAccess = public)
        
        
        % Maximum allowed percentage change in the total mass of the phase
        rMaxChange = 0.25;
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
        
        % Maximum factor with which rMaxChange is decreased
        rHighestMaxChangeDecrease = 0;

        
        % Masses in phase at last update.
        fMassLastUpdate;
        afMassLastUpdate;
        
        % Log mass and time steps which are used to influence rMaxChange
        afMassLog;
        afLastUpd;
        
    end

    methods

        function this = phase(oStore, sName, tfMass, fTemperature)
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

            % Parent has to be a or derive from matter.store
            if ~isa(oStore, 'matter.store'), this.throw('phase', 'Provided oStore parameter has to be a matter.store'); end;

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
            
            this.afMass = this.oMT.addPhase(this);
            
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

                    % Throw an error if the matter substance is not in the
                    % matter table
                    if ~isfield(this.oMT.tiN2I, sKey), this.throw('phase', 'Matter type %s unkown to matter.table', sKey); end;

                    this.afMass(this.oMT.tiN2I.(sKey)) = tfMass.(sKey);
                end

                % Calculate total mass
                this.fMass = sum(this.afMass);


                % Calculate the partial masses
                if this.fMass > 0, this.arPartialMass = this.afMass / this.fMass;
                else               this.arPartialMass = this.afMass; % afMass is just zeros
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
            this.afMassLost = zeros(1, this.oMT.iSubstances);

            % add a thermal capacity to this phase to handle thermal
            % calculations 
            this.oCapacity = thermal.capacity(this, fTemperature);
            
            % Now update the matter properties
            this.oCapacity.updateSpecificHeatCapacity();
               
            % Preset the cached masses (see calculateTimeStep)
            this.fMassLastUpdate  = 0;
            this.afMassLastUpdate = zeros(1, this.oMT.iSubstances);
        end

        function this = massupdate(this, bSetBranchesOutdated)
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
            
            
            
            if nargin < 2, bSetBranchesOutdated = false; end;

            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastMassUpdate;
            
            
            
            % Return if no time has passed
            if fLastStep == 0
                
                if ~base.oLog.bOff, this.out(2, 1, 'skip', 'Skipping massupdate in %s-%s-%s\tset branches outdated? %i', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, bSetBranchesOutdated }); end;
                
                %NOTE need that in case .exec sets flow rate in manual branch triggering massupdate,
                %     and later in that tick phase does .update -> branches won't be set outdated!
                if bSetBranchesOutdated
                    this.setBranchesOutdated();
                end
                
                return;
            end
            
            if ~base.oLog.bOff, this.out(tools.logger.INFO, 1, 'exec', 'Execute massupdate in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end;

            % Immediately set fLastMassUpdate, so if there's a recursive call
            % to massupdate, e.g. by a p2ps.flow, nothing happens!
            this.fLastMassUpdate     = fTime;
            this.fMassUpdateTimeStep = fLastStep;
            
            % All in-/outflows in [kg/s] and multiply with curernt time
            % step, also get the inflow rates / temperature / heat capacity
            %SPEED OPT - value saved in last calculateTimeStep, still valid
            %[ afTotalInOuts, mfInflowDetails ] = this.getTotalMassChange();
            afTotalInOuts = this.afCurrentTotalInOuts;
            mfInflowDetails = this.mfCurrentInflowDetails;
            
            if ~base.oLog.bOff, this.out(1, 2, 'total-fr', 'Total flow rate in %s-%s: %.20f', { this.oStore.sName, this.sName, sum(afTotalInOuts) }); end;
            
            % Check manipulator
            if ~isempty(this.toManips.substance) && ~isempty(this.toManips.substance.afPartialFlows)
                % Add the changes from the manipulator to the total inouts
                afTotalInOuts = afTotalInOuts + this.toManips.substance.afPartialFlows;
                
                if ~base.oLog.bOff, this.out(tools.logger.MESSAGE, 1, 'manip-substance', 'Has substance manipulator'); end; % directly follows message above, so don't output name
            end

            % Cache total mass in/out so the EXMEs can use that
            this.fCurrentTotalMassInOut = sum(afTotalInOuts);
            
            
            % Multiply with current time step
            afTotalInOuts = afTotalInOuts * fLastStep;
            %afTotalInOuts = this.getTotalMassChange() * fTimeStep;
            
            % Do the actual adding/removing of mass.
            %CHECK round the whole, resulting mass?
            %  tools.round.prec(this.afMass, this.oTimer.iPrecision)
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
                this.afMassLost(abNegative) = this.afMassLost(abNegative) - this.afMass(abNegative);
                this.afMass(abNegative) = 0;
                
                if ~base.oLog.bOff
                    this.out(tools.logger.NOTICE, 1, 'negative-mass', 'Got negative mass, added to mass lost.', {}); % directly follows message above, so don't output name
                    %this.out(3, 2, 'negative-mass', 'TODO: output all substance names with negative masses!');
                    this.out(3, 2, 'negative-mass', '%s\t', this.oMT.csI2N(abNegative));
                end
                
                %csNegatives = {};
                
%                 for iNeg = 1:length(abNegative)
%                     if ~abNegative(iNeg), continue; end;
%                     
%                     csNegatives{end + 1} = this.oMT.csI2N{iNeg};
%                 end
            end


            %%%% Now calculate the new total heat capacity for the
            %%%% asscociated capacity
            this.oCapacity.setTotalHeatCapacity(this.fMass * this.oCapacity.fSpecificHeatCapacity);
            
            % Update total mass
            this.fMass = sum(this.afMass);
            
            
            % Trigger branch solver updates in post tick for all branches
            % whose matter is currently flowing INTO the phase
            if this.bSynced || bSetBranchesOutdated
                %%%this.setBranchesOutdated('in');
                this.setBranchesOutdated();
                this.setBranchesOutdated('both', true); % true to indicate that only residual branches are set outdated
            end
            
            % Execute updateProcessorsAndManipulators between branch solver
            % updates for inflowing and outflowing flows
            if this.iProcsP2Pflow > 0 || this.iManipulators > 0
                this.oTimer.bindPostTick(@this.updateProcessorsAndManipulators, 1);
            end
            
            % Flowrate update binding for OUTFLOWING matter flows.
            if this.bSynced || bSetBranchesOutdated
                %%%this.setBranchesOutdated('out');
            end

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
                if ~base.oLog.bOff, this.out(2, 1, 'update', 'Skip update in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end;
                
                return;
            end
            
            if ~base.oLog.bOff, this.out(2, 1, 'update', 'Execute update in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end;
            

            % Store update time
            this.fLastUpdate = this.oTimer.fTime;


            % Actually move the mass into/out of the phase.
            % Pass true as a parameter so massupd calls setBranchesOutdated
            % even if the bSynced attribute is not true
            this.massupdate(true);
            this.oCapacity.updateTemperature(true);

            % Cache current fMass / afMass so they represent the values at
            % the last phase update. Needed in phase time step calculation.
            this.fMassLastUpdate  = this.fMass;
            this.afMassLastUpdate = this.afMass;


            % Partial masses
            if this.fMass > 0
                this.arPartialMass = this.afMass / this.fMass;
            else
                this.arPartialMass = this.afMass; % afMass is just zeros
            end

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
            
            if this.bTriggerSetUpdateCallbackBound
            	this.trigger('update_post');
            end
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
            % trSubstanceMaxChange: Alterantive Input instead of
            %               arMaxChange that contains a struct reference
            %               for the maximum allowed partial mass change.
            %               For example tTimeStepProperties.trSubstanceMaxChange = struct('H2O', 0.0001, 'CO2', 0.01)
            % fMaxStep:     Maximum time step in seconds
            % fMinStep:     Minimum time step in seconds
            % fFixedTimeStep:     Fixed (constant) time step in seconds, if this
            %               property is set all other time step properties
            %               will be ignored and the set time step will be
            %               used
            %
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            csPossibleFieldNames = {'rMaxChange', 'arMaxChange', 'fMaxStep', 'fMinStep', 'fFixedTimeStep'};
            
            % In case the struct reference for the partial mass change is
            % used the arMaxChange vector for the internal calculations has
            % to be created based on the provided struct
            if isfield(tTimeStepProperties, 'trSubstanceMaxChange')
                csSubstances = fieldnames(tTimeStepProperties.trSubstanceMaxChange);
                arMaxChangeTemp = zeros(1,this.oMT.iSubstances);
                for iSubstance = 1:length(csSubstances)
                    arMaxChangeTemp(this.oMT.tiN2I.(csSubstances{iSubstance})) = tTimeStepProperties.trSubstanceMaxChange.(csSubstances{iSubstance});
                end
                tTimeStepProperties.arMaxChange = arMaxChangeTemp;
                % removes the struct field as it has now been replaced by
                % the arMaxChange vector
                tTimeStepProperties = rmfield(tTimeStepProperties, 'trSubstanceMaxChange');
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


    %% Methods for interfacing with thermal system
        
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

        % TBD: Do we still want this?
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
                if isempty(fFlowRate), continue; end;
                
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
            
            
            
            
            afTotalInOuts   = tools.round.prec(afTotalInOuts,   this.oTimer.iPrecision);
            mfInflowDetails = tools.round.prec(mfInflowDetails, this.oTimer.iPrecision);
        end
        
    end


    %% Finalize methods
    methods

        function seal(this)
            
            % Preset mass and time step logging attributes
            % iPrecision ^ 2 is more or less arbitrary
            iStore = this.oTimer.iPrecision ^ 2;
            
            this.afMassLog = ones(1, iStore) * this.fMass;
            this.afLastUpd = 0:(1/(iStore-1)):1;%ones(1, iStore) * 0.00001;
            
            %TODO oData.rUF -> this.oStore.oContainer.oRoot.tSolverParams
            this.rHighestMaxChangeDecrease = this.oStore.oContainer.tSolverParams.rHighestMaxChangeDecrease;
            
            
            % Auto-Set rMaxChange - max. 0.25, min. 1e-5!
            rMaxChangeTmp = sif(this.fVolume <= 0.25, this.fVolume, 0.25);
            rMaxChangeTmp = sif(rMaxChangeTmp <= 1e-5, 1e-5, rMaxChangeTmp);
            
            this.rMaxChange = rMaxChangeTmp / this.oStore.oContainer.tSolverParams.rUpdateFrequency;
            
            
            % Max time step
            this.fMaxStep = this.oStore.oContainer.tSolverParams.fMaxTimeStep;
            
            
            
            
            %TODO if rMaxChange < e.g. 0.0001 --> do not decrease further
            %     but instead increase highestMaxChangeDec?
            
            if ~this.oStore.bSealed
                this.coProcsEXME = struct2cell(this.toProcsEXME)';
                this.iProcsEXME  = length(this.coProcsEXME);


                % Get all p2p flow processors on EXMEs
                this.coProcsP2Pflow = {};
                this.iProcsP2Pflow  = 0;

                for iE = 1:this.iProcsEXME
                    % Get number and references for connected P2Ps
                    if ~isempty(this.coProcsEXME{iE}.oFlow) 
                        if isa(this.coProcsEXME{iE}.oFlow, 'matter.procs.p2ps.flow')
                            this.iProcsP2Pflow = this.iProcsP2Pflow + 1;

                            this.coProcsP2Pflow{this.iProcsP2Pflow} = this.coProcsEXME{iE}.oFlow;
                        end
                    else
                        this.throw('seal','Phase ''%s'' in store ''%s'' has an unconnected exme processor: ''%s''',this.sName, this.oStore.sName, this.coProcsEXME{iE}.sName);
                    end
                end % end of: for
            end % end of: if not sealed
            
            
            % Preset
            [ afChange, mfDetails ] = this.getTotalMassChange();

            this.afCurrentTotalInOuts = afChange;
            this.mfCurrentInflowDetails = mfDetails;
            
        end % end of: seal method

    end


    %% Internal, protected methods
    methods (Access = protected)

        function detachManipulator(this, sManip)
            
            %CHECK several manipulators possible?
            this.toManips.(sManip) = [];
            
        end

        function setBranchesOutdated(this, sFlowDirection, bResidual)
            
%             if nargin < 2
                sFlowDirection = 'both'; 
%             end
            
            if nargin < 3
                bResidual = false;
            end
            
            if this.fLastSetOutdated >= this.oTimer.fTime
                return;
            end
            
            this.fLastSetOutdated = this.oTimer.fTime;
            
            
            % Loop through exmes / flows and set outdated, i.e. request
            % recalculation of flow rate.
            for iE = 1:this.iProcsEXME
                oExme   = this.coProcsEXME{iE};
                oBranch = oExme.oFlow.oBranch;
                
                % Make sure it's not a p2ps.flow - their update method
                % is called in updateProcessorsAndManipulators method
                if bResidual
                    if ~oExme.bFlowIsAProcP2P
                        if isa(oBranch.oHandler, 'solver.matter.residual.branch')
                            % Tell branch to recalculate flow rate (done after
                            % the current tick, in timer post tick).
                            oBranch.setOutdated();
                        end
                    end
                elseif isa(oBranch, 'matter.branch')
                    % If flow direction set, only setOutdated if the
                    % flow direction is either inwards or outwards
                    if strcmp(sFlowDirection, 'in')
                        if oExme.iSign * oExme.oFlow.fFlowRate > 0
                            % ok
                        else
                            continue;
                        end
                    elseif strcmp(sFlowDirection, 'out')
                        if oExme.iSign * oExme.oFlow.fFlowRate <= 0
                            % ok
                        else
                            continue;
                        end
                    end
                    
                    % We can't directly set this oBranch as outdated if
                    % it is just connected to an interface, because the
                    % solver is assigned to the 'leftest' branch.
                    while ~isempty(oBranch.coBranches{1})
                        oBranch = oBranch.coBranches{1};
                    end
                    
                    %fprintf('%s-%s: setOutdated "%s"\n', this.oStore.sName, this.sName, oBranch.sName);
                    
                    % Tell branch to recalculate flow rate (done after
                    % the current tick, in timer post tick).
                    oBranch.setOutdated();
                end
            end % end of: for
            
        end % end of: setBranchesOutdated method
        
        function updateProcessorsAndManipulators(this)
            % Update the p2p flow and manip processors

            %TODO move this to another function or class or whatever. Why
            %is this executed here anyway?
            %ANSWER: Because we need to make sure these guys are updated
            %every time massupdate is called. Than cannot only be done by
            %the phase.update(), which is called from store.update(), but
            %also from branch.update(). Then the update methods from the
            %p2ps and manips would not be called, if they weren't in here.
            %Still, they seem out of place here and might be put into a
            %separate method? Or should we bind them to the post-tick of
            %the timer as well?
            % Check manipulator
            %TODO allow user to set a this.bManipBeforeP2P or so, and if
            %     true execute the [manip].update() before the P2Ps update!
            if ~isempty(this.toManips.substance)
                %keyboard();
                this.toManips.substance.update();

                % Add the changes from the manipulator to the total inouts
                %afTotalInOuts = afTotalInOuts + this.toManips.substances.afPartial;
            end


            %TODO move this to another function or class or whatever. Why
            % is this executed here anyway? Shouldn't that be done in the
            % Store after all phases have updated?
            %keyboard();
            % Call p2ps.flow update methods (if not yet called)
            for iP = 1:this.iProcsP2Pflow
                % That check would make more sense within the flow p2p
                % update method - however, that method will be overloaded
                % in p2ps to include the model to derive the flow rate, so
                % would have to be manually added in each derived p2p ...
                if this.coProcsP2Pflow{iP}.fLastUpdate < this.fLastMassUpdate
                    % Triggers the .massupdate of both connected phases
                    % which is ok, because the fTimeStep == 0 check above
                    % will prevent this .massupdate from re-executing.
                    this.coProcsP2Pflow{iP}.update();
                end
            end
        end
        
        
        
        function calculateTimeStep(this)
            % To calculate the new time step for this phase, we first need
            % some information on what has changed since the last time this
            % was done. 
            % First we'll get the absolute in- and outflows through all
            % EXMEs.
            % afChange contains the flow rates for all substances,
            % mfDetails contains the flow rate, temperature and heat
            % capacity for each INCOMING flow, not the outflows!
            
            % Change in kg of partial masses per second
            [ afChange, mfDetails ] = this.getTotalMassChange();
            
            
            
            afTmpCurrentTotalInOuts = this.afCurrentTotalInOuts;

            % Setting the properties to the current values
            this.afCurrentTotalInOuts = afChange;
            this.mfCurrentInflowDetails = mfDetails;
            
            % If we have set a fixed time steop for this phase, we can just
            % continue without doing any calculations.
            if ~isempty(this.fFixedTimeStep)
                fNewStep = this.fFixedTimeStep;
            else
                rMaxChangeFactor = 1;
                
                % Log the current mass and time to the history arrays
                this.afMassLog = [ this.afMassLog(2:end) this.fMass ];
                this.afLastUpd = [ this.afLastUpd(2:end) this.oTimer.fTime ];
                
                
                %% Provision for adaptive rMaxChange
                % Mass change in percent/second over logged time steps
                % Convert mass change to kg/s, take mean value and divide 
                % by mean tank mass -> mean mass change in %/s (...?)
                % If the mass is constant but unstable (jumping around a mean
                % value), the according mass in- and decreases should cancle
                % each other out.
                
                if this.rHighestMaxChangeDecrease > 0

                    % max or mean?
                    fDev = mean(diff(this.afMassLog) ./ diff(this.afLastUpd)) / mean(this.afMassLog);
                    %fDev = max(abs(diff(this.afMassLog) ./ diff(this.afLastUpd))) / mean(this.afMassLog);

                    % Order of magnitude of fDev
                    fDevMagnitude = abs(log(abs(fDev))./log(10));

                    % Inf? -> zero change.
                    if fDevMagnitude > this.oTimer.iPrecision, fDevMagnitude = this.oTimer.iPrecision;
                    elseif isnan(fDevMagnitude),                      fDevMagnitude = 0;
                    end;

                    % Min deviation (order of magnitude of mass change) 
                    iMaxDev = this.oTimer.iPrecision;
                    
                    
                    % Other try - exp
                    afBase = (0:0.01:1) .* iMaxDev;
                    afRes  = (0:0.01:1).^3 .* (this.rHighestMaxChangeDecrease - 1);

                    rFactor = interp1(afBase, afRes, fDevMagnitude, 'linear');

                    %fprintf('%i\t%i\tDECREASE rMaxChange from %f by %f to %f\n', iDev, iThreshold, rMaxChangeTmp, rFactor, rMaxChangeTmp / rFactor);

                    rMaxChangeFactor = 1 / (1 + rFactor);
                end
                
                
                %% Calculating the changes of mass in phase since last mass update.

                % Calculate the change in total and partial mass since the
                % phase was last updated
                rPreviousChange  = abs(this.fMass   / this.fMassLastUpdate  - 1);
                % The partial mass changes need to be compared to the total
                % mass in the phase, not to themselves, else if a trace gas
                % mass does change significantly, it will reduce the time
                % step too much even though it does not change the overall
                % phase properties a lot.
                %TODO maybe use change in temperature, molar mass, ... as
                %     reference, not the partial mass changes?
                %arPreviousChange = abs(this.afMass ./ this.afMassLastUpdate - 1);
                arPreviousChange = abs(this.afMass - this.afMassLastUpdate) / this.fMass;
    
                
                % If rPrevious change is not a number ('NaN'), the mass
                % during the previous update was zero and the current mass
                % is also zero. That means that afMass was also all zeros
                % during this and the previous update. Therfore the
                % relative change between updates is zero.
                if isnan(rPreviousChange)
                    rPreviousChange  = 0;
                    arPreviousChange = zeros(1, this.oMT.iSubstances);
                end
                
                % If rPreviousChange is infinity ('Inf'), that means that
                % the mass during the last update was zero, but now it is
                % not. The arPreviousChange array will be mostly NaN
                % values, except for the ones where the mass changed from
                % zero to something else. Since the calculation of
                % fNewStepPartials later in this function uses the max()
                % method on arPrevious change, we don't have to do anything
                % here, because it will return one of the 'Inf' values from
                % arPreviousChange. 
                
                %% Calculating the changes of mass in phase during this update.
                
                % To calculate the change in partial mass, we only use
                % entries where the change is not zero. If some substance
                % changed a little bit, but less then the precision
                % threshold, and does not change any more, it is not taken
                % into account. It can still change in relation to other
                % substances, where mass flows in/out, but that should be
                % covered by the total mass change check.
                % The unit of arPartialsChange is [1/s], so multiplied by
                % 100 % we would have a percentage change per second for
                % each substance.
                abChange = (afChange ~= 0);
                arPartialsChange = abs(afChange(abChange) ./ tools.round.prec(this.fMass, this.oTimer.iPrecision));

                % Only use non-inf values. They would be inf if the current
                % mass of according substance is zero. If a new substance
                % enters the phase, it is still covered through the overall
                % mass check.
                % By getting the maximum of the arPartialsChange array, we
                % have the maximum change of partial mass within the
                % phase.
                rPartialsPerSecond = max(arPartialsChange(~isinf(arPartialsChange)));
                
                %CHECK Why would this be empty?
                if isempty(rPartialsPerSecond), rPartialsPerSecond = 0; end;

                % Calculating the change per second of TOTAL mass.
                % rTotalPerSecond also has the unit [1/s], giving us the
                % percentage change per second of the overall mass of the
                % phase.
                fChange = sum(afChange);

                if fChange == 0
                    rTotalPerSecond = 0;
                else
                    % The change needs to be calculated with respect to the
                    % total mass at the time of the last update, as values
                    % like molar mass or the heat capacity were calculated
                    % based on that mass.
                    % Using fMass could lead to two issues:
                    % * prolonged/shortened time steps, if the mass in the
                    %   phase in- or decreases (rTotalPerSecond will be
                    %   smaller if the current mass is larger than the one
                    %   at the last update -> smaller change = larger TS).
                    % * the previous change is based on the mass at last
                    %   updated whereas the current change is based on the
                    %   current mass. This can lead to a change slightly 
                    %   larger than rMaxChange leading to a negative time
                    %   step. This however will only happen if the store
                    %   would update soon anyways and should therefore not
                    %   lead to larger issues.
                    %CHECK use fMassLastUpdate or fMass? The latter leads
                    %      to larger time steps but is logically slightly
                    %      incorrect. [also above, arPartialsChange!]
                    % FOR NOW ... we'll go with fMass, faster and does not
                    % seem to introduce big issues ...
                    rTotalPerSecond = abs(fChange / this.fMass);
                end
                
                %% Partial mass change compared to partial mas
                % note that rPartialsPerSecond from the calculation is the
                % partial mass change compared to the total mass, while
                % this calculation is the partial mass change compared to
                % the respective partial mass. This second calculation
                % therefore is more restrictive and is normally deactivated
                % but can be activated by setting any value of the
                % arMaxChange property to something other than zero
                if this.bHasSubstanceSpecificMaxChangeValues 
                    afCurrentMass = this.afMass;

                    % Partial masses that are smaller than the minimal time
                    % step are rounded to the minimal time step to prevent
                    % extremly small partial masses from delaying the
                    % simulation (otherwise the timestep will go asymptotically
                    % towards zero the smaller the partial mass becomes)
                    afCurrentMass(this.afMass < 10^(-this.oTimer.iPrecision)) = 10^(-this.oTimer.iPrecision);
                    arPartialChangeToPartials = abs(afChange ./ tools.round.prec(afCurrentMass, this.oTimer.iPrecision));
                    % Values where the partial mass is zero are set to zero,
                    % otherwise the value for these is NaN or Inf
                    arPartialChangeToPartials(this.afMass == 0) = 0;

                    afNewStepPartialChangeToPartials = (this.arMaxChange * rMaxChangeFactor) ./ arPartialChangeToPartials;
                    
                    % Values where the arMaxChange value is zero are not of
                    % interest for the user and are therefore set to inf
                    % time steps (setting a max change of zero does not
                    % make sense in any situation where I am actually
                    % interest in the change of the substance, therefore
                    % this logic was chosen)
                    afNewStepPartialChangeToPartials(this.arMaxChange == 0) = inf;

                    % The new timestep from this logic is the smallest of
                    % all partial mass change time steps
                    fNewStepPartialChangeToPartials = min(afNewStepPartialChangeToPartials);
                else
                    % If the logic is deactivate (arMaxChange is empty or
                    % every entry is 0) then the timestep from this
                    % calculation is infinite.
                    fNewStepPartialChangeToPartials = inf;
                end
                
                %% Calculating the new time step

                % To derive the timestep, we use the percentage change of
                % the total mass or the maximum percentage change of one of
                % the substances' relative masses.
                fNewStepTotal    = (this.rMaxChange * rMaxChangeFactor - rPreviousChange) / rTotalPerSecond;
                fNewStepPartials = (this.rMaxChange * rMaxChangeFactor - max(arPreviousChange)) / rPartialsPerSecond;
                
                % The new time step will be set to the smaller one of these
                % two candidates.
                fNewStep = min([ fNewStepTotal fNewStepPartials fNewStepPartialChangeToPartials]);

                if fNewStep < 0
                    if ~base.oLog.bOff, this.out(3, 1, 'time-step-neg', 'Phase %s-%s-%s has neg. time step of %.16f', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep }); end;
                end
                
                % If our newly calculated time step is larger than the
                % maximum time step set for this phase, we use this
                % instead.
                if fNewStep > this.fMaxStep
                    fNewStep = this.fMaxStep;
                    %TODO Make this output a lower level debug message.
                    %fprintf('\nTick %i, Time %f: Phase %s setting maximum timestep of %f\n', this.oTimer.iTick, this.oTimer.fTime, this.sName, this.fMaxStep);
                    
                % If the time step is smaller than the set minimal time
                % step for the phase the minimal time step is used
                % (standard case is that fMinStep is 0, but the user can
                % set it to a different value)
                elseif fNewStep < this.fMinStep
                    fNewStep = this.fMinStep;
                    %TODO Make this output a lower level debug message.
                    %fprintf('Tick %i, Time %f: Phase %s.%s setting minimum timestep\n', this.oTimer.iTick, this.oTimer.fTime, this.oStore.sName, this.sName);
                end
                
                
                if ~base.oLog.bOff
                    this.out(1, 1, 'prev-timestep', 'Previous changes for new time step calc for %s-%s-%s - previous change: %.8f', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, rPreviousChange });
                    this.out(1, 2, 'prev-timestep', 'PREV TS: %.16f s, ACtual Time: %.16f s', { this.fTimeStep, this.oTimer.fTime });
                    this.out(1, 2, 'prev-timestep', 'Last Update: %.16f s, Mass at Last Update: %.16f s', { this.fLastUpdate, this.fMassLastUpdate });
                    this.out(1, 2, 'prev-timestep', 'MASS: %.16f kg, Prevous Mass Change Rate: %.16f kg/s / Total: %.16f kg ', { this.fMass, sum(afTmpCurrentTotalInOuts), sum(afTmpCurrentTotalInOuts)*(this.oTimer.fTime-this.fLastUpdate) });
                    this.out(1, 2, 'prev-timestep', 'MASS: %.16f kg, New Mass Change Rate: %.16f kg/s / Total: %.16f kg ', { this.fMass, sum(this.afCurrentTotalInOuts), sum(this.afCurrentTotalInOuts)*fNewStep });


                    this.out(1, 1, 'new-timestep', '%s-%s-%s new TS: %.16fs', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep });
                end
            end


            % Set the time at which the containing store will be updated
            % again. Need to pass on an absolute time, not a time step.
            % Value in store is only updated, if the new update time is
            % earlier than the currently set next update time.
            %this.oStore.setNextUpdateTime(this.fLastMassUpdate + fNewStep);
            this.oStore.setNextTimeStep(fNewStep);

            % Cache - e.g. for logging purposes
            this.fTimeStep = fNewStep;

            % Now up to date!
            this.bOutdatedTS = false;
        end

        function setOutdatedTS(this)
            
            if ~this.bOutdatedTS
                this.bOutdatedTS = true;

                this.oTimer.bindPostTick(@this.calculateTimeStep, 3);
            end
        end

        function setAttribute(this, sAttribute, xValue)
            % Internal method that needs to be copied to every child.
            % Required to enable the phase class to adapt values on the
            % child through processors.
            %
            %TODO see manipulators (not done with procs any more) - new way
            %     of handling that. Remove?

            this.(sAttribute) = xValue;
        end

        function [ bSuccess, txValues ] = setParameter(this, sParamName, xNewValue)
            % Helper for executing internal processors.
            %
            %TODO OLD - change to 'manipulators' etc ... some other
            %           functionality to map manips to phases?
            %
            % setParameter parameters:
            %   sParamName  - attr/param to set
            %   xNewValue   - value to set param to
            %   setValue    - function handle to set the struct returned by
            %                 the processor (params key, value).
            %
            %TODO   need that method so e.g. a gas phase can change the
            %       fVolume property, and some external manipulator can be
            %       called from here to e.g. change the temperature due to
            %       the volume change stuff.
            %       -> how to define which manipulators to use? This class
            %          here should handle the manipulators for its own
            %          properties (fTemperature, fVol) etc - but depending on
            %          phase type. Specific phase type class should handle
            %          manips for their properties (gas -> fPressure).
            %          SEE setAttribute -> provide generic functionality to
            %          trigger an event or external handler when a property
            %          is changed -> different manipulators can be attached
            %          to different phases and properties
            %       -> just make properties SetAcc protected or create some
            %          more specific setVol, setTemp etc. methods?

            bSuccess = false;
            txValues = [];

            %TODO work with events, or direct callbacks, or ...? 'static
            %     events' that happen generally on e.g.
            %     matter.phase.setVolume?
            this.setAttribute(sParamName, xNewValue);
            this.update();

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
