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
            
            this@simulation.infrastructure('Tutorial_Condensing_Heat_Exchanger', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the root object
            tutorials.condensing_heat_exchanger.systems.Example(this.oSimulationContainer, 'Example');

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 1; % In seconds
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Example', 'flow_props');
            oLog.add('Example', 'thermal_properties');
            
            oLog.addValue('Example', 'toProcsF2F.CondensingHeatExchanger_1.fHeatFlow', 'W', 'Heat Flow');
            oLog.addValue('Example', 'toProcsF2F.CondensingHeatExchanger_2.fHeatFlow', 'W', 'Heat Flow');
            
            oLog.addValue('Example:s:Tank_2.toProcsP2P.CondensingHX', 'fFlowRate', 'kg/s', 'Condensate Flow Rate');
            
            oLog.addValue('Example:s:Tank_1.toPhases.Air_1', 'rRelHumidity', '-', 'Relative Humidity Tank 1');
            oLog.addValue('Example:s:Tank_2.toPhases.Air_2', 'rRelHumidity', '-', 'Relative Humidity Tank 2');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa',  'Tank Pressures');
            oPlot.definePlotAllWithFilter('K',   'Temperatures');
            oPlot.definePlotAllWithFilter('kg',  'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s','Flow Rates');
            oPlot.definePlotAllWithFilter('W', 'Heat Flows');
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
          
            this.toMonitors.oPlotter.plot();
            
            for iIndex = 1:length(this.toMonitors.oLogger.tLogValues)
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Condensate Flow Rate')
                    iCondensateIndex = iIndex;
                end
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Relative Humidity Tank 1')
                    iHumidityTank1 = iIndex;
                end
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Relative Humidity Tank 2')
                    iHumidityTank2 = iIndex;
                end
            end
            
            mLogDataCondensate = this.toMonitors.oLogger.mfLog(:,iCondensateIndex);
            mLogDataCondensate(isnan(mLogDataCondensate(:,1)),:)=[];
            
            mLogDataHumidityTank1= this.toMonitors.oLogger.mfLog(:,iHumidityTank1);
            mLogDataHumidityTank1(isnan(mLogDataHumidityTank1(:,1)),:)=[];
            mLogDataHumidityTank1 = mLogDataHumidityTank1.*100;
            
            mLogDataHumidityTank2= this.toMonitors.oLogger.mfLog(:,iHumidityTank2);
            mLogDataHumidityTank2(isnan(mLogDataHumidityTank2(:,1)),:)=[];
            mLogDataHumidityTank2 = mLogDataHumidityTank2.*100;
            
            afTime = this.toMonitors.oLogger.afTime;
            
            figure('name', 'Condensate Flowrate')
            grid on
            hold on
            plot((afTime./3600), mLogDataCondensate)
            xlabel('Time in h')
            ylabel('Massflow in kg/s')
            
            figure('name', 'Relative Humidity')
            grid on
            hold on
            plot((afTime./3600), mLogDataHumidityTank1)
            plot((afTime./3600), mLogDataHumidityTank2)
            legend('Tank 1', 'Tank 2')
            xlabel('Time in h')
            ylabel('Rel. Humidity in %')
            
        end
        
    end
    
end

