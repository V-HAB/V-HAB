function update(this)
    %UPDATE Performs solver calculations
    % The actual calculation of the solver is performed here. For
    % information on the solution routine please view the initial code
    % section!
    
    this.fLastUpdate         = this.oTimer.fTime;
    
    if ~base.oDebug.bOff
        this.out(1, 1, 'update', 'Update multi flow rate solver');
        this.out(1, 2, 'update', 'B %s\t', { this.aoBranches.sName });
    end
    
    for iB = 1:this.iBranches
        this.afFlowRates(iB) = this.aoBranches(iB).fFlowRate;
    end
    
    rError    = inf;
    afResults = [];
    
    if strcmp(this.sMode, 'complex')
         rErrorMax  = this.fMaxError;
    else
         rErrorMax  = 0;
    end
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
    bPressureError = false;
    
    % parameters necessary in case the P2P flowrates oscillate
    iP2PUpdates = 0;
    bP2POscillationDetected = false;
    
    % These values are only used for debugging. Therefore they are also
    % initialized with nans (as nans are ignored during plotting)
    mfFlowRates = nan(this.iMaxIterations, this.iBranches);
    afP2PFlows  = nan(this.iMaxIterations, this.iBranches);
    
    this.fInitializationFlowRate = this.oTimer.fMinimumTimeStep;
    
    while abs(rError) > rErrorMax || this.bFinalLoop || bPressureError %|| iIteration < 5
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
            [ mfFullPhasePressuresAndFlowRates, afFullBoundaryConditions ] = this.generateMatrices(bForceP2PUpdate);
            mfPhasePressuresAndFlowRates = mfFullPhasePressuresAndFlowRates;
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
            
            if ~bP2POscillationDetected && iP2PUpdates > 3
                afP2PDiffLastCalc = afP2PFlows(iP2PUpdates,:)   - afP2PFlows(iP2PUpdates-1,:);
                afP2PDiff1        = afP2PFlows(iP2PUpdates,:)   - afP2PFlows(iP2PUpdates-2,:);
                afP2PDiff2        = afP2PFlows(iP2PUpdates-1,:) - afP2PFlows(iP2PUpdates-3,:);
                
                if ~ bP2POscillationDetected && (any(afP2PDiffLastCalc > (afP2PDiff1 * 100)) || any((afP2PDiffLastCalc > (afP2PDiff2 * 100))))
                    % If this is true the P2Ps are recalculated in every
                    % tick
                    bP2POscillationDetected = true;
                end
            end
            
        else
            [mfPhasePressuresAndFlowRates, afBoundaryConditions] = this.updatePressureDropCoefficients(mfFullPhasePressuresAndFlowRates, afFullBoundaryConditions);
        end
        
        % Infinite values can lead to singular matrixes in the solution
        % process and at least result in badly scaled matrices. Therefore
        % the branches are checked beforehand for pressure drops that are
        % infinite, which means nothing can flow through this branch and 0
        % flowrate must be enforced anyway (e.g. closed valve)
        abZeroFlowBranchesNew = isinf(this.afPressureDropCoeffsSum)';
        
        % For speed optimization this is only performed if anything
        % changed compared to previous steps
        if this.iIteration == 1 || any(abZeroFlowBranchesNew ~= abZeroFlowBranches)
            % Setting the old array to the new one for the next iteration.
            abZeroFlowBranches = abZeroFlowBranchesNew;
            
            % Also set branches which have a pressure difference of less
            % than this.fMinPressureDiff Pa as zero flow branches! This
            % also must be done in each iteration, as the gas flow nodes
            % can change their pressure
            if all(abZeroFlowBranches)
                this.afFlowRates = zeros(1, this.iBranches);
                break
            end
            aoZeroFlowBranches = this.aoBranches(abZeroFlowBranches);
            
            % Initializing the variables we need
            abRemoveRow = false(1,length(mfPhasePressuresAndFlowRates));
            abRemoveColumn = false(1,length(mfPhasePressuresAndFlowRates));
            
            % Setting the columns we want to remove to true
            for sBranchUUID = {aoZeroFlowBranches.sUUID}
                abRemoveColumn(this.tiObjUuidsToColIndex.(sBranchUUID{1})) = true;
            end
            
            % Setting the rows we want to remove to true
            abRemoveRow(this.miBranchIndexToRowID(abZeroFlowBranches)) = true;
            
            % Later we need the number of original rows to size arrays, so
            % we just count them here. 
            iOriginalRows = length(abRemoveRow);
            
            % Calculating the number of new rows we will have once we've
            % done the removal.
            iNewRows = iOriginalRows - sum(abRemoveRow);
            
            % Generating the reference arrays that link old and new column
            % and row indexes. Some of the returned variables are unused,
            % but we still want to keep them around in case we need them in
            % the future. That's why we ignore the "unused variable"
            % warning.
            [ aiOriginalRowToNewRow, aiNewRowToOriginalRow, ...
              aiOriginalColToNewCol, aiNewColToOriginalCol] = ...
                this.createReferenceArrays(iOriginalRows, abRemoveRow, abRemoveColumn); %#ok<ASGLU>
            
            % Getting the indexes of the boundary conditions array that we
            % need to remove. 
            aiRemoveIndexes = this.miBranchIndexToRowID(abZeroFlowBranches);
            
            % If we enclosed a flow phase with two zero flow branches, e.g.
            % by closing two valves, then there are rows and columns with
            % all zeros that need to be removed as well. So we create a
            % test matrix here, remove the rows and columns we have
            % determined so far and then check for these all-zero rows and
            % columns. 
            mfTest = mfPhasePressuresAndFlowRates;
            mfTest(:, abRemoveColumn) = [];
            mfTest(abRemoveRow,:)     = [];
            
            abZeroRows = ~any(mfTest,2);
            abZeroCols = ~any(mfTest,1);
            
            % Initializing a counter
            iRemovedZeroSumEquations = 0;
            
            % If there are any all-zero rows, there must also be all-zero
            % columns, so we only check for one here to save some time.
            if any(abZeroRows)
                % Getting the rows we need to remove
                aiRemoveAdditionalRows = aiNewRowToOriginalRow(abZeroRows);
                
                % Adding these rows to the removal array
                abRemoveRow(aiRemoveAdditionalRows) = true;
                
                % Updating the iNewRows variable with the number of
                % additional rows we need to remove.
                iNewRows = iNewRows - length(aiRemoveAdditionalRows);
                
                % Updating the aiRemoveIndexes array. This operation is
                % only done once, so we ignore the "Variable seems to grow
                % each iteration" warning. 
                aiRemoveIndexes = [ aiRemoveIndexes; aiRemoveAdditionalRows ]; %#ok<AGROW>
                
                % Now we do the same thing for the columns. 
                aiRemoveAdditionalCols = aiNewColToOriginalCol(abZeroCols);
                abRemoveColumn(aiRemoveAdditionalCols) = true;
                
                % The columns will be in the section of the matrix
                % containing the zero sum equations for the flow nodes. So
                % we need to capture here how many of them we have removed
                % so we can later correctly set the iStartZeroSumEquations
                % variable.
                iRemovedZeroSumEquations = length(aiRemoveAdditionalCols);
                
                % And finally we have to re-create the reference arrays
                % since they will have changed. Some of the returned
                % variables are unused, but we still want to keep them
                % around in case we need them in the future. That's why we
                % ignore the "unused variable" warning.
                [ aiOriginalRowToNewRow, aiNewRowToOriginalRow, ...
                  aiOriginalColToNewCol, aiNewColToOriginalCol] = ...
                    this.createReferenceArrays(iOriginalRows, abRemoveRow, abRemoveColumn); %#ok<ASGLU>
                
            end
        end
        
        % Now we actually remove the values
        mfPhasePressuresAndFlowRates(:, abRemoveColumn) = [];
        mfPhasePressuresAndFlowRates(abRemoveRow,:) = [];
        afBoundaryConditions(aiRemoveIndexes,:) = [];
        
        if ~base.oDebug.bOff
            if any(isnan(mfPhasePressuresAndFlowRates))
                this.out(5,1, 'solver', 'NaNs in the Multi-Branch Solver Phase Pressures and/or Flow Rates!');
                [~, aiColumns] = find(isnan(mfPhasePressuresAndFlowRates));
                for iObject = 1:length(aiColumns)
                    sObjectType = this.coColIndexToObj{aiColumns(iObject)}.sEntity;
                    sObjectName = this.coColIndexToObj{aiColumns(iObject)}.sName;
                    this.out(5,2, 'solver', 'A NaN value has occured in the %s ''%s''.', {sObjectType, sObjectName});
                end
            end
            if any(isnan(afBoundaryConditions))
                this.out(5,1, 'solver', 'NaNs in the Multi-Branch Solver Boundary Conditions!');
                aiRows = find(isnan(afBoundaryConditions));
                for iObject = 1:length(aiRows)
                    sObjectType = this.coColIndexToObj{aiRows(iObject)}.sEntity;
                    sObjectName = this.coColIndexToObj{aiRows(iObject)}.sName;
                    this.out(5,2, 'solver', 'A NaN value has occured in the %s ''%s''.', {sObjectType, sObjectName});
                end
            end
        end
        
        % This index decides at which point in the matrix the equations
        % which enforce zero mass change for the gas flow nodes start.
        % These equations are later used to define the branch update order
        % in flow direction
        iStartZeroSumEquations = length(afBoundaryConditions) - length(this.csVariablePressurePhases) + 1 + iRemovedZeroSumEquations;
        
        % Solve
        %hT = tic();
        warning('off','all');
        
        % this is the acutal solving of the matrix system:
        % aafPhasePressuresAndFlowRates * afResults = afBoundaryConditions
        % Where afResults contains gas flow node pressures and
        % branch flowrates
        afResults = mfPhasePressuresAndFlowRates \ afBoundaryConditions;
        
        warning('on','all');
        
        if any(isnan(afResults))
            this.throw('solver', 'NaNs in the Multi-Branch Solver Results!');
        end
        
        toPhasesWithNegativePressures = struct();
        
        % translate the calculated results into branch flowrates or
        % gas flow node pressures
        for iColumn = 1:iNewRows
            % get the corresponding object according to the current column
            % index. Note that in matrix multiplication the column index
            % from the matrix represents the row index from the vector. So
            % the column index from aafPhasePressuresAndFlowRates
            % corresponds to a row index in afResults!
            oObj = this.coColIndexToObj{aiNewColToOriginalCol(iColumn)};
            
            % TO DO: if we can find a way to do this with a boolean it
            % would be a good speed optimization!
            if isa(oObj, 'matter.branch')
                iB = find(this.aoBranches == oObj, 1);
                
                if this.iIteration == 1 || ~strcmp(this.sMode, 'complex')
                    this.afFlowRates(iB) = afResults(iColumn);
                else
                    % In order for the solver to converge better
                    % the flowrates are smoothed out with this
                    % calculation. We don't do this if the current branch
                    % is being corrected for oscillating. 
                    if ~(this.abOscillationCorrectedBranches(iB) && this.bFinalLoop)
                        this.afFlowRates(iB) = (this.afFlowRates(iB) * 5 + afResults(iColumn)) / 6;
                    end
                end
            elseif isa(oObj, 'matter.phases.flow.flow')
                if afResults(iColumn) < 0
                    % This case occurs for example if a manual solver
                    % flowrate is used as boundary condition and forces the
                    % loop flowrates to high values, while the
                    % initialization is at low flow rates. We ignore this
                    % value here and hopefully the solver will calculate
                    % something better in the next iteration. Just in case,
                    % we record the objects here to help with debugging. 
                    toPhasesWithNegativePressures.(oObj.sUUID) = oObj;
                else
                    oObj.setPressure(afResults(iColumn));
                end
            end
        end
        
        if this.bOscillationSuppression && this.bFinalLoop
            this.abOscillationCorrectedBranches = false(this.iBranches,1);
        end
        
        % For the branches which were removed beforehand because they have
        % 0 flowrate anyway, we set this
        % necessary if e.g. checkvalves are used
        this.afFlowRates(abZeroFlowBranches) = 0.75 * this.afFlowRates(abZeroFlowBranches);
        
        % Now we store the calculated flowrates in the matrix, which is
        % quite usefull for debugging purposes
        mfFlowRates(this.iIteration,:) = this.afFlowRates;
        
        % Flowrates smaller than 1e-8 are respected, but no longer
        % considered as errors
        afFrsDiff  = tools.round.prec(abs(this.afFlowRates - afPrevFrs), 8);
        
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
                this.iNumberOfExternalBoundaryBranches ~= sum(this.mbExternalBoundaryBranches) || ...
                isempty(this.iBranchUpdateLevels)
            
            
            this.updateBranchLevelNetwork(mfPhasePressuresAndFlowRates, afBoundaryConditions, iStartZeroSumEquations, iNewRows, aiNewRowToOriginalRow, aiNewColToOriginalCol);
            
        end
        
        if ~base.oDebug.bOff, this.out(1, 2, 'solve-flow-rates', 'Iteration: %i with error %.12f', { this.iIteration, rError }); end
        
        % Check if we have reached the maximum number of iterations.
        if this.iIteration > this.iMaxIterations
            
            % Check if oscillation suppression is turned on.
            if this.bOscillationSuppression 
                
                % Checking if we have not done this in the previous
                % iteration so we don't do it twice. 
                if ~this.bBranchOscillationSuppressionActive
                    % First we need to find out, which branches are
                    % oscillating. So we get all of the individual errors.
                    arErrors = abs(afFrsDiff ./ afPrevFrs);
                    
                    % Now we find the branches that have the maximum error.
                    aiOffendingBranches = find(arErrors == rError);
                    
                    % How many are there?
                    iNumberOfOffendingBranches = length(aiOffendingBranches);
                    
                    % Creating a boolean array to see if we have resolved
                    % all of them in the end.
                    abResolvableBranches = false(iNumberOfOffendingBranches,1);
                    
                    % We need a simple counter to go through the
                    % abResolvableBranches array.
                    iCounter = 1;
                    
                    % What we will actually do here is average the
                    % calculated flow rates in the offending branches. The
                    % following two values determine over how many
                    % iterations we will average. Here it is hard-coded to
                    % be the last 501 iterations. 
                    iLowerRangeLimit = this.iMaxIterations - 500;
                    iUpperRangeLimit = this.iMaxIterations + 1;
                    
                    % Now we go through all offending branches.
                    for iBranch = aiOffendingBranches
                        % As an additional safe guard against setting
                        % unrealistic flow rates we calculate both the mean
                        % and the median of the flow rates in the defined
                        % range and see how far they are apart.
                        fMean = mean(mfFlowRates(iLowerRangeLimit:iUpperRangeLimit,iBranch));
                        fMedian = median(mfFlowRates(iLowerRangeLimit:iUpperRangeLimit,iBranch));
                        
                        % Defining how large the difference between the
                        % mean and median is allowed to be. Here it is hard
                        % coded to be 0.5%.
                        fAllowedDifference = 0.005;
                        
                        % If the difference between mean and median is
                        % small enough, we actually make a change in the
                        % calculated flow rates. 
                        if abs(1 - fMean/fMedian) < fAllowedDifference 
                            % Setting the offending branch's flow rate to
                            % the mean of the past 501 iterations.
                            this.afFlowRates(iBranch) = fMean;
                            
                            % Setting the corresponding field in the
                            % abResolvableBranches array to true so we know
                            % if we got them all.
                            abResolvableBranches(iCounter) = true;
                            
                            % We also need to capture for which branch we
                            % have done this so it is not overwritten again
                            % in the 'Final Loop' of this solver update
                            % step.
                            this.abOscillationCorrectedBranches(iBranch) = true;
                        end
                        
                        % Incrementing the counter. 
                        iCounter = iCounter + 1;
                    end
                    
                    % Checking if we resolved all oscillating branches.
                    if all(abResolvableBranches)
                        % We did it! So we set bFinalLoop to true and set
                        % the oscillation suppression to active, that way
                        % we skip the 'too many iterations' error and just
                        % finish this method. 
                        this.bFinalLoop = true;
                        this.bBranchOscillationSuppressionActive = true;
                    else
                        % if you reach this, please view debugging tipps at the
                        % beginning of this file!
                        keyboard();
                        this.throw('update', 'too many iterations, error %.12f', rError);
                    end
                end
            else
                % if you reach this, please view debugging tipps at the
                % beginning of this file!
                keyboard();
                this.throw('update', 'too many iterations, error %.12f', rError);
            end
        end
    end
    
    this.bBranchOscillationSuppressionActive = false;
    
    %% Setting of final results to afFlowRates
    % during the iteration it is necessary to adapt the results for the
    % next iteration so that the solver can converge. However after it has
    % converged, the actual results must be used to ensure that the zero
    % sum of mass flows over the gas flow nodes is maintained!
    for iColumn = 1:iNewRows
        oObj = this.coColIndexToObj{aiNewColToOriginalCol(iColumn)};
        
        if isa(oObj, 'matter.branch')
            iB = find(this.aoBranches == oObj, 1);
            this.afFlowRates(iB) = afResults(iColumn);
        end
    end
    
    % However, in the desorption case it is still possible that now mass is
    % put into the flow nodes. To solve this either the P2Ps should have a
    % flowrate of 0 in case nothing flows through the flow nodes, or a
    % solution must be found where it is allowed that desorption occurs
    % for no flow through the phase. Or the solution could be that if
    % nothing flows through the flow nodes, the desorption takes place
    % directly in a boundary phase (the P2P would have decide what is the
    % case) where all desorption flowrates from the flow node p2ps are
    % summed up!
    
    if ~base.oDebug.bOff
        this.out(1, 1, 'solve-flow-rates', 'Iterations: %i', { this.iIteration });
        
        for iColumn = 1:length(this.csObjUuidsToColIndex)
            oObj = this.coColIndexToObj{iColumn};
            
            if strcmp(oObj.sObjectType, 'branch')
                abBranch = this.aoBranches == oObj;
                
                this.out(1, 2, 'solve-flow-rates', 'Branch: %s\t%.24f', { oObj.sName, this.afFlowRates(abBranch) });
            end
        end
    end
    
    % Since the last update of the partial mass composition of the flow
    % phases was done before the newest branch flowrates were calculated,
    % we have to update this now. However, the P2Ps are not allowed to
    % update because otherwise the conservation of mass over the flow nodes
    % would no longer be valid!
    this.updateNetwork(false);
    
    % Ok now go through results - variable pressure phase pressures and
    % branch flow rates - and set! This must be done in the update order of
    % the branches to ensure that the variable pressure phase have already
    % inflows, otherwise it is possible that nothing flows because the
    % arPartialMass values of the flow nodes are still 0
    for iBL = 1:this.iBranchUpdateLevels
        
        miCurrentBranches = find(this.mbBranchesPerUpdateLevel(iBL,:));
        
        for iK = 1:length(miCurrentBranches)
            
            iB = miCurrentBranches(iK);
            
            afDeltaPressures = zeros(1,this.aoBranches(iB).iFlowProcs);
            for iF2F = 1:this.aoBranches(iB).iFlowProcs
                if ~this.aoBranches(iB).aoFlowProcs(iF2F).bActive
                    afDeltaPressures(iF2F) = this.aoBranches(iB).aoFlowProcs(iF2F).fDeltaPressure;
                end
            end
            
            % If any pressure difference is infinite, a closed valve is
            % present in the branch!
            if any(isinf(abs(afDeltaPressures))) && this.afFlowRates(iB) ~= 0
                this.chSetBranchFlowRate{iB}(0, afDeltaPressures);
            else
                
                % For constant flowrate boundary conditions it is possible
                % that the pressure drop values are slightly off in some
                % cases. E.g. desorbing CO2 into vacuum where the phase
                % pressures are also very small. Therefore we limit the
                % pressure drops from F2Fs in the branch to the total
                % pressure difference in the branch
                fPressureDifferenceBranch = sign(this.afFlowRates(iB)) * (this.aoBranches(iB).coExmes{1}.oPhase.fPressure - this.aoBranches(iB).coExmes{2}.oPhase.fPressure);
                if sum(afDeltaPressures) > fPressureDifferenceBranch
                    afDeltaPressures = afDeltaPressures .* (fPressureDifferenceBranch/sum(afDeltaPressures));
                end
                
                % If this branch is choked, we need to use different values
                % for afDeltaPressures; the ones we calculated in
                % updatePressureDropCoefficients.
                if this.abChokedBranches(iB) == true
                    afDeltaPressures = this.cafChokedBranchPressureDiffs{iB};
                end

                % Now we can call the setFlowRate callback.
                this.chSetBranchFlowRate{iB}(this.afFlowRates(iB), afDeltaPressures);
            end
        end
    end
    
    if this.bTriggerUpdateCallbackBound
        this.trigger('update');
    end
    
    % now set the flag that this solver is outdated
    this.bRegisteredOutdated = false;
end