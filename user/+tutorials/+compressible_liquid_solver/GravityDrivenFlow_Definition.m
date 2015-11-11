classdef GravityDrivenFlow_Definition < simulation
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = GravityDrivenFlow_Definition()
            this@simulation('TestCase_SimpleFlow');
            oGravityDrivenFlow = tutorials.compressible_liquid_solver.systems.GravityDrivenFlow(this.oRoot, 'GravityDrivenFlow');
            
            %for branch liquid the second entry is the number of cells used
            %to calculate the branches
            %branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, sCourantAdaption)
            sCourantAdaption = struct( 'bAdaption', 0,'fIncreaseFactor', 1.001, 'iTicksBetweenIncrease', 100, 'iInitialTicks', 10000);
            solver.matter.fdm_liquid.branch_liquid(oGravityDrivenFlow.aoBranches(1), 3, 1*10^-5, 0, 1, sCourantAdaption);
           
            % What to log?
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';
                
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.fTimeStepBranch';
                
                % Add other parameters here
                'toChildren.GravityDrivenFlow.toStores.Tank_1.aoPhases(1).fPressure';
                'toChildren.GravityDrivenFlow.toStores.Tank_2.aoPhases(1).fPressure';
                
                'toChildren.GravityDrivenFlow.aoBranches(1).fFlowRate';
                
                % Add other parameters here
                'toChildren.GravityDrivenFlow.toStores.Tank_1.aoPhases(1).fMass';
                'toChildren.GravityDrivenFlow.toStores.Tank_2.aoPhases(1).fMass';
                
                'toChildren.GravityDrivenFlow.toStores.Tank_1.aoPhases(1).fVolume';
                'toChildren.GravityDrivenFlow.toStores.Tank_2.aoPhases(1).fVolume';
                
                'toChildren.GravityDrivenFlow.aoBranches(1).coExmes{1}.fLiquidLevel';
                'toChildren.GravityDrivenFlow.aoBranches(1).coExmes{2}.fLiquidLevel';
                
                'toChildren.GravityDrivenFlow.toStores.Tank_1.fTotalPressureErrorStore';
                'toChildren.GravityDrivenFlow.toStores.Tank_2.fTotalPressureErrorStore';
                
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mPressureOld(1)';
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mPressureOld(2)';
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mPressureOld(3)';
                
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mFlowSpeedOld(1)';
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mFlowSpeedOld(2)';
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mFlowSpeedOld(3)';
                
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mDensityOld(1)';
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mDensityOld(2)';
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mDensityOld(3)';
                
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mTemperatureOld(1)';
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mTemperatureOld(2)';
                'toChildren.GravityDrivenFlow.aoLiquidBranch{1,1}.mTemperatureOld(3)';
                
                'toChildren.GravityDrivenFlow.toStores.Tank_1.iNestedIntervallCounterStore';
                'toChildren.GravityDrivenFlow.toStores.Tank_2.iNestedIntervallCounterStore';

            };
            
            % Sim time [s]
            this.fSimTime = 10;
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
            plot(this.mfLog(:,1), this.mfLog(:, 6:7));
            legend('Tank 1', 'Tank 2');
            ylabel('Mass in kg');
            xlabel('Time in s');

            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 5));
            legend('Branch1');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');

            figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 2));
            legend('Solver');
            ylabel('Time Step [s]');
            xlabel('Time in s');
            
            figure('name', 'Liquid Volumes');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 8:9));
            legend('Tank 1 Liquid', 'Tank 2 Liquid');
            ylabel('Volume in m³');
            xlabel('Time in s');
            
            figure('name', 'Liquid Levels');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 10:11));
            legend('Tank 1 Liquidlevel', 'Tank 2 Liquidlevel');
            ylabel('Level in m');
            xlabel('Time in s');
            
            
             figure('name', 'Pressure Error in Tanks');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 12:13));
            legend('Tank 1', 'Tank 2');
            ylabel('Error in Pa');
            xlabel('Time in s');
            
            figure('name', 'Cell Pressure');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 14:16));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Cell Flowspeed');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 17:19));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Flowspeed in m/s');
            xlabel('Time in s');
            
            figure('name', 'Cell Density');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 20:22));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Density in kg/m³');
            xlabel('Time in s');
            
            figure('name', 'Cell Temperature');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 23:25));
            legend('Cell 1', 'Cell 2', 'Cell 3');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Steps for Nested Intervall calculation');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 26:27));
            legend('Tank 1', 'Tank 2');
            ylabel('Steps');
            xlabel('Time in s');

        end
    end
    
    
end

