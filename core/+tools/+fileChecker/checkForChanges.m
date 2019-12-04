function bChanged = checkForChanges(sFileOrFolderPath, sCaller)
%CHECKFORCHANGES  Check whether folder contains changed files
%   This function will check a given folder for changed files. The
%   information when you last ran this function will be saved in a .mat
%   file, so the function will only search for newer files until it has
%   found one and then return a true or false.
%   This function will be called recursively and during the recursions
%   the input parameter may be a file name.
%   If the given folder path string is empty, the STEPS Base top directory
%   will be searched. 
%   The sCaller input argument is to discern between different callers of
%   this function in the stored file status files. This prevents one part
%   of V-HAB code from calling this function and changing the file status
%   without the other knowing about it. 

% Getting or creating a global variable to temporarily contain our data.
global tSavedInfo

% This is mainly just to save some space in the following code, but it
% also defines the file name we will use to store the tSavedInfo
% struct.
sSavePath = fullfile('data',['FolderStatusFor', sCaller, '.mat']);

% If this is the very first call of this function the global variable
% 'tSavedInfo' will be empty and we have not yet saved any information to a
% file. However, if this function has been called before, then the file
% will exist. Finally, this call may be a recursive one, in which case the
% global variable will already be populated. We check all of this here for
% performance reasons. The exist() function is very slow, so by checking it
% here once, we don't need to do it for every recursive call of this
% function. 
if isempty(tSavedInfo)
    if exist(sSavePath, 'file') ~= 0
        load(sSavePath, 'tSavedInfo');
        bFirstCall = true;
        bFirstRun = false;
    else
        bFirstCall = true;
        bFirstRun = true;
    end
else
    bFirstCall = false;
    bFirstRun = false;
end

