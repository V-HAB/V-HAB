function [aafPhasePressuresAndFlowRates, afBoundaryConditions] = updatePressureDropCoefficients(this, aafPhasePressuresAndFlowRates, afBoundaryConditions)
    %UPDATEPRESSUREDROPCOEFFICIENTS Updates the F2F procs for all in branch
    % For higher speeds the full network is only calculated a few times,
    % this calculation handles only the necessary update of the pressure
    % drop coefficient
    
    % For this we first loop through all of the branches
    for iB = 1:this.iBranches
        
        % we have to get the branch object to decide if it is
        % active or not and get the current flowrate etc.
        oB = this.aoBranches(iB);
        afPressureDropCoeffs = nan(1, oB.iFlowProcs);
        fFlowRate = this.afFlowRates(iB);
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
        
        % if the branch contains an active component, it is not allowed to
        % have any other f2f procs! And both sides must be gas flow nodes.
        % But this is not checked here for speed reasons. This information
        % is also provided at the beginning in the rules for solver
        % implementation section! Therefore the user should be aware of it
        % and if not, should find it when debugging
        if oB.aoFlowProcs(1).bActive
            bActiveBranch = true;
            % Since this is an active branch, we the set the pressure drop
            % variable to false.
            bPressureDrop = false;
        end
        
        % now we get the corresponding row of this branch in the
        % afBoundaryConditions and aafPhasePressuresAndFlowRates matrix
        iRow = this.miBranchIndexToRowID(iB);
        
        % if the branch is active we calculate the pressure rise and add it
        % to the boundary conditions
        if bActiveBranch
            fCoeffFlowRate = 0;
            
            % Active component --> Get pressure rise based on last
            % iteration flow rate - add to boundary condition!
            fFlowRate   = this.afFlowRates(iB);
            oProcSolver = oB.aoFlowProcs(1).toSolve.(this.sSolverType);
            
            % calDeltas returns POSITIVE value for pressure DROP!
            fPressureRise = oProcSolver.calculateDeltas(fFlowRate);
            
            if fPressureRise > 0
                % Boundary condition for this case can be non zero, both
                % sides must be variable pressure phases
                afBoundaryConditions(iRow) = 0;
                % The pressure rise is positive, so this is actually a
                % pressure drop. Therefore we need to set the boolean
                % variable to true, so this pressure drop is correctly used
                % in the determination of flow rate coefficients.
                bPressureDrop = true;
            else
                fPressureRise = -1 * fPressureRise;
                % the pressure rise is not used directly but smoothed out
                % (TO DO: Check if this actually makes sense)
                fPressureRise = (this.afTmpPressureRise(iB) * 33 + fPressureRise) / 34;
                
                this.afTmpPressureRise(iB) = fPressureRise;
                
                % Boundary condition for this case can be non zero, both
                % sides must be variable pressure phases
                afBoundaryConditions(iRow) = -fPressureRise;
                
                this.afPressureDropCoeffsSum(iB) = 0;
            end
        end
        
        % This part is only executed if there is a 'normal' pressure drop
        % or the active component has produced a pressure drop.
        if bPressureDrop
            % if the branch does not contain an active component, the
            % pressure drops are calculated, summed up and added to the
            % aafPhasePressuresAndFlowRates matrix at the corresping index
            if fFlowRate == 0
                % for no flowrate we check the drops with a very small flow
                fFlowRate = this.fInitializationFlowRate;
                
                % Negative pressure difference? Negative guess!
                if oB.coExmes{1}.getPortProperties() < oB.coExmes{2}.getPortProperties()
                    fFlowRate = -1 * fFlowRate;
                end
            end
            
            % If this is an active branch, then the active component has
            % produced a pressure drop. We can therefore just use the
            % previously calculated pressure difference for the coefficient
            % calculation. Otherwise we get them from the individual
            % processors on the branch.
            if bActiveBranch
                this.afPressureDropCoeffsSum(iB) = fPressureRise/abs(fFlowRate);
            else
                % Now we loop through all the f2fs of the branch and
                % calculate the pressure drops
                for iProc = 1:oB.iFlowProcs
                    afPressureDropCoeffs(iProc) = oB.aoFlowProcs(iProc).toSolve.(this.sSolverType).calculateDeltas(fFlowRate);
                end
                
                % the pressure drops are linearized to drop coefficient by
                % summing them all up and dividing them with the currently
                % assumed flowrate (for laminar this is pretty accurate,
                % for turbulent the correct relationship would be a
                % quadratic dependency on the flowrate. TO DO: Check if
                % implementing that increases speed of the solver!)
                this.afPressureDropCoeffsSum(iB) = sum(afPressureDropCoeffs)/abs(fFlowRate);
            end
            
            
            % now we use this as flowrate coefficient for this branch
            fCoeffFlowRate = this.afPressureDropCoeffsSum(iB);
        end
        
        % get the corresponding column from the matrix for this branch (we
        % already have the row)
        iCol = this.piObjUuidsToColIndex(oB.sUUID);
        
        % now set the value to matrix (remember that drops are provided as
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
        
        fEqualizedPressure = sum(afBoundaryHelper(abEqualize)) / sum(abEqualize);
        
        afBoundaryConditions(abEqualize) = fEqualizedPressure .* miSigns(abEqualize);
    end
    
end