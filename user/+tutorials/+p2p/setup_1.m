classdef setup_1 < simulation
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
        function this = setup_1()
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation('Tutorial_p2p');
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation.
            tutorials.p2p.systems.Example1(this.oRoot, 'Example');
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';                                           %1

                % Add other parameters here
                'toChildren.Example.toStores.Atmos.aoPhases(1).fMassToPressure';      %2
                'toChildren.Example.toStores.Filter.aoPhases(1).fMassToPressure';     

                'toChildren.Example.aoBranches(1).fFlowRate';                   %4
                'toChildren.Example.aoBranches(2).fFlowRate';                   

                'toChildren.Example.toStores.Filter.oProc.fFlowRate';           %6

                'toChildren.Example.toStores.Atmos.aoPhases(1).afMass(this.oData.oMT.tiN2I.O2)';      
                'toChildren.Example.toStores.Filter.aoPhases(2).afMass(this.oData.oMT.tiN2I.O2)';     %8

                'toChildren.Example.toStores.Atmos.aoPhases(1).fMass';
                'toChildren.Example.toStores.Filter.aoPhases(2).fMass';         %10
                'toChildren.Example.toStores.Filter.aoPhases(1).fMass';         
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
            plot(this.mfLog(:,1), this.mfLog(:, 2:3) .* this.mfLog(:, [9 11]));
            legend('Atmos', 'Filter Flow');
            ylabel('Pressure in Pa');
            xlabel('Time in s');

            figure('name', 'Flow Rates');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 4:5));
            legend('atmos to filter', 'filter to atmos');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');

            figure('name', 'Filter Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 6));
            legend('filter filter');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');


            figure('name', 'Tank O2 Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 7:8));
            legend('Atmos', 'Filtered');
            ylabel('Mass in kg');
            xlabel('Time in s');

            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 9:11));
            legend('Atmos', 'Filter Stored', 'Filter Flow');
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

