classdef test_heater < simulation
    
    
    properties
        
    end
    
    methods
        function this = test_heater(bReversed)
            this@simulation('left_to_right');
            
            if nargin < 1 || ~islogical(bReversed), bReversed = false; end
            
            if bReversed
                sDir = 'right_to_left';
            else
                sDir = 'left_to_right';
            end
            
            tutorials.solver_tests.systems.def(this.oRoot, 'Example', sDir, 'iterative', 'heater_and_pipes');
            
            
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
                'toChildren.Example.aoBranches(1).aoFlows(6).fPressure';
                
                'fDummy'; 'fDummy'; 'fDummy'; 'fDummy';
                
                'toChildren.Example.toStores.Tank_Left.aoPhases(1).fTemp'; % 30
                
                'toChildren.Example.aoBranches(1).aoFlows(1).fTemp'; % 31
                'toChildren.Example.aoBranches(1).aoFlows(2).fTemp';
                'toChildren.Example.aoBranches(1).aoFlows(3).fTemp';
                'toChildren.Example.aoBranches(1).aoFlows(4).fTemp';
                'toChildren.Example.aoBranches(1).aoFlows(5).fTemp';
                'toChildren.Example.aoBranches(1).aoFlows(6).fTemp';
                
                'toChildren.Example.toStores.Tank_Right.aoPhases(1).fTemp'; % 37
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
            legend('Tank Left', 'Tank Right');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [ 11 13 ]));
            legend('Tank Left', 'Tank Right');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
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
            plot(this.mfLog(:,1), this.mfLog(:, 20:25));
            legend('Left Flow (EXME)', 'Flow 2', 'Flow 3 preHtr', 'Flow 4 postHtr', 'Right Flow (EXME)');
            ylabel('pressure [Pa]');
            xlabel('Time in s');
            
            
            
            aiF(end + 1) = figure('name', 'Flow Temperatures in Branch 1');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 31:36));
            legend('Left Flow (EXME)', 'Flow 2', 'Flow 3 preHtr', 'Flow 4 postHtr', 'Flow 5', 'Right Flow (EXME)');
            ylabel('temperature [K]');
            xlabel('Time in s');
            
            
            
            aiF(end + 1) = figure('name', 'Flow Temperatures in Branch 1');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [ 30 37 ]));
            legend('Tank Left', 'Tank Right');
            ylabel('temperature [K]');
            xlabel('Time in s');
            
            


%             aiF(end + 1) = figure('name', 'Time Step');
%             hold on;
%             grid minor;
%             plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
%             legend('Solver');
%             ylabel('Time [s]');
%             xlabel('Tick [-]');
%             
            
            
            tools.arrangeWindows();
        end
        
    end
    
end

