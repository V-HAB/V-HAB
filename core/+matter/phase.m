classdef phase < base & matlab.mixin.Heterogeneous
    %MATTERPHASE Summary of this class goes here
    %   Detailed explanation goes here
    %
    %
    %TODO need a clean separation between processors (move stuff from one
    %     phase to another, change flows, phase to flow processors) and
    %     manipulators (change volume/temperature/..., split up molecules,
    %     and other stuff that happens within a phase).
    %     Best way to introduce those manipulators? Just callbacks/events,
    %     or manipulator classes? One object instance per manipulator, and
    %     relate all phases that are using this manipulator, or one object
    %     per class?
    %     Package manip.change.vol -> manipulators .isobaric, .isochoric
    %     etc - one class/function each. Then, as for meta model in VHP, 
    %     registered as callbacks for e.g. set.fVolume in phase, and return
    %     values of callbacks determine what happens?
    
    
    % Abstracts - matter.phase can't be used directly, just derivatives!
    properties (SetAccess = protected, GetAccess = public, Abstract = true)
        % Type of phase - abstract to force the derived classes to set the
        % value and to ensure that matter.phase is never used directly!
        sType;
    end
    
    % Basic parameters
    properties (SetAccess = protected, GetAccess = public)
        % Masses for every species, temperature of phase
        afMass;             % [kg]
        fTemp;              % [K]
        
        %%%% Dependent variables:
        % Partial masses for every species and total mass
        arPartialMass;    % [%]
        fMass;              % [kg]
        
        % Mol mass, heat capacity
        fMolMass;           % [g/mol]
        fHeatCapacity = 0;  % [J/K]
        %TODO heat capacity with 0 initialized because needed on first
        %     .update call (from .seal())
        
        
        afMassLost;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Parent - store
        oStore;
        
        % Matter table
        oMT;
        
        % Name of phase
        sName;
        
        % Internal processors have to be used if a specific parameter shall
        % be changed.
        %TODO object references or function handles?
        %     internal processors renamed to manipulator.
        %ttoProcs = struct('internal', struct(), 'extract', struct(), 'merge', struct());
        
        
        % Extract/Merge processors - "ports", so key of struct (set to the
        % processors name) can be used to receive that port. If 'default'
        % as name, several flows can be connected.
        %TODO rename to f2p processor?
        toProcsEXME = struct();
        
        % Cache for procs ... see .update()
        coProcsEXME;
        iProcsEXME;
        
        
        % List with all p2p flow processors (matter.procs.p2ps.flow) that
        % are connected to an EXME of this phase.
        % Used to quickly access the objects on .massupdate, created on
        % .seal()
        %TODO make Transient, reload on loadobj
        coProcsP2Pflow;
        iProcsP2Pflow;
        
        
        % Last time the phase was updated?
        fLastMassUpdate = 0;
        % Time step in last massupdate
        fMassUpdateTimeStep = 0;
        
        fLastUpdate = -10;
        
        
        % Manipulators
        toManips = struct('vol', [], 'temp', [], 'partial', []);
     end
    
    % Derived values
    properties (SetAccess = protected, GetAccess = public)
        % Not handled by Matter, has to be set by derived state class
        fDensity = -1;      % [kg/m^3]
    end
    
    % 
    properties (SetAccess = private, GetAccess = private)
        % Fct callback on timer. Used for setting the time step for the
        % calculateTimeStep method.
        %setTimeStep;
        bOutdatedTS = false;
    end
    
    
    properties (SetAccess = public, GetAccess = public)
        % Limit - how much can the phase mass (total or single species)
        % change before an update of the matter properties (of the whole
        % store) is triggered?
        rMaxChange = 0.05;
        fMaxStep   = 15;
        fFixedTS;
        
        % If true, massupdate triggers all branches to re-calculate their
        % flow rates. Use when volumes of phase compared to flow rates are
        % small!
        bSynced = false;
    end
    
    
    properties (SetAccess = private, GetAccess = public, Transient = true)
        % Mass in phase at last update.
        fMassLastUpdate;
        afMassLastUpdate;
    end
    
    methods
        function this = phase(oStore, sName, tfMass, fTemp)
            % Constructor for the matter.phase class. Input parameters can
            % be provided to define the contained masses and temperature,
            % additionally the internal, merge and extract processors.
            %
            % phase parameters:
            %   oStore  - object reference to the store, matter table also
            %             received from there
            %   sName   - name of the phase
            %   aoPorts - ports (exme procs instances); can be empty or not
            %             provided, but then no mass can be extracted or
            %             merged.
            %   tfMass  - optional. Struct containing the initial masses. 
            %             Keys refer to the name of the according species
            %   fTemp 	- temperature of the initial mass, has to be given
            %             if  tfMass is provided
            
            % Parent has to be a or derive from matter.store
            if ~isa(oStore, 'matter.store'), this.throw('phase', 'Provided oStore parameter has to be a matter.store'); end;
            
            
            % Set name
            this.sName = sName;
            
            
            % Parent store - FIRST call addPhase on parent, THEN set the
            % store as the parent - matter.store.addPhase only does that if
            % the oStore attribute here is empty!
            this.oStore = oStore.addPhase(this);
            
            % Set the matter table
            %this.oMT = oMT;
            this.updateMatterTable();
            
            % Preset masses
            this.afMass = zeros(1, this.oMT.iSpecies);
            this.arPartialMass = zeros(1, this.oMT.iSpecies);
            
            % Mass provided?
            %TODO do all that in a protected addMass method? Especially the
            %     partial masses calculation -> has to be done on .update()
            if (nargin >= 3) && ~isempty(tfMass) && ~isempty(fieldnames(tfMass))
                % If tfMass is provided, fTemp also has to be there
                if nargin < 4 || isempty(fTemp) || ~isnumeric(fTemp) || (fTemp <= 0)
                    this.throw('phase', 'If tfMass is provided, the fTemp parameter also has to be provided (Kelvin, non-empty number, greater than zero).');
                end
                
                % Extract initial masses from tfMass and set to afMass
                csKeys = fieldnames(tfMass);
                
                for iI = 1:length(csKeys)
                    sKey = csKeys{iI};
                    
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
                this.fTemp = fTemp;
            else
                % Set this to zero to handle empty phases
                this.fMass = 0;
                % No mass - no temp
                this.fTemp = 0;
                
                % Partials also to zeros
                this.arPartialMass = this.afMass;
            end
            
            % Now update the matter properties
            this.fMolMass      = this.oMT.calculateMolecularMass(this.afMass);
            this.fHeatCapacity = this.oMT.calculateHeatCapacity(this);
            
            % Mass
            this.fMass = sum(this.afMass);
            this.afMassLost = zeros(1, this.oMT.iSpecies);
            
            % Preset the cached masses (see calculateTimeStep)
            this.fMassLastUpdate  = 0;
            this.afMassLastUpdate = zeros(1, this.oMT.iSpecies);
        end



        function hRemove = addManipulator(this, oManip)
            sManipType = [];
            
            if     isa(oManip, 'matter.manips.vol'),     sManipType = 'vol';
            elseif isa(oManip, 'matter.manips.temp'),    sManipType = 'temp';
            elseif isa(oManip, 'matter.manips.partial'), sManipType = 'partial';
            end
            
            if ~isempty(this.toManips.(sManipType))
                this.throw('addManipulator', 'A manipulator of type %s is already set for phase %s (store %s)', sManipType, this.sName, this.oStore.sName);
            end
            
            % Set manipulator
            this.toManips.(sManipType) = oManip;
            
            % Remove fct call to detach manipulator
            hRemove = @() this.detachManipulator(sManipType);
        end
        
        
        
        function this = massupdate(this, bSetOutdatedTS)
            fTime     = this.oStore.oTimer.fTime;
            fTimeStep = fTime - this.fLastMassUpdate;
            
            % Return if no time has passed
            if fTimeStep == 0, return; end;
            
            % Immediately set fLastMassUpdate, so if there's a recursive call 
            % to massupdate, e.g. by a p2ps.flow, nothing happens!
            this.fLastMassUpdate     = fTime;
            this.fMassUpdateTimeStep = fTimeStep;
            
            % All in-/outflows in [kg/s] and multiply with curernt time
            % step, also get the inflow rates / temperature / heat capacity
            [ afTotalInOuts, mfInflowDetails ] = this.getTotalMassChange();
            
            if any(afTotalInOuts ~= 0)
                %keyboard();
            end
            
            
            % Check manipulator
            if ~isempty(this.toManips.partial) && ~isempty(this.toManips.partial.afPartial)
                this.toManips.partial.update();
                %keyboard();
                % Add the changes from the manipulator to the total inouts
                afTotalInOuts = afTotalInOuts + this.toManips.partial.afPartial;
            end
            
            
            % Multiply with current time step
            afTotalInOuts = afTotalInOuts * fTimeStep;
            %afTotalInOuts = this.getTotalMassChange() * fTimeStep;
            
            % Do the actual adding/removing of mass.
            %TODO-NOW check if p2p stuff works, and manipulator stuff!
            %         the outflowing EXMEs need to get the right partial
            %         masses, e.g. if a p2p in between extracs a species!
            %CHECK    ok to round? default uses 1e8 ... should be coupled
            %         to the min. time step!
            %this.afMass =  tools.round.prec(this.afMass + afTotalInOuts, 10);
            this.afMass =  this.afMass + afTotalInOuts;
            
            
            % Check if that is a problem, i.e. negative masses.
            %abNegative = (this.afMass + afTotalInOuts) < 0;
            abNegative = this.afMass < 0;
            
            if any(abNegative)
                %disp(this.afMass + afTotalInOuts);
                %this.throw('massupdate', 'Extracted more mass then available in phase %s (store %s)', this.sName, this.oStore.sName);
                
                % Subtract - negative - added
                %NOTE uncomment this, comment out the two lines above if
                %     negative masses should just be logged
                this.afMassLost(abNegative) = this.afMassLost(abNegative) - this.afMass(abNegative);
                this.afMass(abNegative) = 0;
            end
            
            
            
            %%%% Now calculate the new temperature of the phase using the
            % inflowing enthalpies / inner energies / ... whatever.
            
            % Convert flow rates to masses
            mfInflowDetails(:, 1) = mfInflowDetails(:, 1) * fTimeStep;
            
            % Add the phase mass and stuff
            if ~isempty(mfInflowDetails) % no inflows?
                %mfInflowDetails = [ this.fMass, this.fTemp, this.fHeatCapacity ];
                mfInflowDetails(end + 1, 1:3) = [ this.fMass, this.fTemp, this.fHeatCapacity ];
                
                % Calculate inner energy (m * c_p * T) for all masses
                afEnergy = mfInflowDetails(:, 1) .* mfInflowDetails(:, 3) .* mfInflowDetails(:, 2);
                
                % For all masses - mass * heat capacity - helper
                afMassTimesCP = mfInflowDetails(:, 1) .* mfInflowDetails(:, 3);
                
                % New temperature
                %keyboard();
                this.fTemp = sum(afEnergy) / sum(afMassTimesCP);
            end
            
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
            %
            %
            %TODO see http://de.wikipedia.org/wiki/Innere_Energie
            %     also see EXME, old .merge
            %     -> handle further things?
            
            
            % Update total mass
            this.fMass = sum(this.afMass);
            
            % Only set outdatedTS (so in post tick, new time step is
            % calculated) if 2nd param is not false. Used by .update() to
            % make sure the time step calculation callback is executed
            % after the flow rate update callbacks in the branches.
            if (nargin < 2) || isempty(bSetOutdatedTS) || bSetOutdatedTS
                if this.bSynced
                    %TODO check if branche that called this massupdate
                    %   method is not executed again, and if flow rates are
                    %   actually calcualted before the phase sets the 
                    %   new time step!
                    this.setBranchesOutdated();
                end
                
                this.setOutdatedTS();
            end
        end
        
        function this = update(this)
            % Only update if not yet happened at the current time.
            if (this.oStore.oTimer.fTime <= this.fLastUpdate) || (this.oStore.oTimer.fTime < 0)
                return;
            end;
            
            %disp([ num2str(this.oStore.oTimer.iTick) ': Phase ' this.oStore.sName '-' this.sName ' (@' num2str(this.oStore.oTimer.fTime) 's, last ' num2str(this.fLastUpdate) 's)' ]);
            
            
            % Store update time
            this.fLastUpdate = this.oStore.oTimer.fTime;
            
            
            % Move matter in/out. Param false passed to prevent massupd
            % from registering the time step calculation callback on post
            % step. Needs to be added later, after the branches are set to
            % recalculate their flow rates - which they do post-step as
            % well. Therefore make sure that this.calculateTimeStep is
            % executed after the flow rate calculators.
            this.massupdate(false);
            
            
            % Cache old fMass / afMass - need that in time step
            % calculations!
            this.fMassLastUpdate  = this.fMass;
            this.afMassLastUpdate = this.afMass;
            
            
            % Partial masses
            if this.fMass > 0, this.arPartialMass = this.afMass / this.fMass;
            else               this.arPartialMass = this.afMass; % afMass is just zeros
            end
            
            % Now update the matter properties
            this.fMolMass      = this.oMT.calculateMolecularMass(this.afMass);
            this.fHeatCapacity = this.oMT.calculateHeatCapacity(this);
            
            
            % Triggers all branchs to recalculate flow rate
            this.setBranchesOutdated();
            
            % Register time step calculation on post tick
            this.setOutdatedTS();
        end
    end
    
    
    %% Methods for adding ports etc
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
                
            end
            
            
            
            this.toProcsEXME.(oProcEXME.sName) = oProcEXME;
        end
        
        function seal(this)
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
                end
                
                %this.update();
            end
        end
    end
    
    
    %% Internal, protected methods
    methods (Access = protected)
        function detachManipulator(this, sManip)
            %CHECK several manipulators possible?
            
            this.toManips.(sManip) = [];
        end
        
        
        function setBranchesOutdated(this)
            % Loop through exmes / flows and set outdated, i.e. request re-
            % calculation of flow rate.
            for iE = 1:this.iProcsEXME
                for iF = 1:length(this.coProcsEXME{iE}.aoFlows)
                    oBranch = this.coProcsEXME{iE}.aoFlows(iF).oBranch;
                    
                    % Make sure it's not a p2ps.flow - their update method
                    % is called in time step calculation method
                    if isa(oBranch, 'matter.branch')
                        % Tell branch to recalculate flow rate (done after
                        % the current tick, in timer post tick).
                        oBranch.setOutdated();
                    end
                end
            end
        end
        
        
        function [ afTotalInOuts, mfInflowDetails ] = getTotalMassChange(this)
            % Get vector with total mass change through all EXME flows
            % witin one second, i.e. [kg/s].
            %
            % The second output parameter is a matrix containing all inflow
            % rates, temperatures and heat capacities for calculating the
            % inflowing enthalpy/inner energy
            
            % Total flows - one row (see below) for each EXME, amount of
            % columns is the amount of species (partial masses)
            mfTotalFlows = zeros(this.iProcsEXME, this.oMT.iSpecies);
            
            % Each row: flow rate, temperature, heat capacity
            mfInflowDetails = zeros(0, 3);
            
            % Get flow rates and partials from EXMEs
            for iI = 1:this.iProcsEXME
                [ afFlowRates, mrFlowPartials, mfProperties ] = this.coProcsEXME{iI}.getFlowData();
                
                % The afFlowRates is a row vector containing the flow rate
                % at each flow, negative being an extraction!
                % mrFlowPartials is matrix, each row has partial ratios for
                % a flow, cols are the different species.
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
                % outflow for the current EXME for each species and for one
                % second!
                
                
                % Calculate inner energy of INflows, per sec
                abInf    = (afFlowRates > 0);
                %TODO store as attribute for 'automatic' preallocation,
                %     replace rows instead of append.
                if any(abInf)
                    mfInflowDetails = [ mfInflowDetails; afFlowRates(abInf), mfProperties(abInf, 1), mfProperties(abInf, 2) ];
                end
            end
            
            
            % Now sum up in-/outflows over all EXMEs and multiply with the
            % time step!
            afTotalInOuts = sum(mfTotalFlows, 1);
        end
        
        
        
        function calculateTimeStep(this)
            %TODO move this to another function or class or whatever. Why
            %is this executed here anyway?
            % Check manipulator
            %TODO allow user to set a this.bManipBeforeP2P or so, and if
            %     true execute the [manip].update() before the P2Ps update!
            if ~isempty(this.toManips.partial)
                %keyboard();
                this.toManips.partial.update();
                
                % Add the changes from the manipulator to the total inouts
                %afTotalInOuts = afTotalInOuts + this.toManips.partial.afPartial;
            end
            
            
            %TODO move this to another function or class or whatever. Why
            %is this executed here anyway?
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
            
            
            if ~isempty(this.fFixedTS)
                fTimeStep = this.fFixedTS;
            else

                % Calculate the change in total and partial mass since last
                % update that already happend / was applied
                rPreviousChange  = max(abs(this.fMassLastUpdate   / this.fMass  - 1));
                arPreviousChange = abs(this.afMassLastUpdate ./ this.afMass - 1);
                
                % Should only happen if fMass (therefore afMass) is zero!
                if isnan(rPreviousChange)
                    rPreviousChange  = 0;
                    arPreviousChange = this.afMass; % ... set to zeros!
                end

                % Change in kg of partial masses per second
                afChange = this.getTotalMassChange();

                % Only use entries where change is not zero
                abChange = (afChange ~= 0);
                
                % Changes of species masses - get max. change, add the change
                % that happend already since last update
                arPreviousChange = abs(afChange(abChange) ./ tools.round.prec(this.afMass(abChange), this.oStore.oTimer.iPrecision)) + arPreviousChange(abChange);
                
                % Only use non-inf --> inf if current mass of according
                % species is zero. If new species enters phase, still
                % covered through the overall mass check.
                rChangePerSecond = max(arPreviousChange(~isinf(arPreviousChange)));
                
                % Change per second of TOTAL mass
                fChange = sum(afChange);

                % No change? Use max. change per second --> one second timestep
                if fChange == 0
                    rTotalPerSecond = this.rMaxChange + rPreviousChange;
                else
                    rTotalPerSecond = abs(fChange / this.fMass - 0) + rPreviousChange;
                end

                % Derive timestep, use the max change (total mass or one of the
                % species change)
                %NOTE if some species has zero mass, but then one of the flows
                %     starts to introduce some of that species, the first tick
                %     the rChangePerSecond will be Inf, therefore fTimeStep
                %     will be zero - this is ok, if a new species is introduced
                %     a short time step is fine.
                fTimeStep = this.rMaxChange / max([ rChangePerSecond rTotalPerSecond ]);

                if fTimeStep > this.fMaxStep, fTimeStep = this.fMaxStep; end;
            end
            
            
            
            % Set new time step (on store, only sets that if smaller then
            % the currently set time step, btw).
            %CHECK     don't really need the whole store to update, p2p
            %          procs are always updated if one of the connected
            %          phases is updated, massupd also always done.
            %          Just register own callback and exec .update()!
            %          Still, logic required to update e.g. store's
            %          volume distribution if liquid phase changes etc.
            this.oStore.setNextExec(this.fLastMassUpdate + fTimeStep);
            %this.oStore.setNextExec(this.fLastMassUpdate + 1);
            
            % Now up to date!
            this.bOutdatedTS = false;
        end
        
        function setOutdatedTS(this)
            %if ~this.bOutdatedTS
                this.bOutdatedTS = true;
                
                %this.setTimeStep(0);
                this.oStore.oTimer.bindPostTick(@this.calculateTimeStep);
            %end
        end
        
        
        
        
        function this = updateMatterTable(this)
            % Update matter table from parent oStore. The afMass vector is 
            % automatically rearranged to fit the new matter table.
            %
            %TODO
            %   - first set this.oMT to [], then removePhase - and
            %     removePhase/addPhase both check if phase oMT empty?
            %   - also update exme procs MT!!
            
            if ~isempty(this.oMT)
                oOldMT = this.oMT.removePhase(this);
            else
                oOldMT = [];
            end
            
            this.oMT = this.oStore.oMT;
            
            % addPhase returns the old afMass mappend to the new MT
            this.afMass = this.oMT.addPhase(this, oOldMT);
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
        
        function [ bSuccess txValues ] = setParameter(this, sParamName, xNewValue)
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
            %          properties (fTemp, fVol) etc - but depending on
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
            
            return;
            
            % Check if processor was registered for that parameter
            if isfield(this.ttoProcs.internal, sParamName)
                % Found a processor - true
                bSuccess = true;
                
                % Struct returned by callback is written onto the object,
                % i.e. arbitrary attributes can be changed by processor!
                %TODO use (int procs, also ex/me procs) a events system?
                %     So several procs can register? Same mode, they can
                %     return a struct with the class props to modify ...
                txValues = this.ttoProcs.internal.(sParamName)(this, xNewValue, sParamName);
                
                % If returned value not empty ...
                if ~isempty(txValues)
                    % ... get the keys (= attribute names) from struct ...
                    csAttrs = fieldnames(txValues);
                    
                    % ... and write the values on this object
                    for iI = 1:length(csAttrs)
                        %setValue(csAttrs{iI}, txValues.(csAttrs{iI}));
                        %this.(csAttrs{iI}) = txValues.(csAttrs{iI});
                        this.setAttribute(csAttrs{iI}, txValues.(csAttrs{iI}));
                    end
                end
            end
        end
    end
    
    
    
    methods(Sealed)
        % Seems like we need to do that for heterogeneous, if we want to
        % compare the objects in the mixin array with one object ...
        function varargout = eq(varargin)
            varargout{:} = eq@base(varargin{:});
        end
    end
    
    %% Abstract methods
    methods (Abstract = true)
        %calcMolMasses(this)
        %calcHeatCapacity(this)
    end
    
    
    
    %% Getters and Setters for on the fly calculations
    methods
%         function fPressure = get.fPressure(this)
%             fPressure = 3;
%         end

          
    end
end

