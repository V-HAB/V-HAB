classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) % Constructor function
            
            this@simulation.infrastructure('Test_Solver_MultiBranch_4', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tests.multibranch_solver_4.systems.Example_4(this.oSimulationContainer, 'Example');
            

            %% Simulation length
            
            if nargin < 4 || isempty(fSimTime)
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
            
% %             oConsOut.addTypeToFilter('matter.phases.gas_flow_node');
            %%
            
            
            %this.oSimulationContainer.oTimer.setMinStep(1e-12)
            this.oSimulationContainer.oTimer.setMinStep(1e-16);
            
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
        end
        
        function plot(this) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot(csPressures,     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csTemperatures,  'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end

