classdef capacity < base & event.source
    %CAPACITY An object that holds thermal energy
    % created automatically with a phase and performs all thermal
    % calculations for the respective phase
        
    properties (Access = public)
        % If true, updateTemperature triggers all branches to re-calculate their
        % heat flows. Use when thermal capacity is small compared to heat
        % flows
        bSynced = false;
    end
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
        fLastTemperatureUpdate = -10;
        
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
        
        % Do we need to trigger the massupdate/update events? These
        % properties were implement to improve simulation speed for cases
        % where these triggers are not used
        bTriggerSetCalculateHeatsourcePreCallbackBound = false;
        bTriggerSetUpdateTemperaturePostCallbackBound = false;
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
            
            % sets the temperature of this capacity and the asscociated
            % phase
            this.setTemperature(fTemperature);
            
            % We need properties that are only defined in the specific
            % phase definition and are not available at the time this
            % constructor is called to set the specific heat capacity.
            try
                this.fSpecificHeatCapacity  = this.oMT.calculateSpecificHeatCapacity(this.oPhase);
                this.fTotalHeatCapacity     = sum(this.oPhase.afMass) * this.fSpecificHeatCapacity;
            catch
                % just use dummy values in case the previous try did not
                % work, the really correct ones will be calculated before
                % the sim starts in the init_post triggered function
                this.fSpecificHeatCapacity  = 1000;
                this.fTotalHeatCapacity     = sum(this.oPhase.afMass) * this.fSpecificHeatCapacity;
            end
            
            this.oPhase.oStore.oContainer.bind('ThermalSeal_post',@(~)this.setInitialHeatCapacity());
            
            
            % Set name of capacity.
            this.sName = oPhase.sName;
            
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
            if (this.oTimer.iTick <= 0)
                return
            end
            if (abs(this.fPressureLastHeatCapacityUpdate - this.oPhase.fPressure) > 100) ||...
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
            if this.oPhase.bFlow
                mfFlowRate              = zeros(1,this.iProcsEXME);
                mfSpecificHeatCapacity  = zeros(1,this.iProcsEXME);
                for iExme = 1:this.iProcsEXME
                    if isa(this.aoExmes(iExme).oBranch.oHandler, 'solver.thermal.basic_fluidic.branch')
                        fFlowRate = this.aoExmes(iExme).oBranch.coConductors{1}.oMassBranch.fFlowRate * this.oPhase.toProcsEXME.(this.aoExmes(iExme).sName).iSign;
                        
                        if fFlowRate > 0
                            mfFlowRate(iExme) = fFlowRate;
                            mfSpecificHeatCapacity(iExme) = this.oPhase.toProcsEXME.(this.aoExmes(iExme).sName).oFlow.fSpecificHeatCapacity;
                        end
                    end
                end
                
                if sum(mfFlowRate) ~= 0
                    this.fSpecificHeatCapacity  = sum(mfFlowRate .* mfSpecificHeatCapacity) / sum(mfFlowRate);
                end
            else
                fInnerEnergyBefore = this.fTotalHeatCapacity * this.fTemperature;

                this.fTotalHeatCapacity = (this.oPhase.fMass * fSpecificHeatCapacity);

                this.setTemperature( fInnerEnergyBefore / this.fTotalHeatCapacity );

                this.fSpecificHeatCapacity = fSpecificHeatCapacity;
            end
               
        end
        
        function addProcEXME(this, oProcEXME)
            % Adds a exme proc, i.e. a port. 
            
            if this.oPhase.oStore.oContainer.bThermalSealed
                this.throw('addProcEXME', 'The container to which this capacity belongs is sealed, so no ports can be added any more.');
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
            
            if this.oPhase.oStore.oContainer.bThermalSealed
                this.throw('addHeatSource', 'The container to which this capacity belongs is sealed, so no heat sources can be added any more.');
            end

            if ~isa(oHeatSource, 'thermal.heatsource')
                this.throw('addHeatSource', 'Provided object ~isa thermal.heatsource');
            elseif ~isempty(oHeatSource.oCapacity)
                this.throw('addHeatSource', 'Heat source has already a Capacity set as parent.');
            elseif isfield(this.toHeatSources, oHeatSource.sName)
                this.throw('addHeatSource', 'Heat source %s already exists.', oHeatSource.sName);
            end

            this.toHeatSources.(oHeatSource.sName) = oHeatSource;
            
            oHeatSource.setCapacity(this);
            
            if isempty(this.aoHeatSource)
                this.aoHeatSource = oHeatSource;
            else
                this.aoHeatSource(end+1) = oHeatSource;
            end
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
            
            % to ensure that we calculate the new energy with the correct
            % total heat capacity, a massupdate is executed first (if this
            % was not done anyway already)
            this.oPhase.massupdate();
            
            % in case that the phase is considered only a flowthrough phase
            % with 0 mass (and therefore also 0 capacity by itself) the
            % temperature calculation must be adapted to reflect this
            % correctly
            if this.oPhase.bFlow
                mfFlowRate              = zeros(1,this.iProcsEXME);
                mfSpecificHeatCapacity  = zeros(1,this.iProcsEXME);
                mfTemperature           = zeros(1,this.iProcsEXME);
                for iExme = 1:this.iProcsEXME
                    if isa(this.aoExmes(iExme).oBranch.oHandler, 'solver.thermal.basic_fluidic.branch')
                        fFlowRate = this.aoExmes(iExme).oBranch.coConductors{1}.oMassBranch.fFlowRate * this.oPhase.toProcsEXME.(this.aoExmes(iExme).sName).iSign;
                        
                        if fFlowRate > 0
                            mfFlowRate(iExme) = fFlowRate;
                            mfSpecificHeatCapacity(iExme) = this.oPhase.toProcsEXME.(this.aoExmes(iExme).sName).oFlow.fSpecificHeatCapacity;
                            mfTemperature(iExme) = this.oPhase.toProcsEXME.(this.aoExmes(iExme).sName).oFlow.fTemperature;
                        end
                    end
                end
                
                fOverallHeatCapacityFlow = sum(mfFlowRate .* mfSpecificHeatCapacity);
                if sum(mfFlowRate) == 0
                    % if nothing flows into the phase, it maintains the
                    % previous temperature
                    fTemperatureNew = this.fTemperature;
                else
                    
                    fSourceHeatFlow = 0;
                    for iSource = 1:length(this.aoHeatSource)
                        fSourceHeatFlow = fSourceHeatFlow + this.aoHeatSource(iSource).fHeatFlow;
                    end
                    
                    fTemperatureNew = (sum(mfFlowRate .* mfSpecificHeatCapacity .* mfTemperature) / fOverallHeatCapacityFlow) + fSourceHeatFlow/fOverallHeatCapacityFlow;
                end
            else
                % Now we calculate the new temperature
                fTemperatureNew = this.fTemperature + ((this.fCurrentHeatFlow / this.fTotalHeatCapacity) * fLastStep);

            end
            
            this.fLastTemperatureUpdate     = fTime;
            this.fTemperatureUpdateTimeStep = fLastStep;
            
            % The temperature is not set directly, because we want to
            % ensure that the phase and capacity have the exact same
            % temperature at all times
            this.setTemperature(fTemperatureNew);
            
            % Trigger branch solver updates in post tick for all branches
            % whose heatflow is currently flowing INTO the capacity
            if this.bSynced || bSetBranchesOutdated
                this.setBranchesOutdated();
            end
            
            % Capacity sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
            
            if this.bTriggerSetUpdateTemperaturePostCallbackBound
            	this.trigger('updateTemperature_post');
            end
            
        end
        
        %% Setting of time step properties
        function setTimeStepProperties(this, tTimeStepProperties)
            % currently the possible time step properties that can be set
            % by the user are:
            %
            % rMaxChange:   Maximum allowed percentage change in the total
            %               temperature of the capacity
            %
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            csPossibleFieldNames = {'rMaxChange'};
            
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
            if strcmp(sType, 'calculateHeatsource_pre')
                this.bTriggerSetCalculateHeatsourcePreCallbackBound = true;
            end
            if strcmp(sType, 'updateTemperature_post')
                this.bTriggerSetUpdateTemperaturePostCallbackBound = true;
            end
        end
    end
    
    methods (Access = protected)
        function setTemperature(this, fTemperature)
            % Internal function of the capacity object to set the
            % temperature. This is used to ensure that the capacity
            % temperature and phase temperature are always set at the same
            % time. Note that only the capacity is allowed to set
            % temperature values
            this.fTemperature = fTemperature;
            this.oPhase.setTemperature(this, fTemperature);
        end
        
        function setInitialHeatCapacity(this,~)
            this.fSpecificHeatCapacity  = this.oMT.calculateSpecificHeatCapacity(this.oPhase);
            this.fTotalHeatCapacity     = sum(this.oPhase.afMass) * this.fSpecificHeatCapacity;
        end
        
        function calculateTimeStep(this,~)
            % This function performs the following calculation steps
            % - Loop through all thermal exmes of the capacity and get 
            %   their heat flows
            % - Loop through all heat sources and get their heat flows
            % - Store the overall heat flow in the fCurrentHeatFlow property
            % - calculate the allowed time step based on the phase
            %   temperature max change
            
            fExmeHeatFlow = 0;
            for iExme = 1:length(this.aoExmes)
                fExmeHeatFlow = fExmeHeatFlow + (this.aoExmes(iExme).iSign * this.aoExmes(iExme).fHeatFlow);
            end
            
            if this.bTriggerSetCalculateHeatsourcePreCallbackBound
            	this.trigger('calculateHeatsource_pre');
            end
            
            fSourceHeatFlow = 0;
            for iSource = 1:length(this.aoHeatSource)
                fSourceHeatFlow = fSourceHeatFlow + this.aoHeatSource(iSource).fHeatFlow;
            end
            
            this.fCurrentHeatFlow = fExmeHeatFlow + fSourceHeatFlow;
            
            % If we have set a fixed time step for the phase, we can just
            % continue without doing any calculations as the fixed step is
            % also used for the capacity
            if ~isempty(this.oPhase.fFixedTimeStep)
                fNewStep = this.oPhase.fFixedTimeStep;
            else
                
                rTemperatureChangePerSecond = abs((this.fCurrentHeatFlow / this.fTotalHeatCapacity) / this.fTemperature);
                
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
