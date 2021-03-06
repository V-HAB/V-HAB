classdef capacity < base & event.source & matlab.mixin.Heterogeneous
    %CAPACITY An object that holds thermal energy
    % created automatically with a phase and performs all thermal
    % calculations for the respective phase
        
    % Objects of different classes cannot be put into the same
    % array if they do not inherti from the matlab.mixin.Heterogenous class
    % Therefore we use this reference here to be able to put capacities of
    % different subtypes into an object array
    properties (Access = public)
        % If true, updateTemperature triggers all branches to re-calculate their
        % heat flows. Use when thermal capacity is small compared to heat
        % flows
        bSynced = false;
    end
    properties (GetAccess = public, SetAccess = protected)
        %% Basic Properties
        % Current temperature value of this capacity. Can only be cahnged
        % by the updateTemperature function of the capacity to prevent
        % inconsistencies
        fTemperature;
        
        % Specific heat capacity of mixture in phase
        fSpecificHeatCapacity = 0; % [J/(K*kg)]
        
        % Total heat capacity of mixture in phase
        fTotalHeatCapacity = 0; % [J/(K*kg)]
        
        % Total heat flow produced (as in increases temperature,
        % represented by positive sign) or consumed (reduces temperature,
        % represented by negative sign) by the heat sources within this
        % capacity
        fTotalHeatSourceHeatFlow = 0; % [W]
        
        % Property to store the current overall heat flow of this capacity
        % (positive values increase the temperature, negative values
        % decrease it)
        fCurrentHeatFlow = 0; %[W]
        
        % The name of the capacity, which is identical to the name of the
        % phase
        sName;
        
        % Boolean to identify this as a boundary capacity
        bBoundary = false;
        
        % Boolean to identify this as a flow capacity
        bFlow = false;
        
        %% Associated objects
        % The phase which is the matter domain representation of this
        % capacity (as there is no capacity without matter)
        oPhase;
        
        % The thermal.container of which this capacity is a part of.
        oContainer;
        
        % cell array containing all heat sources within this capacity
        coHeatSource;
        
        % struct array containing all heat sources within this capacitiy
        % with their names as the corresponding field names
        toHeatSources;
        
        % Number of heat sources of this capacity
        iHeatSources = 0;
        
        % object arry containing the different (thermal) exmes of this
        % capacity. Not that each matter exme is mirrored by a thermal exme
        % because mass transfer generally also transfers thermal energy
        aoExmes;
        
        % struct containing the different (thermal) exmes with their names
        % as field names
        toProcsEXME;
        
        % integer which is equal to the total number of exmes of this
        % capacity. Usefull to loop over the exmes
        iProcsEXME = 0;
        
        % reference to the matter table object
        oMT;
        
        % reference to the timer object
        oTimer;
        
        %% Numerical properties
        % current (thermal) timestep enforced by this capacity
        fTimeStep; % [s]
        
        % last time at which the temperature was updated
        fLastTemperatureUpdate = -10; %[s]
        
        % This time step is the one used internally by the
        % updateTemperature method. It can be smaller than the fTimeStep
        % property because the updateTemperature methode can also be called
        % by branches for example. See the updateMatter methode of phase.m
        % for further reference
        fTemperatureUpdateTimeStep; % [s]
        
        % maximum allowed temperature change in percent. A value of 0.5%
        % means that for a temperature of 293 K the maximum temperature
        % change is 1.47 K
        rMaxChange = 0.005; % [-]
        
        % These two temperature values represent temperature limits up to
        % which the time step can extended at maximum. E.g. without any
        % other limits, if the temperature is currently 300 K and the lower
        % limit is 275 K, the temperature change at most can be 25 K with
        % the corresponding timestep
        fMinimumTemperatureForTimeStep;
        fMaximumTemperatureForTimeStep;
        
        % In case the user does not want to specify a percentage limit for
        % the time step, this value can be used to define a K limit
        fMaxTemperatureChange = inf;
        
        % The minimal and maximal time step of the capacity:
        fMaxStep = 60;
        fMinStep = 1e-8;
        
        % as for the phase in the matter domain, the time step for the
        % capacity can also be set to a fixed value
        fFixedTimeStep; % [s]
        
        % the last time at which this capacity was set outdated
        fLastSetOutdated = -1; % [s]
        
        % A flag to decide if the updateTemperature is already registered or not
        bRegisteredTemperatureUpdated       = false;
            
        % In recursive calls within the post tick where the capacity itself
        % triggers outdated calls up to the point where it is set outdated
        % again itself it is possible for it to get stuck with a
        % true bRegisteredOutdated flag. To prevent this we also store the
        % last time at which we registered a massupdate
        fLastRegisteredTemperatureUpdated   = -1;
        
        % The last time at which the total heat capacity of this capacity
        % was updated
        fLastTotalHeatCapacityUpdate = 0; % [s]
        
        % Values to decide if the specific heat capacity requires an
        % update. Contain the pressure, temperature and percentual mass
        % composition of the capacity/phase at the last time the specific
        % heat capacity was updated
        fPressureLastHeatCapacityUpdate;        % [Pa]
        fTemperatureLastHeatCapacityUpdate;     % [K]
        arPartialMassLastHeatCapacityUpdate;    % [-]
        
        % Do we need to trigger the massupdate/update events? These
        % properties were implement to improve simulation speed for cases
        % where these triggers are not used
        bTriggerSetCalculateHeatsourcePreCallbackBound = false;
        bTriggerSetUpdateTemperaturePostCallbackBound = false;
        bTriggerSetCalculateFlowConstantTemperatureCallbackBound = false;
        
        % handle to bind the post tick temperature update function to the
        % correct post tick level. If any part wants to trigger a
        % temperature update this is then done through this handle to
        % ensure the correct post tick levels are used.
        % Note that the capacity does not have an update function, as the
        % temperature is the relevant parameter, and similar to mass that
        % must be updated whenever the heatflow of a branch changes, as
        % well as when the time step limits are exceeded.
        hBindPostTickTemperatureUpdate

        % handle to bind the post tick calculateTimeStep function to the
        % correct post tick level. If any part wants to trigger a
        % calculateTimeStep this is then done through this handle to ensure
        % the correct post tick levels are used
        hBindPostTickTimeStep
        
        % In case the capacity is detled, we have to call all unbind
        % functions
        chUnbindFunctions;
        
        % function registered at the timer to allow the setting of a
        % specific time step for this capacity, which is then enforced by
        % the timer object
        setTimeStep;
    end
    
    methods
        
        function this = capacity(oPhase, fTemperature, bFlow)
            %CAPACITY Create new thermal capacity object
            %   Create a new capacity with a name and associated phase
            %   object. Capacities are generated automatically together
            %   with phases and all thermal calculations are performed here
            if nargin < 3
                this.bFlow = false;
            else
                this.bFlow = bFlow;
            end
            % Set associated objects.
            this.oPhase     = oPhase;
            this.oContainer = this.oPhase.oStore.oContainer;
            this.oMT        = oPhase.oMT;
            this.oTimer     = oPhase.oTimer;
            
            % Adding this capacity to the container
            this.oContainer.addCapacity(this);
            
            % Adding this capacity to its phase
            this.oPhase.setCapacity(this);
            
            % Sets the temperature of this capacity and the asscociated
            % phase
            this.setTemperature(fTemperature);
            
            % We need properties that are only defined in the specific
            % phase definition and are not available at the time this
            % constructor is called to set the specific heat capacity.
            try
                this.fSpecificHeatCapacity  = this.oMT.calculateSpecificHeatCapacity(this.oPhase);
                this.fTotalHeatCapacity     = sum(this.oPhase.afMass) * this.fSpecificHeatCapacity;
            catch %#ok<CTCH>
                % Just use dummy values in case the previous try did not
                % work, the really correct ones will be calculated before
                % the sim starts in the init_post triggered function
                this.fSpecificHeatCapacity  = 1000;
                this.fTotalHeatCapacity     = sum(this.oPhase.afMass) * this.fSpecificHeatCapacity;
            end
            
            this.chUnbindFunctions = cell.empty;
            
            [ ~, this.chUnbindFunctions{end+1} ] = this.oContainer.bind('ThermalSeal_post',@(~)this.setInitialHeatCapacity());
            
            
            % Set name of capacity
            this.sName = oPhase.sName;
            
            % Initialize the heat source cell
            this.coHeatSource = cell.empty();
            
            %% Register post tick callbacks for massupdate and update
            if this.bFlow
                [this.hBindPostTickTemperatureUpdate, this.chUnbindFunctions{end+1}] = this.oTimer.registerPostTick(@this.updateTemperature, 'thermal', 'flow_capacity_temperatureupdate');
            else
                [this.hBindPostTickTemperatureUpdate, this.chUnbindFunctions{end+1}] = this.oTimer.registerPostTick(@this.updateTemperature, 'thermal', 'capacity_temperatureupdate');
            end
            [this.hBindPostTickTimeStep,          this.chUnbindFunctions{end+1}] = this.oTimer.registerPostTick(@this.calculateTimeStep, 'post_physics', 'timestep');
            
            % Register the first temperature update
            this.hBindPostTickTemperatureUpdate();
            
            % Bind the .registerUpdateTemperature method to the timer, with
            % a time step of 0 (i.e. smallest step), will be adapted after
            % each .registerUpdateTemperature
            [this.setTimeStep, this.chUnbindFunctions{end+1}] = this.oTimer.bind(@(~) this.registerUpdateTemperature(), 0, struct(...
                'sMethod', 'registerUpdateTemperature', ...
                'sDescription', 'The .registerUpdateTemperature method of a phase', ...
                'oSrcObj', this ...
            ));
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
            if (this.oTimer.iTick <= 0)
                return
            end
            
            if isempty(this.fPressureLastHeatCapacityUpdate) ||...
               (abs(this.fPressureLastHeatCapacityUpdate - this.oPhase.fPressure) > 100) ||...
               (abs(this.fTemperatureLastHeatCapacityUpdate - this.fTemperature) > 1) ||...
               (max(abs(this.arPartialMassLastHeatCapacityUpdate - this.oPhase.arPartialMass)) > 0.01)
                
           
                if ~base.oDebug.bOff
                    this.out(1, 1, 'name', '%s-%s-%s', { this.oContainer.sName, this.oPhase.oStore.sName, this.sName });

                    this.out(1, 2, 'last', 'fSpecificHeatCapacity:              %f [J/(kg*K)]', { this.fSpecificHeatCapacity });
                    this.out(1, 2, 'last', 'fMass:                              %f [kg]',       { sum(this.arPartialMassLastHeatCapacityUpdate) });
                    this.out(1, 2, 'last', 'fPressureLastHeatCapacityUpdate:    %f [Pa]',       { this.fPressureLastHeatCapacityUpdate });
                    this.out(1, 2, 'last', 'fTemperatureLastHeatCapacityUpdate: %f [K]',        { this.fTemperatureLastHeatCapacityUpdate });
                end
                
                % Actually updating the specific heat capacity
                this.setSpecificHeatCapacity(this.oMT.calculateSpecificHeatCapacity(this.oPhase));
                
                % Setting the properties for the next check
                this.fPressureLastHeatCapacityUpdate     = this.oPhase.fPressure;
                this.fTemperatureLastHeatCapacityUpdate  = this.fTemperature;
                this.arPartialMassLastHeatCapacityUpdate = this.oPhase.arPartialMass;
                
                
                if ~base.oDebug.bOff
                    this.out(1, 2, 'curr', 'fSpecificHeatCapacity:              %f [J/(kg*K)]', { this.fSpecificHeatCapacity });
                    this.out(1, 2, 'curr', 'fMass:                              %f [kg]',       { sum(this.arPartialMassLastHeatCapacityUpdate) });
                    this.out(1, 2, 'curr', 'fPressureLastHeatCapacityUpdate:    %f [Pa]',       { this.fPressureLastHeatCapacityUpdate });
                    this.out(1, 2, 'curr', 'fTemperatureLastHeatCapacityUpdate: %f [K]',        { this.fTemperatureLastHeatCapacityUpdate });
                end
            end
        end
        
        function setTotalHeatCapacity(this, fTotalHeatCapacity)
            % Function to overwrite the total heat capacity of this
            % capacity and perform necessary other settings as well
            %
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
            % this is basically what happens here as the difference in
            % temperature is already handled in the thermal branch
            if ~this.bBoundary
                this.fTotalHeatCapacity = fTotalHeatCapacity;
            end
            
            this.fLastTotalHeatCapacityUpdate = this.oTimer.fTime;
        end
        
        function setSpecificHeatCapacity(this, fSpecificHeatCapacity)
            % Set the specific heat capacity (and while doing this also the
            % total heat capacity) of this phase and ensure a closed energy
            % balance while doing this. The specific heat capacity changes
            % when the matter property is recalculated in the matter table,
            % as it is temperature (and pressure) dependent
            if this.oPhase.bFlow
                % For flow phases we use the current inflowing masses for
                % the specific heat capacity calculation
                mfFlowRate              = zeros(1,this.iProcsEXME);
                mfSpecificHeatCapacity  = zeros(1,this.iProcsEXME);
                
                for iExme = 1:this.iProcsEXME
                    if isa(this.aoExmes(iExme).oBranch.oHandler, 'solver.thermal.basic_fluidic.branch')
                        
                        iExMeSign = this.aoExmes(iExme).iSign;
                        fFlowRate = this.aoExmes(iExme).oBranch.oMatterObject.fFlowRate * iExMeSign;
                        
                        if fFlowRate > 0
                            mfFlowRate(iExme) = fFlowRate;
                            oMatterObject = this.aoExmes(iExme).oBranch.oMatterObject;
                            try
                                iBranchSign = sign(oMatterObject.fFlowRate);
                                if iBranchSign * iExMeSign < 0
                                    mfSpecificHeatCapacity(iExme) = oMatterObject.aoFlows(1).fSpecificHeatCapacity;
                                else
                                    mfSpecificHeatCapacity(iExme) = oMatterObject.aoFlows(end).fSpecificHeatCapacity;
                                end
                            catch oFirstError
                                try
                                    mfSpecificHeatCapacity(iExme) = oMatterObject.fSpecificHeatCapacity;
                                catch oSecondError
                                    if strcmp(oFirstError.identifier, 'MATLAB:noSuchMethodOrField')
                                        rethrow(oSecondError);
                                    else
                                        rethrow(oFirstError);
                                    end
                                end
                            end
                        end
                    end
                end
                
                if sum(mfFlowRate) ~= 0
                    this.fSpecificHeatCapacity  = sum(mfFlowRate .* mfSpecificHeatCapacity) / sum(mfFlowRate);
                end
            else
                this.fSpecificHeatCapacity = fSpecificHeatCapacity;
                % Set the new total heat capacity
                this.setTotalHeatCapacity(this.oPhase.fMass * fSpecificHeatCapacity);

                % in case the total heat capacity is 0 (as happens if no
                % mass is present) we also set the temperature to 0
                if this.fTotalHeatCapacity == 0
                    this.setTemperature( 0 );
                end
            end
               
        end
        
        function addProcEXME(this, oProcEXME)
            % Adds a (thermal) exme proc, i.e. a port. 
            
            % Check cases which would result in inconsistencies within the
            % simulation
            if this.oContainer.bThermalSealed
                this.throw('addProcEXME', 'The container to which this capacity belongs is sealed, so no ports can be added any more.');
            end

            if ~isa(oProcEXME, 'thermal.procs.exme')
                this.throw('addProcEXME', 'Provided object ~isa thermal.procs.exme');
            elseif ~isempty(oProcEXME.oCapacity)
                this.throw('addProcEXME', 'Processor has already a Capacity set as parent.');
            elseif isfield(this.toProcsEXME, oProcEXME.sName)
                this.throw('addProcEXME', 'Proc %s already exists.', oProcEXME.sName);
            end

            % add exme to the struct reference and the array
            this.toProcsEXME.(oProcEXME.sName) = oProcEXME;
            
            if isempty(this.aoExmes)
                this.aoExmes = oProcEXME;
            else
                this.aoExmes(end+1) = oProcEXME;
            end
            
            % increase the counter for the number of exmes by 1
            this.iProcsEXME = this.iProcsEXME + 1;
        end
        
        function addHeatSource(this, oHeatSource)
            % Add a heat source to this capacity object. The power set to this
            % heat source will be included in the temperature calculations.
            %
            % Parameter oHeatSource: will be added as a local heat source
            % of this capacity
            % Positive power means temperature RISE.
            
            if this.oContainer.bThermalSealed
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
            
            if isempty(this.coHeatSource)
                this.coHeatSource = {oHeatSource};
            else
                this.coHeatSource{end+1} = oHeatSource;
            end
            
            this.iHeatSources = length(this.coHeatSource);
        end
        
        function setOutdatedTS(this)
            % tell the timer object that heat flows entering/leaving the
            % capacity changed or the total heat capacity changed and we
            % therefore have to recalculate the time step to ensure that no
            % limits are broken.
            %
            % Only sets a boolean in the timer to true, so it does not
            % matter if we do this multiple times --> no check required
            this.hBindPostTickTimeStep();
            % Since this function is called when the heat flows change, we
            % also have to call the temperature update to transfer the
            % correct amount of thermal energy before changing the heat
            % flows!
            this.registerUpdateTemperature();
        end
        
        function registerUpdateTemperature(this, ~)
            % register a temperature update for this capacity in the post
            % tick
            if ~(this.oTimer.fTime > this.fLastRegisteredTemperatureUpdated) && this.bRegisteredTemperatureUpdated
                return
            end
            
            this.hBindPostTickTemperatureUpdate();
            
            this.fLastRegisteredTemperatureUpdated = this.oTimer.fTime;
            this.bRegisteredTemperatureUpdated = true;
            
        end
            
        function updateTemperature(this, ~)
            % Use fCurrentHeatFlow to calculate the temperature change
            % since the last execution fLastTemperatureUpdate
            
            % Getting the current time and calculating the last time step
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastTemperatureUpdate;
            
            % Return if no time has passed
            if fLastStep == 0
                if ~base.oDebug.bOff, this.out(2, 1, 'skip', 'Skipping temperatureupdate in %s-%s-%s', { this.oPhase.oStore.oContainer.sName, this.oPhase.oStore.sName, this.sName }); end
                return;
            end
            
            % To ensure that we calculate the new energy with the correct
            % total heat capacity we have to get the current mass and the
            % possible mass that was added since the last mass update (in
            % case this was not executed in the same tick) (oPhase.fMass +
            % oPhase.fCurrentTotalInOuts * (this.oTimer.fTime -
            % oPhase.fLastMassUpdate)) * this.fSpecificHeatCapacity There
            % is a small error from this because the specific heat capacity
            % is not perfectly correct. However, as the matter side
            % controls the maximum allowed changes in composition until
            % this is recalculated, these are acceptable errors.
            
            % This is not a flow phase. 
            if this.fTotalHeatCapacity <= 1e-15
                % Setting the temperature to 293 K. If the temperature
                % is set to zero, it will cause problems with several
                % solvers that use the capacity temperature for density
                % calculations, even though the flow rate is zero. 
                fTemperatureNew = 293;
            else
                % Calculating the new temperature based on the current
                % heat flow. This value is calculated in the
                % calculateTimeStep() method of this class. 
                fTemperatureNew = this.fTemperature + ((this.fCurrentHeatFlow / this.fTotalHeatCapacity) * fLastStep);
            end
            
            % Setting the properties that help us determine if we need to
            % do this again next time this method is called. 
            this.fLastTemperatureUpdate     = fTime;
            this.fTemperatureUpdateTimeStep = fLastStep;
            
            % The temperature is not set directly, because we want to
            % ensure that the phase and capacity have the exact same
            % temperature at all times
            this.setTemperature(fTemperatureNew);
            
            % check if we have to update the specific heat capacity
            this.updateSpecificHeatCapacity();
            
            % Trigger branch solver updates in post tick for all branches
            this.setBranchesOutdated();
            
            % Capacity sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
            
            % Triggering in case someone wants to do something here
            if this.bTriggerSetUpdateTemperaturePostCallbackBound
            	this.trigger('updateTemperature_post');
            end
            
            this.bRegisteredTemperatureUpdated = false;
        end
        
        %% Setting of time step properties
        function setTimeStepProperties(this, tTimeStepProperties)
            % currently the possible time step properties that can be set
            % by the user are:
            %
            % rMaxChange:     Maximum allowed percentage change in the total
            %                 temperature of the capacity
            % fMaxStep:       Maximum time step in seconds
            % fMinStep:       Minimum time step in seconds
            % fFixedTimeStep: Fixed (constant) time step in seconds, if this
            %                 property is set all other time step properties
            %                 will be ignored and the set time step will be
            %                 used
            %
            % fMaxTemperatureChange:    Maximum allowed temperature change
            %                           in K
            % fMinimumTemperatureForTimeStep:   Minimum temperature up to
            %                                   which the time step can
            %                                   extend
            % fMaximumTemperatureForTimeStep:   Maximum temperature up to
            %                                   which the time step can
            %                                   extend
            
        
            
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            csPossibleFieldNames = {'rMaxChange', 'fFixedTimeStep', 'fMaxStep', 'fMinStep', 'fMaxTemperatureChange', 'fMinimumTemperatureForTimeStep', 'fMaximumTemperatureForTimeStep'};
            
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
        
        function [ this, unbindCallback ] = bind(this, sType, callBack)
        % Catch 'bind' calls, so we can set a specific boolean property to
        % true so the .trigger() method will only be called if there are
        % callbacks registered.
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % Only do for set
            if strcmp(sType, 'calculateHeatsource_pre')
                this.bTriggerSetCalculateHeatsourcePreCallbackBound = true;
            end
            if strcmp(sType, 'updateTemperature_post')
                this.bTriggerSetUpdateTemperaturePostCallbackBound = true;
            end
            if strcmp(sType, 'calculateFlowConstantTemperature')
                this.bTriggerSetCalculateFlowConstantTemperatureCallbackBound = true;
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
            this.oPhase.setTemperature(fTemperature);
        end
        
        function setInitialHeatCapacity(this,~)
            % Function used to set the initial heat capacity after the
            % system has been sealed
            this.fSpecificHeatCapacity  = this.oMT.calculateSpecificHeatCapacity(this.oPhase);
            if this.bBoundary
                this.fTotalHeatCapacity	= inf;
            else
                this.fTotalHeatCapacity	= sum(this.oPhase.afMass) * this.fSpecificHeatCapacity;
            end
        end
        
        function calculateTimeStep(this,~)
            % This function performs the following calculation steps
            % - Loop through all thermal exmes of the capacity and get 
            %   their heat flows
            % - Loop through all heat sources and get their heat flows
            % - Store the overall heat flow in the fCurrentHeatFlow property
            % - calculate the allowed time step based on the phase
            %   temperature max change
            
            % In case we have a boundary we can just use the maximum time
            % step because any change in boundary phases is triggered externally
            if this.bBoundary
                fNewStep = this.fMaxStep;
            else
                try
                    fExmeHeatFlow = sum([this.aoExmes.iSign] .* [this.aoExmes.fHeatFlow]);
                catch oError
                    if ~isempty(this.aoExmes)
                        rethrow(oError)
                    else
                        fExmeHeatFlow = 0;
                    end
                end

                
                % For constant temperature heat sources, we have to
                % recalculate the heat source now with this trigger, to
                % ensure that it used the correct heat flows from other
                % values
                if this.bTriggerSetCalculateHeatsourcePreCallbackBound
                    this.trigger('calculateHeatsource_pre');
                end
                
                this.fTotalHeatSourceHeatFlow = sum(cellfun(@(cCell) cCell.fHeatFlow, this.coHeatSource));
                
                fNewHeatFlow = fExmeHeatFlow + this.fTotalHeatSourceHeatFlow;
                % In case the heat flow changed we trigger a update of the
                % residual solver branches, which in the thermal domain are
                % e.g. the infinite conduction branches
                if fNewHeatFlow ~= this.fCurrentHeatFlow
                    this.setBranchesOutdated(true);
                end
                
                % Checking for NaNs. It is necessary to do this here so the
                % origin of NaNs can be found easily during debugging.
                if isnan(fNewHeatFlow)
                    
                    % Checking if its the EXMEs
                    abEXMEsWithNaNs = isnan([this.aoExmes.fHeatFlow]);
                    
                    if any(abEXMEsWithNaNs)
                        error('Error in capacity ''%s''. The heat flow from EXME ''%s'' is NaN.\n', this.sName, this.aoExmes(abEXMEsWithNaNs).sName);
                    else
                        % It's not from the EXMEs so it has to be from one
                        % of the connected heat sources.
                        abHeatSourcesWithNaNs = false(length(this.coHeatSource));
                        for iHeatSource = 1:length(this.coHeatSource)
                            abHeatSourcesWithNaNs(iHeatSource) = isnan(this.coHeatSource{iHeatSource}.fHeatFlow);
                        end
                        error('Error in capacity ''%s''. The heat flow from heatsource ''%s'' is NaN.\n', this.sName, this.coHeatSource{abHeatSourcesWithNaNs}.sName);
                    end
                end
                
                this.fCurrentHeatFlow = fNewHeatFlow;
                
                % If we have set a fixed time step for the phase, we can
                % just continue without doing any calculations as the fixed
                % step is also used for the capacity
                if this.oPhase.bFlow
                    % In a flow phase heat flows do not change temperature
                    % over time, but instead directly change the
                    % temperature. Therefore, the time step in flow phases
                    % can be infinite. Recalculation in this case is
                    % triggered only through changes in the branches
                    fNewStep = inf;
                else
                    % if it is not a flow phase we always calculate a
                    % maximum time step which prevents unphysical
                    % properties
                    
                    % calculate the current percentual temperature change
                    % per second
                    fTemperatureChangePerSecond = (this.fCurrentHeatFlow / this.fTotalHeatCapacity);
                    rTemperatureChangePerSecond = abs(fTemperatureChangePerSecond / this.fTemperature);
                    
                    % similar to the mass we also limit the temperature
                    % update to prevent negative temperatures:
                    if fTemperatureChangePerSecond < 0
                        fMaximumTimeStep = - this.fTemperature / fTemperatureChangePerSecond;
                    else
                        fMaximumTimeStep = inf;
                    end
                    
                    if ~isempty(this.fFixedTimeStep)
                        % If a fixed time step is set just use that value
                        % as time step
                        fNewStep = this.fFixedTimeStep;
                        
                        fNewStep = min(fNewStep, fMaximumTimeStep);
                    else
                        % for no heat capacity, no heat can be stored -->
                        % infinite time step
                        if this.fTotalHeatCapacity == 0 || this.fTemperature == 0
                            this.setTimeStep(inf);
                            return
                        end
                        
                        fNewStepPercentage = this.rMaxChange / rTemperatureChangePerSecond;
                        fNewStepTotal      = abs(this.fMaxTemperatureChange / fTemperatureChangePerSecond);
                        fNewStepLowerLimit = inf;
                        fNewStepUpperLimit = inf;
                        if fTemperatureChangePerSecond < 0 && ~isempty(this.fMinimumTemperatureForTimeStep)
                            fNewStepLowerLimit = (this.fTemperature - this.fMinimumTemperatureForTimeStep) / fTemperatureChangePerSecond;
                            if fNewStepLowerLimit < 0
                                fNewStepLowerLimit = inf;
                            end
                        elseif fTemperatureChangePerSecond > 0 && ~isempty(this.fMaximumTemperatureForTimeStep)
                            fNewStepUpperLimit = (this.fMaximumTemperatureForTimeStep - this.fTemperature) / fTemperatureChangePerSecond;
                            if fNewStepUpperLimit < 0
                                fNewStepUpperLimit = inf;
                            end
                        end
                        
                        fNewStep = min([fNewStepPercentage, fNewStepTotal, fNewStepLowerLimit, fNewStepUpperLimit, fMaximumTimeStep]);
                        
                        if fNewStep < 0
                            if ~base.oDebug.bOff, this.out(3, 1, 'time-step-neg', 'Phase %s-%s-%s has neg. time step of %.16f', { this.oStore.oContainer.sName, this.oStore.sName, this.sName, fNewStep }); end
                        end
                        
                        % If our newly calculated time step is larger than
                        % the maximum time step set for this phase, we use
                        % this instead.
                        if fNewStep > this.fMaxStep
                            fNewStep = this.fMaxStep;
                            if ~base.oDebug.bOff
                                this.out(3, 1, 'max-time-step', 'Phase %s-%s-%s setting maximum timestep of %f', { this.oContainer.sName, this.oPhase.oStore.sName, this.sName, this.oPhase.fMaxStep });
                            end
                            
                            % If the time step is smaller than the set
                            % minimal time step for the phase the minimal
                            % time step is used (standard case is that
                            % fMinStep is 0, but the user can set it to a
                            % different value)
                        elseif fNewStep < this.fMinStep
                            fNewStep = this.fMinStep;
                            %TODO Make this output a lower level debug
                            %message.
                            if ~base.oDebug.bOff
                                this.out(3, 1, 'min-time-step', 'Phase %s-%s-%s setting minimum timestep', { this.oContainer.sName, this.oPhase.oStore.sName, this.sName });
                            end
                        end
                    end
                end
                
            end
            
            % Set the time step for this capacity. If the update was also
            % called in this tick we also reset the time at which the phase
            % was last executed thus enforcing the next execution time to
            % be exactly this.oTimer.fTime + fNewStep
            if this.fLastTemperatureUpdate == this.oTimer.fTime
                this.setTimeStep(fNewStep, true);
            else
                this.setTimeStep(fNewStep);
            end

            % Cache - e.g. for logging purposes
            this.fTimeStep = fNewStep;
        end
        
        function setBranchesOutdated(this, bResidual)
            % Function to set all connected branches outdated. In case that
            % the bResidual parameter is also provided it sets only
            % branches outdated which are considered "residual" meaning
            % they require to be informed about even very small changes in
            % the heat flow affecting this capacity
            if nargin < 2
                bResidual = false;
            end
            
            bUpdateOutFlow = false;
            if ~bResidual && this.fLastSetOutdated >= this.oTimer.fTime
                if this.bFlow
                    % Since flow phases can change instantly, we still have
                    % to update their outflows even if they were already
                    % updated in this tick
                    bUpdateOutFlow = true;
                else
                    return;
                end
            end
            
            this.fLastSetOutdated = this.oTimer.fTime;
            
            
            % Loop through exmes / flows and set outdated, i.e. request
            % recalculation of flow rate.
            for iE = 1:this.iProcsEXME
                oBranch = this.aoExmes(iE).oBranch;
                % We can't directly set this oBranch as outdated if
                % it is just connected to an interface, because the
                % solver is assigned to the 'leftest' branch.
                while oBranch.abIf(1)
                    oBranch = oBranch.coBranches{1};
                end    
                
                if bResidual && ~oBranch.oHandler.bResidual
                    continue
                end
                
                % Tell branch to recalculate flow rate (done after
                % the current tick, in timer post tick).
                
                if bUpdateOutFlow && this.aoExmes(iE).iSign * oBranch.fHeatFlow <= 0
                    oBranch.setOutdated();
                else
                    oBranch.setOutdated();
                end
            end
        end
    end
    
    methods (Access = {?thermal.procs.exme})
        % these functions are used to handle dynamic reconnection of
        % branches during simulations. As it is important that everything
        % is done correctly to prevent inconsistent simulation states while
        % doing this, only the exme itself (from which the operation is
        % triggered) has access to the necessary functions
        function removeExMe(this, oExMe)
            %% removeExMe
            % This function removes the specified oExMe from the phase and
            % sets the phase to outdated
            this.toProcsEXME = rmfield(this.toProcsEXME, oExMe.sName);
            for iExme = 1:this.iProcsEXME
                if this.aoExmes(iExme) == oExMe
                    break
                end
            end
            this.aoExmes(iExme) = [];
            this.iProcsEXME = this.iProcsEXME - 1;
            
            this.setOutdatedTS();
        end
        
        function addExMe(this, oExMe)
            %% addExMe
            % adds the specified ExMe to this phase and sets the phase to
            % outdated
            this.toProcsEXME.(oExMe.sName) = oExMe;
            if isempty(this.aoExmes)
                this.aoExmes = oExMe;
            else
                this.aoExmes(end + 1) = oExMe;
            end
            this.iProcsEXME = this.iProcsEXME + 1;
            
            this.setOutdatedTS();
        end
    end
end