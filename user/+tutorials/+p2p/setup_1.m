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
        function this = setup_1()
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation('Tutorial_p2p');
            
            
            % To increase the frequency of phase updates, uncomment this
            % line. This doesn't mean that the phases update ten times as
            % often, but that they increase their sensitivity towards mass
            % changes within them when calculating the next time step.
            % This can lead to more stable flow rates and with that,
            % possibly to longer instead of shorter time steps.
            % As shown below, the default values set by the phase seal
            % methods can be manually overwritten for specific phases.
            this.oData.set('rUpdateFrequency', 15);
            
            
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
            this.oB1.iDampFR = 15;
            this.oB2.iDampFR = 15;
            
            
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
            this.aoFilterPhases(2).rMaxChange = 0.1;

            
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

