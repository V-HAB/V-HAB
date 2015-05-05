classdef test_press_drop < simulation
    
    
    properties
        
    end
    
    methods
        function this = test_press_drop(bReversed)
            this@simulation('left_to_right');
            
            if nargin < 1 || ~islogical(bReversed), bReversed = false; end;
            
            
            sDir = sif(bReversed, 'right_to_left', 'left_to_right');
            
            tutorials.solver_tests.systems.def(this.oRoot, 'Example', sDir, 'iterative', 'pipes');
            
            
            %% Logging
            % Creating a cell setting the log items
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';    % 1
                
                'toChildren.Example.aoBranches(1).fFlowRate';
                
                'fDummy'; 'fDummy'; 'fDummy'; 'fDummy'; 'fDummy'; 'fDummy'; 'fDummy'; 
                
                % Add other parameters here
                'toChildren.Example.toStores.Tank_Left.aoPhases(1).fMassToPressure';  % 10
                'toChildren.Example.toStores.Tank_Left.aoPhases(1).fMass';
                
                'toChildren.Example.toStores.Tank_Right.aoPhases(1).fMassToPressure';  % 12
                'toChildren.Example.toStores.Tank_Right.aoPhases(1).fMass';
                
                'fDummy'; 'fDummy'; 'fDummy'; 'fDummy'; 'fDummy'; 'fDummy';
                
                'toChildren.Example.aoBranches(1).aoFlows(1).fPressure'; % 20
                'toChildren.Example.aoBranches(1).aoFlows(2).fPressure';
                'toChildren.Example.aoBranches(1).aoFlows(3).fPressure';
                'toChildren.Example.aoBranches(1).aoFlows(4).fPressure';
                'toChildren.Example.aoBranches(1).aoFlows(5).fPressure';
            };
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;

        end
        
        function plot(this, bAll) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            aiF = [];
            
            %close all
            
            aiF(end + 1) = figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            %plot(this.mfLog(:,1), this.mfLog(:, [ 10 12 14 ]));
            plot(this.mfLog(:,1), this.mfLog(:, [ 10 12 ]) .* this.mfLog(:, [ 11 13 ]));
            legend('Tank 1', 'Tank 2');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
%             figure('name', 'Tank Masses');
%             hold on;
%             grid minor;
%             plot(this.mfLog(:,1), this.mfLog(:, [ 11 13 ]));
%             legend('Tank 1', 'Tank 2', 'Tank 3');
%             ylabel('Mass in kg');
%             xlabel('Time in s');
            
            aiF(end + 1) = figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 2));
            legend('Branch 1');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            
            
            aiF(end + 1) = figure('name', 'Flow Pressures in Branch 1');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 20:24));
            legend('Left Flow (EXME)', 'Flow 2', 'Flow 3', 'Flow 4', 'Right Flow (EXME)');
            ylabel('pressure [Pa]');
            xlabel('Time in s');
            
            
%             figure('name', 'Time Steps');
%             hold on;
%             grid minor;
%             plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
%             legend('Solver');
%             ylabel('Time in [s]');
%             xlabel('Ticks');
            


            aiF(end + 1) = figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
            legend('Solver');
            ylabel('Time [s]');
            xlabel('Tick [-]');
            
            
            
            tools.arrangeWindows();
        end
        
    end
    
end

