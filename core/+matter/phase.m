classdef (Abstract) phase < base & matlab.mixin.Heterogeneous
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

        % Specific heat capacity of mixture in phase
        % @type float
        fSpecificHeatCapacity = 0; % [J/(K*kg)]
        
        % Total heat capacity of mixture in phase
        % @type float
        fTotalHeatCapacity = 0; % [J/(K*kg)]
        
    end

    properties (SetAccess = protected, GetAccess = public)
        % Internal properties, part 1:
        %TODO: investigate if this block can be merged with other ones

        % Length of the last time step (??)
        fTimeStep;

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

        % User-defined name of phase
        % @type string
        %TODO: rename to |sIdent|??
        %TODO: auto-generate name???
        sName;

        % List of Extract/Merge processors added to the phase: Key of
        % struct is set to the processor's name and can be used to retrieve
        % that object.
        %NOTE: A port with the name 'default' is not allowed (was previously
        %      used to define ports that can have several flows).
        %TODO: rename to |toExMePorts|, |toExMeProcessors|, etc.; or ?
        %TODO: use map and rename to |poExMeProcessors|?
        % @type struct
        % @types object
        toProcsEXME = struct();

        % List of manipulators added to the phase
        % @type struct
        % @types object
        toManips = struct('volume', [], 'temperature', [], 'substance', []);

    end

    properties (SetAccess = private, GetAccess = public) % (Access = private)
        % Internal properties, part 3:
        %TODO: investigate if this block can be merged with other ones

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
        %TODO make Transient, reload on loadobj
        coProcsP2Pflow;
        iProcsP2Pflow;

    end

    properties (SetAccess = private, GetAccess = public)
        % Internal properties, part 4:
        %TODO: investigate if this block can be merged with other ones

        % Last time the phase was updated (??)
        % @type float
        fLastMassUpdate = -1;

        % Time step in last massupdate (???)
        % @type float
        fMassUpdateTimeStep = 0;

        % Current total incoming or (if negative value) outgoing mass flow,
        % for all substances combined. Used to improve pressure estimation
        % in ExMe processors.
        % @type float
        fCurrentTotalMassInOut = 0;

        % ???
        fLastUpdate = -10;
        fLastTimeStepCalculation = -10;
        
        % Time when the total heat capacity was last updated. Need to save
        % this information in order to prevent the heat capacity
        % calculation to be performed multiple times per timestep.
        fLastTotalHeatCapacityUpdate; 

