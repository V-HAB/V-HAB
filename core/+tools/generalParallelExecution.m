function generalParallelExecution(sSimulationPath, cmInputs, csSimulationNames, iTicksBetweenUpdateWaitBar, sContinueFromFolder, fAdvanceTo)
    %% generalParallelExecution
    % this script can be used to start parallel execution of any defined
    % simulation with different parameters. This is usefull if e.g. a case
    % study for multiple different cases shall be run on a cluster without
    % GUI in parallel.
    %
    % The first input must be the path to the simulation, this is the path
    % you also provide to the vhab.exec function when running the
    % simulation. E.g. for the ISS this is 
    % sSimulationPath = 'simulations.ISS.setup';
    %
    % The parameters of the simulation can be defined as a
    % cell array of containers.Map, for example for the ISS this could look
    % as follows:
    %
    % cmInputs =   {containers.Map({'tbCases', 'sPlantLocation', 'fSimTime'},{struct('ACLS', false, 'PlantChamber', false), '',         300}),...
    %               containers.Map({'tbCases', 'sPlantLocation', 'fSimTime'},{struct('ACLS', false, 'PlantChamber', true),  'Columbus', 300}),...
    %               containers.Map({'tbCases', 'sPlantLocation', 'fSimTime'},{struct('ACLS', false, 'PlantChamber', true),  'US_Lab',   300}),...
    %               containers.Map({'tbCases', 'sPlantLocation', 'fSimTime'},{struct('ACLS', false, 'PlantChamber', true),  'JEM',      300}),...
    %               containers.Map({'tbCases', 'sPlantLocation', 'fSimTime'},{struct('ACLS', false, 'PlantChamber', true),  'SM',       300})};
    %
    % csSimulationNames is an optional input where the user can assign
    % names for the simulations which are used to store the files/ show in
    % the waitbar
    %
    % iTicksBetweenUpdateWaitBar is also optional and defines how many
    % ticks pass before the wait bar and console output showing the state
    % of the simulation is updated
    
    iSimulations = length(cmInputs);
    
    if nargin < 2
        csSimulationNames = cell(1, iSimulations);
        for iSimulation = 1:iSimulations
            csSimulationNames{iSimulation} = num2str(iSimulation);
        end
    end
    if nargin < 3
        iTicksBetweenUpdateWaitBar = 1;
    end
    
    fCreated = now();
    global sStorageDirectory
    sStorageDirectory = [ datestr(fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') '_ParallelExecution'];
    
    if ~isfolder([ 'data/runs/' sStorageDirectory ])
        mkdir([ 'data/runs/' sStorageDirectory ]);
    end
            
    % Creating a matter table object. Due to the file system access that is
    % done during the matter table instantiation, this cannot be done within
    % the parallel loop.
    oMT = matter.table();

    % Creating a timer object. This is necessary, because we want to
    % use a multiWaitbar to show the progress of the individual
    % simulations. Since the multiWaitbar function is not designed to
    % be called from multiple workers simultaneously, the timer object
    % acts as the queue manager for the calls to update the wait bar.
    % For that we actually need to explicitly set the BusyMode property
    % of the timer to 'queue'.
    oWaitBarTimer = timer;
    oWaitBarTimer.BusyMode = 'queue';

    % Now we set the timer function to the nested updateWaitbar()
    % function that is defined at the end of this function. It needs to
    % be generic regarding its input because it needs to handle both
    % the 'update' calls as well as the 'close' calls when a simulation
    % is completed.
    oWaitBarTimer.TimerFcn = @(xInput) updateWaitBar(xInput);

    % It may be the case that a user wants to abort all simulations
    % while they are still running. Since they are running on parallel
    % workers, creating the 'STOP' file in the base directory won't
    % work. So we provide a nice, big, red STOP button here that calls
    % the other nested function called stopAllSims(). This callback
    % changes dynamically based on the number of simulations that are
    % currently running. So the actual assignment of that callback is
    % done later on. Here we just create the figure and the button. 
    oFigure = figure('Name','Control', ...
        'MenuBar','none');
    oFigure.Position(3:4) = [200 150];

    oButton = uicontrol(oFigure, ...
        'Style', 'Pushbutton', ...
        'Units', 'normalized', ...
        'String', 'STOP', ...
        'ForegroundColor', 'red', ...
        'FontSize', 20, ...
        'FontWeight', 'bold');

    oButton.Units = 'normalized';
    oButton.Position = [0.25 0.25 0.5 0.5];

    % The button callback will set this boolean variable to true so we
    % can properly abort the for and while loops below. 
    bCancelled = false;
    
    % In order to steer the while loop within the for loop below, we
    % need these variables to keep track of which simulations are
    % currently running. 
    abActiveSimulations = false(iSimulations,1);
    iActiveSimulations = 0;
    
    % The parallel pool memory usage continues to pile up if it is not
    % restarted
    % create a parallel pool
    oPool = gcp();

    % Creating an empty array of pollable data queues so we can get
    % information from the workers and their simulations while they are
    % running.
    aoDataQueues = parallel.pool.DataQueue.empty(iSimulations,0);

    for  iSimulation = 1:iSimulations
        mInputs = cmInputs{iSimulation};

        % Now we create a wait bar for each simulation. We do this here and
        % not within the for loop below so the user can see all simulations
        % at once and not just the ones that are currently running. 
        tools.multiWaitbar(['Simulation ', csSimulationNames{iSimulation}, ':'], 0);

        aoDataQueues(iSimulation) = parallel.pool.DataQueue;

        % The afterEach() function will execute the timer function
        % after each transmission from the worker. There the send()
        % method is called with a payload of data which is passed
        % directly to the timer function by afterEach(). Here this
        % is used to update the waitbar for the individual
        % simulation.
        afterEach(aoDataQueues(iSimulation), oWaitBarTimer.TimerFcn);

        if nargin > 4 && ~isempty(sContinueFromFolder)
            aoResults(iSimulation) = parfeval(oPool, @runSim, 1, sSimulationPath, mInputs, iTicksBetweenUpdateWaitBar, oMT, aoDataQueues(iSimulation), iSimulation, sContinueFromFolder, csSimulationNames, fAdvanceTo);  %#ok
        else
            aoResults(iSimulation) = parfeval(oPool, @runSim, 1, sSimulationPath, mInputs, iTicksBetweenUpdateWaitBar, oMT, aoDataQueues(iSimulation), iSimulation);  %#ok
        end
        % Now that the FevalFuture object hast been added to the
        % aoResultObjects array, we can update the callback of the
        % stop button to include the current version of this array.
        % This ensures that all simulations that are currently
        % running are properly aborted when the button is pressed. 
        oButton.Callback = { @stopAllSims, aoResults };

        % In order to control the addition of new simulations to
        % the parallel pool, we need to keep track of how many
        % simulations are currently running, so we set the
        % following variables accordingly. 
        iActiveSimulations = iActiveSimulations + 1;
        abActiveSimulations(iSimulation) = true;
    end

    abErrorResults = false(1, iSimulations);
    for idx = 1:iSimulations
       % fetchNext blocks until more results are available, and
       % returns the index into f that is now complete, as well
       % as the value computed by f.
       if ~bCancelled
           try
               [completedIdx, value] = fetchNext(aoResults);
               disp(['got Results for Simulation: ', csSimulationNames(completedIdx)])
               
               sSimObjName = ['oLastSimObj_', csSimulationNames{completedIdx},'.mat'];
               sFileName = sprintf('data/runs/%s/%s', sStorageDirectory, sSimObjName);
               
               % We want the stored variable to have the same name that we use
               % for the object that is assigned in the base workspace, so we
               % create a reference to the infrastructure object called
               % 'oLastSimObj'.
               oLastSimObj = value;
               
               % Actually saving the object into the mat file.
               save(sFileName, 'oLastSimObj', '-v7.3');
               
               % No matter the reason, this simulation is done, so
               % we can delete the wait bar for it.
               oWaitBarTimer.TimerFcn(completedIdx);
           catch oErr
               for iResult = 1:length(aoResults)
                   if ~isempty(aoResults(iResult).Error) && ~abErrorResults(iResult)
                       disp(aoResults(iResult).Error.message)
                       rethrow(oErr)
                 elseif isprop(aoResults(iResult),  'OutputArguments') && ~isempty(aoResults(iResult).OutputArguments) && isa(aoResults(iResult).OutputArguments{1}, 'MException')
                       rethrow(aoResults(iResult).OutputArguments{1})
                   end
               end
           end

       end
    end
    
%% Nested functions

    function updateWaitBar(xInput)
        % This function updates the wait bar for an individual simulation
        % or deletes it. Both functions call the tools.multiWaitbar()
        % function with different sets of input arguments.
        % For the 'update' case, this function is called by the afterEach()
        % method of a parallel data queue. The input parameters are
        % provided as a 2x1 double array containing the simulation's index
        % and it's progress as a percentage. The index is converted to a
        % string containing the name of the simulation, which acts as the
        % identifier within the wait bar. For the 'close' case, this
        % function is called with just the index of the simulation. 
        
        % To discern between these two callers, we enclose the 'update'
        % call in a try catch block. If the xInput argument contains a
        % second element (xInput(2)) then we are being called from the data
        % queue to update the wait bar. If xInput only has one element,
        % this call will fail, so within the catch part, we handle the
        % closing of the waitbar. 
        try
            tools.multiWaitbar(['Simulation ', csSimulationNames{xInput(1)}, ':'], xInput(2));
            disp(['Simulation ', csSimulationNames{xInput(1)}, ': ' , num2str(xInput(2)*100, 3),'%'])
        catch %#ok<CTCH>
            tools.multiWaitbar(['Simulation ', csSimulationNames{xInput(1)}, ':'], 'Close');
        end
    end

    function stopAllSims(~, ~, aoResultObjects)
        % This function is the callback for the STOP button. When it is
        % pressed, this function loops through all parallel.FevalFuture
        % objects in the aoResultsObjects input argument and cancels the
        % worker, unless it is already finished. 
        for iObject = 1:length(aoResultObjects)
            if ~strcmp(aoResultObjects(iObject).State, 'finished')
                cancel(aoResultObjects(iObject));
            end
        end
        
        % In order to prevent further simulations from being added after
        % the button is pressed, we set this boolean variable to true. 
        bCancelled = true;
    end
end

function oLastSimObj = runSim(sSimulationPath, mInputs, iTicksBetweenUpdateWaitBar, oMT, oDataQueue, iSim, sContinueFromFolder, csSimulationNames, fAdvanceTo)
    % Combine the inputs defined by the user with the parallelization
    % inputs:
    try
        csKeys = keys(mInputs);
        csKeys{end+1} = 'ParallelExecution';

        csValues = values(mInputs);
        csValues{end+1} = {oMT, oDataQueue, iSim};

        if nargin > 6 && ~isempty(sContinueFromFolder)

            sSimObjName = ['oLastSimObj_', csSimulationNames{iSim},'.mat'];
            sFileName = sprintf('data/runs/%s/%s', sContinueFromFolder, sSimObjName);

            load(sFileName, 'oLastSimObj');

            oLastSimObj.setParallelSendInterval(iTicksBetweenUpdateWaitBar);

            % Actually running the simulation
            oLastSimObj.advanceTo(fAdvanceTo, oDataQueue, iSim);
        else
            oLastSimObj = vhab.sim(sSimulationPath, containers.Map(csKeys, csValues), []);

            oLastSimObj.setParallelSendInterval(iTicksBetweenUpdateWaitBar);

            % Actually running the simulation
            oLastSimObj.run();
        end
    catch oErr
        % this try and catch is necessary, because otherwise the parallel
        % execution will only throw the error that not enough output
        % arguments were provided. However, by catching potential errors
        % and assigning them as output here, the output arguments are
        % correct and we can later rethrow the actual error to allow the
        % user easier debugging
        oLastSimObj = oErr;
    end
end