classdef Example < vsys
    % an example of a 3-dimensional thermal problem, a cube which is
    % located on space and has a internal heat source. The thermal multi
    % branch is used to solve this problem efficiently and this example
    % also serves as test case for the solver
    
    properties (SetAccess = protected, GetAccess = public)
        
        fTotalCubeVolume    = 1;
        iNodesPerDirection  = 3;
        fHeatFlow           = 100;
            
        coNodes;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, inf);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Create Environment Capacity
            matter.store(this, 'Space', Inf);
            
            this.toStores.Space.createPhase(  'gas', 'boundary',   'Vacuum',   1e6,    struct('N2', 2),          3,          0);
            
            % For the Multibranch solver, we initialize a 1 m^3 Cube of
            % Aluminium, which has a discretizable number of thermal nodes
            % as phases (which are also capacities), and automatically
            % creates the corresponding thermal branches. The minimum
            % discretization is 3x3x3, so that one node without connection
            % to the vaccum exists. For thermal exchange at the space
            % boundary, we assume radiative exchange with the created space
            % node. As thermal energy source, a 100 W energy source in the
            % middle of the cube is assumed
            
            % Variable Inputs the user can change:
            this.fTotalCubeVolume    = 1;
            this.iNodesPerDirection  = 7;
            this.fHeatFlow           = 500;
            fInitialTemperature      = 200;
            
            %% Remaining code
            matter.store(this, 'Cube', this.fTotalCubeVolume + 1e-3);
            
            iTotalNodes = this.iNodesPerDirection^3;
            if this.iNodesPerDirection < 3
                error('define at least a 3x3x3 cube!')
            end
            
            this.coNodes = cell(this.iNodesPerDirection, this.iNodesPerDirection, this.iNodesPerDirection);
            
            % Now we create the nodes to discretize the cube
            for iX = 1:this.iNodesPerDirection
                for iY = 1:this.iNodesPerDirection
                    for iZ = 1:this.iNodesPerDirection
                        
                        oNode = this.toStores.Cube.createPhase(  'solid',   ['Node_X', num2str(iX),'_Y', num2str(iY),'_Z', num2str(iZ)],   this.fTotalCubeVolume/iTotalNodes,    struct('Al', 1),          fInitialTemperature,          1e5);
            
                        this.coNodes{iX, iY, iZ} = oNode;
                    end
                end
            end
            
        end
        
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            oSpaceCapacity = this.toStores.Space.toPhases.Vacuum.oCapacity;
            
            fTotalCubeSideLength = this.fTotalCubeVolume^(1/3);
            
            %% Define the radiative resistance of each outfacing side
            fEpsilon        = 0.8;
            fSightFactor    = 1;
            % The area of each node facing to one of its sides
            fNodeArea     	= (fTotalCubeSideLength / this.iNodesPerDirection)^2;
            fRadiativeResistance = 1 / (fEpsilon * fSightFactor * this.oMT.Const.fStefanBoltzmann * fNodeArea);
            
            %% Define the conductive resistance between each cube element:
            % The distance between the center of each thermal node
            fNodeDistance           = fTotalCubeSideLength / this.iNodesPerDirection;
            fThermalConductivity    = this.oMT.calculateThermalConductivity(this.coNodes{1,1,1});
            fConductionResistance   = fNodeDistance / (fNodeArea * fThermalConductivity);
            
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
                        
                        bX_Side_Outfacing = iX == 1 || iX == this.iNodesPerDirection;
                        bY_Side_Outfacing = iY == 1 || iY == this.iNodesPerDirection;
                        bZ_Side_Outfacing = iZ == 1 || iZ == this.iNodesPerDirection;
                        
                        iNumberOfOutfacingSides = bX_Side_Outfacing + bY_Side_Outfacing + bZ_Side_Outfacing;
                        
                        oNode = this.coNodes{iX, iY, iZ}.oCapacity;
                        
                        for iRadiativeBranch = 1:iNumberOfOutfacingSides
                            sRadiatorConductorName = ['Radiator_',num2str(iRadiativeBranch),'_Node_X', num2str(iX),'_Y', num2str(iY),'_Z', num2str(iZ)];
                            thermal.procs.conductors.radiative(this, sRadiatorConductorName, fRadiativeResistance);
                            
                            sRadiatorBranchName = sRadiatorConductorName;
                            thermal.branch(this, oNode, {sRadiatorConductorName}, oSpaceCapacity, sRadiatorBranchName);
                        end
                        
                        % For the internal branches, we have to decide what
                        % nodes to connect. Since we loop through all
                        % nodes, we generall only connect from the node
                        % with the lower indices to the one with higher
                        % indices
                        
                        %% X Direction
                        % We only create the connection to the other
                        % node, if the node counter is 1, since in the
                        % othe case the branch is created by the node
                        % on the other side of the branch
                        if iX ~= this.iNodesPerDirection
                            aiOtherNode = [(iX +1) , iY, iZ];
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
            
            
            % The heatsource is located in the center, so we try finding
            % the middle of all three coordinated to place it
            if mod(this.iNodesPerDirection, 2) == 0
                % for an even number of nodes, no exact center node exists
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
                            
                            oNode = this.coNodes{iX, iY, iZ}.oCapacity;
                            oHeatSource = thermal.heatsource(['Heater_Node_X', num2str(iX),'_Y', num2str(iY),'_Z', num2str(iZ)], 0);
                            oNode.addHeatSource(oHeatSource);
                            oHeatSource.setHeatFlow(this.fHeatFlow / 8);
                            
                        end
                    end
                end
            else
                % for an uneven number of nodes, an exact center node
                % exists (e.g. for a 3x3x3 cube it is node 2,2,2)
                iCenterNodeIndex = (this.iNodesPerDirection + 1) / 2;
                
                oNode = this.coNodes{iCenterNodeIndex, iCenterNodeIndex, iCenterNodeIndex}.oCapacity;
                        
                oHeatSource = thermal.heatsource(['Heater_Node_X', num2str(iCenterNodeIndex),'_Y', num2str(iCenterNodeIndex),'_Z', num2str(iCenterNodeIndex)], 0);
                oNode.addHeatSource(oHeatSource);
                oHeatSource.setHeatFlow(this.fHeatFlow);
            end
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.thermal.multi_branch.iterative.branch(this.aoThermalBranches);
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
        end
        
     end
    
end

