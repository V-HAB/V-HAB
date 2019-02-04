function tLogProps = flowProperties(tLogProps, oVsys, csStores)
%FLOW_PROPS Logs typical relevant flow props for all or selected phases and
%branches
%   If csStores is not given, this function will return logging properties
%   for the masses, temperatures and, if applicable, pressures, of all
%   phases in the system defined by oVsys. It will also return the logging
%   properties for the flow rates of all branches in the system.
%   If csStores given, only those stores and branches connected to any of
%   their phases are logged!

% Checking for the csStores input argument
if nargin < 3 || isempty(csStores)
    csStores = fieldnames(oVsys.toStores);
    bStoresGiven = false;
else
    bStoresGiven = true;
end

% Getting the path to the vsys object
sPath = simulation.helper.paths.getSysPath(oVsys);

% Initializing a counter for all the values we want to log.
iValue = 1;

%% Phase Properties

% Going through the csStores cell
for iS = 1:length(csStores)
    % Setting some local variables to make the code more legigible
    oStore     = oVsys.toStores.(csStores{iS});
    sStorePath = [ sPath '.toStores.' oStore.sName ];
    
    % Going throuhg all the phases of the store and getting the logging
    % properties
    for iP = 1:length(oStore.aoPhases)
        % Setting some local variables to make the code more legigible
        oPhase     = oStore.aoPhases(iP);
        sPhasePath = [ sStorePath '.toPhases.' oPhase.sName ];
        
        % Mass
        tLogProps(iValue).sObjectPath = sPhasePath;
        tLogProps(iValue).sExpression = 'this.fMass + this.fCurrentTotalMassInOut * (this.oTimer.fTime - this.fLastMassUpdate)';
        tLogProps(iValue).sLabel = [ 'Phase Mass (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
        tLogProps(iValue).sUnit = 'kg'; % the auto-convert is only for fMass directly, not for the calculation above
        
        % Incrementing the value counter
        iValue = iValue + 1;
        
        % Temperature
        tLogProps(iValue).sObjectPath = sPhasePath;
        tLogProps(iValue).sExpression = 'fTemperature';
        tLogProps(iValue).sLabel = [ 'Phase Temp (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
    
        % Incrementing the value counter
        iValue = iValue + 1;
        
        % We only need to get the pressure if the phase is gas or liquid
        switch oPhase.sType
            case 'liquid'
                sExpression = 'fPressure';
                bLog = true;
            case 'gas'
                sExpression = 'this.fMassToPressure * (this.fMass + this.fCurrentTotalMassInOut * (this.oTimer.fTime - this.fLastMassUpdate))';
                bLog = true;
            otherwise
                bLog = false;
        end
        
        % Depending on the value of bLog we add the pressure as a log value
        if bLog == true
            tLogProps(iValue).sExpression = sExpression;
            tLogProps(iValue).sObjectPath = sPhasePath;
            tLogProps(iValue).sLabel = [ 'Phase Pressure (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
            tLogProps(iValue).sUnit = 'Pa'; % the auto-convert is only for fMass directly, not for the calculation above
            
            % Incrementing the value counter
            iValue = iValue + 1;
        end
    end
end

%% Branch Properties

% If the csStores input argument is given, we need to get all branches that
% are connected to the phases of the stores in that cell.
if bStoresGiven
    % Initializing some variables
    aoBranches = matter.branch.empty(0,oVsys.iBranches);
    iBranch = 1;
    
    % Going throuhg all stores
    for iStore = 1:length(csStores)
        % Setting a local variable for the store to make the code more
        % legigible
        oStore = oVsys.toStores.(csStores{iStore});
        
        % Going throuhg all the phases of the current store
        for iPhase = 1:oStore.iPhases
            % Going through all the exmes of the current phase
            for iEXME = 1:oStore.aoPhases(iPhase).iProcsEXME
                % We need to check if the current exme has a branch or if
                % it is a p2p or other processor
                if ~isempty(oStore.aoPhases(iPhase).coProcsEXME{iEXME}.oFlow.oBranch)
                    % Now we need to check if the branch object has already
                    % been added to the aoBranches array. On the first
                    % iteration, that is not needed.
                    if iBranch == 1 || ~any(arrayfun(@(oArray) isequal(oArray, oStore.aoPhases(iPhase).coProcsEXME{iEXME}.oFlow.oBranch), aoBranches))
                        % All conditions have been met and we can add the
                        % current branch to the aoBranches array.
                        aoBranches(iBranch) = oStore.aoPhases(iPhase).coProcsEXME{iEXME}.oFlow.oBranch;
                        % Incrementing the branch counter
                        iBranch = iBranch + 1;
                    end
                end
            end
        end
    end
    
else
    % In this case the csStores input argument is NOT set, so we can just
    % use all branches in the vsys object.
    aoBranches = oVsys.aoBranches;
end

% Going through all branches
for iBranch = 1:length(aoBranches)
    % Getting the current branch object
    oBranch = aoBranches(iBranch);
    
    % Checking if the branch has a custom name or not and adding it
    % accordingly.
    if ~isempty(oBranch.sCustomName)
        tLogProps(iValue).sObjectPath = [ sPath ':b:' oBranch.sCustomName ];
    else
        tLogProps(iValue).sObjectPath = [ sPath ':b:' oBranch.sName ];
    end
    
    % Adding the expressionand lable
    tLogProps(iValue).sExpression = 'fFlowRate';
    tLogProps(iValue).sLabel = [ 'Flow Rate (' oVsys.sName ' - ' oBranch.sName ')' ];
    
    % Incrementing the value counter
    iValue = iValue + 1;
end

end

