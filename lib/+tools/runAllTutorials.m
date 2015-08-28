function runAllTutorials()
%RUNALLTUTORIALS Runs all tutorials and saves the figures to a folder
%   This function is a debugging helper. It will run all tutorials inside
%   the user/+tutorials folder and save the resulting figures to
%   data/Tutorials_Testrun/ with a timestamp. The only condition for this
%   to work is that the class file that inherits from simulation.m is on
%   the top level of the tutorial folder and is called 'setup.m'. If this
%   is not the case, the function will throw an error. 

% First we get the struct that shows us the current contents of the
% tutorials directory.
sTutorialDirectory = strrep('user/+tutorials/','/',filesep);
tTutorials = dir(sTutorialDirectory);

% Initializing some counters
iSuccessfulTutorials = 0;
iSkippedTutorials    = 0;
iAbortedTutorials    = 0;

% Initializing a helper array
abIllegals = zeros(1,length(tTutorials));

for iI = 1:length(tTutorials)
    % There are some files from the operating system and git that contain a
    % '.' (period) character. 
    if strfind(tTutorials(iI).name,'.')
        % First we need to find them
        abIllegals(iI) = 1;
    end
end
% Now we can delete the entries from the struct
tTutorials(abIllegals > 0) = [];

% Generating a dynamic folder path so all of our saved data is nice and
% organized.
sFolderPath = createFolderPath();

% Now we go through each item in the struct and see if we can execute a
% V-HAB simulation. 
for iI = 1:length(tTutorials)
    
    % If the folder has a correctly named 'setup.m' file, we can go
    % ahead and try to execute it.
    if exist([sTutorialDirectory,tTutorials(iI).name,filesep,'setup.m'],'file')
        
        % First we construct the string that is the argument for the
        % vhab.exec() method.
        sExecString = ['tutorials.',strrep(tTutorials(iI).name,'+',''),'.setup'];
        
        % Some nice printing for the console output
        
        fprintf('\n\n======================================\n');
        fprintf('Running %s Tutorial\n',strrep(tTutorials(iI).name,'+',''));
        fprintf('======================================\n\n');
        
        % Now we can finally run the simulation, but we need to catch
        % any errors inside the simulation itself
        try
            oLastSimObj = vhab.exec(sExecString);
            
            % Done! Let's plot stuff!
            oLastSimObj.plot();
            
            % Saving the figures to the pre-determined location
            tools.saveFigures(sFolderPath, strrep(tTutorials(iI).name,'+',''));
            
            % Closing all windows so we can see the console again. The
            % drawnow() call is necessary, because otherwise MATLAB would
            % just jump over the close('all') instruction and run the next
            % sim. Stupid behavior, but this is the workaround.
            close('all');
            drawnow();
            
            % Since we've now actually completed the simulation, we can
            % increment the counter of successful tutorials. Also we
            % can set the string property for the final output.
            iSuccessfulTutorials = iSuccessfulTutorials + 1;
            tTutorials(iI).sStatus = 'Successful';
        catch oException
            % Something went wrong inside the simulation. So we tell
            % the user and keep going. The counter for aborted
            % tutorials is incremented and the string property for the
            % final output is set accordingly.
            disp('Encountered an error in the simulation. Aborting.');
            iAbortedTutorials = iAbortedTutorials + 1;
            tTutorials(iI).sStatus = 'Aborted';
            tTutorials(iI).sErrorReport = getReport(oException);
        end
        
    else
        % In case there is no 'setup.m' file, we print this to the
        % command window, but we don't stop the skript. We increment
        % the skipped-counter and set the property.
        disp(['The ',tTutorials(iI).name,' Tutorial does not have a ''setup.m'' file. Skipping.']);
        iSkippedTutorials = iSkippedTutorials + 1;
        tTutorials(iI).sStatus = 'Skipped';
    end
    
    
end

% Now that we're all finished, we can tell the user how well everything
% went. 

% Also, because I am a teeny, tiny bit obsessive about visuals, I'm going
% to calculate how many blanks I have to insert between the colon and the
% actual status so they are nice and aligned.

% Initializing an array
aiNameLengths = zeros(1,length(tTutorials));

% Getting the lengths of each of the tutorial names. (Good thing we deleted
% the other, non-tutorial folders earlier...)
for iI = 1:length(tTutorials)
    aiNameLengths(iI) = length(tTutorials(iI).name);
end

% And now we can get the length of the longest tutorial name
iColumnWidth = max(aiNameLengths);

% Printing...
disp('--------------------------------------');
disp('======================================');
fprintf('Total Tutorials:       %i\n\n', length(tTutorials));
fprintf('Successfully executed: %i\n',   iSuccessfulTutorials);
fprintf('Aborted:               %i\n',   iAbortedTutorials);
fprintf('Skipped:               %i\n',   iSkippedTutorials);
disp('--------------------------------------');
disp('Detailed Summary:');
for iI = 1:length(tTutorials)
    % Every name should have at least two blanks of space between the colon
    % and the status, so we subtract the current name length from the
    % maximum name length and add two.
    iWhiteSpaceLength = iColumnWidth - length(tTutorials(iI).name) + 2;
    % Now we make ourselves a string of blanks of the appropriate length
    % that we can insert into the output in the following line. 
    sBlanks = blanks(iWhiteSpaceLength);
    % Tada!
    fprintf('%s:%s%s\n',tTutorials(iI).name,sBlanks,tTutorials(iI).sStatus);
end
disp('--------------------------------------');
fprintf('Error messages:\n\n');
for iI = 1:length(tTutorials)
    if strcmp(tTutorials(iI).sStatus,'Aborted')
        fprintf('%s Tutorial Error Message:\n',strrep(tTutorials(iI).name,'+',''));
        fprintf('%s\n\n',tTutorials(iI).sErrorReport);
    end
end
disp('======================================');
disp('--------------------------------------');

end

function sFolderPath = createFolderPath()
    % Initializing the variables
    bSuccess      = false;
    iFolderNumber = 1;
    
    % Getting the current date for use in the folder name
    sTimeStamp  = datestr(datetime('now'), 'yyyymmdd');
    
    % Generating the base folder path for all figures
    sBaseFolderPath = strrep('data/figures/','/',filesep);
    
    % We want to give the folder a number that doesn't exist yet. So we
    % start at 1 and work our way up until we find one that's not there
    % yet. 
    while ~bSuccess
        sFolderPath = ['Tutorials_Test',filesep,sTimeStamp,'_Test_Run_',num2str(iFolderNumber)];
        if exist([sBaseFolderPath, sFolderPath],'dir')
            iFolderNumber = iFolderNumber + 1;
        else
            bSuccess = true;
        end
    end
end
