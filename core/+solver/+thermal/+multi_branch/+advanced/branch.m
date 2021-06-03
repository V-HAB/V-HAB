classdef branch < solver.thermal.multi_branch.basic.branch
% A multi branch thermal solver which calculates the heat flow in a network
% of thermal branches. It can solve only branches which do not include
% mass flows, so add only non fluidic conductors to branches for this
% solver! 
% Different from the basic thermal multi branch, which only calculates the
% heat flows, this thermal solver is closer to other thermal network
% solvers, as it directly solves the temperatures and includes the capacity
% calculations for the network. Therefore, it is the only valid solver for
% all capacities present in the network, do not use any other thermal
% solver in a branch connected to an capacity which is also part of this
% network! Because the solver has to take into account heat flows from heat
% sources, it is also not compatible with heat sources that require the
% solver heat flows (like the constant temperature heat source!)
%
% Note that it is not possibe to combine convective/conductive conductors
% and radiative conductors in one solver branch, you have to separate these
% heat transfers so that the convective/conductive part and the radiative
% part are solved separatly
%
% Also note that the temperatures of the network capacities are only update
% if this solver is updated! If you require the really up to date
% temperature of a node in this solver, you first have to call the
% setOutdatedTS function of that node, which then triggers a solver update,
% and then bind yourself to the post update of this solver!
%    
%% Description of solution strategy for this solver:
% The basic equation for the temperature change in capacities is:
%
% m ? c_p ? ?T = Q_dot ? ?T = Q_dot / (m ? c_p) 
%
% This means the temperature difference calculated in the solver depends on
% the current mass of the phase, as well as its composition (c_p)!
% Therefore, we can envision two possible solution approaches for a multi
% thermal solver in a combined system. One would be the accurate solution,
% where the whole thermal solver must be updated for ANY change in the
% matter domain. That is basically the 'basic' thermal multi branch solver.
% It is updated in case anything in the matter domain is changed.
% 
% For the advanced thermal multi branch, we at first do not allow mass
% changes for the phases. Meaning, the variables m?c_p are constant, and
% the only possible change comes from the thermal solver itself. This
% allows us to use an adjusted thermal network. However, you cannot simply
% divide the connectivity matrix with the mass and heat capacity, as the
% connectivity matrix currently represents the thermal branches in V-HAB
% and not the capacities. However, in the basic thermal multi branch, the
% values for the branches where calculated and these connections are stored
% in the connectivity matrix. If we want to calculate the temperatures
% directly now, we have to use that connectivity matrix to calculate the
% temperature changes for each capacity. In the conductivity matrix each
% row represents a branch and each column represents a capacity. Since we
% already calculate the heat flows for the branches, we basically have to
% multiply the first entry from the heat flow vector with the first row of
% connectivity matrix, and the second heat flow with the second row of the
% connectivity matrix and so on. The resulting columns of the matrix can
% then be summed up to get the heat flows for the individual capacities. If
% we divide the connectivity matrix with the m?c_p values of the
% corresponding capacities beforehand, we calculate the temperature
% differences instead of the heat flows. More mathematical spoken, we can
% transpose the connectivity matrix and then multiply it with the heat
% flows to calculate the heatflows of the capacities. But since a positive
% branch heat flow represents a negative heat flow for the capacity whose
% index is 1, we have to multiply the whole matrix with -1 (using the same
% example as the basic thermal multi branch):
%
%   ConnectivityMatrix'  | HeatFlows |          HeatFlows for Capacities
%  -1	 1	  0     0 '         10               -10
%   0   -1    1     0       *   26           =   -16
%   0    0   -1     1           18                8
%                                                 18
%
% SoE   = -1 .* [1 -1 0 0; 0 1 -1 0; 0 0 1 -1]'
% Q     = [10; 26; 18]
%
% And if we create a vector of the m?c_p values for the capacities we can
% use the Matlab elementwise division operator ./ on the transposed
% connectivity matrix. Using that matrix instead of the connectivity matrix
% then allows us to calculate the temperature differences directly. The
% equivalent to the operations we performed stepwise is the following:
% 
%   ConnectivityMatrix'  | ConductivityMatrix |  HeatFlows |        HeatFlows for Capacities
%  -1	 1	  0     0 '    2   -2	0   0           10              -10
%   0   -1    1     0    * 0    2  -2   0     *     26           =  -16
%   0    0   -1     1      0    0  	2  -2           18               8

