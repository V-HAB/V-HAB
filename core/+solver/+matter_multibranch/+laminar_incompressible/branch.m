classdef branch < base & event.source
    %
    %
    %
    %
    %TODO
    %   * possibility to include time step calculator, prepared ones e.g.
    %     for detection of pressure/mass oscillations in boundary nodes
    %     (i.e. pressures equalized) -> set timestep for exact equalization
    
    properties (SetAccess = private, GetAccess = private)
        chSetBranchFlowRate;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        aoBranches;
        iBranches;
        
        fLastUpdate = -10;
        
        
        % Mode:
        %   * simple: coeffs for f2fs, fan dP = f(fr, density), p2p = flow
        %     rates from last tick used
        %   * complex: f2f callbacks for dP, fan callback, p2p immediately
        %     called in every iteration for absorption rate (requires
        %     specific method in p2p)
        sMode = 'complex';
        
        iLastWarn = -1000;
    end
    
    properties (SetAccess = private, GetAccess = protected) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        bRegisteredOutdated = false;
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
        
        miBranchIndexToRowID;
        
        iBranchUpdateLevels;
        mbBranchesPerUpdateLevel;
    end
    
    
    properties (SetAccess = protected, GetAccess = public)
        % The solver itself is calculated before the residual solvers. This
        % may lead to problems if a residual solver is used as input to
        % this system directly (not with a boundary phase inbetween) as the
        % flowrate of the residual solver is assumed to be constant
        % boundary condition for one tick, while it can actually change
        % before the tick ends. Therefore residual solvers should only be
        % used as input with a boundary phase inbetween that reaches the
        % necessary pressure to supply the system the correct flowrate
        iPostTickPriority = -1;
        % the time step is calculated in the last post tick, the same as
        % the phase time steps
        iPostTickPriorityCalculateTimeStep = 3;
    end
    
    
    methods
        function this = branch(aoBranches, sMode)
            %TODO check for every branch!
%             if isempty(oBranch.coExmes{1}) || isempty(oBranch.coExmes{2})
%                 this.throw('branch:constructor',['The interface branch %s is not properly connected.\n',...
%                                      'Please make sure you call connectIF() on the subsystem.'], oBranch.sName);
%             end
            
            if (nargin >= 2) && ~isempty(sMode)
                this.sMode = sMode;
            end
            
            this.sSolverType = sif(strcmp(this.sMode, 'complex'), 'callback', 'coefficient');
            
            
            this.aoBranches = aoBranches;
            this.iBranches  = length(this.aoBranches);
            this.oMT        = this.aoBranches(1).oMT;
            this.oTimer     = this.aoBranches(1).oTimer;
            
            % Preset
            this.afTmpPressureRise = zeros(1, this.iBranches);
            
            %this.aoSolverProps = solver.matter.base.type.(this.sSolverType).empty(0, size(this.oBranch.aoFlowProcs, 2));

