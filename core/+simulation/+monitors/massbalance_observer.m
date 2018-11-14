classdef massbalance_observer < simulation.monitor
    % massbalance_observer is a monitor to track the mass transfers in your
    % system and identify the locations where mass balance errors (which
    % are not a result of mass lost errors) occur. If your system has a
    % high mass lost value, first fix that and if after that a high mass
    % balance error remains, use this monitor to identify the locations for
    % these mass balance errors. Mass balance differs from the mass lost
    % value as mass lost occurs whenever a substance within a phase reaches
    % a value of less than 0. Mass balance on the other hand occurs if the
    % flowrates do not sum up to zero over the whole vsys.
    %
    % Please note that this monitor is not complete and cannot find all
    % possible mass balance errors, but quite a lot of the common errors
    % are identified by it. If the monitor identifies a mass balance error
    % it provides the tick and the substance for which a mass balance Issue
    % was identified. Mass balance issues arise if the positive and
    % negative flowrates for a substance do not sum up to zero over the
    % complete simulation. Matter changes from manipulators are respected
    % in this check as the only location where one substance can change
    % into another substance. If the manipulator is programmed wrong, it
    % can actually generate mass (subtracted flows are not equal to
    % generated flows)
    %
    % Optional inputs:
    % this.fAccuracy:    This values defines the size of the mass balance error
    %               befor information about it is provided by this tool. For
    %               Example if the value is 1e-6 the mass balance error has to
    %               be larger than 1e-6 kg/s for information about it to be
    %               displayed.
    %
    % fMaxMassBalanceDifference:    can be set if you want your simulation to
    %                               stop in case you exceed a certain total
    %                               error in the mass balance. E.g. if the
    %                               value is 1 [kg] then the simulation will
    %                               pause once the total mass balance error is
    %                               larger than 1 kg
    %
    % bSetBreakPoints:  This function is a bit experimental, but if you set the
    %                   value to true the function will try to automaticall set
    %                   breakpoints at the locations within V-HAB where the
    %                   mass balance error orginiates.

    
    properties (SetAccess = protected, GetAccess = public)
        fAccuracy = 0;
        fMaxMassBalanceDifference = inf;
        bSetBreakPoints = false;
        
        tMassErrorHelper;
    end
    
    methods
        function this = massbalance_observer(oSimulationInfrastructure, fAccuracy, fMaxMassBalanceDifference, bSetBreakPoints)
            this@simulation.monitor(oSimulationInfrastructure, { 'tick_post' });
            
            if nargin > 1
                this.fAccuracy = fAccuracy;
            end
            if nargin > 2
                this.fMaxMassBalanceDifference = fMaxMassBalanceDifference;
            end
            if nargin > 3
                this.bSetBreakPoints = bSetBreakPoints;
            end
            
            this.tMassErrorHelper.csMassErrorNames = cell(0,0);
        end
    end
    
    
    methods (Access = protected)
        
        function onTickPost(this, ~)
            
            oInfra = this.oSimulationInfrastructure;
            oSim   = oInfra.oSimulationContainer;
            
            oMT = oSim.oMT;

            aoPhases = oInfra.toMonitors.oMatterObserver.aoPhases;
            aoFlows  = oInfra.toMonitors.oMatterObserver.aoFlows;

            % Include a calculation if the afCurrentTotalInOuts of each
            % phase corresponds to the total flowrate of all attached
            % branches! Covers the case where the calculateTimeStep
            % function was not correctly called!
            
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

                if oExmeIn.oFlow.fFlowRate ~= 0 && abs(sum(oExmeIn.oFlow.arPartialMass) - 1) > this.fAccuracy
                    if oExmeOut.bFlowIsAProcP2P
                        disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the P2P ', oExmeIn.oFlow.sName, ' the partial mass vector is unequal to 1']);
                    else
                        disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the branch ', oExmeIn.oFlow.oBranch.sCustomName, ' the partial mass vector is unequal to 1']);
                    end
                end
                
                if oExmeOut.oFlow.fFlowRate ~= 0 && abs(sum(oExmeOut.oFlow.arPartialMass) - 1) > this.fAccuracy
                    if oExmeOut.bFlowIsAProcP2P
                        disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the P2P ', oExmeOut.oFlow.sName, ' the partial mass vector is unequal to 1']);
                    else
                        disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the branch ', oExmeOut.oFlow.oBranch.sCustomName, ' the partial mass vector is unequal to 1']);
                    end
                end
                
                if any(abs(mfMassBalanceErrorsFlows) > this.fAccuracy)

                    if isempty(aoFlows(iFlow).oBranch)
                        disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the P2P ', aoFlows(iFlow).sName]);

                        if this.bSetBreakPoints
                            this.tMassErrorHelper.csMassErrorNames{end+1} = aoFlows(iFlow).sName;
                        end
                    else
                        disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the branch ', aoFlows(iFlow).oBranch.sCustomName]);
                        if this.bSetBreakPoints
                            this.tMassErrorHelper.csMassErrorNames{end+1} = aoFlows(iFlow).oBranch.sCustomName;
                        end
                    end

                    csSubstances = oMT.csSubstances(abs(mfMassBalanceErrorsFlows) > this.fAccuracy);
                    for iSubstance = 1:length(csSubstances)
                        disp(['a mass balance error of ', num2str(mfMassBalanceErrorsFlows(oMT.tiN2I.(csSubstances{iSubstance}))),' kg/s occured for the substance ', csSubstances{iSubstance}]);
                    end

                    % Note in case changes were made to the phase file, search for the
                    % end of the getTotalMassChange and set the integer to
                    % that line number
                    % For the branch look for the expression:
                    % "this.hSetFlowData"
                    if this.bSetBreakPoints
                        this.tMassErrorHelper.csMassErrorNames{end+1} = oExmeIn.oPhase.sName;
                        this.tMassErrorHelper.csMassErrorNames{end+1} = oExmeOut.oPhase.sName;
                        dbstop in matter.phase at 954 if ~isempty(strmatch(this.sName, this.tMassErrorHelper.csMassErrorNames));
                        dbstop in matter.branch at 763 if ~isempty(strmatch(this.sCustomName, this.tMassErrorHelper.csMassErrorNames));
                    end
                end
            end

            %% Check manipulators (only checked for total mass change since manips are allowed to transform substances)
            for iPhase = 1:length(aoPhases)
                if ~isempty(aoPhases(iPhase).toManips.substance)
                    oManip = aoPhases(iPhase).toManips.substance;
                    if ~isempty(oManip.afPartialFlows)
                        fMassBalanceError = sum(oManip.afPartialFlows);
                        if abs(fMassBalanceError) > this.fAccuracy
                            disp(['In the phases ', aoPhases(iPhase).sName, ' the manipulator ', oManip.sName, ' generated a mass error of ', num2str(fMassBalanceError) ,' kg/s']);
                        end
                    end
                end
            end

            %% Check the current  partial mass changes in the phases:
            afCurrentMassBalance = zeros(1, oMT.iSubstances);
            if length(aoPhases) > 1
                for iPhase = 1:length(aoPhases)
                    % Manips are not included in the afCurrentTotalInOuts value,
                    % the mass balance for those is calculated individually
                    afCurrentMassBalance = afCurrentMassBalance + aoPhases(iPhase).afCurrentTotalInOuts;
                    
                    if aoPhases(iPhase).bFlow
                        if aoPhases(iPhase).fCurrentTotalMassInOut ~= 0 && abs(sum(aoPhases(iPhase).arPartialMass) - 1) > this.fAccuracy
                            disp(['In the Store ', aoPhases(iPhase).oStore.sName, ' in Phase ', aoPhases(iPhase).sName, ' the partial mass vector is unequal to 1']);
                        end
                    else
                        if aoPhases(iPhase).fMass ~= 0 && abs(sum(aoPhases(iPhase).arPartialMass) - 1) > this.fAccuracy
                            disp(['In the Store ', aoPhases(iPhase).oStore.sName, ' in Phase ', aoPhases(iPhase).sName, ' the partial mass vector is unequal to 1']);
                        end
                    end
                end
            end

            if any(abs(afCurrentMassBalance) > this.fAccuracy)
                miSubstances = abs(afCurrentMassBalance) > this.fAccuracy;
                sSubstancesStringWithSpaces = strjoin(oMT.csI2N(miSubstances), ', ');
                disp(['An overall mass balance issue was detected in tick ', num2str(aoPhases(1).oTimer.iTick), ' for the substances: ', sSubstancesStringWithSpaces]);
            end

            %% checks the mass balance in V-HAB and stops the simulation if it exceeds a value defined by the user
            if this.fMaxMassBalanceDifference ~= inf
                oInfrastructure = oMT.aoPhases(1).oStore.oContainer.oRoot.oInfrastructure;

                iLength = size(oInfrastructure.toMonitors.oMatterObserver.mfTotalMass);
                iLength = iLength(1);
                if iLength > 1
                    afInitialTotalMass = oInfrastructure.toMonitors.oMatterObserver.mfTotalMass(1,:);
                    afCurrentTotalMass = oInfrastructure.toMonitors.oMatterObserver.mfTotalMass(end,:);

                    fError = abs(sum(afInitialTotalMass) - sum(afCurrentTotalMass));
                    if fError > this.fMaxMassBalanceDifference
                        keyboard()
                    end
                end
            end
        end
    end
end