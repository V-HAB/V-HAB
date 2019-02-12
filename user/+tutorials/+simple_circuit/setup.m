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
        tiLogValues;
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            % vhab.exec always passes in ptConfigParams, tSolverParams
            % If not provided, set to empty containers.Map/struct
            % Can be passed to vhab.exec:
            %
            % ptCfgParams = containers.Map();
            % ptCfgParams('Tutorial_Simple_Flow/Example') = struct('fPipeLength', 7);
            % vhab.exec('tutorials.simple_flow.setup', ptCfgParams);
            
            
            % By Path - will overwrite (by definition) CTOR value, even 
            % though the CTOR value is set afterwards!
            %%%ptConfigParams('Tutorial_Simple_Flow/Example') = struct('fPipeLength', 7);
            
            
            % By constructor
            %%%ptConfigParams('tutorials.simple_flow.systems.Example') = struct('fPipeLength', 5, 'fPressureDifference', 2);
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            %%%ttMonitorConfig.oConsoleOutput = struct('cParams', {{ 50 5 }});
            
            %tSolverParams.rUpdateFrequency = 0.1;
            %tSolverParams.rHighestMaxChangeDecrease = 100;
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Simple_Circuit', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.simple_circuit.systems.Example(this.oSimulationContainer, 'Example');
            
            % This is an alternative to providing the ttMonitorConfig above
            %this.toMonitors.oConsoleOutput.setReportingInterval(10, 1);
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 100 * 1; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            this.tiLogValues = oLog.add('Example', 'electricalProperties');
        
        end
        
        function plot(this) % Plotting the results
            % First we get a handle to the plotter object associated with
            % this simulation.
            oPlotter = plot@simulation.infrastructure(this);
            
            % Converting the tiLogValues struct into a cell with just the
            % values of the indexes
            ciLogValues = struct2cell(this.tiLogValues);
            
            % Defining a filter for voltages
            tPlotOptions = struct('tUnitFilter', struct('sUnit','V'));
            % Creating the voltage plot
            coPlots{1,1} = oPlotter.definePlot(ciLogValues, 'Voltages', tPlotOptions);
            
            % Defining a filter for currents
            tPlotOptions = struct('tUnitFilter', struct('sUnit','A'));
            % Creating the current plot
            coPlots{2,1} = oPlotter.definePlot(ciLogValues, 'Currents', tPlotOptions);
            
            % Defining the figure
            oPlotter.defineFigure(coPlots, 'Results');
            
            % Plotting 
            oPlotter.plot();
        end
        
    end
    
end

