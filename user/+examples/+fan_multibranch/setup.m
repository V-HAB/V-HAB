classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the top-level system
    %   - set the simulation duration
    %   - determine which items are logged
    %   - determine how results are plotted
    %   - provide methods for plotting the results
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Example_Fan_Loop_Flow', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            
            examples.fan_multibranch.systems.Example(this.oSimulationContainer, 'Example');
            
            % Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 1800 * 1; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            % Logging
            oLog = this.toMonitors.oLogger;
            oLog.add('Example','flowProperties');
        end
        
        function plot(this, varargin) % Plotting the results
            % Define Plots
            oPlotter = plot@simulation.infrastructure(this);
            oPlotter.plot();
        end
        
    end
    
end

