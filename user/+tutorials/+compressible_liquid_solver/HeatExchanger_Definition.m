classdef HeatExchanger_Definition < simulation
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = HeatExchanger_Definition()
            this@simulation('TestCase_HeatExchanger');
            oHeatExchangerSystem = tutorials.compressible_liquid_solver.systems.HeatExchangerSystem(this.oRoot, 'HeatExchangerSystem');
            
            %for branch liquid the second entry is the number of cells used
            %to calculate the branches
            %branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, sCourantAdaption)
            sCourantAdaption = struct( 'bAdaption', 0,'fIncreaseFactor', 1.001, 'iTicksBetweenIncrease', 100, 'iInitialTicks', 10000, 'fMaxCourantNumber', 1);
            solver.matter.fdm_liquid.branch_liquid(oHeatExchangerSystem.aoBranches(1), 3, 0, 0, 1, sCourantAdaption);
            solver.matter.fdm_liquid.branch_liquid(oHeatExchangerSystem.aoBranches(2), 3, 0, 0, 1, sCourantAdaption);
            solver.matter.fdm_liquid.branch_liquid(oHeatExchangerSystem.aoBranches(3), 3, 0, 0, 1, sCourantAdaption);
            solver.matter.fdm_liquid.branch_liquid(oHeatExchangerSystem.aoBranches(4), 3, 0, 0, 1, sCourantAdaption);
            
            % What to log?
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';
                'oData.oTimer.iTick';
                                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.fTimeStepBranch'; %3
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.fTimeStepBranch'; %4
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,3}.fTimeStepBranch'; %5
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,4}.fTimeStepBranch'; %6
                
                'toChildren.HeatExchangerSystem.aoBranches(1).fFlowRate'; %7
                'toChildren.HeatExchangerSystem.aoBranches(2).fFlowRate'; %8
                'toChildren.HeatExchangerSystem.aoBranches(3).fFlowRate'; %9
                'toChildren.HeatExchangerSystem.aoBranches(4).fFlowRate'; %10
                
                'toChildren.HeatExchangerSystem.toStores.Tank_1.aoPhases(1).fPressure'; %11
                'toChildren.HeatExchangerSystem.toStores.Tank_2.aoPhases(1).fPressure'; %12
                'toChildren.HeatExchangerSystem.toStores.Tank_3.aoPhases(1).fPressure'; %13
                'toChildren.HeatExchangerSystem.toStores.Tank_4.aoPhases(1).fPressure'; %14
                
                'toChildren.HeatExchangerSystem.toStores.Tank_1.aoPhases(1).fMass'; %15
                'toChildren.HeatExchangerSystem.toStores.Tank_2.aoPhases(1).fMass'; %16
                'toChildren.HeatExchangerSystem.toStores.Tank_3.aoPhases(1).fMass'; %17
                'toChildren.HeatExchangerSystem.toStores.Tank_4.aoPhases(1).fMass'; %18
                                
                'toChildren.HeatExchangerSystem.toStores.Tank_1.aoPhases(1).fTemperature'; %19
                'toChildren.HeatExchangerSystem.toStores.Tank_2.aoPhases(1).fTemperature'; %20
                'toChildren.HeatExchangerSystem.toStores.Tank_3.aoPhases(1).fTemperature'; %21
                'toChildren.HeatExchangerSystem.toStores.Tank_4.aoPhases(1).fTemperature'; %22
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mPressureOld(1)'; %23
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mPressureOld(2)'; %24
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mPressureOld(3)'; %25
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mPressureOld(1)'; %26
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mPressureOld(2)'; %27
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mPressureOld(3)'; %28
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mFlowSpeedOld(1)'; %29
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mFlowSpeedOld(2)'; %30
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mFlowSpeedOld(3)'; %31
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mFlowSpeedOld(1)'; %32
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mFlowSpeedOld(2)'; %33
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mFlowSpeedOld(3)'; %34
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mDensityOld(1)'; %35
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mDensityOld(2)'; %36
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mDensityOld(3)'; %37
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mDensityOld(1)'; %38
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mDensityOld(2)'; %39
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mDensityOld(3)'; %40
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mTemperatureOld(1)'; %41
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mTemperatureOld(2)'; %42
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,1}.mTemperatureOld(3)'; %43
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mTemperatureOld(1)'; %44
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mTemperatureOld(2)'; %45
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,2}.mTemperatureOld(3)'; %46
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,3}.mPressureOld(1)'; %47
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,3}.mPressureOld(2)'; %48
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,3}.mPressureOld(3)'; %49
                
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,3}.mFlowSpeedOld(1)'; %50
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,3}.mFlowSpeedOld(2)'; %51
                'toChildren.HeatExchangerSystem.aoLiquidBranch{1,3}.mFlowSpeedOld(3)'; %52
            };
            
            % Sim time [s]
            this.fSimTime = 5;
        end
        
        function plot(this)
            
            figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 3:6));
            legend('Branch 1', 'Branch 2', 'Branch 3', 'Branch 4');
            ylabel('Timestep in s');
            xlabel('Time in s');
            
            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 7:10));
            legend('Branch 1', 'Branch 2', 'Branch 3', 'Branch 4');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 11:14));
            legend('Tank 1', 'Tank 2', 'Tank 3', 'Tank 4');
            ylabel('Pressure in Pa');
            xlabel('Time in s');

            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 15:18));
            legend('Tank 1', 'Tank 2', 'Tank 3', 'Tank 4');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Temperature Liquids');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 19:22));
            legend('Tank 1', 'Tank 2', 'Tank 3', 'Tank 4');
            ylabel('Temperature [K]');
            xlabel('Time in s');
            
            %values for the individual cells
            figure('name', 'Cell Pressure Branch 1');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 23:25));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            
            figure('name', 'Cell Pressure Branch 2');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 26:28));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Cell Flowspeed Branch 1');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 29:31));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Flowspeed in m/s');
            xlabel('Time in s');
            
            figure('name', 'Cell Flowspeed Branch 2');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 32:34));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Flowspeed in m/s');
            xlabel('Time in s');
            
            figure('name', 'Cell Density Branch 1');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 35:37));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Density in kg/m³');
            xlabel('Time in s');
            
            figure('name', 'Cell Density Branch 2');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 38:40));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Density in kg/m³');
            xlabel('Time in s');

            figure('name', 'Cell Temperature Branch 1');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 41:43));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Cell Temperature Branch 2');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 44:46));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Cell Pressure Branch 3');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 47:49));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Cell Flowspeed Branch 3');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 50:52));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Flowspeed in m/s');
            xlabel('Time in s');

        end
    end
    
    
end

