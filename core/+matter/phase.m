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

        % Specific heat capacity of mixture in phase
        % @type float
        fSpecificHeatCapacity = 0; % [J/(K*kg)]
        
        % Total heat capacity of mixture in phase
        % @type float
        fTotalHeatCapacity = 0; % [J/(K*kg)]
        
        % Summation over all time steps of the excess mass that was removed
        % from this phase (positive value means this mass was removed)
        afRemovedExcessMass;
        
        % In order to allow the modelling of heat sources within a phase
        % without having to implement a complete thermal solver this
        % property can be set using the setInternalHeatFlow function 
        fInternalHeatFlow = 0;
        
        % Heat flow als calculated by the thermal solver
        fThermalSolverHeatFlow = 0;
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

        % Last time the phase was updated (??)
        % @type float
        fLastMassUpdate = -10;
        fLastTemperatureUpdate = 0;

        % Time step in last massupdate (???)
        % @type float
        fMassUpdateTimeStep = 0;

        % Time Step for the temperature update of the phase (with regard to
        % thermal changes only, the temperature update will also be called
        % within each massupdate!)
        fTemperatureUpdateTimeStep = inf;

        % Current total incoming or (if negative value) outgoing mass flow,
        % for all substances combined. Used to improve pressure estimation
        % in ExMe processors.
        % @type float
        fCurrentTotalMassInOut = 0;
        
        % Storage - preserve those props from .calcTS!
        afCurrentTotalInOuts;
        mfCurrentFlowDetails;
        fCurrentTemperatureChangePerSecond = 0;

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
        bOutdatedThermalTS = true;
        
        % Time when the total heat capacity was last updated. Need to save
        % this information in order to prevent the heat capacity
        % calculation to be performed multiple times per timestep.
        fLastTotalHeatCapacityUpdate = 0;

    end

    properties (SetAccess = protected, GetAccess = protected)
        setThermalTimeStep;
    end
    
    properties (Access = public)
        % Limit - how much can the phase mass (total or single substances)
        % change before an update of the matter properties (of the whole
        % store) is triggered?
        rMaxChange = 0.25;
        arMaxChange;
        fMaxStep   = 20;
        fMinStep   = 0;
        fFixedTS;
        
        % Boolean parameter that can be set to true to keep the phase
        % temperature constant. Doing so will result in the phase
        % internally calculating the required heat flow to achieve this and
        % setting it as the internal heat flow (other internal heat flow
        % settings will be ignored)
        bConstantTemperature = false;
        
        % Maximum allowed temperature change for the phase within one thermal step in K
        fMaxTemperatureChange = 1; % K
        
        % Maximum factor with which rMaxChange is decreased
        rHighestMaxChangeDecrease = 0;

        % If true, massupdate triggers all branches to re-calculate their
        % flow rates. Use when volumes of phase compared to flow rates are
        % small!
        bSynced = false;
        
        % How often should the heat capacity be re-calculated?
        fMinimalTimeBetweenHeatCapacityUpdates = 1;
        
        % Properties to decide when the specific heat capacity has to be
        % recalculated
        fPressureLastHeatCapacityUpdate    = 0;
        fTemperatureLastHeatCapacityUpdate = 0;
        arPartialMassLastHeatCapacityUpdate;
        
        % Mass that has to be removed on next mass update
        afExcessMass;
        mfTotalFlowsByExme;
        oOriginPhase;
    end

    properties (SetAccess = private, GetAccess = public)

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
            
            % binds the temperature update function to the
            % setThermalTimeStep function to allow the phase to register
            % its own thermal update in case no global tick is taking place
            % before
            % this.setThermalTimeStep = this.oTimer.bind(@(~) this.temperatureupdate(), inf);
            
            this.arMaxChange = zeros(1,this.oMT.iSubstances);
            
            this.afMass = this.oMT.addPhase(this);
            
            % Preset masses
            this.afRemovedExcessMass = zeros(1, this.oMT.iSubstances);
            this.afExcessMass = zeros(1, this.oMT.iSubstances);
            this.afMass = zeros(1, this.oMT.iSubstances);
            this.arPartialMass = zeros(1, this.oMT.iSubstances);
            this.arPartialMassLastHeatCapacityUpdate = this.arPartialMass;
            
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

            this.fMolarMass            = this.oMT.calculateMolarMass(this.afMass);
            
            % Now update the matter properties
            this.updateSpecificHeatCapacity();
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

            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastMassUpdate;
            
            
            
            % Return if no time has passed
            if fLastStep == 0
                %NOTE need that in case .exec sets flow rate in manual branch triggering massupdate,
                %     and later in that tick phase does .update -> branches won't be set outdated!
                if bSetBranchesOutdated
                    this.setBranchesOutdated();
                end
                % even if no time has passed, in case that the flowrates
                % have changed the time step has to be set outdated to
                % allow the setting of the new flowrates
                this.setOutdatedTS();
                return;
            end
            this.fMassUpdateTimeStep = fLastStep;
            

            % All in-/outflows in [kg/s] and multiply with curernt time
            % step, also get the inflow rates / temperature / heat capacity
            %SPEED OPT - value saved in last calculateTimeStep, still valid
            %[ afTotalInOuts, mfInflowDetails ] = this.getTotalMassChange();
            afTotalInOuts = this.afCurrentTotalInOuts;

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
            %  tools.round.prec(this.afMass, this.oTimer.iPrecision)
            %
            % In the same step remove mass that was transmitted from other phases which
            % resulted in a negative mass for the other phase
            
            afMassNew =  this.afMass + afTotalInOuts;
            afMassNew = afMassNew - this.afExcessMass;
            this.afRemovedExcessMass = this.afRemovedExcessMass + this.afExcessMass;
            this.afExcessMass = zeros(1,this.oMT.iSubstances);
            
            % Now we check if any of the masses has become negative. This
            % can happen for two reasons, the first is just MATLAB rounding
            % errors causing barely negative numbers (e-14 etc.) The other
            % is an error in the programming of one of the procs/solvers.
            % In any case, we don't interrupt the simulation for this, we
            % just log the negative masses and set them to zero in the
            % afMass array. The sum of all mass lost is shown in the
            % command window in the post simulation summary.
            abNegative = afMassNew < 0;
            
            if any(abNegative)
                this.resolveNegativeMasses(afMassNew, abNegative);
            else
                this.afMass = afMassNew;
            end
            
            % Had to be moved to after the logic for negative masses
            % Immediately set fLastMassUpdate, so if there's a recursive call
            % to massupdate, e.g. by a p2ps.flow, nothing happens!
            this.fLastMassUpdate     = fTime;
            
            
            % Update total mass
            this.fMass = sum(this.afMass);
            if this.fMass > 0
                this.arPartialMass = this.afMass./this.fMass;
            else
                this.arPartialMass = zeros(1, this.oMT.iSubstances);
            end
            
            % Trigger branch solver updates in post tick for all branches
            % whose matter is currently flowing INTO the phase
            if this.bSynced || bSetBranchesOutdated
                %%%this.setBranchesOutdated('in');
                this.setBranchesOutdated();
            end
            
            % Execute updateProcessorsAndManipulators between branch solver
            % updates for inflowing and outflowing flows
            if this.iProcsP2Pflow > 0 || this.iManipulators > 0
                this.oTimer.bindPostTick(@this.updateProcessorsAndManipulators, 0);
                this.setBranchesOutdated(true); % true to indicate that only residual branches are set outdated
            end
            
            % Flowrate update binding for OUTFLOWING matter flows.
            if this.bSynced || bSetBranchesOutdated
                %%%this.setBranchesOutdated('out');
            end

            % Phase sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
            
            this.temperatureupdate();
            %%%this.trigger('massupdate.post');
        end

        function resolveNegativeMasses(this, afMassNew, abNegative)
            % For small negative masses the old logic is used
            abSmall = abs(afMassNew(abNegative)) < -10^-20;
            this.afMassLost(abSmall) = this.afMassLost(abSmall) - afMassNew(abSmall);
            afMassNew(abSmall) = 0;
            if all(afMassNew(abNegative) >= 0)
                this.afMass = afMassNew;
                return
            end

            if this.fMassUpdateTimeStep <= 0
                % In Case the time step is zero or negative the new
                % solution to prevent negative masses will not work and
                % instead the old version is used.
                %
                % this should not occur normaly, just to prevent any
                % strange crashes from happening ;)
                this.afMass = afMassNew;
                abNegative = this.afMass < 0;
                this.afMassLost(abNegative) = this.afMassLost(abNegative) - this.afMass(abNegative);
                this.afMass(abNegative) = 0;
                return;
            end;
            
           	mbBranch  	= false(this.iProcsEXME,1);
            miSign      = zeros(this.iProcsEXME, 1);
            % Get flow rates and partials from EXMEs
            for iI = 1:this.iProcsEXME
                mbBranch(iI) = ~this.coProcsEXME{iI}.bFlowIsAProcP2P;
                miSign(iI) = this.coProcsEXME{iI}.iSign;
            end 
            
            %% Calculate negative mass by each EXME
            % From the negative value that did occur it is possible to
            % calculate how much mass would be removed beyond the phase
            % capacity at the current flow rates:
            afNegativeMass = zeros(1,this.oMT.iSubstances);
            afNegativeMass(abNegative) = afMassNew(abNegative);
            
            afNegativeMassByExMe = zeros(this.iProcsEXME, this.oMT.iSubstances);
            
            % at this point we have the information which substances became
            % negative (abNegative) and which flows are outlet flows for
            % the substances that became negative (all flows ~= 0 of
            % mfFlowRates). Now these outlet flows have to be reduced
            % according to the missing mass to prevent a negative mass from
            % occuring.
            afPartialFlowRateOut = zeros(this.iProcsEXME, this.oMT.iSubstances);
            abNegativeFlows = sum(this.mfTotalFlowsByExme,2) < 0;
            afPartialFlowRateOut(abNegativeFlows,:) = this.mfTotalFlowsByExme(abNegativeFlows,:);
            
            miNegatives = find(abNegative);
            
            for iK = 1:length(miNegatives)
                % get the total outlet flow rate of the current negative
                % substance (with index miNegatives(iK) )
                fCurrentOutFlow = sum(afPartialFlowRateOut(:,miNegatives(iK)));
                % It is possible that this is zero (if the negative mass
                % logic itself is handing negative masses downstream
                % because all phases are too small)
                if fCurrentOutFlow == 0
                    % In this case just equally spread it over all current
                    % outgoing flows based on the total outflow
                    fCurrentOutFlow = sum(sum(afPartialFlowRateOut(mbBranch,:)));
                    if fCurrentOutFlow == 0
                        mbUseBranch = (mbBranch + (miSign == -1)) == 2;
                        if sum(mbUseBranch) == 0
                            afNegativeMassByExMe(:,miNegatives(iK))           = zeros(length(mbUseBranch),1) .* (afNegativeMass(miNegatives(iK)) ./ length(mbUseBranch));
                        else
                            afNegativeMassByExMe(mbUseBranch,miNegatives(iK)) = mbUseBranch(mbUseBranch) .* (afNegativeMass(miNegatives(iK)) ./sum(mbUseBranch));
                        end
                    else
                        % Different idea for this, only use branches to get
                        % it downstream
                        afNegativeMassByExMe(mbBranch,miNegatives(iK)) = afNegativeMass(miNegatives(iK)) .*  sum(afPartialFlowRateOut(mbBranch,:),2)./fCurrentOutFlow;
                    end
                else
                    % Additionally the mass that was removed from this phase
                    % beyond the current capacity is split between the outflows
                    % based on their current outflows:
                    afNegativeMassByExMe(:,miNegatives(iK)) = afNegativeMass(miNegatives(iK)) .* (afPartialFlowRateOut(:,miNegatives(iK))./fCurrentOutFlow);
                end
                
                %% P2Ps
                % Since P2Ps remove mass specifically they are given priority
                % to remove mass. E.g. an absorber that removes CO2 via a p2p
                % would remove the co2 in a cell before the branch can transfer
                % it to the next cell
                
                % Current mass that should got through P2Ps
                fCurrentMassThroughP2P = this.fMassUpdateTimeStep * sum(afPartialFlowRateOut(~mbBranch,miNegatives(iK)));
                if fCurrentMassThroughP2P ~= 0
                    % Mass of the substance after the P2Ps have removed their
                    % mass
                    fSubstanceMassAfterP2P = this.afMass(miNegatives(iK)) - fCurrentMassThroughP2P;

                    fCurrentOutFlowBranches = sum(afPartialFlowRateOut(mbBranch,miNegatives(iK)));
                    
                    if fCurrentOutFlowBranches ~= 0
                        % If this mass is larger or equal than 0 then the P2Ps can
                        % be completly filled with mass and it is not necessary to
                        % remove any excess mass from them. Instead even less mass
                        % should have been transferred through the branches
                        if fSubstanceMassAfterP2P >= 0
                            afNegativeMassByExMe(mbBranch,miNegatives(iK)) = afNegativeMassByExMe(mbBranch,miNegatives(iK)) +...
                                sum(afNegativeMassByExMe(~mbBranch,miNegatives(iK))) .* (afPartialFlowRateOut(mbBranch,miNegatives(iK))./ fCurrentOutFlowBranches);

                            afNegativeMassByExMe(~mbBranch,miNegatives(iK)) = 0;
                        else
                            % In this case the P2Ps have some negative mass
                            % remaining that has to be subtracted from them
                            fCurrentOutFlowP2Ps = sum(afPartialFlowRateOut(~mbBranch,miNegatives(iK)));
                            fAdditionalNegativeMassBranches = sum(afNegativeMassByExMe(~mbBranch,miNegatives(iK))) - fSubstanceMassAfterP2P;
                            
                            afNegativeMassByExMe(mbBranch,miNegatives(iK)) = afNegativeMassByExMe(mbBranch,miNegatives(iK)) +...
                                fAdditionalNegativeMassBranches .* (afPartialFlowRateOut(mbBranch,miNegatives(iK))./ fCurrentOutFlowBranches);
                            
                            % removes the negative mass added to the
                            % branches from the P2Ps
                            afNegativeMassByExMe(~mbBranch,miNegatives(iK)) = afNegativeMassByExMe(~mbBranch,miNegatives(iK)) -...
                                fAdditionalNegativeMassBranches .* (afPartialFlowRateOut(~mbBranch,miNegatives(iK))./ fCurrentOutFlowP2Ps);
                        end
                    end
                end
            end
            
            %%
            % now we have the correct partial (and therefore also total)
            % mass flow rates for each exme that have to be used to prevent
            % a negative mass from occuring.
            
            % Now there are two ways to do this, One way would be to adapt
            % the flow rates, which was the initial idea for this concept.
            % However, that makes it difficult to maintain the mass balance
            % since all phases can have different time steps and update
            % times. This would result in a fairly large logic to decide
            % when too much mass had been transfered into the adjacent
            % phase and how to remove it. Additionally adapting the flow
            % rates takes a fair amount of computation time, while the
            % impact on the flowrates is small. The overall required effect
            % however is only to remove the integrative error that
            % increases over simulation time. Therefore, the flow rates are
            % not adapted, and instead the mass that is taken from this
            % phase beyond the current capacity of the phase is removed
            % from the phases to which the mass is transported on the next
            % mass update of these phases. 
            %
            % Furthermore this logic should also keep the total mass in the
            % phases constant to maintain the pressure (for everything
            % except mixture, because other phases would not be able to
            % handle mixture substances :). Therefore the negative mass
            % that was removed too much from one substance, which is added
            % to the phase again, is instead removed from all the other
            % substances
            % Also for P2P the user probably does not want to keep the mass
            % constant but control what flows into the other phase.
            % Therefore this is only used on Branches. The mass that was
            % recreated because of P2Ps is instead tranferred to the origin
            % mass which has to be a larger mass that is allowed to change
            % in mass
            fPositiveMass = sum(afMassNew(~abNegative));
            afPositiveMassOrigin = zeros(1,this.oMT.iSubstances);
            if  strcmp(this.sType, 'mixture')
                % In this case the absorber is experiencing a desorption
                % process and a negative mass in the process
                
            elseif (fPositiveMass > abs(sum(afNegativeMass)))
                
                afNegativeMassThroughBranch = sum(afNegativeMassByExMe(mbBranch,:),2);
                
                if any(afNegativeMassThroughBranch)
                    afPositiveMassByExMe = zeros(this.iProcsEXME, this.oMT.iSubstances);
                    for iExme = 1:this.iProcsEXME
                        if mbBranch(iExme)
                            afPositiveMassByExMe(iExme,~abNegative) = -((afMassNew(~abNegative)./fPositiveMass).*(sum(afNegativeMassByExMe(iExme,:),2)));
                        end
                    end
                    
                    afNegativeMassByExMe = afNegativeMassByExMe + afPositiveMassByExMe;
                end
                
                % For P2P flowrates it is not possible to change the
                % substances that are transfered through the P2P to keep the 
                % mass of the phase from which the P2P extracts mass
                % constant. Therefore, instead the mass that is added to
                % the phase to replace the negative mass some of the other
                % substances in the phase are removed here and instead put
                % into the origin phase. 
                fNegativeMassThroughP2P = sum(sum(afNegativeMassByExMe(~mbBranch,:),1));
                if ~isempty(this.oOriginPhase) && fNegativeMassThroughP2P ~= 0
                    % Weighted contribution of mass removed from this phase
                    % and added to the origin phase
                    afPositiveMassOrigin(~abNegative) = -(afMassNew(~abNegative)./fPositiveMass) .* fNegativeMassThroughP2P;
                    
                    this.oOriginPhase.afExcessMass = this.oOriginPhase.afExcessMass - afPositiveMassOrigin;
                end
            end
            for iI = 1:this.iProcsEXME
                % First the exme on the other side of the affected outflows
                % has to be found
                if this.coProcsEXME{iI}.bFlowIsAProcP2P
                    % Get the other side ExMe
                    if this.coProcsEXME{iI} == this.coProcsEXME{iI}.oFlow.oIn
                        oCounterExMe = this.coProcsEXME{iI}.oFlow.oOut;
                    else
                        oCounterExMe = this.coProcsEXME{iI}.oFlow.oIn;
                    end
                else
                    % Get the other side ExMe
                    if this.coProcsEXME{iI} == this.coProcsEXME{iI}.oFlow.oBranch.coExmes{1}
                        oCounterExMe = this.coProcsEXME{iI}.oFlow.oBranch.coExmes{2};
                    else
                        oCounterExMe = this.coProcsEXME{iI}.oFlow.oBranch.coExmes{1};
                    end
                end
                
                % Now the afExcessMass Property can be set which is used on
                % the next mass update of the adjacent phase to remove the
                % excess mass that was transfered, therefore closing the
                % mass balance
                %
                % Times -1 because the masses is afNegativeMassByExMe are
                % negative, but the mass in afExcessMass is positive for
                % mass that has to be removed
                oCounterExMe.oPhase.afExcessMass = oCounterExMe.oPhase.afExcessMass - afNegativeMassByExMe(iI,:);
            end
            
            % Well now the mass that is created in this phase by
            % overwriting the negative value with 0 is subtracted from the
            % phases downstream. For this phase we have to overwrite the
            % negative values 
            afMassNew2 =  afMassNew - sum(afNegativeMassByExMe,1) - afPositiveMassOrigin;
            
            if any(afMassNew2 < 0)
                % Well if all this still didn't fix anything the old logic
                % is used
                abNegative2 = afMassNew2 < 0;
                this.afMassLost(abNegative2) = this.afMassLost(abNegative2) - afMassNew2(abNegative2);
                afMassNew2(abNegative2) = 0;
                this.afMass = afMassNew2;
                
            else
                this.afMass = afMassNew2;
            end
        end
        
        function this = update(this)
            % Only update if not yet happened at the current time.
            if (this.oTimer.fTime <= this.fLastUpdate) || (this.oTimer.fTime < 0)
                return;
            end

            % Store update time
            this.fLastUpdate = this.oTimer.fTime;


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
            %
            % See getTotalHeatCapacity --> only recalculated if at least
            % the minimal time difference between calculations, as
            % specified in the fMinimalTimeBetweenHeatCapacityUpdates
            % property, has passed. So we'll also include that here!
            if ~isempty(this.fMinimalTimeBetweenHeatCapacityUpdates) && (this.oTimer.fTime >= (this.fLastTotalHeatCapacityUpdate + this.fMinimalTimeBetweenHeatCapacityUpdates))
                bRecalculate = true;
            elseif isempty(this.fMinimalTimeBetweenHeatCapacityUpdates) && ~(this.oTimer.fTime == this.fLastTotalHeatCapacityUpdate)
                bRecalculate = true;
            else
                bRecalculate = false;
            end

            if bRecalculate
                % Our checks have concluded, that we have to recalculate
                % the specific heat capacity for this phase. To do that, we
                % call a phase type specific method. 
                this.updateSpecificHeatCapacity()
                
                % The total heat capacity is just the product of the
                % specific heat capacity and the total mass of this phase.
                this.fTotalHeatCapacity = this.fSpecificHeatCapacity * this.fMass;
                
                % Finally, we update the last update property with the
                % current time, so we can use it the next time this method
                % is called.
                this.fLastTotalHeatCapacityUpdate = this.oTimer.fTime;
            end
            
            this.trigger('PostUpdate');
        end

        %% Calculate Nutritional Content 
        
        function [ ttxResults ] = calculateNutritionalContent(this)
            
            %% Initialize
            
            % temporary struct
            ttxResults = struct();
            
            % Initialize totals
            ttxResults.EdibleTotal.Substance = 'Total';
            ttxResults.EdibleTotal.Mass = 0;
            ttxResults.EdibleTotal.DryMass = 0;
                        
            ttxResults.EdibleTotal.ProteinMass = 0;
            ttxResults.EdibleTotal.LipidMass = 0;
            ttxResults.EdibleTotal.CarbohydrateMass = 0;
            ttxResults.EdibleTotal.AshMass = 0;
                        
            ttxResults.EdibleTotal.TotalEnergy = 0;
            ttxResults.EdibleTotal.ProteinEnergy = 0;
            ttxResults.EdibleTotal.LipidEnergy = 0;
            ttxResults.EdibleTotal.CarbohydrateEnergy = 0;
                        
            ttxResults.EdibleTotal.CalciumMass = 0;
            ttxResults.EdibleTotal.IronMass = 0;
            ttxResults.EdibleTotal.MagnesiumMass = 0;
            ttxResults.EdibleTotal.PhosphorusMass = 0;
            ttxResults.EdibleTotal.PotassiumMass = 0;
            ttxResults.EdibleTotal.SodiumMass = 0;
            ttxResults.EdibleTotal.ZincMass = 0;
            ttxResults.EdibleTotal.CopperMass = 0;
            ttxResults.EdibleTotal.ManganeseMass = 0;
            ttxResults.EdibleTotal.SeleniumMass = 0;
            ttxResults.EdibleTotal.FluorideMass = 0;
                        
            ttxResults.EdibleTotal.VitaminCMass = 0;
            ttxResults.EdibleTotal.ThiaminMass = 0;
            ttxResults.EdibleTotal.RiboflavinMass = 0;
            ttxResults.EdibleTotal.NiacinMass = 0;
            ttxResults.EdibleTotal.PantothenicAcidMass = 0;
            ttxResults.EdibleTotal.VitaminB6Mass = 0;
            ttxResults.EdibleTotal.FolateMass = 0;
            ttxResults.EdibleTotal.VitaminB12Mass = 0;
            ttxResults.EdibleTotal.VitaminAMass = 0;
            ttxResults.EdibleTotal.VitaminEMass = 0;
            ttxResults.EdibleTotal.VitaminDMass = 0;
            ttxResults.EdibleTotal.VitaminKMass = 0;
            
            ttxResults.EdibleTotal.TryptophanMass = 0;
            ttxResults.EdibleTotal.ThreonineMass = 0;
            ttxResults.EdibleTotal.IsoleucineMass = 0;
            ttxResults.EdibleTotal.LeucineMass = 0;
            ttxResults.EdibleTotal.LysineMass = 0;
            ttxResults.EdibleTotal.MethionineMass = 0;
            ttxResults.EdibleTotal.CystineMass = 0;
            ttxResults.EdibleTotal.PhenylalanineMass = 0;
            ttxResults.EdibleTotal.TyrosineMass = 0;
            ttxResults.EdibleTotal.ValineMass = 0;
            ttxResults.EdibleTotal.HistidineMass = 0;
            
            %% Calculate
            
            % check contained substances if nutritional data available
            for iI = 1:(this.oMT.iSubstances)
                % check for all currently available edible substances 
                if isfield(this.oMT.ttxMatter.(this.oMT.csI2N{iI}), 'txNutrientData')     

                    % substance name
                    ttxResults.(this.oMT.csI2N{iI}).Substance = this.oMT.csI2N{iI};

                    % substance mass and dry mass [kg]
                    ttxResults.(this.oMT.csI2N{iI}).Mass = this.afMass(iI);
                    ttxResults.(this.oMT.csI2N{iI}).DryMass = this.afMass(iI) * (1 - this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fWaterMass);

                    % protein, lipid, carbohydrate and ash content [kg]
                    ttxResults.(this.oMT.csI2N{iI}).ProteinMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fProteinDMF;
                    ttxResults.(this.oMT.csI2N{iI}).LipidMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fLipidDMF;
                    ttxResults.(this.oMT.csI2N{iI}).CarbohydrateMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fCarbohydrateDMF;
                    ttxResults.(this.oMT.csI2N{iI}).AshMass = ttxResults.(this.oMT.csI2N{iI}).DryMass - (ttxResults.(this.oMT.csI2N{iI}).ProteinMass + ttxResults.(this.oMT.csI2N{iI}).LipidMass + ttxResults.(this.oMT.csI2N{iI}).CarbohydrateMass);

                    % total and partly energy content [J]
                    ttxResults.(this.oMT.csI2N{iI}).TotalEnergy         = this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fEnergyMass * ttxResults.(this.oMT.csI2N{iI}).Mass;
                    ttxResults.(this.oMT.csI2N{iI}).ProteinEnergy       = ttxResults.(this.oMT.csI2N{iI}).ProteinMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fProteinEnergyFactor;
                    ttxResults.(this.oMT.csI2N{iI}).LipidEnergy         = ttxResults.(this.oMT.csI2N{iI}).LipidMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fLipidEnergyFactor;
                    ttxResults.(this.oMT.csI2N{iI}).CarbohydrateEnergy  = ttxResults.(this.oMT.csI2N{iI}).CarbohydrateMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fCarbohydrateEnergyFactor;

                    % Mineral content [kg]
                    ttxResults.(this.oMT.csI2N{iI}).CalciumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fCalciumDMF;
                    ttxResults.(this.oMT.csI2N{iI}).IronMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fIronDMF;
                    ttxResults.(this.oMT.csI2N{iI}).MagnesiumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fMagnesiumDMF;
                    ttxResults.(this.oMT.csI2N{iI}).PhosphorusMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fPhosphorusDMF;
                    ttxResults.(this.oMT.csI2N{iI}).PotassiumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fPotassiumDMF;
                    ttxResults.(this.oMT.csI2N{iI}).SodiumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fSodiumDMF;
                    ttxResults.(this.oMT.csI2N{iI}).ZincMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fZincDMF;
                    ttxResults.(this.oMT.csI2N{iI}).CopperMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fCopperDMF;
                    ttxResults.(this.oMT.csI2N{iI}).ManganeseMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fManganeseDMF;
                    ttxResults.(this.oMT.csI2N{iI}).SeleniumMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fSeleniumDMF;
                    ttxResults.(this.oMT.csI2N{iI}).FluorideMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fFluorideDMF;

                    % Vitamin content [kg]
                    ttxResults.(this.oMT.csI2N{iI}).VitaminCMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fVitaminCDMF;
                    ttxResults.(this.oMT.csI2N{iI}).ThiaminMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fThiaminDMF;
                    ttxResults.(this.oMT.csI2N{iI}).RiboflavinMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fRiboflavinDMF;
                    ttxResults.(this.oMT.csI2N{iI}).NiacinMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fNiacinDMF;
                    ttxResults.(this.oMT.csI2N{iI}).PantothenicAcidMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fPantothenicAcidDMF;
                    ttxResults.(this.oMT.csI2N{iI}).VitaminB6Mass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fVitaminB6DMF;
                    ttxResults.(this.oMT.csI2N{iI}).FolateMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fFolateDMF;
                    ttxResults.(this.oMT.csI2N{iI}).VitaminB12Mass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fVitaminB12DMF;
                    ttxResults.(this.oMT.csI2N{iI}).VitaminAMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fVitaminADMF;
                    ttxResults.(this.oMT.csI2N{iI}).VitaminEMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fVitaminEDMF;
                    ttxResults.(this.oMT.csI2N{iI}).VitaminDMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fVitaminDDMF;
                    ttxResults.(this.oMT.csI2N{iI}).VitaminKMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fVitaminKDMF;

                    % Amino Acid content [kg]
                    ttxResults.(this.oMT.csI2N{iI}).TryptophanMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fTryptophanDMF;
                    ttxResults.(this.oMT.csI2N{iI}).ThreonineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fThreonineDMF;
                    ttxResults.(this.oMT.csI2N{iI}).IsoleucineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fIsoleucineDMF;
                    ttxResults.(this.oMT.csI2N{iI}).LeucineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fLeucineDMF;
                    ttxResults.(this.oMT.csI2N{iI}).LysineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fLysineDMF;
                    ttxResults.(this.oMT.csI2N{iI}).MethionineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fMethionineDMF;
                    ttxResults.(this.oMT.csI2N{iI}).CystineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fCystineDMF;
                    ttxResults.(this.oMT.csI2N{iI}).PhenylalanineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fPhenylalanineDMF;
                    ttxResults.(this.oMT.csI2N{iI}).TyrosineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fTyrosineDMF;
                    ttxResults.(this.oMT.csI2N{iI}).ValineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fValineDMF;
                    ttxResults.(this.oMT.csI2N{iI}).HistidineMass = ttxResults.(this.oMT.csI2N{iI}).DryMass * this.oMT.ttxMatter.(this.oMT.csI2N{iI}).txNutrientData.fHistidineDMF;

                    %% Total Edible Substance Content

                    ttxResults.EdibleTotal.Mass = ttxResults.EdibleTotal.Mass + ttxResults.(this.oMT.csI2N{iI}).Mass;
                    ttxResults.EdibleTotal.DryMass = ttxResults.EdibleTotal.DryMass + ttxResults.(this.oMT.csI2N{iI}).DryMass;

                    ttxResults.EdibleTotal.ProteinMass = ttxResults.EdibleTotal.ProteinMass + ttxResults.(this.oMT.csI2N{iI}).ProteinMass;
                    ttxResults.EdibleTotal.LipidMass = ttxResults.EdibleTotal.LipidMass + ttxResults.(this.oMT.csI2N{iI}).LipidMass;
                    ttxResults.EdibleTotal.CarbohydrateMass = ttxResults.EdibleTotal.CarbohydrateMass + ttxResults.(this.oMT.csI2N{iI}).CarbohydrateMass;
                    ttxResults.EdibleTotal.AshMass = ttxResults.EdibleTotal.AshMass + ttxResults.(this.oMT.csI2N{iI}).AshMass;

                    ttxResults.EdibleTotal.TotalEnergy = ttxResults.EdibleTotal.TotalEnergy + ttxResults.(this.oMT.csI2N{iI}).TotalEnergy;
                    ttxResults.EdibleTotal.ProteinEnergy = ttxResults.EdibleTotal.ProteinEnergy + ttxResults.(this.oMT.csI2N{iI}).ProteinEnergy;
                    ttxResults.EdibleTotal.LipidEnergy = ttxResults.EdibleTotal.LipidEnergy + ttxResults.(this.oMT.csI2N{iI}).LipidEnergy;
                    ttxResults.EdibleTotal.CarbohydrateEnergy = ttxResults.EdibleTotal.CarbohydrateEnergy + ttxResults.(this.oMT.csI2N{iI}).CarbohydrateEnergy;

                    ttxResults.EdibleTotal.CalciumMass = ttxResults.EdibleTotal.CalciumMass + ttxResults.(this.oMT.csI2N{iI}).CalciumMass;
                    ttxResults.EdibleTotal.IronMass = ttxResults.EdibleTotal.IronMass + ttxResults.(this.oMT.csI2N{iI}).IronMass;
                    ttxResults.EdibleTotal.MagnesiumMass = ttxResults.EdibleTotal.MagnesiumMass + ttxResults.(this.oMT.csI2N{iI}).MagnesiumMass;
                    ttxResults.EdibleTotal.PhosphorusMass = ttxResults.EdibleTotal.PhosphorusMass + ttxResults.(this.oMT.csI2N{iI}).PhosphorusMass;
                    ttxResults.EdibleTotal.PotassiumMass = ttxResults.EdibleTotal.PotassiumMass + ttxResults.(this.oMT.csI2N{iI}).PotassiumMass;
                    ttxResults.EdibleTotal.SodiumMass = ttxResults.EdibleTotal.SodiumMass + ttxResults.(this.oMT.csI2N{iI}).SodiumMass;
                    ttxResults.EdibleTotal.ZincMass = ttxResults.EdibleTotal.ZincMass + ttxResults.(this.oMT.csI2N{iI}).ZincMass;
                    ttxResults.EdibleTotal.CopperMass = ttxResults.EdibleTotal.CopperMass + ttxResults.(this.oMT.csI2N{iI}).DryMass;
                    ttxResults.EdibleTotal.ManganeseMass = ttxResults.EdibleTotal.ManganeseMass + ttxResults.(this.oMT.csI2N{iI}).ManganeseMass;
                    ttxResults.EdibleTotal.SeleniumMass = ttxResults.EdibleTotal.SeleniumMass + ttxResults.(this.oMT.csI2N{iI}).SeleniumMass;
                    ttxResults.EdibleTotal.FluorideMass = ttxResults.EdibleTotal.FluorideMass + ttxResults.(this.oMT.csI2N{iI}).FluorideMass;

                    ttxResults.EdibleTotal.VitaminCMass = ttxResults.EdibleTotal.VitaminCMass + ttxResults.(this.oMT.csI2N{iI}).VitaminCMass;
                    ttxResults.EdibleTotal.ThiaminMass = ttxResults.EdibleTotal.ThiaminMass + ttxResults.(this.oMT.csI2N{iI}).ThiaminMass;
                    ttxResults.EdibleTotal.RiboflavinMass = ttxResults.EdibleTotal.RiboflavinMass + ttxResults.(this.oMT.csI2N{iI}).RiboflavinMass;
                    ttxResults.EdibleTotal.NiacinMass = ttxResults.EdibleTotal.NiacinMass + ttxResults.(this.oMT.csI2N{iI}).NiacinMass;
                    ttxResults.EdibleTotal.PantothenicAcidMass = ttxResults.EdibleTotal.PantothenicAcidMass + ttxResults.(this.oMT.csI2N{iI}).PantothenicAcidMass;
                    ttxResults.EdibleTotal.VitaminB6Mass = ttxResults.EdibleTotal.VitaminB6Mass + ttxResults.(this.oMT.csI2N{iI}).VitaminB6Mass;
                    ttxResults.EdibleTotal.FolateMass = ttxResults.EdibleTotal.FolateMass + ttxResults.(this.oMT.csI2N{iI}).FolateMass;
                    ttxResults.EdibleTotal.VitaminB12Mass = ttxResults.EdibleTotal.VitaminB12Mass + ttxResults.(this.oMT.csI2N{iI}).VitaminB12Mass;
                    ttxResults.EdibleTotal.VitaminAMass = ttxResults.EdibleTotal.VitaminAMass + ttxResults.(this.oMT.csI2N{iI}).VitaminAMass;
                    ttxResults.EdibleTotal.VitaminEMass = ttxResults.EdibleTotal.VitaminEMass + ttxResults.(this.oMT.csI2N{iI}).VitaminEMass;
                    ttxResults.EdibleTotal.VitaminDMass = ttxResults.EdibleTotal.VitaminDMass + ttxResults.(this.oMT.csI2N{iI}).VitaminDMass;
                    ttxResults.EdibleTotal.VitaminKMass = ttxResults.EdibleTotal.VitaminKMass + ttxResults.(this.oMT.csI2N{iI}).VitaminKMass;

                    ttxResults.EdibleTotal.TryptophanMass = ttxResults.EdibleTotal.TryptophanMass + ttxResults.(this.oMT.csI2N{iI}).TryptophanMass;
                    ttxResults.EdibleTotal.ThreonineMass = ttxResults.EdibleTotal.ThreonineMass + ttxResults.(this.oMT.csI2N{iI}).ThreonineMass;
                    ttxResults.EdibleTotal.IsoleucineMass = ttxResults.EdibleTotal.IsoleucineMass + ttxResults.(this.oMT.csI2N{iI}).IsoleucineMass;
                    ttxResults.EdibleTotal.LeucineMass = ttxResults.EdibleTotal.LeucineMass + ttxResults.(this.oMT.csI2N{iI}).LeucineMass;
                    ttxResults.EdibleTotal.LysineMass = ttxResults.EdibleTotal.LysineMass + ttxResults.(this.oMT.csI2N{iI}).LysineMass;
                    ttxResults.EdibleTotal.MethionineMass = ttxResults.EdibleTotal.MethionineMass + ttxResults.(this.oMT.csI2N{iI}).MethionineMass;
                    ttxResults.EdibleTotal.CystineMass = ttxResults.EdibleTotal.CystineMass + ttxResults.(this.oMT.csI2N{iI}).CystineMass;
                    ttxResults.EdibleTotal.PhenylalanineMass = ttxResults.EdibleTotal.PhenylalanineMass + ttxResults.(this.oMT.csI2N{iI}).PhenylalanineMass;
                    ttxResults.EdibleTotal.TyrosineMass = ttxResults.EdibleTotal.TyrosineMass + ttxResults.(this.oMT.csI2N{iI}).TyrosineMass;
                    ttxResults.EdibleTotal.ValineMass = ttxResults.EdibleTotal.ValineMass + ttxResults.(this.oMT.csI2N{iI}).ValineMass;
                    ttxResults.EdibleTotal.HistidineMass = ttxResults.EdibleTotal.HistidineMass + ttxResults.(this.oMT.csI2N{iI}).HistidineMass;

                % if not an edible substance
                else
                    % substance name
                    ttxResults.(this.oMT.csI2N{iI}).Substance = this.oMT.csI2N{iI};

                    % substance mass and dry mass [kg]
                    ttxResults.(this.oMT.csI2N{iI}).Mass = this.afMass(iI);
                end
            end
        end
    end


    %% Methods for interfacing with thermal system
    methods

        function temperatureupdate(this, bSetBranchesOutdated)
            % uses the temperature change rate calculated by the
            % calculateThermalTimeStep function and the last execution
            % time of this function to change the temperature:
            if nargin < 2
                bSetBranchesOutdated = true;
            end
            
            fThermalTimestep = this.oTimer.fTime - this.fLastTemperatureUpdate;
            if fThermalTimestep <= 0
                return
            end
            this.fTemperature = this.fTemperature + (this.fCurrentTemperatureChangePerSecond * fThermalTimestep);
            
            if this.fTemperature < 0
                this.fTemperature = 0;
            end
            
            this.fLastTemperatureUpdate = this.oTimer.fTime;
            
            if bSetBranchesOutdated
                this.setBranchesOutdated(false, true);
            end
            
            % since the temperature has changed the specific heat capacity
            % has to be updated as well
            this.updateSpecificHeatCapacity()

            this.setOutdatedThermalTS();
        end
        
        function setThermalSolverHeatFlow(this,fThermalSolverHeatFlow)
            % function used to set the heat flow  calculated by a thermal
            % solver that is attached to the phase i
            this.fThermalSolverHeatFlow = fThermalSolverHeatFlow;
            
            this.setOutdatedThermalTS();
        end
        function setInternalHeatFlow(this,fInternalHeatFlow)
            % function used to set the internal heat flow of the phase in
            % order to model internal heat flows. Should only be used if
            % not thermal solver is used (in case that a thermal solver is
            % used you can use it to set internal heat flows for the
            % phases). This function is only present to allow the modelling
            % of such heat sources without having to use the complete
            % thermal solver
            this.fInternalHeatFlow = fInternalHeatFlow;
            
            this.setOutdatedThermalTS();
        end
        function changeInnerEnergy(this, fEnergyChange)
            %CHANGEINNERENERGY Change phase temperature via inner energy
            %   Change the temperature of a phase by adding or removing
            %   inner energy in |J|.
            
            % setParameter does .update anyways ... %%%
