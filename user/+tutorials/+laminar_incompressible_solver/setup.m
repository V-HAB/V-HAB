classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, fSimTime, iNr) % Constructor function
            
            if nargin < 4 || isempty(iNr), iNr = 0; end;
            
            
            this@simulation.infrastructure('Tutorial_Solver_LaminarIncompressible', ptConfigParams, tSolverParams);
            
            
            if iNr == 0
                tutorials.laminar_incompressible_solver.systems.Example(this.oSimulationContainer, 'Example');
            else
                tutorials.laminar_incompressible_solver.systems.(sprintf('Example_%i', iNr))(this.oSimulationContainer, 'Example');
            end
            
            
            
            

            %% Simulation length
            
            if nargin < 3 || isempty(fSimTime)
                fSimTime = 3600 * 1;
            end
            
            if fSimTime < 0
                this.fSimTime = 3600;
                this.iSimTicks = abs(fSimTime);
                this.bUseTime = false;
            else
                % Stop when specific time in simulation is reached or after 
                % specific amount of ticks (bUseTime true/false).
                this.fSimTime = fSimTime; % In seconds
                this.iSimTicks = 1950;
                this.bUseTime = true;
            end
        end
        
        
        
        function configureMonitors(this)
            
            
            oConsOut = this.toMonitors.oConsoleOutput;
            
            
            %%
%             oConsOut.setLogOn().setVerbosity(3);
%             oConsOut.addMethodFilter('updatePressure');
%             oConsOut.addMethodFilter('massupdate');
%             oConsOut.addIdentFilter('changing-boundary-conditions');
            
% %             oConsOut.addIdentFilter('solve-flow-rates');
% %             oConsOut.addIdentFilter('calc-fr');
% %             oConsOut.addIdentFilter('set-fr');
% %             oConsOut.addIdentFilter('total-fr');
% %             oConsOut.addIdentFilter('negative-mass');
            
% %             oConsOut.addTypeToFilter('matter.phases.gas_pressure_manual');
            %%
            
            
            %this.oSimulationContainer.oTimer.setMinStep(1e-12)
            this.oSimulationContainer.oTimer.setMinStep(1e-16);
            
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Example', 'flow_props');
            
            
            

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

