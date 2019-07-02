function tLogProps = allPartialMasses(tLogProps, oVsys, csSubstances)
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
sPath    = simulation.helper.paths.getSystemPath(oVsys);

% Checking to see if the user provided specific substances to be logged. If
% not we use the major constituents of sea-level air.
if nargin < 3 || isempty(csSubstances)
    csSubstances = { 'N2', 'O2', 'CO2', 'Ar' };
end

% Initializing a counter
iNumberOfSubstances = 1;

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
        
        % Now we loop through all substances and actually add them to the
        % logging properties struct.
        for iSubstance = 1:length(csSubstances)
            
            % Adding the phase path
            tLogProps(iNumberOfSubstances).sObjectPath = sPhasePath;
            
            % Adding an expression that will be eval'd to extract the
            % actual log value from the object
            tLogProps(iNumberOfSubstances).sExpression = [ 'afMass(' num2str(oVsys.oMT.tiN2I.(csSubstances{iSubstance})) ')' ];
            
            % Adding a label that will be used during plotting in the
            % legend
            tLogProps(iNumberOfSubstances).sLabel = [ 'Phase ' csSubstances{iSubstance} ' Mass (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
            
            % Incrementing the substance counter.
            iNumberOfSubstances = iNumberOfSubstances + 1;
        end
    end
end

end

