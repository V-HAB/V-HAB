classdef branch < base & event.source
        %% General Information
    % This solver is used to solve networks of branches including gas flow
    % nodes. Gas flow nodes are basically phases that are considered to
    % have no mass and therefore allow the representation of very small
    % volumes in V-HAB (e.g. of T-pieces). The solver is provided an array
    % contain the objects of the branches (aoBranches) that it is supposed
    % to solve. There is no limit to the number of branches that it can
    % solve.
    %
    %% Regaring the implementation some rules must be observed!:
    %
    % - it is not possible to have a gas flow node as the connection
    %   between two different multi branch solvers!
    %
    % - If an active component is used, it must have a gas flow node on
    %   either side of the branch in which it is located and cannot have
    %   any other flow to flow proc inside the branch where it is located!
    %
    % - loops can be solved but should have at least one "normal"
    %   (boundary) phase in between. Full loops consisting only of gas flow
    %   nodes are not possible!
    %
    % - P2Ps used together with this solver must implement the
    %   calculateFlowRate(afInFlowRates, aarInPartials) function, which
    %   can take an array of inflows with corresping partial mass ratios to
    %   calculate the p2p flow rate
    %
    % - The solver is incompatible with a residual solver, unless the phase
    %   in which this connection takes place is a boundary (normal) phase,
    %   which does not have the bFlow parameter set to true! The reason for
    %   this is that the solver cannot differentiate between a residual
    %   solver and another solver, and would handle the old residual solver
    %   flowrate (as this solver is calculated before the residual solver)
    %   as a boundary conditions while the residual solver would then
    %   change its flowrate after the calculation again. Instead simply add
    %   the branches for which you wanted to use a residual solver to the
    %   system solved by this solver!
    %
    %% Information about the possible parameters that can be changed for the solver
    %
    %   Please view the commenting of the setSolverProperties function for
    %   information on the parameters and options for the solver! If you
    %   want to change one also use that function to do so
    %
    %% Information and Tips on Debugging
    %
    % - Maximum number of iterations reached:
    %   In this case the solver should stop (by a keyboard command) and you
    %   can use the command plot(mfFlowRates) to view the course of the
    %   branch flowrates over the calculation, if they are converging and
    %   not osciallating (zoom in if you have very different flowrates!)
    %   but you reached this error, you can try simply increasing the value
    %   for the maximum iterations.
    %   If your solver is oscillating in every iteration, most likely one
    %   of your flow to flow components has large changes in the delta
    %   pressure for small flowrate changes or jumps in this (e.g. at the
    %   transition between laminar and turbulent flow). Please check which
    %   branch is oscillating and review your f2fs to make sure that this
    %   is not the case!
    %   If the solver converges to a value but then jumps to a different
    %   value again and repeats this the recalculation of a p2p throws your
    %   solver of. This can happen e.g. if the p2p flowrates changes a lot
    %   for small flowrates changes or oscillates due to some other reason.
    %   In this case please check which branch is oscillating, then check
    %   to which gas flow node it is connected and which p2p flowrates
    %   influence it. Then check if that p2p flowrate is changing in
    %   unintended ways!
    %
    % - If you received NAN values because the determinant of aafPhasePressuresAndFlowRates
    %   is 0 (calculate with det(aafPhasePressuresAndFlowRates)) then you
    %   probably have a wrong valve at some location that cut off gas flow
    %   nodes from any boundary node, but they have a non zero external
    %   flowrate
    % - Another reason for returning NaN values is the implementation of
    %   fans. These require
    % 
    %
    % - You received an error of any different type? Please contact your
    %   supervisor!
    %
    %% Additional Information regarding the solving process
    %
    % This information can also be found (in better formatting) on the wiki
    % page: XXXX TO DO
    %
    % The solver creats a matrix from the provied branches which represents
    % the branch pressure drops, the gas flow node pressures and equations
    % that enforce that gas flow nodes have no mass change. Additionally
    % branches not solved by this system but connected to it at any phase
    % and p2ps are handled as boundary conditions together with the
    % pressures of "normal" phases.
    %
    % The equations containing the gas flow node pressures and the branch
    % pressure drops have a boundary phase pressure as boundary condition.
    % These equations represent the pressure difference between two
    % boundary phases. The total pressure drop between these must be equal
    % to this pressure difference (in semi static conditions we neglect the 
    % part where the flow is accelerated and this is not the case).
    % 
    % The only exception for this are branches containing active components, 
    % the pressure rise of these is handled as a boundary condition and the
    % equation from this row should only have two gas flow node pressures
    % to solve! 
    %
    % The second part of the matrix contains only 1 and -1 entries and
    % represents the in and outgoing flowrates of the gas flow nodes. The
    % boundary conditions for these rows are the sum of external flowrates
    % (from p2ps and other branches) for these gas flow nodes. Overall,
    % these equations enforce that the gas flow nodes have no mass change
    % as all in and outgoing flowrates solved by this system must be
    % exactly the boundary condition times -1
    %
    % For Example: In the tutorial case (without additional parameter)
    % this was the matrix:
    %
    % aafPhasePressuresAndFlowRates =
    % 
    %    1.0e+04 *
    % 
    %    -0.0001   -1.0890         0         0         0         0         0
    %     0.0001         0   -0.0001   -1.0890         0         0         0
    %          0         0    0.0001         0   -0.0001   -1.0890         0
    %          0         0         0         0    0.0001         0   -1.0890
    %          0         0         0    0.0001         0   -0.0001         0
    %          0    0.0001         0   -0.0001         0         0         0
    %          0         0         0         0         0    0.0001   -0.0001
    %               
    % and 
    % afBoundaryConditions =
    % 
    %      -100200
    %            0
    %            0
    %       100000
    %            0
    %            0
    %            0
    %
    % now basically this would translate into the following system of
    % equations: (1.089e4 will be written as 1e4
    %
    % - x1 - 1e4 x2                                             = -100200   (I)
    % + x1          -  x3 - 1e4 x4                              = 0         (II)
    %               +  x3               - x5 -  1e4 x6          = 0         (III)
    %                                   + x5 -         - 1e4 x7 = 100000    (IV)
    %                     +     x4           -      x6          = 0         (V)
    %      +     x2      -      x4                              = 0         (VI)
    %                                        +      x6 -     x7 = 0         (VII)
    %
    % According to this.poColIndexToObj the columns represent the following
    % objects: (phases are gas flow nodes)
    %   x1 ,  x2   ,  x3  ,   x4  ,   x5 ,   x6  ,  x7
    % phase, branch, phase, branch, phase, branch, branch
    %
    % Therefoe there are three types of equations within this system:
    %
    % Equation (I) is -BoundaryPress + Pressure - C*m_dot = 0 
    % which is the condition that the pressure difference in the branch has to
    % be equal to the pressure difference between the two boundaries
    %
    % Equations (II) and (III) represent the same condition just not between a
    % boundary and gas flow node, but between two gas flow nodes
    %
    % Equation (IV) is BoundaryPress - Pressure + C*m_dot, which is the same as
    % Eqation I just with a different sign (as it is the boundary conditions
    % from the other side)
    %
    % Equations (V) (VI) and (VII) mean that these flowrates have to sum up to zero
    
    
    properties (SetAccess = private, GetAccess = private)
        % cell containing the handles of the set flow rate functions of the
        % individual branches in this network
        chSetBranchFlowRate;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
        
    end
    
    properties (SetAccess = private, GetAccess = public)
       	% array containing the branches which are solved by this solver
        aoBranches;
        % number of total branches in the network
        iBranches;
        
        % last time at which the solver was updated
        fLastUpdate = -10;
        
        % Mode:
        %   * simple: coeffs for f2fs, fan dP = f(fr, density), p2p = flow
        %     rates from last tick used. Currently not working!
        %
        %   * complex: f2f callbacks for dP, fan callback, p2p immediately
        %     called in every iteration for absorption rate (requires
        %     specific method in p2p)
        sMode = 'complex';
        
        iLastWarn = -1000;
        
        bFinalLoop = false;
    end
    
    properties (SetAccess = private, GetAccess = protected) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        bRegisteredOutdated = false;
        
        hBindPostTickUpdate;
        hBindPostTickTimeStepCalculation;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Solving mechanism supported by the solver
        sSolverType;
        
        % Cached solving objects (from [procs].toSolver.coefficient)
        aoSolverProps;
        
        % Reference to the matter table
        % @type object
        oMT;
        
        oTimer;
        
        iIteration = 0;
        
        % Variable pressure phases by UUID
        poVariablePressurePhases;
        
        % Boundary nodes
        poBoundaryPhases;
        
        % Maps variable pressure phases / branches, using their UUIDs, to
        % the according column in the solving matrix
        piObjUuidsToColIndex;
        
        % Maps variable which provides the corresponding object to a column
        % index number (each column represents either a gas flow node or a
        % branch)
        poColIndexToObj;
        
        
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        csVariablePressurePhases;
        csObjUuidsToColIndex;
        csBoundaryPhases;
        
        % Sum of flow coeffs for each branch
        % For volumetric flow rate!
        afPressureDropCoeffsSum;
        
        %% Solver Properties
        % The maximum error represents the allowed remaining difference
        % between the currently calculated flowrates and the previous
        % flowrates in percent. This means once the difference of the
        % flowrates for all branches is smaller than this the solver
        % considers the system solved
        fMaxError = 1e-4; % percent
        % The maximum number of iterations defines how often the solver
        % iterates before resulting in an error
        iMaxIterations = 1000;
        % This value can be used to force more frequent P2P updates (every
        % X iterations). Or the standard approach is to have the solver
        % solve the branch flowrates and then calculate the P2P flowrates.
        % Once the P2P flowrates are calculate, iterate through the system
        % again till converged. This is repeated until overall convergence
        % is achieved
        iIterationsBetweenP2PUpdate = 1000;
        % The solver calculates a maximum time step, after which the phases
        % equalized their pressures. If this time step is exceed
        % oscillations can occur. This timestep represents the lowest
        % possible value for that time step (indepdentent from phase time
        % steps)
        fMinimumTimeStep = 1e-8; % s
        % The minimum pressure difference defines how many Pa of pressure
        % difference must be present before the solver starts calculating
        % the branch. If the difference is below the value, the branch will
        % be considered to have no pressure difference and therefore to
        % have 0 kg/s flowrate
        fMinPressureDiff = 10; % Pa
        
        tBoundaryConnection;
        
        % Last values of caclulated flow rates.
        afFlowRates;
        arPartialsFlowRates;
        
        % Temporary - active flow f2f procs - pressure rise (or drop)
        afTmpPressureRise;
        
        % Matrix that translated the index of a branch from aoBranches to a
        % row in the solution matrix
        miBranchIndexToRowID;
        
        % Integer that tells us how many branches are connected in a row.
        % These must be solved after each other to get the correct p2p
        % flows
        iBranchUpdateLevels;
        
        % boolean matrix that has one row per update level. Each column
        % represents a branch and is true if the branch should be updated
        % in this update level
        mbBranchesPerUpdateLevel;
        
        % For branches that are not connected to a boundary node, but
        % enforce a constant flowrate boundary condition (not from p2ps) we
        % require a matrix to store the indices to handle them correctly in
        % the update level calculation
        mbExternalBoundaryBranches;
        iNumberOfExternalBoundaryBranches = 0;
    end
    
    
    methods
        function this = branch(aoBranches, sMode)
            
            if (nargin >= 2) && ~isempty(sMode)
                this.sMode = sMode;
            end
            
            if strcmp(this.sMode, 'complex')
                this.sSolverType = 'callback';
            else
                this.sSolverType = 'coefficient';
            end
            
            this.aoBranches = aoBranches;
            this.iBranches  = length(this.aoBranches);
            this.mbExternalBoundaryBranches = zeros(this.iBranches,1);
            this.oMT        = this.aoBranches(1).oMT;
            this.oTimer     = this.aoBranches(1).oTimer;
            
            % Preset
            this.afTmpPressureRise = zeros(1, this.iBranches);
            
            this.chSetBranchFlowRate = cell(1, this.iBranches);
            
            for iB = 1:this.iBranches 
                this.chSetBranchFlowRate{iB} = this.aoBranches(iB).registerHandler(this);
                
                this.aoBranches(iB).bind('outdated', @this.registerUpdate);
            end
            
            
            this.setTimeStep = this.oTimer.bind(@(~) this.registerUpdate(), inf);
            
            % The solver itself is calculated before the residual solvers. This
            % may lead to problems if a residual solver is used as input to
            % this system directly (not with a boundary phase inbetween) as the
            % flowrate of the residual solver is assumed to be constant
            % boundary condition for one tick, while it can actually change
            % before the tick ends. Therefore residual solvers should only be
            % used as input with a boundary phase inbetween that reaches the
            % necessary pressure to supply the system the correct flowrate
            this.hBindPostTickUpdate = this.oTimer.registerPostTick(@this.update, 'matter', 'multibranch_solver');
            this.hBindPostTickTimeStepCalculation = this.oTimer.registerPostTick(@this.calculateTimeStep, 'post_physics', 'timestep');
            
            this.initialize();
        end
        
        function setSolverProperties(this, tSolverProperties)
            % currently the possible time step properties that can be set
            % by the user are:
            %
            % fMaxError:    Maximum Error of the solution in Pa, also
            %               decides when the solver should be recalculated
            %               in case the boundary conditions have changed
            % iMaxIterations: Sets the maximum value for iterations, if it
            %                 is exceed the solver throws an error
            %
            % iIterationsBetweenP2PUpdate: maximum number of iterations
            %               between each update of the P2Ps, if this is
            %               higher than the maximum iterations the P2Ps are
            %               only recalculated once the solver converges,
            %               then the solver must converge again, till
            %               overall convergence is achieved
            %
            % fMinimumTimeStep: The solver calculates a maximum time step,
            %                   after which the phases equalized their
            %                   pressures. If this time step is exceed
            %                   oscillations can occur. This timestep
            %                   represents the lowest possible value for
            %                   that time step (indepdentent from phase
            %                   time steps)
            %
            % fMinPressureDiff: The minimum pressure difference defines how
            %                   many Pa of pressure difference must be
            %                   present before the solver starts
            %                   calculating the branch. If the difference
            %                   is below the value, the branch will be
            %                   considered to have no pressure difference
            %                   and therefore to have 0 kg/s flowrate
            %
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            csPossibleFieldNames = {'fMaxError', 'iMaxIterations', 'iIterationsBetweenP2PUpdate', 'fMinimumTimeStep', 'fMinPressureDiff'};
            
            % Gets the fieldnames of the struct to easier loop through them
            csFieldNames = fieldnames(tSolverProperties);
            
            for iProp = 1:length(csFieldNames)
                sField = csFieldNames{iProp};

                % If the current properties is any of the defined possible
                % properties the function will overwrite the value,
                % otherwise it will throw an error
                if ~any(strcmp(sField, csPossibleFieldNames))
                    error(['The function setSolverProperties was provided the unknown input parameter: ', sField, ' please view the help of the function for possible input parameters']);
                end
                

                % checks the type of the input to ensure that the
                % correct type is used.
                xProperty = tSolverProperties.(sField);

                if ~isfloat(xProperty)
                    error(['The ', sField,' value provided to the setSolverProperties function is not defined correctly as it is not a (scalar, or vector of) float']);
                end
                
                this.(sField) = tSolverProperties.(sField);
            end
        end
    end
    
    
    methods (Access = protected)
        function initialize(this)
            % Initialized variable pressure phases / branches
            
            this.poVariablePressurePhases = containers.Map();
            this.piObjUuidsToColIndex     = containers.Map();
            this.poBoundaryPhases         = containers.Map();
            this.poColIndexToObj          = containers.Map('KeyType', 'uint32', 'ValueType', 'any');
            
            iColIndex = 0;
            
            for iBranch = 1:this.iBranches
                abIsFlowNode = [false, false];
                for iPhase = 1:2
                    oPhase = this.aoBranches(iBranch).coExmes{iPhase}.oPhase;
                    
                    % Variable pressure phase - add to reference map if not
                    % present yet, generate index for matrix column
                    if isa(oPhase, 'matter.phases.flow.flow')
                        abIsFlowNode(iPhase) = true;
                        if ~this.poVariablePressurePhases.isKey(oPhase.sUUID)

                            this.poVariablePressurePhases(oPhase.sUUID) = oPhase;

                            iColIndex = iColIndex + 1;

                            this.piObjUuidsToColIndex(oPhase.sUUID) = iColIndex;
                            this.poColIndexToObj(iColIndex) = oPhase;
                        end
                        
                    % 'Real' phase - boundary condition
                    else
                        abIsFlowNode(iPhase) = false;
                        if ~this.poBoundaryPhases.isKey(oPhase.sUUID)
                            this.poBoundaryPhases(oPhase.sUUID) = oPhase;
                        end
                    end
                    
                    oPhase.bind('update_post', @this.registerUpdate);
                end
                
                
                iColIndex = iColIndex + 1;
                oBranch = this.aoBranches(iBranch);
                
                this.piObjUuidsToColIndex(oBranch.sUUID) = iColIndex;
                this.poColIndexToObj(iColIndex) = oBranch;
                
                % Init
                this.chSetBranchFlowRate{iBranch}(0, []);
                
            end
            
            
            this.csVariablePressurePhases = this.poVariablePressurePhases.keys();
            this.csObjUuidsToColIndex     = this.piObjUuidsToColIndex.keys();
            this.csBoundaryPhases         = this.poBoundaryPhases.keys();
        end
        
        function registerUpdate(this, ~)
            % this function registers an update
            % TO DO: provide more information on this in the wiki
            if ~base.oDebug.bOff, this.out(1, 1, 'reg-post-tick', 'Multi-Solver - register outdated? [%i]', { ~this.bRegisteredOutdated }); end
            
            if this.bRegisteredOutdated
                return;
            end
            
            this.bRegisteredOutdated = true;
            
            for iB = 1:this.iBranches
                for iE = 1:2
                    this.aoBranches(iB).coExmes{iE}.oPhase.registerMassupdate();
                end
            end
            
            this.hBindPostTickUpdate();
            this.hBindPostTickTimeStepCalculation();
            
        end
        
        function calculateTimeStep(this)
            %% time step limitation
            % Bound to a post tick level after the residual branches.
            % Then all external flowrates are fix for this tick as well and
            % the calculated time step is definitly correct!
            %
            % Now check for the maximum allowable time step with the
            % current flow rate (the pressure differences in the branches
            % are not allowed to change their sign within one tick)
            for iBoundaryPhase = 1:this.poBoundaryPhases.Count
                oBoundary = this.poBoundaryPhases(this.csBoundaryPhases{iBoundaryPhase});
                
                tfTotalMassChangeBoundary.(oBoundary.sUUID) = 0;
                for iExme = 1:length(oBoundary.coProcsEXME)
                    tfTotalMassChangeBoundary.(oBoundary.sUUID) = tfTotalMassChangeBoundary.(oBoundary.sUUID) + (oBoundary.coProcsEXME{iExme}.iSign * oBoundary.coProcsEXME{iExme}.oFlow.fFlowRate);
                end
            end
            
            % This calculation compares the mass change of only the
            % connected boundary phases, which actually exchange mass. For
            % them the total mass change is compared to calculate the
            % maximum allowable time step. However, temperature changes are
            % neglected here so in some cases this limitation might not be
            % sufficient
            fTimeStep = inf;
            if ~isempty(this.tBoundaryConnection)
                csBoundaries = fieldnames(this.tBoundaryConnection);
                if length(csBoundaries) > 1
                    for iBoundaryLeft = 1:length(csBoundaries)
                        if isempty(this.tBoundaryConnection.(csBoundaries{iBoundaryLeft}))
                            continue
                        else
                            try
                                coRightSide = this.tBoundaryConnection.(csBoundaries{iBoundaryLeft});

                                oLeftBoundary = this.poBoundaryPhases(csBoundaries{iBoundaryLeft});

                            catch
                                continue
                            end
                            if isempty(oLeftBoundary) || isempty(coRightSide)
                                continue
                            end
                            for iBoundaryRight = 1:length(coRightSide)
                                oRightBoundary = coRightSide{iBoundaryRight};

                                fPressureDifference = oLeftBoundary.fMass * oLeftBoundary.fMassToPressure - oRightBoundary.fMass * oRightBoundary.fMassToPressure;

                                if abs(fPressureDifference) < this.fMinPressureDiff
                                    fPressureDifference = sign(fPressureDifference) * this.fMinPressureDiff;
                                end
                                % (p * delta_t * massflow * masstopressure)_Left =
                                % (p * delta_t * massflow * masstopressure)_Right
                                fPressureChangeRight = (tfTotalMassChangeBoundary.(oRightBoundary.sUUID) * oRightBoundary.fMassToPressure);
                                fPressureChangeLeft  = (tfTotalMassChangeBoundary.(oLeftBoundary.sUUID) * oLeftBoundary.fMassToPressure);

                                % For a positive pressure difference, if the left
                                % pressure increases more than the right pressure,
                                % no sign change will ever occur. Similar for a
                                % negative pressure difference if the right
                                % pressure increases more than left pressure this
                                % will not occur
                                if fPressureDifference > 0 && fPressureChangeLeft > fPressureChangeRight
                                    fNewStep = inf;
                                elseif fPressureDifference < 0 && fPressureChangeLeft < fPressureChangeRight
                                    fNewStep = inf;
                                else
                                    fNewStep = abs(fPressureDifference/(fPressureChangeRight - fPressureChangeLeft));
                                end

                                % 0 Means we have reached equalization, therefore this can also
                                % be ignored for max time step condition
                                if fNewStep < fTimeStep && fNewStep ~= 0
                                    fTimeStep = fNewStep;
                                end
                            end
                        end
                    end
                end
            end
            if fTimeStep < this.fMinimumTimeStep
                fTimeStep = this.fMinimumTimeStep;
            end
            this.setTimeStep(fTimeStep);
        end
    end
end
