function [ tInfo, bRemoved ] = removeEntriesForDeletedFiles(sPath, tInfo)
%REMOVEENTRIESFORDELETEDFILES This function is called by
%tools.checkForChanges() to remove entries in the data struct storing the
%file and folder information because they have been deleted. 
%   Input arguments are the path for which the search shall be conducted
%   and a struct containing the information that has been saved for that
%   path.
%   Since the checkForChanges() function has to save the information on the
%   files and folders in a struct, some changes have to be made for the
%   file and folder names to be valid field names for structs. A good part
%   of this function deals with reverting these changes to a check if the
%   file or folder exists can be performed. 
%   The return values are the struct containing the file information and a
%   boolean variable indicating, if a file or a folder was removed.

% Getting a cell with the fieldnames from the input struct
csFieldNames = fieldnames(tInfo);

% If this is the very fist call, then the top level struct from
% checkForChanges() will have two fields that are not related to the file
% system, so we delete them. 
csFieldNames(contains(csFieldNames,'bInitialScanComplete')) = [];
csFieldNames(contains(csFieldNames,'bLastActionComplete'))  = [];

% Since we are iterating through all of the items in the current path
% level, we create a boolean array to store the information in. 
abRemoved = false([length(csFieldNames),1]);

% Now we can loop through all the field names and check if the files and
% folders the individual entries refer to still exist. If not, we delete
% them.
for iI = 1:length(csFieldNames)
    % If the entry for an individual field is numeric, it is the change
    % date of the file. If it is not numeric, then it is a struct,
    % indicating a folder. So we have to do different things.
    if isnumeric(tInfo.(csFieldNames{iI}))
        % It's a file. Since the field name will not be the file name
        % directly, we need to modify it by removing '_<extension>_file'
        % and replacing it with '.<extension>' at the end
        [iEnd, csToken] = regexp(csFieldNames{iI},'_(?<type>[^_]*)_file','start','tokens');
        if ~isempty(iEnd)
            sFileName = [csFieldNames{iI}(1:iEnd-1),'.',csToken{1}{1}];
        else
            sFileName = csFieldNames{iI};
        end
        
        % If we are looking at the base directory, then sPath will be an
        % empty string. If so, we can call the dir command without any
        % arguments to get the information on the current directory.
        if isempty(sPath)
            tDirInfo = dir;
        else
            tDirInfo = dir(sPath);
        end
        
        % Getting the file and folder names of the current directory
        csNames = {tDirInfo(:).name};
        
        % In order to ensure that we find the file we are looking for, we
        % replace all non-letter characters with '.?' and use the result as
        % the search pattern in the regular expression in the following
        % lines. 
        sExpression = regexprep(sFileName,'[^a-z]','.?','ignorecase');
        
        % Now we look for the file name within all file names in the
        % current folder.
        cbFoundItems = regexp(csNames, sExpression);
        abFoundItems = ~cellfun(@isempty, cbFoundItems);
        
        % If we cannot find the file, we delete it and let the user know. 
        if ~any(abFoundItems)
            tInfo = rmfield(tInfo, csFieldNames{iI});
            abRemoved(iI) = true;
            fprintf('''%s%s'' was removed.\n', sPath, sFileName);
        end
        
    else
        % We are currently looking at the struct of a folder. Here we need
        % to perform changes to the folder name as well in order to be able
        % to search for it. A folder name can begin with a number, but a
        % struct field name cannot. If there was a number as the first
        % character, the folder name will have been prepended with 'p_'.
        % Now we remove that again. 
        if strcmp(csFieldNames{iI}(1:2),'p_')
            sFolderName = csFieldNames{iI}(3:end);
        else
            sFolderName = csFieldNames{iI};
        end
        
        % Now we have to look at the folder name. Some folders have '@' at
        % the beginning. This will have been replaced with 'at_at_' to make
        % it a valid struct field name. If there is no '@', then it is
        % usually '+'.
        if length(sFolderName) > 3 && ...
                strcmp(sFolderName(1:3),'at_')
            sNewPath = [ '@', sFolderName(7:end), filesep ];
        else
            sNewPath = [ '+', sFolderName, filesep ];
        end
        
        % Now we check if the folder exists. This should work for all
        % package '+' and class '@' folders. If not, we'll try some more
        % stuff. 
        if ~isfolder([sPath, sNewPath])
            bContinue = true;
        else
            bContinue = false;
        end
        
        if bContinue
            % First we get the directory information. If the path is empty,
            % this is the first call, so we can just use dir() without
            % arguments. 
            if isempty(sPath)
                tDirInfo = dir;
            else
                tDirInfo = dir(sPath);
            end 
            
            % Getting the file and folder names of the current directory
            csNames = {tDirInfo(:).name};
            
            % In order to ensure that we find the folder we are looking
            % for, we replace all non-letter characters with '.?' and use
            % the result as the search pattern in the regular expression in
            % the following lines.
            sExpression = regexprep(sNewPath(1:end-1),'[^a-z]','.?','ignorecase');
            
            % Now we look for the folder name within all names in the
            % current folder.
            cbFoundItems = regexp(csNames, sExpression);
            abFoundItems = ~cellfun(@isempty, cbFoundItems);
            
            % If we found it, then we set the new path accordingly, if not
            % we assume the folder has been removed and we delete it from
            % the struct. 
            if any(abFoundItems)
                sNewPath = [ csNames{abFoundItems}, filesep ];
            else
                % Deleting the field from the struct and informing the
                % user. 
                tInfo = rmfield(tInfo, csFieldNames{iI});
                abRemoved(iI) = true;
                fprintf('''%s%s'' was removed.\n', sPath, sFolderName);
                
                % We don't have to do anything else in this iteration, so
                % we abort it. 
                continue;
            end
        end
        
        % We now have a working path so we call this function recursively
        % to check for deleted files folders on that path. 
        [ tInfo.(csFieldNames{iI}), abRemoved(iI) ] = tools.fileChecker.removeEntriesForDeletedFiles([sPath, sNewPath], tInfo.(csFieldNames{iI}));
    end
end

% Before we are finished, we need to check if any files or folders have
% been removed and set the return variable accordingly. 
if any(abRemoved)
    bRemoved = true;
else
    bRemoved = false;
end
end