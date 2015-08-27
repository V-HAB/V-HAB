classdef ColdPlateRefDefinition < simulation
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = ColdPlateRefDefinition()
            this@simulation('TestCase_SimpleFlow');
            oColdPlateRef = tutorials.compressible_liquid_solver.systems.ColdPlateRef(this.oRoot, 'ColdPlateRef');
            
            %for branch liquid the second entry is the number of cells used
            %to calculate the branches
            %branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, sCourantAdaption)
            solver.matter.fdm_liquid.branch_liquid(oColdPlateRef.aoBranches(1), 3, 10^-5, 0, 1);
            
            % What to log?
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';
                'oData.oTimer.iTick';
                
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.fTimeStepBranch';
                
                % Add other parameters here
                'toChildren.ColdPlateRef.toStores.Tank_1.aoPhases(1).fPressure';
                'toChildren.ColdPlateRef.toStores.Tank_2.aoPhases(1).fPressure';
                
                'toChildren.ColdPlateRef.aoBranches(1).fFlowRate';
                
                % Add other parameters here
                'toChildren.ColdPlateRef.toStores.Tank_1.aoPhases(1).fMass';
                'toChildren.ColdPlateRef.toStores.Tank_2.aoPhases(1).fMass';
                
                'toChildren.ColdPlateRef.toStores.Tank_1.aoPhases(1).fTemp';
                'toChildren.ColdPlateRef.toStores.Tank_2.aoPhases(1).fTemp';
                
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mPressureOld(1)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mPressureOld(2)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mPressureOld(3)';
                
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mVirtualPressureOld(1)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mVirtualPressureOld(2)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mVirtualPressureOld(3)';
                
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mTemperatureOld(1)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mTemperatureOld(2)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mTemperatureOld(3)';
                
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mVirtualTemperatureOld(1)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mVirtualTemperatureOld(2)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mVirtualTemperatureOld(3)';
                
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mDensityOld(1)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mDensityOld(2)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mDensityOld(3)';
                
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mFlowSpeedOld(1)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mFlowSpeedOld(2)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mFlowSpeedOld(3)';
                
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mPressureLoss(1)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mPressureLoss(2)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mPressureLoss(3)';
                
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mFlowSpeedLoss(1)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mFlowSpeedLoss(2)';
                'toChildren.ColdPlateRef.aoLiquidBranch{1,1}.mFlowSpeedLoss(3)';
                
            };
            
            % Sim time [s]
            this.fSimTime = 0.1;
        end
        
        function plot(this)
            
            figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 3));
            legend('Solver');
            ylabel('Time Step in s');
            xlabel('Time in s');
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 4:5));
            legend('Tank 1', 'Tank 2');
            ylabel('Pressure in Pa');
            xlabel('Time in s');

            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 6));
            legend('Branch1');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 7:8));
            legend('Tank 1', 'Tank 2');
            ylabel('Mass in kg');
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
            plot(this.mfLog(:,1), this.mfLog(:, 11:13));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Virtual Cell Pressure (without Procs)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 14:16));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Cell Temperature (with Procs)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 17:19));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Virtual Cell Temperature (without Procs)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 20:22));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Cell Density');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 23:25));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Density in kg/m³');
            xlabel('Time in s');
            
            figure('name', 'Cell Flow Speed');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 26:28));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Flow Speed in m/s');
            xlabel('Time in s');
            
            figure('name', 'Cell Pressure Loss');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 29:31));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Pressure Loss in N/m²');
            xlabel('Time in s');
            
            figure('name', 'Cell Flow Speed Loss');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 32:34));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Flow Speed Loss in m/s');
            xlabel('Time in s');

        end
    end
    
    
end

