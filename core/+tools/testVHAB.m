function testVHAB(sCompareToState, fSimTime, bForceExecution, bDebugModeOn)
%TESTVHAB Runs all tests and saves the figures to a folder
%   This function is a debugging helper. It will run all tests inside
%   the user/+tests folder and save the resulting figures to
%   data/Testrun/ with a timestamp. The only condition for this
%   to work is that the class file that inherits from simulation.m is on
%   the top level of the tutorial folder and is called 'setup.m'. If this
%   is not the case, the function will throw an error.
%
%   If you have the Parallel Computing Toolbox installed this function will
%   create a parallel pool and execute as many of the tests in parallel as
%   possible. This significantly speeds up the execution time.
%
%   Possible inputs are:
%   sCompareToState: a String which allows the user to select against which
%   version of the code the current run should be compare. It can either be
%   'server' or 'local'.
%   For 'server' the current will be compared against the file
%   user/+tests/ServerTestStatus.mat, which is created and maintained by
%   the Institute of Astronautics. If you compare to this file, the
%   execution speed will most likely differ because you are running it on a
%   different computer, but the mass balance values should not change
%   unless you changed something in the core.
%   For 'local' the run will be compared against the file
%   data/OldTestStatus.mat. In case that file does not yet exist, it will
%   be created on the first run of this function. After it has been created
%   once, it will not change automatically, if you want to compare to a
%   different version of the code, you have to rename the file
%   data/TestStatus.mat into OldTestStatus.mat and overwrite the other
%   file. The TestStatus file is created on each run of this function and
%   always represents the latest run of this function

% Starting a timer so we can capture how long this function takes to
% complete.
hTimer = tic();

% Processing the input parameters

if nargin < 1
    sCompareToState = 'server';
else
    if  ~(strcmp(sCompareToState, 'server') ||  strcmp(sCompareToState, 'local'))
        error('VHAB:testVHAB','Unknown state to which the testVHAB run should be compared');
    end
end

if nargin < 2
    fSimTime = [];
end

if nargin < 3
    bForceExecution = false;
end

if nargin < 4
    bDebugModeOn = false;
end

% First we get the struct that shows us the current contents of the
% tests directory. We also check which entries are directories.
sTestDirectory = fullfile('user', '+tests');
tTests   = dir(sTestDirectory);
mbIsTest = [tTests.isdir];

% Ignore all directories that do not start with a plus, i.e. mark all
% entries that are not packages.
for iI = 1:length(tTests)
    if ~isequal(strfind(tTests(iI).name, '+'), 1)
        mbIsTest(iI) = false;
    end
end
% Now remove the non-package directories from the list.
tTests = tTests(mbIsTest);

% Generating a dynamic folder path so all of our saved data is nice and
% organized. The folder path will have the following format:
% Test/YYYYMMDD_Test_Run_X
% The number at the end ('X') will be automatically incremented so you
% don't have to worry about anything.
sFolderPath = createDataFolderPath();

% Check if there are changed files in the core or library folders since the
% last execution of this script. If yes, then all tests have to be
% executed again. If no, then we only have to run the tests that have
% changed. I've also included the files in the base directory with core.
bCoreChanged  = tools.fileChecker.checkForChanges('core', 'testVHAB');
bLibChanged   = tools.fileChecker.checkForChanges('lib', 'testVHAB');
bTestsChanged = tools.fileChecker.checkForChanges('user/+tests', 'testVHAB');
bVHABChanged  = checkVHABFile();

% Being a UI nerd, I needed to produce a nice dynamic user message here.

% Initializing a boolean array for each of the possibly changed folders and
% a cell containing their names.
abChanged = [false false false];
csWords = {'Core', 'Library', 'Tests'};

% We only need to do stuff if something changed at all.
if any([bCoreChanged, bVHABChanged, bLibChanged, bTestsChanged])
    % Global changed status
    bChanged = true;
    
    % Figuring out where the change(s) happened and setting the according
    % fields in the abChanged array to true.
    if bCoreChanged || bVHABChanged
        abChanged(1) = true;
    end
    
    if bLibChanged
        abChanged(2) = true;
    end
    
    if bTestsChanged
        abChanged(3) = true;
    end
    
    % Depending if one, two or all three changed we construct a
    % gramatically correct sentence.
    switch sum(abChanged)
        case 1
            sString = [csWords{abChanged}, ' has '];
        case 2
            csWords(~abChanged) = [];
            sString = [csWords{1}, ' and ', csWords{2}, ' have '];
        case 3
            sString = [csWords{1}, ', ', csWords{2}, ' and ', csWords{3}, ' have '];
    end
    
    % Now we can tell the user what's going on.
    fprintf('\n%schanged. All tests will be executed!\n\n', sString);
    
