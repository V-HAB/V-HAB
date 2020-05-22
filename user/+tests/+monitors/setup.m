classdef setup < simulation.infrastructure
    %SETUP Test for logging with dumping, time step and mass balance observers
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
        % This class does not have any properties.
    end
    
    methods
        % Constructor function
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) 
            
            % Passing parameters for dumping and pre-allocating to the
            % logger.
            ttMonitorConfig.oLogger = struct('cParams', {{ true, 100000 }});
            
            % Activating the time step observer monitor. Use this for
            % debugging only since it slows down the simulation a bit.
            ttMonitorConfig.oTimeStepObserver = struct('sClass', 'simulation.monitors.timestepObserver', 'cParams', {{ 0 }});
            
            ttMonitorConfig.oMassBalanceObserver.sClass = 'simulation.monitors.massbalanceObserver';
            fAccuracy = 1e-8;
            fMaxMassBalanceDifference = inf;
            bSetBreakPoints = false;
            ttMonitorConfig.oMassBalanceObserver.cParams = { fAccuracy, fMaxMassBalanceDifference, bSetBreakPoints };
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Test_Monitors', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.simple_flow.systems.Example(this.oSimulationContainer, 'Example');
            
            % Setting the simulation duration to one hour. Time is always
            % in units of seconds in V-HAB.
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 3600;
            else 
                this.fSimTime = fSimTime;
            end
            
        end
        
        % Logging function
        function configureMonitors(this)
            % To make the code more legible, we create a local variable for
            % the logger object.
            oLogger = this.toMonitors.oLogger;

            % Adding the tank temperatures to the log
            oLogger.addValue('Example:s:Tank_1:p:Tank_1_Phase_1', 'fTemperature', 'K', 'Temperature Phase 1');
            oLogger.addValue('Example:s:Tank_2:p:Tank_2_Phase_1', 'fTemperature', 'K', 'Temperature Phase 2');
            
            % Adding the tank pressures to the log
            oLogger.addValue('Example:s:Tank_1:p:Tank_1_Phase_1', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 1');
            oLogger.addValue('Example:s:Tank_2:p:Tank_2_Phase_1', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 2');
            
            % Adding the branch flow rate to the log
            oLogger.addValue('Example.toBranches.Branch', 'fFlowRate', 'kg/s', 'Branch Flow Rate');
            
        end
        
        % Plotting function
        function plot(this) 
            % First we get a handle to the plotter object associated with
            % this simulation.
            oPlotter = plot@simulation.infrastructure(this);
            
            % Creating three plots arranged in a 2x2 matrix. The first
            % contains the two temperatures, the second contains the two
            % pressures and the third contains the branch flow rate. 
            coPlots{1,1} = oPlotter.definePlot({'"Temperature Phase 1"', '"Temperature Phase 2"'}, 'Temperatures');
            coPlots{1,2} = oPlotter.definePlot({'"Pressure Phase 1"', '"Pressure Phase 2"'}, 'Pressure');
            coPlots{2,1} = oPlotter.definePlot({'"Branch Flow Rate"'}, 'Flowrate');
            
            % Creating a figure containing the three plots. By passing in a
            % struct with the 'bTimePlot' field set to true, we create an
            % additional plot showing the relationship between simulation
            % steps and simulated time.
            oPlotter.defineFigure(coPlots, 'Tank Temperatures', struct('bTimePlot',true));
            
            % Plotting all figures (in this case just one). 
            oPlotter.plot();
            
        end
        
    end
    
end

