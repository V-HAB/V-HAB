classdef setup < simulation.infrastructure
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
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Liquid_Flow', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.liquid_flow.systems.Example(this.oSimulationContainer, 'Example');
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 500 * 1; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;

        end
        function configureMonitors(this,~)
            %% Logging
            
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Example', 'flow_props');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlot('Pa', 'Tank Pressures');
            oPlot.definePlot('kg', 'Tank Masses');
            oPlot.definePlot('kg/s', 'Flow Rates');
            
            
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            this.toMonitors.oPlotter.plot();
            return;
%             close all
%             
%             figure('name', 'Tank Pressures');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [2 4]));
%             legend('Tank 1', 'Tank 2');
%             ylabel('Pressure in Pa');
%             xlabel('Time in s');
%             
%             figure('name', 'Tank Masses');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [3 5]));
%             legend('Tank 1', 'Tank 2');
%             ylabel('Mass in kg');
%             xlabel('Time in s');
%             
%             figure('name', 'Flow Rate');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, 6));
%             legend('Branch');
%             ylabel('flow rate [kg/s]');
%             xlabel('Time in s');
%             
%             figure('name', 'Time Steps');
%             hold on;
%             grid minor;
%             plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
%             legend('Solver');
%             ylabel('Time in [s]');
%             xlabel('Ticks');
%                         
%             tools.arrangeWindows();
        end
        
    end
    
end

