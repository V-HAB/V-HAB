classdef setup < simulation.infrastructure
    % This simulation shows a system of tanks that are calculated
    % incompressible. Tank 1, 2, 3, 4, and 8 form a loop structure while
    % Tank 5, 6 and 7 form a line structure. The loop and line are
    % completly independent from each other
    %
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Incompressible_System', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tutorials.incompressible_solver.systems.Incompressible_System(this.oSimulationContainer, 'Incompressible_System', 0);
        end
           
        
        function configureMonitors(this) 
            %Logging
            oLog = this.toMonitors.oLogger;
            
            tiFlowProps = oLog.add('Incompressible_System', 'flow_props');
            
            %Define Plots
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
                
            
            % Sim time [s]
            this.fSimTime = 30;
        end
        
         function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            this.toMonitors.oPlotter.plot();
        end
    end
end

