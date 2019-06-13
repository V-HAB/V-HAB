function saveFigures(sFolderName, sFileName)
%SAVEFIGURES Saves all open figures into a folder
%
%   This function saves all currently open windows. It is intended to be
%   called after a simulation run is complete or has been aborted. It
%   creates a folder with sFolderName as the folder name. Then we get the
%   graphics root object, groot. All open figures are children of groot
%   (groot.Children). The figures will be saved in a single .fig file with
%   a timestamp and sFileName as the file name. 

% Getting the graphics root object (needs to be a separate step)
oGraphicsRoot = get(groot);
% Getting the array of figure handle objects
aoFigures = oGraphicsRoot.Children;
% Getting the time stamp
sTimeStamp  = datestr(datetime('now'), 'yyyymmddHHMM');


% If the folder doesn't exist yet, we create it.
if ~isfolder(sFolderName)
    mkdir(strrep(sFolderName, '/', filesep));
end

% Using the folder path and the file name, we can create the entire filepath, the necessary input
% for the savefig() method.
sFilePath = strrep([sFolderName, '/', sTimeStamp, '_', sFileName], '/', filesep);

% Finally we can save our beloved figures!
savefig(aoFigures, sFilePath, 'compact');

fprintf('Files saved here: %s\n', sFilePath);

end