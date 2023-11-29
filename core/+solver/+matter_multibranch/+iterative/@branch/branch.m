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
    %% Regarding the implementation some rules must be observed!:
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
    % According to this.coColIndexToObj the columns represent the following
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
       	% array containing the branches that are solved by this solver
        aoBranches;
        
        % number of total branches in the network
        iBranches;
        
        % A cell containing all UUIDs of the branches that are solved by
        % this solver. 
        csBranchUUIDs;
        
        % Last time the solver was updated
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
        
        % A flag to decide if the solver is already outdated or not
        bRegisteredOutdated = false;
        
        % In recursive calls within the post tick where the solver itself
        % triggers outdated calls up to the point where it is set outdated
        % again itself it is possible for the solver to get stuck with a
        % true bRegisteredOutdated flag. To prevent this we also store the
        % last time at which we registered an update
        fLastSetOutdated = -1;
    end
    
    properties (SetAccess = private, GetAccess = protected) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        
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
        toVariablePressurePhases;
        
        % Boundary nodes
        toBoundaryPhases;
        
        % Struct variable pressure phases / branches, using their UUIDs, to
        % the according column in the solving matrix
        tiObjUuidsToColIndex;
        
        tiObjUuidsToRowIndex;
        
        % Cell variable that provides the corresponding object to a column
        % index number (each column represents either a gas flow node or a
        % branch)
        coColIndexToObj;
        
        
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
        
        % This boolean can be turned on, if you want the multi branch
        % solver to solve only the flowrates for its branches. In that case
        % it uses the average boundary phase pressure to calculate the
        % pressure for the flow phases
        bSolveOnlyFlowRates = false;
        
        tBoundaryConnection;
        
        % Last values of caclulated flow rates.
        afFlowRates;
        arPartialsFlowRates;
        
        % Matrix that translated the index of a branch from aoBranches to a
        % row in the solution matrix
        miBranchIndexToRowID;
        
        % This vector can be used to translate column ids to branch ids
        miColIndexToBranchID;
        
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
        
        fInitializationFlowRate;
        
        % As a performance enhancement, these booleans are set to true once
        % a callback is bound to the 'update' and 'register_update'
        % triggers, respectively. Only then are the triggers actually sent.
        % This saves quite some computational time since the trigger()
        % method takes some time to execute, even if nothing is bound to
        % them.
        bTriggerUpdateCallbackBound = false;
        bTriggerRegisterUpdateCallbackBound = false;
        
        % The current time step of the solver in seconds
        fTimeStep;
        
        % Boolean indicating if oscillation suppression is turned on at all
        % for all branches. 
        bOscillationSuppression = true;
        
        % A boolean array indicating which branches are being corrected for
        % oscillating in the current update step.
        abOscillationCorrectedBranches;
        
        % A boolean used in the update() method to skip the 'too many
        % iterations' error when the oscillating branches have been
        % corrected. 
        bBranchOscillationSuppressionActive = false;
        
        % A boolean that is set to true while the update() method of this
        % class is being run. It is used by the flow phase objects to
        % determine if it is safe to use their afPP and rRelHumidity
        % properties or not. During the update those properties may change
        % between solver iterations.
        bUpdateInProgress = false;
        
        % This matrix contains a row for each branch and two columns (one
        % for each exme) which contain a boolean to quickly decide whether
        % the connected phase has a flow P2P connected to it
        mbFlowP2P;
        coFlowP2P;
        ciFlowP2PSign;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        %% Properties related to choked flow checking
        
        % This boolean array identifies those branches that are to be
        % checked for choked flow conditions. Since this is a fairly
        % complex calculation, it can be turned on and off per branch,
        % rather than globally. To enable this functionality, just pass the
        % branch object you want to montior to the
        % activateChokedFlowChecking() method of this class.
        abCheckForChokedFlow;
        
        % This boolean array contains all branches that contain a choked
        % flow for a given iteration of the solver.
        abChokedBranches;
        
        % This cell contains the pressure drop values for each branch with
        % a choked flow. We need these values as inputs to the
        % setBranchFlowRate callback. The values for the pressure
        % differences are calculated in the
        % updatePressureDropCoefficients() method of this class.
        cafChokedBranchPressureDiffs;
        
        % The following three properties capture the pressure, temperature
        % partial mass, adiabatic index and initialization state of the
        % flow through the branches where choked flow checking is
        % activated. This is done in an effort to reduce the calls to
        % calculateAdiabaticIndex() in the matter table. See
        % checkForChokedFlow() for details.
        afPressureLastCheck;
        afTemperatureLastCheck;
        mrPartialMassLastCheck;
        afAdiabaticIndex;
        abChokedFlowCheckInitialized;
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
            % through subsystems it is possible that two different
            % multibranch solvers are combined. Therefore we check the
            % branches added to this solver for flow phases and branches
            % that are solved by a different multibranch solver. If we find
            % this to be the case, we do not create a new multibranch
            % solver, but instead add the branches which were supposed to
            % be used for this multibranch solver and add them to other
            % multibranch solver. The Solver properties therefore are only
            % overwritten if the limitations are harsher or if the user
            % specifically request these properties to be used.
            [bFoundOtherSolver, oSolver] = this.findOtherMultiSolver(aoBranches);
            if bFoundOtherSolver
                this = oSolver;
                return
            end
            % Initializing a bunch of properties
            this.aoBranches                     = aoBranches;
            this.iBranches                      = length(this.aoBranches);
            this.abCheckForChokedFlow           = false(this.iBranches,1);
            this.abChokedBranches               = false(this.iBranches,1);
            this.cafChokedBranchPressureDiffs   = cell(this.iBranches,1);
            this.abChokedFlowCheckInitialized   = false(this.iBranches,1);
            this.afPressureLastCheck            = zeros(this.iBranches,1);
            this.afTemperatureLastCheck         = zeros(this.iBranches,1);
            this.afAdiabaticIndex               = zeros(this.iBranches,1);
            this.mrPartialMassLastCheck         = zeros(this.iBranches,this.aoBranches(1).oMT.iSubstances);
            this.abOscillationCorrectedBranches = false(this.iBranches,1);
            this.mbExternalBoundaryBranches     = zeros(this.iBranches,1);
            this.oMT                            = this.aoBranches(1).oMT;
            this.oTimer                         = this.aoBranches(1).oTimer;
            
            % Preset
            this.chSetBranchFlowRate = cell(1, this.iBranches);
            
            for iB = 1:this.iBranches 
                this.chSetBranchFlowRate{iB} = this.aoBranches(iB).registerHandler(this);
                
                this.aoBranches(iB).bind('outdated', @this.registerUpdate);
                
                this.csBranchUUIDs{iB} = this.aoBranches(iB).sUUID;

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
            % bOscillationSuppression: In some cases the solver may be
            %                   oscillating around a very small value. This
            %                   will still cause the error to be larger
            %                   than the maximum error. This setting can be
            %                   used to just set the flow rate to the mean
            %                   value of the last 500 iterations. 
            %
            % bSolveOnlyFlowRates: This can be turned on to allow the
            %                      solver to only solve flowrates and
            %                      not calculate the flow pressures
            %
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            csPossibleFieldNames = {'fMaxError', 'iMaxIterations', 'iIterationsBetweenP2PUpdate', 'fMinimumTimeStep', 'fMinPressureDiff', 'bOscillationSuppression', 'bSolveOnlyFlowRates'};
            
            % Gets the fieldnames of the struct to easier loop through them
            csFieldNames = fieldnames(tSolverProperties);
            
            for iProp = 1:length(csFieldNames)
                sField = csFieldNames{iProp};

                % If the current properties is any of the defined possible
                % properties the function will overwrite the value,
                % otherwise it will throw an error
                if ~any(strcmp(sField, csPossibleFieldNames))
                    error('VHAB:MatterMultiBranch:UnknownParameter',['The function setSolverProperties was provided the unknown input parameter: ', sField, ' please view the help of the function for possible input parameters']);
                end
                

                % checks the type of the input to ensure that the
                % correct type is used.
                xProperty = tSolverProperties.(sField);

                if strcmp(sField, 'bSolveOnlyFlowRates')
                    if ~islogical(xProperty) || length(xProperty) ~= 1
                        error('VHAB:MatterMultiBranch:IncorrectParameter',['The ', sField,' value provided to the setSolverProperties function is not defined correctly as it is not a scalar boolean']);
                    end
                else
                    if ~isfloat(xProperty)
                        error('VHAB:MatterMultiBranch:IncorrectParameter',['The ', sField,' value provided to the setSolverProperties function is not defined correctly as it is not a (scalar, or vector of) float']);
                    end
                end
                
                this.(sField) = tSolverProperties.(sField);
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
        
        function activateChokedFlowChecking(this, oBranch)
            % Activates the choked flow checking for the branch object that
            % has been passed to this function. 
            
            % Finding the branch object in our aoBranches array
            iBranch = find(this.aoBranches == oBranch, 1);
            
            % If it is present, we set the appropriate field in the
            % abCheckForChokedFlow property to true. Otherwise we let the
            % user know.
            if ~isempty(iBranch)
                this.abCheckForChokedFlow(iBranch) = true;
            else
                % Getting the custom name if it is set, otherwise use the
                % standard name.
                if ~isempty(oBranch.sCustomName)
                    sName = oBranch.sCustomName;
                else
                    sName = oBranch.sName;
                end
                
                % Throwing up the error message.
                this.throw('ActivateChokedFlow','Could not activate choked flow checking for branch ''%s'' because it is not part of this multi-branch solver.',sName);
            end
        end
        
        function [ bChokedFlow, fChokedFlowRate, iChokedProc, fPressureDiff ] = checkForChokedFlow(this, iBranch)
            % Checks a specified branch for possible choked flow. 
            % 
            % Input argument is the index of the branch in the aoBranches
            % property of this class. 
            % 
            % Output arguments are: 
            % 
            % - bChokedFlow:     A boolean indicating if the flow in this
            %                    branch is choked at all.
            %
            % - fChokedFlowRate: Mass flow rate of the choked flow.
            % 
            % - iChokedProc:     Index of the processor in the branch with
            %                    the smallest hydraulic diameter, thus
            %                    causing the flow to be choked.
            % 
            % - fPressureDiff:   Pressure difference between the two phases
            %                    that the branch connects. This is returned
            %                    to enable the calculation of the
            %                    individual pressure differences for each
            %                    processor in the branch.
            % 
            
            % First we get the reference to the branch
            oBranch = this.aoBranches(iBranch);
            
            % Now we need the pressure difference across the branch. First
            % we get the two phase objects.
            oPhaseLeft  = oBranch.coExmes{1}.oPhase;
            oPhaseRight = oBranch.coExmes{2}.oPhase;
            
            % Getting the current pressures of both phases.
            fPressureLeft  = oPhaseLeft.fMass  * oPhaseLeft.fMassToPressure;
            fPressureRight = oPhaseRight.fMass * oPhaseRight.fMassToPressure;
            
            % Determining which pressure is higher and saving the index.
            [ fUpstreamPressure, iPhaseIndex ] = max([fPressureLeft, fPressureRight]);
            fDownstreamPressure = min([fPressureLeft, fPressureRight]);
            
            % Calculating the pressure difference. Always positive!
            fPressureDiff = fUpstreamPressure - fDownstreamPressure;
            
            oPhase = oBranch.coExmes{iPhaseIndex}.oPhase;
            
            % We need to calculate the adiabatic index for the critical
            % pressure calculation below. To reduce the number of calls to
            % the matter table findProperty() method, we only do this if
            % the parameters of the inflowing phase have changed
            % significantly.
            if ~this.abChokedFlowCheckInitialized(iBranch) ||...
               (abs(this.afPressureLastCheck(iBranch) - oPhase.fPressure) > 100) ||...
               (abs(this.afTemperatureLastCheck(iBranch) - oPhase.fTemperature) > 1) ||...
               (max(abs(this.mrPartialMassLastCheck(iBranch,:) - oPhase.arPartialMass)) > 0.01)
                
                % Recalculating the adiabatic index
                this.afAdiabaticIndex(iBranch) = this.oMT.calculateAdiabaticIndex(oPhase);
                
                % Setting the properties for the next check
                this.afPressureLastCheck(iBranch)      = oPhase.fPressure;
                this.afTemperatureLastCheck(iBranch)   = oPhase.fTemperature;
                this.mrPartialMassLastCheck(iBranch,:) = oPhase.arPartialMass;
                
                
                this.abChokedFlowCheckInitialized(iBranch) = true;
            end
            
            % Now we can calculate the critical pressure for this branch. 
            fCriticalPressure = fUpstreamPressure * (2 / (this.afAdiabaticIndex(iBranch) + 1))^(this.afAdiabaticIndex(iBranch) / (this.afAdiabaticIndex(iBranch) - 1));
            
            % If the downstream pressure is smaller or equal to the
            % critical pressure, the flow is choked. Otherwise we just
            % return. 
            if fDownstreamPressure <= fCriticalPressure
                bChokedFlow = true;
            else
                bChokedFlow = false;
                fChokedFlowRate = 0;
                iChokedProc = 0;
                return;
            end
            
            % This part is only reached if the flow is actually choked.
            
            % We now need to find out which of the processors in the branch
            % has the smallest hydraulic diameter, because that is where
            % the choked flow will occur. First we initialize an array.
            afHydraulicDiameters = zeros(oBranch.iFlowProcs, 1);
            
            % Now we loop through all processors and record their diameter.
            % NOTE: All involved processors must implement this manually,
            % it is not part of the standard f2f processor. That's why we
            % include a check here to make sure it works. 
            for iProc = 1:oBranch.iFlowProcs
                oProc = oBranch.aoFlowProcs(iProc);
                try
                    afHydraulicDiameters(iProc) = oProc.fDiameter;
                catch  %#ok<CTCH>
                    this.throw('ChokedFlowCheck','The processor ''%s'' does not have a ''fDiameter'' property. In order to support the checkForChokedFlow() method it must be implemented.', oProc.sName);
                end
            end
            
            % Finding the minimum diameter and the index of the processor
            % that has it. 
            [ fMinimumDiameter, iChokedProc ] = min(afHydraulicDiameters);
            
            % Now we calculate the choked flow rate. First we need the area
            % of the choked processor.
            fMinimumArea = pi * (fMinimumDiameter/2)^2;
            
            % The discharge coefficient is itself dependent on the mass
            % flow we are trying to calculate here. In order to avoid doing
            % this whole calculation iteratively, we just set it to 0.9.
            % This value was found several times in various examples
            % online, but would be a point of future optimization. 
            fDischargeCoefficient = 0.9;
            
            % Finally we can calculate the mass flow rate. This is based on
            % the equation found in Wikipedia (yeah, I know...) here:
            % https://en.wikipedia.org/wiki/Choked_flow#Mass_flow_rate_of_a_gas_at_choked_conditions
            % I tried to find a better source with a simple explanation,
            % but decided not to spend any more time on this. So:
            % NOTE: The source of the following equations is Wikipedia and
            % may not be correct. Should make sure it's good at some point.
            fChokedFlowRate = fDischargeCoefficient * fMinimumArea * sqrt(this.afAdiabaticIndex(iBranch) * oBranch.coExmes{iPhaseIndex}.oPhase.fDensity * fUpstreamPressure * (2/(this.afAdiabaticIndex(iBranch)+1))^((this.afAdiabaticIndex(iBranch) + 1)/(this.afAdiabaticIndex(iBranch) - 1)));
            
        end
       
        function registerUpdate(this, ~)
            % this function registers an update
            
            if ~(this.oTimer.fTime > this.fLastSetOutdated) && this.bRegisteredOutdated
                return;
            end
            
            if ~base.oDebug.bOff, this.out(1, 1, 'reg-post-tick', 'Multi-Solver - register outdated? [%i]', { ~this.bRegisteredOutdated }); end
            
            for iB = 1:this.iBranches
                for iE = 1:2
                    this.aoBranches(iB).coExmes{iE}.oPhase.registerMassupdate();
                end
                % Also tell all associated thermal branches to update, as
                % otherwise it may happen that only the one thermal branch
                % connected to the mass branch that triggered the original
                % update is updated
                this.aoBranches(iB).oThermalBranch.setOutdated();
            end
            
            % Allows other functions to register an event to this trigger
            if this.bTriggerRegisterUpdateCallbackBound
                this.trigger('register_update');
            end

            if ~base.oDebug.bOff, this.out(1, 1, 'registerUpdate', 'Registering update() method on the multi-branch solver.'); end
            
            this.hBindPostTickUpdate();
            this.hBindPostTickTimeStepCalculation();
            
            this.bRegisteredOutdated = true;
            this.fLastSetOutdated = this.oTimer.fTime;
        end
        
        function addBranches(this, aoBranches)
            % this function is used by another multibranch solver if it
            % detects that two multibranch solvers are connected via a flow
            % phase. It then adds its branches to the already existing
            % multibranch solver, instead of creating a new solver.
            iCurrentBranches = this.iBranches;
            iNewBranches = length(aoBranches);
            this.aoBranches(end+1:end+iNewBranches) = aoBranches;
            
            this.iBranches                      = length(this.aoBranches);
            this.abCheckForChokedFlow           = false(this.iBranches,1);
            this.abChokedBranches               = false(this.iBranches,1);
            this.cafChokedBranchPressureDiffs   = cell(this.iBranches,1);
            this.abChokedFlowCheckInitialized   = false(this.iBranches,1);
            this.afPressureLastCheck            = zeros(this.iBranches,1);
            this.afTemperatureLastCheck         = zeros(this.iBranches,1);
            this.afAdiabaticIndex               = zeros(this.iBranches,1);
            this.mrPartialMassLastCheck         = zeros(this.iBranches,this.aoBranches(1).oMT.iSubstances);
            this.abOscillationCorrectedBranches = false(this.iBranches,1);
            this.mbExternalBoundaryBranches     = zeros(this.iBranches,1);
            
            for iB = iCurrentBranches+1:this.iBranches 
                this.chSetBranchFlowRate{iB} = this.aoBranches(iB).registerHandler(this);
                
                this.aoBranches(iB).bind('outdated', @this.registerUpdate);
                
                this.csBranchUUIDs{iB} = this.aoBranches(iB).sUUID;

            end
            
            this.initialize();
        end
        
        function initialize(this)
            % Initialized variable pressure phases / branches
            
            this.toVariablePressurePhases = struct();
            this.toBoundaryPhases         = struct();
            
            iColIndex = 0;
            
            for iBranch = 1:this.iBranches
                abIsFlowNode = [false, false];
                for iPhase = 1:2
                    oPhase = this.aoBranches(iBranch).coExmes{iPhase}.oPhase;
                    
                    % Variable pressure phase - add to reference map if not
                    % present yet, generate index for matrix column
                    if isa(oPhase, 'matter.phases.flow.flow')
                        abIsFlowNode(iPhase) = true;
                        if ~isfield(this.toVariablePressurePhases, oPhase.sUUID)

                            this.toVariablePressurePhases.(oPhase.sUUID) = oPhase;

                            iColIndex = iColIndex + 1;

                            this.tiObjUuidsToColIndex.(oPhase.sUUID) = iColIndex;
                            this.coColIndexToObj{iColIndex} = oPhase;
                            
                            oPhase.setHandler(this);
                        end
                        
                    % 'Real' phase - boundary condition
                    else
                        abIsFlowNode(iPhase) = false;
                        if ~(isfield(this.toBoundaryPhases, oPhase.sUUID))
                            this.toBoundaryPhases.(oPhase.sUUID) = oPhase;
                        end
                    end
                    
                    oPhase.bind('update_post', @this.registerUpdate);
                end
                
                
                iColIndex = iColIndex + 1;
                oBranch = this.aoBranches(iBranch);
                
                % Check to see if an active processor is alone in the
                % branch.
                if oBranch.iFlowProcs > 1 && any([oBranch.aoFlowProcs.bActive])
                    sProcName = oBranch.aoFlowProcs([oBranch.aoFlowProcs.bActive]).sName;
                    error('MatterMultiBranch:ActiveComponentNotAlone', 'One of the components in branch ''%s'' is active. Active component: ''%s''. When using the multi-branch solver in the matter domain, active components must be the only f2f processors in the branch.', oBranch.sName, sProcName);
                end
                
                this.tiObjUuidsToColIndex.(oBranch.sUUID) = iColIndex;
                this.coColIndexToObj{iColIndex} = oBranch;
                
                oBranch.bind('outdated', @this.registerUpdate);
                if oBranch.bOutdated
                    this.registerUpdate();
                end
                % Init
                this.chSetBranchFlowRate{iBranch}(0, []);
                
            end
            
            this.csVariablePressurePhases = fieldnames(this.toVariablePressurePhases);
            this.csObjUuidsToColIndex     = fieldnames(this.tiObjUuidsToColIndex);
            this.csBoundaryPhases         = fieldnames(this.toBoundaryPhases);
            
            this.mbFlowP2P      = false(this.iBranches, 2);
            this.coFlowP2P      = cell(this.iBranches, 2);
            this.ciFlowP2PSign  = cell(this.iBranches, 2);
            for iBranch = 1:this.iBranches
                for iExme = 1:2
                    oPhase = this.aoBranches(iBranch).coExmes{iExme}.oPhase;
                    coCurrentFlowP2Ps    = cell(0);
                    ciCurrentFlowP2PSign = cell(0);
                    for iPhaseExme = 1:oPhase.iProcsEXME
                        if oPhase.coProcsEXME{iPhaseExme}.bFlowIsAProcP2P
                            if isa(oPhase.coProcsEXME{iPhaseExme}.oFlow, 'matter.procs.p2ps.flow')
                                this.mbFlowP2P(iBranch, iExme)  = true;
                                coCurrentFlowP2Ps{end+1}        = oPhase.coProcsEXME{iPhaseExme}.oFlow; %#ok
                                ciCurrentFlowP2PSign{end+1}   	= oPhase.coProcsEXME{iPhaseExme}.iSign; %#ok
                            end
                        end
                    end
                    this.coFlowP2P{iBranch, iExme}      = coCurrentFlowP2Ps;
                    this.ciFlowP2PSign{iBranch, iExme}  = ciCurrentFlowP2PSign;
                end
            end
        end
    end
    
    methods (Access = protected)
        function [bFoundOtherSolver, oSolver] = findOtherMultiSolver(~, aoBranches)
            % This function is used to check if another multibranch solver
            % is already added to a flow phase which is connected to this
            % solver. If that is the case we add the branches intended for
            % this solver to the other solver.
            bFoundOtherSolver = false;
            oSolver = [];
            for iBranch = 1:length(aoBranches)
                for iExme = 1:2
                    oPhase = aoBranches(iBranch).coExmes{iExme}.oPhase;
                    if ~oPhase.bFlow
                        continue
                    end
                    for iPhaseExme = 1:oPhase.iProcsEXME
                        if ~oPhase.coProcsEXME{iPhaseExme}.bFlowIsAProcP2P && ~isempty(oPhase.coProcsEXME{iPhaseExme}.oFlow.oBranch.oHandler)
                            if isa(oPhase.coProcsEXME{iPhaseExme}.oFlow.oBranch.oHandler, 'solver.matter_multibranch.iterative.branch')
                                oSolver =  oPhase.coProcsEXME{iPhaseExme}.oFlow.oBranch.oHandler;
                                oSolver.addBranches(aoBranches);
                                bFoundOtherSolver = true;
                                return
                            end
                        end
                    end
                end
                
            end
            
        end
        function calculateTimeStep(this)
            %% time step limitation
            % Bound to a post tick level after the residual branches.
            % Then all external flowrates are fix for this tick as well and
            % the calculated time step is definitly correct!
            
            % In order to assure a smooth startup of the simulated system,
            % we set the minimum time step for the first 12 ticks. There
            % are many systems that include checks for fTime == 0, so by
            % slowly starting the solver we get rid of weird effects
            % regarding solver time step jumps right at the beginning. 
            if this.oTimer.iTick < 13
                this.setTimeStep(this.fMinimumTimeStep);
                if ~base.oDebug.bOff
                    this.out(1,1,'Multi-Solver','Setting Minimum Time Step: %e', {this.fMinimumTimeStep});
                    this.out(1,2,'Multi-Solver','Setting the minimum time step for the first 12 ticks ensures smooth startup of the simulation.', {});
                end
                return;
            end
            
            % Now check for the maximum allowable time step with the
            % current flow rate (the pressure differences in the branches
            % are not allowed to change their sign within one tick)
            for iBoundaryPhase = 1:length(this.csBoundaryPhases)
                oBoundary = this.toBoundaryPhases.(this.csBoundaryPhases{iBoundaryPhase});
                
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
            this.fTimeStep = inf;
            if ~isempty(this.tBoundaryConnection)
                csBoundaries = fieldnames(this.tBoundaryConnection);
                if length(csBoundaries) > 1
                    for iBoundaryLeft = 1:length(csBoundaries)
                        if isempty(this.tBoundaryConnection.(csBoundaries{iBoundaryLeft}))
                            continue
                        else
                            try
                                coRightSide = this.tBoundaryConnection.(csBoundaries{iBoundaryLeft});

                                oLeftBoundary = this.toBoundaryPhases.(csBoundaries{iBoundaryLeft});

                            catch %#ok<CTCH>
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
                                if fNewStep < this.fTimeStep && fNewStep ~= 0
                                    this.fTimeStep = fNewStep;
                                end
                            end
                        end
                    end
                end
            end
            if this.fTimeStep < this.fMinimumTimeStep
                this.fTimeStep = this.fMinimumTimeStep;
            end
            
            this.out(1,1,'Multi-Solver','New Time Step: %e', {this.fTimeStep});
            
            this.setTimeStep(this.fTimeStep, true);
        end
    end
end
