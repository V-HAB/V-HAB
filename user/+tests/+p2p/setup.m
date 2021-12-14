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
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime)
            
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
            
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Test_P2P', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            
            
            %this.oSimulationContainer.oTimer.setMinStep(1e-12);
            
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation.
            oExample = tutorials.p2p.stationary.systems.Example(this.oSimulationContainer, 'Example');
            
            
            
            %% Simulation length
            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 5000 * 1;
            
            if nargin >= 4 && ~isempty(fSimTime)
                this.fSimTime = fSimTime;
            end
            
            
            %this.fSimTime = 1700;
            this.iSimTicks = 3000;
            this.bUseTime = true;
            
            
%             this.bUseTime = false;
%             this.iSimTicks = 300;
            
            % Solver Tuning see Example -> createSolverStructure
            
            
            
            % Register callback for debug state
            %   -> dependent, i.e. no 'own' time step, just exec each tick
            this.oSimulationContainer.oTimer.bind(@this.switchDebugState, -1, struct('sMethod', 'switchDebugState', 'sDescription', 'setup - logdbg ctrl fct'));
            
        end
        
        
        
        function switchDebugState(this, oTimer)
            
            % TO DO: Move this to a seperate tutorial! The basic P2P
            % tutorial should not throw a bunch of debugging messages in
            % between
            return;
            
            iTick  = oTimer.iTick;
            oOut   = this.toMonitors.oConsoleOutput;
            
            if iTick == 1015
                oOut.setLogOn();
                
            elseif iTick == 1020
                oOut.addIdentFilter('update');
            
            elseif iTick == 1030
                oOut.resetIdentFilters();
                oOut.toggleShowStack();
            
            elseif iTick == 1035
                oOut.toggleShowStack();
            
            elseif iTick == 1040
                oOut.setVerbosity(3);
            
            elseif iTick == 1045
                oOut.setVerbosity(1);
            
            elseif iTick == 1050
                oOut.setLevel(2);
            
            elseif iTick == 1055
                oOut.setLogOff();
            end
            
            
            %TODO e.g. set level/verbosity, filter by some identifiers to
            %     show some specific behaviour.
            %     get objs uuids via this.oSimCont.toChildren.(...)
            %           -> filter by those UUIDs, e.g. just one phase debug
        end
        
        
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLog.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLog.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
            
            oLog.addValue('Example:s:Atmos.aoPhases(1)', 'afMass(this.oMT.tiN2I.O2)',   'kg',       'O_2 Mass in Atmosphere');
            oLog.addValue('Example:s:Filter.aoPhases(2)', 'afMass(this.oMT.tiN2I.O2)',  'kg',       'O_2 Mass in Filter');
            
            oLog.addValue('Example:s:Filter.toProcsP2P.filterproc', 'fFlowRate',                        'kg/s',  	'P2P Filter Flow Rate');
            
        end
        
        function plot(this) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);
            
            csIndividualPlots = {'"O_2 Mass in Atmosphere"', '"O_2 Mass in Filter"',  '"P2P Filter Flow Rate"'};

            coPlots{1,1} = oPlotter.definePlot(csPressures,     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csTemperatures,  'Temperatures', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csIndividualPlots,  'Random Plots', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end

