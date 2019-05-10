classdef timestepObserver < simulation.monitor
    %TIMESTEPOBSERVER Tracks the smallest time step in a simulation
    % It will identify the part of V-HAB that currently has the smallest
    % time step, if you provided a limit the monitor will display the
    % component and tick in which a timestep smaller than your limit
    % occured. If you used the standard use case without a limit you can
    % use the tool findSmallestTimeStep after finishing or pausing your
    % simulation to receive a report on what component in which tick had
    % the smallest time step for the last 100 ticks.
    %
    % to add this monitor to your simulation simply go to your setup file
    % and define ttMonitorConfig as follows (if you have other monitors
    % just leave out the fist line in order not to overwrite them!)
    %
    % ttMonitorConfig = struct();
    % ttMonitorConfig.oTimeStepObserver.sClass = 'simulation.monitors.timestepObserver';
    % ttMonitorConfig.oTimeStepObserver.cParams = { 0 };
    %
    % Instead of 0 you can provide the limit for the time step!
    
    
    properties (SetAccess = protected, GetAccess = public)
        iTickInterval = 100;
        fLimit = 0;
        tDebug = struct();
    end
    
    methods
        function this = timestepObserver(oSimulationInfrastructure, fLimit)
            this@simulation.monitor(oSimulationInfrastructure, { 'step_post' });
            
            if nargin >= 2
                this.fLimit = fLimit;
            else
                this.fLimit = 0;
            end
        end
    end
    
    
    methods (Access = protected)
        
        function onStepPost(this, ~)
            
            oTimer = this.oSimulationInfrastructure.oSimulationContainer.oTimer;
            
            % Minimal Time Step is the minimum value in afTimeSteps
            fMinStep = min(oTimer.afTimeSteps(oTimer.afTimeSteps >= 0));

            miIndexMinStep = find(oTimer.afTimeSteps == fMinStep);
            % The time steps in afTimeSteps belong to the respective callback within
            csReports = cell(length(miIndexMinStep),1);
            for iIndex = 1:length(miIndexMinStep)
                tInfo = functions(oTimer.cCallBacks{miIndexMinStep(iIndex)});
                oCaller = tInfo.workspace{1}.this;

                if isa(oCaller, 'matter.store')
                    [ ~, iPhase ] = min([ oCaller.aoPhases.fTimeStep ]);
                    csReports{iIndex} = ['In the system ', oCaller.oContainer.sName, ' in Store ''', oCaller.sName, ''', Phase ''', oCaller.aoPhases(iPhase).sName,''', a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(oTimer.iTick)];

                elseif isa(oCaller, 'thermal.capacity')
                    csReports{iIndex} = ['In the system ', oCaller.oPhase.oStore.oContainer.sName, ' in Store ', oCaller.oPhase.oStore.sName, ' in Capacity ', oCaller.sName, ' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(oTimer.iTick), ' for the function ', tInfo.function];
                    
                elseif isa(oCaller, 'vsys')
                    csReports{iIndex} = ['In the system ', oCaller.sName, ' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(oTimer.iTick)];

                elseif isa(oCaller, 'solver.thermal.lumpedparameter')
                    csReports{iIndex} = ['The lumped parameter thermal solver in the system ', oCaller.oVSys.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(oTimer.iTick)];
                
                elseif isa(oCaller, 'solver.matter.iterative.branch')
                    csReports{iIndex} = ['The iterative matter solver in the system ', oCaller.oBranch.oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(oTimer.iTick)];
                    
                elseif isa(oCaller, 'solver.matter.interval.branch')
                    csReports{iIndex} = ['The interval matter solver in the system ', oCaller.oBranch.oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(oTimer.iTick)];
                   
                elseif isa(oCaller, 'solver.matter.linear.branch')
                    csReports{iIndex} = ['The linear matter solver in the system ', oCaller.oBranch.oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(oTimer.iTick)];
                   
                elseif isa(oCaller, 'solver.matter_multibranch.iterative.branch')
                    csReports{iIndex} = ['The multibranch matter solver in the system ', oCaller.aoBranches(1).oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(oTimer.iTick)];
                
                elseif isa(oCaller, 'solver.matter.fdm_liquid.branch_liquid')
                    csReports{iIndex} = ['The compressible liquid matter solver in the system ', oCaller.oBranch.oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(oTimer.iTick)];
                
                elseif isa(oCaller, 'solver.matter.incompressible_liquid.branch_incompressible_liquid')
                    csReports{iIndex} = ['The compressible liquid matter solver in the system ', oCaller.oBranch.oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(oTimer.iTick)];
                
                elseif isa(oCaller, 'matter.phase')
                    csReports{iIndex} = ['In the system ', oCaller.oStore.oContainer.sName, ' in Store ''', oCaller.oStore.sName, ''', Phase ''', oCaller.sName,''', a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(oTimer.iTick)];

                elseif isa(oCaller, 'electrical.store')
                    csReports{iIndex} = ['In the circuit ', oCaller.oCircuit.sName, ' in electrical Store ', oCaller.sName, ' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(oTimer.iTick)];
                end
                    
                if isempty(csReports{iIndex})
                    warning('you came accros an unknown object that binds time steps, please check the oCaller object and add it to the list above with a report string to enable debugging')
                end
            end
    
            
            % if the limit is undercut the program will display the location of the
            % minimal timestep in the command window, only used if the user
            % specified a limit!
            if this.fLimit > 0 && fMinStep < this.fLimit
                for iReport = 1:length(csReports)
                    disp(csReports{iReport});
                end
            end
            
            % For further use the minimal time steps, report strings and
            % ticks in which they occured, are saved for the last 100
            % ticks.
            if mod(oTimer.iTick, 101) == 0
                this.tDebug = struct();
                this.tDebug(mod(oTimer.iTick, 101)+1).csReport    = csReports;
                this.tDebug(mod(oTimer.iTick, 101)+1).iTick       = oTimer.iTick;
                this.tDebug(mod(oTimer.iTick, 101)+1).fTimeStep   = fMinStep;
            else
                this.tDebug(mod(oTimer.iTick, 101)+1).csReport    = csReports;
                this.tDebug(mod(oTimer.iTick, 101)+1).iTick       = oTimer.iTick;
                this.tDebug(mod(oTimer.iTick, 101)+1).fTimeStep   = fMinStep;
            end
        end
    end
end