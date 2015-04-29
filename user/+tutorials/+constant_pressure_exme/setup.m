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
            this@simulation('Tutorial_Simple_Flow');
            
            
            % Decreases the default rMaxChange set by phases in .seal() by
            % a factor of 10. A manual rMaxChange set after. seal() 
            % overrides the default value.
            this.oData.set('rUpdateFrequency', 0.1);
            
            % Creating the root object
            oExample = tutorials.constant_pressure_exme.systems.Example(this.oRoot, 'Example');
            
            
            % Add branch to solver
            oB1 = solver.matter.iterative.branch(oExample.aoBranches(1));
            
            
            %% Logging
            % Creating a cell setting the log items
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';                                        % 1
                
                % Add other parameters here
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMassToPressure';  % 2
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMass';
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fMassToPressure';  % 4
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fMass';
                'toChildren.Example.aoBranches(1).fFlowRate';                % 6
                
                };
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 1000 * 3.6; % In seconds
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
            plot(this.mfLog(:,1), this.mfLog(:, [2 4]) .* this.mfLog(:, [3 5]));
            legend('Tank 1', 'Tank 2');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [3 5]));
            legend('Tank 1', 'Tank 2');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 6));
            legend('Branch');
            ylabel('flow rate [kg/s]');
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

