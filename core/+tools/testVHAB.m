function testVHAB()
%TESTVHAB Runs all tests and saves the figures to a folder
%   This function is a debugging helper. It will run all tests inside
%   the user/+tests folder and save the resulting figures to
%   data/Testrun/ with a timestamp. The only condition for this
%   to work is that the class file that inherits from simulation.m is on
%   the top level of the tutorial folder and is called 'setup.m'. If this
%   is not the case, the function will throw an error. 

% Initializing some counters
iSuccessfulTests = 0;
iSkippedTests    = 0;
iAbortedTests    = 0;

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

abChanged = [false false false];
if any([bCoreChanged, bVHABChanged, bLibChanged, bTestsChanged])
    bChanged = true;

    if bCoreChanged || bVHABChanged
        abChanged(1) = true;
    end
    
    if bLibChanged
        abChanged(2) = true;
    end
    
    if bTestsChanged
        abChanged(3) = true;
    end
    
    csWords = {'Core', 'Library', 'Tests'};
    
    switch sum(abChanged)
        case 1
            sString = [csWords{abChanged}, ' has '];
        case 2
            csWords(~abChanged) = [];
            sString = [csWords{1}, ' and ', csWords{2}, ' have '];
        case 3
            sString = [csWords{1}, ', ', csWords{2}, ' and ', csWords{3}, ' have '];
    end
    
    fprintf('\n%schanged. All tests will be executed!\n\n', sString);
else
    bChanged = false;
    fprintf('\nNothing has changed. No tests will be performed.\n\n');
end

% Only do stuff if we need to
if bChanged
    % Go through each item in the struct and see if we can execute a
    % V-HAB simulation.
    for iI = 1:length(tTests)
        % Some nice printing for the console output
        fprintf('\n\n======================================\n');
        fprintf('Running %s Test\n',strrep(tTests(iI).name,'+',''));
        fprintf('======================================\n\n');
        
        % If the folder has a correctly named 'setup.m' file, we can go
        % ahead and try to execute it.
        if exist(fullfile(sTestDirectory, tTests(iI).name, 'setup.m'), 'file')
            
            % First we construct the string that is the argument for the
            % vhab.exec() method.
            sExecString = ['tests.',strrep(tTests(iI).name,'+',''),'.setup'];
            
            % Now we can finally run the simulation, but we need to catch
            % any errors inside the simulation itself
            try
                oLastSimObj = vhab.exec(sExecString);
                
                % Done! Let's plot stuff!
                oLastSimObj.plot();
                
                % Saving the figures to the pre-determined location
                tools.saveFigures(sFolderPath, strrep(tTests(iI).name,'+',''));
                
                % Closing all windows so we can see the console again. The
                % drawnow() call is necessary, because otherwise MATLAB would
                % just jump over the close('all') instruction and run the next
                % sim. Stupid behavior, but this is the workaround.
                close('all');
                drawnow();
                
                % Store information about the simulation duration and
                % errors. This will be saved later on to allow a comparison
                % between different version of V-HAB
                tTests(iI).run.iTicks               = oLastSimObj.oSimulationContainer.oTimer.iTick;
                tTests(iI).run.fRunTime             = oLastSimObj.toMonitors.oExecutionControl.oSimulationInfrastructure.fRuntimeTick;
                tTests(iI).run.fLogTime             = oLastSimObj.toMonitors.oExecutionControl.oSimulationInfrastructure.fRuntimeOther;
                tTests(iI).run.fGeneratedMass       = oLastSimObj.toMonitors.oMatterObserver.fGeneratedMass;
                tTests(iI).run.fTotalMassBalance    = oLastSimObj.toMonitors.oMatterObserver.fTotalMassBalance;
                
                % Since we've now actually completed the simulation, we can
                % increment the counter of successful tutorials. Also we
                % can set the string property for the final output.
                iSuccessfulTests = iSuccessfulTests + 1;
                tTests(iI).sStatus = 'Successful';
            catch oException
                % Something went wrong inside the simulation. So we tell
                % the user and keep going. The counter for aborted
                % tutorials is incremented and the string property for the
                % final output is set accordingly.
                fprintf('\nEncountered an error in the simulation. Aborting.\n');
                iAbortedTests = iAbortedTests + 1;
                tTests(iI).sStatus = 'Aborted';
                tTests(iI).sErrorReport = getReport(oException);
            end
            
        else
            % In case there is no 'setup.m' file, we print this to the
            % command window, but we don't stop the skript. We increment
            % the skipped-counter and set the property.
            disp(['The ',strrep(tTests(iI).name,'+',''),' Tutorial does not have a ''setup.m'' file. Skipping.']);
            iSkippedTests = iSkippedTests + 1;
            tTests(iI).sStatus = 'Skipped';
        end
        
    end
    
