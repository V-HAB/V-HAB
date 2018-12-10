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
        % This class does not have any properties.
    end
    
    methods
        % Constructor function
        function this = setup(ptConfigParams, tSolverParams)
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Simple_Circuit', ptConfigParams, tSolverParams, struct());
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.simple_circuit.systems.Example(this.oSimulationContainer, 'Example');
            
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 100 * 1; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        % Logging function
        function configureMonitors(this)
            % To make the code more legible, we create a local variable for
            % the logger object.
            oLogger = this.toMonitors.oLogger;
            
            % Using a helper, we add a bunch of values to the log.
            oLogger.add('Example', 'electrical_properties');
        
        end
        
        % Plotting function
        function plot(this)
            % First we get a handle to the plotter object associated with
            % this simulation.
            oPlotter = plot@simulation.infrastructure(this);
            
            % We're not going to define any plots, that will cause the
            % plotter to create a default plot for us, which is good enough
            % in this case. 
            oPlotter.plot();
            
        end
        
    end
    
end