% Load the information from when we last executed this check or create
% a new variable that we can later save.
if ~bFirstRun
    % There is a mechanism in place to prevent a corrupted file from being
    % used in the event the initial folder scan was aborted. We check if
    % this field exists at all to force an update for users that created
    % their folder scan with an older version of this function. If the
    % field exists, we verify if the initial scan is complete, if not, we
    % have to redo it, unless THIS is actually the inital scan. In this
    % case, a field called bInitialScanInProgress will exist. We also need
    % to be sure, that the file we have loaded is NOT from an aborted scan
    % due to errors. For this, there is another variable added to the
    % tSavedInfo struct called bLastActionComplete. This is set to false at
    % the beginning of each step of the scan and set to true once this step
    % is complete and this function is recursively called again. 
    bRedoScan = false;
    
    if ~isfield(tSavedInfo, 'bInitialScanComplete')
        % If this field does not exist, the loaded file was created with an
        % older version of this function and the scan has to be redone. 
        bRedoScan = true;
    elseif tSavedInfo.bInitialScanComplete
        % If the initial scan is complete, then this is a 'regular' search
        % for changes and we don't hve to rescan.
        bRedoScan = false;
    elseif isfield(tSavedInfo, 'bInitialScanInProgress')
        % If this field exists the initial scan is in progress. It will be
        % deleted at the end of the initial scan. 
        if tSavedInfo.bLastActionComplete
            % If the bLastActionComplete variable is true, then the last
            % action during the initial scan was completed successfully.
            % Usually errors occur due to file or folder names that contain
            % illegal characters.
            bRedoScan = false;
        else
            % In this case the initial scan has been aborted, so we have to
            % redo the initial scan. 
            bRedoScan = true;
        end
    end
    
    if bRedoScan
        % Before we redo the initial scan, we first have to prepare some
        % things:
        % Tell the user what's going on.
        disp(['FolderStatusFor', sCaller, '.mat', 'file is outdated or corrupt. Repeating initial folder scan.']);
        % Delete the previously saved data file
        delete(sSavePath);
        % Clear the current workspace variable
        clear('tSavedInfo');
        % Now we recursively call this function, without the existing data
        % file this will trigger a re-scan.
        tools.fileChecker.checkForChanges(sFileOrFolderPath, sCaller);
        % We still have to set the return variable to true, since this is
        % the first called instance of this function.
        bChanged = true;
        % Then we abort the function, otherwise it would continue to
        % execute the following code. 
        return;
    end
    
    % Now that we have determined that a re-scan is not necessary, we set
    % the bLastActionComplete variable to false, because now we start a new
    % action. 
    tSavedInfo.bLastActionComplete = false;
    
    % Checking if there are any space characters in the string. This is not
    % permitted, so we throw an error. 
    if contains(sFileOrFolderPath, ' ')
        error('VHAB:checkForChanges', ['The file you are adding\n(%s)\n', ... 
              'contains space characters in its path. This is not permitted within V-HAB/MATLAB.\n'...
              'Please change all file and folder names accordingly.'], sFileOrFolderPath);
    end
    
    % Make sure the string is cleaned up and doesn't contain any
    % illegal characters that can't be used as field names
    sFileOrFolderString = tools.normalizePath(sFileOrFolderPath, true);
    
    % Splitting the string into a cell array
    csFieldNames = strsplit(sFileOrFolderString, {'__', '_aaat_', '_p_'});
    
    % If there is only one element in the array, this means that either
    % a new folder is being added, or we are beginnig a search in the
    % top most folder.
    if length(csFieldNames) == 1
        % Check if the folder name already exists as a field
        if ~isfield(tSavedInfo, csFieldNames{1})
            % The folder name doesn't exist, so this is either the
            % addition of a new folder or we are searching the STEPS Base
            % folder. We can determine this by checking if csFieldNames{1}
            % is empty or not.
            if isempty(csFieldNames{1})
                % We are starting a search for changes in the top level
                % STEPS Base folder.
                
                % Since we want to scan the entire V-HAB folder, we'll use
                % the directory information of the current folder ('pwd').
                tInfo = dir(pwd);
                % Cleaning up the struct to get rid of files and folders we
                % don't want to scan.
                tInfo = tools.fileChecker.removeIllegalFilesAndFolders(tInfo);
                % We're initializing a boolean array to save the
                % information if there are changed files in the folder.
                abChanged = zeros(1,length(tInfo));
                % Now we go through all the items in the info struct and
                % check for changes.
                for iI = 1:length(tInfo)
                    if isfolder(tInfo(iI).name)
                        
                        % Since we will now be recursively calling this
                        % function, we need to set the
                        % bLastActionComplete variable to true.
                        tSavedInfo.bLastActionComplete = true;
                        
                        % Now go through all the items and see if there
                        % are changes.
                        if strcmp(tInfo(iI).name,'data')
                            continue;
                        else
                            abChanged(iI) = tools.fileChecker.checkForChanges(tInfo(iI).name, sCaller);
                        end
                    else
                        % We are looking at a file so we'll first get the
                        % struct-compatible file name.
                        sFileName = tools.normalizePath(tInfo(iI).name, true);
                        
                        % Now we need to check, if this is a new or an
                        % existing file.
                        if isfield(tSavedInfo, sFileName)
                            % The file exists, so we'll compare the save
                            % date that we stored in our file with the date
                            % in the current file's info struct. If the
                            % current date is newer, then the file has
                            % changed since we last ran this function.
                        
                            if eval(['tSavedInfo.',sFileName,' < tInfo(iI).datenum;'])
                                % It has changed! So we can save the new
                                % change date into the struct and set our
                                % return variable to true.
                                eval(['tSavedInfo.',sFileName,' = tInfo(iI).datenum;'])
                                abChanged(iI) = true;
                                fprintf('''%s'' has changed.\n',tInfo(iI).name);
                            else
                                % Seems like nothing has changed, so we can
                                % return false.
                                abChanged(iI) = false;
                            end
                        else
                            % The file doesn't exist. This means we are
                            % adding a new file in the V-HAB base directory
                            % that has not yet been added to the struct. So
                            % we use the file name as a key to create a new
                            % member of the current struct, with the
                            % changed date as a value. 
                            eval(['tSavedInfo.',sFileName,' = tInfo(iI).datenum;']);
                            
                            % Returning true for this item
                            abChanged(iI) = true;
                            
                            % Letting the user know that this file was
                            % added.
                            fprintf('''%s'' was added.\n', tInfo(iI).name);
                            
                        end
                    end
                end
                
                % Set the return variable.
                bChanged = any(abChanged);
                
                % In case it is the first call, we can clean up
                % and save the data into the file again for
                % next time.
                if bFirstCall
                    % Removing any deleted files
                    [ tSavedInfo, bRemoved ] = tools.fileChecker.removeEntriesForDeletedFiles('', tSavedInfo);
                    % If any files have been removed, then we also set the
                    % return variable to true.
                    if bRemoved, bChanged = true; end
                    
                    save(sSavePath,'tSavedInfo','-v7');
                    clear global tSavedInfo
                end
                
                % Finish the function.
                return;
                
                
            else
                % The field name for the folder doesn't exist, So we add it
                % to the top level of our tSavedInfo struct.
                tSavedInfo.(csFieldNames{1}) = struct();
                % Now we get the information struct for the folder via the
                % dir() method. This struct contains information on all
                % files and folders inside the folder we are currently
                % looking at, including the date and time the files were
                % last changed.
                tInfo = dir(sFileOrFolderPath);
                % There will be some hidden files and folders in here that
                % we have to remove.
                tInfo = tools.fileChecker.removeIllegalFilesAndFolders(tInfo);
                % Now we can go through all objects in the folder to see if
                % they have changed. If the current item is a folder, we
                % just call this function (checkForChanges()) again, if it
                % is a file we save the information to a field in the
                % struct.
                for iI = 1:length(tInfo)
                    if tInfo(iI).isdir
                        % Since we will now be recursively calling this
                        % function, we need to set the bLastActionComplete
                        % variable to true and save it to the data file.
                        tSavedInfo.bLastActionComplete = true;
                        % Recursive call of this function
                        tools.fileChecker.checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name], sCaller);
                    else
                        % This is only executed if a new folder is added to
                        % the existing file that has files on the top
                        % level.
                        sFileName = tools.normalizePath(tInfo(iI).name, true);
                        % Saving the new file info and setting the
                        % bLastActionComplete variable to true.
                        tSavedInfo.(csFieldNames{1}).(sFileName) = tInfo(iI).datenum;
                        tSavedInfo.bLastActionComplete = true;
                    end
                end
                
                % This code block is only executed, when we're adding new
                % files and folders, so we return 'true' and finish the
                % function.
                bChanged = true;
                if tSavedInfo.bInitialScanComplete
                    fprintf('''%s'' was added.\n', sFileOrFolderPath);
                end
                return;
            end
        else
            % The field name for the top level folder we are looking at
            % already exists. This means we are beginning a search in
            % this folder for changed files.
            
            % Getting the info struct and deleting the illegal files
            % and folders.
            tInfo = dir(sFileOrFolderPath);
            tInfo = tools.fileChecker.removeIllegalFilesAndFolders(tInfo);
            % We're initializing a boolean array to save the
            % information if there are changed files in the folder.
            abChanged = zeros(1,length(tInfo));
            % Because we'll now recursively call this function, we have to
            % set the bLastActionComplete variable to true. We don't have
            % to reload the file because we are not in a loop. The variable
            % will still be the same as in the beginning of this execution.
            tSavedInfo.bLastActionComplete = true;
            
            % Now go through all the items and see if there are
            % changes.
            for iI = 1:length(tInfo)
                abChanged (iI) = tools.fileChecker.checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name], sCaller);
            end
            
            % Set the return variable.
            bChanged = any(abChanged);
            
            % In case it is the first call, we can clean up and save the data into
            % the file again for next time.
            if bFirstCall
                % Getting the old struct for the folder we are looking at.
                tOldInfo = eval(['tSavedInfo.',sFileOrFolderPath]);
                % Removing any deleted files
                [ tNewInfo, bRemoved ] = tools.fileChecker.removeEntriesForDeletedFiles([sFileOrFolderPath, filesep], tOldInfo); %#ok<ASGLU>
                % If any files have been removed, then we also set the
                % return variable to true and update the saved info struct.
                if bRemoved
                    bChanged = true;
                    eval(['tSavedInfo.',sFileOrFolderPath, '=','tNewInfo;']);
                end
                
                save(sSavePath,'tSavedInfo','-v7');
                clear global tSavedInfo
            end
            
            % Finish the function.
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
        % Make sure that the field names are clean
        csFieldNames{iI} = tools.normalizePath(csFieldNames{iI}, true);
        sFieldNames = strcat(sFieldNames,'.',csFieldNames{iI});
    end
    sStructString = ['tSavedInfo','.',sFieldNames];
    
    % Make sure that the field name is clean
    sFieldName = tools.normalizePath(csFieldNames{end}, true);
    
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
            tInfo = tools.fileChecker.removeIllegalFilesAndFolders(tInfo);
            % Creating new sub-struct
            eval([sStructString,'.',sFieldName,' = struct();']);
            % Since we will now be recursively calling this function, we
            % need to set the bLastActionComplete variable to true.
            tSavedInfo.bLastActionComplete = true;
            % Go into the folder to add its subfolders and files.
            for iI = 1:length(tInfo)
                tools.fileChecker.checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name], sCaller);
            end
        else
            % The item we're looking at is a file that has not yet been
            % added to the struct. So we use the file name as a key to
            % create a new member of the current struct, with the
            % changed date as a value. After completing this else-statement
            % we will return to the calling instance of this function, so
            % we have to set the bLastActionComplete variable to true.
            eval([sStructString,'.',sFieldName,' = tInfo.datenum;']);
            tSavedInfo.bLastActionComplete = true;
        end
        
        % Alright, all done in here, since we came into this part of the
        % if-condition because there was a non-existent field, we have
        % definitely added a file or a folder, so we set our return
        % variable to true and finish the function.
        bChanged = true;
        if tSavedInfo.bInitialScanComplete
            fprintf('''%s'' was added.\n', sFileOrFolderPath);
        end
        
    else
        % Okay, so the file exists AND the field exists, this must be a
        % search for actual changes and not the initial scan.
        % Getting the info and checking if we're looking at a file or a
        % folder
        tInfo = dir(sFileOrFolderPath);
        if ~(length(tInfo) == 1 && ~tInfo.isdir)
            % It's a folder, so we'll remove the illegal entries and
            % call ourselves recursively to check the contents for
            % changes.
            tInfo = tools.fileChecker.removeIllegalFilesAndFolders(tInfo);
            % Initializing a boolean array to log the changes in the
            % folders.
            abChanged = zeros(1,length(tInfo));
            for iI = 1:length(tInfo)
                abChanged (iI) = tools.fileChecker.checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name], sCaller);
            end
            
            % If any of the folders have changed, we need to return
            % true. 
            bChanged = any(abChanged);
            
        else
            % We are looking at a file, so we'll compare the save date
            % that we stored in our file with the date in the current
            % file's info struct. If the current date is newer, then
            % the file has changed since we last ran this function.
            if eval([sStructString,'.',sFieldName,' < tInfo.datenum;'])
                % It has changed! So we can save the new change date into
                % the struct and set our return variable to true.
                eval([sStructString,'.',sFieldName,' = tInfo.datenum;'])
                bChanged = true;
                fprintf('''%s'' has changed.\n',sFileOrFolderPath);
            else
                % Seems like nothing has changed, so we can return false.
                bChanged = false;
            end
        end
    end
    
    % In case it is the first call, we can clean up and save the data into
    % the file again for next time.
    if bFirstCall
        % Getting the old struct for the folder we are looking at.
        tOldInfo = eval([sStructString,'.',sFieldName]);
        % Removing any deleted files
        [ tNewInfo, bRemoved ] = tools.fileChecker.removeEntriesForDeletedFiles([sFileOrFolderPath, filesep], tOldInfo); %#ok<ASGLU>
        % If any files have been removed, then we also set the return
        % variable to true and update the saved info struct.
        if bRemoved
            bChanged = true;
            eval([sStructString,'.',sFieldName, '=','tNewInfo;']);
        end
        
        save(sSavePath,'tSavedInfo','-v7');
        clear global tSavedInfo
    end
else
    % Need to do initial scan of all folders, this block is only
    % executed at the very first time the function is called and there
    % is no .mat file present.
    
    % Tell the user
    disp('Doing initial scan of current folder. This will take a moment ...');
    % Creating our main tSavedInfo struct.
    tSavedInfo = struct();
    
    % Saving the empty variable into a file. This will be the indicator for
    % the following recursive calls, that this is NOT the first run.
    save(sSavePath,'tSavedInfo','-v7');
    
    % The following is a safety feature. When this function is run and
    % aborts somewhere in between, the saved .mat file will not be deleted.
    % Therfore, when this function is run again, it will NOT redo the
    % initial scan, but assume that the existing file is valid. This is not
    % the desired behavior. So to determine, if the initial scan was
    % succesfully completed, we will add one more field to the struct,
    % called bInitialScanComplete. This will be set to true at the end of
    % this 'else' case when the initial scan is complete. If the incomplete
    % file is used, this variable will be checked at the beginning of an
    % actual check for changes run.
    tSavedInfo.bInitialScanComplete = false;
    % Since this function is called recursively, we also need to know, if
    % we are currently in the process of doing the initial scan, or if this
    % is a scan checking for changes. For this, we create another field.
    % This will be set to false, after the initial scan is complete. 
    tSavedInfo.bInitialScanInProgress = true;
    
    % Just as a fun feature, we'll log the start time here so we can tell
    % the user how long it took to create the full scan.
    hTimer = tic();
    
    % Since we want to scan the entire V-HAB folder, we'll use the
    % directory information of the current folder ('pwd').
    tInfo = dir(pwd);
    % Cleaning up the struct to get rid of files and folders we don't want
    % to scan.
    tInfo = tools.fileChecker.removeIllegalFilesAndFolders(tInfo);
    % Now we go through all the items in the info struct and check for
    % changes, although since this is the fist run, they will of course
    % all have changed.
    for iI = 1:length(tInfo)
        if tInfo(iI).isdir
            % The item is a folder, so we'll call ourselves again to
            % look into that folder. But we don't want to look into the 
            % 'data' folder, because that is where all of the temporary 
            % data is stored. This is also a folder that is being ignored 
            % by git.
            if strcmp(tInfo(iI).name,'data')
                continue;
            else
                % Since we will now be recursively calling this function,
                % we need to set the bLastActionComplete variable to true.
                tSavedInfo.bLastActionComplete = true;
                % Go into the folder to add its subfolders and files.
                tools.fileChecker.checkForChanges(tInfo(iI).name, sCaller);
            end
        else
            % The item we're looking at is a file, so we'll cleanup the
            % file name and create a new item in the struct in which we
            % can save the changed date for this file.
            sFileName = tools.normalizePath(tInfo(iI).name, true);
            tSavedInfo.(sFileName) = tInfo(iI).datenum;
        end
    end
    
    % Since this was the inital scan, we set the return variable to true
    bChanged = true;
    % We tell the user, that the initial scan is complete and how long it
    % took.
    disp(['Initial folder scan completed in ', num2str(toc(hTimer)), ' seconds.']);
    
    % Finally, we can set the boolean variable for the completed initial
    % scan to true. 
    tSavedInfo.bInitialScanComplete   = true;
    
    % Now just cleaning up, removing some fields, saving the global
    % variable to the file for later use and clearing it.
    tSavedInfo = rmfield(tSavedInfo, 'bInitialScanInProgress');
    tSavedInfo = rmfield(tSavedInfo, 'bLastActionComplete');
    save(sSavePath,'tSavedInfo','-v7');
    clear global tSavedInfo
    return;
end
end