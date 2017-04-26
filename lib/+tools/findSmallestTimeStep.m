function [ csReports ] = findSmallestTimeStep( oInput , fLimit)
% findSmallestTimeStep is intended to be used within the run function of
% the timer class in V-HAB (but it can also be used at a different
% location, as long as the timer object is provided as input). If it is not
% used within the timer it is possible that the smallest timestep is missed
% by this function! Therefore the recommended usage is to open the
% core/event/timer.m file and search for the name of this function. You
% will find an outcommented section of code that you can use to implement
% this function!
%
% If no limit is provided (standard use case) the function will only write
% the report strings containing the locations of the smallest time step
% occurances into the timer object (for the last 100 ticks) together with
% the time step for that tick. If you now stop a simulation and call this
% function but provide the oLastSimObj as input it will automatically look
% through the stored values and pick the overall smallest step from the
% last 100 ticks and display its report strings in the command window
% telling you the exact location of the smallest time step and the
% simulation tick in which it occured (which is helpful if you want to set
% a breakpoint to the specific location). Note in case you get an empty
% report string an unexpected object (one that is not defined below) used a
% time step and you have to add it to this function or call our advisor and
% hope you receive help ;)
% If you set a limit (within the Timer) the function will additional
% display the report string in the command window during the simulation run

if isa(oInput, 'event.timer')
    if nargin < 2
        fLimit = 0;
    end
    % Minimal Time Step is the minimum value in afTimeStep
    fMinStep = min(oInput.afTimeStep(oInput.afTimeStep >= 0));
    
    miIndexMinStep = find(oInput.afTimeStep == fMinStep);
    % The time steps in afTimeStep belong to the respective callback within
    csReports = cell(length(miIndexMinStep),1);
    for iIndex = 1:length(miIndexMinStep)
        tInfo = functions(oInput.cCallBacks{miIndexMinStep(iIndex)});
        oCaller = tInfo.workspace{1}.this;
        
        if isa(oCaller, 'matter.phase')
            csReports{iIndex} = ['In the system ', oCaller.oStore.oContainer.sName, ' in Store ', oCaller.oStore.sName, ' in Phase ', oCaller.sName, ' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(oInput.iTick), ' for the function ', tInfo.function];
        
        elseif isa(oCaller, 'matter.store')
            csReports{iIndex} = ['In the system ', oCaller.oContainer.sName, ' in Store ', oCaller.sName, ' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(oInput.iTick)];
            
        elseif isa(oCaller, 'vsys')
            csReports{iIndex} = ['In the system ', oCaller.sName, ' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(oInput.iTick)];
            
        elseif isa(oCaller, 'solver.thermal.lumpedparameter')
            csReports{iIndex} = ['The lumped parameter thermal solver in the system ', oCaller.oVSys.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(oInput.iTick)];
        end
    end
    
    % if the limit is undercut the program will display the location of the
    % minimal timestep in the command window (if you want to debug, just
    % set a break point in here
    if fMinStep < fLimit && fMinStep > 0
        for iReport = 1:length(csReports)
            disp(csReports{iReport});
        end
    end
else
    oTimer = oInput.oSimulationContainer.oTimer;
    % go through the stored values and select the one with the absolute
    % smallest time step
    fMinStep = inf;
    if isempty(oTimer.tDebug)
        error('it seems like you did not activate the smallest time step functionality in the timer. Please go to core/event/timer.m and search for the name of this function to find the section of code you have to use');
    else
        for iDebug = 1:length(oTimer.tDebug)
            if oTimer.tDebug(iDebug).fTimeStep < fMinStep
                fMinStep  = oTimer.tDebug(iDebug).fTimeStep;
                csReports = oTimer.tDebug(iDebug).csReport;
            end
        end
        % then display the reports for that 
        for iReport = 1:length(csReports)
            disp(csReports{iReport});
        end
    end
end
end

