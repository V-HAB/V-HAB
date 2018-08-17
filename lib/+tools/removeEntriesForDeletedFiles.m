function tInfo = removeEntriesForDeletedFiles(tInfo)
%REMOVEENTRIESFORDELETEDFILES

tInfo = rmfield(tInfo,{'bInitialScanComplete','bLastActionComplete'});

csFieldNames = fieldnames(tInfo);

for iI = 1:length(csFieldNames)
    if ischar(csFieldNames{iI})
        % Remove '_<extension>_file' and replace with '.<extension>'
        [iEnd, csToken] = regexp(csFieldNames{iI},'_(?<type>[^_]*)_file','start','tokens');
        sFileName = [csFieldNames{iI}(1:iEnd-1),'.',csToken{1}{1}];
        
        % Remove 'p_' at the beginning if present.
        
        
        if ~isfile(csFieldNames{iI})
            tInfo = rmfield(tInfo, csFieldNames{iI});
        end
    else
        tools.removeEntriesForDeletedFiles(tInfo.(csFieldNames{iI}));
    end
end
end