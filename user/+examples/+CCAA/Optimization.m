function Optimization()
    mfLength            = 0.2:0.01:0.4;
    mfBroadness         = 0.2:0.01:0.4;

    mfAirOutletDiff         = zeros(length(mfLength), length(mfBroadness));
    mfCoolantOutletDiff     = zeros(length(mfLength), length(mfBroadness));
    mfWaterProduced         = zeros(length(mfLength), length(mfBroadness));

    Data = load('user\+examples\+CCAA\+TestData\ProtoflightData.mat');

    iSimTicks = 4;
    
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
    abActiveSimulations = false(length(mfBroadness),1);
    iActiveSimulations = 0;
    
    for iLength = 1:length(mfLength)
        fLength = mfLength(iLength);
        disp(['Currently calculating Length: ', num2str(fLength)])
        
        % The parallel pool memory usage continues to pile up if it is not
        % restarted
        % create a parallel pool
        oPool = gcp();

        % Creating an empty array of pollable data queues so we can get
        % information from the workers and their simulations while they are
        % running.
        aoDataQueues = parallel.pool.DataQueue.empty(length(mfBroadness),0);
        aoResultObjects = parallel.FevalFuture.empty(length(mfBroadness),0);

        for iBroadness = 1:length(mfBroadness)
            fBroadness = mfBroadness(iBroadness);
            % Now we create a wait bar for each simulation. We do this here and
            % not within the for loop below so the user can see all simulations
            % at once and not just the ones that are currently running. 
            tools.multiWaitbar(['Broadness: ', num2str(mfBroadness(iBroadness))], 0);
            
            aoDataQueues(iBroadness) = parallel.pool.DataQueue;
                
            % The afterEach() function will execute the timer function
            % after each transmission from the worker. There the send()
            % method is called with a payload of data which is passed
            % directly to the timer function by afterEach(). Here this
            % is used to update the waitbar for the individual
            % simulation.
            afterEach(aoDataQueues(iBroadness), oWaitBarTimer.TimerFcn);
            
            aoResults(iBroadness) = parfeval(oPool, @runCCAASim, 1, fBroadness, fLength, iSimTicks, Data, oMT, aoDataQueues(iBroadness), iBroadness);
            
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
            abActiveSimulations(iBroadness) = true;
        end
        
            
        Results = cell(1, length(mfBroadness));
        for idx = 1:length(mfBroadness)
           % fetchNext blocks until more results are available, and
           % returns the index into f that is now complete, as well
           % as the value computed by f.
           if ~bCancelled
               [completedIdx, value] = fetchNext(aoResults);
               Results{completedIdx} = value;
               disp(['got Results for Broadness: ', num2str(mfBroadness(completedIdx))])

               mfAirOutletDiff(iLength, completedIdx)        = Results{completedIdx}.fAirOutletDiff;
               mfCoolantOutletDiff(iLength, completedIdx)    = Results{completedIdx}.fCoolantOutletDiff;
               mfWaterProduced(iLength, completedIdx)        = Results{completedIdx}.fWaterProduced;
               delete(aoResults(completedIdx));
           end
            % No matter the reason, this simulation is done, so
            % we can delete the wait bar for it. 
            oWaitBarTimer.TimerFcn(completedIdx);
        end
        try 
            oPool.delete
        catch
            % well if we cannot delete it, it is probably already deleted
        end
    end
    
    % gets the screen size
    scrsz = get(groot,'ScreenSize');

    X = ones(1, length(mfBroadness)) .* mfLength';
    Y = ones(length(mfLength), 1) .* mfBroadness;
    figure1 = figure('name', 'Air Outlet Temperature Difference');
    figure1.Position = [scrsz(3)/12, scrsz(4)/12 + scrsz(4)/2, scrsz(3)/3 scrsz(4)/3];
    mesh(X, Y, mfAirOutletDiff);
    xlabel('Length / m')
    ylabel('Broadness / m')
    zlabel('Air Outlet Temperature Difference / K')
    
    figure2 = figure('name', 'Coolant Outlet Temperature Difference');
    figure2.Position = [scrsz(3)/12 + scrsz(3)/2, scrsz(4)/12 + scrsz(4)/2, scrsz(3)/3 scrsz(4)/3];
    mesh(X, Y, mfCoolantOutletDiff);
    xlabel('Length / m')
    ylabel('Broadness / m')
    zlabel('Coolant Outlet Temperature Difference / K')
    
    figure3 = figure('name', 'Condensate Flow Difference');
    figure3.Position =  [scrsz(3)/12, scrsz(4)/12, scrsz(3)/3 scrsz(4)/3];
    mesh(X, Y, mfWaterProduced);
    xlabel('Length / m')
    ylabel('Broadness / m')
    zlabel('Condensate Flow Difference / kg/h')
    
    % Get minimum Index for Broadness
