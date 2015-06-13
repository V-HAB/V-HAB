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
            this@simulation('Tutorial_Subsystems');
            
            %%%% Tuning of the solving process %%%%
            %
            % Generally, the phases/stores and branches separately schedule
            % their own update method calls. If a phase updates, its
            % internal properties as the heat capacity, density, molecular
            % mass etc. are updated. Additionally, all connected branches
            % are notified so they can re-calculate their flow rate in the
            % 'post tick' phase (i.e. after all regularly scheduled call-
            % backs were executed by the timer object). After the branches
            % update their flow rates, the phase triggers p2p and substance
            % manipulators to update, and finally calculates a new time
            % step for its own, next update call - based on rMaxChange.
            % A solver calculates its time step based on rSetChange and
            % rMaxChange, however, this behaviour will change soon.
            % Additionally, the change in the flow rate set by the solvers
            % can be dampened with iDampFR (see below).
            % If a solver calculates a new flow rate, the connected phases
            % are notified so they can do a 'massupdate', i.e. acutally
            % 'move' the mass, according to the OLD flow rate, from the one
            % connected phase to the other (depending of the sign of the
            % flow rate). If for one of the connected phases, the attribute
            % bSynced is true, all other branches connected to this phase
            % are triggered to re-calculate their flow rate as well.
            %
            % As a general rule of thumb:
            % - if the instabilities in phase masses / pressures are too
            %   high, reduce rMaxChange locally for those phases, or
            %   globally using rUpdateFrequency
            % - if a phase is failry small, activate bSynced which MIGHT
            %   help, as all connected branches calculate new flow rates as
            %   soon as one branch calculates a new one
            % - instabilities can be smoothed out using iDampFR for all
            %   connected branch solvers. However, a high value of iDampFR
            %   might lead to more inaccurate results or even to a hang up
            %   of the solver.
            % - the rSetChange/rMaxChange behaviour in the iterative solver
            %   will be changed soon, so not described here.
            
            
            % To increase the frequency of phase updates, uncomment this
            % line. This doesn't mean that the phases update ten times as
            % often, but that they increase their sensitivity towards mass
            % changes within them when calculating the next time step.
            % This can lead to more stable flow rates and with that,
            % possibly to longer instead of shorter time steps.
            % As shown below, the default values set by the phase seal
            % methods can be manually overwritten for specific phases.
            this.oData.set('rUpdateFrequency', 100);
            
            % Creating the root object
            oExample = tutorials.subsystems.systems.Example(this.oRoot, 'Example');
            
            % For ease of typing, getting a reference to the subsystem object.
            oSubSystem = oExample.toChildren.SubSystem;
            
            % Create the solver instances. Generally, this can be done here
            % or directly within the vsys (after the .seal() command).
            solver.matter.iterative.branch(oSubSystem.aoBranches(1));
            solver.matter.iterative.branch(oSubSystem.aoBranches(2));

            
            %% Solver Tuning
            
            % Phases
            
            oFilterFlowPhase = oSubSystem.toStores.Filter.aoPhases(1);
            oFilterBedPhase  = oSubSystem.toStores.Filter.aoPhases(2);
            
            % To ensure that both branches are always re-calculated at the
            % same time, we set the flow phase of the filter, in the center
            % of the system, between the two branches, to synced. This
            % causes both branches to be re-calculated after every phase
            % update.
            oFilterFlowPhase.bSynced   = true;
            
            % We are not really interested in the pressure, heat capacity
            % etc. of the filtered phase, so we don't need to re-calculate
            % it often. So we set a large maximum change. 
            oFilterBedPhase.rMaxChange = 0.5;

            
            %% Logging
            % Creating a cell setting the log items
            this.csLog = {
                % System timer
                'oData.oTimer.fTime';                                                                   % 1
                
                % Add other parameters here
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMassToPressure';                       % 2
                'toChildren.Example.toStores.Tank_1.aoPhases(1).fMass';                                 % 3
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fMassToPressure';                       % 4
                'toChildren.Example.toStores.Tank_2.aoPhases(1).fMass';                                 % 5
                'toChildren.Example.toChildren.SubSystem.aoBranches(1).fFlowRate';                      % 6
                'toChildren.Example.toChildren.SubSystem.aoBranches(2).fFlowRate';                      % 7
                'toChildren.Example.toChildren.SubSystem.toStores.Filter.aoPhases(1).fMassToPressure';  % 8
                'toChildren.Example.toChildren.SubSystem.toStores.Filter.aoPhases(1).fMass';            % 9
                'toChildren.Example.toChildren.SubSystem.toStores.Filter.aoPhases(2).fMassToPressure';  % 10
                'toChildren.Example.toChildren.SubSystem.toStores.Filter.aoPhases(2).fMass';            % 11
                'toChildren.Example.toChildren.SubSystem.toStores.Filter.oProc.fFlowRate';              % 12
                'toChildren.Example.toStores.Tank_1.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.O2)';% 13
                'toChildren.Example.toStores.Tank_2.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.O2)';% 14
                
                
                };
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 500 * 1; % In seconds
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
            plot(this.mfLog(:,1), this.mfLog(:, [2 4 8]) .* this.mfLog(:, [3 5 9]));
            legend('Tank 1', 'Tank 2', 'Filter');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            figure('name', 'Tank Masses (1)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [3 5]));
            legend('Tank 1', 'Tank 2');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            figure('name', 'Tank Masses (2)');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [9 11]));
            legend('Filter', 'Absorber');
            ylabel('Mass in kg');
            xlabel('Time in s');
                        
            figure('name', 'Flow Rate');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [6 7 12]));
            legend('In', 'Out', 'Filter Flow');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');
            
            figure('name', 'O2 Percentages');
            hold on;
            grid minor;
            plot(this.mfLog(:,1), this.mfLog(:, [13 14]) * 100);
            legend('Tank 1', 'Tank 2');
            ylabel('O2 [%]');
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

