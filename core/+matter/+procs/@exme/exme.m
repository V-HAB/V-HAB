classdef exme < base
    % EXME extract/merge processor
    % The ExMe is the basic port within V-HAB to remove or add mass to a
    % phase. It is used by both branches and P2Ps to connect two different
    % phases. ExMes can also be created automatically by providing a phase
    % object as reference during branch definition.
    
    properties (SetAccess = private, GetAccess = public)
        % Phase this EXME belongs to
        oPhase;
        
        % Matter table
        oMT;
        
        % Timer
        oTimer;
        
        % Name of the ExMe
        sName;
        
        % Connected matter flow
        oFlow;
        
        % Boolean flag to check if the ExMe has a flow or if it is
        % unconnected
        bHasFlow = false;
        
        % Boolean flag to check if this exme is used for a P2P, which
        % requires some adjustments to handling in certain cases
        bFlowIsAProcP2P = false;
        
        % integer that is either 1 or -1. This multiplied with the flowrate
        % of the asscociated flow from the oFlow property results in the
        % correct mass change for the phase to which the exme is connected
        % (stored in oPhase property)
        iSign;

    end
    
    properties (SetAccess = private, GetAccess = private)
        % To allow reconnection of the exme we create a property to store
        % the new phase until the post tick reconnect operation is
        % performed. The property is set to all private, as it should not
        % be seen from outside the exme!
        oNewPhase;
        
        % Function handle to the bindPostTick function of the timer,
        % telling the corresponding post tick to be executed
        hReconnectExme;
    end
    
    
    methods
        function this = exme(oPhase, sName)
            %% exme class constructor
            % Constructor for the exme matter processor class. 
            % Used to extract / merge matter from / into phases. Note that
            % the processor itself does not handle the merging, it is just
            % an interface providing the necessary information to handle
            % the corresponding calculation within the matter.phase class
            %
            % Required Inputs:
            % oPhase:   the phase the exme is attached to
            % sName:    the name of the processor
            
            % First we check to see if there is already an ExMe with this
            % name in the store. If so, we throw an error. 
            if any(strcmp(sName, oPhase.oStore.csExMeNames))
                this.throw('exme:constructor','There is already an ExMe named ''%s'' in store ''%s''. Please make all ExMe Names in this store unique.', sName, oPhase.oStore.sName);
            end
            
            this.sName  = sName;
            this.oMT    = oPhase.oMT;
            this.oTimer = oPhase.oTimer;
            
            oPhase.addProcEXME(this);
            
            this.oPhase = oPhase;
            
            % For rebinding the exme, we create a post tick call back which
            % is performed after all phase operations are performed. That
            % ensures that the phase still has a valid exme etc when it is
            % calculated but that the exme is changed before the solvers
            % are updated
            this.hReconnectExme = this.oTimer.registerPostTick(@this.reconnectExMePostTick,            'matter',        'post_phase_update');
        end
        
        
        function addFlow(this, oFlow)
            %% ExMe addFlow
            % INTERNAL METHOD! Called from the matter.procs.p2p class
            % constructor or the base.branch handleSide function!
            %
            % adds a flow to this exme and sets the corresponding
            % properties (bHasFlow, bFlowIsAProcP2P, iSign) according to
            % the flow which is connected to this exme
            %
            % Required inputs:
            % oFlow, the matter flow object which should be connected with
            % this exme
            
            if this.oPhase.oStore.bSealed
                this.throw('addFlow', 'The store to which this processors phase belongs is sealed, so no ports can be added any more.');
            
            elseif ~isempty(this.oFlow)
                this.throw('addFlow', 'There is already a flow connected to this exme! You have to create another one.');
            
            elseif ~isa(oFlow, 'matter.flow')
                this.throw('addFlow', 'The provided flow object is not a matter.flow!');
            
            elseif any(this.oFlow == oFlow)
                this.throw('addFlow', 'The provided flow object is already registered!');
            end
            
            this.oFlow = oFlow;
            
            this.bHasFlow = true;
            this.bFlowIsAProcP2P = isa(this.oFlow, 'matter.procs.p2ps.flow') || isa(this.oFlow, 'matter.procs.p2ps.stationary');
            
            try
                this.iSign = oFlow.addProc(this, @() this.removeFlow(oFlow));
            catch oErr
                % Reset back to default MF
                this.oFlow = this.oMT.oFlowZero;
                
                rethrow(oErr);
            end
            
        end
        
        function reconnectExMe(this, oNewPhase)
            %% reconnectExMe
            % This function can be used to change the phase to which the
            % exme is connect, therefore also changing the phase to which
            % the corresponding branch is connected. This function does not
            % instantly change the connection, but rather binds the
            % corresponding operation into the correct post tick location
            % to ensure a consistent simulation
            % Inputs:
            % oNewPhase: The phase object to which the exme should be
            %            connected afterwards
            
            % If someone reconnects the exme to the current phase nothing
            % has to be changed (note without this check it would be
            % possible for the exme to belong to no phase at all
            if this.oPhase == oNewPhase
                return
            end
            
            % Bin the new phase to the property, will be set in post tick
            % function reconnectExMePostTick
            this.oNewPhase = oNewPhase;
            
            % tells the post tick to be executed
            this.hReconnectExme();
            
            % Reconnecting the matter exme, also requires us to reconnect
            % the thermal exme!
            if this.iSign == 1
                iExme = 2;
            else
                iExme = 1;
            end
            this.oFlow.oBranch.oThermalBranch.coExmes{iExme}.reconnectExMe(oNewPhase.oCapacity, true);
        end
        
        function [ fFlowRate, arPartials, afProperties, arCompoundMass ] = getFlowData(this, fFlowRate)
            %% ExMe getFlowData
            % This function can be called to receive information about the
            % exme flow properties. 
            %
            % Outputs:
            % fFlowRate:      current mass flow rate in kg/s with respect to
            %                 the connected phase (negative values mean the
            %                 mass of this.oPhase is beeing reduced)
            % arPartials:     A vector with the length (1,oMT.iSubstances)
            %                 with the partial mass ratio of each substance in the current
            %                 fFlowRate. The sum of this vector is 1 and
            %                 multipliying arPartials with fFlowRate yields
            %                 the partial mass flow rates for each substance
            % afProperties:   A vector with two entries, the flow temperature
            %                 and the flow specific heat capacity
            % arCompoundMass: An array containing the compound masses of
            %                 the flow or attached phase
            
            % The flow rate property of the flow is unsigned, so we have to
            % add it again by multiplying with the iSign property of this
            % exme. 
            if nargin >= 2 && ~isempty(fFlowRate)
                fFlowRate  =  fFlowRate * this.iSign;
            else
                fFlowRate  =  this.oFlow.fFlowRate * this.iSign;
            end
                        
            if this.bFlowIsAProcP2P
                % This exme is connected to a P2P processor, so we can get
                % the properties from the connected flow.
                arPartials   = this.oFlow.arPartialMass;
                afProperties = [ this.oFlow.fTemperature this.oFlow.fSpecificHeatCapacity ];
                arCompoundMass = this.oFlow.arCompoundMass;
            else
                
                if fFlowRate > 0
                    % The flow rate is larger than zero, this means we use
                    % the properties of the incoming flow. We have to get
                    % it from the other side only in case the phase from
                    % which the mass is taken is a flow phase. For that
                    % case however, we have to check which exme is the
                    % inexme of the branch. However, if we have to do this
                    % anyway, we can do it for all cases
                    if this.oFlow.fFlowRate >= 0
                        arPartials   = this.oFlow.oBranch.coExmes{1}.oPhase.arPartialMass;
                    else
                        arPartials   = this.oFlow.oBranch.coExmes{2}.oPhase.arPartialMass;
                    end
                    afProperties = [ this.oFlow.fTemperature this.oFlow.fSpecificHeatCapacity ];
                    arCompoundMass = this.oFlow.arCompoundMass;
                    
                else 
                    % The flow rate is either zero or negative, which means
                    % matter is flowing out of the phase. In both cases we
                    % have to use the matter properties of the connected
                    % phase.
                    arPartials   = this.oPhase.arPartialMass;
                    arCompoundMass = this.oPhase.arCompoundMass;
                    
                    % If this is called from the seal() method of the
                    % store, the phase's capacity has not yet been set. So
                    % we catch that error here and calculated the phase's
                    % specific heat capacity directly. 
                    try
                        afProperties = [ this.oPhase.fTemperature this.oPhase.oCapacity.fSpecificHeatCapacity ];
                    catch oError
                        if isempty(this.oPhase.oCapacity)
                            afProperties = [ this.oPhase.fTemperature this.oMT.calculateSpecificHeatCapacity(this.oPhase)];
                        else
                            rethrow(oError);
                        end
                    end
                end
            end
        end
    end
    
    %% ABSTRACT METHODS - the concrete exmes have to define those!
    methods (Abstract = true)
        % Method returns absolute values of pressure and temperature of the
        % extracted matter
        % For e.g. a liquid phase, the pressure would depend on gravity,
        % filling level and position of the port, which could be
        % implemented by a derived version of the EXME. See the according
        % matter.procs.exme.[phase type] for that.
        getExMeProperties(~);
    end
    
    
    %% Internal methdos for handling the flows
    % The removeFlow is private - only accessible through anonymous handle
    methods (Access = private)
        function removeFlow(this, ~ )
            %% ExMe removeFlow
            % This function can be used to remove the flow from this ExMe
            % which is necessary to then reconnect the ExMe with another
            % flow!
            % Here we need the tilde as an input parameter, because the
            % removeFlow method for the matter table and the f2f processor
            % need to specify which flow is to be removed. Since exmes only
            % have one input parameter, this is not necessary here. 
            this.oFlow = matter.flow.empty();
            this.iSign = 0;
        end
        
        function reconnectExMePostTick(this)
            %% reconnectExMePostTick
            % This function is executed in the post tick between the phase
            % massupdated (which must be performed before the exme is
            % changed) and the branch updates (which must be performed
            % therefafter).
            
            % we check if reconnecting the ExMe would moved the
            % branch from one system to another:
            
            % the first condition for this is, that the changed exme is
            % the left exme of the branch, otherwise the system did not
            % change! (as the branch is only located in the subsystem)
            if this.oFlow.oBranch.coExmes{1} == this
                % The second check is if the two phases are not located in
                % the same system.
                if this.oNewPhase.oStore.oContainer ~= this.oPhase.oStore.oContainer
                    % If both conditions are met, the left exme and
                    % therefore the branch were moved to a different
                    % system. In this case we have to adjust the toBranches
                    % and aoBranches properties of these systems
                    % accordingly (check for thermal performed in thermal
                    % domain)
                    error(['currently it is not possible to change the left hand exme to a phase which is located in a different system! Occured while reconnecting exme', this.sName])
                    
                end
            end
            % Store the current phase as reference
            oOldPhase = this.oPhase;
            
            this.oPhase = this.oNewPhase;
            % Now we have to remove/add the exme to the old/new phase
            oOldPhase.removeExMe(this);
            this.oPhase.addExMe(this);
            
            % to prevent confusion, empty the new phase property
            this.oNewPhase = [];
            
            if isa(this.oFlow.oBranch.oHandler, 'solver.matter_multibranch.iterative.branch')
                % Since the multi branch solver stores the UUIDs of the
                % phases to create the network, we have to recreate that
                % network, if an exme with a multibranch solver is
                % reconnected.
                this.oFlow.oBranch.oHandler.initialize();
            end
            
        end
    end
    
    methods (Access = {?matter.container})
        function disconnectFlow(this)
            %DISCONNECTFLOW Deletes the reference to the connected flow
            %   This is necessary when the simulation object is saved to a
            %   MAT file. In large and/or networked systems the number of
            %   consecutive, unique objects that are referenced in a row
            %   cannot be larger than 500. In order to break these chains,
            %   we delete the link to the branch on all matter ExMes. This
            %   link is the oFlow property. Since the branch object retains
            %   a reference to this flow and the ExMe it is connected to,
            %   we can easily reconnect it on load.
            this.oFlow = [];
        end
        
        function reconnectFlow(this, oFlow)
            %RECONNECTFLOW Restores the reference to the connected flow
            %   Reverses the action from disconnectFlow().
            this.oFlow = oFlow;
        end
    end
end

