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
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation('Tutorial_Loop_Flow');
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.loop_flow.systems.Example(this.oRoot, 'Example');
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';                                        % 1
                
                % Add other parameters here
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fPressure';  % 2
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMass';
                'toChildren.Example.aoBranches(1).fFlowRate';                % 4
                
                };
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 100 * 1; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;

        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            
            close all
            
            figure('name', 'Tank Pressure');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 2));
            legend('Tank 1');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Tank Mass');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 3));
            legend('Tank 1');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 4));
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

