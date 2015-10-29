classdef setup_simpleArm < simulation
    %SETUP_SIMPLEARM Runner script/class for example simulation
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function this = setup_simpleArm()
            % Create a new simulation with the system described in
            % |Example_simpleArm|. 
            
            % Initialize simulation with name. 
            this@simulation('TestCase_simpleArm');
            
            % Create system |Example_simpleArm|. 
            oThermalSystem = tutorials.thermal.systems.example_simpleArm(this.oRoot, 'simpleArm');
            
            % Create a new solver.
            oThermalSystem.oThermalSolver = solver.thermal.lumpedparameter(oThermalSystem);
            
            % Register timer callback to update capacities of nodes and
            % thermal conductivities of conductive conductors. 
            this.oTimer.bind(@(o) this.updateMassFlow(o), 1);
            
            % Set what data should be logged.
            %TODO/vhab: This should be done with a method like setLogData?
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';
                
                % Solver & node temperatures
                %'toChildren.simpleArm.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 1)'; % 2
%                 'toChildren.simpleArm.poCapacities(''Arm1Shoulder'').getTemperature()'; % 2
                'toChildren.simpleArm.toStores.Arm.aoPhases(1).fTemperature'; 
                %'toChildren.simpleArm.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 2)'; % 4
%                 'toChildren.simpleArm.poCapacities(''Arm2Upper'').getTemperature()'; % 4
                'toChildren.simpleArm.toStores.Arm.aoPhases(2).fTemperature'; 
                %'toChildren.simpleArm.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 3)'; % 6
%                 'toChildren.simpleArm.poCapacities(''Arm3Elbow'').getTemperature()'; % 6
                'toChildren.simpleArm.toStores.Arm.aoPhases(3).fTemperature'; 
                %'toChildren.simpleArm.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 4)'; % 8
%                 'toChildren.simpleArm.poCapacities(''Arm4Lower'').getTemperature()'; % 8
                'toChildren.simpleArm.toStores.Arm.aoPhases(4).fTemperature';
                %'toChildren.simpleArm.oThermalSolver.getMatrixValueIfExists(''mNodeTemperatures'', 5)'; % 10
%                 'toChildren.simpleArm.poCapacities(''Arm5Hand'').getTemperature()'; % 10
                'toChildren.simpleArm.toStores.Arm.aoPhases(5).fTemperature';
                
                'toChildren.simpleArm.poCapacities(''Env'').getTemperature()'; % 12
                
                'toChildren.simpleArm.poFluidicConductors(''fluidic:Arm1Shoulder+Arm2Upper'').fConductivity'; % 13
                'toChildren.simpleArm.poFluidicConductors(''fluidic:Arm4Lower+Arm5Hand'').fConductivity'; % 14
                
                'toChildren.simpleArm.oThermalSolver.getMatrixValueIfExists(''mNodeCapacities'', 1)'; % 15
                'toChildren.simpleArm.toStores.Arm.aoPhases(1).fTotalHeatCapacity'; 
%                 'toChildren.simpleArm.poCapacities(''Arm1Shoulder'').fOverloadedTotalHeatCapacity';
                'toChildren.simpleArm.toStores.Arm.aoPhases(1).fSpecificHeatCapacity'; 
                'toChildren.simpleArm.oThermalSolver.getMatrixValueIfExists(''mNodeCapacities'', 2)'; % 18
                'toChildren.simpleArm.toStores.Arm.aoPhases(1).fTotalHeatCapacity'; 
%                 'toChildren.simpleArm.poCapacities(''Arm2Upper'').fOverloadedTotalHeatCapacity';
                'toChildren.simpleArm.toStores.Arm.aoPhases(2).fSpecificHeatCapacity'; % 20
                % Add other parameters here
            };
            
            % Simulate 2000s.
            this.fSimTime = 2000; % [s]
            
        end
        
        function updateMassFlow(this, oTimer)
            
            oTSys = this.oRoot.toChildren.simpleArm;
            
            % Get fluidic conductors map.
            poFluidC = oTSys.poFluidicConductors;
            
            if oTimer.fTime > 1100 && oTimer.fTime < 1120
                fFactor = 0.97; % reduce by 3%
            elseif oTimer.fTime > 1580 && oTimer.fTime < 1600
                fFactor = 1.02; % increase by 2%
            else
                return; % Nothing to do here.
            end
            
            %return;
            
            % Adjust mass flow rate.
            oTSys.fMassFlowRate = fFactor * oTSys.fMassFlowRate;
            
            % Get handle to |calculateConductance| of fluidic heat transfer
            % class.
            hCalcFunc = str2func('thermal.transfers.fluidic.calculateConductance');
            
            % Set new conductivities: 
            poFluidC('fluidic:Arm1Shoulder+Arm2Upper').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 1.00*oTSys.fMassFlowRate) ...
            );
            poFluidC('fluidic:Arm2Upper+Arm1Shoulder').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 1.00*oTSys.fMassFlowRate) ...
            );
            
            poFluidC('fluidic:Arm2Upper+Arm3Elbow').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.52*oTSys.fMassFlowRate) ...
            );
            poFluidC('fluidic:Arm3Elbow+Arm2Upper').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.52*oTSys.fMassFlowRate) ...
            );
            
            poFluidC('fluidic:Arm3Elbow+Arm4Lower').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.48*oTSys.fMassFlowRate) ...
            );
            poFluidC('fluidic:Arm4Lower+Arm3Elbow').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.48*oTSys.fMassFlowRate) ...
            );
            
            poFluidC('fluidic:Arm4Lower+Arm5Hand').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.08*oTSys.fMassFlowRate) ...
            );
            poFluidC('fluidic:Arm5Hand+Arm4Lower').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.08*oTSys.fMassFlowRate) ...
            );
            
            % Mark thermal container as tainted.
            oTSys.taint();
            
        end
        
        function plot(this)
            
            close all
            
            mTimes = this.mfLog(812:end, 1);
            
            figure('name', 'Phase Temperatures');
            hold on;
            grid on;
            plot(mTimes, this.mfLog(812:end, 2:6 ));
            legend('node 1', 'node 2', 'node 3', 'node 4', 'node 5');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Node 1+2 & 2+3 conductance');
            hold on;
            grid on;
            plot(mTimes, this.mfLog(812:end, 8:9));
            legend('Shoulder+UpperArm', 'LowerArm+Hand');
            xlabel('Time in s');
            ylabel('Conductance in W/K');
            
            %{
            figure();
            hold on;
            grid on;
            subplot(2,1,1);
            plot(mTimes, this.mfLog(812:end, 3), mTimes, this.mfLog(812:end, 5), mTimes, this.mfLog(812:end, 7), mTimes, this.mfLog(812:end, 9), mTimes, this.mfLog(812:end, 11));
            legend('node 1', 'node 2', 'node 3', 'node 4', 'node 5');
            ylabel('Temperature in K');
            xlabel('Time in s');
            subplot(2,1,2);
            plot(mTimes, this.mfLog(812:end, 13:14));
            legend('Shoulder+UpperArm', 'LowerArm+Hand');
            xlabel('Time in s');
            ylabel('Conductance in W/K');
            %}
            
            tools.arrangeWindows();
        end
        
    end
    
end

