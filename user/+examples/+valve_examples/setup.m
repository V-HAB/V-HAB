classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, fSimTime, bExample2) % Constructor function
            
            
            % Example for _Mutiple
            % vhab.exec('tutorials.valve_examples.setup', [], struct('rUpdateFrequency', 0.05, 'rHighestMaxChangeDecrease', 500), 3600 * 0.1, true)
            % vhab.exec('tutorials.valve_examples.setup', containers.Map({'Example'}, {struct('piPipeLengths', containers.Map({ 6, 7, 9 }, { 10, 10, 10 }))}), struct('rUpdateFrequency', 0.05, 'rHighestMaxChangeDecrease', 500), 3600 * 0.1, true)
            
            this@simulation.infrastructure('Tutorial_Valve_Examples', ptConfigParams, tSolverParams);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            if (nargin >= 4) && ~isempty(bExample2) && islogical(bExample2) && (bExample2 == true)
                tutorials.valve_examples.systems.Example_Multiple(this.oSimulationContainer, 'Example');
            else
                tutorials.valve_examples.systems.Example(this.oSimulationContainer, 'Example');
            end
            
            
            

            %% Simulation length
            
            if nargin < 3 || isempty(fSimTime)
                fSimTime = 3600 * 3;
            end
            
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = fSimTime; % In seconds
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