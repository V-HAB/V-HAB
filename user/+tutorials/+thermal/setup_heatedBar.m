classdef setup_heatedBar < simulation.infrastructure
    %SETUP_HEATEDBAR Runner script/class for example simulation
    %   Detailed explanation goes here
    
    properties
        
        %TODO: (re)move!?
        oThermalSolver; % The thermal solver of this system.
        
        mPreviousTemperatures = [];
        fTempConvergenceCriteria = 0.00001;
        
    end
    
    methods
        
        function this = setup_heatedBar(ptConfigParams, tSolverParams)
            % Create a new simulation with the system described in
            % Example_heatedBar. 
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % Initialize simulation with name. 
            this@simulation.infrastructure('TestCase_heatedBar', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Create system Example_heatedBar. 
            oThermalSystem = tutorials.thermal.systems.example_heatedBar(this.oSimulationContainer, 'heatedBar');
            
            % Create a new solver.
            this.oThermalSolver = solver.thermal.lumpedparameter(oThermalSystem);
            
            % Register timer callback to stop simulation when tempereatures
            % converge.
            this.oSimulationContainer.oTimer.bind(@(o) this.breakAtConvergence(o), 1);
            
            % Register thermal solver with the system. This is needed for
            % the logger since it can only access properties defined in the
            % system. 
            oThermalSystem.oThermalSolver = this.oThermalSolver;
            
            % Set what data should be logged.
            oLog = this.toMonitors.oLogger;
            
            oLog.add('heatedBar', 'thermal_properties');
            oLog.add('heatedBar', 'temperatures');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('K', 'Temperatures');
            oPlot.definePlotAllWithFilter('J/K', 'Capacities');
            oPlot.definePlotAllWithFilter('W/K','Conductances');
            
            %TODO/vhab: This should be done with a method like setLogData?
%             this.csLog = {
%                 % System timer
%                 'oData.oTimer.fTime';
%                 
%                 % Solver & node temperatures
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 1)'; % 2
%                 %'toChildren.heatedBar.toStores.Block1.fTemperature'; % 2
%                 'toChildren.heatedBar.toStores.Block1.oPhase.fTemperature'; % 2
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 2)'; % 5
%                 %'toChildren.heatedBar.toStores.Block2.fTemperature'; % 4
%                 'toChildren.heatedBar.toStores.Block2.oPhase.fTemperature'; % 3
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 3)'; % 8
%                 %'toChildren.heatedBar.toStores.Block3.fTemperature'; % 6
%                 'toChildren.heatedBar.toStores.Block3.oPhase.fTemperature'; % 4
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 4)'; % 11
%                 %'toChildren.heatedBar.toStores.Block4.fTemperature'; % 8
%                 'toChildren.heatedBar.toStores.Block4.oPhase.fTemperature'; % 5
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 5)'; % 14
%                 %'toChildren.heatedBar.toStores.Block5.fTemperature'; % 10
%                 'toChildren.heatedBar.toStores.Block5.oPhase.fTemperature'; % 6
%                 
%                 % Solver heat energy transfers
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mPreviousNodeHeatChange'', 1)'; % 17
%                 %'toChildren.heatedBar.poCapacities(''Block1'').fEnergyDiff'; % 12
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mPreviousNodeHeatChange'', 2)'; % 19
%                 %'toChildren.heatedBar.poCapacities(''Block2'').fEnergyDiff';
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mPreviousNodeHeatChange'', 3)'; % 21
%                 %'toChildren.heatedBar.poCapacities(''Block3'').fEnergyDiff'; % 14
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mPreviousNodeHeatChange'', 4)'; % 23
%                 %'toChildren.heatedBar.poCapacities(''Block4'').fEnergyDiff';
%                 %'toChildren.heatedBar.oThermalSolver.getMatrixValueIfExists(''mPreviousNodeHeatChange'', 5)'; % 25
%                 %'toChildren.heatedBar.poCapacities(''Block5'').fEnergyDiff'; % 16
%                 
%                 % Add other parameters here
%             };
            % Simulate 3600s.
            this.fSimTime = 3600; % [s]
        end
        
        function breakAtConvergence(this, oTimer)
            
            %mNodeTemperatures = this.oThermalSolver.mNodeTemperatures;
            mNodeTemperatures = this.oSimulationContainer.toChildren.heatedBar.getNodeTemperatures();
            
            if isempty(this.mPreviousTemperatures)
                this.mPreviousTemperatures = mNodeTemperatures;
                return; % Return early.
            end
            
            mAbsTempChange = abs(this.mPreviousTemperatures - mNodeTemperatures);
            
            if max(mAbsTempChange) < this.fTempConvergenceCriteria
                disp('Converged!');
                this.fSimTime = oTimer.fTime; % Set simulation end time to current time, effectively aborting the simulation.
            end
            
            this.mPreviousTemperatures = mNodeTemperatures;
            
        end
        
        function plot(this)
            % Actually plot stuff
            this.toMonitors.oPlotter.plot();
            return;
%             close all
            
%             mTimes = this.mfLog(:, 1);
%             
%             figure('name', 'Phase Temperatures');
%             hold on;
%             grid minor;
%             plot(mTimes, this.mfLog(:, 2:6));
%             legend('Block 1', 'Block 2', 'Block 3', 'Block 4', 'Block 5');
%             ylabel('Temperature in K');
%             xlabel('Time in s');
            
            %{
            figure('name', 'Block1 Temperatures');
            hold on;
            grid minor;
            %plot(mTimes, this.mfLog(:, 2), ':', mTimes, this.mfLog(:, 3), '-', mTimes, this.mfLog(:, 4), '*');
            plot(mTimes, this.mfLog(:, 2), ':', mTimes, this.mfLog(:, 3), '*');
            %legend('Solver', 'Store', 'Phase');
            legend('Store', 'Phase');
            ylabel('Temperature in [K]');
            xlabel('Time in s');
            
            %figure('name', 'Block1 Heat Difference');
            figure('name', 'Heat Difference');
            hold on;
            grid minor;
            %plot(mTimes, this.mfLog(:, 17), '-', mTimes, this.mfLog(:, 18), 'r:');
            plot(mTimes, this.mfLog(:, 12:16));
            %legend('Solver' , 'Capacity');
            legend('Block1' , 'Block2' , 'Block3' , 'Block4' , 'Block5');
            ylabel('Heat Energy Difference in [J]');
            xlabel('Time in [s]');
            %}
        end
        
    end
    
end

