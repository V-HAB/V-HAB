classdef infrastructure < base & event.source
    %SIM V-HAB Simulation Class
    %   Objects instatiated from this class contain all necessary
    %   information to run a V-HAB simulation. They include the root vsys
    %   object, the timer and data objects and logged simulation data.
    %   It also contains the tick() method which advances the timer one
    %   time step (or tick) ahead until the total simulated time has
    %   reached the user-defined value.
    
    properties (SetAccess = public, GetAccess = public)
        % Default number of ticks
        iSimTicks = 100;
        
        % Default simulation time [s]
        fSimTime  = 3600 * 1;
        
        % Use time or ticks to check if simulation finished? Default is
        % time in seconds.
        bUseTime = true;
        
        % Boolean variable to suppress the console output at the beginning
        % and end of each simulation. This is mainly for cases when V-HAB
        % is being called by TherMoS every simulated second and we want to
        % minimize clutter on the console.
        bSuppressConsoleOutput = false;
        
        % Sometimes it may be helpful for the user to receive an acoustic
        % message when a simulation is complete. This can be enabled by
        % setting this flag to true.
        bPlayFinishSound = false;
    end
    
    
    
    properties (SetAccess = private, GetAccess = public)
        % Name of sim
        sName;
        
        % Sim Contaienr (root sys)
        oSimulationContainer;
        
        fRuntimeTick  = 0;
        fRuntimeOther = 0;
        
        % Matlab date number -> object/sim created
        fCreated = 0;
        
        % string containing the time and date at which this simulation was
        % created (or startet) 
        sCreated = '';
        
        % Was everything initialized, e.g. create*Structure, event
        % init_post was sent etc?
        bInitialized = false;
    end
    
    properties (GetAccess = public, Dependent = true)
        % This factor represents the simulated time / elapsed time. It
        % therefore represents how much faster than real time the
        % simulation is (if the factor is larger than 1) or how much slower
        % it is (smaller than 1)
        fSimFactor;
    end

    properties (SetAccess = private, GetAccess = public)
        % Default monitors
        ttMonitorCfg = struct(...
            ... % Logs the simulation process in the console - params are major, minor tick
            'oConsoleOutput', struct('sClass', 'simulation.monitors.console_output', 'cParams', {{ 100, 10 }}), ...
            ... % Logs specific simulation values, can be specified throug helpers
            ... % First param is bDumpToMat --> active?
            'oLogger', struct('sClass', 'simulation.monitors.logger_basic', 'cParams', {{ false }}), ...
            ... % Allows to e.g. pause the simulation
            'oExecutionControl', struct('sClass', 'simulation.monitors.execution_control'), ...
            ... % Logs mass loss/gain, TODO warn if too much mass loss / gain
            'oMatterObserver', struct('sClass', 'simulation.monitors.matter_observer'), ...
            ... observes time step, and can tell the user what part of the system uses a small timestep
            'oTimeStepObserver', struct('sClass', 'simulation.monitors.timestep_observer') ...
        );
        
        % Monitor objs
        toMonitors = struct();
    end
    
    methods
        function this = infrastructure(sName, ptConfigParams, tSolverParams, tMonitors)
            this.sName = sName;
            
            
            if nargin < 2 || isempty(ptConfigParams), ptConfigParams = containers.Map(); end
            if nargin < 3 || isempty(tSolverParams),  tSolverParams  = struct(); end
            if nargin < 4 || isempty(tMonitors),      tMonitors      = struct(); end

            % Monitors -> merge
            csMonitors = fieldnames(tMonitors);

            for iM = 1:length(csMonitors)
                % Just add the monitor if it doesn't exist.
                if ~isfield(this.ttMonitorCfg, csMonitors{iM})
                    % Just a strig? Create struct
                    if ischar(tMonitors.(csMonitors{iM}))
                        this.ttMonitorCfg.(csMonitors{iM}) = struct('sClass', tMonitors.(csMonitors{iM}));
                    else
                        this.ttMonitorCfg.(csMonitors{iM}) = tMonitors.(csMonitors{iM});
                    end

                % Overwrite/Merge, provided value is a struct that would contain the sClass and / or cParams values
                elseif isstruct(tMonitors.(csMonitors{iM}))
                    
                    %this.ttMonitorCfg.(csMonitors{iM}) = tMonitors.(csMonitors{iM});
                    this.ttMonitorCfg.(csMonitors{iM}) = tools.struct.mergeStructs(...
                        this.ttMonitorCfg.(csMonitors{iM}), ...
                        tMonitors.(csMonitors{iM}) ...
                    );
                    

                % If value is a string, overwrite or insert the monitor and set value as sClass
                elseif ischar(tMonitors.(csMonitors{iM}))
                    if ~isfield(this.ttMonitorCfg, csMonitors{iM})
                        this.ttMonitorCfg.(csMonitors{iM}) = struct('sClass', tMonitors.(csMonitors{iM}));
                    else
                        this.ttMonitorCfg.(csMonitors{iM}).sClass = tMonitors.(csMonitors{iM});
                    end
                end
            end
            
            
            
            %% Create monitors
            csMonitors = fieldnames(this.ttMonitorCfg);
            
            for iM = 1:length(csMonitors)
                cParams = {};
                monitorConstructor = str2func(this.ttMonitorCfg.(csMonitors{iM}).sClass);
                
                if isfield(this.ttMonitorCfg.(csMonitors{iM}), 'cParams')
                    cParams = this.ttMonitorCfg.(csMonitors{iM}).cParams;
                end
                
                this.toMonitors.(csMonitors{iM}) = monitorConstructor(this, cParams{:});
            end
            
            
            %% Global objects and settings for constructors

            oTimer = event.timer();

            hTimer = tic();
            
            % If we are running this simulation in parallel with other
            % simulations, a key in the ptConfigParams container map must
            % be 'ParallelExecution'. If this key is present, the matter
            % table object will have been instantiated outside of the
            % parallel loop and ist contained in the container map as the
            % value for the key 'ParallelExecution'. So we just assign it
            % here. 
            % If this simulation is being run individually, we can call the
            % matter table constructor directly.
            if isKey(ptConfigParams, 'ParallelExecution')
                oMT = ptConfigParams('ParallelExecution');
                if ~isa(oMT, 'matter.table')
                    this.throw('infrastructure','The provided object is not a matter table.');
                end
            else
                oMT = matter.table();
            end
            
            disp(['Matter Table created in ', num2str(toc(hTimer)), ' seconds.'])
            
            oCfgParams = simulation.configuration_parameters(ptConfigParams);
            
            % Create the root object for the simulation, referencing the
            % global objects. Also the hierarchy root for the systems.
            this.oSimulationContainer = simulation.container(this.sName, oTimer, oMT, oCfgParams, tSolverParams);

            % Remember the time of object creation
            this.fCreated = now();
            this.sCreated = datestr(this.fCreated);
            
            % Bind the playFinishSound() method to the 'finished' event.
            this.bind('finish', @(~) this.playFinishSound());
        
            % Pre Init
            this.trigger('init_pre');
            % Now the child class constructor will run. After that is
            % finished, the initialize() method (that also sends init_post)
            % will have to be called explicitly (e.g. from vhab.sim) or in
            % .run() below (if first tick).
        end
        
        
        function oPlotter = plot(this, sLogger)
            if nargin >= 2
                oPlotter = tools.postprocessing.plotter.plotter_basic(this, sLogger);
            else
                oPlotter = tools.postprocessing.plotter.plotter_basic(this);
            end
        end

        
        
        function initialize(this)
            if this.bInitialized
                return;
            end
            
            % Construct matter, solvers, ...
            oRoot = this.oSimulationContainer;
        
            disp('Assembling Simulation Model...')
            hTimer = tic();
            
            for iC = 1:length(oRoot.csChildren)
                sChild = oRoot.csChildren{iC};
                oChild = oRoot.toChildren.(sChild);
                
                if ismethod(oChild,'createMatterStructure')
                    oChild.createMatterStructure();
                    
                    % Seal matter things - do we need something like that
                    % for thermal/electrical?
                    oChild.sealMatterStructure();
                end

                
                if ismethod(oChild,'createThermalStructure')
                    oChild.createThermalStructure();
                    
                    oChild.sealThermalStructure();
                end
                
                
                if ismethod(oChild,'createElectricalStructure')
                    oChild.createElectricalStructure();
                    
                    oChild.sealElectricalStructure();
                end
                
                oChild.createSolverStructure();
                
                % Making sure that all of our branches have a solver
                % assigned to them. 
                oChild.checkMatterSolvers();
                oChild.checkThermalSolvers();
            end
            
            disp(['Model Assembly Completed in ', num2str(toc(hTimer)), ' seconds!']);
            
            this.bInitialized = true;

            % Setup monitors
            this.configureMonitors();
            
            % Trigger event so e.g. monitors can react
            this.trigger('init_post');
        end
        
        
        function run(this)
            % Run until tick/time (depending on bUseTime)
            % iSimTicks/fSimTime reached - directly set attributes to
            % influence behaviour
            
            
            if this.oSimulationContainer.oTimer.iTick == -1 && ~this.bInitialized
                this.initialize();
            end
            
            % Only output this, if we want to and the first time this is
            % run.
            if ~this.bSuppressConsoleOutput || this.oSimulationContainer.oTimer.iTick == -1
                disp('Initialization complete!');
                fprintf('+-----------------------------------------------------------------------------------+\n');
                disp('Starting simulation run...');
            end
            
            this.trigger('run');
            
            while true
                % Simulation finished?
                if this.bUseTime && (this.oSimulationContainer.oTimer.fTime >= this.fSimTime),       break;
                elseif ~this.bUseTime && (this.oSimulationContainer.oTimer.iTick >= this.iSimTicks), break;
                end
                
                this.tick();
                
            end
            
        end
        
        
        function pause(this, varargin)
            this.iSimTicks = this.oSimulationContainer.oTimer.iTick;
            this.bUseTime  = false;
            disp('##################### PAUSE ###################');
            
            this.trigger('pause');
        end
        
        
        function advanceTo(this, fTime)
            % Run to specific time and set to fSimTime
            
            this.fSimTime = fTime;
            this.bUseTime = true;
            
            this.run();
        end
        
        function advanceFor(this, fSeconds)
            % Run for specific duraction and set to fSimTime
            
            this.fSimTime = this.oSimulationContainer.oTimer.fTime + fSeconds;
            this.bUseTime = true;
            
            this.run();
        end
        
        
        
        function tickTo(this, iTick)
            % Run until specific tick and set to iSimTicks
            
            this.iSimTicks = iTick;
            this.bUseTime  = false;
            
            this.run();
        end
        
        function tickFor(this, iTicks)
            % Run provided amount of ticks and set to iSimTicks
            
            this.iSimTicks = this.oSimulationContainer.oTimer.iTick + iTicks;
            this.bUseTime  = false;
            
            this.run();
        end
        
        
        
        function tick(this)
            % Pre Tick (e.g. monitors) incl. time tracking
            hTimer = tic();
            this.trigger('tick_pre');
            this.fRuntimeOther = this.fRuntimeOther + toc(hTimer);
            
            
            % Tick and measure time
            hTimer = tic();
            this.oSimulationContainer.oTimer.step();
            this.fRuntimeTick = this.fRuntimeTick + toc(hTimer);
            
            
            % Post tick (monitors e.g. logger) and measure time
            %TODO-RESTRUCTURING move to base_logger, or generally tic/toc
            %  e.g. the tick_pre, tick_post trigger calls?
            hTimer = tic();
            this.trigger('tick_post');
            this.fRuntimeOther = this.fRuntimeOther + toc(hTimer);
            
            % Sim finished?
            if (this.bUseTime && (this.oSimulationContainer.oTimer.fTime >= this.fSimTime)) || (~this.bUseTime && (this.oSimulationContainer.oTimer.iTick >= this.iSimTicks))
                % Only trigger 'finish' if we actually want the console
                % output. 
                if ~this.bSuppressConsoleOutput
                    this.trigger('finish');
                end
            end
        end
        
        
        function triggerFinish(this)
            % This is just here so we can trigger the final simulation
            % console output from TherMoS.
            this.trigger('finish');
        end
            
        function saveSim(this, sAppendix)
            if nargin < 2 || isempty(sAppendix)
                sAppendix = '';
            else
                sAppendix = [ '_' sAppendix ];
            end
            
            sTick = [ '_tick' num2str(this.oSimulationContainer.oTimer.iTick) ];
            sPath = [  this.sName '_' datestr(this.fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') sTick sAppendix ];
            
            
            oSimObj = this;
            
            save([ 'data/' sPath '.mat' ], 'oSimObj');

        end
        
        function playFinishSound(this)
            if this.bPlayFinishSound
                % Loading the data for the finishing sound
                [afSampleData, afSampleRate] = audioread('lib/+special/V-HAB Finish Sound.mp3');
                % Playing the finishing sound
                sound(afSampleData, afSampleRate);
            end
        end
        
        
        function delete(this)
            csMonitors = fieldnames(this.toMonitors);
            
            for iM = 1:length(csMonitors)
                delete(this.toMonitors.(csMonitors{iM}));
            end
        end
    end
    
    
    %% Getters / Setters
    methods
        function fSimFactor = get.fSimFactor(this)
            if isempty(this.oSimulationContainer.oTimer) || (this.oSimulationContainer.oTimer.fTime == -10)
                fSimFactor = nan;
            else
                fSimFactor = this.oSimulationContainer.oTimer.fTime / (this.fRuntimeTick + this.fRuntimeOther);
            end
        end
    end
end

	