%             this.update();
            %TODO don't do whole update, just set outdated TS - calcTS
            %     should include temperature change in ts calculations!
            
            %TODO check ... heat capacity updates every second, so that
            %     should be ok? As for mass, use a change rate for the heat
            %     capacity and, with last update time, calculate current
            %     value?
            
            %fCurrentTotalHeatCapacity = this.getTotalHeatCapacity();
            fCurrentTotalHeatCapacity = this.fTotalHeatCapacity;
            
            % Calculate temperature change due to change in inner energy.
            fTempDiff = fEnergyChange / fCurrentTotalHeatCapacity;
            
            % Update temperature property of phase.
            %this.setParameter('fTemperature', this.fTemperature + fTempDiff);
            this.fTemperature = this.fTemperature + fTempDiff;
            
            % Why would a massupdate be necessary at this location?
            % Changing the temperature does not change the mass (it changes
            % the temperature and pressure for the branches, but that is
            % at best covered indirectly by calling a massupdate here)
            %this.massupdate();
            this.setOutdatedThermalTS();
        end


        function fTotalHeatCapacity = getTotalHeatCapacity(this)
            % Returns the total heat capacity of the phase. 
            
            this.warn('getTotalHeatCapacity', 'Use oPhase.fSpecificHeatCapacity * oPhase.fMass!');
            
            % We'll only calculate this again, if it has been at least one
            % second since the last update. This is to reduce the
            % computational load and may be removed in the future,
            % especially if the calculateSpecificHeatCapactiy() method and
            % the findProperty() method of the matter table have been
            % substantially accelerated.
            % One second is also the fixed timestep of the thermal solver. 
            %
            % Could that not be written as:
            % this.oTimer.fTime < (this.fLastTotalHeatCapacityUpdate + ...
            %                  this.fMinimalTimeBetweenHeatCapacityUpdates)
            % It feels like that is more readable ...
            if isempty(this.fLastTotalHeatCapacityUpdate) || (this.oTimer.fTime - this.fLastTotalHeatCapacityUpdate < this.fMinimalTimeBetweenHeatCapacityUpdates)
                fTotalHeatCapacity = this.fTotalHeatCapacity;
            else
                this.updateSpecificHeatCapacity();
                
                fTotalHeatCapacity = this.fSpecificHeatCapacity * this.fMass;
            
                % Save total heat capacity as a property for faster logging.
                this.fTotalHeatCapacity = fTotalHeatCapacity;
                
                this.fLastTotalHeatCapacityUpdate = this.oTimer.fTime;
            end
            
        end
        
    end
    
    methods (Abstract)
        % This method has to be implemented by all child classes.
        updateSpecificHeatCapacity(this)
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
        function [ afTotalInOuts, mfFlowDetails ] = getTotalMassChange(this)
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
            mfFlowDetails = zeros(this.iProcsEXME, 3);
            
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
                
                % Saves the flow details for the thermal calculation
                mfFlowDetails(iI,:) = [ fFlowRate, afProperties(1), afProperties(2) ];
            end
            

            % Now sum up in-/outflows over all EXMEs
            afTotalInOuts = sum(mfTotalFlows, 1);
            this.mfTotalFlowsByExme = mfTotalFlows;
            
