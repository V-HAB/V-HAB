function runAllTutorials()
%RUNALLTUTORIALS Runs all tutorials and saves the figures to a folder
%   This function is a debugging helper. It will run all tutorials inside
%   the user/+tutorials folder and save the resulting figures to
%   data/Tutorials_Testrun/ with a timestamp. The only condition for this
%   to work is that the class file that inherits from simulation.m is on
%   the top level of the tutorial folder and is called 'setup.m'. If this
%   is not the case, the function will throw an error. 

% Initializing some counters
iSuccessfulTutorials = 0;
iSkippedTutorials    = 0;
iAbortedTutorials    = 0;

% First we get the struct that shows us the current contents of the
% tutorials directory. We also check which entries are directories.
sTutorialDirectory = fullfile('user', '+tutorials');
tTutorials   = dir(sTutorialDirectory);
mbIsTutorial = [tTutorials.isdir];

% Ignore all directories that do not start with a plus, i.e. mark all
% entries that are not packages.
for iI = 1:length(tTutorials)
    if ~isequal(strfind(tTutorials(iI).name, '+'), 1)
        mbIsTutorial(iI) = false;
    end
end
% Now remove the non-package directories from the list.
tTutorials = tTutorials(mbIsTutorial);

% Generating a dynamic folder path so all of our saved data is nice and
% organized. The folder path will have the following format: 
% Tutorials_Test/YYYYMMDD_Test_Run_X 
% The number at the end ('X') will be automatically incremented so you
% don't have to worry about anything.
sFolderPath = createDataFolderPath();

% Check if there are changed files in the core or library folders since the
% last execution of this script. If yes, then all tutorials have to be
% executed again. If no, then we only have to run the tutorials that have
% changed. I've also included the files in the base directory with core.
bCoreChanged = tools.checkForChanges('core');
bLibChanged  = tools.checkForChanges('lib');
%TODO: only |vhab.m| should ever be of interest, so handle it separately
bVHABChanged = checkVHABFiles();

% Being a UI nerd, I needed to produce a nice dynamic user message here. 
if any([bCoreChanged bLibChanged])
    if bCoreChanged || bVHABChanged
        sCore = 'Core ';
    else
        sCore = '';
        sConjunction = '';
        sVerb = 'has ';
    end
    
    if bLibChanged
        sLib = 'Library ';
    else
        sLib = '';
        sConjunction = '';
        sVerb = 'has ';
    end
    
    if (bCoreChanged || bVHABChanged) && bLibChanged
        sConjunction = 'and ';
        sVerb = 'have ';
    end
    
    fprintf('\n%s%s%s%schanged. All tutorials will be executed!\n\n', sCore, sConjunction, sLib, sVerb);
else
    fprintf('\nCore and Library are both unchanged. Proceeding with tutorial execution.\n\n');
end

% Go through each item in the struct and see if we can execute a
% V-HAB simulation. 
for iI = 1:length(tTutorials)
    % Check if the tutorial's files have changed since the last execution 
    % of this script. If not, we can just skip this one, because we already
    % know it works. Unless of course the core or the library has changed.
    % In this case, all tutorials will be executed.
    if tools.checkForChanges(fullfile(sTutorialDirectory, tTutorials(iI).name)) || bLibChanged || bCoreChanged
        
        % Some nice printing for the console output
        fprintf('\n\n======================================\n');
        fprintf('Running %s Tutorial\n',strrep(tTutorials(iI).name,'+',''));
        fprintf('======================================\n\n');
    
    
        
        % If the folder has a correctly named 'setup.m' file, we can go
        % ahead and try to execute it.
        if exist(fullfile(sTutorialDirectory, tTutorials(iI).name, 'setup.m'), 'file')
            
            % First we construct the string that is the argument for the
            % vhab.exec() method.
            sExecString = ['tutorials.',strrep(tTutorials(iI).name,'+',''),'.setup'];
            
            % Now we can finally run the simulation, but we need to catch
            % any errors inside the simulation itself
            try
                oLastSimObj = vhab.exec(sExecString);
                
                % Done! Let's plot stuff!
                oLastSimObj.plot();
                
                % Saving the figures to the pre-determined location
                tools.saveFigures(sFolderPath, strrep(tTutorials(iI).name,'+',''));
                
                % Closing all windows so we can see the console again. The
                % drawnow() call is necessary, because otherwise MATLAB would
                % just jump over the close('all') instruction and run the next
                % sim. Stupid behavior, but this is the workaround.
                close('all');
                drawnow();
                
                % Since we've now actually completed the simulation, we can
                % increment the counter of successful tutorials. Also we
                % can set the string property for the final output.
                iSuccessfulTutorials = iSuccessfulTutorials + 1;
                tTutorials(iI).sStatus = 'Successful';
            catch oException
                % Something went wrong inside the simulation. So we tell
                % the user and keep going. The counter for aborted
                % tutorials is incremented and the string property for the
                % final output is set accordingly.
                fprintf('\nEncountered an error in the simulation. Aborting.\n');
                iAbortedTutorials = iAbortedTutorials + 1;
                tTutorials(iI).sStatus = 'Aborted';
                tTutorials(iI).sErrorReport = getReport(oException);
            end
            
        else
            % In case there is no 'setup.m' file, we print this to the
            % command window, but we don't stop the skript. We increment
            % the skipped-counter and set the property.
            disp(['The ',strrep(tTutorials(iI).name,'+',''),' Tutorial does not have a ''setup.m'' file. Skipping.']);
            iSkippedTutorials = iSkippedTutorials + 1;
            tTutorials(iI).sStatus = 'Skipped';
        end
    else
        % If the tutorial hasn't changed since the last execution, there's
        % no need to run it again. 
        disp(['The ',strrep(tTutorials(iI).name,'+',''),' Tutorial has not changed. Skipping.']);
        iSkippedTutorials = iSkippedTutorials + 1;
        tTutorials(iI).sStatus = 'Skipped';
    end
    
    
