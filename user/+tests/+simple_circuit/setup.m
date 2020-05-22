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
        % A cell containing all log items
        ciLogValues;
    end
    
    methods
        % Constructor function
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime)
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Test_Simple_Circuit', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.simple_circuit.systems.Example(this.oSimulationContainer, 'Example');
            
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 100;
            else 
                this.fSimTime = fSimTime;
            end
            this.fSimTime = 100 * 1; % In seconds
        end
        
        % Logging function
        function configureMonitors(this)
            %% Logging
            % To make the code more legible, we create a local variable for
            % the logger object.

            oLog = this.toMonitors.oLogger;

            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            this.ciLogValues = oLog.add('Example', 'electricalProperties');
        
        end
        
        function plot(this) % Plotting the results
            % First we get a handle to the plotter object associated with
            % this simulation.
            oPlotter = plot@simulation.infrastructure(this);
            
            % Defining a filter for voltages
            %tPlotOptions = struct('tUnitFilter', struct('sUnit','V'));
            tPlotOptions = struct(); 
            % Creating the voltage plot
            coPlots{1,1} = oPlotter.definePlot(this.ciLogValues, 'Voltages', tPlotOptions);
            
            % Defining a filter for currents
            %tPlotOptions = struct('tUnitFilter', struct('sUnit','A'));
            tPlotOptions = struct(); 
            % Creating the current plot
            coPlots{2,1} = oPlotter.definePlot(this.ciLogValues, 'Currents', tPlotOptions);
            
            % Defining the figure
            oPlotter.defineFigure(coPlots, 'Results');
            
            % Plotting 
            oPlotter.plot();
        end
        
    end
    
end

