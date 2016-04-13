classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, fSimTime) % Constructor function
            
            this@simulation.infrastructure('Tutorial_Linearized_Solver', ptConfigParams, tSolverParams);
            
            tutorials.linearized_solver.systems.Example(this.oSimulationContainer, 'Example_Sys');
            
            
            

            %% Simulation length
            
            if nargin < 3 || isempty(fSimTime)
                fSimTime = 3600;
            end
            
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = fSimTime; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        
        
        function configureMonitors(this)
            
            %this.toMonitors.oConsoleOutput.setReportingInterval(10, 1);
            
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            tiFlowProps = oLog.add('Example_Sys', 'flow_props');
            
            
            
            

            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            %oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
            
            

        end
        
        function plot(this) % Plotting the results
            
            this.toMonitors.oPlotter.plot();
            
        end
        
    end
    
end

