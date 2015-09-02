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
bCoreChanged = checkForChanges('core');
bLibChanged  = checkForChanges('lib');
%TODO: only |vhab.m| should ever be of interest, so handle it separately
bVHABChanged = checkVHABFiles();

% Being a UI nerd, I needed to produce a nice dynamic user message here. 
if any([bCoreChanged bLibChanged])
    if bCoreChanged || bVHABChanged
        sCore = 'Core ';
    else
        sCore = '';
        sConjunction = '';
        sVerb = 'has';
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
    if checkForChanges(fullfile(sTutorialDirectory, tTutorials(iI).name)) || bLibChanged || bCoreChanged;
        
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
disp('--------------------------------------');
% Now we print out the error messages from the tutorials that were aborted.
fprintf('Error messages:\n\n');
iErrorCounter = 0;
for iI = 1:length(tTutorials)
    if strcmp(tTutorials(iI).sStatus,'Aborted')
        fprintf('%s Tutorial Error Message:\n',strrep(tTutorials(iI).name,'+',''));
        fprintf(2, '%s\n\n',tTutorials(iI).sErrorReport);
        iErrorCounter = iErrorCounter + 1;
    end
end
if ~iErrorCounter; fprintf('None.\n\n'); end

disp('======================================');
disp('===== Finished running tutorials =====');
disp('======================================');

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

function tOutputStruct = removeIllegalFilesAndFolders(tInputStruct)
    % Initializing a helper array
    abIllegals = zeros(1,length(tInputStruct));
    
    for iI = 1:length(tInputStruct)
        % There are some files and folders from the operating system and 
        % git that begin with a '.' (period) character. Also MATLAB creates
        % temporary files with '*.asv' and '*.m~' extensions on Windows and
        % Mac OS respectively. Lastly, we need to exclude this file, the
        % one you are currently reading.
        if ~isempty(strfind(tInputStruct(iI).name(1),'.')) || ...
           ~isempty(strfind(tInputStruct(iI).name,'~')) || ...
           strcmp(tInputStruct(iI).name,'runAllTutorials.m')
            % First we need to find them
            abIllegals(iI) = 1;
        end
    end
    tOutputStruct = tInputStruct;
    % Delete the entries from the struct
    tOutputStruct(abIllegals > 0) = [];
end

function [sOutputName, varargout] = normalizePath(sInputPath, bUseNewSeparators)
    %normalizePath  Convert a path to a form without special characters
    % Other than underscores, not much except letters is allowed in struct
    % field names. So this function cleans any input string and replaces
    % the illegal characters with legal ones. 
    
    % Define magic separators.
    %TODO: update callsites and drop second parameter
    if nargin > 1 && bUseNewSeparators
        tSeparators = struct('package', '__pkd_', 'class', '__clsd_', 'filesep', '__ds__');
    else
        tSeparators = struct('package', '__', 'class', '_aaat_', 'filesep', '_p_');
    end
    
    % Make sure path starts with a file separator so we can identify
    % package and class folders more easily (see below).
    if ~strcmp(sInputPath(1), filesep)
        sOutputName = [filesep, sInputPath];
    else
        sOutputName = sInputPath;
    end
    
    % Replace package and class folder designators with special keywords.
    % Preserve a prefix for @-folders so those folder names do not clash
    % with files or packages that are named similarly.
    sOutputName = strrep(sOutputName, [filesep,'+'], tSeparators.package);
    sOutputName = strrep(sOutputName, [filesep,'@'], [tSeparators.class, 'at_']);
    
    % Drop any leading non-alphanumeric characters (e.g. UNC server paths),
    % then replace all path separators.
    sOutputName = regexprep(sOutputName, '^[^a-z0-9]*', '', 'ignorecase');
    sOutputName = strrep(sOutputName, filesep, tSeparators.filesep);
    
    % Replace the file extension including its leading dot with something
    % meaningful. Then replace all other invalid characters with an
    % underscore.
    sOutputName = regexprep(sOutputName, '\.(\w+)$', '_$1_file');
    sOutputName = regexprep(sOutputName, '[^a-z0-9_]', '_', 'ignorecase');
    
    % Make sure field name starts with a character, so just add a prefix if
    % it does not.
    sOutputName = regexprep(sOutputName, '^([^a-z])', 'p_$1', 'ignorecase');
    
    % Output the separator struct (optionally).
    if nargout > 1
        varargout = {tSeparators};
    end
    
end


