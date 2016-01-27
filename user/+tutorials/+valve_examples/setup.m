classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, fSimTime) % Constructor function
            
            this@simulation.infrastructure('Tutorial_Valve_Examples', ptConfigParams, tSolverParams);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.valve_examples.systems.Example(this.oSimulationContainer, 'Example');
            
            
            

            %% Simulation length
            
            if nargin < 3 || isempty(fSimTime)
                fSimTime = 3600 * 3;
            end
            
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = fSimTime; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        
        
        function configureMonitors(this)
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            tiFlowProps = oLog.add('Example', 'flow_props');
            
            % Add single values
            iPropLogIndex1 = oLog.addValue('Example', 'iChildren',     [],  'Label of Prop');
            %keyboard();
            iPropLogIndex2 = oLog.addValue('Example', 'fPipeDiameter', 'm', 'Pipe Diameter');
            
            
            
            

            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            %oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
            
            

        end
        
        function plot(this) % Plotting the results
            
            this.toMonitors.oPlotter.plot();
            
            return;
            %tools.arrangeWindows();
        end
        
    end
    
end

