function tLogProps = flow_props(tLogProps, oVsys, csStores)
%FLOW_PROPS Logs typical relevant flow props, e.g. flow rates, ...
%   If csStores given, only those stores and branches connected to any of
%   their phases are logged!


%TODO only branches that are connected to phases of the selected stores
%       just collect exmes and compare coExmes{1/2}

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
        
        
        % Mass, Pressure, Temperature
        tLogProps(iV).sObjectPath = sPhasePath;
        %tLogProps(iV).sExpression = 'fMass';
        tLogProps(iV).sExpression = 'this.fMass + this.fCurrentTotalMassInOut * (this.oTimer.fTime - this.fLastMassUpdate)';
        tLogProps(iV).sLabel = [ 'Phase Mass (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
        tLogProps(end).sUnit = 'kg'; % the auto-convert is only for fMass directly, not for the calculation above
        
        
        iV = iV + 1;
        
        tLogProps(iV).sObjectPath = sPhasePath;
        tLogProps(iV).sExpression = 'fTemperature';
        tLogProps(iV).sLabel = [ 'Phase Temp (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
    
        
        iV = iV + 1;
        switch oPhase.sType
            case 'solid'
                continue;
            case 'liquid'
                tLogProps(iV).sExpression = 'fPressure';
            case 'gas'
                %tLogProps(iV).sExpression = 'this.fMass * this.fMassToPressure';
                tLogProps(iV).sExpression = 'this.fMassToPressure * (this.fMass + this.fCurrentTotalMassInOut * (this.oTimer.fTime - this.fLastMassUpdate))';
            case 'absorber'
                continue;
            case 'mixture'
                tLogProps(iV).sExpression = 'fPressure';
        end
        tLogProps(iV).sObjectPath = sPhasePath;
        tLogProps(iV).sLabel = [ 'Phase Pressure (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ];
        tLogProps(end).sUnit = 'Pa'; % the auto-convert is only for fMass directly, not for the calculation above
        
        iV = iV + 1;
    end
end



for iB = 1:length(oVsys.aoBranches)
    oBranch = oVsys.aoBranches(iB);
    if ~isempty(oBranch.sCustomName)
        tLogProps(iV).sObjectPath = [ sPath ':b:' oBranch.sCustomName ];
    else
        tLogProps(iV).sObjectPath = [ sPath ':b:' oBranch.sName ];
    end
    tLogProps(iV).sExpression = 'fFlowRate';
    tLogProps(iV).sLabel = [ 'Flow Rate (' oVsys.sName ' - ' oBranch.sName ')' ];
    %tLogProps(end).sUnit = 'kg/s';
    
    iV = iV + 1;
end



end

