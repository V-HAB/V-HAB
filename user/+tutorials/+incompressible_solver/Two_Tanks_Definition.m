classdef Two_Tanks_Definition < simulation
    % This simulation shows the equalization of pressure between two gas
    % stores over time assuming the BRANCH to be incompressible, the stores
    % are not incompressible since then the equalization would be
    % instantaneous.
    
    properties
    end
    
    methods
        function this = Two_Tanks_Definition()
            this@simulation('Two_Tanks_Incomp');
            oTwo_Tanks = tutorials.incompressible_solver.systems.Two_Tanks(this.oRoot, 'Two_Tanks');
            warning('off', 'all');
            %for branch liquid the second entry is the number of cells used
            %to calculate the branches
            %branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, sCourantAdaption)
            
            %system_incompressible_liquid(oSystem, sStores, fMinTimeStep, fMaxTimeStep, fMaxProcentualFlowSpeedChange, iLastSystemBranch)  
            iIncompBranches = 1;
            oTwo_Tanks.oSystemSolver = solver.matter.incompressible_liquid.system_incompressible_liquid(oTwo_Tanks, 1e-3, 5, 1e-2, 500, iIncompBranches, 10);
           
            
            % What to log?
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';
                'oData.oTimer.iTick';
                
                'toChildren.Two_Tanks.aoBranches(1).fFlowRate'; %3
                
                'toChildren.Two_Tanks.toStores.Tank_1.aoPhases(1).fPressure'; %4
                'toChildren.Two_Tanks.toStores.Tank_2.aoPhases(1).fPressure'; %5
                
                'toChildren.Two_Tanks.toStores.Tank_1.aoPhases(1).fMass'; %6
                'toChildren.Two_Tanks.toStores.Tank_2.aoPhases(1).fMass'; %7
                
                'toChildren.Two_Tanks.toStores.Tank_1.aoPhases(1).fVolume'; %8
                'toChildren.Two_Tanks.toStores.Tank_2.aoPhases(1).fVolume'; %9
                
                'toChildren.Two_Tanks.toStores.Tank_1.aoPhases(1).fTemp'; %10
                'toChildren.Two_Tanks.toStores.Tank_2.aoPhases(1).fTemp'; %11
                
                'toChildren.Two_Tanks.aoBranches(1).aoFlowProcs(1).fDeltaPressure'; %12
                
            };
            
            % Sim time [s]
            this.fSimTime = 30;
        end
        
        function plot(this)
            
            mTimeStep = zeros(length(this.mfLog(:,1))-1,1);
            for k = 1:(length(this.mfLog(:,1))-1)
                mTimeStep(k) = (this.mfLog(k+1,1)-(this.mfLog(k,1)));
            end
            figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(this.mfLog(2:end,1), mTimeStep);
            legend('Timestep');
            ylabel('Timestep in s');
            xlabel('Time in s');
            
            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 3));
            legend('Branch');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 4:5));
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
            
            figure('name', 'Volume Liquids');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 8:9));
            legend('Liquid1', 'Liquid2');
            ylabel('Volume [m³]');
            xlabel('Time in s');
            
            figure('name', 'Temperature Liquids');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 10:11));
            legend('Liquid1', 'Liquid2');
            ylabel('Temperature [K]');
            xlabel('Time in s');
            
            figure('name', 'Pipe Pressure Loss');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 12));
            ylabel('Pressure Loss in Pa');
            xlabel('Time in s');
            
        end
    end
end