%         % ???
%         fTimeStep;

    end

    properties (Access = private)

        % ???
        bOutdatedTS = false;

    end

    properties (Access = public)

        % Limit - how much can the phase mass (total or single substances)
        % change before an update of the matter properties (of the whole
        % store) is triggered?
        rMaxChange = 0.25;
        fMaxStep   = 20;
        fFixedTS;
        
        % Maximum factor with which rMaxChange is decreased
        rHighestMaxChangeDecrease = 0;

        % If true, massupdate triggers all branches to re-calculate their
        % flow rates. Use when volumes of phase compared to flow rates are
        % small!
        bSynced = false;

    end

    properties (Transient, SetAccess = private, GetAccess = public)

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

                % Handle temperature
                this.fTemperature = fTemperature;
            else
                % Set this to zero to handle empty phases
                this.fMass = 0;
                % No mass - no temp
                this.fTemperature = 0;

                % Partials also to zeros
                this.arPartialMass = this.afMass;
            end

            % Now update the matter properties
            this.fMolarMass            = this.oMT.calculateMolarMass(this.afMass);
            this.fSpecificHeatCapacity = this.oMT.calculateSpecificHeatCapacity(this);
            this.fTotalHeatCapacity    = this.fSpecificHeatCapacity * this.fMass;

            % Mass
            this.fMass = sum(this.afMass);
            this.afMassLost = zeros(1, this.oMT.iSubstances);

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

            fTime     = this.oStore.oTimer.fTime;
            fLastStep = fTime - this.fLastMassUpdate;

            % Return if no time has passed
            if fLastStep == 0,
                return;
            end;

            % Immediately set fLastMassUpdate, so if there's a recursive call
            % to massupdate, e.g. by a p2ps.flow, nothing happens!
            this.fLastMassUpdate     = fTime;
            this.fMassUpdateTimeStep = fLastStep;

            % All in-/outflows in [kg/s] and multiply with curernt time
            % step, also get the inflow rates / temperature / heat capacity
            [ afTotalInOuts, mfInflowDetails ] = this.getTotalMassChange();

            % Check manipulator
            if ~isempty(this.toManips.substance) && ~isempty(this.toManips.substance.afPartialFlows)
                % Add the changes from the manipulator to the total inouts
                afTotalInOuts = afTotalInOuts + this.toManips.substance.afPartialFlows;

            end

            % Cache total mass in/out so the EXMEs can use that
            this.fCurrentTotalMassInOut = sum(afTotalInOuts);

            % Multiply with current time step
            afTotalInOuts = afTotalInOuts * fLastStep;
            %afTotalInOuts = this.getTotalMassChange() * fTimeStep;

            % Do the actual adding/removing of mass.
            %CHECK round the whole, resulting mass?
            %  tools.round.prec(this.afMass, this.oStore.oTimer.iPrecision)
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
            end


            %%%% Now calculate the new temperature of the phase using the
            % inflowing enthalpies / inner energies
            % Calculations from here: https://en.wikipedia.org/wiki/Internal_energy
            %
            % Logic for deriving new temperature:
            % Inner Energy
            %   Q = m * c_p * T
            %
            % Total energy, mass:
            %   Q_t = Q_1 + Q_2 + ...
            %   m_t = m_1 + m_2 + ...
            %
            % Total Heat capacity of the mixture
            %   c_p,t = (c_p,1*m_1 + c_p,2*m_2 + ...) / (m_1 + m_2 + ...)
            %
            %
            % Temperature from total energy of a mix
            %   T_t = Q_t / (m_t * c_p,t)
            %       = (m_1 * c_p,1 * T_1 + m_2 * c_p,2 * T_2 + ...) /
            %         ((m_1 + m_2 + ...) * (c_p,1*m_1 + ...) / (m_1 + ...))
            %       = (m_1 * c_p,1 * T_1 + m_2 * c_p,2 * T_2 + ...) /
            %               (c_p,1*m_1 + c_p,2*m_2 + ...)

            % First we split out the mfInflowDetails matrix to make the
            % code more readable.
            afInflowMasses                 = mfInflowDetails(:,1);
            afInflowTemperatures           = mfInflowDetails(:,2);
            afSpecificInflowHeatCapacities = mfInflowDetails(:,3);

            % Convert the incoming flow rates to absolute masses that are
            % added in this timestep.
            afAbsoluteMassesIn = afInflowMasses * fLastStep;

            % We only need to change things if there are any inflows.
            if ~isempty(mfInflowDetails)

                % This phase may currently be empty, so |this.fMass| could
                % be zero. In this case we'll only use the values of the
                % incoming flows.
                if this.fMass > 0
                    mfAbsoluteMasses         = [afAbsoluteMassesIn; this.fMass];
                    mfTemperatures           = [afInflowTemperatures; this.fTemperature];
                    mfSpecificHeatCapacities = [afSpecificInflowHeatCapacities; this.fSpecificHeatCapacity];
                else
                    mfAbsoluteMasses         = afInflowMasses;
                    mfTemperatures           = afInflowTemperatures;
                    mfSpecificHeatCapacities = afSpecificInflowHeatCapacities;
                end

                % Calculate inner energy (m * c_p * T) for all masses.
                mfEnergy = mfAbsoluteMasses .* mfSpecificHeatCapacities .* mfTemperatures;

                % As can be seen from the explanation given above, we need
                % the products of all masses and heat capacities in the
                % denominator of the fraction that calulates the new
                % temperature.
                mfEnergyPerKelvin = mfAbsoluteMasses .* mfSpecificHeatCapacities;

                % New temperature
                %TODO: Investigate if this does what it's supposed to do,
                %      especially in the case of non-zero mass where the
                %      matrices are Nx2 (N: number of substances). Is the
                %      temperature calculated correctly? Isn't it better
                %      (at least for readability), to calculcate the
                %      current temperature and the one of the incoming
                %      flows separately and then calculate the new
                %      weighted temperature from those values?
                this.fTemperature = sum(mfEnergy) / sum(mfEnergyPerKelvin);

            end


            % Update total mass
            this.fMass = sum(this.afMass);


            % Trigger branch solver updates in post tick for all branches
            % whose matter is currently flowing INTO the phase
            if this.bSynced || bSetBranchesOutdated
                %%%this.setBranchesOutdated('in');
                this.setBranchesOutdated();
            end
            
            % Execute updateProcessorsAndManipulators between branch solver
            % updates for inflowing and outflowing flows
            this.oStore.oTimer.bindPostTick(@this.updateProcessorsAndManipulators);
            
            % Flowrate update binding for OUTFLOWING matter flows.
            if this.bSynced || bSetBranchesOutdated
                %%%this.setBranchesOutdated('out');
            end

            % Phase sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
        end

        function this = update(this)
            % Only update if not yet happened at the current time.
            if (this.oStore.oTimer.fTime <= this.fLastUpdate) || (this.oStore.oTimer.fTime < 0)
                return;
            end

            % Store update time
            this.fLastUpdate = this.oStore.oTimer.fTime;


            % Actually move the mass into/out of the phase.
            % Pass true as a parameter so massupd calls setBranchesOutdated
            % even if the bSynced attribute is not true
            this.massupdate(true);

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
            if ~(this.oStore.oTimer.fTime == this.fLastTotalHeatCapacityUpdate)
                this.fSpecificHeatCapacity = this.oMT.calculateSpecificHeatCapacity(this);
            end
        end

    end


    %% Methods for interfacing with thermal system
    methods

        function changeInnerEnergy(this, fEnergyChange)
            %CHANGEINNERENERGY Change phase temperature via inner energy
            %   Change the temperature of a phase by adding or removing
            %   inner energy in |J|.
            
            fCurrentTotalHeatCapacity = this.getTotalHeatCapacity();
            
            % Calculate temperature change due to change in inner energy.
            fTempDiff = fEnergyChange / fCurrentTotalHeatCapacity;
            
            % Update temperature property of phase.
            this.setParameter('fTemperature', this.fTemperature + fTempDiff);
            
        end


        function fTotalHeatCapacity = getTotalHeatCapacity(this)
            % Returns the total heat capacity of the phase. 
            
            if this.oStore.oTimer.fTime - this.fLastTotalHeatCapacityUpdate < 1
                fTotalHeatCapacity = this.fTotalHeatCapacity;
            else
                this.fSpecificHeatCapacity = this.oMT.calculateSpecificHeatCapacity(this);
                
                fTotalHeatCapacity = this.fSpecificHeatCapacity * this.fMass;
            
                % Save total heat capacity as a property for faster logging.
                this.fTotalHeatCapacity = fTotalHeatCapacity;
                
                this.fLastTotalHeatCapacityUpdate = this.oStore.oTimer.fTime;
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
            %TODO
            %   * on .seal() and when branches are (re)connected, write all
            %     flow objects connected to the EXMEs to this.aoFlowsEXMEs
            %     or something, in order to access them more quickly here!
            %   * Simplify - all EXMEs can only have one flow now!

            % Total flows - one row (see below) for each EXME, number of
            % columns is the number of substances (partial masses)
            mfTotalFlows = zeros(this.iProcsEXME, this.oMT.iSubstances);

            % Each row: flow rate, temperature, heat capacity
            mfInflowDetails = zeros(this.iProcsEXME, 3);
            
            % Creating an array to log which of the flows are not in-flows
            aiOutFlows = ones(this.iProcsEXME, 1);

            % Get flow rates and partials from EXMEs
            for iI = 1:this.iProcsEXME
                [ afFlowRates, mrFlowPartials, mfProperties ] = this.coProcsEXME{iI}.getFlowData();

                % The afFlowRates is a row vector containing the flow rate
                % at each flow, negative being an extraction!
                % mrFlowPartials is matrix, each row has partial ratios for
                % a flow, cols are the different substances.
                % mfProperties contains temp, heat capacity

                if isempty(afFlowRates), continue; end;

                % So bsxfun with switched afFlowRates (to col vector) will
                % multiply every column value in the flow partials matrix
                % with the value in flow rates at the according position
                % (i.e. each element in first row with first element of fr,
                % each element in second row with 2nd element on fr, ...)
                % Then we sum() the resulting matrix which sums up column
                % wise ...
                mfTotalFlows(iI, :) = sum(bsxfun(@times, afFlowRates, mrFlowPartials), 1);

                % ... and now we got a vector with the absolute mass in-/
                % outflow for the current EXME for each substance and for one
                % second!


                % Which EXMEs have mass flows into the phase?
                abInf = (afFlowRates > 0);
                
                if any(abInf)
                    % Saving the details of the incoming flows into a
                    % matrix.
                    mfInflowDetails(iI,:) = [ afFlowRates(abInf), mfProperties(abInf, 1), mfProperties(abInf, 2) ];
                    
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

        end
        
    end


    %% Finalize methods
    methods

        function seal(this)
            
            % Preset mass and time step logging attributes
            % iPrecision ^ 2 is more or less arbitrary
            iStore = this.oStore.oTimer.iPrecision ^ 2;
            
            this.afMassLog = ones(1, iStore) * this.fMass;
            this.afLastUpd = 0:(1/(iStore-1)):1;%ones(1, iStore) * 0.00001;
            
            %TODO oData.rUF -> this.oStore.oContainer.oRoot.tSolverParams
            this.rHighestMaxChangeDecrease = this.oStore.oContainer.oRoot.tSolverParams.rHighestMaxChangeDecrease;
            
            
            % Auto-Set rMaxChange - max. 0.25, min. 1e-5!
            rMaxChangeTmp = sif(this.fVolume <= 0.25, this.fVolume, 0.25);
            rMaxChangeTmp = sif(rMaxChangeTmp <= 1e-5, 1e-5, rMaxChangeTmp);
            
            this.rMaxChange = rMaxChangeTmp / this.oStore.oContainer.oRoot.tSolverParams.rUpdateFrequency;
            
            
            %TODO if rMaxChange < e.g. 0.0001 --> do not decrease further
            %     but instead increase highestMaxChangeDec?
            
            if ~this.oStore.bSealed
                this.coProcsEXME = struct2cell(this.toProcsEXME)';
                this.iProcsEXME  = length(this.coProcsEXME);


                % Get all p2p flow processors on EXMEs
                this.coProcsP2Pflow = {};
                this.iProcsP2Pflow  = 0;

                for iE = 1:this.iProcsEXME
                    % If p2p flow, cannot be port 'default', i.e. just one
                    % flow possible!
                    if ~isempty(this.coProcsEXME{iE}.aoFlows) && isa(this.coProcsEXME{iE}.aoFlows(1), 'matter.procs.p2ps.flow')
                        this.iProcsP2Pflow = this.iProcsP2Pflow + 1;

                        this.coProcsP2Pflow{this.iProcsP2Pflow} = this.coProcsEXME{iE}.aoFlows(1);
                    end
                end % end of: for
            end % end of: if not sealed
            
        end % end of: seal method

    end


    %% Internal, protected methods
    methods (Access = protected)

        function detachManipulator(this, sManip)
            
            %CHECK several manipulators possible?
            this.toManips.(sManip) = [];
            
        end

        function setBranchesOutdated(this, sFlowDirection)
            
            if nargin < 2
                sFlowDirection = 'both'; 
            end;
            
            % Loop through exmes / flows and set outdated, i.e. request
            % recalculation of flow rate.
            for iE = 1:this.iProcsEXME
                %CHECK no 'default' exmes allowed any more, only one flow!
                %TODO remove aoFlows, aiSign, add oFlow, iSign
                for iF = 1:1 %length(this.coProcsEXME{iE}.aoFlows)
                    oExme   = this.coProcsEXME{iE};
                    oBranch = oExme.aoFlows(iF).oBranch;

                    % Make sure it's not a p2ps.flow - their update method
                    % is called in updateProcessorsAndManipulators method
                    if isa(oBranch, 'matter.branch')
                        % If flow direction set, only setOutdated if the
                        % flow direction is either inwards or outwards
                        if strcmp(sFlowDirection, 'in')
                            if oExme.aiSign(1) * oExme.aoFlows(1).fFlowRate > 0
                                % ok
                            else
                                continue;
                            end
                        elseif strcmp(sFlowDirection, 'out')
                            if oExme.aiSign(1) * oExme.aoFlows(1).fFlowRate <= 0
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
            if ~isempty(this.fFixedTS)
                fNewStep = this.fFixedTS;
            else
                rMaxChangeFactor = 1;
                
                % Log the current mass and time to the history arrays
                this.afMassLog = [ this.afMassLog(2:end) this.fMass ];
                this.afLastUpd = [ this.afLastUpd(2:end) this.oStore.oTimer.fTime ];
                
                
                %%%% Mass change in percent/second over logged time steps
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
                    if fDevMagnitude > this.oStore.oTimer.iPrecision, fDevMagnitude = this.oStore.oTimer.iPrecision;
                    elseif isnan(fDevMagnitude),                      fDevMagnitude = 0;
                    end;

                    % Min deviation (order of magnitude of mass change) 
                    iMaxDev = this.oStore.oTimer.iPrecision;
                    
                    
                    % Other try - exp
                    afBase = (0:0.01:1) .* iMaxDev;
                    afRes  = (0:0.01:1).^3 .* (this.rHighestMaxChangeDecrease - 1);

                    rFactor = interp1(afBase, afRes, fDevMagnitude, 'linear');

                    %fprintf('%i\t%i\tDECREASE rMaxChange from %f by %f to %f\n', iDev, iThreshold, rMaxChangeTmp, rFactor, rMaxChangeTmp / rFactor);

                    rMaxChangeFactor = 1 / (1 + rFactor);
                end
                
                
                %%%% Calculate changes of mass in phase since last mass upd

                % Calculate the change in total and partial mass since the
                % phase was last updated
                rPreviousChange  = abs(this.fMass / this.fMassLastUpdate - 1);
                arPreviousChange = abs(this.afMass ./ this.afMassLastUpdate - 1);

                % Should only happen if fMass (therefore afMass) is zero!
                if isnan(rPreviousChange)
                    rPreviousChange  = 0;
                    arPreviousChange = this.afMass; % ... set to zeros!
                end

                % Change in kg of partial masses per second
                afChange = this.getTotalMassChange();

                % Only use entries where change is not zero
                % If some substance changed a bit, but less then the thres-
                % hold, and does not any more - not taken into account. It
                % can still change in relation to other substances, where mass
                % flows in/out, but that should be covered by the total
                % mass change check.
                abChange = (afChange ~= 0);

                % Changes of substance masses - get max. change, add the change
                % that happend already since last update
                %arPreviousChange = abs(afChange(abChange) ./ tools.round.prec(this.afMass(abChange), this.oStore.oTimer.iPrecision)) + arPreviousChange(abChange);
                arPartialsChange = abs(afChange(abChange) ./ tools.round.prec(this.fMass, this.oStore.oTimer.iPrecision));% + arPreviousChange(abChange);

                % Only use non-inf --> inf if current mass of according
                % substance is zero. If new substance enters phase, still
                % covered through the overall mass check.
                rPartialsPerSecond = max(arPartialsChange(~isinf(arPartialsChange)));

                if isempty(rPartialsPerSecond), rPartialsPerSecond = 0; end;

                % Change per second of TOTAL mass
                fChange = sum(afChange);

                % No change in total mass?
                if fChange == 0
                    rTotalPerSecond = 0;
                else
                    rTotalPerSecond = abs(fChange / this.fMass);
                end
                
                
                %%%% Calculate new time step

                % Derive timestep, use the max change (total mass or one of
                % the substances change)
                %fNewStep = this.rMaxChange / max([ rChangePerSecond rTotalPerSecond ]);
                %fNewStep = (this.rMaxChange - rPreviousChange) / max([ rPartialsPerSecond rTotalPerSecond ]);

                fNewStepTotal    = (this.rMaxChange * rMaxChangeFactor - rPreviousChange) / rTotalPerSecond;
                fNewStepPartials = (this.rMaxChange * rMaxChangeFactor - max(arPreviousChange)) / rPartialsPerSecond;

                fNewStep = min([ fNewStepTotal fNewStepPartials ]);

                %{
                %CHECK can calulateTimeStep be called multiple times in one
                %      tick?
                iRemDeSi = this.iRememberDeltaSign;
                iPrec    = this.oStore.oTimer.iPrecision;
                iExpRem  = 0;
                iExpDelta= 0; % inactive right now!


                if this.fLastTimeStepCalculation < this.oStore.oTimer.fTime
                    this.abDeltaPositive(1:iRemDeSi)   = this.abDeltaPositive(2:(iRemDeSi + 1));
                    this.abDeltaPositive(iRemDeSi + 1) = fChange > 0;

                    if tools.round.prec(fChange, iPrec) == tools.round.prec(this.fLastTotalChange, iPrec)
                        %this.abDeltaPositive(iRemDeSi + 1) = this.abDeltaPositive(iRemDeSi);
                    end
                end

                this.fLastTimeStepCalculation = this.oStore.oTimer.fTime;


                aiChanges = abs(diff(this.abDeltaPositive));
                afExp     = (1:iRemDeSi) .^ iExpRem;
                arExp     = afExp ./ sum(afExp);% * 1.5;
                rChanges  = sum(arExp .* aiChanges);

                fNewStep = interp1([ 0 1 ], [ this.oStore.oTimer.fTimeStep fNewStep ], (1 - rChanges) ^ iExpDelta, 'linear', 'extrap');
                %}


                if fNewStep > this.fMaxStep
                    fNewStep = this.fMaxStep;
                elseif fNewStep < 0
                    fNewStep = 0;
                end
            end


            % Set the time at which the containing store will be updated
            % again. Need to pass on an absolute time, not a time step.
            % Value in store is only updated, if the new update time is
            % earlier than the currently set next update time.
            this.oStore.setNextUpdateTime(this.fLastMassUpdate + fNewStep);

            % Cache - e.g. for logging purposes
            this.fTimeStep = fNewStep;

            % Now up to date!
            this.bOutdatedTS = false;
        end

        function setOutdatedTS(this)
            if ~this.bOutdatedTS
                this.bOutdatedTS = true;

                this.oStore.oTimer.bindPostTick(@this.calculateTimeStep);
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
