function tLogProps = partial_pressures(tLogProps, oPhase, csSubstances)
%PARTIAL_PRESSURES Summary of this function goes here
%   Detailed explanation goes here


if ~isa(oPhase, 'matter.phases.gas')
    error('The provided phase (%s %s) is not a gas phase. Partial pressures can only be logged in gas phases.', oPhase.oStore.sName, oPhase.sName);
end

oStore = oPhase.oStore;
oVsys  = oStore.oContainer;
sPath  = simulation.helper.paths.getSysPath(oVsys);


if nargin < 3 || isempty(csSubstances)
    csSubstances = { 'N2', 'O2', 'CO2', 'Ar' };
end



iV = 1;
sStorePath = [ sPath '.toStores.' oPhase.oStore.sName ];
sPhasePath = [ sStorePath '.toPhases.' oPhase.sName ];

for iC = 1:length(csSubstances);
    
    tLogProps(iV).sObjectPath = sPhasePath;
    tLogProps(iV).sExpression = [ 'afPP(' num2str(oVsys.oMT.tiN2I.(csSubstances{iC})) ')' ];
    tLogProps(iV).sLabel = [ csSubstances{iC} ' Partial Pressure (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
    
    
    iV = iV + 1;
    
    
end




end