%     [~, minIndexBroadnessAir]   = min(min(abs(mfAirOutletDiff), [], 1));
%     [~, minIndexLengthAir]      = min(min(abs(mfAirOutletDiff), [], 2));
% 
%     [~, minIndexBroadnessCoolant]   = min(min(abs(mfCoolantOutletDiff), [], 1));
%     [~, minIndexLengthCoolant]      = min(min(abs(mfCoolantOutletDiff), [], 2));
%     
%     [~, minIndexBroadnessCondensate]   = min(min(abs(mfWaterProduced), [], 1));
%     [~, minIndexLengthCondensate]      = min(min(abs(mfWaterProduced), [], 2));
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
            tools.multiWaitbar(['Broadness: ', num2str(mfBroadness(xInput(1)))], xInput(2));
        catch %#ok<CTCH>
            tools.multiWaitbar(['Broadness: ', num2str(mfBroadness(xInput(1)))], 'Close');
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

function tCCAA = runCCAASim(fBroadness, fLength, iSimTicks, Data, oMT, oDataQueue, iSim)
    oLastSimObj = vhab.sim('examples.CCAA.setup', containers.Map({'ParallelExecution', 'tParameters'}, {{oMT, oDataQueue, iSim}, struct('fBroadness', fBroadness, 'fLength', fLength, 'iSimTicks', iSimTicks)}), []);

    % Actually running the simulation
    oLastSimObj.run();

    oLogger = oLastSimObj.toMonitors.oLogger;

    mfAirOutletTemperature      = zeros(oLogger.iLogIndex, 6);
    mfMixedAirOutletTemperature = zeros(oLogger.iLogIndex, 6);
    mfCoolantOutletTemperature  = zeros(oLogger.iLogIndex, 6);
    mfCondensateFlow            = zeros(oLogger.iLogIndex, 6);
    for iLog = 1:length(oLogger.tLogValues)
        for iProtoflightTest = 1:6
            if strcmp(oLogger.tLogValues(iLog).sLabel, ['CCAA_', num2str(iProtoflightTest), ' Air Outlet Temperature'])
                mfAirOutletTemperature(:, iProtoflightTest) = oLogger.mfLog(1:oLogger.iLogIndex, oLogger.tLogValues(iLog).iIndex);
            elseif strcmp(oLogger.tLogValues(iLog).sLabel, ['CCAA_', num2str(iProtoflightTest), ' Mixed Air Outlet Temperature'])
                mfMixedAirOutletTemperature(:, iProtoflightTest) = oLogger.mfLog(1:oLogger.iLogIndex, oLogger.tLogValues(iLog).iIndex);
            elseif strcmp(oLogger.tLogValues(iLog).sLabel, ['CCAA_', num2str(iProtoflightTest), ' Coolant Outlet Temperature'])
                mfCoolantOutletTemperature(:, iProtoflightTest) = oLogger.mfLog(1:oLogger.iLogIndex, oLogger.tLogValues(iLog).iIndex);
            elseif strcmp(oLogger.tLogValues(iLog).sLabel, ['CCAA_', num2str(iProtoflightTest), ' Condensate Flow Rate'])
                mfCondensateFlow(:, iProtoflightTest) = oLogger.mfLog(1:oLogger.iLogIndex, oLogger.tLogValues(iLog).iIndex);
            end
        end
    end

    mfAirTemperatureDifference      = mfMixedAirOutletTemperature(4,:) 	- Data.ProtoflightTestData.AirOutletTemperature';
    mfCoolantTemperatureDifference  = mfCoolantOutletTemperature(4,:)   - Data.ProtoflightTestData.CoolantOutletTemperature';
    mfCondensateDifference          = mfCondensateFlow(4,:) * 3600      - Data.ProtoflightTestData.CondensateMassFlow';

    tCCAA.fAirOutletDiff        = mean(mfAirTemperatureDifference);
    tCCAA.fCoolantOutletDiff	= mean(mfCoolantTemperatureDifference);
    tCCAA.fWaterProduced        = mean(mfCondensateDifference);
end