else
    bChanged = false;
    
    if bForceExecution
        fprintf('\nForced execution. All tests will be executed!\n\n');
    else
        fprintf('\nNothing has changed. No tests will be performed.\n\n');
    end
end

% If we run these using parallel execution, we need to add these fields
% outside of the function that is being executed on the parallel workers.
tTests = arrayfun(@(tStruct) tools.addFieldToStruct(tStruct,'run'), tTests);
tTests = arrayfun(@(tStruct) tools.addFieldToStruct(tStruct,'sStatus'), tTests);
tTests = arrayfun(@(tStruct) tools.addFieldToStruct(tStruct,'sErrorReport'), tTests);

% Getting the total number of tests.
iNumberOfTests = length(tTests);

% Obvioulsy, we only perform any simulations if something has changed in
% the code or if we are being forced to run.
if (bChanged || bForceExecution)
    
    % We're enclosing this in a try-catch block so if the user hasn't
    % installed the Parallel Computing Toolbox the function keeps
    % executing.
    try
        % In order to query the parallel pool of workers, we need to start
        % one. The gcp() function gets the current parallel pool or starts
        % a new one.
        oPool = gcp();
        
        % If starting the parallel pool worked, we set this boolean to true so
        % we can make decisions based on its value later on.
        bParallelExecution = true;
        
        % Now we can get the number of workers
        iNumberOfWorkers = oPool.NumWorkers;

    catch %#ok<CTCH>
        % We can't do parallel execution, so we set this to false.
        bParallelExecution = false;
        
    end
    
    % If we are running parallel simulations, we check if anything has changed
    % or if we are forced to execute.
    if bParallelExecution
        
        % Creating an empty array of pollable data queues so we can get
        % information from the workers and their simulations while they are
        % running.
        aoDataQueues = parallel.pool.DataQueue.empty(iNumberOfTests,0);
        aoResultObjects = parallel.FevalFuture.empty(iNumberOfTests,0);
        
        
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
        
        % Now we create a wait bar for each simulation. We do this here and
        % not within the for loop below so the user can see all simulations
        % at once and not just the ones that are currently running. 
        for iTest = 1:iNumberOfTests
            tools.multiWaitbar(tTests(iTest).name, 0);
        end
        
        % In order to steer the while loop within the for loop below, we
        % need these variables to keep track of which simulations are
        % currently running. 
        abActiveSimulations = false(iNumberOfTests,1);
        iActiveSimulations = 0;
        
        disp('Starting multiple simulations. Progess window may be in background.');
        
        % Looping through all tests and starting a simulation for each of them
        % using the parfeval() method.
        for iTest = 1:iNumberOfTests
            
            % If the user hit the stop button, bCancelled will be true.
            % This if condition here is to prevent another simulation from
            % being launched even after the user cancelled. 
            if ~bCancelled
                % To be able to receive data from the parallel workers in
                % the client, we need a data queue. We create this here for
                % every simulation. 
                aoDataQueues(iTest) = parallel.pool.DataQueue;
                
                % The afterEach() function will execute the timer function
                % after each transmission from the worker. There the send()
                % method is called with a payload of data which is passed
                % directly to the timer function by afterEach(). Here this
                % is used to update the waitbar for the individual
                % simulation.
                afterEach(aoDataQueues(iTest), oWaitBarTimer.TimerFcn);
                
                % Since we are in parallel execution mode we need to set a
                % key-value-pair in the ptParams containers.Map called
                % 'ParallelExecution' with the matter table object, the
                % data queue object and this simulations index within the
                % tTest struct as its values within a cell.
                ptParams = containers.Map({'ParallelExecution'}, {{oMT, aoDataQueues(iTest), iTest}});
                
                % Now we actually start the simulation on the parallel
                % worker. The parfeval() function takes the parallel pool
                % as the first input argument, followed by the function
                % that is to be executed on the worker. The following
                % arguments are the input arguments to the function to run.
                % In this case it is the runTest() function that is defined
                % below. 
                % parfeval() returns a parallel.FevalFuture object from
                % which the results of the parallel worker can be obtained.
                % These results are the return values of runTest().
                aoResultObjects(iTest) = parfeval(oPool, @runTest, 1, tTests(iTest), ptParams, sTestDirectory, sFolderPath, fSimTime, true, bDebugModeOn);
                
                % Now that the FevalFuture object hast been added to the
                % aoResultObjects array, we can update the callback of the
                % stop button to include the current version of this array.
                % This ensures that all simulations that are currently
                % running are properly aborted when the button is pressed. 
                oButton.Callback = { @stopAllSims, aoResultObjects };
                
                % In order to control the addition of new simulations to
                % the parallel pool, we need to keep track of how many
                % simulations are currently running, so we set the
                % following variables accordingly. 
                iActiveSimulations = iActiveSimulations + 1;
                abActiveSimulations(iTest) = true;
            end
            
            % The following while loop contains code that continuously
            % checks all simulations in the aoResultObjects array for their
            % status. If they are completed, we fetch their outputs and
            % delete their wait bar from the multiWaitbar window. The while
            % loop continues if there are any active simulations
            % (iActiveSimulations > 0) and if either the total number of
            % simulations equals the number of workers (iActiveSimulations
            % == iNumberOfWorkers) or the for loop in which we are running
            % this has reached the last entry (iTest == iNumberOfTests).
            % This logic ensures that the maximum number of simulations
            % that we try to execute in parallel is equal to the number of
            % workers. This is important, because if we try to add an
            % additional simulation via a call of perfeval() the code will
            % wait on that line until a worker is available. That means
            % that the code does not enter this while loop, so old
            % simulations are not detected and cleared out and
            % additionally, since it locks up the client, the wait bars are
            % not updated. 
            %NOTE: Initially I thought that the parallel pool would take 
            % care of this for me, but apparently it doesn't. This might be
            % a bug, but I have not taken the time yet to take it up with
            % Mathworks. 
            while iActiveSimulations && (iActiveSimulations == iNumberOfWorkers || iTest == iNumberOfTests)
                
                % First we get the indexes of the currently active
                % simulations.
                aiSimulationIndexes = find(abActiveSimulations);
                
                % Now we loop through all active simulations and check
                % their status. 
                for iSimulation = 1:length(aiSimulationIndexes)
                    % Getting the index of the current simulation within
                    % the aoResultObjects array.
                    iI = aiSimulationIndexes(iSimulation);
                    
                    % If this simulation's state is 'finished', we do
                    % stuff. It will be finished regardless of the
                    % simulation completing normally or crashing or being
                    % cancelled via the STOP button. If it is not finished,
                    % we don't have to do anything.
                    if strcmp(aoResultObjects(iI).State, 'finished')
                        % This simulation has completed, so we set the
                        % tracking variables accordingly.
                        abActiveSimulations(iI) = false;
                        iActiveSimulations = iActiveSimulations - 1;
                        
                        % If the simulation finished normally or crashed,
                        % we will be able to retreive the outputs from the
                        % parallel worker. If the simulation was cancelled,
                        % the results will not be accessible, so we enclose
                        % the following logic in a try catch block. 
                        try
                            tTests(iI) = fetchOutputs(aoResultObjects(iI));
                        catch %#ok<CTCH>
                            tTests(iI).sStatus = 'Cancelled';
                        end
                        
                        % No matter the reason, this simulation is done, so
                        % we can delete the wait bar for it. 
                        oWaitBarTimer.TimerFcn(iI);
                        
                    end
                end
            end
        end
        
        % All simulations have completed. So now we can close the window
        % that contains the STOP button and close the multibar. We need to
        % call this even if there are no more individual wait bars left,
        % because it will delete a persistent variable for the window
        % handle. This is important if this function is called again within
        % the same MATLAB session. 
        close(oFigure);
        tools.multiWaitbar('Close All');
        
        % If the user used the STOP button, we need to set the status of
        % the simulations that had not yet been started to 'Cancelled' as
        % well. 
        if bCancelled
            for iTest = 1:iNumberOfTests
                if isempty(tTests(iTest).sStatus)
                    tTests(iTest).sStatus = 'Cancelled';
                end
            end
        end
        
    else
        % We are running all tests in series, not parallel and something
        % has changed or we are forced to execute.
        
        % We need to pass this to the runTest() function, but only need it
        % for the parallel execution. So we just create an empty
        % containers.Map.
        ptParams = containers.Map();
        
        % Go through each item in the struct and see if we can execute a
        % V-HAB simulation.
        for iTest = 1:iNumberOfTests
            runTest(tTests(iTest), ptParams, sTestDirectory, sFolderPath, false, bDebugModeOn);
        end
    end