%             for iP = 1:length(this.oBranch.aoFlowProcs)
%                 if ~isfield(this.oBranch.aoFlowProcs(iP).toSolve, this.sSolverType)
%                     this.throw('branch:constructor', 'F2F processor ''%s'' does not support the %s solving method!', this.oBranch.aoFlowProcs(iP).sName, this.sSolverType);
%                 end
% 
%                 this.aoSolverProps(iP) = this.oBranch.aoFlowProcs(iP).toSolve.(this.sSolverType);
%             end
            
            
            this.chSetBranchFlowRate = cell(1, this.iBranches);
            
            for iB = 1:this.iBranches 
                this.chSetBranchFlowRate{iB} = this.aoBranches(iB).registerHandlerFR(this);
                
                this.aoBranches(iB).bind('outdated', @this.registerUpdate);
            end
            
            
            this.setTimeStep = this.oTimer.bind(@(~) this.registerUpdate(), inf);
            
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
            
            for iB = 1:this.iBranches
                for iP = 1:2
                    oP = this.aoBranches(iB).coExmes{iP}.oPhase;
                    
                    % Variable pressure phase - add to reference map if not
                    % present yet, generate index for matrix column
                    if isa(oP, 'matter.phases.gas_flow_node')
                        if ~this.poVariablePressurePhases.isKey(oP.sUUID)

                            this.poVariablePressurePhases(oP.sUUID) = oP;

                            iColIndex = iColIndex + 1;

                            this.piObjUuidsToColIndex(oP.sUUID) = iColIndex;
                            this.poColIndexToObj(iColIndex)     = oP;
                        end
                    
                    % 'Real' phase - boundary condition
                    else
                        if ~this.poBoundaryPhases.isKey(oP.sUUID)
                            this.poBoundaryPhases(oP.sUUID) = oP;
                        end
                    end
                end
                
                
                iColIndex = iColIndex + 1;
                oB = this.aoBranches(iB);
                
                this.piObjUuidsToColIndex(oB.sUUID) = iColIndex;
                this.poColIndexToObj(iColIndex)     = oB;
                
                % Init
                this.chSetBranchFlowRate{iB}(0, []);
            end
            
            
            this.csVariablePressurePhases = this.poVariablePressurePhases.keys();
            this.csObjUuidsToColIndex     = this.piObjUuidsToColIndex.keys();
            this.csBoundaryPhases         = this.poBoundaryPhases.keys();
        end
        
        
        function [ aafPhasePressuresAndFlowRates, afBoundaryConditions ] = generateMatrices(this, bForceP2Pcalc)
            % afBoundaryConditions is the B vector mostly with the boundary
            % node pressures (later also fan pressure deltas)
            
            if nargin < 2
                bForceP2Pcalc = false;
            end
            
            if ~base.oLog.bOff, this.out(1, 3, 'props', 'Mean density: %f', { fDensity }); end;
            
            this.afPressureDropCoeffsSum = nan(1, this.iBranches);
            
            % One equation per branch, one per variable pressure phase
            iVariablePressurePhases = length(this.csVariablePressurePhases);
            iMatrixHeight           = this.iBranches + iVariablePressurePhases;
            
            aafPhasePressuresAndFlowRates = zeros(iMatrixHeight, iVariablePressurePhases + this.iBranches);
            afBoundaryConditions          = zeros(iMatrixHeight, 1);
            
            iRow = 0;
            
            this.miBranchIndexToRowID = zeros(this.iBranches,1);
            % Loop branches, generate equation row to calculate flow rate
            % DP = C * FR, or P_Left - P_Right = C * FR
            
            bRepeat = this.updateNetwork(bForceP2Pcalc);
            if bRepeat
                % a P2P had a negative flow rate, therefore we repeat the
                % calculation and force the update of all P2Ps
                this.updateNetwork(true);
            end
            
            for iB = 1:this.iBranches

                iRow = iRow + 1;
                oB   = this.aoBranches(iB);
                this.miBranchIndexToRowID(iB) = iRow;
                
                % Equation depending on pressure left/right
                %   P-T, T-P, T-T, P-P
                % If left side of branch - positive value on matrix,
                % negative on vector. Vice versa for right side.
                iSign = 1;

                for iP = 1:2
                    oE = oB.coExmes{iP};
                    oP = oB.coExmes{iP}.oPhase;

                    if this.poBoundaryPhases.isKey(oP.sUUID)
                        % NEGATIVE - right side! For second iteration, sign
                        % would be negative - i.e. value added!
                        % If both are boundary conditions, that means
                        % 0 - P_left + P_right = P_right - P_left
                        % This is ok, as the flow coeff above is also added
                        % with a negative sign, i.e.:
                        % -C * FR = P_right - P_left     | *-1
                        % C * FR  = - P_right + P_left
                        afBoundaryConditions(iRow) = afBoundaryConditions(iRow) ...
                                                    - iSign * oE.getPortProperties(); %oP.fPressure;



                        if ~base.oLog.bOff, this.out(1, 3, 'props', 'Phase %s-%s: Pressure %f', { oP.oStore.sName, oP.sName, oE.getPortProperties() }); end;

                    else
                        iCol = this.piObjUuidsToColIndex(oP.sUUID);

                        aafPhasePressuresAndFlowRates(iRow, iCol) = iSign;
                    end


                    % Multiplication not really necessary, only two loops
                    iSign = -1 * iSign;
                end
            end
            
            % We want to ignore small pressure differences (as specified by
            % the user). Therefore we equalize pressure differences smaller
            % than the specified limit
            afBoundaryHelper = abs(afBoundaryConditions);
            miSigns = sign(afBoundaryConditions);
            for iBoundary = 1:length(afBoundaryConditions)
                abEqualize = abs(afBoundaryHelper - afBoundaryHelper(5)) < this.fMinPressureDiff;
                
                fEqualizedPressure = sum(afBoundaryHelper(abEqualize)) / sum(abEqualize);
                
                afBoundaryConditions(abEqualize) = fEqualizedPressure .* miSigns(abEqualize);
            end
            
            % Loop variable pressure phases, generate eq row to enforce sum
            % of flow rates is zero (or the BC/p2p conds)
            for iP = 1:iVariablePressurePhases
                iRow   = iRow + 1;
                oP     = this.poVariablePressurePhases(this.csVariablePressurePhases{iP});
                fFrSum = 0;
                iAdded = 0;
                
                % Connected branches - col indices in matrix
                for iB = 1:oP.iProcsEXME
                    % P2ps definitely not sovled by this solver.
                    if isa(oP.coProcsEXME{iB}.oFlow, 'matter.procs.p2p')
                        continue;
                    end

                    
                    oB = oP.coProcsEXME{iB}.oFlow.oBranch;
                    
                    % Ok now check - if this phase is on exme 1, i.e. the
                    % left side - positive flow rate means OUTWARDS. If on
                    % the right side, positive means INWARDS.
                    % Therefore if on exme 1, and positive, value must be
                    % negative, i.e. sign -1
                    iSign = oP.coProcsEXME{iB}.iSign;
                    
                    % Not solved by us? Use as boundary cond flow rate!
                    if ~this.piObjUuidsToColIndex.isKey(oB.sUUID)
                        fFrSum = fFrSum - iSign * oB.fFlowRate;
                    else
                        iCol = this.piObjUuidsToColIndex(oB.sUUID);
                        
                        aafPhasePressuresAndFlowRates(iRow, iCol) = iSign;
                        iAdded = iAdded + 1;        
                    end
                end
                
                % Now go through the P2Ps and get their flowrates
                if oP.iProcsP2Pflow > 0
                    for iProcP2P = 1:oP.iProcsEXME
                        if oP.coProcsEXME{iProcP2P}.bFlowIsAProcP2P
                            fFrSum = fFrSum + oP.coProcsEXME{iProcP2P}.iSign * oP.coProcsEXME{iProcP2P}.oFlow.fFlowRate;
                        end
                    end
                end
                
                % If unsolved branch as BC, one solved branch is
                % sufficient.
                % If no branch added, don't add bc flow rate. This is a VPP
                % so that would only be valid if the inflow is zero! And
                % that does not really make sense.
                %TODO throw an error if fFrSum ~= 0 and iAdded == 0?
                if fFrSum ~= 0
                    if iAdded >= 1
                        % Note, since we add this as boundary condition we
                        % have to change the sign, because it is on the
                        % other of the = in the equation, and
                        % mathematically has to be subtracted from the
                        % overall equation to get it correct
                        afBoundaryConditions(iRow) = -fFrSum;
                    else
                        this.throw('generateMatrices', 'BC flows (manual solver or p2p) but no variable, solved branches connected!');
                    end