end

% Now that we're all finished, we can tell the user how well everything
% went. 

% Also, because I am a teeny, tiny bit obsessive about visuals, I'm going
% to calculate how many blanks I have to insert between the colon and the
% actual status so they are nice and aligned.

% Initializing an array
aiNameLengths = zeros(1,length(tTutorials));

% Getting the lengths of each of the tutorial names. (Good thing we deleted
% the other, non-tutorial folders earlier...)
for iI = 1:length(tTutorials)
    aiNameLengths(iI) = length(tTutorials(iI).name);
end

% And now we can get the length of the longest tutorial name
iColumnWidth = max(aiNameLengths);

% Printing...
fprintf('\n\n======================================\n');
fprintf('============== Summary ===============\n');
fprintf('======================================\n\n');
fprintf('Total Tutorials:       %i\n\n', length(tTutorials));
fprintf('Successfully executed: %i\n',   iSuccessfulTutorials);
fprintf('Aborted:               %i\n',   iAbortedTutorials);
fprintf('Skipped:               %i\n',   iSkippedTutorials);
disp('--------------------------------------');
disp('Detailed Summary:');
for iI = 1:length(tTutorials)
    % Every name should have at least two blanks of space between the colon
    % and the status, so we subtract the current name length from the
    % maximum name length and add two.
    iWhiteSpaceLength = iColumnWidth - length(tTutorials(iI).name) + 2;
    % Now we make ourselves a string of blanks of the appropriate length
    % that we can insert into the output in the following line. 
    sBlanks = blanks(iWhiteSpaceLength);
    % Tada!
    fprintf('%s:%s%s\n',strrep(tTutorials(iI).name,'+',''),sBlanks,tTutorials(iI).sStatus);
end
fprintf('--------------------------------------\n\n');

% Now we print out the error messages from the tutorials that were aborted
% if there were any.
mbHasAborted = strcmp({tTutorials.sStatus}, 'Aborted');
if any(mbHasAborted)
    fprintf('=======================================\n');
    fprintf('=========== Error messages ============\n');
    fprintf('=======================================\n\n');
    iErrorCounter = 0;
    for tTutorial = tTutorials(mbHasAborted)
        fprintf('=> %s Tutorial Error Message:\n\n',strrep(tTutorial.name,'+',''));
        fprintf(2, '%s\n\n',tTutorial.sErrorReport);
        iErrorCounter = iErrorCounter + 1;
        fprintf('--------------------------------------\n\n\n');
    end
end

fprintf('======================================\n');
fprintf('===== Finished running tutorials =====\n');
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
    sBaseFolderPath = fullfile('data', 'figures', 'Tutorials_Test');
    
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





function bChanged = checkVHABFiles()
    %TODO: |vhab.m| should be the only file in root, so only check this one
    % Since we can't call this function from outside the V-HAB base
    % folder and this function would then catalog the entire directory,
    % we'll add a virtual folder here so we can still check the few files
    % in the top level V-HAB folder.
    
    % This is mainly just to save some space in the following code, but it
    % also defines the file name we will use to store the tSavedInfo
    % struct. 
    sSavePath  = strrep('data/FolderStatus.mat','/',filesep);
    
    bChanged = false;
    tInfo = dir();
    tInfo = tools.removeIllegalFilesAndFolders(tInfo);
    tSavedInfo = struct();
    load(sSavePath);
    
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
