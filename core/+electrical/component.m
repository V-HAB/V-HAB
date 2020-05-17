classdef (Abstract) component < base
    %COMPONENT Describes an electrical component
    %   This abstract class is the foundation for all electrical components
    %   in V-HAB, e.g. resistors, capacitors, etc. 
    %   In the current version, the class assumes that the derived
    %   component will have only two ports. If the derived component must
    %   have more than two ports, e.g. a transistor, the addFlow() method
    %   must be overloaded.
    
    properties (SetAccess = protected, GetAccess = public)
        % Name of component.
        sName;
        
        % Reference to circuit object this component is contained in
        oCircuit;
        
        % A struct containing references to all ports of this component
        toPorts = struct();
        
        abPorts = [false false];
        
        % An array containing references to all flows associated with this
        % component
        aoFlows;
        
        % Reference to the timer object
        oTimer;
        
        % Reference to a branch object this component is contained in
        oBranch; 
        
        % Indicator if this component is sealed or not
        bSealed = false;
    end
    
    methods
        function this = component(oCircuit, sName)
            % Setting the reference to the parent circuit
            this.oCircuit = oCircuit;
            
            % Setting the name property
            this.sName = sName;
            
            % Adding ourselves to the parent circuit
            this.oCircuit.addComponent(this);
            
            this.aoFlows = electrical.flow.empty();
        end
        
        function this = addFlow(this, oFlow, sPort)
            % Adds a flow. Automatically first sets left, then right port.
            % Can only be disconnected by deleting the flow object.
            
            % Checking if the provided object is actually an electrical
            % flow object
            if ~isa(oFlow, 'electrical.flow')
                this.throw('addFlow', 'The provided flow object has to be a or derive from electrical.flow!');
            
            % Checking if we already added this object
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
            
            % Saving the reference to the flow object into the toPorts
            % property under the appropriate name
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
            
            % Saving the information about the flow object to the
            % appropriate properties.
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
    methods (Access = private)
        % The removeFlow() method is private - only accessible through
        % anonymous handle
        function removeFlow(this, oFlow)
            %REMOVEFLOW Removes the provided flow object from this component
            
            % Trying to find the flow object by comparing it to all members
            % of the aoFlows array.
            iIdx = find(this.aoFlows == oFlow, 1);
            
            % If we didn't find anything the provided flow object is not
            % connected to this component
            if isempty(iIdx)
                this.throw('removeFlow', 'The provided flow object is not connected to %s', this.sName);
            end
            
            % Actually deleting the flow object reference
            this.aoFlows(iIdx) = [];
            
        end
    end
    
    methods (Abstract)
        % Methods that child classes MUST implement
        update(this)
    end
    
end

