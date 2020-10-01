function [afInFlowRates, aarInPartials] = getPhaseInFlows(this, oPhase)

iNumberOfExMes = oPhase.iProcsEXME;
    
afInFlowRates = zeros(iNumberOfExMes, 1);
aarInPartials = zeros(iNumberOfExMes, this.oMT.iSubstances);

for iExme = 1:iNumberOfExMes
    
    oProcExme = oPhase.coProcsEXME{iExme};
    
    % At first skip the P2Ps, we first have to
    % calculate all flowrates except for the P2Ps, then
    % calculate the P2Ps and then consider the
    % necessary changes made by the P2P
    if oProcExme.bFlowIsAProcP2P
        continue;
    end
    
    oBranch = oProcExme.oFlow.oBranch;
    
    
    % Find branch index
    abBranchIndex = strcmp(oBranch.sUUID, this.csBranchUUIDs);
    
    % If the branch is not part of this network solver we consider the
    % branch as a constant boundary flowrate.
    if ~any(abBranchIndex)
        [ fFlowRate, arFlowPartials, ~ ] = oProcExme.getFlowData();
        
        % Dynamically solved branch - get CURRENT flow
        % rate (last iteration), not last time step
        % flow rate!!
    else
        % Get the flow rate
        fFlowRate = oProcExme.iSign * this.afFlowRates(abBranchIndex);
        
        if fFlowRate > 0
            if this.afFlowRates(abBranchIndex) >= 0
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