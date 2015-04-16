function saveFigures(varargin)
%SAVEFIGURES Saves all open figures into a folder
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


oGraphicsRoot = get(groot);

aoFigures = oGraphicsRoot.Children;

sFolderPath = 'data/figures/';

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

sFolderName = strrep([sFolderPath, sName], '/', filesep);

sTimeStamp  = datestr(datetime('now'), 'yyyymmddHHMM');

if ~isdir(sFolderName)
    mkdir(strrep(sFolderPath, '/', filesep), sName);
end

if nargin > 1 
    if ischar(varargin{2})
        sName = varargin{2};
    else
        disp('Error: The second input argument for the saveFigures() method must be a string!');
        return;
    end
end

sFileName = strrep([sFolderName, '/', sTimeStamp, '_', sName], '/', filesep);

savefig(aoFigures, sFileName);

end

