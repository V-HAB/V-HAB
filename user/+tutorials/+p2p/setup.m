classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
        
        tiLog = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            %if nargin < 1 || isempty(tOpt), tOpt = struct(); end;
            
            
            
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
            
%             if isfield(tOpt, 'rUF'), this.oData.set('rUpdateFrequency', tOpt.rUF);
%             else                     this.oData.set('rUpdateFrequency', 2);
%             end
%             
%             if isfield(tOpt, 'rMD'), this.oData.set('rHighestMaxChangeDecrease', tOpt.rMD);
%             else                     this.oData.set('rHighestMaxChangeDecrease', 25);
%             end
            
%             tSolverParams.rUpdateFrequency = 2;
%             tSolverParams.rHighestMaxChangeDecrease = 25;
            
            % 2 / 25 - 3.3k ticks, ok
            % 1 / 100 - ok - faster (~3.5k ticks?)
            
            
            
            % 5/50 SEHR SCHOEN!!
            % 10/0 SCHNELL!
            % 0.1/1000 - ok
            if ~isfield(tSolverParams, 'rUpdateFrequency')
                tSolverParams.rUpdateFrequency = 0.1;
            end
            
            if ~isfield(tSolverParams, 'rHighestMaxChangeDecrease')
                tSolverParams.rHighestMaxChangeDecrease = 1000;
            end
            
%             tSolverParams.rUpdateFrequency = 0.5;
%             tSolverParams.rHighestMaxChangeDecrease = 100;
            
            %tSolverParams.rUpdateFrequency = 1;
            %tSolverParams.rHighestMaxChangeDecrease = 50;
            
            
            % Params for the monitor logger -> dump to mat!
            ttMonitorCfg = struct();
            %ttMonitorCfg = struct('oLogger', struct('cParams', {{ true, 100 }}));
            
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_p2p', ptConfigParams, tSolverParams, ttMonitorCfg);
            
            
            
            %this.oSimulationContainer.oTimer.setMinStep(1e-12);
            
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation.
            oExample = tutorials.p2p.systems.Example1(this.oSimulationContainer, 'Example');
            
            
            
            %% Simulation length
            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 5000 * 1;
            %this.fSimTime = 1700;
            this.iSimTicks = 600;
            this.bUseTime = true;
            
            
%             this.bUseTime = false;
%             this.iSimTicks = 300;
            
            % Solver Tuning see Example -> createSolverStructure
            
            
            
            
        end
        
        
        
        function configureMonitors(this)
            
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            
            oLogger = this.toMonitors.oLogger;
            
            
            this.tiLog.M2P_Atmos  = oLogger.addValue('Example:s:Atmos.aoPhases(1)', 'fMassToPressure', 'Atmos mass2press', 'Pa/kg');
            this.tiLog.M2P_Filter = oLogger.addValue('Example:s:Filter.aoPhases(1)', 'fMassToPressure', 'Filter mass2press', 'Pa/kg');
            
            this.tiLog.M_Atmos = oLogger.addValue('Example:s:Atmos.aoPhases(1)', 'fMass', 'Atmos Mass', 'kg');
            %oL.addValue('Example:s:Atmos.toPhases.Atmos_Phase_1', 'fMass', 'Atmos Mass', 'kg');
            
            this.tiLog.M_Filter   = oLogger.addValue('Example:s:Filter.aoPhases(1)', 'fMass', 'Filter Mass', 'kg');
            this.tiLog.M_Filtered = oLogger.addValue('Example:s:Filter.aoPhases(2)', 'fMass', 'Filtered Mass', 'kg');
            
            this.tiLog.PM_O2_Atmos    = oLogger.addValue('Example:s:Atmos.aoPhases(1)', 'afMass(this.oMT.tiN2I.O2)', 'Atmos O2', 'kg');
            this.tiLog.PM_O2_Filtered = oLogger.addValue('Example:s:Filter.aoPhases(2)', 'afMass(this.oMT.tiN2I.O2)', 'Filtered O2', 'kg');
            
            this.tiLog.FR_AtmFlt  = oLogger.addValue('Example.aoBranches(1)', 'fFlowRate', 'Flow Rate To Filter', 'kg/s');
            this.tiLog.FR_FltAtm  = oLogger.addValue('Example.aoBranches(2)', 'fFlowRate', 'Flow Rate From Filter', 'kg/s');
            this.tiLog.FR_FltProc = oLogger.addValue('Example:s:Filter.oProc', 'fFlowRate', 'Proc Flow Rate', 'kg/s');
            
            
            
            