%                 elseif afBoundaryConditions(iRow) ~= 0
%                     afBoundaryConditions(iRow) = (3 * afBoundaryConditions(iRow) + fFrSum) / 4;
                end
            end
            
            % Now we use the subfunction to update the pressure drop and
            % rise coefficients. This is a seperate function because this
            % is the only part of the calculation that must be executed in
            % every iteration!
            [aafPhasePressuresAndFlowRates, afBoundaryConditions] = updatePressureDropCoefficients(this, aafPhasePressuresAndFlowRates, afBoundaryConditions);
            
        end
        
        function [aafPhasePressuresAndFlowRates, afBoundaryConditions] = updatePressureDropCoefficients(this, aafPhasePressuresAndFlowRates, afBoundaryConditions)
            % For higher speeds the full network is only calculated a few
            % times, this calculation handles the sole necessary update of
            % the pressure drop coefficient
            for iB = 1:this.iBranches
                
                oB = this.aoBranches(iB);
                afPressureDropCoeffs = nan(1, oB.iFlowProcs);
                fFlowRate = this.afFlowRates(iB);
                bActiveBranch = false;

                if (oB.iFlowProcs == 1) && oB.aoFlowProcs(1).bActive

                    for iP = 1:2
                        if this.poBoundaryPhases.isKey(oB.coExmes{iP}.oPhase.sUUID)
                            this.throw('generateMatrices', 'Active f2f proc (fan component) - both sides need to be variable pressure phases!');
                        end
                    end

                    bActiveBranch = true;
                end

                iRow = this.miBranchIndexToRowID(iB);

                if bActiveBranch
                    fCoeffFlowRate = 0;
                    
                    % Active component? Get pressure rise based on last
                    % iteration flow rate - add to boundary condition!
                    fFlowRate   = this.afFlowRates(iB);
                    oProcSolver = oB.aoFlowProcs(1).toSolve.(this.sSolverType);

                    % calDeltas returns POSITIVE value for pressure DROP!
                    fPressureRise = -1 * oProcSolver.calculateDeltas(fFlowRate);

                    % No flow, most likely?
                    if fPressureRise == 0
                        this.afTmpPressureRise(iB) = 0;

                    % DROP!
                    elseif fPressureRise < 0
                        this.afTmpPressureRise(iB) = 0;

                    else
                        fPressureRise = (this.afTmpPressureRise(iB) * 33 + fPressureRise) / 34;

                        this.afTmpPressureRise(iB) = fPressureRise;
                    end

                    % Boundary condition for this case can be non zero,
                    % both sides must be variable pressure phases
                    afBoundaryConditions(iRow) = fPressureRise;
                    
                else
                    if fFlowRate == 0
                        fFlowRate = this.oTimer.fMinimumTimeStep;

                        % Negative pressure difference? Negative guess!
                        if oB.coExmes{1}.getPortProperties() < oB.coExmes{2}.getPortProperties()
                            fFlowRate = -1 * fFlowRate;
                        end
                    end
                    for iProc = 1:oB.iFlowProcs
                        afPressureDropCoeffs(iProc) = oB.aoFlowProcs(iProc).toSolve.(this.sSolverType).calculateDeltas(fFlowRate);
                    end

                    this.afPressureDropCoeffsSum(iB) = sum(afPressureDropCoeffs)/abs(fFlowRate);

                    fCoeffFlowRate = this.afPressureDropCoeffsSum(iB);
                end

                % Set flow coeff
                iCol = this.piObjUuidsToColIndex(oB.sUUID);

                aafPhasePressuresAndFlowRates(iRow, iCol) = -1 * fCoeffFlowRate;
                
            end
            
            % We want to ignore small pressure differences (as specified by
            % the user). Therefore we equalize pressure differences smaller
            % than the specified limit
            afBoundaryHelper = abs(afBoundaryConditions);
            miSigns = sign(afBoundaryConditions);
            for iBoundary = 1:length(afBoundaryConditions)
                abEqualize = abs(afBoundaryHelper - afBoundaryHelper(5)) < this.fMinPressureDiff;
                
                fEqualizedPressure = sum(afBoundaryHelper(abEqualize)) / sum(abEqualize);
                
                afBoundaryConditions(abEqualize) = fEqualizedPressure .* miSigns(abEqualize);
            end
            
        end
        
        
        function bRepeat = updateNetwork(this, bForceP2Pcalc)
            
            bRepeat = false;
            
            if ~isempty(this.mbBranchesPerUpdateLevel)
                this.arPartialsFlowRates = zeros(this.iBranches, this.oMT.iSubstances);
                
                % Ok now go through results - variable pressure phase pressures
                % and branch flow rates - and set!
                
                mbBranchUpdated = false(this.iBranches,1);
                
                for iBL = 1:this.iBranchUpdateLevels
                    
                    miCurrentBranches = find(this.mbBranchesPerUpdateLevel(iBL,:));
                    
                    for iK = 1:length(miCurrentBranches)
                        
                        iB = miCurrentBranches(iK);
                        if mbBranchUpdated(iB)
                            continue
                        end
                        
                        % Generate flow rates array!
                        afInFlowRates = zeros(0);
                        aarInPartials = zeros(0, this.oMT.iSubstances);
                        
                        oCurrentBranch   = this.aoBranches(iB);
                        
                        fFlowRate = this.afFlowRates(iB);
                        
                        % it must ensured that all branches upstream of the
                        % current branch are already update and the phase
                        % partial masses are set correctly for this to
                        % work!
                        if fFlowRate < 0
                            oCurrentProcExme = oCurrentBranch.coExmes{1};
                        else
                            oCurrentProcExme = oCurrentBranch.coExmes{2};
                        end
                        
                        oPhase = oCurrentProcExme.oPhase;
                        
                        iInflowBranches = 0;
                        for iExme = 1:oPhase.iProcsEXME
                            
                            oProcExme = oPhase.coProcsEXME{iExme};
                            
                            % at first skip the P2Ps, we first have to
                            % calculate all flowrates except for the P2Ps,
                            % then calculate the P2Ps and then consider the
                            % necessary changes made by the P2P
                            if oProcExme.bFlowIsAProcP2P
                                continue;
                            end
                            
                            oBranch = oProcExme.oFlow.oBranch;
                            
                            % If the branch is not part of this network
                            % solver consider it as constant boundary
                            % flowrate. TO DO: check this condition!
                            if ~this.piObjUuidsToColIndex.isKey(oBranch.sUUID)
                                [ fFlowRate, arFlowPartials, ~ ] = oProcExme.getFlowData();

                            % Dynamically solved branch - get CURRENT flow rate
                            % (last iteration), not last time step flow rate!!
                            else

                                % Find branch index
                                iBranchIdx = find(this.aoBranches == oBranch, 1);

                                fFlowRate = oProcExme.iSign * this.afFlowRates(iBranchIdx);
                                
                                if fFlowRate > 0
                                    if this.afFlowRates(iBranchIdx) >= 0
                                        arFlowPartials = oBranch.coExmes{1}.oPhase.arPartialMass;
                                    else
                                        arFlowPartials = oBranch.coExmes{2}.oPhase.arPartialMass;
                                    end
                                end
                            end

                            % Only for INflows
                            if fFlowRate > 0
                                iInflowBranches = iInflowBranches + 1;
                                afInFlowRates(end + 1, 1) = fFlowRate;
                                aarInPartials(end + 1, :) = arFlowPartials;
                            end
                        end
                        
                        if oPhase.bFlow

                            % Now we have all inflows (except for P2Ps) for the
                            % current phase, with these values we can now
                            % update the current partial masses and flowrates
                            % for the current phase (oPhase) without P2Ps and
                            % then calculate the P2P flowrates based on this
                            if isempty(afInFlowRates)
                                oPhase.updatePartials(zeros(1,this.oMT.iSubstances));
                            else
                                oPhase.updatePartials(afInFlowRates .* aarInPartials);
                            end

                            % TO DO: for another value as in every tick the
                            % calculation of the flowrates in case it is
                            % below zero must be changed but during testing
                            % sometimes lead to osciallating P2P flowrates,
                            % maybe the overall network update could be
                            % repeated with bForceP2P = true?
                            % Also allow the user to set this value? Write
                            % a setSolverProperties function, similar to
                            % the setTimeStep function of the phase to set
                            % this value and the maximum number of
                            % iterations, as well as the max Error for the
                            % iterative solution
                            if (mod(this.iIteration, this.iIterationsBetweenP2PUpdate) == 0) || bForceP2Pcalc
                                for iProcP2P = 1:oPhase.iProcsP2Pflow
                                    oProcP2P = oPhase.coProcsP2Pflow{iProcP2P};

                                    % Update the P2P! (not with update function
                                    % because that is also called at different
                                    % other times!
                                    oProcP2P.calculateFilterRate(afInFlowRates, aarInPartials);
                                end
                            end

                            for iProcP2P = 1:oPhase.iProcsP2Pflow
                                oProcP2P = oPhase.coProcsP2Pflow{iProcP2P};
                                % Get partial flow rates, not only total
                                % flowrates. Then this can be used to update
                                % the overall partial mass of the current
                                % phase! Also decide the sign by checking the
                                % oIn Phase, if the oIn Phase is the current
                                % phase, a positive flowrate represents an
                                % outflow, otherwise it is an inflow. For P2Ps
                                % both must be considered, but there should be
                                % no individual partial flowrate that is larger
                                % than the total inflows (so the lowest overall
                                % value for the inflows is 0)
                                if oProcP2P.oIn.oPhase == oPhase
                                    afInFlowRates(end + 1, 1) = -oProcP2P.fFlowRate;
                                else
                                    afInFlowRates(end + 1, 1) = oProcP2P.fFlowRate;
                                end
                                aarInPartials(end + 1, :) = oProcP2P.arPartialMass;

                                % forced P2P update if the total inflow
                                % becomes negative, if the forced P2P
                                % update still results in a negative value,
                                % throw an error!
                                if any(sum(afInFlowRates .* aarInPartials,1) < 0)
                                    bRepeat = true;
                                    return
                                end
                            end

                            % Now the phase is updated again this time with the
                            % partial flowrates of the P2Ps as well!
                            if isempty(afInFlowRates)
                                oPhase.updatePartials(zeros(1,this.oMT.iSubstances));
                            else
                                oPhase.updatePartials(afInFlowRates .* aarInPartials);
                            end
                        end
                        
                        mbBranchUpdated(iB) = true;
                    end
                end
            end
        end
        
        
        function registerUpdate(this, ~)
            
            if ~base.oLog.bOff, this.out(1, 1, 'reg-post-tick', 'Multi-Solver - register outdated? [%i]', { ~this.bRegisteredOutdated }); end;
            
            if this.bRegisteredOutdated
                return;
            end
            
            this.bRegisteredOutdated = true;
            
            for iB = 1:this.iBranches
                for iE = sif(this.aoBranches(iB).fFlowRate >= 0, 1:2, 2:-1:1)
                    this.aoBranches(iB).coExmes{iE}.oPhase.massupdate();
                end
            end
            
            this.oTimer.bindPostTick(@this.update, this.iPostTickPriority);
            this.oTimer.bindPostTick(@this.calculateTimeStep, this.iPostTickPriorityCalculateTimeStep);
            
        end
        
        
        function update(this)
            this.fLastUpdate         = this.oTimer.fTime;
            this.bRegisteredOutdated = false;
            
            if ~base.oLog.bOff
                this.out(1, 1, 'update', 'Update multi flow rate solver');
                this.out(1, 2, 'update', 'B %s\t', { this.aoBranches.sName });
            end
            
            for iB = 1:this.iBranches
                this.afFlowRates(iB) = this.aoBranches(iB).fFlowRate;
            end
            
            
            rError    = inf;
            afResults = [];
            
            rErrorMax  = sif(strcmp(this.sMode, 'complex'), this.fMaxError, 0);
            this.iIteration = 0;
            
            % For an additional steady state solver there are basically two
            % cases: A loop with an active component generating a pressure
            % difference and a loop without such a component that only
            % equalizes the pressures. To decide whether the steady state
            % has been reached we can calculate the steady state condition
            % initially using the steady state solver, and then compare the
            % calculated solution to this steady state solution
            % --> Include mechanic to identify the individual components in
            % the current system of equations (active components, pressure
            % losses, phase pressures etc). The the steady state solver can
            % see what the final pressure difference should be in a loop
            % (zero without active component, active component pressure
            % changes with active component). The next step would be to set
            % flowrates for equalizing branches to zero (done here) and to
            % iterate the active component branches 
            
            % The initial flow rates are all zero, so initial rError below
            % will be inf -> that's good, e.g. the p2ps need a correct set
            % of flow rate directions to be included in equations!
            bFinalLoop = false;
            mfFlowRates = nan(this.iMaxIterations, this.iBranches);
            afP2PFlows = nan(this.iMaxIterations, this.iBranches);
            
            while abs(rError) > rErrorMax || bFinalLoop %|| iIteration < 5
                this.iIteration = this.iIteration + 1;
                
                if bFinalLoop % || any(abs(this.afFlowRates./afPrevFrs - afPrevFrs) -1 > 0.25) %|| any(sign(afPrevFrs) ~= sign(this.afFlowRates))
                    bForceP2PUpdate = true;
                else
                    bForceP2PUpdate = false;
                end
                
                afPrevFrs  = this.afFlowRates;
                
                if this.iIteration == 1 || bFinalLoop
                    % Regenerates matrices, gets coeffs from flow procs
                    [ aafFullPhasePressuresAndFlowRates, afFullBoundaryConditions ] = this.generateMatrices(bForceP2PUpdate);
                    aafPhasePressuresAndFlowRates = aafFullPhasePressuresAndFlowRates;
                    afBoundaryConditions = afFullBoundaryConditions;
                else
                    [aafPhasePressuresAndFlowRates, afBoundaryConditions] = this.updatePressureDropCoefficients(aafFullPhasePressuresAndFlowRates, afFullBoundaryConditions);
                end
                % Infinite values can lead to singular matrixes in the solution
                % process and at least result in badly scaled matrices.
                % Therefore the branches are checked beforehand for pressure
                % drops that are infinite, which means nothing can flow through
                % this branch an 0 flowrate must be enforced anyway (e.g.
                % closed valve)
                mbZeroFlowBranches = isinf(this.afPressureDropCoeffsSum)';
                
                % Also set branches which have a pressure difference of
                % less than this.fMinPressureDiff Pa as zero flow branches!
                % This also must be done in each iteration, as the gas flow
                % nodes can change their pressure
                if all(mbZeroFlowBranches)
                    this.afFlowRates = zeros(1, this.iBranches);
                    break
                end
                aoZeroFlowBranches = this.aoBranches(mbZeroFlowBranches);
                
                mbRemoveRow = false(1,length(aafPhasePressuresAndFlowRates));
                mbRemoveColumn = false(1,length(aafPhasePressuresAndFlowRates));
                iZeroFlowBranches = length(aoZeroFlowBranches);
                for iZeroFlowBranch = 1:iZeroFlowBranches
                    mbRemoveColumn(this.piObjUuidsToColIndex(aoZeroFlowBranches(iZeroFlowBranch).sUUID)) = true;
                end
                
                aafPhasePressuresAndFlowRates(:, mbRemoveColumn) = [];
                
                mbRemoveRow(this.miBranchIndexToRowID(mbZeroFlowBranches)) = true;
                aafPhasePressuresAndFlowRates(mbRemoveRow,:) = [];
                afBoundaryConditions((this.miBranchIndexToRowID(mbZeroFlowBranches)),:) = [];
                
                iNewRows = length(aafPhasePressuresAndFlowRates);
                iOriginalRows = length(mbRemoveRow);
                
                % create variables to simplify the transfer from old to new
                % indices and vice versa
                miOriginalRowToNewRow = zeros(iOriginalRows, 1);
                miOriginalColToNewCol = zeros(1, iOriginalRows);
                for iOriginalIndex = 1:iOriginalRows
                    if mbRemoveRow(iOriginalIndex)
                        miOriginalRowToNewRow(iOriginalIndex) = 0;
                    else
                        miOriginalRowToNewRow(iOriginalIndex) = iOriginalIndex - sum(mbRemoveRow(1:iOriginalIndex));
                    end
                    
                    if mbRemoveColumn(iOriginalIndex)
                        miOriginalColToNewCol(iOriginalIndex) = 0;
                    else
                        miOriginalColToNewCol(iOriginalIndex) = iOriginalIndex - sum(mbRemoveColumn(1:iOriginalIndex));
                    end
                end
                
                miNewRowToOriginalRow = zeros(iNewRows, 1);
                miNewColToOriginalCol = zeros(1, iNewRows);
                
                for iNewIndex = 1:iNewRows
                    miNewRowToOriginalRow(iNewIndex) = find(miOriginalRowToNewRow == iNewIndex);
                    miNewColToOriginalCol(iNewIndex) = find(miOriginalColToNewCol == iNewIndex);
                end
                
                iStartZeroSumEquations = length(afBoundaryConditions) - length(this.csVariablePressurePhases)+1;
                
                afP2PFlowsHelper = afBoundaryConditions(iStartZeroSumEquations:end)';
                afP2PFlows(this.iIteration, 1:length(afP2PFlowsHelper)) = afP2PFlowsHelper;
                %aafPhasePressuresAndFlowRates = tools.round.prec(aafPhasePressuresAndFlowRates, this.oTimer.iPrecision);
                %afBoundaryConditions          = tools.round.prec(afBoundaryConditions,          this.oTimer.iPrecision);

                % Solve
                %hT = tic();
                warning('off','all');
                % TO DO: Comment from puda
                % Some comments from me, if I misunderstood anything please
                % correct. This operation would solve the linear system of
                % equation where aafPhasePressuresAndFlowRates * X =
                % afBoundaryConditions but what are the X, are they the
                % flowrates? This cannot be because in the example I viewed
                % there were only 4 branches.
                
                % Example: In the tutorial case this was the matrix:
%                 aafPhasePressuresAndFlowRates =
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
% 

                afResults = aafPhasePressuresAndFlowRates \ afBoundaryConditions;
                sLastWarn = lastwarn;
                
                warning('on','all');
                
                if ~isempty(sLastWarn) && ~isempty(strfind(sLastWarn, 'badly scaled'))
                    if (this.oTimer.iTick - this.iLastWarn) >= 100
                        % warning(sLastWarn);
                        
                        this.iLastWarn = this.oTimer.iTick;
                    end
                end
                
                % Round everything to the precision, else we get small
                % errors
                %afResults = tools.round.prec(afResults, this.oTimer.iPrecision);
                
                for iColumn = 1:iNewRows
                    oObj = this.poColIndexToObj(miNewColToOriginalCol(iColumn));

                    if isa(oObj, 'matter.branch')
                        iB = find(this.aoBranches == oObj, 1);
                        
                        if this.iIteration == 1 || ~strcmp(this.sMode, 'complex')
                            this.afFlowRates(iB) = afResults(iColumn);
                        else
                            this.afFlowRates(iB) = (this.afFlowRates(iB) * 3 + afResults(iColumn)) / 4;
                        end
                    elseif isa(oObj, 'matter.phases.gas_flow_node')
                        oObj.setPressure(afResults(iColumn));
                    end
                end
                for iZeroBranch = 1:iZeroFlowBranches
                    iB = find(this.aoBranches == aoZeroFlowBranches(iZeroBranch), 1);
                    this.afFlowRates(iB) = 0;
                end
                mfFlowRates(this.iIteration,:) = this.afFlowRates;
                %this.afFlowRates = tools.round.prec(this.afFlowRates, this.oTimer.iPrecision);
                
                iPrecision = this.oTimer.iPrecision;
                afFrsDiff  = tools.round.prec(abs(this.afFlowRates - afPrevFrs), iPrecision);
                
                %rError = max(abs(this.afFlowRates ./ afPrevFrs) - 1);
                rError = max(abs(afFrsDiff ./ afPrevFrs));
                % if the error is smaller than the limit, do one final
                % update where the recalculation of P2P flowrates is
                % enforced. If after that the error is still smaller than
                % the limit, the iteration is finished, otherwise it
                % continues normally again
                if bFinalLoop && rError < this.fMaxError
                    bFinalLoop = false;
                elseif rError < this.fMaxError
                    bFinalLoop = true;
                else
                    bFinalLoop = false;
                end
                
                %%
                % the solver must start updating the branches and phases from
                % the boundary phases and then move flow direction downward.
                % Otherwise it is possible that flow nodes are set with
                % outflows but no inflows, which results in flows with a
                % flowrate but not partial masses.
                % However, only do this if the flowrates have changed
                % direction or became zero!
                if any(sign(afPrevFrs) ~= sign(this.afFlowRates)) || any(this.afFlowRates(afPrevFrs == 0))
                    miBoundaryRows = false(iNewRows,1);
                    miBoundaryRows(1:iStartZeroSumEquations-1) = afBoundaryConditions(1:iStartZeroSumEquations-1) ~= 0;
                    miBoundaryBranches = miNewRowToOriginalRow(miBoundaryRows);
                    
                    % get the part of the equation that connects phases and
                    % branches (it contains the sum over each variable pressure
                    % phase and ensures that the total mass flow through it is
                    % 0)
                    aafZeroSumMatrix = aafPhasePressuresAndFlowRates(iStartZeroSumEquations:end,:);

                    % change the sign of the matrix to reflect the current
                    % flowrate direction, also get the current branch to column
                    % index matrix
                    miBranchToColumnIndex = zeros(this.iBranches,1);
                    for iBranch = 1:this.iBranches
                        iCol = this.piObjUuidsToColIndex(this.aoBranches(iBranch).sUUID);
                        mbCol = miNewColToOriginalCol == iCol;
                        if any(mbCol)
                            miBranchToColumnIndex(iBranch) = find(mbCol);
                            aafZeroSumMatrix(:,mbCol) = aafZeroSumMatrix(:,mbCol) .* sign(this.afFlowRates(iBranch));
                        end
                    end
                    
                    % now remove the boundary branches that are exiting the
                    % system, we want to start from the boundary branches that
                    % enter the system
                    for iBoundaryBranch = 1:length(miBoundaryBranches) 
                        iBranch = miBoundaryBranches(iBoundaryBranch);
                        if this.afFlowRates(iBranch) > 0
                            if this.aoBranches(iBranch).coExmes{1}.oPhase.bFlow
                                miBoundaryBranches(iBoundaryBranch) = 0;
                            end
                        elseif this.afFlowRates(iBranch) < 0
                            if this.aoBranches(iBranch).coExmes{2}.oPhase.bFlow
                                miBoundaryBranches(iBoundaryBranch) = 0;
                            end
                        else
                            miBoundaryBranches(iBoundaryBranch) = 0;
                        end
                    end
                    miBoundaryBranches(miBoundaryBranches == 0) = [];

                    % The update level increases for branches further
                    % downstream, it is initialized to one for the first branch
                    % and the vector is initialized to zero (if a zero remains
                    % in the end, it means that branch has 0 flowrate or it is
                    % not part of this loop)
                    iBranchUpdateLevel = 1;
                    miUpdateLevel = zeros(this.iBranches,1);

                    % continue the loop until a boundary phase is reached or
                    % the starting variable pressure phase is reached
                    bFinished = false;
                    
                    this.iBranchUpdateLevels = this.iBranches+1;
                    mbBranchesOnUpdateLevel = false(this.iBranches+1,this.iBranches);
                    mbBranchesOnUpdateLevel(1,miBoundaryBranches) = true;
                    
                    while ~bFinished
                        if (iBranchUpdateLevel > this.iBranches) || ~any(mbBranchesOnUpdateLevel(iBranchUpdateLevel,:))
                            break
                        end

                        mbBranches = mbBranchesOnUpdateLevel(iBranchUpdateLevel,:);
                        miBranches = find(mbBranches);

                        for iI = 1:length(miBranches)
                            iBranch = miBranches(iI);
                            miUpdateLevel(iBranch) = iBranchUpdateLevel;

                            if miBranchToColumnIndex(iBranch) == 0
                                continue
                            else
                                miPhases = find(aafZeroSumMatrix(:,miBranchToColumnIndex(iBranch)) > 0);
                            end
                            
                            for iPhase = 1:length(miPhases)
                                % we want to know where this branch leads,
                                % therefore we require the negative entries
                                % here
                                miBranchesNext = find(aafZeroSumMatrix(miPhases(iPhase), :) == -1);
                                for iK = 1:length(miBranchesNext)
                                    oB = this.poColIndexToObj(miBranchesNext(iK));
                                    iB = find(this.aoBranches == oB);
                                    miBranchesNext(1, iK) = iB;
                                end
                                mbBranchesOnUpdateLevel(iBranchUpdateLevel+1, miBranchesNext) = true;
                            end
                        end
                        iBranchUpdateLevel = iBranchUpdateLevel + 1;
                    end
                    
                    mbBranchesOnUpdateLevel(end,~sum(mbBranchesOnUpdateLevel,1)) = true;
                    this.mbBranchesPerUpdateLevel = mbBranchesOnUpdateLevel;
                    
                    clear this.tBoundaryConnection
                    for iBoundaryBranch = 1:length(miBoundaryBranches)
                        mbBranchesOnUpdateLevel = false(this.iBranches+1,this.iBranches);
                        mbBranchesOnUpdateLevel(1,miBoundaryBranches(iBoundaryBranch)) = true;

                        iBranchUpdateLevel = 1;
                        coOtherSidePhase = cell(0,0);
                        while ~bFinished
                            if (iBranchUpdateLevel > this.iBranches) || ~any(mbBranchesOnUpdateLevel(iBranchUpdateLevel,:))
                                break
                            end

                            mbBranches = mbBranchesOnUpdateLevel(iBranchUpdateLevel,:);
                            miBranches = find(mbBranches);

                            for iI = 1:length(miBranches)
                                iBranch = miBranches(iI);
                                miUpdateLevel(iBranch) = iBranchUpdateLevel;

                                if miBranchToColumnIndex(iBranch) == 0
                                    continue
                                else
                                    miPhases = find(aafZeroSumMatrix(:,miBranchToColumnIndex(iBranch)) > 0);
                                end

                                for iPhase = 1:length(miPhases)
                                    % we want to know where this branch leads,
                                    % therefore we require the negative entries
                                    % here
                                    miBranchesNext = find(aafZeroSumMatrix(miPhases(iPhase), :) == -1);
                                    for iK = 1:length(miBranchesNext)
                                        oB = this.poColIndexToObj(miBranchesNext(iK));
                                        iB = find(this.aoBranches == oB);
                                        miBranchesNext(1, iK) = iB;
                                        
                                        if this.afFlowRates(iB) == 0
                                            continue
                                        elseif this.afFlowRates(iB) > 0
                                            iExme = 2;
                                        else
                                            iExme = 1;
                                        end
                                        
                                        if ~oB.coExmes{iExme}.oPhase.bFlow
                                            coOtherSidePhase{end+1} = oB.coExmes{iExme}.oPhase;
                                        end
                                    end
                                    mbBranchesOnUpdateLevel(iBranchUpdateLevel+1, miBranchesNext) = true;
                                end
                            end
                            iBranchUpdateLevel = iBranchUpdateLevel + 1;
                        end
                        
                        oBoundaryBranch = this.aoBranches(this.miBranchIndexToRowID == (miBoundaryBranches(iBoundaryBranch)));
                        if this.afFlowRates(miBoundaryBranches(iBoundaryBranch)) >= 0
                            oBoundaryPhase = oBoundaryBranch.coExmes{1}.oPhase;
                        else
                            oBoundaryPhase = oBoundaryBranch.coExmes{2}.oPhase;
                        end
                        this.tBoundaryConnection.(oBoundaryPhase.sUUID) = coOtherSidePhase;
                    end
                end
                
                %rError = tools.round.prec(max(afFrsDiff ./ afPrevFrs), iPrecision);
                
                % Boundary conditions (= p2p and others) changing? Continue
                % iteration!
                % Also enforces at least two iterations ... ok? BS?
                % Not ok, as P2P flowrates are calculated during the
                % iteration and therefore change, if this is forced to
                % become 0 it will not converge for cases that actually use
                % this
                
                if ~base.oLog.bOff, this.out(1, 2, 'solve-flow-rates', 'Iteration: %i with error %.12f', { this.iIteration, rError }); end;
                
                if this.iIteration > this.iMaxIterations
                    keyboard();
                    this.throw('update', 'too many iterations, error %.12f', rError);
                end
            end
            
            %% Setting of final results to afFlowRates
            % during the iteration it is necessary to adapt the results for
            % the next iteration so that the solver can converge. However
            % after it has converged, the actual results must be used to
            % ensure that the zero sum of mass flows over the gas flow
            % nodes is maintained!
            for iColumn = 1:iNewRows
                oObj = this.poColIndexToObj(miNewColToOriginalCol(iColumn));

                if isa(oObj, 'matter.branch')
                    iB = find(this.aoBranches == oObj, 1);
                    this.afFlowRates(iB) = afResults(iColumn);
                end
            end
            
            % However, in the desorption case it is still possible that now
            % mass is put into the flow nodes. To solve this either the
            % P2Ps should have a flowrate of 0 in case nothing flows
            % through the flow nodes, or a solution muste be found where it
            % is allowed that desorption occurs for no flow through the
            % phase. Or the solution could be that if nothing flows through
            % the flow nodes, the desorption takes place directly in a
            % boundary phase (the P2P would have decide what is the case)
            % where all desorption flowrates from the flow node p2ps are
            % summed up!
            
            if ~base.oLog.bOff, this.out(1, 1, 'solve-flow-rates', 'Iterations: %i', { this.iIteration }); end;
            
            for iColumn = 1:length(this.csObjUuidsToColIndex)
                oObj = this.poColIndexToObj(iColumn);

                if isa(oObj, 'matter.branch')
                    iB = find(this.aoBranches == oObj, 1);
                    
                    if ~base.oLog.bOff, this.out(1, 2, 'solve-flow-rates', 'Branch: %s\t%.24f', { oObj.sName, this.afFlowRates(iB) }); end;
                end
            end
            % Ok now go through results - variable pressure phase pressures
            % and branch flow rates - and set!
            
            for iBL = 1:this.iBranchUpdateLevels 
                
                miCurrentBranches = find(this.mbBranchesPerUpdateLevel(iBL,:));
                
                for iK = 1:length(miCurrentBranches)
                
                    iB = miCurrentBranches(iK);
                    
                    %TODO get pressure drop distribution (depends on total
                    %     pressure drop and drop coeffs!)
                    %this.chSetBranchFlowRate{iB}(afResults(iR), []);
                    this.chSetBranchFlowRate{iB}(this.afFlowRates(iB), []);
                end
            end
            
            this.calculateTimeStep();
            
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
            % connected boundary phases, which actually exchange masse. For
            % them the total mass change is compared to calculate the
            % maximum allowable time step. However, temperature changes are
            % neglected here so in some cases this limitation might not be
            % sufficient
            fTimeStep = inf;
            if ~isempty(this.tBoundaryConnection)
                csBoundaries = fieldnames(this.tBoundaryConnection);
                for iBoundaryLeft = 1:length(csBoundaries)
                    if isempty(this.tBoundaryConnection.(csBoundaries{iBoundaryLeft}))
                        continue
                    else
                        coRightSide = this.tBoundaryConnection.(csBoundaries{iBoundaryLeft});

                        oLeftBoundary = this.poBoundaryPhases(csBoundaries{iBoundaryLeft});

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
            if fTimeStep < this.fMinimumTimeStep
                fTimeStep = this.fMinimumTimeStep;
            end
            this.setTimeStep(fTimeStep);
        end
    end
end
