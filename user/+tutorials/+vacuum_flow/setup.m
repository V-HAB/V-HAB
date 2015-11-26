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
            
            ttMonitorConfig = struct();
            
            
            
            this@simulation.infrastructure('Vacuum_Flow', ptConfigParams, tSolverParams);
            
            
            
            tutorials.vacuum_flow.systems.Example(this.oSimulationContainer, 'Example');
            
        end
        
        
        
        function configureMonitors(this)
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            tiFlowProps = oLog.add('Example', 'flow_props');
            
            
%             this.csLog = {
%                 % System timer
%                 'oData.oTimer.fTime';                                              % 1
%                 
%                 % Logging pressures, masses and the flow rate
%                 'toChildren.Example.toStores.Tank_1.aoPhases(1).fMassToPressure';  % 2
%                 'toChildren.Example.toStores.Tank_1.aoPhases(1).fMass';
%                 'toChildren.Example.toStores.Tank_2.aoPhases(1).fMassToPressure';  % 4
%                 'toChildren.Example.toStores.Tank_2.aoPhases(1).fMass';
%                 'toChildren.Example.aoBranches(1).fFlowRate';                      % 6
%                 'toChildren.Example.toStores.Tank_1.aoPhases(1).fTemp';
%                 'toChildren.Example.toStores.Tank_2.aoPhases(1).fTemp';     % 8
% 
%                 % You can add other parameters here
%                 };
            

            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
            
            

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 2.5e5;%3600 * 14*4.9; % In seconds
            this.iSimTicks = 1000;
            this.bUseTime = false;

        end
        
        function plot(this) % Plotting the results
            
            this.toMonitors.oPlotter.plot();
            return;
            
            
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            
            
            
%             figure('name', 'Tank Pressures');
%             hold on;
%             grid minor;
%             %plot(this.mfLog(:,1), this.mfLog(:, [2 4]) .* this.mfLog(:, [3 5]));
%             plot(this.mfLog(:,1), this.mfLog(:, [2 4]) .* this.mfLog(:, [3 5]));
%             legend('Tank 1', 'Tank 2');
%             ylabel('Pressure in Pa');
%             xlabel('Time in s');
            


            sPlot = 'Tank Masses';
            csValues = {
                'Tutorial_Simple_Flow/Example:s:Tank_1:p:Tank_1_Phase_1.fMass';
                'Tutorial_Simple_Flow/Example:s:Tank_2:p:Tank_2_Phase_1.fMass';
            };
            
            %%% Default Code START
            
            figure('name', sPlot);
            hold on;
            grid minor;
            
            mfLog    = [];
            sLabel   = [];
            sUnit    = [];
            csLegend = {};
            
            for iV = 1:length(csValues)
                [ axData, tDefinition, sLabel ] = oLog.get(csValues{iV});
                
                mfLog = [ mfLog, axData ];
                csLegend{end + 1} = tDefinition.sName;
                sUnit = tDefinition.sUnit;
            end
            
            plot(oLog.afTime, mfLog);
            legend(csLegend);
            
            ylabel([ sLabel ' in [' sUnit ']' ]);
            xlabel('Time in s');
            
            %%% Default Code END
            
            
            
            return;
            
            
            figure('name', 'Tank Temperatures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 7:8));
            legend('Tank 1', 'Tank 2');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 6));
            legend('Branch');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'Time Steps');
            hold on;
            grid minor;
            plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
            legend('Solver');
            ylabel('Time in [s]');
            xlabel('Ticks');
            
            tools.arrangeWindows();
        end
        
    end
    
end