end

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

% Printing...
fprintf('\n\n======================================\n');
fprintf('============== Summary ===============\n');
fprintf('======================================\n\n');
fprintf('Total Tests:  %i\n\n', length(tTests));
fprintf('Successful:   %i\n',   iSuccessfulTests);
fprintf('Aborted:      %i\n',   iAbortedTests);
fprintf('Skipped:      %i\n',   iSkippedTests);
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

bSkipComparison = false;
try
    tOldTests = load('data\OldTestStatus.mat');
catch Msg
    if strcmp(Msg.identifier, 'MATLAB:load:couldNotReadFile')
        % if the file not yet exists, we create it!
        sPath = fullfile('data', 'OldTestStatus.mat');
        save(sPath, 'tTests');
        bSkipComparison = true;
    else
        rethrow(Msg)
    end
end

if ~bSkipComparison
    fprintf('=======================================\n');
    fprintf('=== Time and Mass Error Comparisons ===\n');
    fprintf('=======================================\n\n');
    fprintf('Comparisons are new values - old values!\n');
    fprintf('--------------------------------------\n');
    for iI = 1:length(tTests)
        fprintf('%s:\n', strrep(tTests(iI).name,'+',''));

        for iOldTutorial = 1:length(tOldTests.tTests)
            % check if the name of the old tutorial matches the new tutorial,
            % if it does, compare the tutorials
            if strcmp(tTests(iI).name, tOldTests.tTests(iOldTutorial).name)

                iTickDiff = tTests(iI).run.iTicks - tOldTests.tTests(iOldTutorial).run.iTicks;
                fprintf('change in ticks compared to old status:                 %s%i\n',sBlanks, iTickDiff);
                
                fTimeDiff = tTests(iI).run.fRunTime - tOldTests.tTests(iOldTutorial).run.fRunTime;
                fprintf('change in run time compared to old status:                  %s%d\n',sBlanks, fTimeDiff);

                fTimeDiffLog = tTests(iI).run.fLogTime - tOldTests.tTests(iOldTutorial).run.fLogTime;
                fprintf('change in log time compared to old status:                  %s%d\n',sBlanks, fTimeDiffLog);
                
                fGeneratedMassDiff = tTests(iI).run.fGeneratedMass - tOldTests.tTests(iOldTutorial).run.fGeneratedMass;
                fprintf('change in generated mass compared to old status:        %s%d\n',sBlanks, fGeneratedMassDiff);

                fTotalMassBalanceDiff = tTests(iI).run.fTotalMassBalance - tOldTests.tTests(iOldTutorial).run.fTotalMassBalance;
                fprintf('change in total mass balance compared to old status:    %s%d\n',sBlanks, fTotalMassBalanceDiff);
            end
        end
        fprintf('--------------------------------------\n');
    end
    fprintf('--------------------------------------\n');
    fprintf('--------------------------------------\n\n\n');

    sPath = fullfile('data', 'TestStatus.mat');
    save(sPath, 'tTests');
end

fprintf('======================================\n');
fprintf('===== Finished running tests =====\n');
fprintf('======================================\n\n');

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
        if exist([sBaseFolderPath, sFolderPath],'dir')
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
