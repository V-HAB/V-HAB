classdef circuit < base & event.source
    %CIRCUIT Defines an electrical circuit 
    %   The model of an electrical circuit consists of store, components,
    %   branches and nodes. These will all be child objects of instances of
    %   this class. 
    %   A circuit can have only one voltage or current source, which is
    %   stored as a reference in the oSource property of this class. 
    
    properties
        % Reference to a voltage or current source. 
        oSource = [];
        
        % Reference to the parent electrical system
        oParent;
        
        % Name of this circuit
        sName;
        
        % An array of all electrical.store objects in this circuit
        aoStores = [];
        
        % A struct of all electrical.store objects in this circuit
        toStores = struct();
        
        % Number of stores in this circuit
        iStores;
        
        % An array of all node objects in this circuit
        aoNodes;
        
        % A struct of all node objects in this circuit
        toNodes = struct();
        
        % Number of nodes in this circuit
        iNodes;
        
        % An array of all components in this circuit
        aoComponents = [];
        
        % A struct of all components in this circuit
        toComponents = struct();
        
        % An array of all branches in this circuit
        aoBranches;
        
        % A struct of all branches in this circuit
        toBranches = struct();
        
        % Number of branches in this circuit
        iBranches;
        
        % Indicator if this circuit is sealed or not
        bSealed;
        
        % Reference to the timer object
        oTimer;
    end
    
    methods
        
        function this = circuit(oParent, sName)
            % Setting the parent object reference
            this.oParent = oParent;
            
            % Setting the circuit name
            this.sName = sName;
            
            % Setting the reference to the timer object
            this.oTimer = this.oParent.oRoot.oTimer;
            
            % Adding ourselves to the parent object. 
            this.oParent.addCircuit(this);
            
            this.aoNodes = electrical.node.empty();
            
            this.aoBranches = electrical.branch.empty();
                        
        end
        
        function addStore(this, oStore)
            %ADDSTORE Adds the provided store to the circuit
            % Might be overloaded by derived classes to e.g. implement some
            % dynamic handling of store capacities or other stuff.
            
            % Checking if this circuit is already sealed, throw error if so
            if this.bSealed
                this.throw('addStore', 'The container is sealed, so no stores can be added any more.');
            end
            
            % Making sure we're adding an electrical store object
            if ~isa(oStore, 'electrical.store')
                this.throw('addStore', 'Provided object is not a electrical.store!');
            
            % Making sure we don't have one of this name already
            elseif isfield(this.toStores, oStore.sName)
                this.throw('addStore', 'Store with name %s already exists!', oStore.sName);
                
            % Making sure we don't add more than one voltage source
            elseif isa(oStore, 'electrical.stores.constantVoltageSource')
               if isempty(this.oSource)
                   this.oSource = oStore;
               else
                   this.throw('addStore', 'This circuit (%s) already has a source. A circuit can only have one source.', this.sName);
               end
            end
            
            % Adding the store to the toStores property
            this.toStores.(oStore.sName) = oStore;
            
            % Adding the store to the aoStores property. We need to do some
            % more checking here in comparison to the addNode() and
            % addBranch() methods, because the aoStores property is
            % initialized empty, while the aoNodes and aoBranches
            % properties are initilized with empty objects (e.g.
            % electrical.branch.empty()). This is not possible for the
            % stores, because the store class is abstract and cannot be
            % instantiated on it's own. 
            if isempty(this.aoStores)
                this.aoStores = oStore;
            else
                this.aoStores(end + 1) = oStore;
            end
            
        end
        
        function addNode(this, oNode)
            %ADDNODE Adds the provided node to the circuit
            
            % Making sure we're not sealed.
            if this.bSealed
                this.throw('addNode', 'The container is sealed, so no nodes can be added any more.');
            end
            
            % Checking if we're adding an electrical node, throw an error
            % if not.
            if ~isa(oNode, 'electrical.node')
                this.throw('addNode', 'Provided object is not a electrical.node!');
            
            % Making sure there's no other node with the same name
            elseif isfield(this.toNodes, oNode.sName)
                this.throw('addNode', 'Node with name %s already exists!', oNode.sName);
            end
            
            % Adding the node to the toNodes property
            this.toNodes.(oNode.sName) = oNode;
            
            % Adding the node to the aoNodes property
            this.aoNodes(end + 1) = oNode;
            
        end
        
        function this = addBranch(this, oBranch)
            %ADDBRANCH Adds the provided branch to the circuit
            
            % Making sure we're not sealed.
            if this.bSealed
                this.throw('addBranch', 'Can''t create branches any more, sealed.');
                
            % Checking if we're adding an electrical branch, throw an error
            % if not.
            elseif ~isa(oBranch, 'electrical.branch')
                this.throw('addBranch', 'Provided branch is not a and does not inherit from matter.branch');
                
            % Making sure there's no other branch with the same name    
            elseif isfield(this.toBranches, oBranch.sName)
                this.throw('addBranch', 'Branch with name "%s" alreay exists!', oBranch.sName);
                
            end
            
            % Adding the branch to the aoBranches property
            this.aoBranches(end + 1) = oBranch;
           
            % Adding the branch to the toBranches property. We need to
            % first check, if the user provided a custom name
            if ~isempty(oBranch.sCustomName)
                % There is a custom name, so we need to check if a branch
                % with that custom name already exists.
                if isfield(this.toBranches, oBranch.sCustomName)
                    error('A branch with this custom name already exists')
                else
                    this.toBranches.(oBranch.sCustomName) = oBranch;
                end
            else
                this.toBranches.(oBranch.sName) = oBranch;
            end
        end
        
        function addComponent(this, oComponent)
            %ADDCOMPONENT Adds the provided component to the circuit.
            
            % Making sure we're not sealed.
            if this.bSealed
                this.throw('addComponent', 'The circuit is sealed, so no components can be added any more.');
            end
            
            % Checking if we're adding an electrical component, throw an
            % error if not.
            if ~isa(oComponent, 'electrical.component')
                this.throw('addStore', 'Provided object is not a electrical.component!');
                
            % Making sure there's no other component with the same name    
            elseif isfield(this.toComponents, oComponent.sName)
                this.throw('addStore', 'Component with name %s already exists!', oComponent.sName);
            
            end
            
            % Adding the component to the aoComponents property
            this.toComponents.(oComponent.sName) = oComponent;
            
            % Adding the component to the aoComponents property. We need to
            % do some more checking here in comparison to the addNode() and
            % addBranch() methods, because the aoComponents property is
            % initialized empty, while the aoNodes and aoBranches
            % properties are initilized with empty objects (e.g.
            % electrical.branch.empty()). This is not possible for the
            % components, because the component class is abstract and
            % cannot be instantiated on it's own.
            if isempty(this.aoComponents)
                this.aoComponents = oComponent;
            else
                this.aoComponents(end + 1) = oComponent;
            end
            
        end
        
        function seal(this)
            %SEAL Seals this circuit so nothing can be changed later on
            
            % Sealing the nodes
            this.iNodes = length(this.aoNodes);
            for iI = 1:this.iNodes
                this.aoNodes(iI).seal();
            end
            
            % Sealing the stores
            this.iStores = length(this.aoStores);
            for iI = 1:this.iStores
                this.aoStores(iI).seal();
            end
            
            % Sealing the branches
            this.iBranches = length(this.aoBranches);
            for iI = 1:this.iBranches
                this.aoBranches(iI).seal();
            end
        end
    end
    
    methods (Access = public, Sealed = true)
        
        % The update() method is sealed to make sure the voltages and
        % currents are always set in the circuit update. 
        function update(this, afValues)
            %UPDATE Sets voltages in nodes and currents in branche
            % Update() uses data in afValues from the solver to set the
            % currents in the branches, the voltages in the nodes and the
            % signs on the terminals. afValues is a 1xN vector containing
            % the voltages for all nodes, followed by the currents for all
            % branches in the order in which they are stored in the aoNodes
            % and aoBranches properties, respectively.
            
            for iI = 1:this.iNodes
                this.aoNodes(iI).setVoltage(afValues(iI));
            end
            
            for iI = 1:this.iBranches
                this.aoBranches(iI).setCurrent(afValues(iI + this.iNodes));
            end
            
        end
        
    end
end

