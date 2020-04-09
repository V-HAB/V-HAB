function tLogProps = allDensities(tLogProps, oVsys)
%ALLPARTIALMASSES A helper function to log all partial masses in a system
% The substances to be logged are defined by the csSubstances input
% argument. If this argument is empty, the four major constituents of
% sea-level air will be used.
% The function will add the partial masses for the specified substances
% from all phases contained in the system provided via the oVsys input
% argument.

% First we need to check if the provided object is a vsys, because the
% generic logger-helper-interface also accepts other types.
if ~isa(oVsys, 'vsys')
    error('The provided object (%s) is not a vsys. Partial masses can only be logged in vsys objects, specifically matter.containers.', oVsys.sName);
end

% Getting the names of all the stores in the provided system
csStores = fieldnames(oVsys.toStores);

% Getting the system path of the system
sPath = simulation.helper.paths.getSystemPath(oVsys);

% Initializing a counter
iLogItems = 1;

% Now we loop through all stores on the system
for iStore = 1:length(csStores)
    % Getting an object reference and the path to the current store
    oStore     = oVsys.toStores.(csStores{iStore});
    sStorePath = [ sPath '.toStores.' oStore.sName ];
    
    % Now we loop through all phases on the current store
    for iPhase = 1:length(oStore.aoPhases)
        % Getting an object reference and the path to the current phase
        oPhase     = oStore.aoPhases(iPhase);
        sPhasePath = [ sStorePath '.toPhases.' oPhase.sName ];
        
        % Adding the phase path
        tLogProps(iLogItems).sObjectPath = sPhasePath;
        
        % Adding an expression that will be eval'd to extract the
        % actual log value from the object
        tLogProps(iLogItems).sExpression = 'fDensity';
        
%         % Adding the unit
%         tLogProps(iPhase).sObjectPath = sPhasePath;
        
        % Adding a label that will be used during plotting in the
        % legend
        tLogProps(iLogItems).sLabel = [ 'Density (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
        
        % Incrementing the counter
        iLogItems = iLogItems + 1;
    end
end

end

