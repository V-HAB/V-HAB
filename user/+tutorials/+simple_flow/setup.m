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
            
            % vhab.exec always passes in ptConfigParams, tSolverParams
            % If not provided, set to empty containers.Map/struct
            % Can be passed to vhab.exec:
            %
            % ptCfgParams = containers.Map();
            % ptCfgParams('Tutorial_Simple_Flow/Example') = struct('fPipeLength', 7);
            % vhab.exec('tutorials.simple_flow.setup', ptCfgParams);
            
            
            % By Path - will overwrite (by definition) CTOR value, even 
            % though the CTOR value is set afterwards!
            %%%ptConfigParams('Tutorial_Simple_Flow/Example') = struct('fPipeLength', 7);
            
            
            % By constructor
            %%%ptConfigParams('tutorials.simple_flow.systems.Example') = struct('fPipeLength', 5, 'fPressureDifference', 2);
            
            
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            %%%ttMonitorConfig.oConsoleOutput = struct('cParams', {{ 50 5 }});
            
            %tSolverParams.rUpdateFrequency = 0.1;
            %tSolverParams.rHighestMaxChangeDecrease = 100;
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Simple_Flow', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.simple_flow.systems.Example(this.oSimulationContainer, 'Example');
            
            % This is an alternative to providing the ttMonitorConfig above
            %this.toMonitors.oConsoleOutput.setReportingInterval(10, 1);
            
            
            
            
            

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 1; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        
        
        function configureMonitors(this)
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            tiFlowProps = oLog.add('Example', 'flow_props');
            
            % Add single values
            iPropLogIndex1 = oLog.addValue('Example', 'iChildren',     [],  'Label of Prop');
            %keyboard();
            iPropLogIndex2 = oLog.addValue('Example', 'fPipeDiameter', 'm', 'Pipe Diameter');
            
            oLog.addValue('Example:s:Tank_1.aoPhases(1)', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO_2 Tank 1');
            oLog.addValue('Example:s:Tank_2.aoPhases(1)', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO_2 Tank 2');
            
            
            oLog.addValue('Example:s:Tank_2.aoPhases(1)', 'this.fMass * this.fMassToPressure', 'kg', 'Mass Tank 2');
            
            oLog.addValue('Example:s:Tank_1.aoPhases(1)', 'afMass(this.oMT.tiN2I.CO2)', 'kg', 'Partial Mass CO_2 Tank 1');
            oLog.addValue('Example:s:Tank_2.aoPhases(1)', 'afMass(this.oMT.tiN2I.CO2)', 'kg', 'Partial Mass CO_2 Tank 2');
            
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
            

            oLog.addValue('Example:s:Tank_1.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.H2O)', 'Partial kg', 'Partial Mass Water');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlot('Pa', 'Tank Pressures');
            oPlot.definePlot('K', 'Tank Temperatures');
            oPlot.definePlot('kg', 'Tank Masses');
            oPlot.definePlot('kg/s', 'Flow Rates');
            
            cNames = {'Partial Pressure CO_2 Tank 1', 'Partial Pressure CO_2 Tank 2'};
            sTitle = 'Partial Pressure CO2';
            oPlot.definePlot(cNames, sTitle);

            cNames = {'Partial Mass CO_2 Tank 1', 'Partial Mass CO_2 Tank 2'};
            sTitle = 'Partial Mass CO2';
            oPlot.definePlot(cNames, sTitle);

        end
        
        function plot(this, varargin) % Plotting the results
            
            this.toMonitors.oPlotter.plot(varargin{:});
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

