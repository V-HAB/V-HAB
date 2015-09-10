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
        oB1;
        oB2;
        
        aoFilterPhases;
        oAtmosPhase;
    end
    
    methods
        function this = setup_1(tOpt)
            
            if nargin < 1 || isempty(tOpt), tOpt = struct(); end;
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation('Tutorial_p2p');
            
            
            %%%% Tuning of the solving process %%%%
            %
            % Generally, the phases/stores and branches separately schedule
            % their own update method calls. If a phase updates, its
            % internal properties as the heat capacity, density, molar
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
            
            % FASTEST set: rUF = 2, rMD = 25 (~2.5k ticks)
            % Slower, but nicer: 15/5, 5/25, 1/125 (>3k ticks)
            % NICE: rUF = 1, rMD = 150; 1/250, 2.5/100, 10/20 (~4.5k ticks)
            
            if isfield(tOpt, 'rUF'), this.oData.set('rUpdateFrequency', tOpt.rUF);
            else                     this.oData.set('rUpdateFrequency', 2);
            end
            
            if isfield(tOpt, 'rMD'), this.oData.set('rHighestMaxChangeDecrease', tOpt.rMD);
            else                     this.oData.set('rHighestMaxChangeDecrease', 25);
            end
            
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation.
            oExample = tutorials.p2p.systems.Example1(this.oRoot, 'Example');
            
            % Create the solver instances. Generally, this can be done here
            % or directly within the vsys (after the .seal() command).
            this.oB1 = solver.matter.iterative.branch(oExample.aoBranches(1));
            this.oB2 = solver.matter.iterative.branch(oExample.aoBranches(2));
            
            
            %% Solver Tuning
            
            % The flow rate is driven by the fan within branch 1, and flows
            % through a rather small filter volume. This combination leads
            % to instabilities in the flow rate. Using this parameter, the
            % solvers reduce the changes in flow rates:
            % fFlowRate = (fNewFR + iDampFR * fOldFR) / (iDampFR + 1)
            this.oB1.iDampFR = 5;
            this.oB2.iDampFR = 5;
            
            
            % Phases
            
            this.aoFilterPhases = this.oRoot.toChildren.Example.toStores.Filter.aoPhases;
            this.oAtmosPhase    = this.oRoot.toChildren.Example.toStores.Atmos.aoPhases(1);
            
            % As the input flow rate can change quickly due to the fan, and
            % the filter flow phase is rather small, it can help to 'sync'
            % the flow rate solvers connected to this phase. This means
            % that as soon as the flow rate of one of the solvers changes,
            % the other solvers will also immediately calculate a new FR.
            this.aoFilterPhases(1).bSynced = true;
            
            
            % The phase for the adsorbed matter in the filter store has a
            % small rMaxChange (small volume) but is not really important
            % for the solving process, so increase rMaxChange manually.
            this.aoFilterPhases(2).rMaxChange = 5;

            
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
            plot(this.mfLog(:,1), this.mfLog(:, [ 2 3 ]) .* this.mfLog(:, [ 9 11 ]));
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

