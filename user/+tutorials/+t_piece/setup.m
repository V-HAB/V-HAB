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
            
%             tSolverParams.rUpdateFrequency = 10;
%             tSolverParams.rHighestMaxChangeDecrease = 1000;
%             
%             tSolverParams.rUpdateFrequency = 1;
%             tSolverParams.rHighestMaxChangeDecrease = 1000;
%             
%             tSolverParams.rUpdateFrequency = 5;
%             tSolverParams.rHighestMaxChangeDecrease = 500;
%             
%             
%             tSolverParams.rUpdateFrequency = 1;
%             tSolverParams.rHighestMaxChangeDecrease = 100;
%             
%             
%             tSolverParams.rUpdateFrequency = 2.5;
%             tSolverParams.rHighestMaxChangeDecrease = 50;
%             
%             
%             tSolverParams.rUpdateFrequency = 0.5;
%             tSolverParams.rHighestMaxChangeDecrease = 100;
            

            tSolverParams.rUpdateFrequency = 0.2;
            tSolverParams.rHighestMaxChangeDecrease = 25;
            
            
            tSolverParams.rUpdateFrequency = 1;
            tSolverParams.rHighestMaxChangeDecrease = 0;

            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('T_Piece', ptConfigParams, tSolverParams);
            
            %this.oSimulationContainer.oTimer.setMinStep(1e-12);
%             this.toMonitors.oConsoleOutput.setReportingInterval(10, 1);
            
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.t_piece.systems.Example(this.oSimulationContainer, 'Example');
            
            
            % This is an alternative to providing the ttMonitorConfig above
            %this.toMonitors.oConsoleOutput.setReportingInterval(10, 1);
            
            oP = this.oSimulationContainer.toChildren.Example.toStores.T_Piece.aoPhases(1);
            
%             oP.rMaxChange = 0.01;% oP.rMaxChange * 100000;
            %oP.rMaxChange = oP.rMaxChange * 100;
%             oP.rMaxChange = 0.01;
%             oP.rHighestMaxChangeDecrease = 1000;
%             oP.bSynced = true;
            
            
            
            oSolver1 = this.oSimulationContainer.toChildren.Example.coSolvers{1};
            oSolver2 = this.oSimulationContainer.toChildren.Example.coSolvers{2};
            oSolver3 = this.oSimulationContainer.toChildren.Example.coSolvers{3};
            
%             oSolver1.iDampFR = 5;
%             oSolver2.iDampFR = 5;
%             oSolver3.iDampFR = 5;
            
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            tiFlowProps = oLog.add('Example', 'flow_props');
            
            

            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
            
            oPlot.definePlot(12, 'ASD')
            
            

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 1; % In seconds
            this.iSimTicks = 500;
            this.bUseTime = false;

        end
        
        function plot(this) % Plotting the results
            
            this.toMonitors.oPlotter.plot();
            return;
            
            
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            
            close all
            
            oLog = this.toMonitors.oLogger;
            
            
            
            
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

