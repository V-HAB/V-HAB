function [sSystemLabel, sPath] = createFolders(filepath)
%% Create Folders if they do not yet exists
sCurrentFolder = pwd;

sUserFolder = [sCurrentFolder, filesep, 'user'];

sDrawIoFolder = '+DrawIoImport';
% create the folder if it doesn't exist already.
if  ~exist(fullfile(sUserFolder, sDrawIoFolder), 'dir')
    mkdir(sUserFolder, sDrawIoFolder);
end

sPath = [sUserFolder, filesep, sDrawIoFolder];

% Extract the name of the xml file to use it for the V-HAB folder into
% which the import is placed
miSeperations = strfind(filepath, filesep);
miDots = strfind(filepath, '.');

sFileName = filepath((miSeperations(end)+1):(miDots(end)-1));
sFileName = tools.normalizePath(sFileName);
sSystemLabel = ['+', sFileName];

if ~exist(fullfile(sPath, sSystemLabel), 'dir')
    mkdir(sPath, sSystemLabel);
else
    sOldSystemLabel = sSystemLabel;
    while exist(fullfile(sPath, sSystemLabel), 'dir')
        sLastThreeDigits = sSystemLabel(end-2:end);
        if all(ismember(sLastThreeDigits, '0123456789'))
            iCurrentNumber = str2num(sLastThreeDigits);
            iCurrentNumber = iCurrentNumber + 1;
            sSystemLabel = sSystemLabel(1:end-3);
            if iCurrentNumber < 10
                sSystemLabel = [sSystemLabel, '00', num2str(iCurrentNumber)];
            elseif iCurrentNumber < 100
                sSystemLabel = [sSystemLabel, '0', num2str(iCurrentNumber)];
            end
        else
            sSystemLabel = [sSystemLabel, '_001'];
        end
    end
    fprintf('\nYou already have an imported draw io V-HAB system with the name %s!\nIncreased number increment and created a new folder called %s for this import\n\n', sOldSystemLabel, sSystemLabel)
end

sPath = [sPath, filesep, sSystemLabel];

% remove the + from the label to be used in dot referencing matlab code
sSystemLabel = sSystemLabel(2:end);

if ~exist(fullfile(sPath, '+systems'), 'dir')
    mkdir(sPath, '+systems');
end
end