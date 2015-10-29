classdef setup_cooledBar_phases < simulation.infrastructure
    %SETUP_COOLEDBAR Runner script/class for example simulation
    %   Detailed explanation goes here
    
    properties
        
        oThermalSolver; % The thermal solver of this system.
        
    end
    
    methods
        
        function this = setup_cooledBar_phases(ptConfigParams, tSolverParams)
            % Create a new simulation with the system described in
            % Example_cooledBar_phases. 
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % Initialize simulation with name. , ptConfigParams, tSolverParams, ttMonitorConfig
            this@simulation.infrastructure('TestCase_cooledBar_phases', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            this.oSimulationContainer.oTimer.setMinStep(5e-3);
            
            % Create system Example_cooledBar. 
            oThermalSystem = tutorials.thermal.systems.example_cooledBar_phases(this.oSimulationContainer, 'cooledBar');
                        
            % Create a new solver.
            this.oThermalSolver = solver.thermal.lumpedparameter(oThermalSystem);
            
            % Register timer callback to update capacities of nodes and
            % thermal conductivities of conductive conductors. 
            this.oSimulationContainer.oTimer.bind(@(~) this.updateThermalProperties(), 1);
            
            % Set what data should be logged.
            oLog = this.toMonitors.oLogger;
            
            oLog.add('cooledBar', 'thermal_properties');
            oLog.add('cooledBar', 'temperatures');
            
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
% %                 'toChildren.cooledBar.poCapacities(''Block1'').getTemperature()'; % 2
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(1).fTemperature'; 
% %                 'toChildren.cooledBar.poCapacities(''Block2'').getTemperature()'; % 4
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(2).fTemperature'; 
% %                 'toChildren.cooledBar.poCapacities(''Block3'').getTemperature()'; % 6
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(3).fTemperature'; 
% %                 'toChildren.cooledBar.poCapacities(''Block4'').getTemperature()'; % 8
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(4).fTemperature';
% %                 'toChildren.cooledBar.poCapacities(''Block5'').getTemperature()'; % 10
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(5).fTemperature';
%                 
%                 'toChildren.cooledBar.poCapacities(''Env'').getTemperature()'; % 12
%                 
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(1).fTotalHeatCapacity';
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(2).fTotalHeatCapacity';
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(3).fTotalHeatCapacity';
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(4).fTotalHeatCapacity';
%                 'toChildren.cooledBar.toStores.Bar.aoPhases(5).fTotalHeatCapacity';
%                 
% %                 'toChildren.cooledBar.poCapacities(''Block1'').getTotalHeatCapacity()'; % 13
% %                 'toChildren.cooledBar.poCapacities(''Block2'').getTotalHeatCapacity()'; 
% %                 'toChildren.cooledBar.poCapacities(''Block3'').getTotalHeatCapacity()'; 
% %                 'toChildren.cooledBar.poCapacities(''Block4'').getTotalHeatCapacity()'; 
% %                 'toChildren.cooledBar.poCapacities(''Block5'').getTotalHeatCapacity()'; % 17
%                 
%                 'toChildren.cooledBar.poLinearConductors(''linear:Block1+Block2'').fConductivity'; % 18
%                 'toChildren.cooledBar.poLinearConductors(''linear:Block2+Block3'').fConductivity';
%                 'toChildren.cooledBar.poLinearConductors(''linear:Block3+Block4'').fConductivity';
%                 'toChildren.cooledBar.poLinearConductors(''linear:Block4+Block5'').fConductivity'; % 21
%                 
%                 % Add other parameters here
%             };
            

            % Simulate 3600s.
            this.fSimTime = 3600; % [s]
        end
        
        function updateThermalProperties(this)
            
            oTSys = this.oSimulationContainer.toChildren.cooledBar;
            
            mNodeTemperatures = oTSys.getNodeTemperatures();
            cNodes = oTSys.piCapacityIndices.keys();
            nNodes = numel(cNodes);
            
            for iIdx = 1:nNodes
                
                % Get name of node. 
                sNodeName = cNodes{1, iIdx};
                
                % Skip environment node and remove it from the cell. 
                if strcmp(sNodeName, 'Env')
                    %mNodeTemperatures(iIdx) = [];
                    cNodes(:, iIdx) = [];
                    continue;
                end
                
                % Get node and its current temperature and mass.
                %oNode = oTSys.poCapacities(sNodeName);
                fTemp = mNodeTemperatures(iIdx);
                %fMass = oNode.oMatterObject.fMass;
                
                % Get new constants. 
                %fNewCp = oTSys.calcAlCp(fTemp);
                %fNewLamba = oTSys.calcAlLambda(fTemp);
                
                %oNode.overloadTotalHeatCapacity(fMass * fNewCp);
                
                % Store temperature in cell.
                cNodes{2, iIdx} = fTemp;
                
            end
            
            % Get remaining node temperatures.
            mNodeTemperatures = cell2mat(cNodes(2, :));
            
            % The nodes are sorted by the value of the first non-identical
            % character, in this case the first digit, which is the order
            % in they were specified. Hence, we can do this to get the mean
            % temperature between two adjacent nodes: 
            mMeanTemps = (mNodeTemperatures(1:end-1) + mNodeTemperatures(2:end)) / 2;
            
            % Get linear conductors map.
            poLinC = oTSys.poLinearConductors;
            
            % Get handle to |calculateConductance| of conductive heat
            % transfer class.
            hCalcFunc = str2func('thermal.transfers.conductive.calculateConductance');
            
            % Set new conductivities: 
            poLinC('linear:Block1+Block2').setConductivity( ...
                hCalcFunc(oTSys.calcAlLambda(mMeanTemps(1)), 0.0016, 0.05) ...
            );
            poLinC('linear:Block2+Block3').setConductivity( ...
                hCalcFunc(oTSys.calcAlLambda(mMeanTemps(2)), 0.0016, 0.05) ...
            );
            poLinC('linear:Block3+Block4').setConductivity( ...
                hCalcFunc(oTSys.calcAlLambda(mMeanTemps(3)), 0.0016, 0.05) ...
            );
            poLinC('linear:Block4+Block5').setConductivity( ...
                hCalcFunc(oTSys.calcAlLambda(mMeanTemps(4)), 0.0016, 0.05) ...
            );
            
            % Mark thermal container as tainted. 
            oTSys.taint();
            
        end
        
        function plot(this)
            
            this.toMonitors.oPlotter.plot();