%             afTotalInOuts   = tools.round.prec(afTotalInOuts,   this.oTimer.iPrecision);
%             mfInflowDetails = tools.round.prec(mfInflowDetails, this.oTimer.iPrecision);
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
            
            % Bind the .checkThermalUpdate function of this phase to the
            % timer to be executed in every tick (indicated by -1). This
            % will allow the checkThermalUpdate function to check if a
            % temperature update for this phase should be executed without
            % the phase having to register independent update ticks at
            % seperate times
            this.oTimer.bind(@(~) this.checkThermalUpdate(), -1);
            
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
            this.mfCurrentFlowDetails = mfDetails;
            
        end % end of: seal method

    end


    %% Internal, protected methods
    methods (Access = protected)

        function detachManipulator(this, sManip)
            
            %CHECK several manipulators possible?
            this.toManips.(sManip) = [];
            
        end

        function setBranchesOutdated(this, bResidual, bThermal)
            
            if nargin < 2
                bResidual = false;
            end
            if nargin < 3
                bThermal = false;
            end
            
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
                else
                    if isa(oBranch, 'matter.branch')

                        % We can't directly set this oBranch as outdated if
                        % it is just connected to an interface, because the
                        % solver is assigned to the 'leftest' branch.
                        while ~isempty(oBranch.coBranches{1})
                            oBranch = oBranch.coBranches{1};
                        end

                        %fprintf('%s-%s: setOutdated "%s"\n', this.oStore.sName, this.sName, oBranch.sName);

                        % Tell branch to recalculate flow rate (done after
                        % the current tick, in timer post tick).
                        % only the outflows have to be updated, since the
                        % inflows are independent from the composition of
                        % this phase
                        if bThermal
                            oBranch.setOutdatedThermal();
                        else
                            oBranch.setOutdated();
                        end
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
            
            
            
            % Setting the properties to the current values
            this.afCurrentTotalInOuts = afChange;
            this.mfCurrentFlowDetails = mfDetails;
            
            % If we have set a fixed time step for this phase, we can just
            % continue without doing any calculations.
            if ~isempty(this.fFixedTS)
                fNewStep = this.fFixedTS;
                this.bOutdatedTS = false;
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
                
                %CHECK Why would this be empty? Because abChange can be
                %false for all entries (no mass is beeing added or removed)
                if isempty(rPartialsPerSecond), rPartialsPerSecond = 0; end;

                % Calculating the change per second of TOTAL mass.
                % rTotalPerSecond also has the unit [1/s], giving us the
                % percentage change per second of the overall mass of the
                % phase.
                fChange = sum(afChange);

                if fChange == 0
                    rTotalPerSecond = 0;
                else
                    rTotalPerSecond = abs(fChange / this.fMass);
                end
                
                
                %% Calculating the new time step

                % To derive the timestep, we use the percentage change of
                % the total mass or the maximum percentage change of one of
                % the substances' relative masses.
                fNewStepTotal    = (this.rMaxChange * rMaxChangeFactor - rPreviousChange) / rTotalPerSecond;
                % Partial mass change compared to total mass
                fNewStepPartials = (this.rMaxChange * rMaxChangeFactor - max(arPreviousChange)) / rPartialsPerSecond;
                
                % Partial mass change compared to partial mass
                afCurrentMass = this.afMass;
                afCurrentMass(this.afMass < 1e-8) = 1e-8;
                arPartialChangeToPartials = abs(afChange ./ tools.round.prec(afCurrentMass, this.oTimer.iPrecision));
                arPartialChangeToPartials(this.afMass == 0) = 0;
                
                afNewStepPartialChangeToPartials = (this.arMaxChange * rMaxChangeFactor) ./ arPartialChangeToPartials;
                afNewStepPartialChangeToPartials(this.arMaxChange == 0) = inf;
                
                fNewStepPartialChangeToPartials = min(afNewStepPartialChangeToPartials);
                
                % The new time step will be set to the smaller one of these
                % two candidates.
                fNewStep = min([ fNewStepTotal fNewStepPartials fNewStepPartialChangeToPartials]);
                
                % The actual minimum time step of the phase is set by the
                % timer object and its current minimum time step property.
                % To ensure that this will happen, we pre-set the fMinStep
                % variable to zero, the timer will then use the actual
                % minimum.
                % fMinStep = 0; TBD does this make sense?
                
                % If our newly calculated time step is larger than the
                % maximum time step set for this phase, we use this
                % instead.
                if fNewStep > this.fMaxStep
                    fNewStep = this.fMaxStep;
                    %TODO Make this output a lower level debug message.
                    %fprintf('\nTick %i, Time %f: Phase %s setting maximum timestep of %f\n', this.oTimer.iTick, this.oTimer.fTime, this.sName, this.fMaxStep);
                    
                % If the time step is smaller than zero, then the previous
                % change was so large, that it made the numerator of the
                % time step calculation negative. 
                % This is weird, the previous change was very large,
                % shouldn't the time step have been made small enough then?
                % Why do we have to deal with it in this time step,
                % additionally causing it to set the minimum time step on
                % the phase?
                elseif fNewStep < this.fMinStep
                    fNewStep = this.fMinStep;
                    %TODO Make this output a lower level debug message.
                    %fprintf('Tick %i, Time %f: Phase %s.%s setting minimum timestep\n', this.oTimer.iTick, this.oTimer.fTime, this.oStore.sName, this.sName);
                end
            end
            % Since the flowrates (and with them the advective flows) are
            % changed within this calculate time step function the thermal
            % time step also has to be recalculated whenever the mass time 
            % step is recalculated:
            this.bOutdatedThermalTS = true;
            % false tells the thermal time step function not to update the
            % flow details because it has already been done in this
            % function
            this.calculateThermalTimeStep(false);
            
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

        function calculateThermalTimeStep(this, bUpdateFlowDetails)
            
            % Please view the derivation for equation 7.1 in
            % "Wärmeübertragung", Polifke for a detailed explanation on the
            % temperature calculation of an ideally stirred volume with in
            % and out flows and internal heat sources
            if nargin == 1
                bUpdateFlowDetails = true;
            end
            
            if ~this.bOutdatedThermalTS
                return
            end
            % updates the flow details if necessary. It can be necessary to
            % reflect temperature changes as mass changes (flowrate etc)
            % would have triggered a massupdate, thus already updating the
            % flowrates. TO DO: Check if implementing another query to
            % receive only the thermal properties would improve simulation
            % speed
            if bUpdateFlowDetails && ~(this.fLastMassUpdate == this.oTimer.fTime)
                
                % Each row: flow rate, temperature, heat capacity
                mfFlowDetails = zeros(this.iProcsEXME, 3);

                % Get flow rates and partials from EXMEs
                for iI = 1:this.iProcsEXME
                    % The fFlowRate parameter is the flow rate at the exme,
                    % with a negative flow rate being an extraction!
                    % arFlowPartials is a vector, with the partial mass ratios
                    % at the exme for each substance. 
                    % afProperties contains the temperature and heat capacity
                    % of the exme.
                    oExme = this.coProcsEXME{iI};
                    [ fFlowRate, ~, afProperties ] = oExme.getFlowData();

                    % If the flow rate is empty, then the exme is not
                    % connected, so we can skip it and move on to the next one.
                    if isempty(fFlowRate), continue; end;

                    % Saves the flow details for the thermal calculation
                    mfFlowDetails(iI,:) = [ fFlowRate, afProperties(1), afProperties(2) ];
                end
                
                this.mfCurrentFlowDetails = mfFlowDetails;
            end
            
            %% First we calculate the advective heat flows:
            
            % this.mfCurrentFlowDetails contains the flow details (FlowRate, Temperature and Specific Heat Capacity)
            abInflows = this.mfCurrentFlowDetails(:,1) > 0;
            mfAdvectiveHeatFlows = this.mfCurrentFlowDetails(abInflows,1) .* (this.mfCurrentFlowDetails(abInflows,2) - this.fTemperature) .* this.mfCurrentFlowDetails(abInflows,3);
            fAdvectiveHeatFlow = sum(mfAdvectiveHeatFlows);
            
