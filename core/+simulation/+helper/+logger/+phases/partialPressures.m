function tLogProps = partialPressures(tLogProps, oPhase, csSubstances)
%PARTIALPRESSURES A helper to log the partial pressures of a gas phase
% The substances to be logged are defined by the csSubstances input
% argument. If this argument is empty, the four major constituents of
% sea-level air will be used. 

% First we need to check if the provided object is a gas phase, because the
% generic logger-helper-interface also accepts other types.
if ~isa(oPhase, 'matter.phases.gas')
    error('The provided phase (%s %s) is not a gas phase. Partial pressures can only be logged in gas phases.', oPhase.oStore.sName, oPhase.sName);
end

% Getting a reference to the phase's store
oStore = oPhase.oStore;

% Getting a reference to the phase's system
oVsys  = oStore.oContainer;

% Getting the system's path
sPath  = simulation.helper.paths.getSystemPath(oVsys);

% Checking to see if the user provided specific substances to be logged. If
% not we use the major constituents of sea-level air.
if nargin < 3 || isempty(csSubstances)
    csSubstances = { 'N2', 'O2', 'CO2', 'Ar' };
end

% Initializing a counter
iNumberOfSubstances = 1;

% Getting the paths for the store and the phase within the store
sStorePath = [ sPath '.toStores.' oPhase.oStore.sName ];
sPhasePath = [ sStorePath '.toPhases.' oPhase.sName ];

% Looping through all given substances and adding them to the logging
% properties struct
for iC = 1:length(csSubstances)
    % Adding the phase path
    tLogProps(iNumberOfSubstances).sObjectPath = sPhasePath;
    
    % Adding an expression that will be eval'd to extract the actual log
    % value from the object
    tLogProps(iNumberOfSubstances).sExpression = [ 'afPP(' num2str(oVsys.oMT.tiN2I.(csSubstances{iC})) ')' ];
    
    % Adding a label that will be used during plotting in the legend
    tLogProps(iNumberOfSubstances).sLabel = [ csSubstances{iC} ' Partial Pressure (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
    
    % Incrementing the substance counter.
    iNumberOfSubstances = iNumberOfSubstances + 1;
end

end

