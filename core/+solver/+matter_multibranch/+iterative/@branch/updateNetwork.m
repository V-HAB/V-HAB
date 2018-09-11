function updateNetwork(this, bForceP2Pcalc)
    %UPDATENETWORK Updates the network of branches associated with this solver
    % This function is used to update the network of the solver. P2Ps are
    % only recalculated if either the solver reached initial convergence
    % and the bForceP2Pcalc property is true or if the number of iterations
    % between p2p updates as specified by the user have been reached
    
    % The update is ordered according the branch update levels. Here
    % actually not the branches are updated but rather the gas flow node
    % mass composition (and if required p2p flows). This is done in branch
    % update level order, because this order is according to the flow
    % direction and the gas flow nodes require all ingoing flows and flow
    % partials to be correctly set before they can be calculated. For this
    % reason the update must be performed in the same direction as the flow
    if ~isempty(this.mbBranchesPerUpdateLevel)
        this.arPartialsFlowRates = zeros(this.iBranches, this.oMT.iSubstances);
        
        % Ok now go through results - variable pressure phase pressures and
        % branch flow rates - and set!
        
        mbBranchUpdated = false(this.iBranches,1);
        
        for iBL = 1:this.iBranchUpdateLevels
            
            miCurrentBranches = find(this.mbBranchesPerUpdateLevel(iBL,:));
            
            for iK = 1:length(miCurrentBranches)
                
                iB = miCurrentBranches(iK);
                if mbBranchUpdated(iB)
                    continue
                end
                
                oCurrentBranch   = this.aoBranches(iB);
                
                fFlowRate = this.afFlowRates(iB);
                
                % it must ensured that all branches upstream of the current
                % branch are already update and the phase partial masses
                % are set correctly for this to work!
                if fFlowRate < 0
                    coCurrentProcExme = oCurrentBranch.coExmes(1);
                elseif fFlowRate > 0
                    coCurrentProcExme = oCurrentBranch.coExmes(2);
                else
                    coCurrentProcExme = oCurrentBranch.coExmes;
                end
                
                % if the flowrate is zero we update both phases, to be sure
                % to update all P2Ps
                for iPhase = 1:length(coCurrentProcExme)
                    oPhase = coCurrentProcExme{iPhase}.oPhase;
                    
                    iInflowBranches = 0;
                    
                    afInFlowRates = zeros(oPhase.iProcsEXME + oPhase.iProcsP2Pflow, 1);
                    aarInPartials = zeros(oPhase.iProcsEXME + oPhase.iProcsP2Pflow, this.oMT.iSubstances);
                    for iExme = 1:oPhase.iProcsEXME
                        
                        oProcExme = oPhase.coProcsEXME{iExme};
                        
                        % At first skip the P2Ps, we first have to
                        % calculate all flowrates except for the P2Ps, then
                        % calculate the P2Ps and then consider the
                        % necessary changes made by the P2P
                        if oProcExme.bFlowIsAProcP2P
                            continue;
                        end
                        
                        oBranch = oProcExme.oFlow.oBranch;
                        
                        % If the branch is not part of this network solver
                        % consider it as constant boundary flowrate. TO DO:
                        % check this condition!
                        if ~this.piObjUuidsToColIndex.isKey(oBranch.sUUID)
                            [ fFlowRate, arFlowPartials, ~ ] = oProcExme.getFlowData();
                            
                            % Dynamically solved branch - get CURRENT flow
                            % rate (last iteration), not last time step
                            % flow rate!!
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
                            afInFlowRates(iExme, 1) = fFlowRate;
                            aarInPartials(iExme, :) = arFlowPartials;
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
                        % calculation of the flowrates in case it is below
                        % zero must be changed but during testing sometimes
                        % lead to osciallating P2P flowrates, maybe the
                        % overall network update could be repeated with
                        % bForceP2P = true? Also allow the user to set this
                        % value? Write a setSolverProperties function,
                        % similar to the setTimeStep function of the phase
                        % to set this value and the maximum number of
                        % iterations, as well as the max Error for the
                        % iterative solution
                        if bForceP2Pcalc
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
                                afInFlowRates(oPhase.iProcsEXME + iProcP2P, 1) = -oProcP2P.fFlowRate;
                            else
                                afInFlowRates(oPhase.iProcsEXME + iProcP2P, 1) = oProcP2P.fFlowRate;
                            end
                            aarInPartials(oPhase.iProcsEXME + iProcP2P, :) = oProcP2P.arPartialMass;
                        end
                        
                        % Now the phase is updated again this time with the
                        % partial flowrates of the P2Ps as well!
                        if isempty(afInFlowRates)
                            oPhase.updatePartials(zeros(1,this.oMT.iSubstances));
                        else
                            oPhase.updatePartials(afInFlowRates .* aarInPartials);
                        end
                    end
                end
                mbBranchUpdated(iB) = true;
            end
        end
    end
end
