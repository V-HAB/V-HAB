function tLogProps = thermal_properties(tLogProps, oVsys, tConfigStruct)
%THERMAL_PROPERTIES Logs typical relevant thermal properties, e.g. capacities, ...
%   If the tConfigStruct is given it will configure which capacities and
%   conductors will be logged.

csConfigCells = {'csCapacities', 'csLinearConductors', 'csFluidicConductors', 'csRadiativeConductors'};

%TODO only branches that are connected to phases of the selected stores
%       just collect exmes and compare coExmes{1/2}

if nargin < 3
    csCapacities          = oVsys.poCapacities.keys;
    csLinearConductors    = oVsys.poLinearConductors.keys;
    csFluidicConductors   = oVsys.poFluidicConductors.keys;
    csRadiativeConductors = oVsys.poRadiativeConductors.keys;
    
%TODO Make this actually work with the config struct in an intelligent way
% else 
%     csFieldNames = fieldnames(tConfigStruct);
%     for iI = 1:length(tConfigStruct)
%         if any(strcmp(csConfigCells, csFieldNames{iI}))
%             
%             %if isempty(tConfigStruct.
%             csResult = eval([csFieldNames{iI}, '= tConfigStruct.(csFieldNames{iI})']);
%             
%         end
%     end
end

sPath = simulation.helper.paths.getSysPath(oVsys);


iV = 1;


for iI = 1:length(csCapacities)
    oCapacity     = oVsys.poCapacities(csCapacities{iI});
    if isa(oCapacity.oMatterObject, 'thermal.dummymatter')
        sStorePath    = [ sPath, '.toStores.', oCapacity.oMatterObject.sName ];
        sCapacityPath = [ sStorePath, '.toPhases.', oCapacity.oMatterObject.aoPhases(1).sName ];
    else
        sStorePath    = [ sPath, '.toStores.', oCapacity.oMatterObject.oStore.sName ];
        sCapacityPath = [ sStorePath, '.toPhases.', oCapacity.oMatterObject.sName ];
    end
    
    
    % Total Heat Capacity
    tLogProps(iV).sObjectPath = sCapacityPath;
    tLogProps(iV).sExpression = 'fTotalHeatCapacity';
    tLogProps(iV).sLabel      = [ 'Total Heat Capacity (' oVsys.sName ' - ' oCapacity.sName ')' ];
    
    iV = iV + 1;
    
    tLogProps(iV).sObjectPath = sCapacityPath;
    tLogProps(iV).sExpression = 'fSpecificHeatCapacity';
    tLogProps(iV).sLabel = [ 'Specific Heat Capacity (' oVsys.sName ' - ' oCapacity.sName ')' ];
    
    iV = iV + 1;
end

for iI = 1:length(csLinearConductors)
    oConductor = oVsys.poLinearConductors(csLinearConductors{iI});
    
    tLogProps(iV).sObjectPath = [ sPath '.poLinearConductors(''' oConductor.sName ''')'];
    tLogProps(iV).sExpression = 'fConductivity';
    tLogProps(iV).sLabel = [ 'Conductivity (' oVsys.sName ' - ' oConductor.sName ')' ];
    
    iV = iV + 1;
end

for iI = 1:length(csFluidicConductors)
    oConductor = oVsys.poFluidicConductors(csFluidicConductors{iI});
    
    tLogProps(iV).sObjectPath = [ sPath '.poFluidicConductors(''' oConductor.sName ''')'];
    tLogProps(iV).sExpression = 'fConductivity';
    tLogProps(iV).sLabel = [ 'Conductivity (' oVsys.sName ' - ' oConductor.sName ')' ];
    
    iV = iV + 1;
end

for iI = 1:length(csRadiativeConductors)
    oConductor = oVsys.poRadiativeConductors(csRadiativeConductors{iI});
    
    tLogProps(iV).sObjectPath = [ sPath '.poRadiativeConductors(''' oConductor.sName ''')'];
    tLogProps(iV).sExpression = 'fConductivity';
    tLogProps(iV).sLabel = [ 'Conductivity (' oVsys.sName ' - ' oConductor.sName ')' ];
    
    iV = iV + 1;
end


end