else
    % Nothing has changed and we are not being forced to execute, so there
    % is actually nothing more to do, so we return.
    return
    
end

% Saving the test data in the TestStatus.mat file
sPath = fullfile('data', 'TestStatus.mat');
save(sPath, 'tTests');

% Now that we're all finished, we can tell the user how well everything
% went.

% Also, because I am a teeny, tiny bit obsessive about visuals, I'm going
% to calculate how many blanks I have to insert between the colon and the
% actual status so they are nice and aligned.

% Initializing an array
aiNameLengths = zeros(1,length(tTests));

% Getting the lengths of each of the tutorial names. (Good thing we deleted
% the other, non-tutorial folders earlier...)
for iI = 1:length(tTests)
    aiNameLengths(iI) = length(tTests(iI).name);
end

% And now we can get the length of the longest tutorial name
iColumnWidth = max(aiNameLengths);

% Getting the number of successful, aborted and skipped tests from the
% struct.
iSuccessfulTests = sum(arrayfun(@(tArray) strcmp(tArray.sStatus, 'Successful'),tTests));
iAbortedTests    = sum(arrayfun(@(tArray) strcmp(tArray.sStatus, 'Aborted'),tTests));
iSkippedTests    = sum(arrayfun(@(tArray) strcmp(tArray.sStatus, 'Skipped'),tTests));
iCancelledTests  = sum(arrayfun(@(tArray) strcmp(tArray.sStatus, 'Cancelled'),tTests));

