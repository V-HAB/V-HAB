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
            this@simulation('Tutorial_Manipulator', 1e-6);
            
            % Creating the root object
            oExample = tutorials.manipulator_test.systems.Example(this.oRoot, 'Example');
            
            % Create the solver
            oB1 = solver.matter.iterative.branch(oExample.aoBranches(1));
            oB2 = solver.matter.iterative.branch(oExample.aoBranches(2));
            

            
            %% Ignore the contents of this section
            
            oB1.iDampFR = 10;
            oB2.iDampFR = 10;

            % Phases in the Transformer
            aoPhases = this.oRoot.toChildren.Example.toStores.Transformer.aoPhases;
            % Flow Phase
            aoPhases(1).bSynced    = true;
            aoPhases(1).fMaxStep   = 10;
            aoPhases(1).rMaxChange = 0.005;
%             aoPhases(1).fFixedTS   = 1;
            
            % Phases in the main system
%             fMaxStep = 1;
            rMaxChange = 0.01;
            fFixedTS = 1;
            
            aoPhases = this.oRoot.toChildren.Example.toStores.Tank_1.aoPhases;
%             aoPhases(1).fMaxStep   = fMaxStep;
%             aoPhases(1).rMaxChange = rMaxChange;
%             aoPhases(1).fFixedTS   = fFixedTS;
            
            aoPhases = this.oRoot.toChildren.Example.toStores.Tank_2.aoPhases;
%             aoPhases(1).fMaxStep   = fMaxStep;
%             aoPhases(1).rMaxChange = rMaxChange;
%             aoPhases(1).fFixedTS   = fFixedTS;
            
            
            
            %% Logging
            % Creating a cell setting the log items
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';

                % Add other parameters here
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMassToPressure';  % 2
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fMassToPressure';
                'toChildren.Example.toStores.Transformer.aoPhases(1).fMassToPressure'; % 4

                'toChildren.Example.aoBranches(1).fFlowRate';  
                'toChildren.Example.aoBranches(2).fFlowRate'; % 6
                
                'toChildren.Example.aoBranches(1).aoFlows(end).arPartialMass(this.oData.oMT.tiN2I.CO2)';
                'toChildren.Example.aoBranches(2).aoFlows(1).arPartialMass(this.oData.oMT.tiN2I.CO2)'; % 8
                
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMass'; 
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fMass'; % 10
                'toChildren.Example.toStores.Transformer.aoPhases(1).fMass'; 

                
            };
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 5000 * 1;
            %this.fSimTime = 1700;
            this.iSimTicks = 600;
            this.bUseTime = true;
        end
        
        
        
        function plot(this)
            
            close all
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 2:4) .* this.mfLog(:, 9:11));
            legend('Tank 1', 'Tank 2', 'Reactor');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Flow Rates');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 5:6));
            legend('Tank 1 -> Reactor', 'Reactor -> Tank 2');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 9:11 ));
            legend('Mass Tank 1', 'Mass Tank 2', 'Mass Flow Phase');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'CO_2 Partial Masses');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, 7:8 ));
            legend('Transformer IN', 'Transformer OUT');
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