% %             oLog = this.toMonitors.oLogger;
% %             
% %             this.tiLog.Atmos_Mass = oLog.addValue('Tutorial_p2p/Example:s:Atmos.aoPhases(1).fMass', 'Atmos Mass', 'kg');
% %             this.tiLog.Filter_Phase1_Mass = oLog.addValue('Tutorial_p2p/Example:s:Filter.aoPhases(1).fMass', 'Filter Mass', 'kg');
% %             this.tiLog.Filter_Phase2_Mass = oLog.addValue('Tutorial_p2p/Example:s:Filter.aoPhases(1).fMass', 'Filtered Mass', 'kg');
% % 
% %             
% %             this.tiLog.FR1 = oLog.addValue('Tutorial_p2p/Example.aoBranches(1).fFlowRate', 'Flow Rate To Filter', 'kg/s');
% %             this.tiLog.FR2 = oLog.addValue('Tutorial_p2p/Example.aoBranches(2).fFlowRate', 'Flow Rate From Filter', 'kg/s');
% %             
% %             this.tiLog.FR1 = oLog.addValue('Tutorial_p2p/Example.aoBranches(1)', 'fFlowRate', 'Flow Rate To Filter', 'kg/s');
            
            
            
%             this.csLog = {
%                 % System timer
%                 'oData.oTimer.fTime';                                           %1
% 
%                 % Add other parameters here
%                 'toChildren.Example.toStores.Atmos.aoPhases(1).fMassToPressure';      %2
%                 'toChildren.Example.toStores.Filter.aoPhases(1).fMassToPressure';     
% 
%                 'toChildren.Example.aoBranches(1).fFlowRate';                   %4
%                 'toChildren.Example.aoBranches(2).fFlowRate';                   
% 
%                 'toChildren.Example.toStores.Filter.oProc.fFlowRate';           %6
% 
%                 'toChildren.Example.toStores.Atmos.aoPhases(1).afMass(this.oData.oMT.tiN2I.O2)';      
%                 'toChildren.Example.toStores.Filter.aoPhases(2).afMass(this.oData.oMT.tiN2I.O2)';     %8
% 
%                 'toChildren.Example.toStores.Atmos.aoPhases(1).fMass';
%                 'toChildren.Example.toStores.Filter.aoPhases(2).fMass';         %10
%                 'toChildren.Example.toStores.Filter.aoPhases(1).fMass';         
%             };
            
        end
        
        
        
        function plot(this)
            
            %close all 
            
            oLogger = this.toMonitors.oLogger;
            
            [ mfLog, tConfig ] = oLogger.get(1:length(oLogger.tLogValues));
            
            
            
            figure('name', 'Tank Pressures');
            hold on;
            grid minor;
            %plot(this.mfLog(:,1), this.mfLog(:, [ 2 3 ]) .* this.mfLog(:, [ 9 11 ]));
            plot(oLogger.afTime, mfLog(:, [ 1 2 ]) .* mfLog(:, [ 3 4 ]));
            %plot(oLogger.afTime, mfLog(:, [ this.tiLog.M2P_Atmos this.tiLog.M2P_Filter ]) .* mfLog(:, [ this.tiLog.M_Atmos this.tiLog.M_Filter ]));
            legend('Atmos', 'Filter Flow');
            ylabel('Pressure in Pa');
            xlabel('Time in s');
            
            
            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            plot(oLogger.afTime, mfLog(:, [ 3 4 5 ]));
            legend('Atmos', 'Filter Flow', 'Filtered');
%             plot(oLogger.afTime, mfLog(:, [ 4 ]));
%             legend('Filter Flow');
            ylabel('Mass in kg');
            xlabel('Time in s');

            
            
            %oPlotter.addPlot({ 'FR1', 'FR2' }, 'Filter Flow Rates');
            
            
            figure('name', 'Flow Rates');
            hold on;
            grid minor;
            %plot(this.mfLog(:,1), this.mfLog(:, [ this.tiLog.FR1 this.tiLog.FR2 ]));
            plot(oLogger.afTime, mfLog(:, [ 8 9 ]));
            legend('atmos to filter', 'filter to atmos');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');

            figure('name', 'Filter Rate');
            hold on;
            grid minor;
            %plot(this.mfLog(:,1), this.mfLog(:, 6));
            plot(oLogger.afTime, mfLog(:, 10));
            legend('filter filter');
            ylabel('flow rate [kg/s]');
            xlabel('Time in s');


            figure('name', 'Tank O2 Masses');
            hold on;
            grid minor;
            %plot(this.mfLog(:,1), this.mfLog(:, 7:8));
            plot(oLogger.afTime, mfLog(:, [ 6 7 ]));
            legend('Atmos', 'Filtered');
            ylabel('Mass in kg');
            xlabel('Time in s');

            figure('name', 'Tank Masses');
            hold on;
            grid minor;
            %plot(this.mfLog(:,1), this.mfLog(:, 9:11));
            plot(oLogger.afTime, mfLog(:, [ 3 4 5 ]));
            legend('Atmos', 'Filter Flow', 'Filter Stored');
            ylabel('Mass in kg');
            xlabel('Time in s');
            
            
            figure('name', 'Time Step');
            hold on;
            grid minor;
            %plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
            plot(1:length(oLogger.afTime), oLogger.afTime, '-*');
            legend('Solver');
            ylabel('Time Step [kg/s]');
            xlabel('Time in s');
            
            tools.arrangeWindows();
        end
    end
    
end

