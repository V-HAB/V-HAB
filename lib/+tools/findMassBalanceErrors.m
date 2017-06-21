function [ ] = findMassBalanceErrors( oInput, fAccuracy, fMaxMassBalanceDifference, bSetBreakPoints )
% a helper function that can be used within any part of the V-HAB code, it
% just has to be supplied the matter table object. It will display the
% location of mass errors (in case any occur for the ticks where the
% function is executed)
%
% The accuracy input can be set to define from which value onward mass
% errors will be regarded. For example for a value of 0 it will regard any
% change as error for a value of 1e-15 it will only consider mass changes
% of more than 1e-15 kg/s as errors
    
    if nargin < 2
        fAccuracy = 0;
    end
    if nargin < 3
        fMaxMassBalanceDifference =  inf;
    end
    if nargin < 4
        bSetBreakPoints =  false;
    end
    
    if isa(oInput, 'matter.table')
        aoPhases = oInput.aoPhases;
        aoFlows  = oInput.aoFlows;
        oMT = oInput;
    elseif isa(oInput, 'matter.phase')
        aoPhases = oInput;
        oMT = oInput.oMT;
        
        for iExme = 1:aoPhases.iProcsEXME
            aoFlows(iExme) = aoPhases.coProcsEXME{iExme}.oFlow;
        end
    else
        error('provide matter table or phase as input')
    end
    
    
    %% Check branches and P2Ps
    for iFlow = 1:length(aoFlows)
        
        if isempty(aoFlows(iFlow).oBranch)
            oExmeIn = aoFlows(iFlow).oIn;
            oExmeOut = aoFlows(iFlow).oOut;
        else
            oExmeIn = aoFlows(iFlow).oBranch.coExmes{1};
            oExmeOut = aoFlows(iFlow).oBranch.coExmes{2};
        end
        
        for iExme = 1:oExmeIn.oPhase.iProcsEXME
            if oExmeIn == oExmeIn.oPhase.coProcsEXME{iExme}
                iCurrentExme_In = iExme;
            end
        end
        
        for iExme = 1:oExmeOut.oPhase.iProcsEXME
            if oExmeOut == oExmeOut.oPhase.coProcsEXME{iExme}
                iCurrentExme_Out = iExme;
            end
        end
        % branches and p2ps are NOT allowed to change mass into a different
        % substance! Therefore the check is done for each substance
        % individually. There will be a different check for the manips in
        % the system
        mfMassBalanceErrors = oExmeIn.oPhase.mfTotalFlowsByExme(iCurrentExme_In,:) + oExmeOut.oPhase.mfTotalFlowsByExme(iCurrentExme_Out,:);
        if any(abs(mfMassBalanceErrors) > fAccuracy)
            
            if isempty(aoFlows(iFlow).oBranch)
                disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the P2P ', aoFlows(iFlow).sName]);
                
                if bSetBreakPoints
                    oMT.setMassErrorNames(aoFlows(iFlow).sName)
                end
            else
                disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the branch ', aoFlows(iFlow).oBranch.sCustomName]);
                if bSetBreakPoints
                    oMT.setMassErrorNames(aoFlows(iFlow).oBranch.sCustomName)
                end
            end
            
            csSubstances = oMT.csSubstances(abs(mfMassBalanceErrors) > fAccuracy);
            for iSubstance = 1:length(csSubstances)
                disp(['a mass balance error of ', num2str(mfMassBalanceErrors(oMT.tiN2I.(csSubstances{iSubstance}))),' kg/s occured for the substance ', csSubstances{iSubstance}]);
            end
            
            % Note in case changes were made to the phase file, search for the
            % expression "this.mfTotalFlowsByExme" and set the integer below to
            % the line number!
            % For the branch look for the expression:
            % "this.hSetFlowData"
            if bSetBreakPoints
                oMT.setMassErrorNames(oExmeIn.oPhase.sName);
                oMT.setMassErrorNames(oExmeOut.oPhase.sName);
                dbstop in matter.phase at 1278 if ~isempty(strmatch(this.sName, this.oMT.tMassErrorHelper.csMassErrorNames));
                dbstop in matter.branch at 661 if ~isempty(strmatch(this.sCustomName, this.oMT.tMassErrorHelper.csMassErrorNames));
            end
        end
    end
    
    %% Check manipulators (only checked for total mass change since manips are allowed to transform substances)
    for iPhase = 1:length(aoPhases)
        if ~isempty(aoPhases(iPhase).toManips.substance)
            oManip = aoPhases(iPhase).toManips.substance;
            if ~isempty(oManip.afPartialFlows)
                fMassBalanceError = sum(oManip.afPartialFlows);
                if abs(fMassBalanceError) > fAccuracy
                    disp(['In the phases ', aoPhases(iPhase).sName, ' the manipulator ', oManip.sName, ' generated a mass error of ', num2str(fMassBalanceError) ,' kg/s']);
                end
            end
        end
    end
    
    %% checks the mass balance in V-HAB and stops the simulation if it exceeds a value defined by the user
    if fMaxMassBalanceDifference ~= inf
        oInfrastructure = oMT.aoPhases(1).oStore.oContainer.oRoot.oInfrastructure;
        
        iLength = size(oInfrastructure.toMonitors.oMatterObserver.mfTotalMass);
        iLength = iLength(1);
        if iLength > 1
            afInitialTotalMass = oInfrastructure.toMonitors.oMatterObserver.mfTotalMass(1,:);
            afCurrentTotalMass = oInfrastructure.toMonitors.oMatterObserver.mfTotalMass(end,:);
            % afCurrentTotalMass = sum(reshape([ oMT.aoPhases.afMass ], oMT.iSubstances, []), 2)';
            
            fError = abs(sum(afInitialTotalMass) - sum(afCurrentTotalMass));
            if fError > fMaxMassBalanceDifference
                keyboard()
            end
        end
    end
end

