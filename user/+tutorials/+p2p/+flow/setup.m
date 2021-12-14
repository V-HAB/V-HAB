classdef setup < simulation.infrastructure
    properties
        tiLog = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorConfig = struct();
            
            this@simulation.infrastructure('Tutorial_p2p', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tutorials.p2p.flow.systems.Example(this.oSimulationContainer, 'Example');
            
            this.fSimTime = 2000;
            this.bUseTime = true;
        end
        function configureMonitors(this)
            
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.afPP(this.oMT.tiN2I.CO2)',        'Pa', [csStores{iStore}, ' CO2 Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.afPP(this.oMT.tiN2I.H2O)',        'Pa', [csStores{iStore}, ' H2O Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            oLog.addValue('Example.toStores.Filter.toPhases.FilteredPhase',	'this.afMass(this.oMT.tiN2I.CO2)',	'kg',  'Adsorbed CO2');
            oLog.addValue('Example.toStores.Filter.toPhases.FilteredPhase',	'this.afMass(this.oMT.tiN2I.H2O)',	'kg',  'Adsorbed H2O');
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
        end
        
        function plot(this)
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            csPressures     = cell(length(csStores),1);
            csTemperatures  = cell(length(csStores),1);
            csCO2           = cell(length(csStores),1);
            csH2O           = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
                csCO2{iStore} = ['"', csStores{iStore}, ' CO2 Pressure"'];
                csH2O{iStore} = ['"', csStores{iStore}, ' H2O Pressure"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot(csPressures,         'Pressures', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csFlowRates,         'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Adsorbed CO2"', '"Adsorbed H2O"'},	'Adsorbed Masses', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csCO2,               'CO2', tPlotOptions);
            coPlots{3,1} = oPlotter.definePlot(csH2O,               'H2O', tPlotOptions);
            coPlots{3,2} = oPlotter.definePlot(csTemperatures,    	'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end

