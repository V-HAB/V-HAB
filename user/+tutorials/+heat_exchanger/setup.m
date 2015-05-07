classdef setup < simulation
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
    end
    
    methods
        function this = setup() % Constructor function
            this@simulation('Tutorial_Heat_Exchanger');
            
            % Creating the root object
            oExample = tutorials.heat_exchanger.systems.Example(this.oRoot, 'Example');
            
            
            %% Logging
            % Creating a cell setting the log items
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';                                                   % 1
                
                % Add other parameters here
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fPressure';             % 2
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fPressure';             
                'toChildren.Example.toStores.Tank_3.aoPhases(1).fPressure';             % 4
                'toChildren.Example.toStores.Tank_4.aoPhases(1).fPressure';             
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMass';                 % 6
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fMass';
                'toChildren.Example.toStores.Tank_3.aoPhases(1).fMass';                 % 8
                'toChildren.Example.toStores.Tank_4.aoPhases(1).fMass';
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fTemp';          % 10
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fTemp';
                'toChildren.Example.toStores.Tank_3.aoPhases(1).fTemp';          % 12
                'toChildren.Example.toStores.Tank_4.aoPhases(1).fTemp';
                'toChildren.Example.toProcsF2F.HeatExchanger_1.fHeatFlow';             % 14
                'toChildren.Example.toProcsF2F.HeatExchanger_2.fHeatFlow';
                'toChildren.Example.aoBranches(1).fFlowRate';                           % 16
                'toChildren.Example.aoBranches(2).fFlowRate'; 
                
                
                };
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 1; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;

        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            
            close all
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 2:5));
            legend('Tank 1', 'Tank 2', 'Tank 3', 'Tank 4');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Tank Masses (1)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 6:7 ));
            legend('Tank 1', 'Tank 2');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Tank Masses (2)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 8:9 ));
            legend('Tank 3', 'Tank 4');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Tank Temperatures (1)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 10:11 ));
            legend('Tank 1', 'Tank 2');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'Tank Temperatures (2)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 12:13 ));
            legend('Tank 3', 'Tank 4');
            ylabel('Temperature in K');
            xlabel('Time in s');
            
            figure('name', 'HX Heat Flows');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 14:15 ));
            legend('HX Flow 1', 'HX Flow 2');
            ylabel('Heat Flow in W');
            xlabel('Time in s');
            
            figure('name', 'Flow Rates');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 16:17));
            legend('Gas Branch', 'Liquid Branch');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'Time Steps');
            hold on;
            grid minor;
            plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
            legend('Solver');
            ylabel('Time in [s]');
            xlabel('Ticks');
            
            tools.arrangeWindows();
        end
        
    end
    
end

