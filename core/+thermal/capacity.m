classdef capacity < base
    %CAPACITY An object that holds thermal energy
    % created automatically with a phase and performs all thermal
    % calculations for the respective phase
        
    properties (SetAccess = protected) %, Abstract)
        
        % Object properties
        
        fTemperature;
        
        sName; % This object's name.
        
        % Associated objects
        oPhase;
        aoHeatSource;
        toHeatSources;
        
        aoExmes;
        toProcsEXME;
        iProcsEXME = 0;
        
        oMT;
        oTimer;
        
        % Internal properties
        
        % Specific heat capacity of mixture in phase
        % @type float
        fSpecificHeatCapacity = 0; % [J/(K*kg)]
        
        % Total heat capacity of mixture in phase
        % @type float
        fTotalHeatCapacity = 0; % [J/(K*kg)]
        
        % Property to store the current overall heat flow of this capacity
        % (positive values increase the temperature, negative values
        % decrease it)
        fCurrentHeatFlow = 0;
        
        %% Numerical properties
        % current (thermal) timestep enforced by this capacity
        fTimeStep;
        
        % last time at which the temperature was updated
        fLastTemperatureUpdate = 0;
        
        % This time step is the one used internally by the
        % updateTemperature method. It can be smaller than the fTimeStep
        % property because the updateTemperature methode can also be called
        % by branches for example. See the updateMatter methode of phase.m
        % for further reference
        fTemperatureUpdateTimeStep;
        
        % maximum allowed temperature change in percent. A value of 0.5%
        % means that for a temperature of 293 K the maximum temperature
        % change is 1.47 K
        rMaxChange = 0.005;
        
        bOutdatedTS = false;
        
        fLastSetOutdated = -1;
        
        fLastTotalHeatCapacityUpdate = 0;
        
        % How often should the heat capacity be re-calculated?
        fMinimalTimeBetweenHeatCapacityUpdates = 1;
        
        % Values to decide if the specific heat capacity requires an update
        fPressureLastHeatCapacityUpdate;
        fTemperatureLastHeatCapacityUpdate;
        arPartialMassLastHeatCapacityUpdate;
        
    end
    
    methods
        
        function this = capacity(oPhase, fTemperature)
            %CAPACITY Create new thermal capacity object
            %   Create a new capacity with a name and associated phase
            %   object. Capacities are generated automatically together
            %   with phases and all thermal calculations are performed here
            
            % Set associated objects.
            this.oPhase = oPhase;
            this.oMT = oPhase.oMT;
            this.oTimer = oPhase.oTimer;
            
            % Note, only during the constructor this is done without the
            % set function, as the values have to be set once for the
            % energy balance calculation in the set functions
            this.fSpecificHeatCapacity  = this.oMT.calculateSpecificHeatCapacity(this.oPhase);
            this.fTotalHeatCapacity     = sum(this.oPhase.afMass) * this.fSpecificHeatCapacity;
            
            % sets the temperature of this capacity and the asscociated
            % phase
            this.setTemperature(fTemperature);
            
            % Set name of capacity.
            this.sName = oPhase.sName;
            
        end
        
        function setHeatSource(this, oHeatSource)
            % Set the heat source object of this capacity.
            
            % Is oHeatSource an instance of thermal.heatsource?
            if ~isa(oHeatSource, 'thermal.heatsource')
                this.throw('capacity:setHeatSource', 'This is no heat source!');
            elseif any(find(this.aoHeatSource, oHeatSource)) % TO DO: Check for name
                this.throw('capacity:setHeatSource', 'A heat source of this name was already set');
            end
            
            % Store heat source object instance.
            this.aoHeatSource(end+1) = oHeatSource;
        end
        
        function updateSpecificHeatCapacity(this)
            
            % When a phase was empty and is being filled with matter again,
            % it may be a couple of ticks until the phase.update() method
            % is called, which updates the phase's specific heat capacity.
            % Other objects, for instance matter.flow, may require the
            % correct value for the heat capacity as soon as there is
            % matter in the phase. In this case, these objects can call
            % this function, that will update the fSpecificHeatCapacity
            % property of the phase.
            
            % In order to reduce the amount of times the matter
            % calculation is executed it is checked here if the pressure
            % and/or temperature have changed significantly enough to
            % justify a recalculation
            % TO DO: Make limits adaptive
            if (this.oTimer.iTick <= 0) ||... %necessary to prevent the phase intialization from crashing the remaining checks
               (abs(this.fPressureLastHeatCapacityUpdate - this.oPhase.fPressure) > 100) ||...
               (abs(this.fTemperatureLastHeatCapacityUpdate - this.fTemperature) > 1) ||...
               (max(abs(this.arPartialMassLastHeatCapacityUpdate - this.oPhase.arPartialMass)) > 0.01)
                
           
                if ~base.oLog.bOff
                    this.out(1, 1, 'name', '%s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName });

                    this.out(1, 2, 'last', 'fSpecificHeatCapacity:              %f [J/(kg*K)]', { this.fSpecificHeatCapacity });
                    this.out(1, 2, 'last', 'fMass:                              %f [kg]', { sum(this.arPartialMassLastHeatCapacityUpdate) });
                    this.out(1, 2, 'last', 'fPressureLastHeatCapacityUpdate:    %f [Pa]', { this.fPressureLastHeatCapacityUpdate });
                    this.out(1, 2, 'last', 'fTemperatureLastHeatCapacityUpdate: %f [K]', { this.fTemperatureLastHeatCapacityUpdate });
                end
                
                % Actually updating the specific heat capacity
                this.setSpecificHeatCapacity(this.oMT.calculateSpecificHeatCapacity(this.oPhase));
                
                % Setting the properties for the next check
                this.fPressureLastHeatCapacityUpdate     = this.oPhase.fPressure;
                this.fTemperatureLastHeatCapacityUpdate  = this.fTemperature;
                this.arPartialMassLastHeatCapacityUpdate = this.oPhase.arPartialMass;
                
                
                if ~base.oLog.bOff
                    this.out(1, 2, 'curr', 'fSpecificHeatCapacity:              %f [J/(kg*K)]', { this.fSpecificHeatCapacity });
                    this.out(1, 2, 'curr', 'fMass:                              %f [kg]', { sum(this.arPartialMassLastHeatCapacityUpdate) });
                    this.out(1, 2, 'curr', 'fPressureLastHeatCapacityUpdate:    %f [Pa]', { this.fPressureLastHeatCapacityUpdate });
                    this.out(1, 2, 'curr', 'fTemperatureLastHeatCapacityUpdate: %f [K]', { this.fTemperatureLastHeatCapacityUpdate });
                end
            end
        end
        
        function setTotalHeatCapacity(this, fTotalHeatCapacity)
            % it may seem strange at first that the total heat capacity is
            % overwritten without changing the temperature, however as a
            % change in total heat capacity (and not specific) comes from
            % mass changes in the phase, the thermal energy is actually
            % transported somewhere else in the form of mass. The thermal
            % solver calculates the heat flow asscociated with that
            % transfer, and therefore the inner energy can be simply
            % overwritten, which is basically what occurs when overwritting
            % the total heat capacity here.
            %
            % Think of it like this, if  masses of identical temperature
            % are moved between container no temperature change occurs. And
            % this basically what happens here as the difference in
            % temperature is already handled in the thermal branch
            
            this.fTotalHeatCapacity = fTotalHeatCapacity;
            
            this.fLastTotalHeatCapacityUpdate = this.oTimer.fTime;
        end
        
        function setSpecificHeatCapacity(this, fSpecificHeatCapacity)
            % Set the specific heat capacity (and while doing this also the
            % total heat capacity) of this phase and ensure a closed energy
            % balance while doing this. The specific heat capacity changes
            % when the matter property is recalculated in the matter table,
            % as it is temperature (and pressure) dependent
            fInnerEnergyBefore = this.fTotalHeatCapacity * this.fTemperature;
            
            this.fTotalHeatCapacity = (this.oPhase.fMass * fSpecificHeatCapacity);
            
            this.setTemperature( fInnerEnergyBefore / this.fTotalHeatCapacity );
            
            this.fSpecificHeatCapacity = fSpecificHeatCapacity;
        end
        
        function addProcEXME(this, oProcEXME)
            % Adds a exme proc, i.e. a port. 
            
            if this.oPhase.oStore.bSealed
                this.throw('addProcEXME', 'The store to which this capacity belongs is sealed, so no ports can be added any more.');
            end

            if ~isa(oProcEXME, 'thermal.procs.exme')
                this.throw('addProcEXME', 'Provided object ~isa thermal.procs.exme');
            elseif ~isempty(oProcEXME.oCapacity)
                this.throw('addProcEXME', 'Processor has already a Capacity set as parent.');
            elseif isfield(this.toProcsEXME, oProcEXME.sName)
                this.throw('addProcEXME', 'Proc %s already exists.', oProcEXME.sName);
            end

            this.toProcsEXME.(oProcEXME.sName) = oProcEXME;
            
            if isempty(this.aoExmes)
                this.aoExmes = oProcEXME;
            else
                this.aoExmes(end+1) = oProcEXME;
            end
            
            this.iProcsEXME = this.iProcsEXME + 1;
        end
        
        function addHeatSource(this, oHeatSource)
            % Add a heat source to this capacity object. The power set to this
            % heat source will be included in the temperature calculations.
            %
            % Parameter oHeatSource: will be added to a local heat source.
            % Positive power means temperature RISE.
            
            if this.oPhase.oStore.bSealed
                this.throw('addHeatSource', 'The store to which this capacity belongs is sealed, so no heat sources can be added any more.');
            end

            if ~isa(oHeatSource, 'thermal.heatsource')
                this.throw('addHeatSource', 'Provided object ~isa thermal.heatsource');
            elseif ~isempty(oHeatSource.oCapacity)
                this.throw('addHeatSource', 'Heat source has already a Capacity set as parent.');
            elseif isfield(this.toHeatSources, oHeatSource.sName)
                this.throw('addHeatSource', 'Heat source %s already exists.', oHeatSource.sName);
            end

            this.toHeatSources.(oHeatSource.sName) = oHeatSource;
            
            this.aoHeatSource(end+1) = oHeatSource;
        end
        
        function setOutdatedTS(this)
            
            if ~this.bOutdatedTS
                this.bOutdatedTS = true;

                this.oTimer.bindPostTick(@this.calculateTimeStep, 3);
            end
        end
        
        function updateTemperature(this, bSetBranchesOutdated)
            % use fCurrentHeatFlow to calculate the temperature change
            % since the last execution fLastTemperatureUpdate
            
            if nargin < 2
                bSetBranchesOutdated = false;
            end
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastTemperatureUpdate;
            
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
            this.fLastTemperatureUpdate     = fTime;
            this.fTemperatureUpdateTimeStep = fLastStep;
            
            fTemperatureNew = this.fTemperature + ((this.fCurrentHeatFlow / this.fTotalHeatCapacity) * this.fTemperatureUpdateTimeStep);
            
            this.setTemperature(fTemperatureNew);
            
            % Trigger branch solver updates in post tick for all branches
            % whose heatflow is currently flowing INTO the capacity
            if bSetBranchesOutdated % TO DO: do we need bySynced on thermal side as well?
                this.setBranchesOutdated();
            end
            % Capacity sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
        end
        
    end
    
    methods (Access = protected)
        function setTemperature(this, fTemperature)
            % Internal function of the capacity object to set the
            % temperature. This is used to ensure that the capacity
            % temperature and phase temperature are always set at the same
            % time. Note that only the capacity is allowed to set
            % temperature values
            if isempty(fTemperature)
                keyboard()
            end
            this.fTemperature = fTemperature;
            this.oPhase.setTemperature(this, fTemperature);
        end
        
        function calculateTimeStep(this,~)
            % This function performs the following calculation steps
            % - Loop through all thermal exmes of the capacity and get 
            %   their heat flows
            % - Loop through all heat sources and get their heat flows
            % - Store the overall heat flow in the fCurrentHeatFlow property
            % - calculate the allowed time step based on the phase
            %   temperature max change
            fSourceHeatFlow = 0;
            for iSource = 1:length(this.aoHeatSource)
                fSourceHeatFlow = fSourceHeatFlow + this.aoHeatSource(iSource).fHeatFlow;
            end
            
            fExmeHeatFlow = 0;
            for iExme = 1:length(this.aoExmes)
                fExmeHeatFlow = fExmeHeatFlow + (this.aoExmes(iExme).iSign * this.aoExmes(iExme).fHeatFlow);
            end
            
            this.fCurrentHeatFlow = fExmeHeatFlow + fSourceHeatFlow;
            
            if isempty(this.fCurrentHeatFlow)
                keyboard()
            end
            
            % If we have set a fixed time step for the phase, we can just
            % continue without doing any calculations as the fixed step is
            % also used for the capacity
            if ~isempty(this.oPhase.fFixedTimeStep)
                fNewStep = this.oPhase.fFixedTimeStep;
            else
                
                rTemperatureChangePerSecond = (this.fCurrentHeatFlow / this.fTotalHeatCapacity) / this.fTemperature;
                
                fNewStep = this.rMaxChange / rTemperatureChangePerSecond;
                
                if fNewStep < 0
                    if ~base.oLog.bOff, this.out(3, 1, 'time-step-neg', 'Phase %s-%s-%s has neg. time step of %.16f', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep }); end;
                end
                
                % If our newly calculated time step is larger than the
                % maximum time step set for this phase, we use this
                % instead.
                if fNewStep > this.oPhase.fMaxStep
                    fNewStep = this.oPhase.fMaxStep;
                    %TODO Make this output a lower level debug message.
                    %fprintf('\nTick %i, Time %f: Phase %s setting maximum timestep of %f\n', this.oTimer.iTick, this.oTimer.fTime, this.sName, this.fMaxStep);
                    
                % If the time step is smaller than the set minimal time
                % step for the phase the minimal time step is used
                % (standard case is that fMinStep is 0, but the user can
                % set it to a different value)
                elseif fNewStep < this.oPhase.fMinStep
                    fNewStep = this.oPhase.fMinStep;
                    %TODO Make this output a lower level debug message.
                    %fprintf('Tick %i, Time %f: Phase %s.%s setting minimum timestep\n', this.oTimer.iTick, this.oTimer.fTime, this.oStore.sName, this.sName);
                end
            end
            
            % Set the time at which the containing store will be updated
            % again. Need to pass on an absolute time, not a time step.
            % Value in store is only updated, if the new update time is
            % earlier than the currently set next update time.
            %this.oStore.setNextUpdateTime(this.fLastMassUpdate + fNewStep);
            this.oPhase.oStore.setNextTimeStep(fNewStep);

            % Cache - e.g. for logging purposes
            this.fTimeStep = fNewStep;

            % Now up to date!
            this.bOutdatedTS = false;
        end
        
        function setBranchesOutdated(this, ~)
            
            if this.fLastSetOutdated >= this.oTimer.fTime
                return;
            end
            
            this.fLastSetOutdated = this.oTimer.fTime;
            
            
            % Loop through exmes / flows and set outdated, i.e. request
            % recalculation of flow rate.
            for iE = 1:this.iProcsEXME
                oExme   = this.aoExmes(iE);
                oBranch = oExme.oBranch;
                
                % Make sure it's not a p2ps.flow - their update method
                % is called in updateProcessorsAndManipulators method
                if isa(oBranch, 'thermal.branch')
                    
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

    end
end
