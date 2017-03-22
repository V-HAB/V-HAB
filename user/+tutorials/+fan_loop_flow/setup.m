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
            warning('off','all')
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Fan_Loop_Flow', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            
            tutorials.fan_loop_flow.systems.Example(this.oSimulationContainer, 'Example');
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 1; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            %% Logging
            tiLog = this.toMonitors.oLogger.add('Example', 'flow_props');
            
            this.toMonitors.oLogger.addValue('Example.aoBranches(1).aoFlows(1)', 'fFlowRate', 'kg/s', 'Flowrate');
            
            %% Plot definition
            this.toMonitors.oPlotter.definePlot('Pa',   'Pressures')
            this.toMonitors.oPlotter.definePlot('K',    'Temperatures')
            this.toMonitors.oPlotter.definePlot('kg',   'Masses')
            this.toMonitors.oPlotter.definePlot('kg/s', 'Flow Rates')

        end
        
        function plot(this, varargin) % Plotting the results
            this.toMonitors.oPlotter.plot(varargin{:});
            
        end
        
    end
    
end

