classdef Example < vsys
    %EXAMPLE Example thermal system
    % This is an example of a 3-dimensional thermal problem, a cube which
    % is located in space and has an internal heat source. The thermal
    % multi-branch solver is used to solve this problem efficiently. This
    % example also serves as test case for the solver. 
    % Using the bAdvancedThermalSolver property, the user can switch
    % between using the basic and advanced thermal multi-branch solvers.
    % The default is using the advanced solver. 
    
    properties (SetAccess = protected, GetAccess = public)
        % By default we initialize a 1 m^3 Cube of Aluminum, which has
        % 7 thermal nodes as phases (which are also capacities), and
        % automatically create the corresponding thermal branches. The
        % minimum discretization is 3x3x3, so one node without
        % connection to vaccum always exists. For thermal exchange at
        % the space boundary, we assume radiative exchange with a space
        % node. As thermal energy source, a 500 W energy source in the
        % middle of the cube is modelled.
        % Volume of the cube that is modeled
        fTotalCubeVolume = 1;
        
        % Number of nodes along each side of the cube
        iNodesPerDirection = 7;
        
        % Heat flow from the heatsource [W]
        fHeatFlow = 500;
        
        % Initial temperature of all nodes [K]
        fInitialTemperature = 200;
            
        % A cell containing references to all nodes (capacities) in the
        % system. We could use the coCapacities property of the thermal
        % container for this, but by using our own property here, we can
        % arrange the nodes in a three dimensional cell array, just like
        % they are geometrically. 
        coNodes;
        
        % A boolean switch that is used to determine if this uses the
        % advanced thermal network solver or the simple one. The advanced
        % solver calculates heat flows and capacity temperatures, the
        % simple solver only calculates heat flows. 
        bAdvancedThermalSolver = true;
        
        % We want to vary the heat load during run time to create some
        % dynamics, so we need this array of heat source objects to access
        % them during the exec() call. 
        aoHeatSources;
    end
    
    methods
        function this = Example(oParent, sName)
            % Calling the parent class constructor. The third argument will
            % cause this object's exec() method to be executed every 120
            % seconds. 
            this@vsys(oParent, sName, 120);
            
            % By calling the following line, we make this system
            % configurable. By passing a containers.Map variable to the
            % setup function, we can set any of the properties of this
            % object, like overwriting the defaults defined above. 
            eval(this.oRoot.oCfgParams.configCode(this));
            
            % If the number of nodes is less than three, we can't have an
            % internal node with the heat source attached. So we check for
            % this condition and throw an error if it is not met. 
            if this.iNodesPerDirection < 3
                error('VHAB:Examples:NotEnoughNodes','define at least a 3x3x3 cube!')
            end
        end
        
        
        function createMatterStructure(this)
            % Calling this method in the parent class, that will also call
            % it on all children of this object.
            createMatterStructure@vsys(this);
            
            % Creating the space store.
            matter.store(this, 'Space', Inf);
            
            % Creating the space phase as a boundary phase. That means it
            % will not change its composition or pressure and its
            % associated thermal capacity will not change its temperature.
            oSpace = this.toStores.Space.createPhase('gas','boundary','Vacuum', 1e6, struct('N2', 2), 3, 0);
            
            % If the advanced solver is selected, the thermal capacity that
            % will be automatically created for the space phase needs to be
            % an instance of thermal.capacities.network. If this is set to
            % false, an instance of the "normal" thermal.capacity will be
            % created. 
            if this.bAdvancedThermalSolver
                oSpace.makeThermalNetworkNode();
            end
            
            % Creating the store that will contain all of the phases that
            % make up the cube. 
            matter.store(this, 'Cube', this.fTotalCubeVolume + 1e-3);
            
            % Calculating the total number of nodes.
            iTotalNodes = this.iNodesPerDirection^3;
            
            % Initializing the coNodes cell.
            this.coNodes = cell(this.iNodesPerDirection, this.iNodesPerDirection, this.iNodesPerDirection);
            
            % Now we create the nodes to discretize the cube
            for iX = 1:this.iNodesPerDirection
                for iY = 1:this.iNodesPerDirection
                    for iZ = 1:this.iNodesPerDirection
                        % Creating a node using the createPhase() method on
                        % the store and the 'solid' helper. Note that the
                        % 'solid' helper uses a mass ratio rather than
                        % absolute masses in the mass struct. 
                        oNode = this.toStores.Cube.createPhase(    ...
                                'solid',                           ... Phase type
                                ['Node_X', num2str(iX),            ... Phase name
                                     '_Y', num2str(iY),            ...     "
                                     '_Z', num2str(iZ)],           ...     "
                                this.fTotalCubeVolume/iTotalNodes, ... Phase volume
                                struct('Al', 1),                   ... Phase constituents and mass ratio
                                this.fInitialTemperature,          ... Phase temperature
                                1e5);                                % Phase pressure
                        
                        % Same as above, if the advanced solver is
                        % selected, the thermal capacity that will be
                        % automatically created for the space phase needs
                        % to be an instance of thermal.capacities.network.
                        % If this is set to false, an instance of the
                        % "normal" thermal.capacity will be created.
                        if this.bAdvancedThermalSolver
                            oNode.makeThermalNetworkNode();
                        end
                        
                        % Populating the coNodes cell array with the node
                        % we just created. 
                        this.coNodes{iX, iY, iZ} = oNode;
                    end
                end
            end
            
        end
        
        
        function createThermalStructure(this)
            % Calling this method in the parent class, that will also call
            % it on all children of this object.
            createThermalStructure@vsys(this);
            
            % Getting a reference to the capacity associated with the Space
            % phase that has been automatically created for us. 
            oSpaceCapacity = this.toStores.Space.toPhases.Vacuum.oCapacity;
            
            % Calculating the length of a side of the cube. We need this
            % value to calculate the surface area of each face. 
            fTotalCubeSideLength = this.fTotalCubeVolume^(1/3);
            
            %% Define the radiative resistance of each outfacing side
            fEpsilon    = 0.8;
            fViewFactor = 1;
            
            % The area of each node face
            fNodeArea = (fTotalCubeSideLength / this.iNodesPerDirection)^2;
            
            % Radiative resistance between each outside node and the space
            % capacity
            fRadiativeResistance = 1 / (fEpsilon * fViewFactor * this.oMT.Const.fStefanBoltzmann * fNodeArea);
            
            %% Define the conductive resistance between each cube element:
            % The distance between the centers of the thermal nodes
            fNodeDistance = fTotalCubeSideLength / this.iNodesPerDirection;
            
            % Getting the thermal conductivity of the first node, which is
            % the same for all nodes. 
            fThermalConductivity = this.oMT.calculateThermalConductivity(this.coNodes{1,1,1});
            
            % Now we can calculate the conductive resistance between all
            % nodes. 
            fConductionResistance = fNodeDistance / (fNodeArea * fThermalConductivity);
            
            %% Create connections between nodes
            % Now we create the connections between the nodes, boundary
            % nodes that connect to space are either at positions including
            % a one for any coordinate or a iTotalNodes/3 for any
            % coordinate. Nodes that fulfill this in mutliple instances
            % have multiple sides facing outwards and therefore also
            % receive multiple connections to space. E.g. the node 1,1,1 is
            % in the corner of the cube and therefore has three sides
            % facing outward and three sides facing inward.
            for iX = 1:this.iNodesPerDirection
                for iY = 1:this.iNodesPerDirection
                    for iZ = 1:this.iNodesPerDirection
                        
                        %% External Branches
                        
                        % Some logic to determine how many sides of the
                        % current node are on the outside of the cube.
                        bX_Side_Outfacing = iX == 1 || iX == this.iNodesPerDirection;
                        bY_Side_Outfacing = iY == 1 || iY == this.iNodesPerDirection;
                        bZ_Side_Outfacing = iZ == 1 || iZ == this.iNodesPerDirection;
                        
                        iNumberOfOutfacingSides = bX_Side_Outfacing + bY_Side_Outfacing + bZ_Side_Outfacing;
                        
                        % Getting the thermal capacity associated with the
                        % current node.
                        oNode = this.coNodes{iX, iY, iZ}.oCapacity;
                        
                        % Creating as many radiative thermal branaches as
                        % there are outward facing sides on the current
                        % node.
                        for iRadiativeBranch = 1:iNumberOfOutfacingSides
                            sRadiatorConductorName = ['Radiator_',num2str(iRadiativeBranch),'_Node_X', num2str(iX),'_Y', num2str(iY),'_Z', num2str(iZ)];
                            thermal.procs.conductors.radiative(this, sRadiatorConductorName, fRadiativeResistance);
                            
                            sRadiatorBranchName = sRadiatorConductorName;
                            thermal.branch(this, oNode, {sRadiatorConductorName}, oSpaceCapacity, sRadiatorBranchName);
                        end
                        
                        %% Internal Branches
                        % For the internal branches, we have to decide what
                        % nodes to connect. Since we loop through all
                        % nodes, we generall only connect from the node
                        % with the lower indices to the one with higher
                        % indices.
                        
                        %% X Direction
                        if iX ~= this.iNodesPerDirection
                            aiOtherNode = [(iX + 1) , iY, iZ];
                            oOtherNode  = this.coNodes{aiOtherNode(1), aiOtherNode(2), aiOtherNode(3)}.oCapacity;

                            sConductorName = ['Conductor_Node_X',num2str(iX),'_Y',num2str(iY),'_Z',num2str(iZ),'_to_X',num2str(aiOtherNode(1)),'_Y',num2str(aiOtherNode(2)),'_Z',num2str(aiOtherNode(3))];
                            thermal.procs.conductors.conductive(this, sConductorName, fConductionResistance);

                            sBranchName = sConductorName;
                            thermal.branch(this, oNode, {sConductorName}, oOtherNode, sBranchName);
                        end
                        
                        %% Y Direction
                        if iY ~= this.iNodesPerDirection
                            aiOtherNode = [iX , (iY + 1), iZ];
                            oOtherNode  = this.coNodes{aiOtherNode(1), aiOtherNode(2), aiOtherNode(3)}.oCapacity;

                            sConductorName = ['Conductor_Node_X',num2str(iX),'_Y',num2str(iY),'_Z',num2str(iZ),'_to_X',num2str(aiOtherNode(1)),'_Y',num2str(aiOtherNode(2)),'_Z',num2str(aiOtherNode(3))];
                            thermal.procs.conductors.conductive(this, sConductorName, fConductionResistance);

                            sBranchName = sConductorName;
                            thermal.branch(this, oNode, {sConductorName}, oOtherNode, sBranchName);
                        end
                        
                        %% Z Direction
                        if iZ ~= this.iNodesPerDirection
                            aiOtherNode = [iX , iY, (iZ + 1)];
                            oOtherNode  = this.coNodes{aiOtherNode(1), aiOtherNode(2), aiOtherNode(3)}.oCapacity;

                            sConductorName = ['Conductor_Node_X',num2str(iX),'_Y',num2str(iY),'_Z',num2str(iZ),'_to_X',num2str(aiOtherNode(1)),'_Y',num2str(aiOtherNode(2)),'_Z',num2str(aiOtherNode(3))];
                            thermal.procs.conductors.conductive(this, sConductorName, fConductionResistance);

                            sBranchName = sConductorName;
                            thermal.branch(this, oNode, {sConductorName}, oOtherNode, sBranchName);
                        end
                    end
                end
            end
            
            %% Heat Sources
            
            % Initializing the array of heat sources. 
            this.aoHeatSources = thermal.heatsource.empty();
            
            % The heatsource is located in the center, so we try finding
            % the middle of all three coordinated to place it
            if mod(this.iNodesPerDirection, 2) == 0
                % For an even number of nodes, no exact center node exists
                % so we split the heat source between multiple nodes. For
                % example for a 6x6x6 cube the center is assumed to be a
                % smaller 2x2x2 cube in the center spanning the indices
                % 3:4,3:4,3:4
                iLowerCenterIndex = this.iNodesPerDirection / 2;
                iUpperCenterIndex = this.iNodesPerDirection / 2 + 1;
                
                % Since we now have a total of 8 nodes (2^3) making up the
                % center we divide the heat flow per source by 8
                for iX = iLowerCenterIndex:iUpperCenterIndex
                    for iY = iLowerCenterIndex:iUpperCenterIndex
                        for iZ = iLowerCenterIndex:iUpperCenterIndex
                            % Getting the current node
                            oNode = this.coNodes{iX, iY, iZ}.oCapacity;
                            
                            % Creating a heat source
                            oHeatSource = thermal.heatsource(['Heater_Node_X', num2str(iX),'_Y', num2str(iY),'_Z', num2str(iZ)], this.fHeatFlow / 8);
                            
                            % Adding the heat source to the node
                            oNode.addHeatSource(oHeatSource);
                            
                            % Adding the heat source to the property array
                            this.aoHeatSources(end+1) = oHeatSource;
                        end
                    end
                end
            else
                % for an uneven number of nodes, an exact center node
                % exists (e.g. for a 3x3x3 cube it is node 2,2,2)
                iCenterNodeIndex = (this.iNodesPerDirection + 1) / 2;
                
                % Getting the center node
                oNode = this.coNodes{iCenterNodeIndex, iCenterNodeIndex, iCenterNodeIndex}.oCapacity;
                
                % Creating a heat source
                oHeatSource = thermal.heatsource(['Heater_Node_X', num2str(iCenterNodeIndex),'_Y', num2str(iCenterNodeIndex),'_Z', num2str(iCenterNodeIndex)], this.fHeatFlow);
                
                % Adding the heat source to the node
                oNode.addHeatSource(oHeatSource);
                
                % Setting the property to this heat source. 
                this.aoHeatSources = oHeatSource;
            end
        end
        
        
        function createSolverStructure(this)
            % Calling this method in the parent class, that will also call
            % it on all children of this object.
            createSolverStructure@vsys(this);
            
            % Depending on user input we either create an advanced or basic
            % thermal solver. 
            if this.bAdvancedThermalSolver
                % The second argument here is the internal time step for
                % the solver.
                solver.thermal.multi_branch.advanced.branch(this.aoThermalBranches, 20);
            else
                solver.thermal.multi_branch.basic.branch(this.aoThermalBranches);
            end
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            % We toggle the heat sources on and off every time exec() is
            % called. 
            for iI = 1:length(this.aoHeatSources)
                if this.aoHeatSources(iI).fHeatFlow == 0
                    this.aoHeatSources(iI).setHeatFlow(this.fHeatFlow);
                else
                    this.aoHeatSources(iI).setHeatFlow(0);
                end
            end
            
        end
        
     end
    
end

