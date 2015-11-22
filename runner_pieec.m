arUpdFreq = [ 0.01 0.05 0.1 0.5 1 2.5 5 10 25 ];
arMaxDecr = [ 0 10 25 50 100 250 500 1000 5000 10000 ];


arUpdFreq = [ 10 1 0.1 0.01 ];
arMaxDecr = [ 0 10 100 1000 ];


arUpdFreq = [ 0.5 0.25 0.1 0.05 ];
arMaxDecr = [ 500 1000 2000 ];


arUpdFreq = [ 0.1 0.075 0.05 ];
arMaxDecr = [ 100 250 500 750 1500 2000 5000 7500 ];



iL1  = length(arUpdFreq);
iL2  = length(arMaxDecr);
iTot = iL1 * iL2;


coSims = cell(iL1, iL2);


% Just outer loop parallelized. Maybe inner loop would make more sense?
for iU = 1:iL1
    parfor iM = 1:iL2
        
        tSolverParams = struct('rUpdateFrequency', arUpdFreq(iU), 'rHighestMaxChangeDecrease', arMaxDecr(iM));
        
        
        disp('============================================================================');
        disp([ '                           ' num2str(iU * iM) ' / ' num2str(iTot) ]);
        disp('============================================================================');
        disp(tSolverParams);
        disp('============================================================================');
        
        
        ptParams = containers.Map({ 'tutorials.t_piece.systems.Example' }, { struct('fPressureDifference', 0.1, 'fTpieceLen', 0.025) });
        
        coSims{iU, iM} = vhab.sim('tutorials.t_piece.setup', ptParams, tSolverParams);
        oSim = coSims{iU, iM};
        
        oSim.iSimTicks = 5000;
        oSim.bUseTime  = false;
        
        oSim.oSimulationContainer.oTimer.setMinStep(1e-12);
        oSim.toMonitors.oConsoleOutput.setReportingInterval(1000);
        
        %poSimObjs([ 'uf_' num2str(arUpdFreq(iU)) '__md_' num2str(arMaxDecr(iM)) ]) = oSim;
        
        
        
        disp(oSim.oSimulationContainer.tSolverParams);
        disp('============================================================================');
        
        oSim.run();
        
        
    end
end


%THEN: best solution above, then bSynced and gradually increase iDampFR!


%%


save('data/tpiece_test_run.mat', 'poSimObjs', 'coSims');

%%

for iU = 1:iL1
    for iM = 1:iL2
        disp([ 'coSims{' num2str(iU) ',' num2str(iM) '} - ' 'rUF ' num2str(arUpdFreq(iU)) ' - rMD ' num2str(arMaxDecr(iM)) ]);

        %oTimer = poSimObjs(csKeys{iI}).oSimulationContainer.oTimer;
        oTimer = coSims{iU, iM}.oSimulationContainer.oTimer;

        disp([ 'Avg Time/Tick:' num2str(oTimer.fTime / oTimer.iTick) ' [s]' ]);
        disp('');
    end
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