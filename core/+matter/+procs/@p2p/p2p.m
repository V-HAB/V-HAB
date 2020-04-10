classdef (Abstract) p2p < matter.flow & event.source
    %P2P or Phase to Phase processor, can be used to move matter from one
    % phase to another within a single store. Allows phase change and
    % specific substance transfer to model e.g. condensation/vaporization
    % (phase change) or adsorbing only CO2 from air (consisting of N2, O2,
    % CO2 and H2O)
    
    properties (SetAccess = protected, GetAccess = public)
        % Time in seconds at which the P2P was last updated
        fLastUpdate = -1;
        
        % for the thermal side the P2Ps are not different from branches,
        % therefore no thermal P2P exists and instead a thermal branch is
        % used to model the heat transfer of this P2P
        oThermalBranch;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Name of the p2p processor
        sName;
        
        % Index of the update post tick in the corresponding cell
        % and boolean array of the timer
        hBindPostTickUpdate;
        
        % cell array containing both exmes which connect the P2P to the
        % different phases
        coExmes;
        
        % boolean flag to decide if the event 'setMatterProperties' has any
        % callbacks registered and should be executed
        bTriggersetMatterPropertiesCallbackBound = false;
    end
    
    methods
        function this = p2p(oStore, sName, xIn, xOut)
            %% p2p class constructor.
            %
            % creates a new P2P which can move individual substance from
            % one phase to another phase in the same store. Note that mass
            % transfer between phases in different stores does NOT work!
            %
            % Required Inputs:
            % oStore:   Store object in which the P2P is located
            % sName:    Name of the processor
            % sPhaseAndPortIn and sPhaseAndPortOut:
            %       Combination of Phase and Exme name in dot notation:
            %       phase.exme as a string. The in side is considered from
            %       the perspective of the P2P, which means in goes into
            %       the P2P but leaves the phase, which might be confusing
            %       at first. So for a positive flowrate the mass is taken
            %       from the in phase and exme!
            
            % Parent constructor
            this@matter.flow(oStore);
            
            % Overwriting the this.sObjectType property that is inherited
            % from matter.flow.
            % In order to remove the need for numerous calls to isa(),
            % especially in the matter table, this property can be used to see
            % if an object is derived from this class.
            this.sObjectType = 'p2p';
            
            if ischar(xIn)
                % Phases / ports
                [ sPhaseIn,  sExMeIn  ] = strtok(xIn,  '.');

                % Find the phases
                try
                    oPhaseIn    = this.oStore.toPhases.(sPhaseIn);
                catch
                    this.throw('p2p', 'Phase could not be found: in phase "%s"', sPhaseIn);
                end
                if isempty(sExMeIn)
                    matter.procs.exmes.(oPhaseIn.sType)(oPhaseIn,       [sName, '_In']);
                    sExMeIn = ['.' , sName, '_In'];
                end
            else
                % In this case the input should be a phase, and we have to
                % create a new exme to which the P2P can be connected:
                if ~isa(xIn, 'matter.phase')
                    this.throw('p2p', 'Provided input for the P2P %s neither a string nor phase', sName)
                end
                oPhaseIn = xIn;
                matter.procs.exmes.(oPhaseIn.sType)(oPhaseIn,       [sName, '_In']);
                sExMeIn = ['.' , sName, '_In'];
            end
            
            if ischar(xOut)
                [ sPhaseOut, sExMeOut ] = strtok(xOut, '.');

                % Find the phases
                try
                    oPhaseOut   = this.oStore.toPhases.(sPhaseOut);
                catch
                    this.throw('p2p', 'Phase could not be found: out phase "%s"', sPhaseOut);
                end
                if isempty(sExMeOut)
                    matter.procs.exmes.(oPhaseOut.sType)(oPhaseOut,       [sName, '_Out']);
                    sExMeOut = ['.' , sName, '_Out'];
                end
            else
                % In this case the input should be a phase, and we have to
                % create a new exme to which the P2P can be connected:
                if ~isa(xOut, 'matter.phase')
                    this.throw('p2p', 'Provided input for the P2P %s neither a string nor phase', this.sName)
                end
                oPhaseOut = xOut;
                matter.procs.exmes.(oPhaseOut.sType)(oPhaseOut,       [sName, '_Out']);
                sExMeOut = ['.' , sName, '_Out'];
            end
            % Set name of P2P
            this.sName   = sName;
            
            % Can only be done after this.oStore is set, store checks that!
            this.oStore.addP2P(this);
            
            oPhaseIn.toProcsEXME.(sExMeIn(2:end) ).addFlow(this);
            oPhaseOut.toProcsEXME.(sExMeOut(2:end)).addFlow(this);
            
            %% Construct asscociated thermal branch
            % Create the respective thermal interfaces for the thermal
            % branch
            % Split to store name / ExMe name
            oExMe = this.oStore.getExMe(sExMeIn(2:end));
            thermal.procs.exme(oExMe.oPhase.oCapacity, sExMeIn(2:end));
            
            oExMe = this.oStore.getExMe(sExMeOut(2:end));
            thermal.procs.exme(oExMe.oPhase.oCapacity, sExMeOut(2:end));
            
            % Now we automatically create a fluidic processor for the
            % thermal heat transfer bound to the matter transferred by the
            % P2P
            try
                thermal.procs.conductors.fluidic(this.oStore.oContainer, this.sName, this);
                sCustomName = this.sName;
            % The operation can fail because the P2Ps are local within a
            % store and therefore can share common names acros multiple
            % stores (e.g. you can have 5 Stores, each containing a P2P
            % called "Absorber"). However, as F2Fs the thermal conductors
            % are added to the parent system, and therefore must be unique
            % for each system. Therefore we count a number up until we find
            % a name that is not yet taken for the fluidic processor
            catch oError 
                if contains(oError.message, 'already exists.')
                    bError = true;
                    iCounter = 2;
                    while bError == true
                        % now we just try the name until we find one that
                        % is not yet taken, increasing the counter each
                        % time the creation of the proc failed
                        try
                            thermal.procs.conductors.fluidic(this.oStore.oContainer, [this.sName, '_', num2str(iCounter)], this);
                            bError = false;
                        catch oError
                            if contains(oError.message, 'already exists.')
                                iCounter = iCounter + 1;
                            else
                                % If it is another error than what we area looking for,
                                % we do throw the error
                                this.throw('P2P', oError.message)
                            end
                        end
                        
                        % If we reach 1000 Iterations, throw an error as we
                        % are not likely to find a valid name anymore
                        if iCounter >= 1000
                            this.throw('P2P',[ 'could not find a valid name for the thermal fluidic conductor of P2P ', this.sName])
                        end
                    end
                    sCustomName = [this.sName, '_', num2str(iCounter)];
                else
                    % If it is another error than what we area looking for,
                    % we do throw the error
                    this.throw('P2P', oError.message)
                end
            end
            
            % Now we generically create the corresponding thermal branch
            % using the previously created fluidic conductor
            this.oThermalBranch = thermal.branch(this.oStore.oContainer, [this.oStore.sName,  sExMeIn] , {sCustomName}, [this.oStore.sName,  sExMeOut], sCustomName, this);
            
            this.coExmes = {this.oIn, this.oOut};
            
            %% Register the post tick update for the P2P at the timer
            this.hBindPostTickUpdate = this.oTimer.registerPostTick(@this.update, 'matter', 'P2Ps');
        end
    end
    
    
    
    %% Methods required for the matter handling
    methods
        function oExme = getInEXME(this)
            %% getInEXME
            % this function can be used to get the current exme from which
            % matter is entering the P2P. For negative flowrates that is
            % the side which is normally the out side, otherwise it is the
            % in side
            if this.fFlowRate < 0
                oExme = this.oOut;
            else
                oExme = this.oIn;
            end
        end
        
        function registerUpdate(this)
            %% registerUpdate
            % registers the post tick callback for the P2P with the timer.
            % Since this only sets a boolean to true it does not matter if
            % it is called multiple times within one tick and no further
            % checks are required
            this.hBindPostTickUpdate();
        end
        
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            %% bind
            % Overwrite the general bind function to be able and write
            % specific trigger flags
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % for setMatterProperties we set the Trigger to true which tells
            % us that we actually have to trigger this. Otherwise it is not
            % triggered saving calculation time
            if strcmp(sType, 'setMatterProperties')
                this.bTriggersetMatterPropertiesCallbackBound = true;
            end
        end
    end
    
    
    methods (Access = protected)
        % The update function is the only function allowed to use the
        % setMatterProperties function, since that function actually
        % changes the flowrates for the P2P, it must be ensured that the
        % massupdate is always performed before this, which is done by
        % never calling the update directly. Unfortunatly, since the child
        % classes must be allowed to override the update function, it is
        % possible to abuse this to directly call the update from other
        % functions of the child class. THIS SHOULD NOT BE DONE!
        function update(this, fFlowRate, arPartials)
            %% update
            % Calculate new flow rate in [kg/s]. This function itself does
            % not calculate anything but only sets the provided values. The
            % actual calculation must be implemented in the update function
            % of a child class of the P2P. The update is only executed in
            % the post tick, therefore it is a protected method. To
            % register an update of the P2P the registerUpdate function can
            % be used.
            %
            % Inputs:
            % fFlowRate:    total mass flowrate with which this p2p
            %               transfers mass
            % arPartials:   vector with the length (1, oMT.iSubstances)
            %               which contains the partial mass ratios for
            %               fFlowRate. Multiplying fFlowRate with
            %               arPartials results in a vector containing the
            %               partial mass flowrates for all substances in
            %               the P2P. Note that the flowrates cannot have
            %               two different directions within the same P2P!
            if nargin >= 3
                this.setMatterProperties(fFlowRate, arPartials);
            elseif nargin >= 2
                this.setMatterProperties(fFlowRate);
            else
                this.setMatterProperties();
            end
            
            this.fLastUpdate = this.oStore.oTimer.fTime;
        end
        
        function [ afInFlowrates, mrInPartials ] = getInFlows(this, sPhase)
            %% getInFlows
            %
            % Checks the specified side of the P2P for flowrates entering
            % the phase and provides information on the ingoing mass flows.
            %
            % Optional Inputs:
            % sPhase:   Can be 'in' or 'out' if nothing is defined the
            %           this.oIn phase will be checked
            % 
            % Outputs:
            % afInFlowrates:    Vector containing all ingoing mass flows of
            %                   the specified phase in kg/s
            % mrInPartials:     Matrix containing all partial mass ratios
            %                   for the in flow of the specified phase
            %
            % Note that by multiplying afInFlowRates and mrInPartials the
            % partial mass flowrates for each individual inflowrate can be
            % calculated. If instead you require one vector with the sume
            % of all partial mass flowrates per substance you can use:
            % afPartialFlowRates = sum(afInFlowrates .* mrInPartials,1);
            % to calculate this.
            % Also note that manipulator flowrates are not considered by
            % the values returned with this function, as a general
            % definition on how manips should be handled is not possible!
            
            if nargin < 2, sPhase = 'in'; end
            
            if strcmp(sPhase, 'in'); oPhase = this.oIn.oPhase; else; this.oOut.oPhase; end
            
            % Initializing temporary matrix and array to save the per-exme
            % data. 
            mrInPartials  = zeros(oPhase.iProcsEXME, this.oMT.iSubstances);
            afInFlowrates = zeros(oPhase.iProcsEXME, 1);
            
            % Creating an array to log which of the flows are not in-flows
            abOutFlows = true(oPhase.iProcsEXME, 1);
            
            % Get flow rates and partials from EXMEs
            for iI = 1:oPhase.iProcsEXME
                [ afFlowRates, mrFlowPartials, ~ ] = oPhase.coProcsEXME{iI}.getFlowData();
                
                % The afFlowRates is a row vector containing the flow rate
                % at each flow, negative being an extraction!
                % mrFlowPartials is matrix, each row has partial ratios for
                % a flow, cols are the different substances.
                
                abInf = (afFlowRates > 0);
                
                if any(abInf)
                    mrInPartials(iI,:) = mrFlowPartials(abInf, :);
                    afInFlowrates(iI)  = afFlowRates(abInf);
                    abOutFlows(iI)     = false;
                end
            end
            
            % Now we delete all of the rows in the mrInPartials matrix
            % that belong to out-flows.
            if any(abOutFlows)
                mrInPartials(abOutFlows,:)  = [];
                afInFlowrates(abOutFlows,:) = [];
            end
        end
        
        % The set matter properties function should only be called by the
        % update function of this class. However, since it has to override
        % the setMatterProperties function from its superclass matter.flow
        % the access rights cannot be set to private. Usually the p2p
        % updates are called  by the phase massupdates, therefore making it
        % unnecessary for the P2Ps to call the massupdates. However, in
        % some use cases (e.g. the manual P2P) it is not the phase
        % massupdate which triggers recalculations for the P2Ps. To prevent
        % these cases from accidentially performing invalid operations,
        % this access restriction is necessary.
        function setMatterProperties(this, fFlowRate, arPartialMass, fTemperature, fPressure)
            %% setMatterProperties
            % is the function used by the update function to actually set
            % the new partial mass flow rates of the P2P
            %
            % Optional Inputs:
            % fFlowRate:     The current total flowrate of the p2p in kg/s.
            %                Total means it must be the sum of all partial
            %                mass flow rates
            % arPartialMass: Vector containing the partial mass flow ratios
            %                to convert fFlowRate into a vector with
            %                partial mass flows by using fFlowRate *
            %                arPartialMass
            % fTemperature:  The temperature for the flow of the P2P mass
            %                transfer
            % fPressure:     The pressure for the flow of the P2P mass
            %                transfer
            %
            % If no value is provided for any of the inputs the value of
            % the ingoing Exme is used based on the fFlowRate. If fFlowRate
            % is not provided the current property fFlowRate is used
            
            
            if (nargin < 2) || isempty(fFlowRate), fFlowRate = this.fFlowRate; end
            
            % We're a p2p, so we're directly connected to EXMEs
            if fFlowRate >= 0
                oExme = this.oIn;
            else
                oExme = this.oOut;
            end
            
            
            if nargin < 3 || isempty(arPartialMass)
                arPartialMass = oExme.oPhase.arPartialMass;
            end
            
            
            % Get matter properties from in exme. 
            [ fExMePressure, fExMeTemperature ] = oExme.getExMeProperties();
            
            % Check temp and pressure. First temp ... cause that might
            % change in a p2p ... pressure not really.
            if (nargin < 4) || isempty(fTemperature), fTemperature = fExMeTemperature; end
            if (nargin < 5) || isempty(fPressure), fPressure = fExMePressure; end
                
            % Connected phases have to do a massupdate before we set the
            % new flow rate - so the mass for the LAST time step, with the
            % old flow rate, is actually moved from tank to tank.
            this.oIn.oPhase.registerMassupdate();
            this.oOut.oPhase.registerMassupdate();
            
            setMatterProperties@matter.flow(this, fFlowRate, arPartialMass, fTemperature, fPressure);
            
            if this.bTriggersetMatterPropertiesCallbackBound
                this.trigger('setMatterProperties');
            end
        end
    end
end