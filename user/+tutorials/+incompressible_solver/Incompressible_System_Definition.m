classdef Incompressible_System_Definition < simulation
    % This simulation shows a system of tanks that are calculated
    % incompressible. Tank 1, 2, 3, 4, and 8 form a loop structure while
    % Tank 5, 6 and 7 form a line structure. The loop and line are
    % completly independent from each other
    %
    
    properties
    end
    
    methods
        function this = Incompressible_System_Definition()
            this@simulation('Incompressible_System');
            oIncompressible_System = tutorials.incompressible_solver.systems.Incompressible_System(this.oRoot, 'Incompressible_System', 0);
            warning('off', 'all');
            
            iIncompBranches = 8;
            %This matrix defines which branches form an interdependant
            %loop. For each loop the matrix contains one columns that has
            %the branch number within this loop as row entries. This is
            %required for the steady state calculation to set viable steady
            %state flowrates that allow high time steps.
            mLoopBranches = [1;2;3;4;7;8];
            oIncompressible_System.oSystemSolver = solver.matter.incompressible_liquid.system_incompressible_liquid(oIncompressible_System, 1e-2, 5, 1e-1, 30, iIncompBranches, 10, mLoopBranches);
           
            
            % What to log?
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';
                'oData.oTimer.iTick';
                
                'toChildren.Incompressible_System.aoBranches(1).fFlowRate'; %3
                'toChildren.Incompressible_System.aoBranches(2).fFlowRate'; %4
                'toChildren.Incompressible_System.aoBranches(3).fFlowRate'; %5
                'toChildren.Incompressible_System.aoBranches(4).fFlowRate'; %6
                'toChildren.Incompressible_System.aoBranches(5).fFlowRate'; %7
                'toChildren.Incompressible_System.aoBranches(6).fFlowRate'; %8
                'toChildren.Incompressible_System.aoBranches(7).fFlowRate'; %9
                'toChildren.Incompressible_System.aoBranches(8).fFlowRate'; %10
                
                %pipe pressure loss
                'toChildren.Incompressible_System.aoBranches(1).aoFlowProcs(1).fDeltaPressure'; %11
                'toChildren.Incompressible_System.aoBranches(2).aoFlowProcs(1).fDeltaPressure'; %12
                'toChildren.Incompressible_System.aoBranches(3).aoFlowProcs(1).fDeltaPressure'; %13
                'toChildren.Incompressible_System.aoBranches(4).aoFlowProcs(1).fDeltaPressure'; %14
                'toChildren.Incompressible_System.aoBranches(5).aoFlowProcs(1).fDeltaPressure'; %15
                'toChildren.Incompressible_System.aoBranches(6).aoFlowProcs(1).fDeltaPressure'; %16
                'toChildren.Incompressible_System.aoBranches(7).aoFlowProcs(1).fDeltaPressure'; %17
                'toChildren.Incompressible_System.aoBranches(8).aoFlowProcs(1).fDeltaPressure'; %18
                
                %Fan delta pressure
                'toChildren.Incompressible_System.aoBranches(1).aoFlowProcs(2).fDeltaPressure'; %19
                
                %tank pressures
                'toChildren.Incompressible_System.toStores.Tank_1.aoPhases(1).fPressure'; %20
                'toChildren.Incompressible_System.toStores.Tank_2.aoPhases(1).fPressure'; %21
                'toChildren.Incompressible_System.toStores.Tank_3.aoPhases(1).fPressure'; %22
                'toChildren.Incompressible_System.toStores.Tank_4.aoPhases(1).fPressure'; %23
                'toChildren.Incompressible_System.toStores.Tank_5.aoPhases(1).fPressure'; %24
                'toChildren.Incompressible_System.toStores.Tank_6.aoPhases(1).fPressure'; %25
                'toChildren.Incompressible_System.toStores.Tank_7.aoPhases(1).fPressure'; %26
                'toChildren.Incompressible_System.toStores.Tank_8.aoPhases(1).fPressure'; %27
                
                
                
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
            plot(this.mfLog(:,1), this.mfLog(:, 3:10));
            legend('Branch 1','Branch 2','Branch 3','Branch 4','Branch 5','Branch 6','Branch 7','Branch 8');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'Pipe Pressure Loss');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 11:18));
            legend('Branch 1','Branch 2','Branch 3','Branch 4','Branch 5','Branch 6','Branch 7','Branch 8');
            ylabel('Pressure Loss in Pa');
            xlabel('Time in s');
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 20:27));
            legend('Tank 1', 'Tank 2', 'Tank 3', 'Tank 4', 'Tank 5', 'Tank 6', 'Tank 7', 'Tank 8');
            ylabel('Pressure in Pa');
            xlabel('Time in s');

            
        end
    end
end

