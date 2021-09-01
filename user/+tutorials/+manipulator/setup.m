classdef setup < simulation.infrastructure
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorConfig = struct();
            this@simulation.infrastructure('Tutorial_Manipulator', ptConfigParams, tSolverParams, ttMonitorConfig);
            tutorials.manipulator.systems.Example(this.oSimulationContainer, 'Example');
            
            %% Simulation length
            this.fSimTime = 2000; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;
        end
        function configureMonitors(this)
            
            %% Logging
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
            
            oLog.addValue('Example:s:Reactor.toProcsP2P.FilterProc', 'fFlowRate', 'kg/s', 'P2P Flow Rate');
            oLog.addValue('Example:s:Reactor.toPhases.FlowPhase.toManips.substance', 'afPartialFlows(this.oMT.tiN2I.O2)', 'kg/s', 'Bosch O2 Flow Rate');
            oLog.addValue('Example:s:Reactor.toPhases.FlowPhase.toManips.substance', 'afPartialFlows(this.oMT.tiN2I.CO2)', 'kg/s', 'Bosch CO2 Flow Rate');
            oLog.addValue('Example:s:Reactor.toPhases.FlowPhase.toManips.substance', 'afPartialFlows(this.oMT.tiN2I.C)', 'kg/s', 'Bosch C Flow Rate');
        end
        
        function plot(this)
            %% Plotting
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
            
            csBoschReactorFlows = {'"P2P Flow Rate"', '"Bosch O2 Flow Rate"',  '"Bosch CO2 Flow Rate"', '"Bosch C Flow Rate"'};
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot(csPressures,     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csTemperatures,  'Temperatures', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csBoschReactorFlows,  'Bosch Reactor Flowrates', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
    end
end