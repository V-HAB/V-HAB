classdef Pump_and_Heater_Circle_Definition < simulation.infrastructure
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = Pump_and_Heater_Circle_Definition(ptConfigParams, tSolverParams) 
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            this@simulation.infrastructure('Compressible_Pump_Heater', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tutorials.compressible_liquid_solver.systems.Pump_and_Heater_Circle(this.oSimulationContainer, 'Pump_and_Heater_Circle');
            
            
            % Sim time [s]
            this.fSimTime = 5;
        end
        function configureMonitors(this)
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            tiFlowProps = oLog.add('Pump_and_Heater_Circle', 'flow_props');
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
            
        end
        
         function plot(this) % Plotting the results
            
            this.toMonitors.oPlotter.plot();

        end
    end
    
    
end

