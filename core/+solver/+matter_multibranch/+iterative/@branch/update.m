function update(this)
    %UPDATE Performs solver calculations
    % The actual calculation of the solver is performed here. For
    % information on the solution routine please view the initial code
    % section!
    
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
    
    % For an additional steady state solver there are basically two cases:
    % A loop with an active component generating a pressure difference and
    % a loop without such a component that only equalizes the pressures. To
    % decide whether the steady state has been reached we can calculate the
    % steady state condition initially using the steady state solver, and
    % then compare the calculated solution to this steady state solution
    % --> Include mechanic to identify the individual components in the
    % current system of equations (active components, pressure losses,
    % phase pressures etc). The the steady state solver can see what the
    % final pressure difference should be in a loop (zero without active
    % component, active component pressure changes with active component).
    % The next step would be to set flowrates for equalizing branches to
    % zero (done here) and to iterate the active component branches
    
    % The initial flow rates are all zero, so initial rError below will be
    % inf -> that's good, e.g. the p2ps need a correct set of flow rate
    % directions to be included in equations!
    
    % The final loop is reached if the solver converged, in this case the
    % p2ps are also updated (which reduces the number of calls for p2p
    % updates) and the solver is recalculated with the new p2p flows. This
    % is repeated again until the solver reaches overall convergence
    % Initially true so that in the first tick the matrices are calculated!
    this.bFinalLoop = true;
    
    % parameters necessary in case the P2P flowrates oscillate
    iP2PUpdates = 0;
    bP2POscillationDetected = false;
    
    % These values are only used for debugging. Therefore they are also
    % initialized with nans (as nans are ignored during plotting)
    mfFlowRates = nan(this.iMaxIterations, this.iBranches);
    afP2PFlows = nan(this.iMaxIterations, this.iBranches);
    
    while abs(rError) > rErrorMax || this.bFinalLoop %|| iIteration < 5
        this.iIteration = this.iIteration + 1;
        
        % if we have reached convergence recalculate the p2ps
        if this.bFinalLoop || (mod(this.iIteration, this.iIterationsBetweenP2PUpdate) == 0) || bP2POscillationDetected
            bForceP2PUpdate = true;
        else
            bForceP2PUpdate = false;
        end
        
        afPrevFrs  = this.afFlowRates;
        
        % only in the beginning and after convergence the whole network is
        % rebuilt to ensure that the correct solution is reached. Otherwise
        % we only update the pressure drop coefficients in the exisiting
        % matrices
        if bForceP2PUpdate
            % Regenerates matrices, gets coeffs from flow procs
            [ aafFullPhasePressuresAndFlowRates, afFullBoundaryConditions ] = this.generateMatrices(bForceP2PUpdate);
            aafPhasePressuresAndFlowRates = aafFullPhasePressuresAndFlowRates;
            afBoundaryConditions = afFullBoundaryConditions;
            
            % The p2ps are only updated once at the beginning and after the
            % solver converged (to reduce the calculation time for more
            % extensive P2P calculations, can be overwritten by the user).
            % However, the disadvantage of this is that oscillations can
            % occur in certain cases. These osciallations are detected by
            % the algorithm, which then activates the update of P2Ps in
            % every tick once necessary
            iP2PUpdates = iP2PUpdates + 1;
            
            iStartZeroSumEquationsFull = length(afFullBoundaryConditions) - length(this.csVariablePressurePhases)+1;
            afP2PFlowsHelper = afFullBoundaryConditions(iStartZeroSumEquationsFull:end)';
            afP2PFlows(iP2PUpdates, 1:length(afP2PFlowsHelper)) = afP2PFlowsHelper;
            
            if bP2POscillationDetected
                afBoundaryConditions(iStartZeroSumEquationsFull:end) = (sum(afP2PFlows(iP2PUpdates-2:iP2PUpdates, 1:length(afP2PFlowsHelper)),1)./3)';
            end
            
            if ~bP2POscillationDetected && iP2PUpdates > 3
                afP2PDiffLastCalc   = afP2PFlows(iP2PUpdates,:)   - afP2PFlows(iP2PUpdates-1,:);
                afP2PDiff1          = afP2PFlows(iP2PUpdates,:)   - afP2PFlows(iP2PUpdates-2,:);
                afP2PDiff2          = afP2PFlows(iP2PUpdates-1,:) - afP2PFlows(iP2PUpdates-3,:);
                
                if ~ bP2POscillationDetected && (any(afP2PDiffLastCalc > (afP2PDiff1 * 100)) || any((afP2PDiffLastCalc > (afP2PDiff2 * 100))))
                    % If this is true the P2Ps are recalculated in every
                    % tick
                    bP2POscillationDetected = true;
                end
            end
            
        else
            [aafPhasePressuresAndFlowRates, afBoundaryConditions] = this.updatePressureDropCoefficients(aafFullPhasePressuresAndFlowRates, afFullBoundaryConditions);
        end
        
        % Infinite values can lead to singular matrixes in the solution
        % process and at least result in badly scaled matrices. Therefore
        % the branches are checked beforehand for pressure drops that are
        % infinite, which means nothing can flow through this branch and 0
        % flowrate must be enforced anyway (e.g. closed valve)
        mbZeroFlowBranchesNew = isinf(this.afPressureDropCoeffsSum)';
        % for speed optimization this is only performed if anything
        % changed compared to previous steps
        if this.iIteration == 1 || any(mbZeroFlowBranchesNew ~= mbZeroFlowBranches)
            
            mbZeroFlowBranches = mbZeroFlowBranchesNew;
            
            % Also set branches which have a pressure difference of less
            % than this.fMinPressureDiff Pa as zero flow branches! This
            % also must be done in each iteration, as the gas flow nodes
            % can change their pressure
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
            
            mbRemoveRow(this.miBranchIndexToRowID(mbZeroFlowBranches)) = true;
            iOriginalRows = length(mbRemoveRow);
            
            iNewRows = iOriginalRows - sum(mbRemoveRow);
            
            % in order to remove the branches without a flow but still be
            % able to have the correct indices for every sitation we have
            % to build a index transformation from the full matrix to the
            % reduced matrix and vice versa
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
            
        end
        
        % now we actuall remove the values
        aafPhasePressuresAndFlowRates(:, mbRemoveColumn) = [];
        aafPhasePressuresAndFlowRates(mbRemoveRow,:) = [];
        afBoundaryConditions((this.miBranchIndexToRowID(mbZeroFlowBranches)),:) = [];
        
        % This index decides at which point in the matrix the equations
        % which enforce zero mass change for the gas flow nodes start.
        % These equations are later used to define the branch update order
        % in flow direction
        iStartZeroSumEquations = length(afBoundaryConditions) - length(this.csVariablePressurePhases)+1;
        
        % Solve
        %hT = tic();
        warning('off','all');
        
        % this is the acutal solving of the matrix system:
        % aafPhasePressuresAndFlowRates * afResults = afBoundaryConditions
        % Where afResults contains gas flow node pressures and
        % branch flowrates
        afResults = aafPhasePressuresAndFlowRates \ afBoundaryConditions;
        
        warning('on','all');
        
        % translate the calculated results into branch flowrates or
        % gas flow node pressures
        for iColumn = 1:iNewRows
            % get the corresponding object according to the current column
            % index. Note that in matrix multiplication the column index
            % from the matrix represents the row index from the vector. So
            % the column index from aafPhasePressuresAndFlowRates
            % corresponds to a row index in afResults!
            oObj = this.poColIndexToObj(miNewColToOriginalCol(iColumn));
            
            % TO DO: if we can find a way to do this with a boolean it
            % would be a good speed optimization!
            if isa(oObj, 'matter.branch')
                iB = find(this.aoBranches == oObj, 1);
                
                if this.iIteration == 1 || ~strcmp(this.sMode, 'complex')
                    this.afFlowRates(iB) = afResults(iColumn);
                else
                    % in order for the solver to converge better
                    % the flowrates are smoothed out with this
                    % calculation
                    this.afFlowRates(iB) = (this.afFlowRates(iB) * 3 + afResults(iColumn)) / 4;
                end
            elseif isa(oObj, 'matter.phases.gas_flow_node')
                oObj.setPressure(afResults(iColumn));
            end
        end
        
        % for the branches which were removed beforehand because they have
        % 0 flowrate anyway, we set this
        for iZeroBranch = 1:iZeroFlowBranches
            iB = find(this.aoBranches == aoZeroFlowBranches(iZeroBranch), 1);
            % necessary if e.g. checkvalves are used
            this.afFlowRates(iB) = 0.75 * this.afFlowRates(iB);
        end
        % now we store the calculated flowrates in the matrix, which is
        % quite usefull for debugging purposes
        mfFlowRates(this.iIteration,:) = this.afFlowRates;
        
        iPrecision = this.oTimer.iPrecision;
        afFrsDiff  = tools.round.prec(abs(this.afFlowRates - afPrevFrs), iPrecision);
        
        rError = max(abs(afFrsDiff ./ afPrevFrs));
        % if the error is smaller than the limit, do one final update where
        % the recalculation of P2P flowrates is enforced. If after that the
        % error is still smaller than the limit, the iteration is finished,
        % otherwise it continues normally again
        if this.bFinalLoop && rError < this.fMaxError
            this.bFinalLoop = false;
        elseif rError < this.fMaxError
            this.bFinalLoop = true;
        else
            this.bFinalLoop = false;
        end
        
        % Check if we have to rebuilt the update level matrix
        if any(sign(afPrevFrs) ~= sign(this.afFlowRates)) || any(this.afFlowRates(afPrevFrs == 0)) ||...
                this.iNumberOfExternalBoundaryBranches ~= sum(this.mbExternalBoundaryBranches)
            
            this.updateBranchLevelNetwork(aafPhasePressuresAndFlowRates, afBoundaryConditions, iStartZeroSumEquations, iNewRows, miNewRowToOriginalRow, miNewColToOriginalCol);
            
        end
        
        if ~base.oLog.bOff, this.out(1, 2, 'solve-flow-rates', 'Iteration: %i with error %.12f', { this.iIteration, rError }); end
        
        if this.iIteration > this.iMaxIterations
            % if you reach this, please view debugging tipps at the
            % beginning of this file!
            keyboard();
            this.throw('update', 'too many iterations, error %.12f', rError);
        end
    end
    
    %% Setting of final results to afFlowRates
    % during the iteration it is necessary to adapt the results for the
    % next iteration so that the solver can converge. However after it has
    % converged, the actual results must be used to ensure that the zero
    % sum of mass flows over the gas flow nodes is maintained!
    for iColumn = 1:iNewRows
        oObj = this.poColIndexToObj(miNewColToOriginalCol(iColumn));
        
        if isa(oObj, 'matter.branch')
            iB = find(this.aoBranches == oObj, 1);
            this.afFlowRates(iB) = afResults(iColumn);
        end
    end
    % We have to reupdate this as well to calculate the P2P flowrates with
    % the final results
    this.generateMatrices();
    
    % However, in the desorption case it is still possible that now mass is
    % put into the flow nodes. To solve this either the P2Ps should have a
    % flowrate of 0 in case nothing flows through the flow nodes, or a
    % solution muste be found where it is allowed that desorption occurs
    % for no flow through the phase. Or the solution could be that if
    % nothing flows through the flow nodes, the desorption takes place
    % directly in a boundary phase (the P2P would have decide what is the
    % case) where all desorption flowrates from the flow node p2ps are
    % summed up!
    
    if ~base.oLog.bOff, this.out(1, 1, 'solve-flow-rates', 'Iterations: %i', { this.iIteration }); end
    
    for iColumn = 1:length(this.csObjUuidsToColIndex)
        oObj = this.poColIndexToObj(iColumn);
        
        if isa(oObj, 'matter.branch')
            iB = find(this.aoBranches == oObj, 1);
            
            if ~base.oLog.bOff, this.out(1, 2, 'solve-flow-rates', 'Branch: %s\t%.24f', { oObj.sName, this.afFlowRates(iB) }); end
        end
    end
    % Ok now go through results - variable pressure phase pressures and
    % branch flow rates - and set! This must be done in the update order of
    % the branches to ensure that the variable pressure phase have already
    % inflows, otherwise it is possible that nothing flows because the
    % arPartialMass values of the flow nodes are still 0
    
    for iBL = 1:this.iBranchUpdateLevels
        
        miCurrentBranches = find(this.mbBranchesPerUpdateLevel(iBL,:));
        
        for iK = 1:length(miCurrentBranches)
            
            iB = miCurrentBranches(iK);
            
            this.chSetBranchFlowRate{iB}(this.afFlowRates(iB), []);
        end
    end
    
    this.calculateTimeStep();
    
end