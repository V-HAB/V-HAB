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
    'oSolver', solver.basic.solver(oTimer) ...
));

% Creating the root system
oRoot = systems.root('ROOT', oData);

% Creating a PLSS object
oExample = tutorial.flow.Example(oRoot, 'Example');


% Add system to solver
oData.oSolver.addSystem(oExample);

% Register solver on timer (0 = global timestep)
%oData.oTimer.bind(@(oTimer) oData.oSolver.solve(oTimer), 0);


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
iTicks = 1000;

% Matrix for datalogging
iLogInt = 1;
mfLog = nan(iTicks / iLogInt, length(csLog));
% Array of indices used during logging
aiLog = 1:length(csLog);


for iI = 1:iTicks
    
    % Performing one single simulation time step by calling the step()
    % function
    oRoot.oData.oTimer.step();
    
    % Logging
    if mod(iI, iLogInt) == 0
        for iL = aiLog
            mfLog(iI / iLogInt, iL) = eval([ 'oRoot.' csLog{iL} ]);
        end
    end
    
    if mod(iI, 100) == 0, disp(iI); end;
end

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
plot(mfLog(:,1), ones(size(mfLog, 1)), '-*');
legend('Solver');
ylabel('Time Step [kg/s]');
xlabel('Time in s');
