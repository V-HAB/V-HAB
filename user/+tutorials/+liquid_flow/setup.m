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
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Liquid_Flow', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.liquid_flow.systems.Example(this.oSimulationContainer, 'Example');
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 2; % In seconds
            this.bUseTime = true;
        end
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fMass',	'kg', [csStores{iStore}, ' Mass']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fVolume',	'm^3', [csStores{iStore}, ' Volume']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fPressure','Pa', [csStores{iStore}, ' Pressure']);
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
            csMasses = cell(length(csStores),1);
            csPressures = cell(length(csStores),1);
            csVolumes = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csMasses{iStore} = ['"', csStores{iStore}, ' Mass"'];
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csVolumes{iStore} = ['"', csStores{iStore}, ' Volume"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
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
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
    end
    
end

