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
            
            this@simulation.infrastructure('Example_CCAA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the root object
            examples.CCAA.systems.Example(this.oSimulationContainer, 'Example');

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 6; % In seconds
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            for iProtoflightTest = 1:6
                oLog.addValue(['Example:s:Cabin_', num2str(iProtoflightTest), '.toPhases.Air'],                     'rRelHumidity',                 '-',    ['Relative Humidity Cabin_', num2str(iProtoflightTest)]);
                oLog.addValue(['Example:s:Cabin_', num2str(iProtoflightTest), '.toPhases.Air'],                     'fTemperature',                 'K',    ['Temperature Cabin_', num2str(iProtoflightTest)]);

                oLog.addValue(['Example:c:CCAA_', num2str(iProtoflightTest) ':c:CCAA_CHX'],                         'fTotalCondensateHeatFlow',   	'W',    ['CCAA_', num2str(iProtoflightTest), ' Condensate Heat Flow']);
                oLog.addValue(['Example:c:CCAA_', num2str(iProtoflightTest) ':c:CCAA_CHX'],                         'fTotalHeatFlow',            	'W',    ['CCAA_', num2str(iProtoflightTest), ' Total Heat Flow']);
                oLog.addValue(['Example:c:CCAA_', num2str(iProtoflightTest) ':c:CCAA_CHX'],                         'fTempOut_Fluid1',            	'K',    ['CCAA_', num2str(iProtoflightTest), ' Air Outlet Temperature']);
                oLog.addValue(['Example:c:CCAA_', num2str(iProtoflightTest) ':c:CCAA_CHX'],                         'fTempOut_Fluid2',            	'K',    ['CCAA_', num2str(iProtoflightTest), ' Coolant Outlet Temperature']);
                oLog.addValue(['Example:c:CCAA_', num2str(iProtoflightTest) ':s:CHX.toProcsP2P.CondensingHX'],      'fFlowRate',                    'kg/s', ['CCAA_', num2str(iProtoflightTest), ' Condensate Flow Rate']);
                
            end
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
            
            oPlotter = plot@simulation.infrastructure(this);
            
            tPlotOptions.sTimeUnit = 'hours';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);
          
            csRelativeHumidities  	= cell(1,6);
            csTemperatures          = cell(1,6);
            csCondensateHeatFlow  	= cell(1,6);
            csTotalHeatFlow         = cell(1,6);
            csAirOutTemperature   	= cell(1,6);
            csCoolantOutTemperature	= cell(1,6);
            csCondensateFlow        = cell(1,6);
            
            for iProtoflightTest = 1:6
                csRelativeHumidities{iProtoflightTest}      = ['"Relative Humidity Cabin_', num2str(iProtoflightTest), '"'];
                csTemperatures{iProtoflightTest}            = ['"Temperature Cabin_', num2str(iProtoflightTest), '"'];
                csCondensateHeatFlow {iProtoflightTest}     = ['"CCAA_', num2str(iProtoflightTest), ' Condensate Heat Flow"'];
                csTotalHeatFlow {iProtoflightTest}          = ['"CCAA_', num2str(iProtoflightTest), ' Total Heat Flow"'];
                csAirOutTemperature {iProtoflightTest}      = ['"CCAA_', num2str(iProtoflightTest), ' Air Outlet Temperature"'];
                csCoolantOutTemperature {iProtoflightTest}	= ['"CCAA_', num2str(iProtoflightTest), ' Coolant Outlet Temperature"'];
                csCondensateFlow {iProtoflightTest}         = ['"CCAA_', num2str(iProtoflightTest), ' Condensate Flow Rate"'];
            end
            
            
            coPlots{1,1} = oPlotter.definePlot(csTemperatures,        'Temperature', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csRelativeHumidities,   'Relative Humidity', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot([csCondensateHeatFlow(:), csTotalHeatFlow(:)],   'CCAA Heat Flows', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csCondensateFlow,            'CCAA Condensate Flow Rate');
            coPlots{3,1} = oPlotter.definePlot(csAirOutTemperature,         'CCAA Air Outlet Temperature');
            coPlots{3,2} = oPlotter.definePlot(csCoolantOutTemperature,     'CCAA Coolant Outlet Temperature');
            oPlotter.defineFigure(coPlots,  'CCAA Plots', tFigureOptions);
            
            oPlotter.plot();
        end
    end
end


