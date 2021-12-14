classdef setup < simulation.infrastructure
    properties
        % A cell containing all log items
        ciLogValues;
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            this@simulation.infrastructure('Tutorial_Simple_Circuit', ptConfigParams, tSolverParams, struct());
            
            tutorials.simple_circuit.systems.Example(this.oSimulationContainer, 'Example');
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 100 * 1; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            this.ciLogValues = oLog.add('Example', 'electricalProperties');
        
        end
        
        function plot(this) 
            
            oPlotter = plot@simulation.infrastructure(this);
            
            % Initializing the plot options struct
            tPlotOptions = struct();

            % Defining a filter for voltages
            tPlotOptions.tFilter = struct('sUnit','V');
            
            % Creating the voltage plot
            coPlots{1,1} = oPlotter.definePlot(this.ciLogValues, 'Voltages', tPlotOptions);

            % Defining a filter for currents
            tPlotOptions.tFilter = struct('sUnit','A');
            
            % Creating the current plot
            coPlots{2,1} = oPlotter.definePlot(this.ciLogValues, 'Currents', tPlotOptions);
            
            % Defining the figure
            oPlotter.defineFigure(coPlots, 'Results');
            
            % Plotting 
            oPlotter.plot();
        end
    end
end