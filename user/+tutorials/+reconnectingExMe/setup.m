classdef setup < simulation.infrastructure
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            this@simulation.infrastructure('Tutorial_ReconnectingExMe', ptConfigParams, tSolverParams);
            
            tutorials.reconnectingExMe.systems.Example(this.oSimulationContainer, 'Example');
            
            this.iSimTicks = 2000;
            this.bUseTime = false;
            
        end
        
        function configureMonitors(this)
            
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.afPP(this.oMT.tiN2I.O2)',         'Pa', [csStores{iStore}, ' O2 Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.afPP(this.oMT.tiN2I.CO2)',        'Pa', [csStores{iStore}, ' CO2 Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
        end
        
        function plot(this, varargin)
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            csPressures     = cell(length(csStores),1);
            csO2            = cell(length(csStores),1);
            csCO2           = cell(length(csStores),1);
            csTemperatures  = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csO2{iStore}        = ['"', csStores{iStore}, ' O2 Pressure"'];
                csCO2{iStore}       = ['"', csStores{iStore}, ' CO2 Pressure"'];
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
            coPlots{1,2} = oPlotter.definePlot(csO2,            'O2 Pressures', tPlotOptions);
            coPlots{1,3} = oPlotter.definePlot(csCO2,           'CO2 Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,     'Flow Rates', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csTemperatures,  'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
    end
end