% Conductivity   = [2 -2 0 0; 0 2 -2 0; 0 0 2 -2]
% T     = [303; 298; 285; 276]   
%
% And if we initially divide the transposed connectivity matrix with the
% total heat capacities of the phases, we get the temperature differences.
%
%% Timestepping:
% From the solver side, the time step can be arbitrarily large, it uses an
% ode45 solver with internal time steps, that will calculate the
% corresponding accurate temperatures. TO BE DONE: add some time stepping
% parameters like rMaxTemperature change?
    
    properties (SetAccess = protected, GetAccess = public)
        % This matrix contains the sign of the temperature changes
        % resulting from positive heat flows in the branches for the
        % corresponding capacities, divided with the total heat capacities
        % of the corresponding capacities! For a better description of the
        % solver see the comments above
       	mfTotalHeatCapacityMatrix;
        
        % This vector contains the heat flow from heat sources in the order
        % of the heat capacities
        afSourceRateVector;
        
        % Vector containing the temperatures of each capacity solved by
        % this solver (the unique temperatures, so it does not have the
        % same length as the aoCapacities vector!)
        afTemperatures;
        
        % This matrix contains the multiplication of the total heat
        % capacity matrix and the conductivity matrix as described in the
        % initial description of the solver. 
        mfTemperatureChangeRateMatrix;
        
        % This matrix can be used to transform the afTemperatureChangeRate
        % vector calculated from the full system of equations, into the
        % afUniqueTemperatureChangeRate vector where the temperature change
        % rates for capacities that have both linear and radiative heat
        % transfer are added up.
        mbNonUniqueCapacities;
        
        % Similar to the mbNonUniqueCapacities properties, this matrix
        % includes a subset of that matrix with only the radiative
        % capacities. This is done to increase the performance of the ODE
        % solver function by reducing the size of matrices that need to be
        % handled.
        mbRadiativeCapacities;
        
        % An array of thermal capacity objects. This array only contains
        % the unique capacities.
        aoUniqueCapacities;
        
        % Number of unique capacities in this solver network.
        iUniqueCapacities;
        
        % Options struct for the ode solver, see help for the ode solver
        % for descriptions on what can be set etc.
        tOdeOptions;
        
        % The time step for the solver
        fTimeStep = 20;
        % If something triggers a solver update before the next solver is
        % scheduled via the time step, a smaller execution time step than
        % time step results.
        fExecutionTimeStep;
        
        % Boolean to decide if external solvers are used or not
        bExternalSolvers = false;
        % This cell array has the same length as the unique capacities
        % index and contains the non multi solver thermal branches for the
        % corresponding capacity. The solver then handles the external
        % branches like heat sources to the network capacity
        coNonSolverBranches;
        % cell which conaints the signs for the non solver branches in
        % relation to their network capacities
        ciNonSolverSigns;
        
        % 
        hCalculateTemperatureChangeRate;
        
        % These properties store the last ODE results
        mfTimePoints;
        mfSolutionTemperatures;
        
        % A boolean property that is set to false once the update() method
        % is bound to a post tick. This is used to short-circuit calls to
        % the bindPostTick() method by the network capacities. If this was
        % not in place, every single capacity in the network would call
        % this method during every tick, which is unneccessary. 
        bPostTickUpdateNotBound = true;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step in [s]
        setTimeStep;
        
        % A function handle that actually binds the update() method of this
        % class to a timer post tick. This was created to prevent all
        % capacities in this network calling the bind() method on the timer
        % every tick. 
        hActuallyBindPostTick;
    end
    
    methods
        function this = branch(aoBranches, fTimeStep, tOdeOptions)
            this@solver.thermal.multi_branch.basic.branch(aoBranches, true)
            
            % Set the default options for the ODE solver. 
            if nargin < 3
                this.tOdeOptions = odeset('RelTol', 1e-3, 'AbsTol', 1e-4);
            else
                this.tOdeOptions = tOdeOptions;
            end
            
            this.fTimeStep = fTimeStep;
            
            afHeatCapacities = [this.aoCapacities.fTotalHeatCapacity]';
            
            this.mfTotalHeatCapacityMatrix = (-1 .* this.mfConnectivityMatrix)' ./ afHeatCapacities;
            
            % While the basic solver only solves values for branches, and
            % therefore does not care about duplicates in the aoCapacities
            % vector, for a solver that solves the temperatures this
            % becomes an issue. Because the heat flows for the thermal
            % capacity that are present in the linear and radiative rate
            % matrix should impact the same capacity and the same
            % temperature value in the matrix. Therefore, we require a
            % transformation that gets the unique capacities from the
            % aoCapacities vector, and allows us to sum up temperature
            % change rates from linear and raidative part that impact the
            % same capacity:
            
            csUUID_LinearRateCapacities    = {this.aoCapacities(1:this.iFirstRadiativeCapacity-1).sUUID};
            csUUID_RadiativeRateCapacities = {this.aoCapacities(this.iFirstRadiativeCapacity:end).sUUID};
            iLinearCapacities              = this.iFirstRadiativeCapacity-1;
            iRadiativeCapacities           = length(csUUID_RadiativeRateCapacities);
            
            % If we have an afTemperatures vector as calculated by the
            % basic thermal multi branch solver we now want a matrix that
            % creates a unique afTemperatures Vector by summing up all
            % temperatures that occur twice.
            iNonUniqueCapacities = sum(this.abNonUniqueCapacity);
            this.mbNonUniqueCapacities = false(this.iCapacities - iNonUniqueCapacities, this.iCapacities);
            
            % There may be unique nodes that are radiative only, so we need
            % to count them here.
            iNumberOfUniqueRadiativeNodes = iRadiativeCapacities - iNonUniqueCapacities;
            
            for iLinearCapacity = 1:iLinearCapacities
                % The index for the linear capacity must be true
                % regardless, otherwise the temperatures of the linear
                % capacities would be set to 0 if no radiative capacity
                % is present
                this.mbNonUniqueCapacities(iLinearCapacity, iLinearCapacity) = true;
                
                % If the current capacity also has a radiative branch
                % attached to it, we will find it here.
                iRadiativeCapacity = find(strcmp(csUUID_LinearRateCapacities{iLinearCapacity}, csUUID_RadiativeRateCapacities), 1);
                
                % If we found an index, we also set it to true. 
                if ~isempty(iRadiativeCapacity)
                    this.mbNonUniqueCapacities(iLinearCapacity, iLinearCapacities + iRadiativeCapacity) = true;
                end
            end
            
            % Initializing a counter
            iUniqueRadiativeNodeCounter = 0;
            
            % Now we need to go through all radiative capacities and find
            % the ones that are radiative only, meaning the have no
            % conductive or convective branches attached to them.
            for iRadiativeCapacity = 1:iRadiativeCapacities
                % We look for the current capacity in the array of linear
                % capacities.
                iLinearCapacity = find(strcmp(csUUID_RadiativeRateCapacities{iRadiativeCapacity}, csUUID_LinearRateCapacities), 1);
                
                % Checking if we found it or not.
                if isempty(iLinearCapacity)
                    % We found one! So we increase the counter.
                    iUniqueRadiativeNodeCounter = iUniqueRadiativeNodeCounter + 1;
                    
                    % This is just a fail-safe to make sure nothing goes
                    % wrong and we find more nodes than actually exist.
                    if iUniqueRadiativeNodeCounter > iNumberOfUniqueRadiativeNodes
                        this.throw('Oops, something went wrong while creating the thermal solver network. Check radiative node setup.');
                    end
                    
                    % Now we can set the appropriate index in the
                    % mbNonUniqueCapacities matrix to true.
                    this.mbNonUniqueCapacities(iLinearCapacities + iUniqueRadiativeNodeCounter, iLinearCapacities + iRadiativeCapacity) = true;
                end
            end
            
            this.aoBranches(1).oContainer.bind('ThermalSolverCheck_post', @this.findExternalSolvers);
            
            % In the ODE function we need subset of the
            % mbNonUniqueCapacities matrix in its transposed form. This
            % subset only contains the radiative capacities. In order to
            % increase performance we store it in a property.
            mbNonUniqueCapacitiesTransposed = this.mbNonUniqueCapacities';
            this.mbRadiativeCapacities = mbNonUniqueCapacitiesTransposed(this.iFirstRadiativeCapacity:end, :);
            
            % Getting the temperatures of all capacities.
            afTemperatures = [this.aoCapacities.fTemperature]';
            
            % Only use the unique temperatures for the ode solver
            this.afTemperatures = afTemperatures(~this.abNonUniqueCapacity);
            
            % Now we have to register this solver with the network
            % capacities:
            this.aoUniqueCapacities = this.aoCapacities(~this.abNonUniqueCapacity);
            this.iUniqueCapacities  = length(this.aoUniqueCapacities);
            arrayfun(@(oCapacity, iIndex) oCapacity.setHandler(this, iIndex), this.aoUniqueCapacities, (1:this.iUniqueCapacities)');
            
            % Define rate of change function for ODE solver.
            this.hCalculateTemperatureChangeRate = @(t, m) this.calculateTemperatureChangeRate(m, t);
            
            this.setTimeStep = this.oTimer.bind(@(~) this.registerUpdate(), this.fTimeStep);
            
            this.setTimeStep(this.fTimeStep);
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed.
            %
            % The thermal multi branch solver is executed after the
            % capacities, heat sources and normal thermal solvers.
            this.hActuallyBindPostTick = this.oTimer.registerPostTick(@this.update, 'thermal' , 'multibranch_solver');
            this.hBindPostTickUpdate = @this.bindPostTickUpdate;
            
        end
        
        function findExternalSolvers(this, ~)
            % For the capacities we also have to check if external non
            % multi solver heat flow branches are connected to them.
            % These will be handled like heat sources in the multi
            % branch solver:
            this.coNonSolverBranches = cell(this.iUniqueCapacities,1);
            this.ciNonSolverSigns    = cell(this.iUniqueCapacities,1);
            for iCapacity = 1:this.iUniqueCapacities
                aoCapacityBranches = [this.aoUniqueCapacities(iCapacity).aoExmes.oBranch];
                
                mbExternalBranch = false(1,length(aoCapacityBranches));
                for iBranch = 1:length(aoCapacityBranches)
                    if aoCapacityBranches(iBranch).oHandler ~= this
                        mbExternalBranch(iBranch) = true;
                        this.bExternalSolvers = true;
                    end
                end
                this.coNonSolverBranches{iCapacity} = {aoCapacityBranches(mbExternalBranch)'};
                
                % Now we have to bind the update of this solver to the
                % update of the external branches, to ensure the solver
                % notices a heat flow change in the external solvers
                coBranches = this.coNonSolverBranches{iCapacity};
                ciSigns = cell(1, length(coBranches));
                aoExternalBranches = coBranches{1};
                for iExternalBranch = 1:sum(mbExternalBranch)
                    aoExternalBranches(iExternalBranch).bind('outdated', @this.bindPostTickUpdate);
                    
                    if this.aoUniqueCapacities(iCapacity) == aoExternalBranches(iExternalBranch).coExmes{1}.oCapacity
                        ciSigns{iExternalBranch} = aoExternalBranches(iExternalBranch).coExmes{1}.iSign;
                    else
                        ciSigns{iExternalBranch} = aoExternalBranches(iExternalBranch).coExmes{2}.iSign;
                    end
                end
                this.ciNonSolverSigns{iCapacity} = ciSigns;
            end
            
        end
    end
    
    methods (Access = protected)
        
        function bindPostTickUpdate(this, ~)
            if this.bPostTickUpdateNotBound
                this.bPostTickUpdateNotBound = false;
                this.hActuallyBindPostTick();
            end
        end
        
        function mfTemperatureChangeRate = calculateTemperatureChangeRate(this, afCurrentTemperatures, ~)
            % Calculates the rate of temperature change. This function is
            % called by the ODE solver at each internal timestep of the ODE
            % solver. It returns the "right side" of the equation |T' =
            % f(t, T)|.
            %
            % The last parameter is the current time at the solver
            % iteration step. It is not used here.
            
            % We need an array of all node temperatures as they are used in
            % the linear system of equations. That means that all linear
            % temperatures can be used as is, while the radiative
            % temperatures need to be raised to the power of four. 
            
            % First we get the linear temperatures, which are just the
            % first part of the afCurrentTemperatures array up until the
            % index this.iFirstRadiativeCapacity-1.
            afLinearNodeTemperatures = afCurrentTemperatures(1:this.iFirstRadiativeCapacity-1);
            
            % Now we get the radiative node temperatures by multiplying the
            % current temperatures with the radiative capacities boolean matrix.
            afRadiativeNodeTemperatures = this.mbRadiativeCapacities * afCurrentTemperatures.^4;
            
            % To get the full temperature array we now concatenate the two
            % arrays we just produced.
            afNonUniqueCurrentTemperatures = [afLinearNodeTemperatures; afRadiativeNodeTemperatures];
            
            mfNonUniqueTemperatureChangeRate = this.mfTemperatureChangeRateMatrix * afNonUniqueCurrentTemperatures;
            
            mfTemperatureChangeRate = (this.mbNonUniqueCapacities * mfNonUniqueTemperatureChangeRate) + this.afSourceRateVector;
        end
        
        function update(this)
            % update the thermal solver
            if this.oTimer.fTime == this.fLastUpdate
                this.bPostTickUpdateNotBound = true;
                return
            end
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
            afBranchResistancesNoZeros = afBranchResistances;
            afBranchResistancesNoZeros(afBranchResistancesNoZeros == 0) = 1;
            % Now we can simply use a vector matrix operation to get the
            % current conductivity matrix
            mfConductivityMatrix = this.mfConnectivityMatrix ./ afBranchResistancesNoZeros;
            mfConductivityMatrix(afBranchResistances == 0, :) = mfConductivityMatrix(afBranchResistances == 0, :) * 1e10;
            
            this.mfTemperatureChangeRateMatrix = this.mfTotalHeatCapacityMatrix * mfConductivityMatrix;

            fStepBeginTime = this.fLastUpdate;
            fStepEndTime   = this.oTimer.fTime;
            this.fExecutionTimeStep = fStepEndTime - fStepBeginTime;
            
            this.afSourceRateVector = [this.aoCapacities(~this.abNonUniqueCapacity).fTotalHeatSourceHeatFlow]';
            
            if this.bExternalSolvers
                afExternalHeatFlows= zeros(this.iUniqueCapacities, 1);
                for iCapacity = 1:this.iUniqueCapacities
                    afExternalHeatFlows(iCapacity) = sum([this.ciNonSolverSigns{iCapacity}{:}] .* [this.coNonSolverBranches{iCapacity}{:}.fHeatFlow]);
                end
                this.afSourceRateVector = this.afSourceRateVector + afExternalHeatFlows;
            end
            
            this.afSourceRateVector = this.afSourceRateVector ./ [this.aoCapacities(~this.abNonUniqueCapacity).fTotalHeatCapacity]';
            
            [this.mfTimePoints, this.mfSolutionTemperatures] = ode45(this.hCalculateTemperatureChangeRate, [fStepBeginTime, fStepEndTime], this.afTemperatures, this.tOdeOptions);
            
            this.afTemperatures = this.mfSolutionTemperatures(end,:)';
            
            for iCapacites = 1:this.iUniqueCapacities
                this.aoUniqueCapacities(iCapacites).updateTemperature();
            end
            
            this.fLastUpdate = this.oTimer.fTime;
            this.bRegisteredOutdated = false;
            this.bPostTickUpdateNotBound = true;
            
            if this.bTriggerUpdateCallbackBound
                this.trigger('update');
            end
        end
    end
end
