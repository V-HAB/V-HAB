function bChanged = checkForChanges(sFileOrFolderPath)
%CHECKFORCHANGES  Check whether folder contains changed files
%   This function will check a given folder for changed files. The
%   information when you last ran this function will be saved in a .mat
%   file, so the function will only search for newer files until it has
%   found one and then return a true or false.
%   This function will be called recursively and during the recursions
%   the input parameter may be a file name.
%TODO: skip uninteresting files like images (PNG, JPG, ...)

% Initializing an empty struct. This will contain all of the file
% information.
tSavedInfo = struct();

% This is mainly just to save some space in the following code, but it
% also defines the file name we will use to store the tSavedInfo
% struct.
sSavePath  = fullfile('data','FolderStatus.mat');

% Load the information from when we last executed this check or create
% a new variable that we can later save.
if exist(sSavePath, 'file') ~= 0
    % The file already exists so we can load it
    load(sSavePath);
    
    % Make sure the string is cleaned up and doesn't contain any
    % illegal characters that can't be used as field names
    sFileOrFolderString = tools.normalizePath(sFileOrFolderPath);
    
    % Splitting the string into a cell array
    %TODO: |tools.normalizePath| preserves a prefix so no hack required here
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
            tInfo = tools.removeIllegalFilesAndFolders(tInfo);
            % Now we can go through all objects in the folder to see if
            % they have changed. If the current item is a folder, we
            % just call this function (checkForChanges()) again, if it
            % is a file we save the information to a field in the
            % struct.
            for iI = 1:length(tInfo)
                if tInfo(iI).isdir
                    % Recursive call of this function
                    tools.checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name]);
                else
                    % This is only executed if a new folder is added to
                    % the existing file that has files on the top
                    % level.
                    sFileName = tools.normalizePath(tInfo(iI).name);
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
            tInfo = tools.removeIllegalFilesAndFolders(tInfo);
            % We're initializing a boolean array to save the
            % information if there are changed files in the folder.
            abChanged = zeros(1,length(tInfo));
            % Now go through all the items and see if there are
            % changes.
            for iI = 1:length(tInfo)
                abChanged (iI) = tools.checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name]);
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
    sFieldName = tools.normalizePath(csFieldNames{end});
    
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
            tInfo = tools.removeIllegalFilesAndFolders(tInfo);
            % Creating new sub-struct
            eval([sStructString,'.',sFieldName,' = struct();']);
            % Saving the changed struct to the file
            save(sSavePath,'tSavedInfo');
            % Go into the folder to add its subfolders and files.
            for iI = 1:length(tInfo)
                tools.checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name]);
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
            tInfo = tools.removeIllegalFilesAndFolders(tInfo);
            % Initializing a boolean array to log the changes in the
            % folders.
            abChanged = zeros(1,length(tInfo));
            for iI = 1:length(tInfo)
                abChanged (iI) = tools.checkForChanges([sFileOrFolderPath,filesep,tInfo(iI).name]);
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

    % Creating our main tSavedInfo struct.
    tSavedInfo = struct();
    % Saving the struct to a file from where it can be loaded by the
    % other instances of this function.
    save(sSavePath,'tSavedInfo');
    % Since we want to scan the entire V-HAB folder, we'll use the
    % directory information of the current folder ('pwd').
    tInfo = dir(pwd);
    % Cleaning up the struct to get rid of files and folders we don't want
    % to scan.
    tInfo = tools.removeIllegalFilesAndFolders(tInfo);
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
                % Since this is the first run, we also need to create a
                % struct for this top level folder.
                tools.checkForChanges(tInfo(iI).name);
            end
        else
            % The item we're looking at is a file, so we'll cleanup the
            % file name and create a new item in the struct in which we
            % can save the changed date for this file.
            sFileName = tools.normalizePath(tInfo(iI).name);
            load(sSavePath);
            tSavedInfo.(sFileName) = tInfo(iI).datenum;
            save(sSavePath,'tSavedInfo');
        end
    end
    
    bChanged = true;
    return;
end
end