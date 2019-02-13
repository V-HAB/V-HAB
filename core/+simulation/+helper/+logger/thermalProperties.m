function tLogProps = thermalProperties(tLogProps, oVsys, csStores)
%THERMALPROPERTIES Logs typical relevant thermal props in a system
%   If csStores is not given, this function will return logging properties
%   for the temperatures, heat capacities and heat source flows of all
%   capacities in the system defined by oVsys. It will also return the
%   logging properties for the heat flows of all branches in the system. If
%   csStores given, only those stores and branches connected to any of
%   their phases are logged!

% Checking for the csStores input argument
if nargin < 3 || isempty(csStores)
    csStores = fieldnames(oVsys.toStores);
    bStoresGiven = false;
else
    bStoresGiven = true;
end

% Getting the path to the vsys object
sPath = simulation.helper.paths.getSystemPath(oVsys);

% Initializing a counter for all the values we want to log.
iNumberOfValues = 1;

%% Capacity Properties

% Going through the csStores cell
for iStore = 1:length(csStores)
    % Setting some local variables to make the code more legigible
    oStore     = oVsys.toStores.(csStores{iStore});
    sStorePath = [ sPath '.toStores.' oStore.sName ];
    
    % Going through all the phases of the store and getting the logging
    % properties of their associated capacity objects
    for iPhase = 1:length(oStore.aoPhases)
        % Getting the path to the current capacity
        sCapacityPath = [ sStorePath '.toPhases.' oStore.aoPhases(iPhase).sName '.oCapacity'];
        
        %% Temperature
        
        % Adding the phase path
        tLogProps(iNumberOfValues).sObjectPath = sCapacityPath;
        
        % Adding an expression that will be eval'd to extract the actual
        % log value from the object
        tLogProps(iNumberOfValues).sExpression = 'fTemperature';
        
        % Adding a label that will be used during plotting in the legend.
        % Phase name and capacity name are the same. 
        tLogProps(iNumberOfValues).sLabel = [ 'Capacity Temperature (' oVsys.sName ' - ' oStore.sName ' - ' oStore.aoPhases(iPhase).sName ')' ];
        
        % Incrementing the value counter
        iNumberOfValues = iNumberOfValues + 1;
        
        %% Total Heat Capacity
        
        % Adding the phase path
        tLogProps(iNumberOfValues).sObjectPath = sCapacityPath;
        
        % Adding an expression that will be eval'd to extract the actual
        % log value from the object
        tLogProps(iNumberOfValues).sExpression = 'fTotalHeatCapacity';
        
        % Adding a label that will be used during plotting in the legend.
        % Phase name and capacity name are the same. 
        tLogProps(iNumberOfValues).sLabel = [ 'Total Heat Capacity (' oVsys.sName ' - ' oStore.sName ' - ' oStore.aoPhases(iPhase).sName ')' ];
    
        % Incrementing the value counter
        iNumberOfValues = iNumberOfValues + 1;
        
        %% Specific Heat Capacity
        
        % Adding the phase path
        tLogProps(iNumberOfValues).sObjectPath = sCapacityPath;
        
        % Adding an expression that will be eval'd to extract the actual
        % log value from the object
        tLogProps(iNumberOfValues).sExpression = 'fSpecificHeatCapacity';
        
        % Adding a label that will be used during plotting in the legend.
        % Phase name and capacity name are the same. 
        tLogProps(iNumberOfValues).sLabel = [ 'Specific Heat Capacity (' oVsys.sName ' - ' oStore.sName ' - ' oStore.aoPhases(iPhase).sName ')' ];
    
        % Incrementing the value counter
        iNumberOfValues = iNumberOfValues + 1;
        
        %% Current Heat Flow
        
        % Adding the phase path
        tLogProps(iNumberOfValues).sObjectPath = sCapacityPath;
        
        % Adding an expression that will be eval'd to extract the actual
        % log value from the object
        tLogProps(iNumberOfValues).sExpression = 'fCurrentHeatFlow';
        
        % Adding a label that will be used during plotting in the legend.
        % Phase name and capacity name are the same. 
        tLogProps(iNumberOfValues).sLabel = [ 'Capacity Heat Flow (' oVsys.sName ' - ' oStore.sName ' - ' oStore.aoPhases(iPhase).sName ')' ];
        
        % Adding a unit explicitly because the auto-convert from expression
        % to unit doesn't work for 'fCurrentHeatFlow', only for
        % 'fHeatFlow'.
        tLogProps(iNumberOfValues).sUnit = 'W';
    
        % Incrementing the value counter
        iNumberOfValues = iNumberOfValues + 1;
        
        
    end
end

%% Branch Properties

% If the csStores input argument is given, we need to get all branches that
% are connected to the capacities of the stores in that cell.
if bStoresGiven
    % Initializing some variables
    aoThermalBranches = thermal.branch.empty(0,oVsys.iThermalBranches);
    iBranch = 1;
    
    % Going throuhg all stores
    for iStore = 1:length(csStores)
        % Setting a local variable for the store to make the code more
        % legigible
        oStore = oVsys.toStores.(csStores{iStore});
        
        % Going throuhg all the phases of the current store
        for iPhase = 1:oStore.iPhases
            % Going through all the exmes of the current phase's capacity
            for iEXME = 1:oStore.aoPhases(iPhase).oCapacity.iProcsEXME
                % We we need to check if the branch object has already been
                % added to the aoBranches array. On the first iteration,
                % that is not needed.
                if iBranch == 1 || ~any(arrayfun(@(oArray) isequal(oArray, oStore.aoPhases(iPhase).oCapacity.aoExmes(iEXME).oBranch), aoThermalBranches))
                    % All conditions have been met and we can add the
                    % current branch to the aoBranches array.
                    aoThermalBranches(iBranch) = oStore.aoPhases(iPhase).oCapacity.aoExmes(iEXME).oBranch;
                    % Incrementing the branch counter
                    iBranch = iBranch + 1;
                end
                
            end
        end
    end
    
else
    % In this case the csStores input argument is NOT set, so we can just
    % use all branches in the vsys object.
    aoThermalBranches = oVsys.aoThermalBranches;
end

% Going through all branches
for iBranch = 1:length(aoThermalBranches)
    % Getting the current branch object
    oBranch = aoThermalBranches(iBranch);
    
    % Checking if the branch has a custom name or not 
    if ~isempty(oBranch.sCustomName)
        sBranchName = oBranch.sCustomName;
    else
        sBranchName = oBranch.sName;
    end
    
    % Setting the log property accordingly
    tLogProps(iNumberOfValues).sObjectPath = [ sPath '.toThermalBranches.' sBranchName ];
    
    % Adding an expression that will be eval'd to extract the actual log
    % value from the object
    tLogProps(iNumberOfValues).sExpression = 'fHeatFlow';
    
    % Adding a label that will be used during plotting in the legend
    tLogProps(iNumberOfValues).sLabel = [ 'Heat Flow Rate (' oVsys.sName ' - ' sBranchName ')' ];
    
    % Incrementing the value counter
    iNumberOfValues = iNumberOfValues + 1;
end

end

