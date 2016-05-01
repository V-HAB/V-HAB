classdef setup < simulation.infrastructure
    % setup file for the Greenhouse system
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % call superconstructor (with possible altered monitor configs)
            this@simulation.infrastructure('GreenhouseV2', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            warning('off', 'all');
            
            % Create Root Object - Initializing system 'Greenhouse'
            tutorials.GreenhouseV2.systems.GreenhouseV2(this.oSimulationContainer, 'GreenhouseV2');
            
            % set simulation time
            this.fSimTime  = 20e6;      % [s]
            
            % if true, use fSimTime for simulation duration, if false use
            % iSimTicks below
            this.bUseTime  = true;      
            
            % set amount of simulation ticks
            this.iSimTicks = 400;       % [ticks]
        end
        
        function configureMonitors(this)
            %% Logging Setup
            oLogger = this.toMonitors.oLogger;
            
            % general logging parameters, greenhouse system
            oLogger.add('GreenhouseV2', 'flow_props');
            oLogger.add('GreenhouseV2', 'thermal_properties');
            
            % log culture subsystems
            for iI = 1:length(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures)
                oLogger.add([this.oSimulationContainer.toChildren.GreenhouseV2.toChildren.(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI})], 'flow_props');
            end
            
            %% Define Plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('K',  'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
        end
        
        function plot(this)
            close all
           
            this.toMonitors.oPlotter.plot();
        end
    end
end