classdef setup < simulation.infrastructure
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            
            if ~isfield('tSolverParams', 'rHighestMaxChangeDecrease')
                tSolverParams.rHighestMaxChangeDecrease = 500;
            end
            
            this@simulation.infrastructure('Tutorial_ReconnectingExMe', ptConfigParams, tSolverParams);
            
            tutorials.reconnectingExMe.systems.Example(this.oSimulationContainer, 'Example');
            
            %% Simulation length
            % Stop after 200 ticks
            this.fSimTime = 900 * 1; % In seconds
            this.iSimTicks = 200;
            this.bUseTime = false;
            
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
            
            csStoresMiddleSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.MiddleSystem.toStores);
            for iStore = 1:length(csStoresMiddleSystem)
                oLog.addValue(['Example:c:MiddleSystem.toStores.', csStoresMiddleSystem{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStoresMiddleSystem{iStore}, ' Pressure']);
                oLog.addValue(['Example:c:MiddleSystem.toStores.', csStoresMiddleSystem{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStoresMiddleSystem{iStore}, ' Temperature']);
            end
            
            csBranchesMiddleSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.MiddleSystem.toBranches);
            for iBranch = 1:length(csBranchesMiddleSystem)
                oLog.addValue(['Example:c:MiddleSystem.toBranches.', csBranchesMiddleSystem{iBranch}],             'fFlowRate',    'kg/s', [csBranchesMiddleSystem{iBranch}, ' Flowrate']);
            end
            
            csStoresSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.MiddleSystem.toChildren.SubSystem.toStores);
            for iStore = 1:length(csStoresSubSystem)
                oLog.addValue(['Example:c:MiddleSystem:c:SubSystem.toStores.', csStoresSubSystem{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStoresSubSystem{iStore}, ' Pressure']);
                oLog.addValue(['Example:c:MiddleSystem:c:SubSystem.toStores.', csStoresSubSystem{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStoresSubSystem{iStore}, ' Temperature']);
            end
            
            csBranchesSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.MiddleSystem.toChildren.SubSystem.toBranches);
            for iBranch = 1:length(csBranchesSubSystem)
                oLog.addValue(['Example:c:MiddleSystem:c:SubSystem.toBranches.', csBranchesSubSystem{iBranch}],             'fFlowRate',    'kg/s', [csBranchesSubSystem{iBranch}, ' Flowrate']);
            end
            
        end
        
        function plot(this, varargin) % Plotting the results
            
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
            
            
            csStoresMiddleSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.MiddleSystem.toStores);
            csPressuresMiddleSystem = cell(length(csStoresMiddleSystem),1);
            csTemperaturesMiddleSystem = cell(length(csStoresMiddleSystem),1);
            for iStore = 1:length(csStoresMiddleSystem)
                csPressuresMiddleSystem{iStore} = ['"', csStoresMiddleSystem{iStore}, ' Pressure"'];
                csTemperaturesMiddleSystem{iStore} = ['"', csStoresMiddleSystem{iStore}, ' Temperature"'];
            end
            
            csBranchesMiddleSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.MiddleSystem.toBranches);
            csFlowRatesMiddleSystem = cell(length(csBranchesMiddleSystem),1);
            for iBranch = 1:length(csBranchesMiddleSystem)
                csFlowRatesMiddleSystem{iBranch} = ['"', csBranchesMiddleSystem{iBranch}, ' Flowrate"'];
            end
            
            
            csStoresSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.MiddleSystem.toChildren.SubSystem.toStores);
            csPressuresMiddleSystem = cell(length(csStoresSubSystem),1);
            csTemperaturesMiddleSystem = cell(length(csStoresSubSystem),1);
            for iStore = 1:length(csStoresSubSystem)
                csPressuresMiddleSystem{iStore} = ['"', csStoresSubSystem{iStore}, ' Pressure"'];
                csTemperaturesMiddleSystem{iStore} = ['"', csStoresSubSystem{iStore}, ' Temperature"'];
            end
            
            csBranchesSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.MiddleSystem.toChildren.SubSystem.toBranches);
            csFlowRatesSubSystem = cell(length(csBranchesSubSystem),1);
            for iBranch = 1:length(csBranchesSubSystem)
                csFlowRatesSubSystem{iBranch} = ['"', csBranchesSubSystem{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot([csPressures(:)', csPressuresMiddleSystem(:)', csPressuresMiddleSystem(:)'],     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot([csFlowRates(:)', csFlowRatesMiddleSystem(:)', csFlowRatesSubSystem(:)'],     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot([csTemperatures(:)', csTemperaturesMiddleSystem(:)', csTemperaturesMiddleSystem(:)'],  'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end