% Printing...
fprintf('\n\n======================================\n');
fprintf('============== Summary ===============\n');
fprintf('======================================\n\n');
fprintf('Total Tests:  %i\n\n', length(tTests));
fprintf('Successful:   %i\n',   iSuccessfulTests);
fprintf('Aborted:      %i\n',   iAbortedTests);
fprintf('Skipped:      %i\n',   iSkippedTests);
fprintf('Cancelled:    %i\n',   iCancelledTests);
disp('--------------------------------------');
disp('Detailed Summary:');
for iI = 1:length(tTests)
    % Every name should have at least two blanks of space between the colon
    % and the status, so we subtract the current name length from the
    % maximum name length and add two.
    iWhiteSpaceLength = iColumnWidth - length(tTests(iI).name) + 2;
    % Now we make ourselves a string of blanks of the appropriate length
    % that we can insert into the output in the following line.
    sBlanks = blanks(iWhiteSpaceLength);
    % Tada!
    fprintf('%s:%s%s\n',strrep(tTests(iI).name,'+',''),sBlanks,tTests(iI).sStatus);
end
fprintf('--------------------------------------\n\n');

% Now we print out the error messages from the tutorials that were aborted
% if there were any.
mbHasAborted = strcmp({tTests.sStatus}, 'Aborted');
if any(mbHasAborted)
    fprintf('=======================================\n');
    fprintf('=========== Error messages ============\n');
    fprintf('=======================================\n\n');
    iErrorCounter = sum(mbHasAborted);
    tAbortedTutorial = tTests(mbHasAborted);
    for iAbortedTests = 1:iErrorCounter
        fprintf('=> %s Test Error Message:\n\n',strrep(tAbortedTutorial(iAbortedTests).name,'+',''));
        fprintf(2, '%s\n\n',tAbortedTutorial(iAbortedTests).sErrorReport);
        fprintf('--------------------------------------\n\n\n');
    end
end

