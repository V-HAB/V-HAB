function updateNetwork(this, bForceP2Pcalc, bManipUpdate)
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
                
                % It must ensured that all branches upstream of the current
                % branch are already update and the phase partial masses
                % are set correctly for this to work!
                
                % TO DO: Find a way to prevent us from having to update
                % each of the two phases for the branch, while also
                % allowing cases where e.g. a flow is used with a manual
                % branch as input, a P2P inside the flow node and a
                % multisolver branch as output
                coCurrentProcExme = this.aoBranches(iB).coExmes;
                
                % If the flowrate is zero we update both phases, to be sure
                % to update all P2Ps
                for iPhase = 1:length(coCurrentProcExme)
                    oPhase = coCurrentProcExme{iPhase}.oPhase;
                    
                    [afInFlowRates, aarInPartials] = this.getPhaseInFlows(oPhase);
                    
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
                        
                        if bManipUpdate
                            if oPhase.iSubstanceManipulators > 0
                                oPhase.toManips.substance.calculateConversionRate(afInFlowRates, aarInPartials);
                            end
                        end
                        
                        if bForceP2Pcalc
                            
                            for iProcP2P = 1:oPhase.iProcsP2P
                                oProcP2P = oPhase.coProcsP2P{iProcP2P};
                                
                                % stationary p2ps are assumed to be
                                % constant for one tick and are calculated
                                % before the branch, therefore they do not
                                % require an update before their flowrate
                                % is used
                                if ~oProcP2P.bStationary
                                    % If the P2P calculations for flow phases
                                    % are calculated we have to get the in flow
                                    % rates of the other p2p side
                                    if oProcP2P.oIn.oPhase ~= oPhase
                                        oOtherPhase = oProcP2P.oIn.oPhase;

                                        [afInsideInFlowRates, aarInsideInPartials] = this.getPhaseInFlows(oOtherPhase);

                                        afOutsideInFlowRate = afInFlowRates;
                                        aarOutsideInPartials = aarInPartials; 
                                    else
                                        oOtherPhase = oProcP2P.oOut.oPhase;

                                        [afOutsideInFlowRate, aarOutsideInPartials] = this.getPhaseInFlows(oOtherPhase);

                                        afInsideInFlowRates = afInFlowRates;
                                        aarInsideInPartials = aarInPartials; 

                                    end

                                    % Update the P2P! (not with update function
                                    % because that is also called at different
                                    % other times!
                                    oProcP2P.calculateFlowRate(afInsideInFlowRates, aarInsideInPartials, afOutsideInFlowRate, aarOutsideInPartials);
                                end
                            end
                        end
                        
                        for iProcP2P = 1:oPhase.iProcsP2P
                            oProcP2P = oPhase.coProcsP2P{iProcP2P};
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