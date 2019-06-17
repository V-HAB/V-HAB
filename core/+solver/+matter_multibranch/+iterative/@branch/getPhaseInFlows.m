function [afInFlowRates, aarInPartials] = getPhaseInFlows(this, oPhase)

afInFlowRates = zeros(oPhase.iProcsEXME + oPhase.iProcsP2P, 1);
aarInPartials = zeros(oPhase.iProcsEXME + oPhase.iProcsP2P, this.oMT.iSubstances);

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
    if ~(oBranch.oHandler == this)
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
        afInFlowRates(iExme, 1) = fFlowRate;
        aarInPartials(iExme, :) = arFlowPartials;
    end
end
end