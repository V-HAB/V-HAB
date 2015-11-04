classdef Pump_and_Heater_Circle_Definition < simulation
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = Pump_and_Heater_Circle_Definition()
            this@simulation('TestCase_SimpleFlow');
            oPump_and_Heater_Circle = tutorials.compressible_liquid_solver.systems.Pump_and_Heater_Circle(this.oRoot, 'Pump_and_Heater_Circle');
            
            %for branch liquid the second entry is the number of cells used
            %to calculate the branches
            %branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, sCourantAdaption)
            sCourantAdaption = struct( 'bAdaption', 0,'fIncreaseFactor', 1.005, 'iTicksBetweenIncrease', 50, 'iInitialTicks', 1000, 'fMaxCourantNumber', 0.25);
            solver.matter.fdm_liquid.branch_liquid(oPump_and_Heater_Circle.aoBranches(1), 4, 0, 0, 0.1, sCourantAdaption);
            solver.matter.fdm_liquid.branch_liquid(oPump_and_Heater_Circle.aoBranches(2), 3, 0, 0, 1, sCourantAdaption);
           
            % What to log?
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';
                
                'oData.oTimer.iTick';
                
                % Add other parameters here
                'toChildren.Pump_and_Heater_Circle.toStores.Tank_1.aoPhases(1).fPressure';
                'toChildren.Pump_and_Heater_Circle.toStores.Tank_2.aoPhases(1).fPressure';
                
                'toChildren.Pump_and_Heater_Circle.aoBranches(1).fFlowRate';
                'toChildren.Pump_and_Heater_Circle.aoBranches(2).fFlowRate';
                
                % Add other parameters here
                'toChildren.Pump_and_Heater_Circle.toStores.Tank_1.aoPhases(1).fMass';
                'toChildren.Pump_and_Heater_Circle.toStores.Tank_2.aoPhases(1).fMass';
                
                'toChildren.Pump_and_Heater_Circle.toStores.Tank_1.aoPhases(1).fTemperature';
                'toChildren.Pump_and_Heater_Circle.toStores.Tank_2.aoPhases(1).fTemperature';
                
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mPressureOld(1)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mPressureOld(2)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mPressureOld(3)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mPressureOld(4)';
                
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mVirtualPressureOld(1)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mVirtualPressureOld(2)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mVirtualPressureOld(3)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mVirtualPressureOld(4)';
                
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mTemperatureOld(1)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mTemperatureOld(2)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mTemperatureOld(3)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mTemperatureOld(4)';
                
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mVirtualTemperatureOld(1)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mVirtualTemperatureOld(2)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mVirtualTemperatureOld(3)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mVirtualTemperatureOld(4)';
                
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.fTimeStepBranch';
                
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mDensityOld(1)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mDensityOld(2)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mDensityOld(3)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mDensityOld(4)';
                
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mFlowSpeedOld(1)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mFlowSpeedOld(2)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mFlowSpeedOld(3)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mFlowSpeedOld(4)';
                
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mPressureLoss(1)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mPressureLoss(2)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mPressureLoss(3)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mPressureLoss(4)';
                
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mFlowSpeedLoss(1)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mFlowSpeedLoss(2)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mFlowSpeedLoss(3)';
                'toChildren.Pump_and_Heater_Circle.aoLiquidBranch{1,1}.mFlowSpeedLoss(4)';
                
            };
            
            % Sim time [s]
            this.fSimTime = 5;
        end
        
        function plot(this)
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 3:4));
            legend('Tank 1', 'Tank 2');
            ylabel('Pressure in Pa');
            xlabel('Time in s');

            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 7:8));
            legend('Tank 1', 'Tank 2');
            ylabel('Mass in kg');
            xlabel('Time in s');

            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 5:6));
            legend('Branch1', 'Branch2');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');

            figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 27));
            legend('Solver');
            ylabel('Time Step in s');
            xlabel('Time in s');
            
            figure('name', 'Tank Temperature');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 9:10));
            legend('Tank 1', 'Tank 2');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Cell Pressure (with Procs)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 11:14));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Virtual Cell Pressure (without Procs)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 15:18));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Cell Temperature (with Procs)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 19:22));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Virtual Cell Temperature (without Procs)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 23:26));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Cell Density');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 28:31));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4');
            ylabel('Density in kg/m³');
            xlabel('Time in s');
            
            figure('name', 'Cell Flow Speed');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 32:35));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4');
            ylabel('Flow Speed in m/s');
            xlabel('Time in s');
            
            figure('name', 'Cell Pressure Loss');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 36:39));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4');
            ylabel('Pressure Loss in N/m²');
            xlabel('Time in s');
            
            figure('name', 'Cell Flow Speed Loss');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 40:43));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4');
            ylabel('Flow Speed Loss in m/s');
            xlabel('Time in s');

        end
    end
    
    
end

