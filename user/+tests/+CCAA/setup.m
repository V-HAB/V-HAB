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
                this.fSimTime = 10;
            else 
                this.fSimTime = fSimTime;
            end
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
                oLog.addValue(['Example:c:CCAA_', num2str(iProtoflightTest) ':s:Mixing.toPhases.MixedGas'],         'fTemperature',                 'K',    ['CCAA_', num2str(iProtoflightTest), ' Mixed Air Outlet Temperature']);
                
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
            
            oLogger = this.toMonitors.oLogger;
            
            mfAirOutletTemperature      = zeros(oLogger.iLogIndex, 6);
            mfMixedAirOutletTemperature = zeros(oLogger.iLogIndex, 6);
            mfCoolantOutletTemperature  = zeros(oLogger.iLogIndex, 6);
            mfCondensateFlow            = zeros(oLogger.iLogIndex, 6);
            for iLog = 1:length(oLogger.tLogValues)
                for iProtoflightTest = 1:6
                    if strcmp(oLogger.tLogValues(iLog).sLabel, ['CCAA_', num2str(iProtoflightTest), ' Air Outlet Temperature'])
                        mfAirOutletTemperature(:, iProtoflightTest) = oLogger.mfLog(1:oLogger.iLogIndex, oLogger.tLogValues(iLog).iIndex);
                    elseif strcmp(oLogger.tLogValues(iLog).sLabel, ['CCAA_', num2str(iProtoflightTest), ' Mixed Air Outlet Temperature'])
                        mfMixedAirOutletTemperature(:, iProtoflightTest) = oLogger.mfLog(1:oLogger.iLogIndex, oLogger.tLogValues(iLog).iIndex);
                    elseif strcmp(oLogger.tLogValues(iLog).sLabel, ['CCAA_', num2str(iProtoflightTest), ' Coolant Outlet Temperature'])
                        mfCoolantOutletTemperature(:, iProtoflightTest) = oLogger.mfLog(1:oLogger.iLogIndex, oLogger.tLogValues(iLog).iIndex);
                    elseif strcmp(oLogger.tLogValues(iLog).sLabel, ['CCAA_', num2str(iProtoflightTest), ' Condensate Flow Rate'])
                        mfCondensateFlow(:, iProtoflightTest) = oLogger.mfLog(1:oLogger.iLogIndex, oLogger.tLogValues(iLog).iIndex);
                    end
                end
            end
            
            Data = load('user\+examples\+CCAA\+TestData\ProtoflightData.mat');
            
            % The first log point are the initialization values. Therefore
            % we compare the protoflight test data to the second log point.
            % Also the limits for the plots are set to ease comparison with
            % data from the old model, where these limits were chosen:
            figure('Name', 'Protoflight Test Comparison', 'units','normalized','outerposition',[0 0 1 1])
            subplot(1,3,1)
            % Unfortunatly it is not completly clear if the protoflight
            % test data is the air outlet temperature directly after the
            % CHX or after the CCAA (where it is mixed with the bypass
            % flow). But comparing the data from the test and the
            % simulation it seems to be after the mixing, otherwise the
            % outlet air temperatures cannot be explained
            scatter(1:6,  mfMixedAirOutletTemperature(4,:))
            hold on
            grid on
            % entry:
            scatter(1:6,  Data.ProtoflightTestData.AirOutletTemperature', 'x')
            xticks(1:6)
            ylim([275, 300])
            xlabel('Protoflight Test Number')
            ylabel('Air Outlet Temperature in K')
            legend('Simulation', 'Protoflight Test');
            hold off
            
            subplot(1,3,2)
            scatter(1:6,  mfCoolantOutletTemperature(2,:))
            hold on
            grid on
            scatter(1:6,  Data.ProtoflightTestData.CoolantOutletTemperature', 'x')
            xticks(1:6)
            ylim([275, 300])
            xlabel('Protoflight Test Number')
            ylabel('Coolant Outlet Temperature in K')
            legend('Simulation', 'Protoflight Test')
            hold off
            
            subplot(1,3,3)
            scatter(1:6,  mfCondensateFlow(2,:) .* 3600)
            hold on
            grid on
            scatter(1:6,  Data.ProtoflightTestData.CondensateMassFlow', 'x')
            xticks(1:6)
            ylim([0, 4])
            xlabel('Protoflight Test Number')
            ylabel('Condensate Mass Flow in kg/h')
            legend('Simulation', 'Protoflight Test')
            hold off
            
        end
    end
end


