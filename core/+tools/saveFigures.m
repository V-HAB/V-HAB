function saveFigures(varargin)
%SAVEFIGURES Saves all open figures into a folder
%
%   Usage:
%   - With a simulation object
%   saveFigures(oLastSimObj);
%   
%   - With two strings
%   saveFigures('FolderName','FileName');
%   
%   This function saves all currently open windows. It is intended to be   
%   called after a simulation run is complete or has been aborted. It 
%   creates a folder in ~/data/figures with the first parameter of varargin 
%   as a folder name. If this parameter is an object with a property called 
%   'sName', it will use this as the folder name. This is to enable usage 
%   with the 'oLastSimObj' object that all V-HAB simulations produce. 
%   Then we get the graphics root object, groot. All open figures are 
%   children of groot (groot.Children). The figures will be saved in a 
%   single .fig file with a timestamp and the the first parameter of 
%   varargin as the file name.
%   If a second parameter is given and it is a string, then this will be
%   used in the file name instead of the first parameter. This is to enable
%   differentiation between different simulation results from the same
%   models. 


% We need to do things a little differently if we are using MATLAB 2014a or older
if verLessThan('matlab','8.4.0')
    % Getting the array of figure handle objects 
    aoFigures = get(0,'Children');
    % Getting the time stamp
    sTimeStamp  = datestr(now, 'yyyymmddHHMM');
else
    % Getting the graphics root object (needs to be a separate step)
    oGraphicsRoot = get(groot);
    % Getting the array of figure handle objects 
    aoFigures = oGraphicsRoot.Children;
    % Getting the time stamp
    sTimeStamp  = datestr(datetime('now'), 'yyyymmddHHMM');
end


% Creating the folder path, if this folder doesn't exist, it will be created. In V-HAB the data
% folder should already exist. 
sFolderPath = 'data/figures/';

% If a simulation object (i.e. oLastSimObj) was passed as an input parameter, we will use its name
% as a folder name. If not, we check if a string was passed to create a user defined folder name. If
% that is also not the case, an error is thrown.
try
    sName = varargin{1}.sName;
catch
    if ischar(varargin{1})
        sName = varargin{1};
    else
        disp('Error: The first input argument for the saveFigures() method must be a string or an object with ''sName'' as a property!');
        return;
    end
end

% Now we can create the folder path
sFolderName = strrep([sFolderPath, sName], '/', filesep);

% If the folder doesn't exist yet, we create it.
if ~isdir(sFolderName)
    mkdir(strrep(sFolderPath, '/', filesep), sName);
end

% If the option with two strings was chosen, we check the second one here to use it as a file name.
% If its not a string, an error is thrown.
if nargin > 1 
    if ischar(varargin{2})
        sName = varargin{2};
    else
        disp('Error: The second input argument for the saveFigures() method must be a string!');
        return;
    end
end

% Using the folder path and the file name, we can create the entire filepath, the necessary input
% for the savefig() method.
sFilePath = strrep([sFolderName, '/', sTimeStamp, '_', sName], '/', filesep);

% Finally we can save our beloved figures!
savefig(aoFigures, sFilePath, 'compact');

fprintf('Files saved here: %s\n', sFilePath);

end