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
        sMode = 'simple';
        
        fMinimumTimeStep = 1;
        
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
        
        %
        fMaxError = 1e-4;
        
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
        iPostTickPriority = -1;
        iPostTickPriorityReUpdate = 2;
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
            % Average density
            afDensities = nan(1, length(this.csBoundaryPhases));
            
            for iP = 1:length(this.csBoundaryPhases)
                afDensities(iP) = this.poBoundaryPhases(this.csBoundaryPhases{iP}).fDensity;
            end
            
            fDensity = mean(afDensities);
            %fDensity = 1.225;
            
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
                            [ ~, arPartialsBranch, ~ ] = oCurrentBranch.coExmes{2}.getFlowData();
                        else
                            oCurrentProcExme = oCurrentBranch.coExmes{2};
                            [ ~, arPartialsBranch, ~ ] = oCurrentBranch.coExmes{1}.getFlowData();
                        end
                        
                        this.arPartialsFlowRates(iB, :) = arPartialsBranch;
                        
                        oPhase = oCurrentProcExme.oPhase;
                        
                        
                        iInflowBranches = 0;
                        for iExme = 1:oPhase.iProcsEXME
                            
                            oProcExme = oPhase.coProcsEXME{iExme};
                            
                            % at first skip the P2Ps, we first have to
                            % calculate all flowrates except for the P2Ps,
                            % then calculate the P2Ps and then consider the
                            % necessary changes made by the P2P
                            if isa(oProcExme.oFlow, 'matter.procs.p2p')
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
                                arFlowPartials = this.arPartialsFlowRates(iB, :);
                            end

                            % Only for INflows
                            if fFlowRate > 0
                                iInflowBranches = iInflowBranches + 1;
                                afInFlowRates(end + 1, 1) = fFlowRate;
                                aarInPartials(end + 1, :) = arFlowPartials;
                            end
                        end
                        
                        if oPhase.bFlow
                            % Note, this is not done for boundary phases,
                            % if the multi branch solver is used with a
                            % normal gas phase where the bFlow parameter is
                            % set to true, this calculation will throw an
                            % error, as that is not the intended use of
                            % such phases!
                            
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
                            % below zero must be changed. Probably just
                            % move this whole first part to another
                            % subfunction and call the whole subfunction
                            % instead of updating one P2P individually
                            if (mod(this.iIteration, 1) == 0) || bForceP2Pcalc
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

                                % TO DO: built in a forced P2P update if the
                                % total inflow becomes negative, if the forced
                                % P2P update still results in a negative value,
                                % throw an error!
                                if any(sum(afInFlowRates .* aarInPartials,1) < 0)
                                    % if this is the case, force an p2p
                                    % update
                                    oProcP2P.calculateFilterRate(afInFlowRates(1:iInflowBranches), aarInPartials(1:iInflowBranches, :));
                                    
                                    if oProcP2P.oIn.oPhase == oPhase
                                        afInFlowRates(end, 1) = -oProcP2P.fFlowRate;
                                    else
                                        afInFlowRates(end, 1) = oProcP2P.fFlowRate;
                                    end
                                    aarInPartials(end, :) = oProcP2P.arPartialMass;
                                end
                                
                                if any(sum(afInFlowRates .* aarInPartials,1) < 0)
                                    keyboard()
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
            
            for iB = 1:this.iBranches

                iRow = iRow + 1;
                oB   = this.aoBranches(iB);
                this.miBranchIndexToRowID(iB) = iRow;

                % If we have a branch with one, active component -->
                % special treatment (no coefficient - get pressure rise
                % based on previous iteration flow rate - add total value
                % as boundary condition (so iteration checks convergence)
                bActiveBranch = false;

                if (oB.iFlowProcs == 1) && isa(oB.aoFlowProcs(1), 'components.fan')

                    for iP = 1:2
                        if this.poBoundaryPhases.isKey(oB.coExmes{iP}.oPhase.sUUID)
                            this.throw('generateMatrices', 'Active f2f proc (fan component) - both sides need to be variable pressure phases!');
                        end
                    end

                    bActiveBranch = true;
                end


                if bActiveBranch
                    fCoeffFlowRate = 0;

                %TODO in case of complex solver, this.afPressDropCoeffSums
                %     is relative to mass flow rate, in other case relative
                %     to volumetric flow rate. Stupid.
                elseif strcmp(this.sMode, 'complex')
                    % dP = Coeff * FR.

                    % If flow rate is zero, use minTs as initial flow rate.
                    % Depending on pressure difference of this branch, set
                    % positive or negative - as we do not have active
                    % components, the pressure difference determines the
                    % flow direction! Yay!
                    fFlowRate = this.afFlowRates(iB);

                    %TODO round somewhere? In between iterations?
                    if fFlowRate == 0
                        fFlowRate = this.oTimer.fMinimumTimeStep;

                        % Negative pressure difference? Negative guess!
                        if oB.coExmes{1}.getPortProperties() < oB.coExmes{2}.getPortProperties()
                            fFlowRate = -1 * fFlowRate;
                        end
                    end
                    afPressureDrops = nan(1, oB.iFlowProcs);

                    for iProc = 1:oB.iFlowProcs
                        afPressureDrops(iProc) = oB.aoFlowProcs(iProc).toSolve.(this.sSolverType).calculateDeltas(fFlowRate);
                    end

                    % Got the absolute pressure drops, so now we need to 
                    % divide that with the flow rate to get the coeff!
                    this.afPressureDropCoeffsSum(iB) = sum(afPressureDrops) / abs(fFlowRate);
                    fCoeffFlowRate = this.afPressureDropCoeffsSum(iB);

                else
                    afPressureDropCoeffs = nan(1, oB.iFlowProcs);


                    %TODO might change after calculation, because pressure
                    %     of VPP might be adapted. At least one iteration
                    %     even for the simple case?
                    %     Cause e.g. checkvalve ... might be some flow for
                    %     one step, which might be up to 20 secs ...
                    bFlowRatePositive = oB.coExmes{1}.getPortProperties() >= oB.coExmes{2}.getPortProperties();


                    for iProc = 1:oB.iFlowProcs
                        afPressureDropCoeffs(iProc) = oB.aoFlowProcs(iProc).toSolve.(this.sSolverType).getCoefficient(bFlowRatePositive);
                    end

                    this.afPressureDropCoeffsSum(iB) = sum(afPressureDropCoeffs);

                    % For the matrix coeffs, we do need to convert the coeff,
                    % which is relative to the VOLUMETRIC flow rate, to the
                    % absolute flow rate - incompresible, use mean density of
                    % all boundary nodes!
                    fCoeffFlowRate = this.afPressureDropCoeffsSum(iB) / fDensity;
                end

                if ~base.oLog.bOff, this.out(1, 3, 'props', 'Branch %s: Flow Coeff %f', { oB.sName, fCoeffFlowRate}); end;


                % Set flow coeff
                iCol = this.piObjUuidsToColIndex(oB.sUUID);

                aafPhasePressuresAndFlowRates(iRow, iCol) = -1 * fCoeffFlowRate;


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


                % Active component? Get pressure rise based on last
                % iteration flow rate - add to boundary condition!
                if bActiveBranch
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

                    % Boundary condition must be zero, can't have active
                    % component if one side is a fixed, BC phase.
                    afBoundaryConditions(iRow) = -1 * fPressureRise;
                end
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
                    iSign = 1;
                    
                    if oB.coExmes{1}.oPhase == oP
                        iSign = -1;
                    end
                    
                    
                    % Not solved by us? Use as boundary cond flow rate!
                    if ~this.piObjUuidsToColIndex.isKey(oB.sUUID)
                        fFrSum = fFrSum - iSign * oB.fFlowRate;
                    else
                        iCol = this.piObjUuidsToColIndex(oB.sUUID);
                        
                        
                        % Check coeff of branch - if inf, don't add this
                        % term! No flow!
                        if isnan(this.afPressureDropCoeffsSum(this.aoBranches(iB) == oB))
                            continue;
                        end
                        
                        
                        aafPhasePressuresAndFlowRates(iRow, iCol) = iSign;
                        iAdded = iAdded + 1;        
                    end
                end
                
                % Now go through the P2Ps and get their flowrates
                if oP.iProcsP2Pflow > 0
                     for iProcP2P = 1:oP.iProcsP2Pflow
                        oProcP2P = oP.coProcsP2Pflow{iProcP2P};

                        % if the current phase is the In phase of the exme,
                        % a positive flowrate means mass is taken out of
                        % the phase
                        if oProcP2P.oIn.oPhase == oP
                            fFrSum = fFrSum - oProcP2P.fFlowRate;
                        else
                            fFrSum = fFrSum + oProcP2P.fFlowRate;
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
            this.oTimer.bindPostTick(@this.reUpdate, this.iPostTickPriorityReUpdate);
        end
        
        
        function update(this)
%             disp(this.oTimer.fTime);
%             disp(this.oTimer.fTime - this.fLastUpdate);
            
            this.fLastUpdate         = this.oTimer.fTime;
            this.bRegisteredOutdated = false;
            
            if ~base.oLog.bOff
                this.out(1, 1, 'update', 'Update multi flow rate solver');
                this.out(1, 2, 'update', 'B %s\t', { this.aoBranches.sName });
            end
            
            for iB = 1:this.iBranches
                this.afFlowRates(iB) = this.aoBranches(iB).fFlowRate;
            end
            
            
            %TOOD
            % Now iterate ... in case of complex solver ...
            % Only really set the resulting pressures/flow rates if
            % converged.
            % FRs - afFlowRates used in iterations, works (for calcDeltas)
            % VPP (var. press. phases) don't need to be updated, densities
            %     etc from last tick used anyways. Well, for initial flow
            %     rate (if FR was zero), maybe the current value from the
            %     iteration then needed?
            
            
            rError    = inf;
            afResults = [];
            
            % Only iterate for the complex solving mechanism
            %rErrorMax = 0.01;
            %rErrorMax = sif(strcmp(this.sMode, 'complex'), 0.001, inf);
            rErrorMax  = sif(strcmp(this.sMode, 'complex'), this.fMaxError, 0);
            %rErrorMax  = sif(strcmp(this.sMode, 'complex'), 0.1 ^ this.oTimer.iPrecision, 0);
            this.iIteration = 0;
            
            afBoundaryConditions = [];
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
            mfFlowRates = nan(500, this.iBranches);
            afP2PFlows = nan(500, this.iBranches);
            afPrevFrs  = this.afFlowRates;
            
            while abs(rError) > rErrorMax || bFinalLoop %|| iIteration < 5
                this.iIteration = this.iIteration + 1;
                
                afPrevBoundaryConditions = afBoundaryConditions;
                
                if bFinalLoop % || any(abs(this.afFlowRates./afPrevFrs - afPrevFrs) -1 > 0.25) %|| any(sign(afPrevFrs) ~= sign(this.afFlowRates))
                    bForceP2PUpdate = true;
                else
                    bForceP2PUpdate = false;
                end
                
                afPrevFrs  = this.afFlowRates;
                
                % Regenerates matrices, gets coeffs from flow procs
                [ aafPhasePressuresAndFlowRates, afBoundaryConditions ] = this.generateMatrices(bForceP2PUpdate);
                
                
                % Infinite values can lead to singular matrixes in the solution
                % process and at least result in badly scaled matrices.
                % Therefore the branches are checked beforehand for pressure
                % drops that are infinite, which means nothing can flow through
                % this branch an 0 flowrate must be enforced anyway (e.g.
                % closed valve)
                mbZeroFlowBranches = isinf(this.afPressureDropCoeffsSum)';
                
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
                miNewRowToOriginalRow = zeros(iNewRows, 1);
                miNewColToOriginalCol = zeros(1, iNewRows);
                
                iOriginalRows = length(mbRemoveRow);
                for iEntry = 1:iNewRows
                    iIndex = 1;
                    iShiftRowBy = 0;
                    while iIndex < iEntry || mbRemoveRow(iIndex)
                        if iIndex > iOriginalRows
                            break
                        else
                            iShiftRowBy = iShiftRowBy + mbRemoveRow(iIndex);
                        end
                        iIndex = iIndex + 1;
                    end
                    
                    miNewRowToOriginalRow(iEntry) = iEntry + iShiftRowBy;
                    
                    iIndex = 1;
                    iShiftColBy = 0;
                    while iIndex < iEntry || mbRemoveColumn(iIndex)
                        if iIndex > iOriginalRows
                            break
                        else
                            iShiftColBy = iShiftColBy + mbRemoveColumn(iIndex);
                        end
                        iIndex = iIndex + 1;
                    end
                    
                    miNewColToOriginalCol(iEntry) = iEntry + iShiftColBy;
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
                
                %toc(hT);

                %disp(afResults);
                %keyboard();
                
                
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
                rError = abs(max(afFrsDiff ./ afPrevFrs));
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
                    iShift = this.poVariablePressurePhases.Count + 1 - sum(mbRemoveRow(1:this.poVariablePressurePhases.Count+1));

                    miBoundaryRows(1:iShift) = afBoundaryConditions(1:iShift) ~= 0;
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
                        if ~any(aafZeroSumMatrix(:,miBranchToColumnIndex(miBoundaryBranches(iBoundaryBranch))) > 0)
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
                                % therefore we require the positive entries
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
                    
                    this.iBranchUpdateLevels = iBranchUpdateLevel;
                    
                    mbBranchesOnUpdateLevel(end,~sum(mbBranchesOnUpdateLevel,1)) = true;
                    this.mbBranchesPerUpdateLevel = mbBranchesOnUpdateLevel;
                end
                
                %rError = tools.round.prec(max(afFrsDiff ./ afPrevFrs), iPrecision);
                
                % Boundary conditions (= p2p and others) changing? Continue
                % iteration!
                % Also enforces at least two iterations ... ok? BS?
                % Not ok, as P2P flowrates are calculated during the
                % iteration and therefore change, if this is forced to
                % become 0 it will not converge for cases that actually use
                % this
%                 afBcChange = [ 0 ];
%                 
%                 if ~isempty(afPrevBoundaryConditions)
%                     %afBcChange = tools.round.prec(afPrevBoundaryConditions - afBoundaryConditions, iPrecision);
%                     afBcChange = tools.round.prec(afPrevBoundaryConditions - afBoundaryConditions, 4);
%                 end
%                 
%                 if isempty(afPrevBoundaryConditions) || ~all(afBcChange == 0) % ~all(afPrevBoundaryConditions == afBoundaryConditions)
%                     if ~base.oLog.bOff, this.out(1, 2, 'changing-boundary-conditions', 'Boundary conditions changing (p2p!), iteration %i', { iIteration }); end;
%                     rError = inf;
%                 end
                
                
                if ~base.oLog.bOff, this.out(1, 2, 'solve-flow-rates', 'Iteration: %i with error %.12f', { this.iIteration, rError }); end;
                
                if this.iIteration > 1000
                    %keyboard();
                    this.throw('update', 'too many iterations, error %.12f', rError);
                end
                
                % Ok now go through the results again because the gas flow
                % nodes need the flowrates of all branches to be set before
                % calculating- variable pressure phase pressures
                for iColumn = 1:length(this.csObjUuidsToColIndex)
                    oObj = this.poColIndexToObj(iColumn);

                    if isa(oObj, 'matter.phases.gas_flow_node')
                        oObj.setPressure(afResults(iColumn));
                    end
                end
            end
            
            if ~base.oLog.bOff, this.out(1, 1, 'solve-flow-rates', 'Iterations: %i', { this.iIteration }); end;
            
            for iColumn = 1:length(this.csObjUuidsToColIndex)
                oObj = this.poColIndexToObj(iColumn);

                if isa(oObj, 'matter.branch')
                    iB = find(this.aoBranches == oObj, 1);
                    
                    if ~base.oLog.bOff, this.out(1, 2, 'solve-flow-rates', 'Branch: %s\t%.24f', { oObj.sName, this.afFlowRates(iB) }); end;
                end
            end
            
            % TO DO (puda): I think there is also another error that
            % should be considered, mfError = (aafPhasePressuresAndFlowRates*afResults) - afBoundaryConditions
            % which is basically the error of this individual solution,
            % In the tutorials the flowrates did not actually reach 0,
            % which therefore lead to small mass changes in the branches.
            % Either we have to find a way to solve these here and achieve
            % an mfError vector as defined above which is 0, or we have to
            % find a way to prevent these small errors from affecting the
            % gas flow node calculations
            % Specifically the last set of equation which enforces that the
            % sum of flowrates for the variable pressure phases has to be
            % zero has to be absolutely enforced. 
            mfError = (aafPhasePressuresAndFlowRates*afResults) - afBoundaryConditions;
            mfErrorInitial = mfError;
            iStartZeroSumEquations = length(mfError) - length(this.csVariablePressurePhases)+1;
            iCounter = 0;
            while any(mfError(iStartZeroSumEquations:end)) && iCounter < 500
                mfError = (aafPhasePressuresAndFlowRates*afResults) - afBoundaryConditions;

                for iRow = iStartZeroSumEquations:length(mfError)
                    if (aafPhasePressuresAndFlowRates(iRow,:) * afResults) ~= 0
                        for iColumn = 1:length(mfError)
                            if aafPhasePressuresAndFlowRates(iRow,iColumn) ~= 0
                                iOriginalCol = miNewColToOriginalCol(iColumn);
                                oObj = this.poColIndexToObj(iOriginalCol);

                                iB = find(this.aoBranches == oObj, 1);
                                
                                %                                                            Number of branches represented in the sum, the error is equally distributed
                                fError = aafPhasePressuresAndFlowRates(iRow,iColumn) * mfError(iRow)/(sum(abs(aafPhasePressuresAndFlowRates(iRow,:))));
                                if this.afFlowRates(iB) == 0
                                    keyboard()
                                end
                                this.afFlowRates(iB) = this.afFlowRates(iB) - fError;
                                
                                afResults(iColumn) = this.afFlowRates(iB);
                            end
                        end
                    end
                end
                iCounter = iCounter + 1;
            end
            
            mfError = aafPhasePressuresAndFlowRates * afResults - afBoundaryConditions;
            
            if any(abs(mfError(iStartZeroSumEquations:end)) > 1e-8)
                keyboard()
            end
            %% Example time step limitation
            % Note not finished, just to showcase the effect of limitation
            % for time steps:
            %
            % Now check for the maximum allowable time step with the
            % current flow rate (the pressure differences in the branches
            % are not allowed to change their sign within one tick)
            afMaxTimeStep = ones(this.poBoundaryPhases.Count, this.poBoundaryPhases.Count) * inf;
            
            mfTotalMassChangeBoundary   = zeros(this.poBoundaryPhases.Count,1);
            mfMassBoundary              = zeros(this.poBoundaryPhases.Count,1);
            mfMassToPressureBoundary    = zeros(this.poBoundaryPhases.Count,1);
            
            for iBoundaryPhase = 1:this.poBoundaryPhases.Count
                oBoundary = this.poBoundaryPhases(this.csBoundaryPhases{iBoundaryPhase});
                
                mfMassBoundary(iBoundaryPhase)              = oBoundary.fMass;
                mfMassToPressureBoundary(iBoundaryPhase)    = oBoundary.fMassToPressure;
                
                for iExme = 1:length(oBoundary.coProcsEXME)
                    if oBoundary.coProcsEXME{iExme}.bFlowIsAProcP2P
                        mfTotalMassChangeBoundary(iBoundaryPhase) = mfTotalMassChangeBoundary(iBoundaryPhase) + (oBoundary.coProcsEXME{iExme}.iSign * oBoundary.coProcsEXME{iExme}.oFlow.fFlowRate);
                        continue
                    else
                        iBranch = find(this.aoBranches == oBoundary.coProcsEXME{iExme}.oFlow.oBranch,1);
                    end
                    if ~isempty(iBranch)
                        mfTotalMassChangeBoundary(iBoundaryPhase) = mfTotalMassChangeBoundary(iBoundaryPhase) + (oBoundary.coProcsEXME{iExme}.iSign * this.afFlowRates(iBranch));
                    else
                        % in this case it is not a multi branch but for
                        % example a manual branch which is simply assumed
                        % to be a boundary condition and constant
                        mfTotalMassChangeBoundary(iBoundaryPhase) = mfTotalMassChangeBoundary(iBoundaryPhase) + (oBoundary.coProcsEXME{iExme}.iSign * oBoundary.coProcsEXME{iExme}.oFlow.fFlowRate);
                    end
                end
            end
            
            for iBoundaryLeft = 1:this.poBoundaryPhases.Count
                for iBoundaryRight = 1:this.poBoundaryPhases.Count
                    if iBoundaryLeft == iBoundaryRight
                        continue
                    else
                        fPressureDifference = (mfMassBoundary(iBoundaryLeft) * mfMassToPressureBoundary(iBoundaryLeft) - mfMassBoundary(iBoundaryRight) * mfMassToPressureBoundary(iBoundaryRight));
                        fAverageMassToPressure = (mfMassToPressureBoundary(iBoundaryLeft) + mfMassToPressureBoundary(iBoundaryRight))/2;
                    end
                    
                    afMaxTimeStep(iBoundaryLeft, iBoundaryRight) = abs(fPressureDifference/(fAverageMassToPressure * (mfTotalMassChangeBoundary(iBoundaryLeft) - mfTotalMassChangeBoundary(iBoundaryRight))));
                end
            end
            % Negative timesteps mean we are already past the
            % equalization and are moving away from it (because of
            % manual flows or active components) Therefore negative
            % values do not have to be considered further. 0 Means
            % we have reached equalization, therefore this can also
            % be ignored for max time step condition
            afMaxTimeStep(afMaxTimeStep <= 0) = inf;
            fTimeStep = min(min(afMaxTimeStep));
            if fTimeStep < this.fMinimumTimeStep
                fTimeStep = this.fMinimumTimeStep;
            end
            this.setTimeStep(fTimeStep);
            
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
                    
                    %TODO get pressure drop distribution (depends on total
                    %     pressure drop and drop coeffs!)
                    %this.chSetBranchFlowRate{iB}(afResults(iR), []);
                    this.chSetBranchFlowRate{iB}(this.afFlowRates(iB), []);
                end
            end
            
            % Ok now go through the results again because the gas flow
            % nodes need the flowrates of all branches to be set before
            % calculating- variable pressure phase pressures
            for iColumn = 1:length(this.csObjUuidsToColIndex)
                oObj = this.poColIndexToObj(iColumn);
                
                if isa(oObj, 'matter.phases.gas_flow_node')
                    oObj.setPressure(afResults(iColumn));
                end
            end
            
            % Don't need the actual pressures right now, but 
            % can easily calculated them using the coeffs!
            %
            
            
            %TODO check total flow rates for each phase, vs. total flow
            %     rates for all connected phases -> calculate time required
            %     for the phases to equalize in mass --> max TS
        end
        
        
        function reUpdate(this)
            % Just re-set flow rates again so branches update from IN phase
            for iR = 1:length(this.csObjUuidsToColIndex)
                oObj = this.poColIndexToObj(iR);
                
                if isa(oObj, 'matter.branch')
                    iB = find(this.aoBranches == oObj, 1);
                    
                    this.chSetBranchFlowRate{iB}(this.afFlowRates(iB), []);
                end
            end
            
        end
    end
end
