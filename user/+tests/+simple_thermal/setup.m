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
            this@simulation.infrastructure('Test_Simple_Thermal', containers.Map(), struct(), struct());
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.simple_thermal.systems.Example(this.oSimulationContainer, 'Example');
            
            % Setting the simulation duration to one hour. Time is always
            % in units of seconds in V-HAB.
            this.fSimTime = 3600;
            
        end
        
        % Logging function
        function configureMonitors(this)
            % To make the code more legible, we create a local variable for
            % the logger object.
            oLogger = this.toMonitors.oLogger;

            % Adding the thermal properties to the log
            oLogger.add('Example', 'thermalProperties');
            
        end
        
        % Plotting function
        function plot(this) 
            % First we get a handle to the plotter object associated with
            % this simulation.
            oPlotter = plot@simulation.infrastructure(this);
            
            % If we don't define any plots and figures, this will produce a
            % default plot with all values sorted by unit
            oPlotter.plot();
            
        end
        
    end
    
end

