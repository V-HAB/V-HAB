function [  ] = findSmallestTimeStep( oInput )
    % This function is used to read the data that the timestep_observer
    % stored for debugging and displays the location, tick and timestep of
    % the component with the smallest timestep in the last 100 ticks.
    % Simply call it after finishing or pausing a simulation by typing
    % tools.findSmallestTimeStep(oLastSimObj) in your command window.
    
    try 
        oTimeStepObserver = oInput.toMonitors.oTimeStepObserver;
    catch
        str = 'it seems like you did not activate the timestep observer, please go to your setup file and replace ttMonitorConfig = struct(); with ttMonitorConfig = struct(''oTimeStepObserver'', struct(''cParams'', {{ 0 }}));';
        error(str);
    end
    
    % go through the stored values and select the one with the absolute
    % smallest time step
    fMinStep = inf;
    if isempty(oTimeStepObserver.tDebug)
        error('it seems like you did not activate the timestep observer');
    else
        for iDebug = 1:length(oTimeStepObserver.tDebug)
            if oTimeStepObserver.tDebug(iDebug).fTimeStep < fMinStep
                fMinStep  = oTimeStepObserver.tDebug(iDebug).fTimeStep;
                csReports = oTimeStepObserver.tDebug(iDebug).csReport;
            end
        end
        % then display the reports for that 
        disp(' ');
        for iReport = 1:length(csReports)
            disp(csReports{iReport});
        end
        disp(' ');
    end
end

