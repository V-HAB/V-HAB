classdef branch < base & event.source
% A multi branch thermal solver which calculates the heat flow in a network
% of thermal branches. It can solve only branches which do not include
% mass flows, so add only non fluidic conductors to branches for this
% solver! 
% Note that it is not possibe to combine convective/conductive conductors
% and radiative conductors in one solver branch, you have to separate these
% heat transfers so that the convective/conductive part and the radiative
% part are solved separatly
    
%% Basic description of the basics for this solver
% The thermal network consists of as many equations as there are branches.
% Each branch represents a thermal heat exchange between two thermal
% capacities. So each equation has the form of some kind of resistance *
% some kind of temperature difference (T1 - T2). For radiation the
% temperature difference is between the temperatures^4 but that is handled
% in the creation of the afTemperatures vector. So in the matrix, we
% require 1 at the location of the corresponding capacity which is T1
% (which is the left side of the thermal branch), and a -1 for the
% capacity that represents T2 in the equation (the right side of the
% branch).
%
% The heat flow can be calculated using: fHeatFlow = fDeltaTemperature /
% fTotalThermalResistance, where fTotalThermalResistance is the total
% thermal resistance from all conductors in the branch. Each of these
% resistances must be updated beforehand and then summed up (within a
% branch no parallel heat exchange is modelled, for that purpose multiple
% branches are necessary): afResistances(iConductor) =
% this.oBranch.coConductors{iConductor}.update();
%
% So each equation has the form: fHeatFlow = fDeltaTemperature /
% fTotalThermalResistance
%
% The vector matrix system that we create only brings that into the
% corresponding form. Let us assume we have 4 capacities, which are
% connected by 3 Branches in a 1D problem (capacity 1 is connected to
% capacity 2 and so on). In that case the following vector matrix
% multiplication allows you to calculate the delta temperatures
%
%   System of Equations  | Temperatures |   	Delta T
%   1	-1	  0     0           303               5
%   0    1   -1     0       *   298           =   13
%   0    0    1    -1           285               9
%                               276
%
% SoE   = [1 -1 0 0; 0 1 -1 0; 0 0 1 -1]
% T     = [303; 298; 285; 276]
%
% However, we don't want the delta between the temperatures but the branch
% heat flows. For that purpose we transform the equation (T1 - T2)/ R into
% T1/R - T2/R. If we assume a thermal resistance of 0.5 K/W for our example
% for all conductors the system of equations becomes:
%
%   System of Equations  | Temperatures |   	Heat Flows
%   2	-2	  0     0           303               10
%   0    2   -2     0       *   298           =   26
%   0    0    2    -2           285               18
%                               276
%
% SoE   = [2 -2 0 0; 0 2 -2 0; 0 0 2 -2]
% T     = [303; 298; 285; 276]
%
% Since we have to use temperatures^4 for the radiative heat transfer, we
% cannot simply use the same temperature values for the radiative heat
% transfers, as we might require them as normal values and as ^4 values. To
% solve this in the initializeNetwork function the aoBranches property is
% reordered to ensure that all radiative branches are at the end of the
% property. All capacities which take part in the radiative heat transfer
% are also added again to aoCapacities and the property
% iFirstRadiativeCapacity is defined to find out which temperatures have to
% be ^4
%
%% Timestepping:
% The basic thermal solver simply calculates the heat flows based on the
% current conditions of the branches and capcities. Since the solver does
% not know when the capacities require an update, it does not set a
% timestep, but is instead updated whenever a connected capacity is updated
    
    properties (SetAccess = protected, GetAccess = public)
       	% array containing the branches that are solved by this solver
        aoBranches;
        
        % Arrray containing the capacities which are connected to the
        % solved matrix in an order specfied by the initializeNetwork
        % function
        aoCapacities;
        
        % Boolean vector which identifies radiative heat transfer branches
        % in the aoBranches property
        abRadiationBranches;
        
        % Index of the first radiative heat transfer branch in aoBranches.
        % So this.aoBranch(this.iFirstRadiationBranch:end) returns all
        % radiative heat transfer branches
        iFirstRadiationBranch;
        
        % Index of the first capacity connected to a radiative heat
        % transfer branch in aoCapacities. So
        % this.aoCapacities(this.iFirstRadiativeCapacity:end) returns all
        % of these capacities
        iFirstRadiativeCapacity;
        
        % This property was implemented for performance improvements, to
        % identify which capacities are represented twice in the network,
        % to only trigger the temperature update for them once
        abNonUniqueCapacity;
        
        % Number of branches in the network
        iBranches;
        
        % Number of capacities that are connected to the network
        iCapacities;
        
        % Last time the solver was updated
        fLastUpdate = -10;
        
        % A flag to decide if the solver is already outdated or not
        bRegisteredOutdated = false;
        
        % In recursive calls within the post tick where the solver itself
        % triggers outdated calls up to the point where it is set outdated
        % again itself it is possible for the solver to get stuck with a
        % true bRegisteredOutdated flag. To prevent this we also store the
        % last time at which we registered an update
        fLastSetOutdated = -1;
        
        % Reference to the timer object
        oTimer;
        
        %% Network variables
        % A matrix where each row corresponds to the branch from aoBranches
        % with the same index. so this.mfConnectivityMatrix(iBranch, :)
        % provides the row representing this.aoBranches(iBranch). For each
        % branch there are two entries, a 1 (for the left capacity) and 
        % a -1 (for the right capacity). The matrix must be divided with
        % the current resistances before it can be used in heat flow
        % calculations.
        mfConnectivityMatrix;
        
        % As a performance enhancement, these booleans are set to true once
        % a callback is bound to the 'update' and 'register_update'
        % triggers, respectively. Only then are the triggers actually sent.
        % This saves quite some computational time since the trigger()
        % method takes some time to execute, even if nothing is bound to
        % them.
        bTriggerUpdateCallbackBound = false;
        bTriggerRegisterUpdateCallbackBound = false;
        
        % Flag to decide if this solver needs to be recalculated for every
        % change in the heat flows of the attached capacities (e.g.
        % infinite conduction thermal solver). Flag is called residual
        % because the matter side residual solver was the first solver
        % which required this
        bResidual = false;
        
        % Handle to bind an update to the corresponding post tick. Simply
        % use XXX.hBindPostTickUpdate() to register an update. Solvers
        % should ONLY be updated in the post tick!
        hBindPostTickUpdate;
    end
    
    properties (SetAccess = private, GetAccess = private)
        % cell containing the handles of the set flow rate functions of the
        % individual branches in this network. THis is used to set the
        % calculated heat flows to the thermal branches of the network
        chSetBranchHeatFlows;
    end
    
    methods
        function this = branch(aoBranches, bChildCall)
            % Please note that the aoBranches property is reordered in the 
            % initializeNetwork function!
            % The bChildCall parameter is only necessary for other thermal
            % multi branches to deactivate the initial update call
            if nargin < 2
                bChildCall = false;
            end
            
            this.aoBranches = aoBranches;
            this.iBranches = length(this.aoBranches);
            
            this.oTimer     = this.aoBranches(1).oTimer;
            
            % we only have to do this once, but initially we have to create
            % the thermal network we want to solve here
            this.initializeNetwork();
            
            if ~bChildCall
                % Now we register the solver at the timer, specifying the post
                % tick level in which the solver should be executed. For more
                % information on the execution view the timer documentation.
                % Registering the solver with the timer provides a function as
                % output that can be used to bind the post tick update in a
                % tick resulting in the post tick calculation to be executed
                this.hBindPostTickUpdate = this.oTimer.registerPostTick(@this.update, 'thermal' , 'solver');

                % and update the solver to initialize everything
                this.update();
            end
        end
        
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            if strcmp(sType, 'update')
                this.bTriggerUpdateCallbackBound = true;
            
            elseif strcmp(sType, 'register_update')
                this.bTriggerRegisterUpdateCallbackBound = true;
            
            end
        end
    end
    
    methods (Access = protected)
        
        function registerUpdate(this, ~)
            % this function registers an update
            
            if ~(this.oTimer.fTime > this.fLastSetOutdated) && this.bRegisteredOutdated
                return;
            end
            
            if ~base.oDebug.bOff, this.out(1, 1, 'reg-post-tick', 'Multi-Solver - register outdated? [%i]', { ~this.bRegisteredOutdated }); end
            
            for iCapacity = 1:this.iCapacities
                if ~this.abNonUniqueCapacity(iCapacity)
                    this.aoCapacities(iCapacity).registerUpdateTemperature();
                end
            end
            
            % Allows other functions to register an event to this trigger
            if this.bTriggerRegisterUpdateCallbackBound
                this.trigger('register_update');
            end

            if ~base.oDebug.bOff, this.out(1, 1, 'registerUpdate', 'Registering update() method on the multi-branch solver.'); end
            
            this.hBindPostTickUpdate();
            %this.hBindPostTickTimeStepCalculation();
            
            this.bRegisteredOutdated = true;
            this.fLastSetOutdated = this.oTimer.fTime;
        end
        
        function initializeNetwork(this)
            %% initializeNetwork
            % Is only execute once when the solver is created. It creates
            % the aoCapacities property in the corresponding order, as well
            % as reorders the aoBranches property. In addition the
            % connectivity Matrix is defined here, allowing fast
            % calculation of the whole network in the update function
            
            % Since it is possible to access properties as follows:
            % afHeatFlows = [this.aoBranches.fHeatFlow]
            % We define an object array of the capacities for the normal
            % conductors and for the radiative conductors. From that we
            % also construct the overall object array of all capacities,
            % but keeping them seperate is easier initially
            this.aoCapacities = thermal.capacity.empty();
            
            % The matrix is not initialized with the correct size, because
            % we do not know yet how many capacities are actually present
            % in the network, but it is at least 1
            this.mfConnectivityMatrix = zeros(this.iBranches, 1);
            
            % The upper part of the connectivity matrix contains the SoE
            % for conductive and convective heat transfer and the lower
            % part contains the SoE for radiative heat transfer.
            % Unfortunatly this would mean the index of the row for the
            % matrix to no longer corresponds to the row in the aoBranches
            % property. Therefore, we reorder the aoBranches property to
            % move all radiative branches to the back of the array!
            this.abRadiationBranches = [this.aoBranches.bRadiative]';
            aoConductiveBranches = this.aoBranches(~this.abRadiationBranches);
            aoRadiativeBranches  = this.aoBranches(this.abRadiationBranches);
            this.aoBranches = [aoConductiveBranches; aoRadiativeBranches];
            this.abRadiationBranches = [this.aoBranches.bRadiative]';
            
            % Since the lower part of the mfConnectivityMatrix may contain
            % some of the same capacities as the upper part, we need to
            % keep track of the capacities that are not unique to the
            % radiation calculations.
            this.abNonUniqueCapacity = logical.empty();
            
            % Getting the index of the first radiation branch
            this.iFirstRadiationBranch = find(this.abRadiationBranches, 1);
            
            % Now we loop through all branches and populate the
            % mfConnectivityMatrix accordingly.
            for iBranch = 1:this.iBranches
                % Getting references to the two capacities of this branch
                % to reduce the number of context changes.
                oLeftCapacity  = this.aoBranches(iBranch).coExmes{1}.oCapacity;
                oRightCapacity = this.aoBranches(iBranch).coExmes{2}.oCapacity;
                
                % Initializing the index variables
                iLeftCapacityIndex = 0;
                iRightCapacityIndex = 0;
                
                % Initializing two booleans to capture if the capacities
                % are unique within the network.
                bNonUniqueLeftCapacity = false;
                bNonUniqueRightCapacity = false;
                
                % If this is the first radiation branch, we store the
                % current index of the aoCapacities array so we know which
                % capacities belong to the radiation calculations.
                if iBranch == this.iFirstRadiationBranch
                    this.iFirstRadiativeCapacity = length(this.aoCapacities) + 1;
                end
                
                % Getting a cell with all UUIDs of the capacities.
                csUUIDs = {this.aoCapacities.sUUID};
                
                % If we are within the upper part of the connectivity
                % matrix, we just need to find the indexes of the two
                % capacities.
                if iBranch < this.iFirstRadiationBranch
                    abLeftCapacity = strcmp(csUUIDs, oLeftCapacity.sUUID);
                    
                    if sum(abLeftCapacity)
                        iLeftCapacityIndex = find(abLeftCapacity);
                    end
                    
                    abRightCapacity = strcmp(csUUIDs, oRightCapacity.sUUID);
                    
                    if sum(abRightCapacity)
                        iRightCapacityIndex = find(abRightCapacity);
                    end
                    
                else
                    % In this case we are in the lower part of the
                    % connectivity matrix, dealing with capacities that are
                    % part of the radiation calculations. So here we try to
                    % find the corresponding indexes only in the upper part
                    % of the aoCapacities array, otherwise we might find it
                    % more than once. 
                    % The uniqueness check on the other hand is only
                    % performed in the lower part. 
                        
                    % Is the left capacity already present in the lower
                    % part of the aoCapacities array?
                    abLeftCapacity = strcmp(csUUIDs(this.iFirstRadiativeCapacity:end), oLeftCapacity.sUUID);
                    
                    if sum(abLeftCapacity)
                        % We found it, so we get the index in the overall
                        % capacities array by adding the index of the first
                        % radiative capacity. Minus one because the first
                        % index in the logical sub-array we got here
                        % corresponds to the first radiative capacity.
                        iLeftCapacityIndex = find(abLeftCapacity) + this.iFirstRadiativeCapacity - 1;
                    end
                    
                    % Is the right capacity already present in the lower
                    % part of the aoCapacities array?
                    abRightCapacity = strcmp(csUUIDs(this.iFirstRadiativeCapacity:end), oRightCapacity.sUUID);
                    
                    if sum(abRightCapacity)
                        % We found it, so we get the index in the overall
                        % capacities array by adding the index of the first
                        % radiative capacity. Minus one because the first
                        % index in the logical sub-array we got here
                        % corresponds to the first radiative capacity.
                        iRightCapacityIndex = find(abRightCapacity) + this.iFirstRadiativeCapacity - 1;
                    end
                    
                    % Is the left capacity alredy present in the upper
                    % part of the aoCapacities array?
                    abLeftCapacity = strcmp(csUUIDs(1:this.iFirstRadiativeCapacity-1), oLeftCapacity.sUUID);
                    
                    if sum(abLeftCapacity)
                        bNonUniqueLeftCapacity = true;
                    end
                    
                    % Is the right capacity alredy present in the upper
                    % part of the aoCapacities array?
                    abRightCapacity = strcmp(csUUIDs(1:this.iFirstRadiativeCapacity-1), oRightCapacity.sUUID);
                    
                    if sum(abRightCapacity)
                        bNonUniqueRightCapacity = true;
                    end
                    
                end
                
                % If one of the capacities was not found, we add it to the
                % aoCapacities array, mark it as unique and set the index
                % to the end of the aoCapacities array.
                if iLeftCapacityIndex == 0
                    this.aoCapacities(end+1, 1)        = oLeftCapacity;
                    this.abNonUniqueCapacity(end+1, 1) = bNonUniqueLeftCapacity;
                    iLeftCapacityIndex                 = length(this.aoCapacities);
                end
                
                if iRightCapacityIndex == 0
                    this.aoCapacities(end+1, 1)        = oRightCapacity;
                    this.abNonUniqueCapacity(end+1, 1) = bNonUniqueRightCapacity;
                    iRightCapacityIndex                = length(this.aoCapacities);
                end
                
                % So here we perform the assignment of left and right side
                % with 1 and -1 as mentioned in the explanatory comments at
                % the beginning of this function. Since the
                % resistance/conductivity changes in each tick, we cannot
                % assign those yet
                this.mfConnectivityMatrix(iBranch, iLeftCapacityIndex)   =  1;
                this.mfConnectivityMatrix(iBranch, iRightCapacityIndex)  = -1;
            end
            
            this.iCapacities = length(this.aoCapacities);
            
            % Register this solver as the solver for all thermal branches
            % inside the network and save the setHeatFlow function of each
            % branch in the chSetBranchHeatFlows property
            this.chSetBranchHeatFlows = cell(1, this.iBranches);
            for iB = 1:this.iBranches 
                this.chSetBranchHeatFlows{iB} = this.aoBranches(iB).registerHandler(this);
                
                this.aoBranches(iB).bind('outdated', @this.registerUpdate);
            end
            
        end
        
        function update(this)
            % update the thermal solver
            
            % The first step is to divide the connectivity matrix by the
            % resistances, so that the vector matrix operation of the
            % matrix times the temperatures results in the heat flows. We
            % call this the conductivity matrix, because basically every
            % entry of the matrix is now a conductivity
            %
            % At first we have to get the current resistances of the
            % branches.
            afBranchResistances = zeros(this.iBranches, 1);
            for iBranch = 1:this.iBranches
                afResistances = zeros(1,this.aoBranches(iBranch).iConductors);
                for iConductor = 1:this.aoBranches(iBranch).iConductors
                    afResistances(iConductor) = this.aoBranches(iBranch).coConductors{iConductor}.update();
                end
                % It is always a sum because parallel heat transfer is
                % modelled through multiple branches!
                afBranchResistances(iBranch) = sum(afResistances);
            end
            
            % Now we can simply use a vector matrix operation to get the
            % current conductivity matrix
            mfConductivityMatrix = this.mfConnectivityMatrix ./ afBranchResistances;
            
            % Getting the temperatures of all capacities.
            afTemperatures = [this.aoCapacities.fTemperature]';
            
            % Since the temperatures for the radiation calculation need to
            % be raised to the power of 4, we do that to all temperatures
            % in the lower part of the array. 
            afTemperatures(this.iFirstRadiativeCapacity:end) = afTemperatures(this.iFirstRadiativeCapacity:end).^4;
            
            % Now we can finally calculate the heat flows. 
            afHeatFlows = mfConductivityMatrix * afTemperatures;
            
            %% Now we set the heat flows to the branches:
            for iBranch = 1:this.iBranches
                oBranch = this.aoBranches(iBranch);
                fHeatFlow = afHeatFlows(iBranch);
                % set heat flows to exmes
                oBranch.coExmes{1}.setHeatFlow(fHeatFlow);
                oBranch.coExmes{2}.setHeatFlow(fHeatFlow);

                % The temperatures between the conductors are not solved
                % here, but a solver could be derived which does that (will
                % be quite slow for larger networks however)
                afTemperatures = []; 
                this.chSetBranchHeatFlows{iBranch}(fHeatFlow, afTemperatures);
            end
            this.fLastUpdate = this.oTimer.fTime;
            this.bRegisteredOutdated = false;
            
            if this.bTriggerUpdateCallbackBound
                this.trigger('update');
            end
        end
    end
end
