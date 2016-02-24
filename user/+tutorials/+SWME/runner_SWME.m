%RUNNER_SWME runs some SWME simulations in parallel

% Setting the different inlet temperatures that we want to try out.
afTemperatures = [ 16 20 24 28 32 ];
afTemperatures = afTemperatures + 273.15;

% Creating an empty cell that will store the simulation objects. We need
% these to trigger plotting later.
coSims = cell(length(afTemperatures), 1);

% Creating a matter table object. Due to the file system access that is
% done during the matter table instantiation, this cannot be done within
% the parallel loop. 
oMT = matter.table();

% Starting the parallel loop
parfor iM = 1:length(afTemperatures)
    
    % Need an empty struct to pass on to the simulation
    tSolverParams = struct();
    
    % Creating the container map input parameter. Key 'ParallelExecution'
    % is a MUST. 
    ptParams = containers.Map({ 'ParallelExecution', 'tutorials.SWME.systems.Example' }, { oMT, struct('fInitialTemperature', afTemperatures(iM))});
    
    % Actually creating the simulation object and storing it into the cell.
    coSims{iM} = vhab.sim('tutorials.SWME.setup', ptParams, tSolverParams);
    oSim = coSims{iM};
    
    % We have to set the reporting interval fairly high, because otherwise
    % the console would be bombarded with outputs. This also suppresses the
    % period characters '.' in between the major console updates. 
    oSim.toMonitors.oConsoleOutput.setReportingInterval(1000);
    
    % Finally we actually run the simulation.
    oSim.run();
    
end

% We are done, so now we can call the plot() method on all of the
% simulation objects.
for iI = 1:length(coSims)
%     coSims{iI}.plot();
    fprintf('--------------------------------------------------\n');
    fprintf('Simulation %i - Inlet Temperature %f K\n', iI, afTemperatures(iI));
    fprintf('Heat Flow: %f\n', coSims{iI}.oSimulationContainer.toChildren.Test.toChildren.SWME.toProcsF2F.TemperatureProcessor.fHeatFlow);
    fprintf('Outlet Temperature: %f\n', coSims{iI}.oSimulationContainer.toChildren.Test.toChildren.SWME.toProcsF2F.TemperatureProcessor.aoFlows(2).fTemperature);
    fprintf('Mass Flow: %f\n', coSims{iI}.oSimulationContainer.toChildren.Test.toChildren.SWME.toBranches.EnvironmentBranch.fFlowRate);
    
    fBackpressure = coSims{iI}.oSimulationContainer.toChildren.Test.toChildren.SWME.toStores.SWMEStore.toPhases.VaporSWME.fMass * coSims{iI}.oSimulationContainer.toChildren.Test.toChildren.SWME.toStores.SWMEStore.toPhases.VaporSWME.fMassToPressure;
    fprintf('Backpressure: %f\n', fBackpressure);
    fprintf('--------------------------------------------------\n\n');
    
end