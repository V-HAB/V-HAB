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
                fSimTime = 3600 * 5;
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
            
            oLog.addValue('Example.toStores.Valve_1.toPhases.flow',             'fPressure',    'Pa', 'Valve1 Pressure');
            oLog.addValue('Example.toStores.Filter.toPhases.flow',              'fPressure',    'Pa', 'Filter Pressure');
            oLog.addValue('Example.toStores.Valve_2.toPhases.flow',             'fPressure',    'Pa', 'Valve2 Pressure');
            oLog.addValue('Example.toStores.Store.toPhases.Store_Phase_1',      'fPressure',    'Pa', 'Store Pressure');
            oLog.addValue('Example.toStores.Vacuum.toPhases.Vacuum_Phase_1',	'fPressure',    'Pa', 'Vacuum Pressure');
            
            
            oLog.addValue('Example.toBranches.Store__Port_Out___Valve_1__In',       'fFlowRate',    'kg/s', 'Store to Valve1 Flow Rate');
            oLog.addValue('Example.toBranches.Valve_1__Out___Filter__In',           'fFlowRate',    'kg/s', 'Valve1 to Filter Flow Rate');
            oLog.addValue('Example.toBranches.Filter__Out___Valve_2__In',           'fFlowRate',    'kg/s', 'Filter to Valve2 Flow Rate');
            oLog.addValue('Example.toBranches.Valve_2__Out___Vacuum__Port_2',       'fFlowRate',    'kg/s', 'Valve2 to Vacuum Flow Rate');
            oLog.addValue('Example.toBranches.Filter__Filtered___Vacuum__Port_1',   'fFlowRate',    'kg/s', 'Filter to Vacuum Flow Rate');
            
            %oLog.add('Example', 'flow_props');
            
        end
        
        function plot(this) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            csPressures = {'"Valve1 Pressure"', '"Filter Pressure"', '"Valve2 Pressure"', '"Store Pressure"', '"Vacuum Pressure"'};
            csFlowRates = {'"Store to Valve1 Flow Rate"', '"Valve1 to Filter Flow Rate"', '"Filter to Valve2 Flow Rate"', '"Valve2 to Vacuum Flow Rate"', '"Filter to Vacuum Flow Rate"'};
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);
            
            coPlots{1,1} = oPlotter.definePlot(csPressures,   'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,   'Flow Rates', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end

