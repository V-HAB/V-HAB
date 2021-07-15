classdef timestepObserver < simulation.monitor
    %TIMESTEPOBSERVER Tracks the smallest time step in a simulation
    % It will identify the part of V-HAB that currently has the smallest
    % time step. If you provide a reporting limit the monitor will display
    % the component and tick in which a timestep smaller than your limit
    % occured during runtime in the command window. If you use the standard
    % use case without a limit, you can use the findSmallestTimeStep()
    % dunction after finishing or pausing your simulation to receive a
    % report on what component in which tick had the smallest time step in
    % the last X ticks. The number of ticks can be set in the iTicks
    % property of this class.
    %
    % To add this monitor to your simulation simply go to your setup file
    % and define ttMonitorConfig as follows (if you have other monitors
    % just leave out the fist line in order not to overwrite them!)
    %
    % ttMonitorConfig = struct();
    % ttMonitorConfig.oTimeStepObserver.sClass = 'simulation.monitors.timestepObserver';
    % 
    % You can also provide two optional parameters that will change the
    % defaults for the reporting limit and the number of ticks in the
    % observation history. The following line just sets the defaults.
    % ttMonitorConfig.oTimeStepObserver.cParams = { 0 , 100 };
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Number of ticks in the observation history. This determines the
        % length of tDebug.
        iTicks;
        
        % A struct array of length this.iTicks containing the information
        % on all objects that set the minimum time step during an
        % individual tick.
        tDebug = struct();
        
        % If a time step is smaller than this limit during a tick, this
        % monitor will display the time step and the associated object in
        % the command window during runtime. 
        fReportingLimit;
        
        % Reference to the timer object of the simulation this monitor is
        % observing. 
        oTimer;
        
        % Since we can't set the timer object reference during
        % construction, we need to do it during the first call to
        % onStepPost(). In order to avoid isempty() or similar queries, we
        % set this boolean to true once the reference has been set. 
        bTimerSet = false;
        
        % Initially, the tDebug array will be empty. We then fill it up
        % with information until it reaches a length of this.iTicks. Then,
        % instead of appending the array at the end, we delete the oldest
        % entry and add a new one. This switch in behavior will be
        % determined by the state of this boolean property. 
        bLogNotFull = true;
    end
    
    methods
        function this = timestepObserver(oSimulationInfrastructure, fReportingLimit, iTicks)
            this@simulation.monitor(oSimulationInfrastructure, { 'step_post' });
            
            if nargin >= 2
                this.fReportingLimit = fReportingLimit;
            else
                this.fReportingLimit = 0;
            end
            
            if nargin >= 3
                this.iTicks = iTicks;
            else
                this.iTicks = 100;
            end
            
        end
    end
    
    
    methods (Access = protected)
        
        function onStepPost(this, ~)
            
            if this.bTimerSet == false
                this.oTimer = this.oSimulationInfrastructure.oSimulationContainer.oTimer;
                this.bTimerSet = true;
            end
            
            % Minimal Time Step is the minimum value in afTimeSteps
            fMinStep = min(this.oTimer.afTimeSteps(this.oTimer.afTimeSteps >= 0));
            
            % Getting the indexes of the objects that set the minimum time
            % step. There can be more than one!
            miIndexMinStep = find(this.oTimer.afTimeSteps == fMinStep);
            
            % The time steps in afTimeSteps belong to the respective callback within
            csReports = cell(length(miIndexMinStep),1);
            for iIndex = 1:length(miIndexMinStep)
                tInfo = functions(this.oTimer.cCallBacks{miIndexMinStep(iIndex)});
                oCaller = tInfo.workspace{1}.this;

                if isa(oCaller, 'matter.store')
                    [ ~, iPhase ] = min([ oCaller.aoPhases.fTimeStep ]);
                    csReports{iIndex} = ['In the system ', oCaller.oContainer.sName, ' in Store ''', oCaller.sName, ''', Phase ''', oCaller.aoPhases(iPhase).sName,''', a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(this.oTimer.iTick)];

                elseif isa(oCaller, 'thermal.capacity')
                    csReports{iIndex} = ['In the system ', oCaller.oPhase.oStore.oContainer.sName, ' in Store ', oCaller.oPhase.oStore.sName, ' in Capacity ', oCaller.sName, ' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(this.oTimer.iTick), ' for the function ', tInfo.function];
                    
                elseif isa(oCaller, 'vsys')
                    csReports{iIndex} = ['In the system ', oCaller.sName, ' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(this.oTimer.iTick)];

                elseif isa(oCaller, 'solver.thermal.lumpedparameter')
                    csReports{iIndex} = ['The lumped parameter thermal solver in the system ', oCaller.oVSys.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(this.oTimer.iTick)];
                
                elseif isa(oCaller, 'solver.matter.iterative.branch')
                    csReports{iIndex} = ['The iterative matter solver in the system ', oCaller.oBranch.oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(this.oTimer.iTick)];
                    
                elseif isa(oCaller, 'solver.matter.interval.branch')
                    csReports{iIndex} = ['The interval matter solver in the system ', oCaller.oBranch.oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(this.oTimer.iTick)];
                   
                elseif isa(oCaller, 'solver.matter.linear.branch')
                    csReports{iIndex} = ['The linear matter solver in the system ', oCaller.oBranch.oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(this.oTimer.iTick)];
                   
                elseif isa(oCaller, 'solver.matter_multibranch.iterative.branch')
                    csReports{iIndex} = ['The multibranch matter solver in the system ', oCaller.aoBranches(1).oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(this.oTimer.iTick)];
                
                elseif isa(oCaller, 'solver.matter.fdm_liquid.branch_liquid')
                    csReports{iIndex} = ['The compressible liquid matter solver in the system ', oCaller.oBranch.oContainer.sName, ' used a minimal time step of ', num2str(fMinStep), ' seconds in Simulation Tick ', num2str(this.oTimer.iTick)];
                
                elseif isa(oCaller, 'matter.phase')
                    csReports{iIndex} = ['In the system ', oCaller.oStore.oContainer.sName, ' in Store ''', oCaller.oStore.sName, ''', Phase ''', oCaller.sName,''', a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(this.oTimer.iTick)];

                elseif isa(oCaller, 'electrical.store')
                    csReports{iIndex} = ['In the circuit ', oCaller.oCircuit.sName, ' in electrical Store ', oCaller.sName, ' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(this.oTimer.iTick)];
                
                elseif isa(oCaller, 'matter.manips.volume.flow')
                    csReports{iIndex} = ['In the system ', oCaller.oPhase.oStore.oContainer.sName, ' in Store ''', oCaller.oPhase.oStore.sName, ''', Phase ''', oCaller.oPhase.sName,''', in the flow volume manipulator ''', oCaller.sName, ''' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(this.oTimer.iTick)];
                
                elseif isa(oCaller, 'matter.procs.p2p')
                    csReports{iIndex} = ['In the system ', oCaller.oStore.oContainer.sName, ' in Store ''', oCaller.oStore.sName, ''' in the p2p ''', oCaller.sName, ''' a minimal time step of ' num2str(fMinStep), ' seconds was used in Simulation Tick ', num2str(this.oTimer.iTick)];
                end
                
                if isempty(csReports{iIndex})
                    if isfield(oCaller, 'sName')
                        csReports{iIndex} = ['The entity ', oCaller.sEntity, ' with the name ', oCaller.sName, ' had a minimal time step of ' num2str(fMinStep), ' seconds in Simulation Tick ', num2str(this.oTimer.iTick)];
                    else
                        csReports{iIndex} = ['The entity ', oCaller.sEntity, ' had a minimal time step of ' num2str(fMinStep), ' seconds in Simulation Tick ', num2str(this.oTimer.iTick)];
                    end
                end
            end
    
            
            % If the limit is undercut the program will display the location of the
            % minimal timestep in the command window, only used if the user
            % specified a limit!
            if this.fReportingLimit > 0 && fMinStep < this.fReportingLimit
                for iReport = 1:length(csReports)
                    disp(csReports{iReport});
                end
            end
            
            % For further use the minimal time steps, report strings and
            % ticks in which they occured, are saved for the number of
            % ticks defined by this.iTicks. 
            if this.bLogNotFull
                % We are still filling up the tDebug array, so we just get
                % the current log index and append the array.
                iLogIndex = mod(this.oTimer.iTick, this.iTicks+1) + 1;
            
                this.tDebug(iLogIndex).csReport  = csReports;
                this.tDebug(iLogIndex).iTick     = this.oTimer.iTick;
                this.tDebug(iLogIndex).fTimeStep = fMinStep;
                
                % Checking if we have reached the maximum length of the
                % tDebug array. If so, we set the boolean indicating the
                % array is full to true.
                if iLogIndex == this.iTicks
                    this.bLogNotFull = false;
                end
            else
                % The array is at a constant length now. So we overwrite
                % the oldest entry, which is always at position 1, and then
                % do a circshift, which pushes this newest entry to the end
                % of the array. Doing it this way is a lot faster than
                % getting sub-arrays (e.g. (2:end)) or using 'end'. 
                this.tDebug(1).csReport  = csReports;
                this.tDebug(1).iTick     = this.oTimer.iTick;
                this.tDebug(1).fTimeStep = fMinStep;
                this.tDebug = circshift(this.tDebug, -1);
            end
        end
    end
end