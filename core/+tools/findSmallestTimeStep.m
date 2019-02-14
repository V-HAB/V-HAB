function findSmallestTimeStep(oInput)
    %FINDSMALLESTTIMESTEP Finds the object setting the smallest time step
    % This function is used to read the data that the timestepObserver
    % stored for debugging and displays the location, tick and timestep of
    % the component with the smallest timestep in the last 100 ticks.
    % Simply call it after finishing or pausing a simulation by typing
    % tools.findSmallestTimeStep(oLastSimObj) in your command window.
    % To activate the monitor add:
    % ttMonitorConfig = struct('oTimeStepObserver', struct('cParams', {{ 0 }}))
    % In the setup file instead of the usual empty ttMonitorConfig, or add
    % it to existing ttMonitorConfig you use
    
    % Getting the time step observer object, tell the user why we failed.
    try 
        oTimeStepObserver = oInput.toMonitors.oTimeStepObserver;
    catch oError
        % We catch the most common error here, the user forgot to activate
        % the times step observer. If it's something else, we rethrow that
        % error. 
        if strcmp(oError.identifier, 'MATLAB:nonExistentField')
            str = 'It seems like you did not activate the timestep observer, please go to your setup file and replace ttMonitorConfig = struct(); with ttMonitorConfig = struct(''oTimeStepObserver'', struct(''cParams'', {{ 0 }}));';
            error('V_HAB:findSmallestTimeStep', str);
        else 
            rethrow(oError);
        end
    end
    
    % Going through the stored values and select the one with the absolute
    % smallest time step
    fMinStep = inf;
    for iObject = 1:length(oTimeStepObserver.tDebug)
        % If the object we are currently looking at has a smaller time step
        % than the current minimum, we make it the new minimum. Otherwise
        % we just continue. 
        if oTimeStepObserver.tDebug(iObject).fTimeStep < fMinStep
            fMinStep  = oTimeStepObserver.tDebug(iObject).fTimeStep;
            csReports = oTimeStepObserver.tDebug(iObject).csReport;
        end
    end
    
    % Now we have found the object that set the minimum time step, so we
    % can print its report to the console. 
    for iReport = 1:length(csReports)
        printf(['\n' csReports{iReport} '\n']);
    end
    
end