% Depending on what was selected, we now try to compare the current
% simulation result to a past one, either from the data on the server or
% our local copy.
if strcmp(sCompareToState, 'server')
    try
        tOldTests = load(strrep('user\+tests\ServerTestStatus.mat','\',filesep));
    catch Msg
        if strcmp(Msg.identifier, 'MATLAB:load:couldNotReadFile')
            % if the file does not exists we inform the user that something
            % went wrong
            error('TestVHAB:FileNotFound','The file user\+tests\ServerTestStatus.mat does not exist. Please check if you accidentially deleted it and if so revert that change.')
        else
            rethrow(Msg)
        end
    end
else
    try
        tOldTests = load(strrep('data\OldTestStatus.mat','\',filesep));
    catch Msg
        if strcmp(Msg.identifier, 'MATLAB:load:couldNotReadFile')
            % if the file not yet exists, we create it!
            sPath = fullfile('data', 'OldTestStatus.mat');
            save(sPath, 'tTests');
            % Since there are no data to make comparisons to, we have to
            % set the bChanged variable back to false in order to skip the
            % code blocks below.
            bChanged = false;
            warning('VHAB:testVHAB',['There was no OldTestStatus.mat file, so we created it using the current test data. No comparisons\n',...
                'can be made at this time. You can select ''server'' as the first input argument to this function\n',...
                'to compare your results to the server state.']);
        else
            rethrow(Msg)
        end
    end
end

% If there were changes and we performed simulations and we have data to
% make comparisons, we make them now an display them to the user.
if ( bChanged || bForceExecution )
    fprintf('=======================================\n');
    fprintf('=== Time and Mass Error Comparisons ===\n');
    fprintf('=======================================\n\n');
    fprintf('Comparisons are new values - old values!\n');
    fprintf('--------------------------------------\n');
    
    % Initializing a data matrix so we can plot the data.
    mfData = zeros(iNumberOfTests, 5);
    
    % Looping through all tests and displaying the results of the
    % comparisons in the console.
    for iI = 1:iNumberOfTests
        fprintf('%s:\n', strrep(tTests(iI).name,'+',''));
        
        % The order in which the tests are listed in both structs may be
        % different, so we also loop through all tests in the tOldTests
        % struct and compare the simulation object names. If they don't
        % match, then a new test has been added.
        for iOldTest = 1:length(tOldTests.tTests)
            % Check if the name of the old tutorial matches the new tutorial,
            % if it does, compare the tutorials
            if strcmp(tTests(iI).name, tOldTests.tTests(iOldTest).name) && ~isempty(tTests(iI).run) && ~isempty(tOldTests.tTests(iOldTest).run)
                
                iTickDiff = tTests(iI).run.iTicks - tOldTests.tTests(iOldTest).run.iTicks;
                mfData(iI,1) = iTickDiff;
                fprintf('change in ticks compared to old status:               %i\n', iTickDiff);
                
                fTimeDiff = tTests(iI).run.fRunTime - tOldTests.tTests(iOldTest).run.fRunTime;
                mfData(iI,2) = fTimeDiff;
                fprintf('change in run time compared to old status:            %d\n', fTimeDiff);
                
                fTimeDiffLog = tTests(iI).run.fLogTime - tOldTests.tTests(iOldTest).run.fLogTime;
                mfData(iI,3) = fTimeDiffLog;
                fprintf('change in log time compared to old status:            %d\n', fTimeDiffLog);
                
                fGeneratedMassDiff = tTests(iI).run.fGeneratedMass - tOldTests.tTests(iOldTest).run.fGeneratedMass;
                mfData(iI,4) = fGeneratedMassDiff;
                fprintf('change in generated mass compared to old status:      %d\n', fGeneratedMassDiff);
                
                fTotalMassBalanceDiff = tTests(iI).run.fTotalMassBalance - tOldTests.tTests(iOldTest).run.fTotalMassBalance;
                mfData(iI,5) = fTotalMassBalanceDiff;
                fprintf('change in total mass balance compared to old status:  %d\n', fTotalMassBalanceDiff);
            end
        end
        fprintf('--------------------------------------\n');
    end
    fprintf('--------------------------------------\n');
    fprintf('--------------------------------------\n\n\n');
    
    % Plotting the data
    plot(mfData, cellfun(@(cCell) cCell(2:end), {tTests.name}, 'UniformOutput', false));
end

fprintf('======================================\n');
fprintf('======= Finished running tests =======\n');
fprintf('======================================\n\n');

% Outputting the total runtime.
disp('Total elapsed time:');
disp(tools.secs2hms(toc(hTimer)));


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
            tools.multiWaitbar(tTests(xInput(1)).name, xInput(2));
        catch %#ok<CTCH>
            tools.multiWaitbar(tTests(xInput(1)).name, 'Close');
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

function plot(mfData, csNames)
% Creating a figure
oFigure = figure('Name','Comparisons');

% First we create the panel that will house the buttons.
fPanelYSize = 0.12;
fPanelXSize = 0.065;
oPanel = uipanel('Title','Undock Subplots','FontSize',10,'Position',[ 0 0 fPanelXSize fPanelYSize]);

% Since the user may want to save the entire figure to a file, we
% create a save button above the panel.
oButton = uicontrol(oFigure,'String','Save Figure','FontSize',10,'Units','normalized','Position',[ 0 fPanelYSize fPanelXSize 0.03]);
oButton.Callback = @tools.postprocessing.plotter.helper.saveFigureAs;

iRows = 2;
iColumns = 3;
iNumberOfPlots = 5;

% Doing some math so we get nicely proportioned buttons. The basic
% idea behind all of it is that the panel is arbitrarily divided
% into 16 equal units and the button sizes and the gaps between
% them are sized accordingly. First we set the outer dimensions of
% the buttons.
fButtonYSize = (14 - (iRows    - 1)) / iRows    / 16;
fButtonXSize = (14 - (iColumns - 1)) / iColumns / 16;

% The buttons shall be 1/16th of the panel width and heigth apart,
% so when calculating the spaceing between the button center
% coordinates we have to add that to the button size.
fHorizontalSpaceing = fButtonXSize + 1/16;
fVerticalSpaceing   = fButtonYSize + 1/16;

% Creating the horizontal coordinates
afHorizontal = ( 0:fHorizontalSpaceing:1 ) - fButtonXSize;
afHorizontal = afHorizontal(2:end);

% Creating the vertical coordinates, we need to flip that array
% because the MATLAB coordinate system has its origin in the bottom
% left corner, but when arranging the buttons in the same position
% as the plots, the first button is in the top left corner of the
% panel.
afVertical = ( 0:fVerticalSpaceing:1 ) - fButtonYSize;
afVertical = afVertical(2:end);
afVertical = fliplr(afVertical);


% Initializing some variables. The coButtons cell will contain
% references to each button object. These will be used later on to
% attach a plot specific callback function to each button.
coButtons = cell(iRows,iColumns);
iSubPlotCounter = 1;

% Creating the array of buttons according to the number of subplots
% there are and labling them with simple numbers.
for iI = 1:iRows
    for iJ = 1:iColumns
        % Since it can be the case, that some of the entries in
        % coPlots are empty, we need to check if there are plots
        % left to create buttons for.
        if iSubPlotCounter <= iNumberOfPlots
            % Creating a button with a single number as its label.
            oButton = uicontrol(oPanel,'String',sprintf('%i', iSubPlotCounter));
            
            % Positioning and sizing the button according to the
            % coordinates we calculated above. These are in
            % relative coordinates, so we first have to set the
            % button units to 'normalized'.
            oButton.Units = 'normalized';
            oButton.Position = [afHorizontal(iJ) afVertical(iI) fButtonXSize fButtonYSize];
            
            % Adding a reference to the button we just created to
            % the coButtons cell.
            coButtons{iI, iJ} = oButton;
            
            % Incrementing the plot counter.
            iSubPlotCounter = iSubPlotCounter + 1;
        end
    end
end

% Now we create the five individual subplots.

oPlot = subplot(2,3,1);
hold(oPlot,'on');
oBars = bar(mfData(:,1));
if ~verLessThan('MATLAB','9.7')
    oBars.DataTipTemplate.DataTipRows(1) = dataTipTextRow('Test',csNames);
    oBars.DataTipTemplate.Interpreter = 'none';
    oBars.DataTipTemplate.DataTipRows(2).Label = 'Ticks';
end
title('Ticks');
coButtons{1, 1}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

oPlot = subplot(2,3,2);
hold(oPlot,'on');
oBars = bar(mfData(:,2));
if ~verLessThan('MATLAB','9.7')
    oBars.DataTipTemplate.DataTipRows(1) = dataTipTextRow('Test',csNames);
    oBars.DataTipTemplate.Interpreter = 'none';
    oBars.DataTipTemplate.DataTipRows(2).Label = 'Seconds';
end
title('Time');
ylabel('Simulation Time [s]');
coButtons{1, 2}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

oPlot = subplot(2,3,3);
hold(oPlot,'on');
oBars = bar(mfData(:,3));
if ~verLessThan('MATLAB','9.7')
    oBars.DataTipTemplate.DataTipRows(1) = dataTipTextRow('Test',csNames);
    oBars.DataTipTemplate.Interpreter = 'none';
    oBars.DataTipTemplate.DataTipRows(2).Label = 'Seconds';
end
title('Logging');
ylabel('Logging Time [s]');
coButtons{1, 3}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

oPlot = subplot(2,3,4);
hold(oPlot,'on');
oBars = bar(mfData(:,4));
if ~verLessThan('MATLAB','9.7')
    oBars.DataTipTemplate.DataTipRows(1) = dataTipTextRow('Test',csNames);
    oBars.DataTipTemplate.Interpreter = 'none';
    oBars.DataTipTemplate.DataTipRows(2).Label = 'kg';
end
title('Generated Mass');
ylabel('Mass [kg]');
coButtons{2, 1}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

oPlot = subplot(2,3,5);
hold(oPlot,'on');
oBars = bar(mfData(:,5));
if ~verLessThan('MATLAB','9.7')
    oBars.DataTipTemplate.DataTipRows(1) = dataTipTextRow('Test',csNames);
    oBars.DataTipTemplate.Interpreter = 'none';
    oBars.DataTipTemplate.DataTipRows(2).Label = 'kg';
end
title('Mass balance');
ylabel('Mass [kg]');
coButtons{2, 2}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

% In the sixth field of the 2x3 figure, we create a sort of legend. This is
% done because MATLAB 2019a does not support custom data tips for
% each bar in a bar graph. That makes it hard to see, which test is
% actually represented by each bar, because it only has a number. The
% legend we are creating here links the number to the name of the test.
if verLessThan('MATLAB','9.7')
    % First creating the plot itself
    oPlot = subplot(2,3,6);
    hold(oPlot,'on');
    oPlot.YTick = [];
    oPlot.XTick = [];
    oPlot.Box = 'on';
    oPlot.Tag = 'LabelPlot';
    title('Legend');
    
    % Now we create a textfield that contains concatenations of each test's
    % index in the csNames cell and their name.
    csContent = cellfun(@(csNumbers, csText) [csNumbers, ' ', csText], strsplit(num2str(1:length(csNames))), csNames, 'UniformOutput', false);
    oText = text(oPlot, 0.1, 0.1, csContent);
    oText.Interpreter = 'none';
    
    % We want to have the text field nice and centered in the plot, so we
    % have a function for this. We call it here once initially and then
    % bind it to the figure's size changed callback so it is executed
    % everytime the window, and thereby the subplot, is resized.
    resizeTextField(oFigure, []);
    oFigure.SizeChangedFcn = @resizeTextField;
end

% Maximize the figure window to fill the whole screen.
set(oFigure, 'WindowState', 'maximized');

end

function resizeTextField(oFigure, ~)
% Finding the plot containing the legend
oPlot = findobj(oFigure, 'Tag', 'LabelPlot');

% Setting its position to the center of the subplot.
oPlot.Children(1).Position = [ (1-oPlot.Children(1).Extent(3))/2, 0.5 0];
end

function sFolderPath = createDataFolderPath()
%createDataFolderPath  Generate a name for a folder in 'data/'

% Initializing the variables
bSuccess      = false;
iFolderNumber = 1;

% Getting the current date for use in the folder name
sTimeStamp  = datestr(now(), 'yyyymmdd');

% Generating the base folder path for all figures
sBaseFolderPath = fullfile('data', 'figures', 'Test');

% We want to give the folder a number that doesn't exist yet. So we
% start at 1 and work our way up until we find one that's not there
% yet.
while ~bSuccess
    sFolderPath = fullfile(sBaseFolderPath, sprintf('%s_Test_Run_%i', sTimeStamp, iFolderNumber));
    if exist(sFolderPath,'dir')
        iFolderNumber = iFolderNumber + 1;
    else
        bSuccess = true;
    end
end
end

function bChanged = checkVHABFile()
% Since we can't call this function from outside the V-HAB base
% folder and this function would then catalog the entire directory,
% we'll add a virtual folder here so we can still check the few files
% in the top level V-HAB folder.

% This is mainly just to save some space in the following code, but it
% also defines the file name we will use to store the tSavedInfo
% struct.
sSavePath  = strrep('data/FolderStatusFortestVHAB.mat','/',filesep);

bChanged = false;
tInfo = dir();
tInfo = tools.fileChecker.removeIllegalFilesAndFolders(tInfo);
tSavedInfo = struct();
try
    load(sSavePath,'tSavedInfo');
catch oError
    if ~strcmp(oError.identifier, 'MATLAB:load:couldNotReadFile')
        rethrow(oError);
    end
end


for iI = 1:length(tInfo)
    if ~tInfo(iI).isdir
        sFileName = tools.normalizePath(tInfo(iI).name);
        if isfield(tSavedInfo,sFileName)
            if tSavedInfo.(sFileName) < tInfo(iI).datenum
                tSavedInfo.(sFileName) = tInfo(iI).datenum;
                save(sSavePath,'tSavedInfo');
                bChanged = true;
            end
        else
            % The item we're looking at is a file, so we'll cleanup the
            % file name and create a new item in the struct in which we
            % can save the changed date for this file.
            tSavedInfo.(sFileName) = tInfo(iI).datenum;
            save(sSavePath,'tSavedInfo');
            bChanged = true;
        end
    end
end
end

function tTest = runTest(tTest, ptParams, sTestDirectory, sFolderPath, fSimTime, bParallelExecution, bDebugModeOn)
% This function creates one V-HAB simulation, runs it and returns an
% updated tTest struct. It can be used for both parallel and serial
% execution of tests, the key here is the value of the bParallelExecution
% input argument. 

% If the folder has a correctly named 'setup.m' file, we can go ahead and
% try to execute it.
if exist(fullfile(sTestDirectory, tTest.name, 'setup.m'), 'file')
    
    % First we construct the string that is the argument for the
    % vhab.exec() method.
    sExecString = ['tests.',strrep(tTest.name,'+',''),'.setup'];
    
    % Now we can finally run the simulation, but we need to catch any
    % errors inside the simulation itself
    try
        % Creating the simulation object.
        oLastSimObj = vhab.sim(sExecString, ptParams, [], [], fSimTime);
        
        % In case the user wants to run the simulations with the debug mode
        % activated, we toggle that switch now.
        if bDebugModeOn
            oLastSimObj.oDebug.toggleOutputState();
        end
        
        % Actually running the simulation
        oLastSimObj.run();
        
%         % Done! Let's plot stuff!
%         oLastSimObj.plot();
%         
%         % If we are running in parallel, we need to jump through some hoops
%         % to get the figures saved. The plotter knows that it is being run
%         % on a parallel worker, so it has created the aoFigures array in
%         % the base workspace of the worker. So here, if we are running in
%         % parallel, we pull this variable from the base workspace into our
%         % local workspace to save it. If we are running in series, then we
%         % just set it to empty; the saveFigures() function knows how to
%         % deal with that. 
%         if bParallelExecution
%             aoFigures = evalin('base', 'aoFigures');
%         else
%             aoFigures = [];
%         end
%         
%         % Saving the figures to the pre-determined location
%         tools.saveFigures(sFolderPath, strrep(tTest.name,'+',''), aoFigures);
%         
%         % Closing all windows so we can see the console again. The
%         % drawnow() call is necessary, because otherwise MATLAB would just
%         % jump over the close('all') instruction and run the next sim.
%         % Stupid behavior, but this is the workaround. We only need to do
%         % this when running in series, because then the windows are
%         % not visible on the parallel workers anyway.
%         if ~bParallelExecution
%             close('all');
%             drawnow();
%         end
        
        % Store information about the simulation duration and errors. This
        % will be saved later on to allow a comparison between different
        % versions of V-HAB
        tTest.run.iTicks            = oLastSimObj.oSimulationContainer.oTimer.iTick;
        tTest.run.fRunTime          = oLastSimObj.toMonitors.oExecutionControl.oSimulationInfrastructure.fRuntimeTick;
        tTest.run.fLogTime          = oLastSimObj.toMonitors.oExecutionControl.oSimulationInfrastructure.fRuntimeOther;
        tTest.run.fGeneratedMass    = oLastSimObj.toMonitors.oMatterObserver.fGeneratedMass;
        tTest.run.fTotalMassBalance = oLastSimObj.toMonitors.oMatterObserver.fTotalMassBalance;
        
        % Since we've now actually completed the simulation we can set the
        % string property for the final output.
        tTest.sStatus = 'Successful';
    catch oException
        % Something went wrong inside the simulation. So we tell the user
        % and keep going. The string property for the final output is set
        % accordingly.
        fprintf('\nEncountered an error in the simulation. Aborting.\n');
        tTest.sStatus = 'Aborted';
        tTest.sErrorReport = getReport(oException);
    end
    
else
    % In case there is no 'setup.m' file, we print this to the command
    % window, but we don't stop the skript and we just set the struct field
    % and leave.
    disp(['The ',strrep(tTests(iI).name,'+',''),' Tutorial does not have a ''setup.m'' file. Skipping.']);
    tTest.sStatus = 'Skipped';
end

end