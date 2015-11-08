function tOutputStruct = removeIllegalFilesAndFolders(tInputStruct)
%REMOVEILLEGALFILESANDFOLDERS Removes files and foldes from an input struct
%   There are some files and folders from the operating system and git that 
%   begin with a '.' (period) character. Also MATLAB creates temporary 
%   files with '*.asv' and '*.m~' extensions on Windows and Mac OS 
%   respectively. When operating on files in a folder, these files need to
%   be excluded and that is exactly hat this function does. 
%
%   Input parameters:
%   tInputStruct    This is the result returned by calling MATLAB's dir()
%                   method for a certain file or folder. 
%
%   Output parameters:
%   tOuputStruct    The returned struct is identical to the input struct in
%                   terms of its structure, but the illegal files and
%                   folders are removed. 

%Initializing a helper array
abIllegals = zeros(1,length(tInputStruct));

% First we need to find the illegal files
for iI = 1:length(tInputStruct)
    if ~isempty(strfind(tInputStruct(iI).name(1),'.')) || ...
       ~isempty(strfind(tInputStruct(iI).name,'~'))
       abIllegals(iI) = 1;
    end
end

% Setting the return variable
tOutputStruct = tInputStruct;

% Delete the entries from the struct
tOutputStruct(abIllegals > 0) = [];

end