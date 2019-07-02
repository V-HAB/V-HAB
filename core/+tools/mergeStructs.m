function tResult = mergeStructs(tOriginal, tNew)
    %MERGESTRUCTS Merges two structs
    %   It is important to note, that the struct in the second input
    %   argument takes precedence. If the original and new structs have
    %   fields with the same name, the resulting struct will incorporate
    %   the values from the new struct, overwriting the original.
    
    % Getting the fieldnames of the new struct
    csFields = fieldnames(tNew);
    
    % Initializing the return struct with the original
    tResult = tOriginal;
    
    % Looping through the fields
    for iI = 1:size(csFields, 1)
        % Getting the current field name
        sField = csFields{iI, 1};
        
        % If both structs have a field of the same name AND both are
        % structs, we call this function recursively. 
        if isfield(tOriginal, sField) && isstruct(tOriginal.(sField)) && isstruct(tNew.(sField))
            tResult.(sField) = tools.mergeStructs(tOriginal.(sField), tNew.(sField));
        else
            % Either of them is not a struct, so tNew takes precedence and
            % overwrites the original. This also happens if the original
            % was a struct and the new field is not. 
            tResult.(sField) = tNew.(sField);
        end
    end
end
