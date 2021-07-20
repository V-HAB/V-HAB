function Convergence()

    miCells             = [2, 5, 10:10:90];
    
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
    abActiveSimulations = false(length(miCells),1);
    iActiveSimulations = 0;
    
    % The parallel pool memory usage continues to pile up if it is not
    % restarted
    % create a parallel pool
    oPool = gcp();

    % Creating an empty array of pollable data queues so we can get
    % information from the workers and their simulations while they are
    % running.
    aoDataQueues = parallel.pool.DataQueue.empty(length(miCells),0);

    for  iCell = 1:length(miCells)
        iCells = miCells(iCell);

        % Now we create a wait bar for each simulation. We do this here and
        % not within the for loop below so the user can see all simulations
        % at once and not just the ones that are currently running. 
        tools.multiWaitbar(['Number of Cells: ', num2str(miCells(iCell))], 0);

        aoDataQueues(iCell) = parallel.pool.DataQueue;

        % The afterEach() function will execute the timer function
        % after each transmission from the worker. There the send()
        % method is called with a payload of data which is passed
        % directly to the timer function by afterEach(). Here this
        % is used to update the waitbar for the individual
        % simulation.
        afterEach(aoDataQueues(iCell), oWaitBarTimer.TimerFcn);

        aoResults(iCell) = parfeval(oPool, @runSim, 1, iCells, oMT, aoDataQueues(iCell), iCell);  %#ok

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
        abActiveSimulations(iCell) = true;
    end


    Results = cell(1, length(miCells));
    abErrorResults = false(1, length(miCells));
    for idx = 1:length(miCells)
       % fetchNext blocks until more results are available, and
       % returns the index into f that is now complete, as well
       % as the value computed by f.
       if ~bCancelled
           try
               [completedIdx, value] = fetchNext(aoResults);
               Results{completedIdx} = value;
               disp(['got Results for Cell Number: ', num2str(miCells(completedIdx))])
               
               cfTimeStep{completedIdx}                 = Results{completedIdx}.afTimeStep; %#ok
               cfPartialPressureCO2_Torr{completedIdx}  = Results{completedIdx}.mfPartialPressureCO2_Torr; %#ok
               cfCO2InletFlow{completedIdx}             = Results{completedIdx}.mfCO2InletFlow; %#ok
               cfH2OInletFlow{completedIdx}             = Results{completedIdx}.mfH2OInletFlow; %#ok
               cfCO2OutletFlow{completedIdx}            = Results{completedIdx}.mfCO2OutletFlow; %#ok
               cfH2OOutletFlow{completedIdx}            = Results{completedIdx}.mfH2OOutletFlow; %#ok
               
               mfAveragedCO2Outlet(completedIdx)        = Results{completedIdx}.fAveragedCO2Outlet; %#ok
               mfMaxDiff(completedIdx)                  = Results{completedIdx}.fMaxDiff; %#ok
               mfMinDiff(completedIdx)                  = Results{completedIdx}.fMinDiff; %#ok
               mfMeanDiff(completedIdx)                 = Results{completedIdx}.fMeanDiff; %#ok
               mrPercentualError(completedIdx)          = Results{completedIdx}.rPercentualError; %#ok
               mfMeanSquaredError(completedIdx)         = Results{completedIdx}.fMeanSquaredError; %#ok
               
               % Just to be save we also store the data while the
               % simulations are still in progress
               tCellData.fTimeStep                 = Results{completedIdx}.afTimeStep; 
               tCellData.fPartialPressureCO2_Torr  = Results{completedIdx}.mfPartialPressureCO2_Torr;
               tCellData.fCO2InletFlow             = Results{completedIdx}.mfCO2InletFlow;
               tCellData.fH2OInletFlow             = Results{completedIdx}.mfH2OInletFlow;
               tCellData.fCO2OutletFlow            = Results{completedIdx}.mfCO2OutletFlow;
               tCellData.fH2OOutletFlow            = Results{completedIdx}.mfH2OOutletFlow;
               
               tCellData.fAveragedCO2Outlet        = Results{completedIdx}.fAveragedCO2Outlet;
               tCellData.fMaxDiff                  = Results{completedIdx}.fMaxDiff;
               tCellData.fMinDiff                  = Results{completedIdx}.fMinDiff;
               tCellData.fMeanDiff                 = Results{completedIdx}.fMeanDiff;
               tCellData.rPercentualError          = Results{completedIdx}.rPercentualError;
               tCellData.fMeanSquaredError         = Results{completedIdx}.fMeanSquaredError;
               
               save(['CellNumber', num2str(miCells(completedIdx))], 'tCellData');
    
               % No matter the reason, this simulation is done, so
               % we can delete the wait bar for it.
               oWaitBarTimer.TimerFcn(completedIdx);
           catch oErr
               for iResult = 1:length(aoResults)
                   if ~isempty(aoResults(iResult).Error) && ~abErrorResults(iResult)
                       if strcmp(aoResults(iResult).Error.message, 'Heater Power insufficient to operate reactor')
                           
                           keyboard()
                           
                           abErrorResults(iResult)                       = true;
                           oWaitBarTimer.TimerFcn(iResult);
                       else
                           disp(aoResults(iResult).Error.message)
                           rethrow(oErr)
                       end
                   end
               end
           end

       end
    end
    
    tData.cfTimeStep                = cfTimeStep;
    tData.cfPartialPressureCO2_Torr = cfPartialPressureCO2_Torr;
    tData.cfCO2InletFlow            = cfCO2InletFlow;
    tData.cfH2OInletFlow            = cfH2OInletFlow;
    tData.cfCO2OutletFlow           = cfCO2OutletFlow;
    tData.cfH2OOutletFlow           = cfH2OOutletFlow;
    tData.mfAveragedCO2Outlet    	= mfAveragedCO2Outlet;
    tData.mfMaxDiff                 = mfMaxDiff;
    tData.mfMinDiff                 = mfMinDiff;
    tData.mfMeanDiff                = mfMeanDiff;
    tData.mrPercentualError       	= mrPercentualError;
    tData.mfMeanSquaredError      	= mfMeanSquaredError;
    
    save('ConvergenveData', 'tData');
    
    figure('name', 'Convergence');
    plot(miCells, tData.mfAveragedCO2Outlet)
    ylabel('Averaged CO2 Outlet Flow / kg/s')
    xlabel('Cell Number per Bed / -')
    
    savefig('Convergence.fig')
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
            tools.multiWaitbar(['Number of Cells: ', num2str(miCells(xInput(1)))], xInput(2));
            disp(['Number of Cells ', num2str(miCells(xInput(1))), ': ' , num2str(xInput(2), 3),'%'])
        catch %#ok<CTCH>
            tools.multiWaitbar(['Number of Cells: ', num2str(miCells(xInput(1)))], 'Close');
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

