classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime)
            this@simulation.infrastructure('Example_Mixture_Flow', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tests.mixture_flow.systems.Example(this.oSimulationContainer, 'Example');
            
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 3000;
            else 
                this.fSimTime = fSimTime;
            end
        end
        function configureMonitors(this)
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fMass',	'kg', [csStores{iStore}, ' Mass']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fVolume',	'm^3', [csStores{iStore}, ' Volume']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fPressure','Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
                
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'afMass(this.oMT.tiN2I.CO2)',	'kg', [csStores{iStore}, ' CO_2 Mass']);
            end
            
            oLog.addValue('Example.toStores.WaterTank_1.toPhases.WaterTank_1_Phase_2',	'fPressure','Pa', 'Water Tank 1 Air Pressure');
            oLog.addValue('Example.toStores.WaterTank_2.toPhases.WaterTank_2_Phase_2',	'fPressure','Pa', 'Water Tank 2 Air Pressure');
                
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
        end
        
        function plot(this)
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            csMasses = cell(length(csStores),1);
            csPressures = cell(length(csStores),1);
            csVolumes = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            csCO2Masses = cell(length(csStores),1);
            
            for iStore = 1:length(csStores)
                csMasses{iStore} = ['"', csStores{iStore}, ' Mass"'];
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csVolumes{iStore} = ['"', csStores{iStore}, ' Volume"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
                
                csCO2Masses{iStore} = ['"', csStores{iStore}, ' CO_2 Mass"'];
            end
            csPressures{end+1} = '"Water Tank 1 Air Pressure"';
            csPressures{end+1} = '"Water Tank 2 Air Pressure"';
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot(csMasses,        'Masses', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csPressures,     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,     'Flow Rates', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csTemperatures,  'Temperatures', tPlotOptions);
            coPlots{3,1} = oPlotter.definePlot(csVolumes,       'Volumes', tPlotOptions);
            coPlots{3,2} = oPlotter.definePlot(csCO2Masses,       'CO2 Masses', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
    end
end