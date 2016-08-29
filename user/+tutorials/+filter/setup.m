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
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            
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
            
            
            
            this@simulation.infrastructure('Tutorial_Filter', ptConfigParams, tSolverParams);
            
            
            
            
            % Creating the root object
            oExample = tutorials.filter.systems.Example(this.oSimulationContainer, 'Example');
            
            
        end
        
        
        
        function configureMonitors(this)
            
            
            %% Logging
            
            oLog = this.toMonitors.oLogger;
            
            tiLog.ALL_EMP = oLog.add('Example', 'flow_props');
            tiLog.ALL_SUB = oLog.add('Example/Filter', 'flow_props');
            
            
            %% Define Plots
            
            
            oPlot = this.toMonitors.oPlotter;
            
            
            % 
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            %oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            
            
            oPlot.definePlotWithFilter(tiLog.ALL_EMP, 'kg', 'Tank Masses - System Example');
            oPlot.definePlotWithFilter(tiLog.ALL_SUB, 'kg', 'Tank Masses - System Filter');
            
            
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
            
            
            
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 900 * 1; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;

        end
        
        function plot(this) % Plotting the results
            
            this.toMonitors.oPlotter.plot();
            
            return;
            
        end
        
    end
    
end