function tSim = runSim(iCells, oMT, oDataQueue, iSim)
    oLastSimObj = vhab.sim('examples.CDRA.setup', containers.Map({'ParallelExecution', 'tInitialization'}, {{oMT, oDataQueue, iSim}, struct('Zeolite13x', struct('iCellNumber', iCells), 'Sylobead', struct('iCellNumber', iCells), 'Zeolite5A', struct('iCellNumber', iCells))}), []);

    % Actually running the simulation
    oLastSimObj.run();

    oLogger = oLastSimObj.toMonitors.oLogger;
    csLogVariableNames = {'Timestep', 'Partial Pressure CO2 Torr', 'CDRA CO2 InletFlow', 'CDRA H2O InletFlow', 'CDRA CO2 OutletFlow', 'CDRA H2O OutletFlow'};
    [aiLogIndices, aiVirtualLogIndices] = tools.findLogIndices(oLogger, csLogVariableNames);
    
    
    tSim.afTimeStep                  = oLogger.mfLog(:,aiLogIndices(1));
    tSim.mfPartialPressureCO2_Torr   = oLogger.tVirtualValues(aiVirtualLogIndices(2)).calculationHandle(oLogger.mfLog);
    tSim.mfCO2InletFlow              = oLogger.tVirtualValues(aiVirtualLogIndices(3)).calculationHandle(oLogger.mfLog);
    tSim.mfH2OInletFlow              = oLogger.tVirtualValues(aiVirtualLogIndices(4)).calculationHandle(oLogger.mfLog);
    tSim.mfCO2OutletFlow             = oLogger.tVirtualValues(aiVirtualLogIndices(5)).calculationHandle(oLogger.mfLog);
    tSim.mfH2OOutletFlow             = oLogger.tVirtualValues(aiVirtualLogIndices(6)).calculationHandle(oLogger.mfLog);
    
    mfCO2PartialPressure = tSim.mfPartialPressureCO2_Torr;
    
    iFileID = fopen(strrep('+examples/+CDRA/+TestData/CDRA_Test_Data.csv','/',filesep), 'r');
            
    [FilePath,~,~,~] = fopen(iFileID);

    mfTestData = csvread(FilePath);
    % at hour 50 of the test data the CO2 input is reduced to 4 CM,
    % this corresponds to hour 19.3 in the simulation. Therefore
    % Test data is timeshifted by 30.7 hours to fit the simulation
    % and ease plotting:
    mfTestData(:,1) = mfTestData(:,1) - 30.7;
    % We do not need the negative values (the test data had a
    % period where an error occur, we start comparing after that)
    mfTestData(mfTestData(:,1) < 0,:) = [];

    mfCO2PartialPressure(isnan(mfCO2PartialPressure)) = [];

    afTime = (oLogger.afTime./3600)';
    afTime(isnan(afTime)) = [];

    [afTimeDataUnique, ia, ~] = unique(mfTestData(:,1));
    afCO2DataUnique = mfTestData(ia,2);

    InterpolatedTestData = interp1(afTimeDataUnique, afCO2DataUnique, afTime);

    % There will be some nan values because the simulation has data
    % before the simulation data, these are removed here
    mfCO2PartialPressure(isnan(InterpolatedTestData)) = [];
    afTime(isnan(InterpolatedTestData)) = [];
    InterpolatedTestData(isnan(InterpolatedTestData)) = [];

    % We only look at the differen from hour 11 onward as before
    % the test data is not accurate because CDRA was turned off
    % since it had a water carry over event
    mfCO2PartialPressure(afTime < 11) = [];
    InterpolatedTestData(afTime < 11) = [];
    
    tSim.fAveragedCO2Outlet = sum(tSim.mfCO2OutletFlow .* tSim.afTimeStep) ./ sum(tSim.afTimeStep);
    tSim.fMaxDiff  = max(abs(mfCO2PartialPressure - InterpolatedTestData));
    tSim.fMinDiff  = min(abs(mfCO2PartialPressure - InterpolatedTestData));
    tSim.fMeanDiff = mean(mfCO2PartialPressure - InterpolatedTestData);
    tSim.rPercentualError = 100 * tSim.fMeanDiff / mean(InterpolatedTestData);
    tSim.fMeanSquaredError = mean((mfCO2PartialPressure - InterpolatedTestData).^2);
    
end