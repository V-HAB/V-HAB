function [sOutputName, varargout] = normalizePath(sInputPath, bUseNewSeparators)
%NORMALIZEPATH  Convert a path to a form without special characters
%   Other than underscores, not much except letters is allowed in struct
%   field names. So this function cleans any input string and replaces
%   the illegal characters with legal ones.
%
%   Input parameters: 
%   sInputPath          A string containing the path to a file or folder
%   bUseNewSeparators   (optional) A boolean variable indicating if the
%                       user would like to use a different (new) set of
%                       separators that will be used to replace illegal
%                       characters.
%
%   Output parameters:
%   sOutputName         A string containing a version of the provided path
%                       without any characters that would prevent its use
%                       as a struct field name.
%   varargout           In case more than one output variable is requested,
%                       varargout will contain a struct of the used
%                       separators. 

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
