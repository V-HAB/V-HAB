classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
        
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('AlgaeModuleExample', ptConfigParams, tSolverParams, ttMonitorConfig);
                       
            tutorials.algae_module.systems.AlgaeModuleExample(this.oSimulationContainer, 'Example');
            
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 100; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fMass',        'kg', [csStores{iStore}, ' Mass']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
            csStoresSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystemAlgaeModule.toStores);
            for iStore = 1:length(csStoresSubSystem)
                oLog.addValue(['Example:c:SubSystemAlgaeModule.toStores.', csStoresSubSystem{iStore}, '.aoPhases(1)'],	'fMass',        'kg', [csStoresSubSystem{iStore}, ' Mass']);
                oLog.addValue(['Example:c:SubSystemAlgaeModule.toStores.', csStoresSubSystem{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStoresSubSystem{iStore}, ' Temperature']);
            end
            
            csBranchesSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystemAlgaeModule.toBranches);
            for iBranch = 1:length(csBranchesSubSystem)
                oLog.addValue(['Example:c:SubSystemAlgaeModule.toBranches.', csBranchesSubSystem{iBranch}],             'fFlowRate',    'kg/s', [csBranchesSubSystem{iBranch}, ' Flowrate']);
            end
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            csMasses = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csMasses{iStore} = ['"', csStores{iStore}, ' Mass"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot(csMasses,     'Masses', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csTemperatures,  'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            
            
            csStoresSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystemAlgaeModule.toStores);
            csMassesSubSystem = cell(length(csStoresSubSystem),1);
            csTemperaturesSubSystem = cell(length(csStoresSubSystem),1);
            for iStore = 1:length(csStoresSubSystem)
                csMassesSubSystem{iStore} = ['"', csStoresSubSystem{iStore}, ' Mass"'];
                csTemperaturesSubSystem{iStore} = ['"', csStoresSubSystem{iStore}, ' Temperature"'];
            end
            
            csBranchesSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystemAlgaeModule.toBranches);
            csFlowRatesSubSystem = cell(length(csBranchesSubSystem),1);
            for iBranch = 1:length(csBranchesSubSystem)
                csFlowRatesSubSystem{iBranch} = ['"', csBranchesSubSystem{iBranch}, ' Flowrate"'];
            end
            
            coPlots{1,1} = oPlotter.definePlot(csMassesSubSystem,           'Masses', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRatesSubSystem,        'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csTemperaturesSubSystem,     'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Subsystem Plots', tFigureOptions);
            
            
            oPlotter.plot();
        end
        
    end
    
end

