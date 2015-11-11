classdef Two_Tanks_Definition < simulation
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = Two_Tanks_Definition()
            this@simulation('TestCase_SimpleFlow');
            oTwo_Tanks = tutorials.compressible_liquid_solver.systems.Two_Tanks(this.oRoot, 'Two_Tanks');
            
            oTwo_Tanks.oDefinition = this;
            %for branch liquid the second entry is the number of cells used
            %to calculate the branches
            %branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, sCourantAdaption)
            sCourantAdaption = struct( 'bAdaption', 0,'fIncreaseFactor', 1.001, 'iTicksBetweenIncrease', 100, 'iInitialTicks', 10000, 'fMaxCourantNumber', 1);
            solver.matter.fdm_liquid.branch_liquid(oTwo_Tanks.aoBranches(1), 10, 10^-5, 0, 1, sCourantAdaption);
           
            % What to log?
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';
                'oData.oTimer.iTick';
                                
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.fTimeStepBranch'; %3
                
                'toChildren.Two_Tanks.aoBranches(1).fFlowRate'; %4
                
                'toChildren.Two_Tanks.toStores.Tank_1.aoPhases(1).fPressure'; %5
                'toChildren.Two_Tanks.toStores.Tank_2.aoPhases(1).fPressure'; %6
                
                'toChildren.Two_Tanks.toStores.Tank_1.aoPhases(1).fMass'; %7
                'toChildren.Two_Tanks.toStores.Tank_2.aoPhases(1).fMass'; %8
                
                'toChildren.Two_Tanks.toStores.Tank_1.aoPhases(1).fVolume'; %9
                'toChildren.Two_Tanks.toStores.Tank_2.aoPhases(1).fVolume'; %10
                
                'toChildren.Two_Tanks.toStores.Tank_1.aoPhases(1).fTemperature'; %11
                'toChildren.Two_Tanks.toStores.Tank_2.aoPhases(1).fTemperature'; %12
                
                'toChildren.Two_Tanks.toStores.Tank_1.fTotalPressureErrorStore'; %13
                'toChildren.Two_Tanks.toStores.Tank_2.fTotalPressureErrorStore'; %14

                'toChildren.Two_Tanks.toStores.Tank_1.iNestedIntervallCounterStore'; %15
                'toChildren.Two_Tanks.toStores.Tank_2.iNestedIntervallCounterStore'; %16
                
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(1)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(2)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(3)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(4)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(5)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(6)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(7)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(8)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(9)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureOld(10)';
                
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(1)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(2)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(3)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(4)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(5)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(6)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(7)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(8)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(9)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mFlowSpeedOld(10)';
                
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(1)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(2)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(3)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(4)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(5)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(6)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(7)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(8)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(9)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mDensityOld(10)';
                
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(1)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(2)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(3)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(4)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(5)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(6)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(7)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(8)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(9)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mTemperatureOld(10)';

                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(1)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(2)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(3)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(4)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(5)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(6)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(7)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(8)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(9)';
                'toChildren.Two_Tanks.aoLiquidBranch{1,1}.mPressureLoss(10)';
                
                'oData.oTimer.afTimeStep(1)';
                'oData.oTimer.afTimeStep(2)';
                'oData.oTimer.afTimeStep(3)';
                'oData.oTimer.afTimeStep(4)';
            };
            
            % Sim time [s]
            this.fSimTime = 0.005;
        end
        
        function plot(this)
            
            figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 3));
            legend('Timestep');
            ylabel('Timestep in s');
            xlabel('Time in s');
            
            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 4));
            legend('Branch');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 5:6));
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
            
            figure('name', 'Volume Liquids');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 9:10));
            legend('Liquid1', 'Liquid2');
            ylabel('Volume [m³]');
            xlabel('Time in s');
            
            figure('name', 'Temperature Liquids');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 11:12));
            legend('Liquid1', 'Liquid2');
            ylabel('Temperature [K]');
            xlabel('Time in s');
            
            figure('name', 'Pressure Error in Tanks');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 13:14));
            legend('Tank 1', 'Tank 2');
            ylabel('Error in Pa');
            xlabel('Time in s');
            
            figure('name', 'Steps for Nested Intervall calculation');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 15:16));
            legend('Tank 1', 'Tank 2');
            ylabel('Steps');
            xlabel('Time in s');
            
            %values for the individual cells
            figure('name', 'Cell Pressure');
            hold on;
            grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, 17:19));
%             legend('Cell 1', 'Cell 2', 'Cell 3');
            plot(this.mfLog(:,1), this.mfLog(:, 17:26));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4', 'Cell 5', 'Cell 6', 'Cell 7', 'Cell 8', 'Cell 9', 'Cell 10');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Cell Flowspeed');
            hold on;
            grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, 20:22));
%            legend('Cell 1', 'Cell 2', 'Cell 3');
            plot(this.mfLog(:,1), this.mfLog(:, 27:36));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4', 'Cell 5', 'Cell 6', 'Cell 7', 'Cell 8', 'Cell 9', 'Cell 10');
            ylabel('Flowspeed in m/s');
            xlabel('Time in s');
            
            figure('name', 'Cell Density');
            hold on;
            grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, 23:25));
%             legend('Cell 1', 'Cell 2', 'Cell 3');
            plot(this.mfLog(:,1), this.mfLog(:, 37:46));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4', 'Cell 5', 'Cell 6', 'Cell 7', 'Cell 8', 'Cell 9', 'Cell 10');
            ylabel('Density in kg/m³');
            xlabel('Time in s');

            figure('name', 'Cell Temperature');
            hold on;
            grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, 26:28));
%             legend('Cell 1', 'Cell 2', 'Cell 3');
            plot(this.mfLog(:,1), this.mfLog(:, 47:56));
            legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4', 'Cell 5', 'Cell 6', 'Cell 7', 'Cell 8', 'Cell 9', 'Cell 10');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Cell Pressure Loss');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 57:66));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Pressure Loss in Pa');
            xlabel('Time in s');


            A = ~isnan(this.mfLog(:,1));
            mTimeStep = zeros(length(this.mfLog(A,1)),1);
            for k = 1:length(this.mfLog(A,1))-1
                mTimeStep(k,1) = this.mfLog(k+1,1)-this.mfLog(k,1);
            end
            
            figure('name', 'TimeStep');
            hold on;
            grid minor;
            plot(this.mfLog(1:length(mTimeStep),1), mTimeStep(:,1));
            legend('TimeStep');
            ylabel('System Timestep in s');
            xlabel('Time in s');
            
            
            figure('name', 'TimeStep');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 67:70));
            legend('VSys', 'Store1', 'Store2', 'Branch');
            ylabel('Timestep in s');
            xlabel('Time in s');
            
        end
    end
    
    
end

