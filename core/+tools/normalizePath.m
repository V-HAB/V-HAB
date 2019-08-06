function sOutputName = normalizePath(sInputPath)
    %NORMALIZEPATH  Convert a path to a form without special characters
    %   Other than underscores, not much except letters is allowed in
    %   struct field names. So this function cleans any input string and
    %   replaces the illegal characters with legal ones.
    %
    %   Input parameters:
    %   sInputPath:     A string containing the path to a file or folder
    %
    %   Output parameters:
    %   sOutputName:    A string containing a version of the provided path
    %                   without any characters that would prevent its use
    %                   as a struct field name.
    
    % Checking if the provided string is empty
    if isempty(sInputPath)
        sOutputName = '';
        warning('V_HAB:normalizePath','The string you have provided to the normalizePath() function is empty.');
        return;
    end
    
    % Checking if there are any space characters in the string. This is not
    % permitted, so we throw an error. 
    if contains(sInputPath, ' ')
        error('VHAB:normalizePath', ['The file you are adding\n(%s)\n', ... 
              'contains space characters in its path. This is not permitted within V-HAB/MATLAB.\n'...
              'Please change all file and folder names accordingly.'], sInputPath);
    end
    
    % The path will contain characters that denote a folder as either a
    % MATLAB package ('+') or a class folder ('@') and operating
    % system-dependent file separator characters ('/' or '\'). These
    % symbols cannot be used in field names, so we create a set of
    % replacements.
    tSeparators = struct('package', '__', ...
        'class',   '_aaat_', ...
        'filesep', '_p_');
    
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
    
end