%             if ~bKeepWindowsOpen
%                 close all;
%             end
%             
%             mTimes = this.mfLog(:, 1);
% %             load('tat_metalbar_cooled_data');
%             
%             figure('name', 'Temperatures');
%             hold on;
%             grid on;
%             plot(mTimes, this.mfLog(:, 2:6));
%             legend('Capacity 1', 'Capacity 2', 'Capacity 3', 'Capacity 4', 'Capacity 5');
%             ylabel('Temperature in K');
%             xlabel('Time in s');
%             
%             figure('name', 'Total heat capacities');
%             hold on;
%             grid minor;
%             plot(mTimes, this.mfLog(:, 8:12));
%             legend('node 1', 'node 2', 'node 3', 'node 4', 'node 5');
%             ylabel('Heat Capacity in J/K');
%             xlabel('Time in s');
%             
%             figure('name', 'Block 1+2 conductance');
%             hold on;
%             grid minor;
%             plot(mTimes, this.mfLog(:, 13:16));
%             legend('conductor 1 <-> 2', 'conductor 2 <-> 3', 'conductor 3 <-> 4', 'conductor 4 <-> 5');
%             ylabel('Thermal Conductivity in W/K');
%             xlabel('Time in s');
%             
%             tools.arrangeWindows();
        end
        
    end
    
end

