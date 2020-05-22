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
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) % Constructor function
            
            this@simulation.infrastructure('Test_CCAA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the root object
            examples.CCAA.systems.Example(this.oSimulationContainer, 'Example');

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 3600 * 12;
            else 
                this.fSimTime = fSimTime;
            end
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity', '-', 'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'fTemperature', 'K', 'Temperature Cabin');
            
            oLog.addValue('Example:c:CCAA:c:CCAA_CHX', 'fTotalCondensateHeatFlow',      'W',    'CCAA Condensate Heat Flow');
            oLog.addValue('Example:c:CCAA:c:CCAA_CHX', 'fTotalHeatFlow',                'W',    'CCAA Total Heat Flow');
            oLog.addValue('Example:c:CCAA:s:CHX.toProcsP2P.CondensingHX', 'fFlowRate',  'kg/s', 'CCAA Condensate Flow Rate');
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
            
            oPlotter = plot@simulation.infrastructure(this);
            
            tPlotOptions.sTimeUnit = 'hours';
            tFigureOptions = struct('bTimePlot', true, 'bPlotTools', false);
          
            coPlots{1,1} = oPlotter.definePlot({'"Temperature Cabin"'},        'Temperature', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Relative Humidity Cabin"'},   'Relative Humidity', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"CCAA Condensate Heat Flow"', '"CCAA Total Heat Flow"'},   'CCAA Heat Flows', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"CCAA Condensate Flow Rate"'},'CCAA Condensate Flow Rate');
            oPlotter.defineFigure(coPlots,  'CCAA Plots', tFigureOptions);
            
            oPlotter.plot();
        end
    end
end


