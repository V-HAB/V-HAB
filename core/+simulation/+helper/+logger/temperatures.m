function tLogProps = temperatures(tLogProps, oVsys, csStores)
%TEMPERATURES Logs temperature of all phases
%   If csStores given, only the phases in these stores are logged!

if nargin < 3 || isempty(csStores)
    csStores = fieldnames(oVsys.toStores);
end

sPath = simulation.helper.paths.getSysPath(oVsys);


iV = 1;


for iS = 1:length(csStores)
    oStore     = oVsys.toStores.(csStores{iS});
    sStorePath = [ sPath '.toStores.' oStore.sName ];
    
    for iP = 1:length(oStore.aoPhases)
        oPhase     = oStore.aoPhases(iP);
        sPhasePath = [ sStorePath '.toPhases.' oPhase.sName ];
        
        tLogProps(iV).sObjectPath = sPhasePath;
        tLogProps(iV).sExpression = 'fTemperature';
        tLogProps(iV).sLabel = [ 'Phase Temperature (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
    
        
        iV = iV + 1;
    end
end

end

