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



for iS = 1:length(csStores)
    oStore     = oVsys.toStores.(csStores{iS});
    sStorePath = [ sPath '.toStores.' oStore.sName ];
    
    for iP = 1:length(oStore.aoPhases)
        oPhase     = oStore.aoPhases(iP);
        sPhasePath = [ sStorePath '.toPhases.' oPhase.sName ];
        
        
        % Mass, Pressure, Temperature
        tLogProps(end + 1) = struct(...
            'sPath', [ sPhasePath '.fMass' ], ...
            'sName', [ 'Phase Mass (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ], ...
            'sUnit', 'kg' ...
        );
    
        tLogProps(end + 1) = struct(...
            'sPath', [ sPhasePath '.fTemperature' ], ...
            'sName', [ 'Phase Temp (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ], ...
            'sUnit', 'K' ...
        );
    
        tLogProps(end + 1) = struct(...
            'sPath', [ sPhasePath '.fMass * ' sPhasePath '.fMassToPressure' ], ...
            'sName', [ 'Phase Pressure (' oVsys.sName ' - ' oStore.sName ' - ' oPhase.sName ')' ], ...
            'sUnit', 'Pa' ...
        );
    end
end



for iB = 1:length(oVsys.aoBranches)
    oBranch = oVsys.aoBranches(iB);
    
    tLogProps(end + 1) = struct(...
        'sPath', [ sPath '.aoBranches(' num2str(iB) ').fFlowRate' ], ...
        'sName', [ 'Flow Rate (' oVsys.sName ' - ' oBranch.sName ')' ], ...
        'sUnit', 'kg/s' ...
    );
end



end

