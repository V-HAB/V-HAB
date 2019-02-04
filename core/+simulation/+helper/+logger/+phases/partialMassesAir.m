function tLogProps = partialMassesAir(tLogProps, oVsys, csSubstances)
%AIR_PARTIALS is a helper function to log the partial masses of air (or if
% specified other partial masses) of all phases and stores inside of the
% provided Vsys

csStores = fieldnames(oVsys.toStores);
sPath    = simulation.helper.paths.getSysPath(oVsys);

if nargin < 3 || isempty(csSubstances)
    csSubstances = { 'N2', 'O2', 'CO2', 'Ar' };
end

iV = 1;


for iS = 1:length(csStores)
    oStore     = oVsys.toStores.(csStores{iS});
    sStorePath = [ sPath '.toStores.' oStore.sName ];
    
    for iP = 1:length(oStore.aoPhases)
        oPhase     = oStore.aoPhases(iP);
        sPhasePath = [ sStorePath '.toPhases.' oPhase.sName ];
        
        
        for iC = 1:length(csSubstances)
            
            tLogProps(iV).sObjectPath = sPhasePath;
            tLogProps(iV).sExpression = [ 'afMass(' num2str(oVsys.oMT.tiN2I.(csSubstances{iC})) ')' ];
            tLogProps(iV).sLabel = [ 'Phase ' csSubstances{iC} ' Mass (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
            

            iV = iV + 1;
            
            
        end
    end
end




end

