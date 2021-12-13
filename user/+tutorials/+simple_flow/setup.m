classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
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
        function this = setup(varargin) 
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Simple_Flow', containers.Map(), struct(), struct());
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.simple_flow.systems.Example(this.oSimulationContainer, 'Example');
            
            % Setting the simulation duration to one hour. Time is always
            % in units of seconds in V-HAB.
            this.fSimTime = 3600;
            
        end
        
        % Logging function
        function configureMonitors(this)
            % To make the code more legible, we create a local variable for
            % the logger object.
            oLogger = this.toMonitors.oLogger;

            % Adding the tank temperatures to the log. For the path the
            % following shorthands are available:
            % :c: for .toChildren.
            % :s: for .toStores.
            % :p: for .toPhases.
            % :b: for .toBranches.
            % :t: for .toThermalBranches.
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