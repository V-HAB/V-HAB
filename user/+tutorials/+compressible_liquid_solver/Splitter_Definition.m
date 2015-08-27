classdef Splitter_Definition < simulation
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function this = Splitter_Definition()
            this@simulation('TestCase_SimpleFlow');
            oSplitter = tutorials.compressible_liquid_solver.systems.Splitter(this.oRoot, 'Splitter');
            
            %for branch liquid the second entry is the number of cells used
            %to calculate the branches
            %branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, sCourantAdaption)
            solver.matter.fdm_liquid.branch_liquid(oSplitter.aoBranches(1), 6, 10^-5, 0, 0.01);
            solver.matter.fdm_liquid.branch_liquid(oSplitter.aoBranches(2), 6, 10^-5, 0, 0.01);
            solver.matter.fdm_liquid.branch_liquid(oSplitter.aoBranches(3), 6, 10^-5, 0, 0.01);
            solver.matter.fdm_liquid.branch_liquid(oSplitter.aoBranches(4), 6, 10^-5, 0, 0.01);
           
            % What to log?
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';
                'oData.oTimer.iTick';
                
                'toChildren.Splitter.aoLiquidBranch{1,1}.fTimeStepBranch';
                
                % Add other parameters here
                'toChildren.Splitter.toStores.Tank_1.aoPhases(1).fPressure';
                'toChildren.Splitter.toStores.Tank_2.aoPhases(1).fPressure';
                'toChildren.Splitter.toStores.Tank_3.aoPhases(1).fPressure';
                'toChildren.Splitter.toStores.Tank_4.aoPhases(1).fPressure';
                'toChildren.Splitter.toStores.Splitter.aoPhases(1).fPressure';
   
                % Add other parameters here
                'toChildren.Splitter.toStores.Tank_1.aoPhases(1).fMass';
                'toChildren.Splitter.toStores.Tank_2.aoPhases(1).fMass';
                'toChildren.Splitter.toStores.Tank_3.aoPhases(1).fMass';
                'toChildren.Splitter.toStores.Tank_4.aoPhases(1).fMass';
                'toChildren.Splitter.toStores.Splitter.aoPhases(1).fMass';
                
                'toChildren.Splitter.toStores.Tank_1.aoPhases(1).fVolume';
                'toChildren.Splitter.toStores.Tank_2.aoPhases(1).fVolume';
                'toChildren.Splitter.toStores.Tank_3.aoPhases(1).fVolume';
                'toChildren.Splitter.toStores.Tank_4.aoPhases(1).fVolume';
                'toChildren.Splitter.toStores.Splitter.aoPhases(1).fVolume';
                
                'toChildren.Splitter.toStores.Tank_1.aoPhases(1).fTemp';
                'toChildren.Splitter.toStores.Tank_2.aoPhases(1).fTemp';
                'toChildren.Splitter.toStores.Tank_3.aoPhases(1).fTemp';
                'toChildren.Splitter.toStores.Tank_4.aoPhases(1).fTemp';
                'toChildren.Splitter.toStores.Splitter.aoPhases(1).fTemp';
                
             	'toChildren.Splitter.aoBranches(1).fFlowRate';
                'toChildren.Splitter.aoBranches(1).fFlowRate';
                'toChildren.Splitter.aoBranches(1).fFlowRate';
                'toChildren.Splitter.aoBranches(1).fFlowRate';
                

            };
            
            % Sim time [s]
            this.fSimTime = 0.001;
        end
        
        function plot(this)
            
          	figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 3));
            legend('Timestep');
            ylabel('Timestep in s');
            xlabel('Time in s');
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 4:8));
            legend('Tank 1', 'Tank 2', 'Tank 3', 'Tank 4', 'Splitter');
            ylabel('Pressure in Pa');
            xlabel('Time in s');

            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 9:13));
            legend('Tank 1', 'Tank 2', 'Tank 3', 'Tank 4', 'Splitter');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Volume Liquids');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 14:18));
            legend('Tank 1', 'Tank 2', 'Tank 3', 'Tank 4', 'Splitter');
            ylabel('Volume [m³]');
            xlabel('Time in s');
            
            figure('name', 'Temperature Liquids');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 19:23));
            legend('Tank 1', 'Tank 2', 'Tank 3', 'Tank 4', 'Splitter');
            ylabel('Temperature [K]');
            xlabel('Time in s');
            
            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 24:27));
            legend('Branch1', 'Branch2', 'Branch3', 'Branch4');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            
        end
    end
    
    
end

