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
    
    % If the branch is not part of this network solver the statments in the
    % following try-block will fail. We then consider the branch as a
    % constant boundary flowrate.
    try
        % Find branch index
        abBranchIndex = strcmp(oBranch.sUUID, this.csBranchUUIDs);
        
        % Get the flow rate
        fFlowRate = oProcExme.iSign * this.afFlowRates(abBranchIndex);
        
        if fFlowRate > 0
            if this.afFlowRates(abBranchIndex) >= 0
                arFlowPartials = oBranch.coExmes{1}.oPhase.arPartialMass;
            else
                arFlowPartials = oBranch.coExmes{2}.oPhase.arPartialMass;
            end
        end
        
    catch oError  %#ok<NASGU> Don't need to do anything with the error here
        [ fFlowRate, arFlowPartials, ~ ] = oProcExme.getFlowData();
        
        % Dynamically solved branch - get CURRENT flow
        % rate (last iteration), not last time step
        % flow rate!!
    end
    
    % Only for INflows
    if fFlowRate > 0
        afInFlowRates(iExme, 1) = fFlowRate;
        aarInPartials(iExme, :) = arFlowPartials;
    end
end
end