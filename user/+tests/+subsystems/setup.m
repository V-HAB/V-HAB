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
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) % Constructor function
            
            
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
            %this.oData.set('rUpdateFrequency', 100);
            
            
            
            if ~isfield('tSolverParams', 'rHighestMaxChangeDecrease')
                tSolverParams.rHighestMaxChangeDecrease = 500;
            end
            
            
            
            this@simulation.infrastructure('Test_Subsystems', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            
            
            
            % Creating the root object
            oExample = tutorials.subsystems.systems.Example(this.oSimulationContainer, 'Example');
            
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 3600;
            else 
                this.fSimTime = fSimTime;
            end
            
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
            
            csStoresSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystem.toStores);
            for iStore = 1:length(csStoresSubSystem)
                oLog.addValue(['Example:c:SubSystem.toStores.', csStoresSubSystem{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStoresSubSystem{iStore}, ' Pressure']);
                oLog.addValue(['Example:c:SubSystem.toStores.', csStoresSubSystem{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStoresSubSystem{iStore}, ' Temperature']);
            end
            
            csBranchesSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystem.toBranches);
            for iBranch = 1:length(csBranchesSubSystem)
                oLog.addValue(['Example:c:SubSystem.toBranches.', csBranchesSubSystem{iBranch}],             'fFlowRate',    'kg/s', [csBranchesSubSystem{iBranch}, ' Flowrate']);
            end
            
            
            
        end
        
        function plot(this, varargin) % Plotting the results
            
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
            
            
            csStoresSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystem.toStores);
            csPressuresSubSystem = cell(length(csStoresSubSystem),1);
            csTemperaturesSubSystem = cell(length(csStoresSubSystem),1);
            for iStore = 1:length(csStoresSubSystem)
                csPressuresSubSystem{iStore} = ['"', csStoresSubSystem{iStore}, ' Pressure"'];
                csTemperaturesSubSystem{iStore} = ['"', csStoresSubSystem{iStore}, ' Temperature"'];
            end
            
            csBranchesSubSystem = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.SubSystem.toBranches);
            csFlowRatesSubSystem = cell(length(csBranchesSubSystem),1);
            for iBranch = 1:length(csBranchesSubSystem)
                csFlowRatesSubSystem{iBranch} = ['"', csBranchesSubSystem{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot({csPressures{:}, csPressuresSubSystem{:}},     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({csFlowRates{:}, csFlowRatesSubSystem{:}},     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({csTemperatures{:}, csTemperaturesSubSystem{:}},  'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end