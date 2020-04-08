function updateBranchLevelNetwork(this, aafPhasePressuresAndFlowRates, afBoundaryConditions, iStartZeroSumEquations, iNewRows, miNewRowToOriginalRow, miNewColToOriginalCol)
    %UPDATEBRANCHLEVELNETWORK Summary of this function goes here
    % the solver must start updating the branches and phases from the
    % boundary phases and then move flow direction downward. Otherwise it
    % is possible that flow nodes are set with outflows but no inflows,
    % which results in flows with a flowrate but not partial masses.
    % However, only do this if the flowrates have changed direction or
    % became zero!
    mbBoundaryRows = false(iNewRows,1);
    mbBoundaryRows(1:iStartZeroSumEquations-1) = afBoundaryConditions(1:iStartZeroSumEquations-1) ~= 0;
    miBoundaryBranches = miNewRowToOriginalRow(mbBoundaryRows);
    
    % get the part of the equation that connects phases and branches (it
    % contains the sum over each variable pressure phase and ensures that
    % the total mass flow through it is 0)
    aafZeroSumMatrix = aafPhasePressuresAndFlowRates(iStartZeroSumEquations:end,:);
    
    % change the sign of the matrix to reflect the current flowrate
    % direction, also get the current branch to column index matrix
    miBranchToColumnIndex = zeros(this.iBranches,1);
    for iBranch = 1:this.iBranches
        iCol = this.tiObjUuidsToColIndex.(this.aoBranches(iBranch).sUUID);
        mbCol = miNewColToOriginalCol == iCol;
        if any(mbCol)
            miBranchToColumnIndex(iBranch) = find(mbCol);
            aafZeroSumMatrix(:,mbCol) = aafZeroSumMatrix(:,mbCol) .* sign(this.afFlowRates(iBranch));
        end
    end
    
    % now remove the boundary branches that are exiting the system, we want
    % to start from the boundary branches that enter the system
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
    % the previous algorithm found branches that are connected to a
    % boundary pase, now we add the branches which have an external branch
    % flowrate attached to them
    miExternalBranches = find(this.mbExternalBoundaryBranches);
    miBoundaryBranches(end+1:end+length(miExternalBranches)) = miExternalBranches;
    
    % The update level increases for branches further
    % downstream, it is initialized to one for the first branch
    % and the vector is initialized to zero (if a zero remains
    % in the end, it means that branch has 0 flowrate or it is
    % not part of this loop)
    iBranchUpdateLevel = 1;
    miUpdateLevel = zeros(this.iBranches,1);
    
    % Continue the loop until a boundary phase is reached or the starting
    % variable pressure phase is reached
    bFinished = false;
    
    this.iBranchUpdateLevels = this.iBranches+1;
    % Inititlize the update level to be false, all branches
    % on this level will be set to true in the while loop
    mbBranchesOnUpdateLevel = false(this.iBranches+1,this.iBranches);
    mbBranchesOnUpdateLevel(1,miBoundaryBranches) = true;
    
    % Here we need a while loop as we initially do not know
    % the shape and size of the network!
    while ~bFinished
        % If we have an update level assigned for all branches we can stop
        % the while loop
        if (iBranchUpdateLevel > this.iBranches) || ~any(mbBranchesOnUpdateLevel(iBranchUpdateLevel,:))
            break
        end
        
        % get the branches on the current update level
        mbBranches = mbBranchesOnUpdateLevel(iBranchUpdateLevel,:);
        miBranches = find(mbBranches);
        
        % now loop through these branches and check where they lead by
        % getting their connected gas flow nodes. If the branch is
        % connected to a boundary node it is either a beginning or end of a
        % loop
        for iI = 1:length(miBranches)
            iBranch = miBranches(iI);
            miUpdateLevel(iBranch) = iBranchUpdateLevel;
            
            if miBranchToColumnIndex(iBranch) == 0
                continue
            else
                % the zero sum equation contains all branches conected to
                % the gas flow node (and only the gas flow nodes) together
                % with the corresponding signs, therefore we can use it to
                % define the update order
                miPhases = find(aafZeroSumMatrix(:,miBranchToColumnIndex(iBranch)) > 0);
            end
            
            for iPhase = 1:length(miPhases)
                % we want to know where this branch leads, therefore we
                % require the negative entries here
                miBranchesNext = find(aafZeroSumMatrix(miPhases(iPhase), :) == -1);
                for iK = 1:length(miBranchesNext)
                    oB = this.coColIndexToObj{miNewColToOriginalCol(miBranchesNext(iK))};
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
    
    % this is the next level of branches, basically with this we loop
    % through all of the branches in order of their flows
    for iBoundaryBranch = 1:length(miBoundaryBranches)
        mbBranchesOnUpdateLevel = false(this.iBranches+1,this.iBranches);
        mbBranchesOnUpdateLevel(1,miBoundaryBranches(iBoundaryBranch)) = true;
        
        iBranchUpdateLevel = 1;
        iBoundaryPhase = 0;
        coOtherSidePhase = cell(100,0);
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
                    % we want to know where this branch leads, therefore we
                    % require the negative entries here
                    miBranchesNext = find(aafZeroSumMatrix(miPhases(iPhase), :) == -1);
                    for iK = 1:length(miBranchesNext)
                        oB = this.coColIndexToObj{miNewColToOriginalCol(miBranchesNext(iK))};
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
                            iBoundaryPhase = iBoundaryPhase + 1;
                            coOtherSidePhase{iBoundaryPhase} = oB.coExmes{iExme}.oPhase;
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
        
        coOtherSidePhase = coOtherSidePhase(1:iBoundaryPhase);
        this.tBoundaryConnection.(oBoundaryPhase.sUUID) = coOtherSidePhase;
    end
end