

tProps = struct('fStoreVols', {}, 'fPressureDifference', {});%, 'fVirtGasPhaseHelperVol', {});
tSrc   = struct(...
    'afStoreVols', [ 1 10 100 1000 ], ...
    'afPressureDifference', [ 0.01 0.05 0.1 0.25 0.5 1 ] ...
    ... 'afVirtGasPhaseHelperVol', [ 1e5 1e4 1e3 1e2 1e1 1e0 ] ...
);


for iV = 1:length(tSrc.afStoreVols)
    for iP = 1:length(tSrc.afPressureDifference)
        %for iH = 1:length(tSrc.afVirtGasPhaseHelperVol)
            
            tProps(end + 1) = struct(...
                'fStoreVols', tSrc.afStoreVols(iV), ...
                'fPressureDifference', tSrc.afPressureDifference(iP) ...
                ... 'fVirtGasPhaseHelperVol', tSrc.afVirtGasPhaseHelperVol(iH) ...
            );
            
        %end
    end
end



%%



iL1  = length(tProps);


coSims = cell(iL1, 1);


parfor iM = 1:iL1

    tSolverParams = struct();%'rUpdateFrequency', arUpdFreq(iU), 'rHighestMaxChangeDecrease', arMaxDecr(iM));


    disp('============================================================================');
    disp([ '                           ' num2str(iM) ' / ' num2str(iL1) ]);
    disp('============================================================================');
    disp(tProps(iM));
    disp('============================================================================');
    

    ptParams = containers.Map(...
        { 'tutorials.t_piece.systems.Example' }, ...
        { tProps(iM) } ...
    );

    coSims{iM} = vhab.sim('tutorials.t_piece.setup', ptParams, tSolverParams);
    oSim = coSims{iM};

    oSim.iSimTicks = 2500;
    oSim.bUseTime  = false;

    oSim.oSimulationContainer.oTimer.setMinStep(1e-12);
    oSim.toMonitors.oConsoleOutput.setReportingInterval(1000);

    %poSimObjs([ 'uf_' num2str(arUpdFreq(iU)) '__md_' num2str(arMaxDecr(iM)) ]) = oSim;



    %disp(oSim.oSimulationContainer.tSolverParams);
    disp(oLastSimObj.oSimulationContainer.oCfgParams.ptConfigParams('tutorials.t_piece.systems.Example'));
    disp('============================================================================');

    oSim.run();


end


%THEN: best solution above, then bSynced and gradually increase iDampFR!


%%


save('data/tpiece_test_run.mat', 'coSims');

%%

for iU = 1:iL1
    %for iM = 1:iL2
        %disp([ 'coSims{' num2str(iU) ',' num2str(iM) '} - ' 'rUF ' num2str(arUpdFreq(iU)) ' - rMD ' num2str(arMaxDecr(iM)) ]);
        %disp([ 'coSims{' num2str(iU) '} - ' 'rUF ' num2str(arUpdFreq(iU)) ' - rMD ' num2str(arMaxDecr(iM)) ]);

        %oTimer = poSimObjs(csKeys{iI}).oSimulationContainer.oTimer;
        oTimer = coSims{iU, iM}.oSimulationContainer.oTimer;

        disp([ 'Avg Time/Tick:' num2str(oTimer.fTime / oTimer.iTick) ' [s]' ]);
        disp('');
    %end
end

% csKeys = poSimObjs.keys();
% 
% for iI = 1:length(csKeys)
%     disp(csKeys{iI});
%     
%     oTimer = poSimObjs(csKeys{iI}).oSimulationContainer.oTimer;
%     
%     disp([ 'Avg Time/Tick:' num2str(oTimer.fTime / oTimer.iTick) ' [s]' ]);
%     disp('');
% end