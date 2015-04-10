classdef setup < simulation
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
    end
    
    methods
        function this = setup() % Constructor function
            this@simulation('Tutorial_Subsystems');
            
            % Creating the root object
            oExample = tutorials.subsystems.systems.Example(this.oRoot, 'Example');
            
            
            %% Ignore the contents of this section
            % Set a veeery high fixed time step - the solver will still be
            % called by the phase update methods!
            %oB1.fFixedTS = 10000;
            
            aoPhases = this.oRoot.toChildren.Example.toChildren.SubSystem.toStores.Filter.aoPhases;
            aoPhases(1).bSynced = true;
            
            % Set fixed time steps for all phases, synced. Means that every
            % tick each phase and both branches are solved.
            % Decrease if flow rates unstable, increase if too slow. If un-
            % stable AND too slow, buy a new computer.
            aoPhases = this.oRoot.toChildren.Example.toStores.Tank_1.aoPhases;
            aoPhases(1).fFixedTS = 0.5;
            aoPhases = this.oRoot.toChildren.Example.toStores.Tank_2.aoPhases;
            aoPhases(1).fFixedTS = 0.5;
            
            %% Logging
            % Creating a cell setting the log items
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';                                                   % 1
                
                % Add other parameters here
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fPressure';             % 2
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMass';
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fPressure';             % 4
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fMass';
                'toChildren.Example.toChildren.SubSystem.aoBranches(1).fFlowRate';      % 6
                'toChildren.Example.toChildren.SubSystem.aoBranches(2).fFlowRate';      % 7
                'toChildren.Example.toChildren.SubSystem.toStores.Filter.aoPhases(1).fPressure';   % 8
                'toChildren.Example.toChildren.SubSystem.toStores.Filter.aoPhases(1).fMass';       % 9
                'toChildren.Example.toChildren.SubSystem.toStores.Filter.aoPhases(2).fPressure';   % 10
                'toChildren.Example.toChildren.SubSystem.toStores.Filter.aoPhases(2).fMass';       % 11
                'toChildren.Example.toChildren.SubSystem.aoBranches(2).fFlowRate';                 % 12
                'toChildren.Example.toStores.Tank_1.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.O2)';%13
                'toChildren.Example.toStores.Tank_2.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.O2)';%14
                
                
                };
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 400 * 1; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;

        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            
            close all
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [2 4 8]));
            legend('Tank 1', 'Tank 2', 'Filter');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [3 5 9 11]));
            legend('Tank 1', 'Tank 2', 'Filter', 'Absorber');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [6 7 12]));
            legend('In', 'Out', 'Filter Flow');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'O2 Percentages');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [13 14]) * 100);
            legend('Tank 1', 'Tank 2');
            ylabel('O2 [%]');
            xlabel('Time in s');

            figure('name', 'Time Steps');
            hold on;
            grid minor;
            plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
            legend('Solver');
            ylabel('Time in [s]');
            xlabel('Ticks');
            
            tools.arrangeWindows();
        end
        
    end
    
end
