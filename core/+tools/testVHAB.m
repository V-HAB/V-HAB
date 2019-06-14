function testVHAB(sCompareToState, bForceExecution)
%TESTVHAB Runs all tests and saves the figures to a folder
%   This function is a debugging helper. It will run all tests inside
%   the user/+tests folder and save the resulting figures to
%   data/Testrun/ with a timestamp. The only condition for this
%   to work is that the class file that inherits from simulation.m is on
%   the top level of the tutorial folder and is called 'setup.m'. If this
%   is not the case, the function will throw an error. 
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

if nargin < 1
    sCompareToState = 'server';
else
    if  ~(strcmp(sCompareToState, 'server') ||  strcmp(sCompareToState, 'local'))
        error('Unknown state to which the testVHAB run should be compared')
    end
end

if nargin < 2
    bForceExecution = false;
end

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
if bChanged || bForceExecution
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
    
else
    for iI = 1:length(tTests)
        tTests(iI).sStatus = 'Not performed';
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
if strcmp(sCompareToState, 'server')
    try
        tOldTests = load(strrep('user\+tests\ServerTestStatus.mat','\',filesep));
    catch Msg
        if strcmp(Msg.identifier, 'MATLAB:load:couldNotReadFile')
            % if the file does not exists we inform the user that something
            % went wrong
            error('The file user\+tests\ServerTestStatus.mat does not exist. Please check if you accidentially deleted it and if so revert that change.')
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
            bSkipComparison = true;
        else
            rethrow(Msg)
        end
    end
end

if ~bSkipComparison
    fprintf('=======================================\n');
    fprintf('=== Time and Mass Error Comparisons ===\n');
    fprintf('=======================================\n\n');
    fprintf('Comparisons are new values - old values!\n');
    fprintf('--------------------------------------\n');
    
    iLength = length(tTests);
    
    mfData = zeros(iLength, 5);
    
    for iI = 1:iLength
        fprintf('%s:\n', strrep(tTests(iI).name,'+',''));

        for iOldTutorial = 1:length(tOldTests.tTests)
            % check if the name of the old tutorial matches the new tutorial,
            % if it does, compare the tutorials
            if strcmp(tTests(iI).name, tOldTests.tTests(iOldTutorial).name)

                iTickDiff = tTests(iI).run.iTicks - tOldTests.tTests(iOldTutorial).run.iTicks;
                mfData(iI,1) = iTickDiff;
                fprintf('change in ticks compared to old status:                 %s%i\n',sBlanks, iTickDiff);
                
                fTimeDiff = tTests(iI).run.fRunTime - tOldTests.tTests(iOldTutorial).run.fRunTime;
                mfData(iI,2) = fTimeDiff;
                fprintf('change in run time compared to old status:                  %s%d\n',sBlanks, fTimeDiff);

                fTimeDiffLog = tTests(iI).run.fLogTime - tOldTests.tTests(iOldTutorial).run.fLogTime;
                mfData(iI,3) = fTimeDiffLog;
                fprintf('change in log time compared to old status:                  %s%d\n',sBlanks, fTimeDiffLog);
                
                fGeneratedMassDiff = tTests(iI).run.fGeneratedMass - tOldTests.tTests(iOldTutorial).run.fGeneratedMass;
                mfData(iI,4) = fGeneratedMassDiff;
                fprintf('change in generated mass compared to old status:        %s%d\n',sBlanks, fGeneratedMassDiff);

                fTotalMassBalanceDiff = tTests(iI).run.fTotalMassBalance - tOldTests.tTests(iOldTutorial).run.fTotalMassBalance;
                mfData(iI,5) = fTotalMassBalanceDiff;
                fprintf('change in total mass balance compared to old status:    %s%d\n',sBlanks, fTotalMassBalanceDiff);
                
            end
        end
        fprintf('--------------------------------------\n');
    end
    fprintf('--------------------------------------\n');
    fprintf('--------------------------------------\n\n\n');
    
    plot(mfData, cellfun(@(cCell) cCell(2:end), {tTests.name}, 'UniformOutput', false));
    
    sPath = fullfile('data', 'TestStatus.mat');
    save(sPath, 'tTests');
end

fprintf('======================================\n');
fprintf('===== Finished running tests =====\n');
fprintf('======================================\n\n');

end

function plot(mfData, csNames)

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


oPlot = subplot(2,3,1);
hold(oPlot,'on');
oBars = bar(mfData(:,1)); %#ok<NASGU>
% This is currently unsupported by MATLAB. The feature was only added in
% 2019a, so hopefully it will be extended to bar plots in the future. For
% now, we need to add a legend at the end.
%oBars.DataTipTemplate.DataTipRows = dataTipTextRow('Test',csNames);
title('Ticks');
coButtons{1, 1}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

oPlot = subplot(2,3,2);
hold(oPlot,'on');
oBars = bar(mfData(:,2)); %#ok<NASGU>
%oBars.DataTipTemplate.DataTipRows = dataTipTextRow('Test',csNames);
title('Time');
ylabel('Simulation Time [s]');
coButtons{1, 2}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

oPlot = subplot(2,3,3);
hold(oPlot,'on');
oBars = bar(mfData(:,3)); %#ok<NASGU>
%oBars.DataTipTemplate.DataTipRows = dataTipTextRow('Test',csNames);
title('Logging');
ylabel('Logging Time [s]');
coButtons{1, 3}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

oPlot = subplot(2,3,4);
hold(oPlot,'on');
oBars = bar(mfData(:,4)); %#ok<NASGU>
%oBars.DataTipTemplate.DataTipRows = dataTipTextRow('Test',csNames);
title('Generated Mass');
ylabel('Mass [kg]');
coButtons{2, 1}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

oPlot = subplot(2,3,5);
hold(oPlot,'on');
oBars = bar(mfData(:,5)); %#ok<NASGU>
%oBars.DataTipTemplate.DataTipRows = dataTipTextRow('Test',csNames);
title('Mass balance');
ylabel('Mass [kg]');
coButtons{2, 2}.Callback = {@tools.postprocessing.plotter.helper.undockSubPlot, oPlot, []};

oPlot = subplot(2,3,6);
hold(oPlot,'on');
oPlot.YTick = [];
oPlot.XTick = [];
oPlot.Box = 'on';
oPlot.Tag = 'LabelPlot';
title('Legend');

csContent = cellfun(@(csNumbers, csText) [csNumbers, ' ', csText], strsplit(num2str(1:length(csNames))), csNames, 'UniformOutput', false);
oText = text(oPlot, 0.1, 0.1, csContent);
oText.Interpreter = 'none';
resizeTextField(oFigure, []);
oFigure.SizeChangedFcn = @resizeTextField;

% Maximize the figure window to fill the whole screen.
set(oFigure, 'WindowState', 'maximized');

end

function resizeTextField(oFigure, ~)
    oPlot = findobj(oFigure, 'Tag', 'LabelPlot');
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