function bChanged = checkForChanges(sFileOrFolderPath)
    %checkForChanges  Check whether folder contains changed files
    % This function will check a given folder for changed files. The 
    % information when you last ran this function will be saved in a .mat 
    % file, so the function will only search for newer files until it has 
    % found one and then return a true or false.
    % This function will be called recursively and during the recursions
    % the input parameter may be a file name. 
    %TODO: skip uninteresting files like images (PNG, JPG, ...)
    
    % Initializing an empty struct. This will contain all of the file
    % information. 
    tSavedInfo = struct();
    
    % This is mainly just to save some space in the following code, but it
    % also defines the file name we will use to store the tSavedInfo
    % struct. 
    sSavePath  = fullfile('data', 'FolderStatus.mat');
    
    % Load the information from when we last executed this check or create
    % a new variable that we can later save.
    if exist(sSavePath, 'file') ~= 0
        % The file already exists so we can load it
        load(sSavePath);
        
        % Make sure the string is cleaned up and doesn't contain any
        % illegal characters that can't be used as field names
        sFileOrFolderString = normalizePath(sFileOrFolderPath);
        
        % Splitting the string into a cell array
        %TODO: |normalizePath| preserves a prefix so no hack required here
        csFieldNames = strsplit(sFileOrFolderString, {'__', '_aa', '_p_'});
        
        % If there is only one element in the array, this means that either
        % a new folder is being added, or we are beginnig a search in the
        % top most folder. 
        if length(csFieldNames) == 1
            % Check if the folder name already exists as a field
            if ~isfield(tSavedInfo, csFieldNames{1})
                % The folder name doesn't exist, so this has to be the
                % addition of a new folder. So we add it to the top level
                % of our tSavedInfo struct. 
                tSavedInfo.(csFieldNames{1}) = struct();
                % As usual we save our work right away into the .mat file. 
                save(sSavePath,'tSavedInfo');
                % Now we get the information struct for the folder via the
                % dir() method. This struct contains information on all
                % files and folders inside the folder we are currently
                % looking at, including the date and time the files were
                % last changed. 
                tInfo = dir(sFileOrFolderPath);
                % There will be some hidden files and folders in here that
                % we have to remove. 
                tInfo = removeIllegalFilesAndFolders(tInfo);
                % Now we can go through all objects in the folder to see if
                % they have changed. If the current item is a folder, we
                % just call this function (checkForChanges()) again, if it
                % is a file we save the information to a field in the
                % struct. 
                for iI = 1:length(tInfo)
                    if tInfo(iI).isdir
                        % Recursive call of this function
                        checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name]);
                    else
                        % This is only executed if a new folder is added to
                        % the existing file that has files on the top
                        % level.
                        sFileName = normalizePath(tInfo(iI).name);
                        load(sSavePath);
                        tSavedInfo.(csFieldNames{1}).(sFileName) = tInfo(iI).datenum;
                        save(sSavePath,'tSavedInfo');
                    end
                end
                % This code block is only executed, when we're adding new
                % files and folders, so we return 'true' and finish the
                % function.
                bChanged = true;
                return;
            else
                % The field name for the top level folder we are looking at
                % already exists. This means we are beginning a search in
                % this folder for changed files. 
                % Getting the info struct and deleting the illegal files
                % and folders.
                tInfo = dir(sFileOrFolderPath);
                tInfo = removeIllegalFilesAndFolders(tInfo);
                % We're initializing a boolean array to save the
                % information if there are changed files in the folder.
                abChanged = zeros(1,length(tInfo));
                % Now go through all the items and see if there are
                % changes. 
                for iI = 1:length(tInfo)
                    abChanged (iI) = checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name]);
                end
                % Set the return variable and finish the function.
                bChanged = any(abChanged);
                return;
            end
        end
        
        % This part of the code is only executed if the FolderStatus.mat
        % file already exsists and we are not adding or searching in a top 
        % level folder
        
        % We need to access the hierarchy of the struct, so here we
        % assemble ourselves a string that we can then use in the eval()
        % method to get to the sub-struct we are looking at. The format
        % is 'tSavedInfo.<top folder name>.<next folder name>. ... 
        % The last item in the csFieldNames struct is the file or folder we
        % are currently looking at, so we don't need to add it to the
        % struct string.
        sFieldNames = csFieldNames{1};
        for iI = 2:(length(csFieldNames) - 1)
            sFieldNames = strcat(sFieldNames,'.',csFieldNames{iI});
        end
        sStructString = ['tSavedInfo','.',sFieldNames];
        
        % Make sure that the field name is clean
        sFieldName = normalizePath(csFieldNames{end});
        
        % Now we can check if the field already exists.
        if ~isfield(eval(sStructString),sFieldName)
            % The field does not exsist, this means that we are in the
            % process of adding this file or folder to our struct.
        
            % Get the info of the current file or folder
            tInfo = dir(sFileOrFolderPath);
        
            % Check if it's a file or a folder
            if ~(length(tInfo) == 1 && ~tInfo.isdir)
                % Its a folder, so we need to go in there, remove the
                % illegal files and folders, create a new sub-struct with 
                % the name of the folder as a field name and start looking
                % in there. 
                % Getting info
                tInfo = removeIllegalFilesAndFolders(tInfo);
                % Creating new sub-struct
                eval([sStructString,'.',sFieldName,' = struct();']);
                % Saving the changed struct to the file
                save(sSavePath,'tSavedInfo');
                % Go into the folder to add its subfolders and files.
                for iI = 1:length(tInfo)
                    checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name]);
                end
            else
                % The item we're looking at is a file that has not yet been
                % added to the struct. So we use the file name as a key to
                % create a new member of the current struct, with the
                % changed date as a value. 
                eval([sStructString,'.',sFieldName,' = tInfo.datenum;']);
                save(sSavePath,'tSavedInfo');
            end
            % Alright, all done in here, since we came into this part of
            % the if-condition because there was a non-existent field, this
            % has to be the initial scan, so we set our return variable to
            % true and finish the function.
            bChanged = true;
            return;
        else
            % Okay, so the file exists AND the field exists, this must be a
            % search for actual changes and not the initial scan. 
            % Getting the info and checking if we're looking at a file or a
            % folder
            tInfo = dir(sFileOrFolderPath);
            if ~(length(tInfo) == 1 && ~tInfo.isdir)
                % Its a folder, so we'll remove the illegal entries and
                % call ourselves recursively to check the contents for
                % changes
                tInfo = removeIllegalFilesAndFolders(tInfo);
                % Initializing a boolean array to log the changes in the
                % folders.
                abChanged = zeros(1,length(tInfo));
                for iI = 1:length(tInfo)
                    abChanged (iI) = checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name]);
                end
                % If any of the folders have changed, we need to return
                % true. We can also finish the function here, because 
                bChanged = any(abChanged);
                return;
            else
                % We are looking at a file, so we'll compare the save date
                % that we stored in our file with the date in the current
                % file's info struct. If the current date is newer, then
                % the file has changed since we last ran this function. 
                if eval([sStructString,'.',sFieldName,' < tInfo.datenum;'])
                    % It has changed! So we can set our return variable to
                    % true and also save the new date to the file. 
                    eval([sStructString,'.',sFieldName,' = tInfo.datenum;'])
                    save(sSavePath,'tSavedInfo');
                    bChanged = true;
                else
                    bChanged = false;
                end
            end
        end
    else
        % Need to do initial scan of all folders, this block is only
        % executed at the very first time the function is called and there
        % is no .mat file present.
        % First we need to clean up the folder name to make sure, it is
        % suitable for use as a struct field name.
        sFieldName = normalizePath(sFileOrFolderPath);
        % Creating the struct in our main tSavedInfo struct.
        tSavedInfo = struct(sFieldName,struct());
        % Since this is all about running the tutorials, we create the
        % appropriate folder for the tutorials. We need to do this, since
        % we will not be looking at the entire 'user' folder for changes,
        % just the folders inside the 'user/+tutorials' folder.
        tSavedInfo.user = struct();
        tSavedInfo.user.tutorials = struct();
        % Saving the struct to a file from where it can be loaded by the
        % other instances of this function.
        save(sSavePath,'tSavedInfo');
        % Getting the information struct for this first folder and removing
        % the hidden files and folders created by the operating system.
        tInfo = dir(sFileOrFolderPath);
        tInfo = removeIllegalFilesAndFolders(tInfo);
        % Now we go through all the items in the info struct and check for
        % changes, although since this is the fist run, they will of course
        % all have changed. 
        for iI = 1:length(tInfo)
            if tInfo(iI).isdir
                % The item is a folder, so we'll call ourselves again to
                % look into that folder. 
                checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name]);
            else
                % The item we're looking at is a file, so we'll cleanup the
                % file name and create a new item in the struct in which we
                % can save the changed date for this file. 
                sFileName = normalizePath(tInfo(iI).name);
                load(sSavePath);
                tSavedInfo.(sFieldName).(sFileName) = tInfo(iI).datenum;
                save(sSavePath,'tSavedInfo');
            end
        end
        
        bChanged = true;
        return;
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
    tInfo = removeIllegalFilesAndFolders(tInfo);
    tSavedInfo = struct();
    load(sSavePath);
    
    for iI = 1:length(tInfo)
        if ~tInfo(iI).isdir
            sFileName = normalizePath(tInfo(iI).name);
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
