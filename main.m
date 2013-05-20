clc
clear all
%close all
clear classes

oTimer = event.timer(1e-8);

% Basic simulation data
oData = data(struct(...
    'oMT',    matter.table(), ...
    'oTimer', oTimer, ...
    'fTime',  0, ...                 % [s]
    ... the 2nd and 3rd parameters are solver limits, used to determine the tick length.
    ... First param: if flow rate changed (last tick - this tick) more than this ratio, time step is reduced
    ... Second param: max change in phase masses in next time step (this tick - next tick)
    ... reduce if flow rates/pressures unstable, increase if simulation too slow
    ... Third/Fourth: take X ticks of flow rate / mass change into account for checks
    'oSolver', solver.basic.solver(oTimer, 0.1, 0.001, 10, 10) ...
));

% Creating the root system
oRoot = systems.root('ROOT', oData);

% Creating a PLSS object
oExample = tutorial.flow.Example(oRoot, 'Example');


% Add system to solver
oData.oSolver.addSystem(oExample);


% Cleaning up the workspace
clear oData oExample oTimer ans;

% Creating a cell setting the log items
csLog = {
    % System timer
    'oData.oTimer.fTime';
    
    % Add other parameters here
    'toChildren.Example.toStores.Tank_1.aoPhases.fPressure';
    'toChildren.Example.toStores.Tank_2.aoPhases.fPressure';
    
    'toChildren.Example.aoBranches(1).fFlowRate';
    };

%% Simulation preparation

%Number of simulation timesteps
fTime  = 3600 * 1;%0.5;

% Matrix for datalogging; preallocate with fTime.
iLogInt = 1;
mfLog = nan(1000, length(csLog));
% Array of indices used during logging
aiLog = 1:length(csLog);


fNextDisp = 0;
fElapsed  = 0;

fLastTickDisp = 0;
hElapsed = tic();

iI = 0;

while oRoot.oData.oTimer.fTime < fTime
    iI = iI + 1;
    
    %if iI == 700, keyboard(); end;
    
    % Performing one single simulation time step by calling the step()
    % function
    oRoot.oData.oTimer.step();
    
    % Logging
    if mod(iI, iLogInt) == 0
        iTmpSize = size(mfLog, 1);
        
        if iI / iLogInt > iTmpSize
            mfLog((iTmpSize + 1):(iTmpSize + 1000), :) = nan(1000, length(csLog));
        end
        
        for iL = aiLog
            mfLog(iI / iLogInt, iL) = eval([ 'oRoot.' csLog{iL} ]);
        end
    end
    
    if mod(iI, 100) == 0
        disp([ num2str(iI) ' (' num2str(oRoot.oData.oTimer.fTime - fLastTickDisp) 's)' ]);
        fLastTickDisp = oRoot.oData.oTimer.fTime;
    end
    
    if oRoot.oData.oTimer.fTime >= fNextDisp
        fNextDisp = fNextDisp + 60;
        fElapsed  = fElapsed + toc(hElapsed);
        
        disp([ 'Sim  Time: ' tools.secs2hms(oRoot.oData.oTimer.fTime) ]);
        disp([ 'Real Time: ' tools.secs2hms(fElapsed) ]);
        
        hElapsed = tic();
    end
end

fElapsed = fElapsed + toc(hElapsed);
disp('-----------------');
disp([ 'Total real time in seconds: ' num2str(fElapsed) ]);
disp([ 'Total sim  time in seconds: ' num2str(oRoot.oData.oTimer.fTime) ]);
disp([ 'Factor: ' num2str(oRoot.oData.oTimer.fTime / fElapsed) ' [%]' ]);

%% Displaying the simulation results

figure('name', 'Tank Pressures');
hold on;
grid minor;
plot(mfLog(:,1), mfLog(:, 2:3));
legend('Tank 1', 'Tank 2');
ylabel('Pressure in Pa');
xlabel('Time in s');

figure('name', 'Flow Rate');
hold on;
grid minor;
plot(mfLog(:,1), mfLog(:, 4));
legend('Branch');
ylabel('flow rate [kg/s]');
xlabel('Time in s');

figure('name', 'Time Step');
hold on;
grid minor;
plot(1:length(mfLog(:,1)), mfLog(:, 1), '-*');
legend('Solver');
ylabel('Time Step [kg/s]');
xlabel('Time in s');
