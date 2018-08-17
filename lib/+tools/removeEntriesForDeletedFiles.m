function tInfo = removeEntriesForDeletedFiles(sPath, tInfo)
%REMOVEENTRIESFORDELETEDFILES

csFieldNames = fieldnames(tInfo);

csFieldNames(contains(csFieldNames,'bInitialScanComplete')) = [];
csFieldNames(contains(csFieldNames,'bLastActionComplete'))  = [];

for iI = 1:length(csFieldNames)
    if isnumeric(tInfo.(csFieldNames{iI}))
        % Remove '_<extension>_file' and replace with '.<extension>'
        [iEnd, csToken] = regexp(csFieldNames{iI},'_(?<type>[^_]*)_file','start','tokens');
        if ~isempty(iEnd)
            sFileName = [csFieldNames{iI}(1:iEnd-1),'.',csToken{1}{1}];
        else
            sFileName = csFieldNames{iI};
        end
        
        % Remove 'p_' at the beginning if present.
        if strcmp(sFileName(1:2),'p_')
            sFileName = sFileName(3:end);
        end
        
        if isempty(sPath)
            tDirInfo = dir;
        else
            tDirInfo = dir(sPath);
        end
        
        csNames = {tDirInfo(:).name};
        
        sExpression = regexprep(sFileName,'[^a-z]','.?','ignorecase');
        
        cbFoundItems = regexp(csNames, sExpression);
        abFoundItems = ~cellfun(@isempty, cbFoundItems);
        
        if ~any(abFoundItems)
            tInfo = rmfield(tInfo, csFieldNames{iI});
            fprintf('''%s%s'' is being removed.\n', sPath, sFileName);
        end
        
    else
        % Remove 'p_' at the beginning if present.
        if strcmp(csFieldNames{iI}(1:2),'p_')
            csFieldNames{iI} = csFieldNames{iI}(3:end);
        end
        
        if isempty(sPath)
            sNewPath = [ csFieldNames{iI}, filesep ];
        else
            if length(csFieldNames{iI}) > 3 && ...
               strcmp(csFieldNames{iI}(1:3),'at_')
                sNewPath = [ '@', csFieldNames{iI}(7:end), filesep ];
            else
                sNewPath = [ '+', csFieldNames{iI}, filesep ];
            end
        end
        
        if ~isfolder([sPath, sNewPath])
            % Special characters, like dashes etc. will all have been
            % converted to underscores. 
            
            if isempty(sPath)
                tDirInfo = dir;
            else
                tDirInfo = dir(sPath);
            end 
            
            csNames = {tDirInfo(:).name};
            
            sExpression = regexprep(sNewPath(1:end-1),'[^a-z]','.?','ignorecase');
            
            cbFoundItems = regexp(csNames, sExpression);
            abFoundItems = ~cellfun(@isempty, cbFoundItems);
            
            if any(abFoundItems)
                sNewPath = [ csNames{abFoundItems}, filesep ];
            else
                tInfo = rmfield(tInfo, csFieldNames{iI});
                fprintf('''%s%s'' is being removed.\n', sPath, sFileName);
                continue;
            end
        end
        
        tInfo.(csFieldNames{iI}) = tools.removeEntriesForDeletedFiles([sPath, sNewPath], tInfo.(csFieldNames{iI}));
    end
end
end