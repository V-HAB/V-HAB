function [aafPhasePressuresAndFlowRates, afBoundaryConditions] = updatePressureDropCoefficients(this, aafPhasePressuresAndFlowRates, afBoundaryConditions)
    %UPDATEPRESSUREDROPCOEFFICIENTS Updates the F2F procs for all in branch
    % For higher speeds the full network is only calculated a few times,
    % this calculation handles only the necessary update of the pressure
    % drop coefficient
    
    if any(isnan(afBoundaryConditions))
        this.throw('updatePDCoeffs','NaN in the pressure drop coefficients.');
    end
    
    % For this we first loop through all of the branches
    for iBranch = 1:this.iBranches
        
        % we have to get the branch object to decide if it is
        % active or not and get the current flowrate etc.
        oBranch = this.aoBranches(iBranch);
        afPressureDrops = nan(1, oBranch.iFlowProcs);
        fFlowRate = this.afFlowRates(iBranch);
        bActiveBranch = false;
        
        % Branches with no active components will cause a pressure drop.
        % Branches with active components usually produce pressure rises,
        % but there are examples where even an active component can produce
        % a pressure drop, for instance when a there is a flow agains the
        % direction of a fan that is so large that the flow rate relative
        % to the fan is negative. In order to catch this edge case we
        % create a boolean variable here to indicate if we have a pressure
        % drop or not.
        bPressureDrop = true;
        
        % Get the corresponding column from the matrix for this branch (we
        % already have the row)
        iCol = this.tiObjUuidsToColIndex.(oBranch.sUUID);
        
        % Now we get the corresponding row of this branch in the
        % afBoundaryConditions and aafPhasePressuresAndFlowRates matrix
        iRow = this.miBranchIndexToRowID(iBranch);
        
        if isempty(oBranch.aoFlowProcs)
            % If no processor is present, assume no pressure loss
            fCoeffFlowRate = 0;
        else
            % If the branch contains an active component, it is not allowed
            % to have any other f2f procs! And both sides must be gas flow
            % nodes. But this is not checked here for speed reasons. This
            % information is also provided at the beginning in the rules
            % for solver implementation section! Therefore the user should
            % be aware of it and if not, should find it when debugging
            if oBranch.aoFlowProcs(1).bActive
                bActiveBranch = true;
                % Since this is an active branch, we the set the pressure
                % drop variable to false.
                bPressureDrop = false;
            end

            % If the branch is active we calculate the pressure rise and
            % add it to the boundary conditions
            if bActiveBranch
                fCoeffFlowRate = 0;

                % Active component --> Get pressure rise based on last
                % iteration flow rate - add to boundary condition!
                fFlowRate   = this.afFlowRates(iBranch);
                oProcSolver = oBranch.aoFlowProcs(1).toSolve.(this.sSolverType);

                % calculateDeltas returns POSITIVE value for pressure DROP!
                fPressureRise = oProcSolver.calculateDeltas(fFlowRate);

                if fPressureRise > 0
                    % Boundary condition for this case can be non zero,
                    % both sides must be variable pressure phases
                    afBoundaryConditions(iRow) = 0;
                    % The pressure rise is positive, so this is actually a
                    % pressure drop. Therefore we need to set the boolean
                    % variable to true, so this pressure drop is correctly
                    % used in the determination of flow rate coefficients.
                    bPressureDrop = true;
                else
                    % Boundary condition for this case can be non zero,
                    % both sides must be variable pressure phases
                    afBoundaryConditions(iRow) = fPressureRise;

                    this.afPressureDropCoeffsSum(iBranch) = 0;
                end
            end

            if any(isnan(afBoundaryConditions))
                this.throw('updatePDCoeffs','NaN in the pressure drop coefficients.');
            end

            % This part is only executed if there is a 'normal' pressure drop
            % or the active component has produced a pressure drop.
            if bPressureDrop
                % If the branch does not contain an active component, the
                % pressure drops are calculated, summed up and added to the
                % aafPhasePressuresAndFlowRates matrix at the corresping
                % index
                if fFlowRate == 0
                    % For no flowrate we check the drops with a very small
                    % flow
                    fFlowRate = this.fInitializationFlowRate;

                    % check for a check valve
                    if any([oBranch.aoFlowProcs.bCheckValve])
                        % if one is present use the open condition for the
                        % check valve for the guess
                        if oBranch.aoFlowProcs([oBranch.aoFlowProcs.bCheckValve]).bReversed
                            fFlowRate = -1 * fFlowRate;
                        end
                    else
                        % Negative pressure difference? Negative guess!
                        if oBranch.coExmes{1}.oPhase.fPressure < oBranch.coExmes{2}.oPhase.fPressure
                            fFlowRate = -1 * fFlowRate;
                        end
                    end
                end

                % If this is an active branch, then the active component
                % has produced a pressure drop. We can therefore just use
                % the previously calculated pressure difference for the
                % coefficient calculation. Otherwise we get them from the
                % individual processors on the branch.
                if bActiveBranch
                    this.afPressureDropCoeffsSum(iBranch) = fPressureRise/abs(fFlowRate);
                else
                    % If this branch has the choked flow check activated, we do
                    % the check. If the flow is choked, we overwrite the
                    % fFlowRate variable with the choked flow rate.
                    if this.abCheckForChokedFlow(iBranch) == true
                        [ bChokedFlow, fChokedFlowRate, iChokedProc, fPressureDiff ] = this.checkForChokedFlow(iBranch);
                        if bChokedFlow
                            fFlowRate = fChokedFlowRate;
                            
                            % Setting the property variable to true for this
                            % branch.
                            this.abChokedBranches(iBranch) = true;
                        end
                    end
                    
                    % Now we loop through all the f2fs of the branch and
                    % calculate the pressure drops
                    for iProc = 1:oBranch.iFlowProcs
                        afPressureDrops(iProc) = oBranch.aoFlowProcs(iProc).toSolve.(this.sSolverType).calculateDeltas(fFlowRate);
                    end
                    
                    % If this branch is choked and there are no closed valves
                    % we need to set the pressure drop for the processor that
                    % is choked to the pressure difference between the left and
                    % right sides of the branch, minus the pressure drop caused
                    % by all of the other processors in the branch.
                    if this.abCheckForChokedFlow(iBranch) == true && bChokedFlow && ~any(isinf(afPressureDrops))
                        % Calculating the pressure drop across the choked proc.
                        afPressureDrops(iChokedProc) = fPressureDiff - sum(afPressureDrops(1:end ~= iChokedProc));
                        
                        % Saving the pressure drops across the branch in the
                        % property so we can access it in update().
                        this.cafChokedBranchPressureDiffs{iBranch} = afPressureDrops;
                    else
                        % The branch is not choked.
                        this.abChokedBranches(iBranch) = false;
                    end

                    if any(isnan(afPressureDrops))
                        this.throw('updatePDCoeffs','NaN in the pressure drops.');
                    end

                    abFlowRateDependenPressureDrops = [oBranch.aoFlowProcs.bFlowRateDependPressureDrop];
                    % The pressure drops are linearized to drop coefficient
                    % by summing them all up and dividing them with the
                    % currently assumed flowrate (for laminar this is
                    % pretty accurate, for turbulent the correct
                    % relationship would be a quadratic dependency on the
                    % flowrate. 
                    %TODO: Check if implementing that increases speed of
                    % the solver!) 
                    this.afPressureDropCoeffsSum(iBranch) = sum(afPressureDrops(abFlowRateDependenPressureDrops))/abs(fFlowRate);
                    
                    if any(~abFlowRateDependenPressureDrops)
                        iSign = sign(this.afFlowRates(iBranch));
                        if iSign == 0
                            iSign = 1;
                        end

                        afBoundaryConditions(iRow) = afBoundaryConditions(iRow) + iSign * sum(afPressureDrops(~abFlowRateDependenPressureDrops));
                    end
                end


                % Now we use this as flowrate coefficient for this branch
                fCoeffFlowRate = this.afPressureDropCoeffsSum(iBranch);
            end
        end
            
        % Now set the value to matrix (remember that drops are provided as
        % positive values, therefore here the sign -1 is used)
        aafPhasePressuresAndFlowRates(iRow, iCol) = -1 * fCoeffFlowRate;
        
    end
    
    % We want to ignore small pressure differences (as specified by the
    % user). Therefore we equalize pressure differences smaller than the
    % specified limit in the boundary conditions!
    afBoundaryHelper = afBoundaryConditions(1:length(this.aoBranches));
    miSigns = sign(afBoundaryHelper);
    afBoundaryHelper = abs(afBoundaryHelper);
    for iBoundary = 1:length(afBoundaryHelper)
        abEqualize = abs(afBoundaryHelper - afBoundaryHelper(iBoundary)) < this.fMinPressureDiff & ~(afBoundaryHelper == 0);
        
        if sum(abEqualize) > 0
            fEqualizedPressure = sum(afBoundaryHelper(abEqualize)) / sum(abEqualize);

            afBoundaryConditions(abEqualize) = fEqualizedPressure .* miSigns(abEqualize);
        end
        if any(isnan(afBoundaryConditions))
            this.throw('updatePDCoeffs','NaN in the pressure drop coefficients.');
        end
    end
    
end