classdef container < sys
    %CONTAINER A collection of thermal capacities
    %   Detailed explanation goes here
        
    properties (SetAccess = protected, GetAccess = public)
        
        % State properties
        
        % Set this to true by calling |taint()| when e.g. adding or
        % removing capacities, conductors, etc. This will mark current
        % thermal matrices as invalid and forces regenerating them.
        bIsTainted = false; % Has the container structure been altered and needs regenerating its intermediary representation?
        
        
        % Internal properties
        
        poCapacities;      % A map of associated |thermal.capacity| objects
        piCapacityIndices; % Map a capacity to an index.
        
        % Thermal connections
        poLinearConductors;    % A Map of associated |thermal.conductors.linear| objects.
        poFluidicConductors;   % A Map of associated |thermal.conductors.fluidic| objects.
        poRadiativeConductors; % A Map of associated |thermal.conductors.radiative| objects.
        
        % Matrices
        mCapacityVector   = [];
        mHeatSourceVector = [];
        mLinearConductance    = [];
        mFluidicConductance   = [];
        mRadiativeConductance = [];
                
    end
    
    methods
        
        function this = container(oParent, sName)
            % Create a new container object and call the |sys| parent
            % constructor. 
            
            % Call the |sys| (parent) constructor. This should register the
            % container with the parent (see |sys.setParent|) and get/set
            % some data from the parent. 
            this@sys(oParent, sName);
            
            % Re-initialize some properties because MATLAB may not do it.
            this.poCapacities          = containers.Map();
            this.piCapacityIndices     = containers.Map();
            this.poLinearConductors    = containers.Map();
            this.poFluidicConductors   = containers.Map();
            this.poRadiativeConductors = containers.Map();
            
        end
        
        %TODO: make a |getThermalNetwork| method that resets |bIsTainted|
        %      and returns pretty much all thermal maps so most of the
        %      stuff below can move to the solver. Should probably create
        %      copies of the maps. Maybe call it |getThermalNetworkSnapshot|?
        function generateThermalMatrices(this)
            % Update internal matrices with the current state of the
            % container. Make sure to only run this before or after a
            % simulation step otherwise you'll overwrite any calculations
            % made during this run. 
            %TODO: This should all probably move to the thermal solver!?
            %TODO: remove heat sources here since they can be reloaded
            %      every time by the solver
            
            % Get the number of available nodes.
            iNodes = this.poCapacities.length;
            
            % We need at least a node to be specified otherwise we cannot
            % do anything. 
            if iNodes < 1
                
                % Reset the index map.
                this.piCapacityIndices = containers.Map();
                
                % Reset the internal matrices.
                this.mCapacityVector   = [];
                this.mHeatSourceVector = [];
                this.mLinearConductance    = [];
                this.mFluidicConductance   = [];
                this.mRadiativeConductance = [];
                
                % Mark this container as clean.
                this.bIsTainted = false;
                
                return; % Return early.
                
            end
            
            % Associate an index to every capacity, preserving the order of
            % the |poCapacities| map.
            this.piCapacityIndices = containers.Map(this.poCapacities.keys, uint32(1:iNodes));
            
            % Generate the capacity and heat source matrices:
            
            % Pre-allocate capacity and heat source vectors.
            mCapacitances = zeros(iNodes, 1);
            mHeatSources  = zeros(iNodes, 1);
            
            % Loop over all node objects and get their capacities and 
            % attached heat sources.
            for sNode = this.piCapacityIndices.keys
                
                % Get index of current node.
                iIndex = this.piCapacityIndices(sNode{1});
                
                % Get the node object.
                oNode = this.poCapacities(sNode{1});
                
                % Get capacity and heater power of current node and store
                % the data at the associated index (i.e. position).
                mCapacitances(iIndex, 1) = oNode.getTotalHeatCapacity();
                mHeatSources(iIndex, 1)  = oNode.getHeatPower();
                
            end
            
            % Store generated capacity and heat source matrices.
            this.mCapacityVector   = mCapacitances;
            this.mHeatSourceVector = mHeatSources;
            
            % Generate and store the conductor matrices.
            this.mLinearConductance    = this.generateConductorMatrixFromObjects(this.poLinearConductors.values);
            this.mFluidicConductance   = this.generateConductorMatrixFromObjects(this.poFluidicConductors.values);
            this.mRadiativeConductance = this.generateConductorMatrixFromObjects(this.poRadiativeConductors.values);
            
            % Mark this container as clean.
            this.bIsTainted = false;
            
        end
        
        function oCapacity = addCreateCapacity(this, oMatter, oHeatSource)
            % Create a capacity, (optionally) add a heat source, and add
            % the capacity to the container. This is a shortcut method that
            % fuses |oCapacity = thermal.capacity|,
            % |oCapacity.setHeatSource|, and
            % |container.addCapacity(oCapacity)|.
                        
            oCapacity = thermal.capacity(oMatter.sName, oMatter);
            
            if nargin > 2
                oCapacity.setHeatSource(oHeatSource);
            end;
            
            this.addCapacity(oCapacity);
            % We're done here.
            
        end
        
        function addCapacity(this, oCapacity)
            % Add a capacity to the thermal container.
            
            if ~isa(oCapacity, 'thermal.capacity')
                this.throw('thermal:container:addCapacity', 'This is no thermal capacity!');
            elseif this.poCapacities.isKey(oCapacity.sName)
                this.throw('thermal:container:addCapacity', 'Capacity with name "%s" already exists!', oCapacity.sName);
            end;
            
            % Mark container as tainted and store capacity.
            this.bIsTainted = true;
            this.poCapacities(oCapacity.sName) = oCapacity;
            
        end
        
        function removeCapacity(this, sName)
            
            oCapacity = this.poCapacities(sName);
            
            % Mark container as tainted.
            this.bIsTainted = true;
            
            this.poCapacities.remove(sName);
            
            for entry = {this.poLinearConductors, ...
                    this.poFluidicConductors, this.poRadiativeConductors}
                
                poConductorsMap = entry{1};
                coConductors = poConductorsMap.values();
                mRemove = cellfun(@(o) o.isConnectedTo(oCapacity), coConductors);
                csRemove = cellfun(@(o) o.sName, coConductors(mRemove), 'UniformOutput', false);
                poConductorsMap.remove(csRemove);
                
            end
            
        end
        
        function addConductor(this, oConductor)
            % Add a conductor between any two capacities to the thermal
            % container.
            
            % Check if |oConductor| is an instance of a known conductor,
            % and load the appropriate property.
            if isa(oConductor, 'thermal.conductors.linear')
                sType = 'Linear';
            elseif isa(oConductor, 'thermal.conductors.fluidic')
                sType = 'Fluidic';
            elseif isa(oConductor, 'thermal.conductors.radiative')
                sType = 'Radiative';
            else
                this.throw('container:addConductor', 'This is no recognized conductor!');
            end
            
            % Get the property name.
            sConductorMap = ['po', sType, 'Conductors'];
            
            % Get conductor map.
            poConductors = this.(sConductorMap);
            
            if poConductors.isKey(oConductor.sName)
                this.throw('container:addConductor', '%s conductor with name "%s" already exists!', sType, oConductor.sName);
            end
            
            %TODO: check if connected capacities are already registered
            %TODO: make connected capacities aware of the conductor object?
            
            % Mark container as tainted and store conductor in the map.
            this.bIsTainted = true;
            poConductors(oConductor.sName) = oConductor;
            
            % Set conductor property. This may actually not be needed since
            % the handle object seems to be updated nonetheless. But better
            % not trust MATLAB's quirks and rather be safe than sorry.
            this.(sConductorMap) = poConductors;
            
        end
        
        function removeConductor(this, sName)
            
            for entry = {this.poLinearConductors, ...
                    this.poFluidicConductors, this.poRadiativeConductors}
                
                poConductorsMap = entry{1};
                
                if poConductorsMap.isKey(sName)
                    
                    % Mark container as tainted.
                    this.bIsTainted = true;
                    
                    % Remove conductor. 
                    poConductorsMap.remove(sName);
                    
                    %TODO: handle different types of conductors with same name?
                    return; % We're done here.
                    
                end
                
            end
            
            % Conductor was not found, so throw here.
            this.throw('container:removeConductor', 'Conductor with name "%s" does not exist!', sName);
            
        end
        
        function changeNodesInnerEnergy(this, mEnergyChange)
            
            % Loop over all node objects and notify them about the inner
            % energy change.
            for sNode = this.piCapacityIndices.keys
                
                % Get index of current node.
                iIndex = this.piCapacityIndices(sNode{1});
                
                % Get the node object.
                oNode = this.poCapacities(sNode{1});
                
                % Notify the node about the energy change.
                oNode.changeInnerEnergy(mEnergyChange(iIndex));
                
            end
            
        end
        
        function mTemperatures = getNodeTemperatures(this)
            % Get the temperatures of currently active nodes, i.e. the
            % nodes that were previously selected during the generation
            % step. 
            
            % Get the number of available nodes.
            iNodes = this.piCapacityIndices.length;
            
            % Pre-allocate vector.
            mTemperatures = zeros(iNodes, 1);
            
            % Loop over all node objects and get their current
            % temperatures.
            for sNode = this.piCapacityIndices.keys
                
                % Get index of current node.
                iIndex = this.piCapacityIndices(sNode{1});
                
                % Get the node object.
                oNode = this.poCapacities(sNode{1});
                
                % Get capacity and heater power of current node and store
                % the data at the associated index (i.e. position).
                mTemperatures(iIndex, 1) = oNode.getTemperature();
                
            end
            
        end
        
        function setNodeTemperatures(this, mNewTemperatures)
            
            this.warn('thermal:container:setNodeTemperatures', 'DEPRECATED method: The node temperature should not be set directly. Use "changeNodesInnerEnergy" instead.');
            
            % Loop over all node objects and set their new temperatures.
            for sNode = this.piCapacityIndices.keys
                
                % Get index of current node.
                iIndex = this.piCapacityIndices(sNode{1});
                
                % Get the node object.
                oNode = this.poCapacities(sNode{1});
                
                % Set the new temperature of the node.
                oNode.setTemperature(mNewTemperatures(iIndex));
                
            end
            
        end
        
        function taint(this)
            % Mark the container as tainted so before the next solver run,
            % the matrices will be regenerated.
            
            this.bIsTainted = true;
            
        end
        
        %TODO: the following is not needed when the matrix generation stuff
        % is done in the solver (see TODO above)
        function mCapacities = getCapacitances(this)
            
            if this.bIsTainted
                this.warn('thermal:container:getCapacitances', 'Container was changed, this might not return the expected results.');
            end
            mCapacities = this.mCapacityVector;
            
        end
        
        function mHeatSourceVector = getHeatSources(this)
            
            if this.bIsTainted
                this.warn('thermal:container:getHeatSources', 'container was changed, this might not return the expected results.');
            end
            mHeatSourceVector = this.mHeatSourceVector;
            
        end
        
        function mLinearConductance = getLinearConductors(this)
            
            if this.bIsTainted
                this.warn('thermal:container:getLinearConductors', 'container was changed, this might not return the expected results.');
            end
            mLinearConductance = this.mLinearConductance;
            
        end
        
        function mRadiativeConductance = getRadiativeConductors(this)
            
            if this.bIsTainted
                this.warn('thermal:container:getRadiativeConductors', 'container was changed, this might not return the expected results.');
            end
            mRadiativeConductance = this.mRadiativeConductance;
            
        end
        
        function mFluidicConductance = getFluidicConductors(this)
            
            if this.bIsTainted
                this.warn('thermal:container:getFluidicConductors', 'container was changed, this might not return the expected results.');
            end
            mFluidicConductance = this.mFluidicConductance;
            
        end
        
    end
    
    methods (Access = protected)
        
        function mConductorMatrix = generateConductorMatrixFromObjects(this, coConductors)
            
            % Get the number of available conductors.
            iConductors = size(coConductors, 2);
            
            % Pre-allocate conductor matrix.
            mConductorMatrix = zeros(iConductors, 3);
            
            % Initialize counter.
            iCounter = 0;
            
            % Loop over all conductor objects and get the indices of their
            % connected capacities. 
            %TODO: This may not do what you expected because theoretically
            % |coCapacities| may have a different ordering than
            % |this.piCapacityIndices|. However since we *just* created the
            % latter, we can reasonably assume their keys and ordering are
            % equal. This may not be the case if this function is called in
            % a different context than in |this.generateThermalMatrices()|.
            % This method should probably be rewritten to be "failsafe".
            for oConductor = coConductors
                
                % Increment counter. 
                iCounter = iCounter + 1;
                
                % Get the names of the connected nodes.
                [sNameLeft, sNameRight] = oConductor{1}.getCapacityNames();
                
                % Get the indices of the connected nodes. 
                iIndexLeft  = this.piCapacityIndices(sNameLeft);
                iIndexRight = this.piCapacityIndices(sNameRight);
                
                % Get the value of conductance. 
                fConductance = oConductor{1}.fConductivity;
                
                % Put it all in the matrix. Make sure the conductivity
                % value is not rounded; this is a bad workaround and needed
                % as long as all this stuff is in the container and not the
                % solver where it belongs.
                mConductorMatrix(iCounter, :) = [double(iIndexLeft), double(iIndexRight), fConductance];
                
            end
            
        end
        
        function exec(this, varargin)
            % TODO: 
            %  - build a matrix if container is tainted
            %  - run solver
            
            if (this.bIsTainted) 
                this.warn('thermal:container:exec', 'Container was changed, this might not do what is expected.');
                %this.generateThermalMatrices();
            end
            
        end
        
    end
    
end

