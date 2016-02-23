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
            this@simulation.infrastructure('Tutorial_Manual_Solver', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation.
            tutorials.manual_solver.systems.Example(this.oSimulationContainer, 'Example');
                       
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3000 * 1; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;
            
        end
        
        function configureMonitors(this)
            % Logging
            oLog = this.toMonitors.oLogger;
            oLog.add('Example', 'flow_props');
            
            % Define plots
            oPlot = this.toMonitors.oPlotter;
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
        end
        
        function plot(this) % Plotting the results
            this.toMonitors.oPlotter.plot();

        end
        
    end
    
end

