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
            
            this@simulation.infrastructure('Tutorial_Heat_Exchanger', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the root object
            tutorials.heat_exchanger.systems.Example(this.oSimulationContainer, 'Example');

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 10; % In seconds
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Example', 'flow_props');
            oLog.add('Example', 'thermal_properties');
            
            oLog.addValue('Example', 'toProcsF2F.HeatExchanger_1.fHeatFlow', 'W', 'Heat Flow');
            oLog.addValue('Example', 'toProcsF2F.HeatExchanger_2.fHeatFlow', 'W', 'Heat Flow');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlot('Pa',  'Tank Pressures');
            oPlot.definePlot('K',   'Temperatures');
            oPlot.definePlot('kg',  'Tank Masses');
            oPlot.definePlot('kg/s','Flow Rates');
            oPlot.definePlot('W', 'Heat Flows');
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
          
            this.toMonitors.oPlotter.plot();
        end
        
    end
    
end

