classdef component < base
    %COMPONENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Name of component.
        % @type string
        sName;
        
        oCircuit;
        
        toPorts = struct();
        abPorts = [false false];
        
        aoFlows = electrical.flow.empty();
        
        % Timer
        % @type object
        oTimer;
        
        oBranch; 
        
        % Sealed?
        bSealed = false;
    end
    
    methods
        function this = component(oCircuit, sName)
            this.oCircuit = oCircuit;
            this.sName = sName;
            
            this.oCircuit.addComponent(this);
        end
        
        function this = addFlow(this, oFlow, sPort)
            % Adds a flow. Automatically first sets left, then right port.
            % Can only be disconnected by deleting the flow object.
            
            if ~isa(oFlow, 'electrical.flow')
                this.throw('addFlow', 'The provided flow object has to be a or derive from electrical.flow!');
            
            elseif any(this.aoFlows == oFlow)
                this.throw('addFlow', 'The provided flow object is already registered!');
            end
            
            
            
            % Find empty port (first zero in abPorts array) - left or right
            if nargin < 3 || isempty(sPort)
                iIdx = find(~this.abPorts, 1);
            else
                iIdx = 0;
            end
            
            % All ports in use (iIdx empty)?
            if isempty(iIdx)
                this.throw('addFlow', ['The component ''',this.sName,...
                           ''' is already in use by another branch.\n', ...
                           'Please check the definition of the following branch: ',...
                           oFlow.oBranch.sName]); 
            end
            
            if iIdx == 1
                this.toPorts.Left = oFlow;
            elseif iIdx == 2
                this.toPorts.Right = oFlow;
            elseif iIdx == 0
                this.toPorts.(sPort) = oFlow;
                switch sPort
                    case 'Left'
                        iIdx = 1;
                    case 'Right'
                        iIdx = 2;
                    otherwise
                        this.throw('addFlow','The port name you have provided (%s) is illegal. The port name must be either ''Left'' or ''Right''.', sPort);
                end
            end
            
            this.abPorts(iIdx) = true;
            this.aoFlows(iIdx) = oFlow;
            
            % Call addComponent on the flow, provide function handle to
            % enable removing, even though that
            % method is protected, it can be called from outside
            % through that! Wrap in anonymous function so no way to
            % remove another flow.
            oFlow.addComponent(this, @() this.removeFlow(oFlow));
            
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
            
            this.aoFlows(iIdx) = []; % Seems like deconstruction of all objs, oMT invalid!
            
        end
    end
    
end

