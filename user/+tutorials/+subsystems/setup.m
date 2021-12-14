classdef setup < simulation.infrastructure
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            this@simulation.infrastructure('Tutorial_Subsystems', ptConfigParams, tSolverParams);
            
            tutorials.subsystems.systems.Example(this.oSimulationContainer, 'Example');
            
            this.fSimTime = 3600 * 2;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
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
            
            csStoresSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystem.toStores);
            for iStore = 1:length(csStoresSubSystem)
                oLog.addValue(['Example:c:SubSystem.toStores.', csStoresSubSystem{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStoresSubSystem{iStore}, ' Pressure']);
                oLog.addValue(['Example:c:SubSystem.toStores.', csStoresSubSystem{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStoresSubSystem{iStore}, ' Temperature']);
            end
            
            csBranchesSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystem.toBranches);
            for iBranch = 1:length(csBranchesSubSystem)
                oLog.addValue(['Example:c:SubSystem.toBranches.', csBranchesSubSystem{iBranch}],             'fFlowRate',    'kg/s', [csBranchesSubSystem{iBranch}, ' Flowrate']);
            end
        end
        
        function plot(this, varargin)
            
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
            
            csStoresSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystem.toStores);
            csPressuresSubSystem = cell(length(csStoresSubSystem),1);
            csTemperaturesSubSystem = cell(length(csStoresSubSystem),1);
            for iStore = 1:length(csStoresSubSystem)
                csPressuresSubSystem{iStore} = ['"', csStoresSubSystem{iStore}, ' Pressure"'];
                csTemperaturesSubSystem{iStore} = ['"', csStoresSubSystem{iStore}, ' Temperature"'];
            end
            
            csBranchesSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystem.toBranches);
            csFlowRatesSubSystem = cell(length(csBranchesSubSystem),1);
            for iBranch = 1:length(csBranchesSubSystem)
                csFlowRatesSubSystem{iBranch} = ['"', csBranchesSubSystem{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot([csPressures(:)', csPressuresSubSystem(:)'],     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot([csFlowRates(:)', csFlowRatesSubSystem(:)'],     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot([csTemperatures(:)', csTemperaturesSubSystem(:)'],  'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
    end
end