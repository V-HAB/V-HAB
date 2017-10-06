function [ ] = findMassBalanceErrors( oInput, fAccuracy, fMaxMassBalanceDifference, bSetBreakPoints )
% a helper function that can be used within any part of the V-HAB code, it
% just has to be supplied the matter table object. It will display the
% location of mass balance errors (in case any occur for the ticks where the
% function is executed) or at least it tries to find them. There is no
% guarantee that it will always find these errors!
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
        
        % branches and p2ps are NOT allowed to change mass into a different
        % substance! Therefore the check is done for each substance
        % individually. There will be a different check for the manips in
        % the system
        mfMassBalanceErrorsFlows =   ( oExmeIn.iSign  .* oExmeIn.oFlow.fFlowRate  .* oExmeIn.oFlow.arPartialMass) +...
                                ( oExmeOut.iSign .* oExmeOut.oFlow.fFlowRate .* oExmeOut.oFlow.arPartialMass);
        
        if any(abs(mfMassBalanceErrorsFlows) > fAccuracy)
            
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
            
            csSubstances = oMT.csSubstances(abs(mfMassBalanceErrorsFlows) > fAccuracy);
            for iSubstance = 1:length(csSubstances)
                disp(['a mass balance error of ', num2str(mfMassBalanceErrorsFlows(oMT.tiN2I.(csSubstances{iSubstance}))),' kg/s occured for the substance ', csSubstances{iSubstance}]);
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
    
    %% Check the current  partial mass changes in the phases:
    afCurrentMassBalance = zeros(1, oMT.iSubstances);
    if length(aoPhases) > 1
        for iPhase = 1:length(aoPhases)
            if ~isempty(aoPhases(iPhase).toManips.substance)
                oManip = aoPhases(iPhase).toManips.substance;
                if ~isempty(oManip.afPartialFlows)
                    % a positive Manipulator flowrate is a generation of
                    % that substance in the phase. To correctly represent
                    % that in the mass balance of the substances the
                    % manipulator flowrates have to subtracted (they will
                    % be added by the afCurrentTotalInOuts again)
                    afCurrentMassBalance = afCurrentMassBalance - oManip.afPartialFlows;
                end
            end
            afCurrentMassBalance = afCurrentMassBalance + aoPhases(iPhase).afCurrentTotalInOuts;
        end
    end
    
    if any(abs(afCurrentMassBalance)) > fAccuracy
        iSubstances = afCurrentMassBalance ~= 0;
        sSubstancesStringWithSpaces = strjoin({oMT.csI2N{iSubstances}}, ', ');
        disp(['An overall mass balance issue was detected in tick ', num2str(aoPhases(1).oTimer.iTick), ' for the substances: ', sSubstancesStringWithSpaces]);
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

