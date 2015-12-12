function coSims = testDifferentSolverValues()


atSolverParams = struct('rUpdateFrequency', {}, 'rHighestMaxChangeDecrease', {});


atSolverParams(end + 1).rUpdateFrequency      = 0.01;
atSolverParams(end).rHighestMaxChangeDecrease = 100;

atSolverParams(end + 1).rUpdateFrequency      = 0.01;
atSolverParams(end).rHighestMaxChangeDecrease = 1000;

atSolverParams(end + 1).rUpdateFrequency      = 0.01;
atSolverParams(end).rHighestMaxChangeDecrease = 10000;



atSolverParams(end + 1).rUpdateFrequency      = 0.1;
atSolverParams(end).rHighestMaxChangeDecrease = 10;

atSolverParams(end + 1).rUpdateFrequency      = 0.1;
atSolverParams(end).rHighestMaxChangeDecrease = 100;

atSolverParams(end + 1).rUpdateFrequency      = 0.1;
atSolverParams(end).rHighestMaxChangeDecrease = 1000;

atSolverParams(end + 1).rUpdateFrequency      = 0.1;
atSolverParams(end).rHighestMaxChangeDecrease = 10000;



atSolverParams(end + 1).rUpdateFrequency      = 1;
atSolverParams(end).rHighestMaxChangeDecrease = 1;

atSolverParams(end + 1).rUpdateFrequency      = 1;
atSolverParams(end).rHighestMaxChangeDecrease = 10;

atSolverParams(end + 1).rUpdateFrequency      = 1;
atSolverParams(end).rHighestMaxChangeDecrease = 100;

atSolverParams(end + 1).rUpdateFrequency      = 1;
atSolverParams(end).rHighestMaxChangeDecrease = 1000;


atSolverParams(end + 1).rUpdateFrequency      = 10;
atSolverParams(end).rHighestMaxChangeDecrease = 1;

atSolverParams(end + 1).rUpdateFrequency      = 10;
atSolverParams(end).rHighestMaxChangeDecrease = 10;

atSolverParams(end + 1).rUpdateFrequency      = 10;
atSolverParams(end).rHighestMaxChangeDecrease = 100;



atSolverParams(end + 1).rUpdateFrequency      = 100;
atSolverParams(end).rHighestMaxChangeDecrease = 1;

atSolverParams(end + 1).rUpdateFrequency      = 100;
atSolverParams(end).rHighestMaxChangeDecrease = 10;






%%



iL1  = length(atSolverParams);


coSims = cell(iL1, 1);


parfor iM = 1:iL1

    tSolverParams = atSolverParams(iM);


    disp('============================================================================');
    disp([ '                           ' num2str(iM) ' / ' num2str(iL1) ]);
    disp('============================================================================');
    disp(tSolverParams);
    disp('============================================================================');
    

    ptParams = containers.Map();

    coSims{iM} = vhab.sim('tutorials.p2p.setup', ptParams, tSolverParams);
    oSim = coSims{iM};

    %oSim.iSimTicks = 2500;
    %oSim.bUseTime  = false;

    %oSim.oSimulationContainer.oTimer.setMinStep(1e-12);
    oSim.toMonitors.oConsoleOutput.setReportingInterval(1000);

    %poSimObjs([ 'uf_' num2str(arUpdFreq(iU)) '__md_' num2str(arMaxDecr(iM)) ]) = oSim;




    oSim.run();


end








%%


%if nargout == 0
    assignin('base', 'coSims', coSims);
%end





%%

for iS = 1:length(coSims)
    fprintf('======== %i ========\n', iS);
    fprintf('rUF: %f, rMD: %f\n', coSims{iS}.oSimulationContainer.tSolverParams.rUpdateFrequency, coSims{iS}.oSimulationContainer.tSolverParams.rHighestMaxChangeDecrease);
    fprintf('Runtime: %fs\n', coSims{iS}.fRuntimeTick);
    fprintf('Ticks: %i\n', coSims{iS}.oSimulationContainer.oTimer.iTick);
end



end