%             if abs(this.mfCurrentFlowDetails(this.mfCurrentFlowDetails(:,1) < 0,2) - this.fTemperature) > 1e-1
%                 keyboard()
%             end
            % temperature change (please see "Wärmeübertragung", Polifke equation 7.1 for detailed derivations)
            % can be calculated by dividing all heat flows with the current
            % heat capacity. 
            
            % if the phase is supposed to have a constant temperature the
            % internal heat flow is calculated to result in zero
            % temperature change
            if this.bConstantTemperature
                this.fInternalHeatFlow = - ( fAdvectiveHeatFlow + this.fThermalSolverHeatFlow);
            end
            this.fCurrentTemperatureChangePerSecond = (fAdvectiveHeatFlow + this.fInternalHeatFlow + this.fThermalSolverHeatFlow) / this.fTotalHeatCapacity;
            
            % In order to calculate the respective thermal time step the
            % maximum allowed temperature change is divided with the
            % temperature change per second
            fThermalTimeStep = abs(this.fMaxTemperatureChange/this.fCurrentTemperatureChangePerSecond);
            
            this.setNextThermalTimeStep(fThermalTimeStep);
            
            this.bOutdatedThermalTS = false;
        end
        function checkThermalUpdate(this)
            % instead of the temperature update binding its own time steps
            % to the timer this function is instead set to be executed in
            % every tick of the timer, and it will execute the temperature
            % if the next exec time for it has been exceeded (without
            % having to register new timesteps resulting in completly new
            % ticks)
            fNextTemperatureUpdate = this.fLastTemperatureUpdate + this.fTemperatureUpdateTimeStep;
            % TBD: Decide whether to check here when the next global exec
            % will take place, and if that is too far off, set a new
            % temperature update for this phase (use setTimeStep function
            % of timer, has to be bound to a function property of phase see
            % store for syntax) This would require this check to be
            % executed after everything else, only by doing that it would
            % be possible to ensure that the next global execute time can
            % be calculated
            % 
            % setThermalTimeStep, outcommented but in principle included
            % to do this
            
            % Also updates in case the ticks is slightly before the
            % intended update
            if (this.oTimer.fTime - fNextTemperatureUpdate) >= -(0.01 * this.fTemperatureUpdateTimeStep)
                this.temperatureupdate();
            end
        end
        function setNextThermalTimeStep(this, fTimeStep)
            % This method is called from the calculateThermalTimeStep
            % function to set the mass independent temperature update time
            % for this phase
            
            % So we will first get the next execution time based on the
            % current time step and the last time this store was updated.
            fCurrentNextExec = this.fLastTemperatureUpdate + this.fTemperatureUpdateTimeStep;
            
            % since an update for the store also results in a mass update
            % etc for the phase (which inlcudes the thermal updates) the
            % thermal time step only has to be registered if it shall be
            % executed before the next store exec.
            fCurrentNextExecStore = this.oStore.fLastUpdate + this.oStore.fTimeStep;
            
            % Since the fTimeStep parameter that is passed on by the phase
            % that called this method is based on the current time, we
            % calculate the potential new execution time based on the
            % timer's current time, rather than the last update time for
            % this store.
            fNewNextExec     = this.oTimer.fTime + fTimeStep;
            
            % Now we can compare the current next execution time and the
            % potential new execution time. If the new execution time would
            % be AFTER the current execution time, it means that the phase
            % that is currently calling this method is faster than a
            % previous caller. In this case we do nothing and just return.
            if fCurrentNextExec < fNewNextExec || fCurrentNextExecStore < fNewNextExec
                return;
            end
            % The new time step is smaller than the old one, so we can
            % actually set the new timestep. Note that it is only set a
            % property which is then used in the checkThermalUpdate
            % function together with the last exec of the thermal update to
            % decide if it has to be reupdated.
            this.fTemperatureUpdateTimeStep = fTimeStep;
        end
        
        function setOutdatedThermalTS(this)
            % this function sets the thermal time step to be outdated, but
            % only if it (or the mass timestep) is not already outdated.
            % The massupdate includes the temperature updates and therefore
            % as long as they are triggered the temperature updates do not
            % have to be triggered addtionally.
            if ~this.bOutdatedThermalTS && ~ this.bOutdatedTS
                this.bOutdatedThermalTS = true;

                this.oTimer.bindPostTick(@this.calculateThermalTimeStep, 2);
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
