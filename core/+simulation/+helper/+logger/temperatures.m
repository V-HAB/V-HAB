function tLogProps = temperatures(tLogProps, oVsys, csStores)
%TEMPERATURES Logs temperature of all phases in a system
%   If csStores given, only the phases in these stores are logged!

% Checking for the csStores input argument
if nargin < 3 || isempty(csStores)
    csStores = fieldnames(oVsys.toStores);
end

% Getting the path to the vsys object
sPath = simulation.helper.paths.getSystemPath(oVsys);

% Initializing a counter for all the values we want to log.
iNumberOfValues = 1;

% Going through the csStores cell
for iStore = 1:length(csStores)
    % Setting some local variables to make the code more legigible
    oStore     = oVsys.toStores.(csStores{iStore});
    sStorePath = [ sPath '.toStores.' oStore.sName ];
    
    % Going through all the phases of the store and getting the temperature
    for iPhase = 1:length(oStore.aoPhases)
        % Setting some local variables to make the code more legigible
        oPhase     = oStore.aoPhases(iPhase);
        sPhasePath = [ sStorePath '.toPhases.' oPhase.sName ];
        
        % Adding the phase path
        tLogProps(iNumberOfValues).sObjectPath = sPhasePath;
        
        % Adding the expression that will be eval'd to extract the actual
        % log value from the object
        tLogProps(iNumberOfValues).sExpression = 'fTemperature';
        
        % Adding a label that will be used during plotting in the legend
        tLogProps(iNumberOfValues).sLabel = [ 'Phase Temperature (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
    
        % Incrementing the value counter
        iNumberOfValues = iNumberOfValues + 1;
    end
end

end

