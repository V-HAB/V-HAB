classdef f2f < base & matlab.mixin.Heterogeneous
    %F2F flow2flow processors
    %   Manipulate a matter flow/stream. Can have two ports with one
    %   flow connected to each port. Provides methods for managing the
    %   connected flows and their flow rates
    %
    %TODO
    %   - diameters for each port -> could do stuff like increasing the
    %     pressure or decreasing the velocity. Or match of flows can be
    %     connected, e.g. some adapter/geometry definition?
    %   - only support two ports here, and for splitter-comps special base
    %     class anyway - needs to behave phase/store-like ... DONE
    %   - THROW OUT the afFR stuff? If we use createBranch etc, we know for
    %     sure that the procs where connected in the 'right' direction
    
    
    properties (SetAccess = private, GetAccess = private)
        % Struct with function handles returned by the flow that allow
        % manipulation of the matter properties
        % GetAccess is private - can only be accessed through protected
        % method, which ensures that only properties of OUTFLOWING matter
        % flows can be manipulated (manipulation methods are sealed!)!
        pthFlow;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Port names. Indices are accordingly used for aiSign / aoFlows
        csPorts = { 'left', 'right' };
        
        % Number of ports
        iPorts = 2;
        
        % Connected matter flows (one for each port possible), indexed
        % according to port name in csPorts
        aoFlows = matter.flow.empty();
        
        % Sign. Depending on the "side" of the flow this processor is
        % connected to, the flow rate set for that flow is either out or in
        % when positive. This array here is accordingly filled with 1 / -1.
        aiSign = [ 0 0 ];
        
        % Matter table
        oMT;
        
        % Name of processor.
        sName;
        
        %TODO Need something like type, as for phases? Define what types of
        %     phases can be used with this processor?
        
        
        % Reference to the branch object
        oBranch;
        
        % Sealed?
        bSealed = false;
    end
    
    
    
    methods
        function this = f2f(oMT, sName)
            % Constructor for the f2f matter processor class. If no csPorts
            % are provided, two default ones (left, right) are created.
            
            % Matter table and name
            this.oMT   = oMT;
            this.sName = sName;
            
            % Preset the flow array with a default, zero FR matter flow
            for iI = 1:this.iPorts
                this.aoFlows(iI) = matter.flow(this.oMT, []); 
            end
            
            % Create map for the func handles
            this.pthFlow = containers.Map('KeyType', 'single', 'ValueType', 'any');
        end
        
        
        function seal(this, oBranch)
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            this.oBranch = oBranch;
            this.bSealed = true;
        end
    end
    
    
    %% Sealed to ensure flow handling, e.g. no setting of matter flow
    % properties if inflow
    methods (Sealed = true)
        
        function this = addFlow(this, oFlow, iIdx)
            % Adds a flow, sets stuff on aiSign. Automatically first sets
            % left, then right port. Can only be disconnected by deleting
            % the flow object.
            
            if ~isa(oFlow, 'matter.flow')
                this.throw('addFlow', 'The provided flow obj has to be a or derive from matter.flow!');
            
            elseif any(this.aoFlows == oFlow)
                this.throw('addFlow', 'The provided flow obj is already registered!');
            end
            
            % Find empty port (first zero in aiSign array) - left or right
            if nargin < 3 || isempty(iIdx)
                iIdx = find(~this.aiSign, 1);
            elseif this.aiSign(iIdx) ~= 0
                this.throw('addFlow', 'Port already connected');
            end
            
            % All ports in use (iIdx empty)?
            if isempty(iIdx), this.throw('addFlow', 'No free port!'); end;
            
            % Set the flow obj - when we call the addProc of the flow
            % object, it checks if it exists on aoFlows!
            this.aoFlows(iIdx) = oFlow;
            
            % Call addProc on the flow, provide function handle to
            % enable removing, returns the sign for the flow rate, throws
            % an error if something went wrong.
            try
                % Provide function handle to removeFlow - even though that
                % method is protected, it can be called from outside
                % through that! Wrap in anonymous function so no way to
                % remove another flow.
                [ iSign, thFlow ] = oFlow.addProc(this, @() this.removeFlow(oFlow));
            
            catch oErr
                % Reset back to default MF
                this.aoFlows(iIdx) = this.oMT.oFlowZero;
                
                rethrow(oErr);
            end
            
            % Set the other stuff
            this.aiSign(iIdx)  = iSign;
            %this.pthFlow(iIdx) = thFlow;
        end
    end
    
    %% Methods required for the matter handling
    methods
        function exec(this, fTime)
            % Called from subsystem to update the internal state of the
            % processor, e.g. change efficiencies etc
        end
        
        function update(this, ~)
            % Possibly needed for manual solver, e.g. .update called on
            % phase/exme, which in turn call the .update on the next flow,
            % which call it on their next f2f processor which call it on
            % the next flows etc?
        end
    end
    
    
    %% Internal methdos for handling the flows/flow rates
    % The removeFlow is private - only accessible through anonymous handle
    methods (Access = private)
        function removeFlow(this, oFlow)
            iIdx = find(this.aoFlows == oFlow, 1);
            
            if isempty(iIdx)
                this.throw('removeFlow', 'Flow doesn''t exist');
            end
            
            if isvalid(this.oMT), this.aoFlows(iIdx) = this.oMT.oFlowZero;
            else                  this.aoFlows(iIdx) = []; % Seems like deconstruction of all objs, oMT invalid!
            end
            
            this.aiSign(iIdx)  = 0;
            %this.pthFlow(iIdx) = struct();
        end
    end
    
    % Protected methods - get flow rates, set matter properties
    %CHECK Also sealed, or should it be possible to overload?
    methods (Access = protected, Sealed = true)
        function afFRs = getFRs(this)
            % Get flow rate of all ports, adjusted with the according sign
            % to ensure that negative FR always means an outflow of mass!
            
            afFRs = [ this.aoFlows.fFlowRate ] .* this.aiSign;
        end
        
        
        function [ oFlowIn oFlowOut ] = getFlows(this, fFlowRate)
            afFRs = this.getFRs();
            
            
            if nargin > 1
                if (fFlowRate >= 0)
                    oFlowIn  = this.aoFlows(1);
                    oFlowOut = this.aoFlows(2);
                else
                    oFlowIn  = this.aoFlows(2);
                    oFlowOut = this.aoFlows(1);
                end
                
                return;
            end
            
            
            if ~any(afFRs)
                this.throw('get', 'Can''t get when flow rate is zero!');

            elseif (afFRs(1) * afFRs(2)) > 0
                this.throw('set', 'Both flows are in or out, need one in, one out!');

            else
                iIdx = find(afFRs > 0, 1);

                if isempty(iIdx), this.throw('set', 'No in flow found!');
                else
                    oFlowIn = this.aoFlows(iIdx);
                end
                
                
                
                iIdx = find(afFRs < 0, 1);

                if isempty(iIdx), this.throw('set', 'No out flow found!');
                else
                    oFlowOut = this.aoFlows(iIdx);
                end
            end
        end
        
        
        function oFlow = get(this, fFlowRate)
            % Gets the object of the INFLOWING matter flow, depending on
            % the provided flowrate (to be called from calcDeltaP). If no
            % flow rate provided, taken from flows ...
            %
            
            % See this.set for comments.
            if nargin < 2
                afFRs = this.getFRs();
                
                if ~any(afFRs)
                    this.throw('get', 'Can''t get when flow rate is zero!');
                
                elseif (afFRs(1) * afFRs(2)) > 0
                    this.throw('set', 'Both flows are in or out, need one in, one out!');

                else
                    iIdx = find(afFRs > 0, 1);

                    if isempty(iIdx), this.throw('set', 'No flow to read from found!');
                    else
                        oFlow = this.aoFlows(iIdx);
                    end
                end
                
            else
                if fFlowRate == 0, this.throw('get', 'Can''t get when flow rate is zero!'); end;
                
                % Dirty (?) ... bool true = 1, false = 0 -> index 2 / 1
                oFlow = this.aoFlows((fFlowRate > 0) + 1);
            end
        end
    end
end

