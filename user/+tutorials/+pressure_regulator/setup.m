classdef setup < simulation.infrastructure
    
    methods
        % constructor function
        function this = setup(ptConfigParams, tSolverParams)
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % call parent constructor
            this@simulation.infrastructure('Pressure_Regulator', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Setting a fixed timestep that is passed through the system
            fFixedTimeStep = 0.1;
            
            % create root object
            tutorials.pressure_regulator.systems.SuitSystem(this.oSimulationContainer, 'SuitSystem', fFixedTimeStep); 
            
            %% Simulation length
            
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 200 * 1; % In seconds
            this.iSimTicks = 3000;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            tiLog = oLog.add('SuitSystem', 'flow_props');
            tiLog = oLog.add('SuitSystem/Regulator', 'flow_props');
            
            tiLog.Valves.Diameter.Valve1 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.FirstStageValve', 'fHydrDiam', 'm', 'First Stage Valve Hydraulic Diameter');
            tiLog.Valves.Diameter.Valve2 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.SecondStageValve', 'fHydrDiam', 'm', 'Second Stage Valve Hydraulic Diameter');
            
            tiLog.Valves.Position.Valve1 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.FirstStageValve', 'afSSM_VectorXNew(3)', 'm', 'First Stage Valve Position');
            tiLog.Valves.Position.Valve2 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.SecondStageValve', 'afSSM_VectorXNew(3)', 'm', 'Second Stage Valve Position');
            
            tiLog.Valves.Speed.Valve1 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.FirstStageValve', 'afSSM_VectorXNew(2)', 'm', 'First Stage Valve Speed');
            tiLog.Valves.Speed.Valve2 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.SecondStageValve', 'afSSM_VectorXNew(2)', 'm', 'Second Stage Valve Speed');
            
            tiLog.Valves.Setpoint.Valve1 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.FirstStageValve', 'fXSetpoint', 'm', 'First Stage Valve Setpoint');
            tiLog.Valves.Setpoint.Valve2 = oLog.addValue('SuitSystem/Regulator.toProcsF2F.SecondStageValve', 'fXSetpoint', 'm', 'Second Stage Valve Setpoint');
            
            if this.oSimulationContainer.toChildren.SuitSystem.bPPRVExists
                tiLog.Valves.Diameter.PPRV = oLog.addValue('SuitSystem.toProcsF2F.ValvePPRV', 'fHydrDiam', 'm', 'PPRV Hydraulic Diameter');
                
                tiLog.Valves.Position.PPRV = oLog.addValue('SuitSystem.toProcsF2F.ValvePPRV', 'afSSM_VectorXNew(2)', 'm', 'PPRV Position');
                
                tiLog.Valves.Speed.PPRV = oLog.addValue('SuitSystem.toProcsF2F.ValvePPRV', 'afSSM_VectorXNew(1)', 'm', 'PPRV Speed');
                
            end
            
            %% Defining plots
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            %oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
            
            oPlot.definePlot(tiLog.Valves.Diameter, 'Valve Diameters');
            oPlot.definePlot(tiLog.Valves.Position, 'Valve Positions');
            oPlot.definePlot(tiLog.Valves.Speed,    'Valve Speeds');
            oPlot.definePlot(tiLog.Valves.Setpoint, 'Valve Setpoints');
            
        end
        
        % plot results
        function plot(this)
            this.toMonitors.oPlotter.plot();
            return;
            
%             if this.oSimulationContainer.toChildren.SuitSystem.bPPRVExists
%             close all
%             
%             figure('name', 'Tank Pressures');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [2 4 6 8 21]));
%             legend('O2 Tank', 'InterStage', 'Suit Tank', 'Buffer Tank', 'Environment Reference');
%             ylabel('Pressure in [Pa]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Tank Masses');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [3 5 7 9]));
%             legend('O2 Tank', 'InterStage', 'Suit Tank', 'Buffer Tank');
%             ylabel('Mass in [kg]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Flow Rate');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), [(this.mfLog(:, 10) * -1) this.mfLog(:, [11 12 23])]);
%             legend('O2Tank - InterStage', 'InterStage - SuitTank',  'Suit Leakage', 'PPRV FlowRate');
%             ylabel('flow rate [kg/s]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Time Steps');
%             hold on;
%             grid minor;
%             plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
%             legend('Solver');
%             ylabel('Time in [s]');
%             xlabel('Ticks');
% 
%             figure('name', 'Hydraulic Diameter');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [13 14 24]));
%             legend('HydrDiam Valve1', 'HydrDiam Valve2', 'HydrDiam PPRV');
%             ylabel('HydrDiam in [m]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Valve Dislocation');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [15 16 25]));
%             legend('Position Valve1', 'Position Valve2', 'Position PPRV');
%             ylabel('Position in [m]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Valve Speed');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [17 18 26]));
%             legend('Speed Valve1', 'Speed Valve2', 'Speed PPRV');
%             ylabel('Speed in [m/s]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Valve Setpoint');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [19 20]));
%             legend('Setpoint Valve1', 'Setpoint Valve2');
%             ylabel('Setpoint Position in [m]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Environment Reference');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [21 22]));
%             legend('Pressure ER', 'Pressure EB');
%             ylabel('Pressure in [Pa], Mass in [kg]');
%             xlabel('Time in [s]');
%             
%             tools.arrangeWindows();
%             
%             else
%                 close all
%             
%             figure('name', 'Tank Pressures');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [2 4 6 8 21]));
%             legend('O2 Tank', 'InterStage', 'Suit Tank', 'Buffer Tank', 'Environment Reference');
%             ylabel('Pressure in [Pa]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Tank Masses');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [3 5 7 9]));
%             legend('O2 Tank', 'InterStage', 'Suit Tank', 'Buffer Tank');
%             ylabel('Mass in [kg]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Flow Rate');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), [(this.mfLog(:, 10) * -1) this.mfLog(:, [11 12])]);
%             legend('O2Tank - InterStage', 'InterStage - SuitTank',  'Suit Leakage');
%             ylabel('flow rate [kg/s]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Time Steps');
%             hold on;
%             grid minor;
%             plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
%             legend('Solver');
%             ylabel('Time in [s]');
%             xlabel('Ticks');
% 
%             figure('name', 'Hydraulic Diameter');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [13 14]));
%             legend('HydrDiam Valve1', 'HydrDiam Valve2');
%             ylabel('HydrDiam in [m]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Valve Dislocation');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [15 16]));
%             legend('Position Valve1', 'Position Valve2');
%             ylabel('Position in [m]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Valve Speed');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [17 18]));
%             legend('Speed Valve1', 'Speed Valve2');
%             ylabel('Speed in [m/s]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Valve Setpoint');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [19 20]));
%             legend('Setpoint Valve1', 'Setpoint Valve2');
%             ylabel('Setpoint Position in [m]');
%             xlabel('Time in [s]');
%             
%             figure('name', 'Environment Reference');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [21 22]));
%             legend('Pressure ER', 'Pressure EB');
%             ylabel('Pressure in [Pa], Mass in [kg]');
%             xlabel('Time in [s]');
%             
%             tools.arrangeWindows();
%             end
        end
    end
end