classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            ttMonitorConfig = struct();
            this@simulation.infrastructure('Tutorial_Human_1_Model', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tutorials.human_model.systems.Example(this.oSimulationContainer, 'Example');
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 24 * 5; % In seconds
            this.iSimTicks = 1500;
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
            
            csStoresHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toStores);
            for iStore = 1:length(csStoresHuman_1)
                oLog.addValue(['Example:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStoresHuman_1{iStore}, ' Pressure']);
                oLog.addValue(['Example:c:Human_1.toStores.', csStoresHuman_1{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStoresHuman_1{iStore}, ' Temperature']);
            end
            
            csBranchesHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toBranches);
            for iBranch = 1:length(csBranchesHuman_1)
                oLog.addValue(['Example:c:Human_1.toBranches.', csBranchesHuman_1{iBranch}],             'fFlowRate',    'kg/s', [csBranchesHuman_1{iBranch}, ' Flowrate']);
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
            
            
            csStoresHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toStores);
            csPressuresHuman_1 = cell(length(csStoresHuman_1),1);
            csTemperaturesHuman_1 = cell(length(csStoresHuman_1),1);
            for iStore = 1:length(csStoresHuman_1)
                csPressuresHuman_1{iStore} = ['"', csStoresHuman_1{iStore}, ' Pressure"'];
                csTemperaturesHuman_1{iStore} = ['"', csStoresHuman_1{iStore}, ' Temperature"'];
            end
            
            csBranchesHuman_1 = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.Human_1.toBranches);
            csFlowRatesHuman_1 = cell(length(csBranchesHuman_1),1);
            for iBranch = 1:length(csBranchesHuman_1)
                csFlowRatesHuman_1{iBranch} = ['"', csBranchesHuman_1{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot({csPressures{:}, csPressuresHuman_1{:}},     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({csFlowRates{:}, csFlowRatesHuman_1{:}},     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({csTemperatures{:}, csTemperaturesHuman_1{:}},  'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end