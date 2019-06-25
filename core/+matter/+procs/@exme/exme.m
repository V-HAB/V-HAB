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
        oFlow = matter.flow.empty();
        
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
            
            this.sName  = sName;
            this.oMT    = oPhase.oMT;
            this.oTimer = oPhase.oTimer;
            
            oPhase.addProcEXME(this);
            
            this.oPhase = oPhase;
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
        
        
        
        function [ fFlowRate, arPartials, afProperties ] = getFlowData(this, fFlowRate)
            %% ExMe getFlowData
            % This function can be called to receive information about the
            % exme flow properties. 
            %
            % Outputs:
            % fFlowRate:    current mass flow rate in kg/s with respect to
            %               the connected phase (negative values mean the
            %               mass of this.oPhase is beeing reduced)
            % arPartials:   A vector with the length (1,oMT.iSubstances)
            %               with the partial mass ratio of each substance in the current
            %               fFlowRate. The sum of this vector is 1 and
            %               multipliying arPartials with fFlowRate yields
            %               the partial mass flow rates for each substance
            % afProperties: A vector with two entries, the flow temperature
            %               and the flow specific heat capacity
            
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
            else
                
                if fFlowRate > 0
                    % The flow rate is larger than zero, this means we use
                    % the properties of the incoming flow.
                    %CHECK do we need to get that from other side, in
                    %      case that changed? Shouldn't need that, when
                    %      mass is extracted on the other side, the
                    %      arPartialMass from that phase is used - but
                    %      if that get's updated, fr recalc is called
                    %      on all branches which would set the new
                    %      arPartials on all flows ... right?
                    
                    arPartials   = this.oFlow.arPartialMass;
                    afProperties = [ this.oFlow.fTemperature this.oFlow.fSpecificHeatCapacity ];
                    
                else 
                    % The flow rate is either zero or negative, which means
                    % matter is flowing out of the phase. In both cases we
                    % have to use the matter properties of the connected
                    % phase.
                    arPartials   = this.oPhase.arPartialMass;
                    afProperties = [ this.oPhase.fTemperature this.oPhase.oCapacity.fSpecificHeatCapacity ];
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
    end
end

