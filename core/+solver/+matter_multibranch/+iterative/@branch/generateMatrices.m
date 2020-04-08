function [ aafPhasePressuresAndFlowRates, afBoundaryConditions ] = generateMatrices(this, bForceP2Pcalc)
    %GENERATEMATRICES Generates matrices for system of equations
    % This function builds the Matrix described in the beginning and the
    % boundary condition vector. It is not updated all the time as this
    % should not change that often.
    %
    % aafPhasePressuresAndFlowRates contains the pressure drops from the
    % branches and the gas flow node pressures
    %
    % afBoundaryConditions is the B vector mostly with the boundary node
    % pressures, fan pressure deltas and external flowrates
    
    if nargin < 2
        bForceP2Pcalc = false;
    end
    
    this.afPressureDropCoeffsSum = nan(1, this.iBranches);
    
    % One equation per branch, one per variable pressure phase
    iVariablePressurePhases = length(this.csVariablePressurePhases);
    iMatrixHeight           = this.iBranches + iVariablePressurePhases;
    
    aafPhasePressuresAndFlowRates = zeros(iMatrixHeight, iMatrixHeight);
    afBoundaryConditions          = zeros(iMatrixHeight, 1);
    
    iRow = 0;
    
    this.miBranchIndexToRowID = zeros(this.iBranches,1);
    % Loop branches, generate equation row to calculate flow rate
    % DP = C * FR, or P_Left - P_Right = C * FR
    
    if bForceP2Pcalc
        this.updateNetwork(bForceP2Pcalc);
    end
    
    for iB = 1:this.iBranches
        
        iRow = iRow + 1;
        oB   = this.aoBranches(iB);
        this.miBranchIndexToRowID(iB) = iRow;
        
        % Equation depending on pressure left/right
        %   P-T, T-P, T-T, P-P
        % If left side of branch - positive value on matrix, negative on
        % vector. Vice versa for right side.
        iSign = 1;
        
        for iP = 1:2
            oE = oB.coExmes{iP};
            oP = oB.coExmes{iP}.oPhase;
            
            if this.poBoundaryPhases.isKey(oP.sUUID)
                % NEGATIVE - right side! For second iteration, sign would
                % be negative - i.e. value added!
                % If both are boundary conditions, that means
                % 0 - P_left + P_right = P_right - P_left
                % This is ok, as the flow coeff above is also added with a
                % negative sign, i.e.:
                % -C * FR = P_right - P_left     | *-1
                % C * FR  = - P_right + P_left
                afBoundaryConditions(iRow) = afBoundaryConditions(iRow) ...
                    - iSign * oE.getExMeProperties(); 
                
                % In case the pressure difference is smaller than our
                % minimum pressure difference, we set the boundary
                % condition to zero. That makes it easier for the solver to
                % find a solution.
                if iP == 2 && abs(afBoundaryConditions(iRow)) < this.fMinPressureDiff
                    afBoundaryConditions(iRow) = 0;
                end
                
                if ~base.oDebug.bOff, this.out(1, 3, 'props', 'Phase %s-%s: Pressure %f', { oP.oStore.sName, oP.sName, oE.getExMeProperties() }); end
                
            else
                iCol = this.tiObjUuidsToColIndex.(oP.sUUID);
                
                aafPhasePressuresAndFlowRates(iRow, iCol) = iSign;
            end
            
            
            % Multiplication not really necessary, only two loops
            iSign = -1 * iSign;
        end
    end
    
    % Loop variable pressure phases, generate eq row to enforce sum of flow
    % rates is zero (or the BC/p2p conds)
    for iP = 1:iVariablePressurePhases
        iRow   = iRow + 1;
        oP     = this.poVariablePressurePhases(this.csVariablePressurePhases{iP});
        fFrSum = 0;
        iAdded = 0;
        
        miBranches = zeros(oP.iProcsEXME,1);
        
        bExternalBranch = false;
        % Connected branches - col indices in matrix
        for iB = 1:oP.iProcsEXME
            % P2Ps definitely not solved by this solver.
            if isa(oP.coProcsEXME{iB}.oFlow, 'matter.procs.p2p')
                continue;
            end
            
            oB = oP.coProcsEXME{iB}.oFlow.oBranch;
            
            % Ok now check - if this phase is on exme 1, i.e. the left side
            % - positive flow rate means OUTWARDS. If on the right side,
            % positive means INWARDS.
            % Therefore if on exme 1, and positive, value must be negative,
            % i.e. sign -1
            iSign = oP.coProcsEXME{iB}.iSign;
            
            % Not solved by us? Use as boundary cond flow rate!
            if ~isfield(this.tiObjUuidsToColIndex, oB.sUUID)
                fFrSum = fFrSum - iSign * oB.fFlowRate;
                if oB.fFlowRate ~= 0
                    bExternalBranch = true;
                end
            else
                miBranches(iB) = find(this.aoBranches == oB);
                
                iCol = this.tiObjUuidsToColIndex.(oB.sUUID);
                
                aafPhasePressuresAndFlowRates(iRow, iCol) = iSign;
                iAdded = iAdded + 1;
            end
        end
        if bExternalBranch
            miBranches(miBranches == 0) = [];
            this.mbExternalBoundaryBranches(miBranches) = true;
        end
        % Now go through the P2Ps and get their flowrates
        if oP.iProcsP2P > 0
            for iProcP2P = 1:oP.iProcsEXME
                if oP.coProcsEXME{iProcP2P}.bFlowIsAProcP2P
                    fFrSum = fFrSum - oP.coProcsEXME{iProcP2P}.iSign * oP.coProcsEXME{iProcP2P}.oFlow.fFlowRate;
                end
            end
        end
        
        % If unsolved branch as BC, one solved branch is sufficient.
        % If no branch added, don't add bc flow rate. This is a VPP so that
        % would only be valid if the inflow is zero! And that does not
        % really make sense.
        if fFrSum ~= 0
            if iAdded >= 1
                afBoundaryConditions(iRow) = fFrSum;
            else
                this.throw('generateMatrices', 'BC flows (manual solver or p2p) but no variable, solved branches connected!');
            end
        end
    end
    
    % Now we use the subfunction to update the pressure drop and rise
    % coefficients. This is a seperate function because this is the only
    % part of the calculation that must be executed in every iteration!
    [aafPhasePressuresAndFlowRates, afBoundaryConditions] = updatePressureDropCoefficients(this, aafPhasePressuresAndFlowRates, afBoundaryConditions);
    
    this.iNumberOfExternalBoundaryBranches = sum(this.mbExternalBoundaryBranches);
end
