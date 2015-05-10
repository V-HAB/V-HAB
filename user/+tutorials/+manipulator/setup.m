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
        function this = setup()
            this@simulation('Tutorial_Manipulator');
            
            % Creating the root object
            oExample = tutorials.manipulator.systems.Example(this.oRoot, 'Example');
            
            % Create the solver
            oB1 = solver.matter.iterative.branch(oExample.aoBranches(1));
            oB2 = solver.matter.iterative.branch(oExample.aoBranches(2));
            
            %% Ignore the contents of this section
            
            % Set a veeery high fixed time step - the solver will still be
            % called by the phase update methods!
%             oB1.fFixedTS = 10000;
%             oB2.fFixedTS = 10000;
            
%             oB1.iDampFR = 3;
%             oB2.iDampFR = 3;

            % Set fixed time steps for all phases, synced. Means that every
            % tick each phase and both branches are solved.
            % Decrease if flow rates unstable, increase if too slow. If un-
            % stable AND too slow, buy a new computer.
            
            % Phases in the Reactor
%             aoPhases = this.oRoot.toChildren.Example.toStores.Reactor.aoPhases;
            % Flow Phase
%             aoPhases(1).bSynced    = true;
%             aoPhases(1).fMaxStep   = 1;
%             aoPhases(1).rMaxChange = 0.1;
%             aoPhases(1).fFixedTS   = 0.1;
            % Absorber Phase
%             aoPhases(2).bSynced    = true;
%             aoPhases(2).fMaxStep   = 1;
%             aoPhases(2).rMaxChange = 0.1;
%             aoPhases(2).fFixedTS   = 0.1;
            
            % Phases in the main system
%             fMaxStep = 1;
%             rMaxChange = 0.1;
%             fFixedTS = 0.5;
%             
%             aoPhases = this.oRoot.toChildren.Example.toStores.Tank_1.aoPhases;
%             aoPhases(1).fMaxStep   = fMaxStep;
%             aoPhases(1).rMaxChange = rMaxChange;
%             aoPhases(1).fFixedTS   = fFixedTS;
%             
%             aoPhases = this.oRoot.toChildren.Example.toStores.Tank_2.aoPhases;
%             aoPhases(1).fMaxStep   = fMaxStep;
%             aoPhases(1).rMaxChange = rMaxChange;
%             aoPhases(1).fFixedTS   = fFixedTS;
%             
            
            
            %% Logging
            % Creating a cell setting the log items
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';

                % Add other parameters here
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fPressure';  % 2
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fPressure';
                'toChildren.Example.toStores.Reactor.aoPhases(1).fPressure';

                'toChildren.Example.aoBranches(1).fFlowRate';  % 5
                'toChildren.Example.aoBranches(2).fFlowRate';
                'toChildren.Example.toStores.Reactor.oProc.fFlowRate';

                'toChildren.Example.toStores.Tank_2.aoPhases(1).afMass(this.oData.oMT.tiN2I.O2)'; %8
                'toChildren.Example.toStores.Reactor.aoPhases(2).afMass(this.oData.oMT.tiN2I.C)';
                
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMass'; % 10
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fMass';
                'toChildren.Example.toStores.Reactor.aoPhases(1).fMass'; 
                'toChildren.Example.toStores.Reactor.aoPhases(2).fMass';
                
            };
            
            %% Simulation length
            % Stop when specific time in sim is reached
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
            legend('Tank 1', 'Tank 2', 'Reactor');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Flow Rates (1)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 5:6));
            legend('Tank 1 -> Reactor', 'Reactor -> Tank 2');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');

            figure('name', 'Flow Rates (2)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 7));
            legend('Reactor -> Filter');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'Masses (1)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [ 8 10 11 ]));
            legend('O2 Tank 2', 'Mass Tank 1', 'Mass Tank 2');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Masses (2)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [ 9 12 13 ]));
            legend('C in Filter', 'Mass Flow Phase', 'Mass Filter Phase');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Time Step');
            hold on;
            grid minor;
            plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
            legend('Solver');
            ylabel('Time in s');
            xlabel('Ticks [-]');
            
            tools.arrangeWindows();
                
        end
    end
    
end

