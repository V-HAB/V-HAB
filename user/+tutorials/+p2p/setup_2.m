classdef setup_2 < simulation
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
        function this = setup_2()
            this@simulation('Tutorial_p2p');
            
            % Creating the root object
            oExample = tutorials.p2p.systems.Example2(this.oRoot, 'Example');
            
            % Create the solver
            oB1 = solver.matter.linear.branch(oExample.aoBranches(1));
            oB2 = solver.matter.linear.branch(oExample.aoBranches(2));
            
            %% Ignore the contents of this section
            
            aoPhases = this.oRoot.toChildren.Example.toStores.Filter.aoPhases;
            aoPhases(1).bSynced = true;
            
            %% Logging
            % Creating a cell setting the log items
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';                                           %1

                % Add other parameters here
                'toChildren.Example.toStores.Atmos.aoPhases(1).fPressure';      %2
                'toChildren.Example.toStores.Atmos2.aoPhases(1).fPressure';
                'toChildren.Example.toStores.Filter.aoPhases(1).fPressure';     %4

                'toChildren.Example.aoBranches(1).fFlowRate';                   
                'toChildren.Example.aoBranches(2).fFlowRate';                   %6

                'toChildren.Example.toStores.Filter.oProc.fFlowRate';           

                'toChildren.Example.toStores.Atmos.aoPhases(1).afMass(this.oData.oMT.tiN2I.O2)';      %8
                'toChildren.Example.toStores.Atmos2.aoPhases(1).afMass(this.oData.oMT.tiN2I.O2)';
                'toChildren.Example.toStores.Filter.aoPhases(2).afMass(this.oData.oMT.tiN2I.O2)';     %10

                'toChildren.Example.toStores.Atmos.aoPhases(1).fMass';
                'toChildren.Example.toStores.Atmos2.aoPhases(1).fMass';         %12
                'toChildren.Example.toStores.Filter.aoPhases(2).fMass';         
                'toChildren.Example.toStores.Filter.aoPhases(1).fMass';         %14
            };
            
            %% Simulation length
            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 1;
            %this.fSimTime = 1700;
            this.iSimTicks = 600;
            this.bUseTime = true;
        end
        
        
        
        function plot(this)
            
            close all
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 2:4));
            legend('Atmos', 'Atmos2', 'Filter Flow');
            ylabel('Pressure in Pa');
            xlabel('Time in s');

            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 5:6));
            legend('atmos to filter', 'filter to atmos2');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');

            figure('name', 'Filter Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 7));
            legend('filter filter');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');


            figure('name', 'Tank O2 Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 8:10));
            legend('Atmos', 'Atmos2', 'Filtered');
            ylabel('Mass in kg');
            xlabel('Time in s');

            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 11:14));
            legend('Atmos', 'Atmos2', 'Filter Stored', 'Filter Flow');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            
            figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
            legend('Solver');
            ylabel('Time Step [kg/s]');
            xlabel('Time in s');
            
            tools.arrangeWindows();
        end
    end
    
end

