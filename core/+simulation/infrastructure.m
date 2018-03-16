classdef infrastructure < base & event.source
    %SIM V-HAB Simulation Class
    %   Objects instatiated from this class contain all necessary
    %   information to run a V-HAB simulation. They include the root vsys
    %   object, the timer and data objects and logged simulation data.
    %   It also contains the tick() method which advances the timer one
    %   time step (or tick) ahead until the total simulated time has
    %   reached the user-defined value.
    %
    %TODO The constructor of the derived class needs to or should set 
    %   csLog, and either iSimTicks of fSimTime.
    %
    
    
    properties (SetAccess = public, GetAccess = public)
        %TODO-RESTRUCTURING general storage dir, for .mat, info about code,
        %   system etc? Or just everything in objs, save() to .mat?
        %   How to implement regular dumping in logger, so mfLog does not
        %   get too big?
% %         sStorageName;
% %         sDescription;
    end
    
    properties (SetAccess = public, GetAccess = public)
        % Default number of ticks
        % @type int
        iSimTicks = 100;
        
        % Default simulation time [s]
        % @type int
        fSimTime  = 3600 * 1;
        
        % Use time or ticks to check if simulation finished? Default is
        % time in seconds.
        % @type int
        bUseTime = true;
        
        % Boolean variable to suppress the console output at the beginning
        % and end of each simulation. This is mainly for cases when V-HAB
        % is being called by TherMoS every simulated second and we want to
        % minimize clutter on the console.
        %TODO move to simulation.infrastructure.monitors.console_output
        bSuppressConsoleOutput = false;
        
        % Sometimes it may be helpful for the user to receive an acoustic
        % message when a simulation is complete. This can be enabled by
        % setting this flag to true.
        bPlayFinishSound = false;
    end
    
    
    
    properties (SetAccess = private, GetAccess = public)
        % Name of sim
        % @type string
        sName;
        
        
        % Sim Contaienr (root sys)
        % @type object
        oSimulationContainer;
        
        
        
        fRuntimeTick  = 0;
        fRuntimeOther = 0;
        
        % Matlab date number -> object/sim created
        fCreated = 0;
        
        % @type string
        sCreated = '';
        
        
        % Was everything initialized, e.g. create*Structure, event
        % init_post was sent etc?
        bInitialized = false;
        
        
        %TODO-RESTRUCTURING see sStorageName
% %         % String for disk storage
% %         sStorageDir;
        
        %TODO-RESTRUCTURING move to monitor
% %         % Variables holding the sum of lost mass / total mass, species-wise
% %         %TODO move to monitors.matter_observer
% %         mfTotalMass = [];
% %         mfLostMass  = [];
        
        %TODO-RESTRUCTURING CPU, RAM etc
        
    end
    
    properties (GetAccess = public, Dependent = true)
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
            %CHANGELOG
            % fMinStep --> use oTimer.setMinStep()
            % tData --> simulation.container
            
            
            this.sName = sName;
            
            
            if nargin < 2 || isempty(ptConfigParams), ptConfigParams = containers.Map(); end;
            if nargin < 3 || isempty(tSolverParams),  tSolverParams  = struct(); end;
            if nargin < 4 || isempty(tMonitors),      tMonitors      = struct(); end;

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
            
            
            
            %%% Create monitors
            csMonitors = fieldnames(this.ttMonitorCfg);
            
            for iM = 1:length(csMonitors)
                cParams = {};
                monitorConstructor = str2func(this.ttMonitorCfg.(csMonitors{iM}).sClass);
                
                if isfield(this.ttMonitorCfg.(csMonitors{iM}), 'cParams')
                    cParams = this.ttMonitorCfg.(csMonitors{iM}).cParams;
                end
                
                this.toMonitors.(csMonitors{iM}) = monitorConstructor(this, cParams{:});
            end
            
            
            

            %%% Global objects and settings for constructors

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
            
            %TODO-RESTRUCTURING see above - exporter monitor?
% %             %this.sStorageDir = [ datestr(this.fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') '_' this.sUUID ];
% %             this.sStorageDir = [ datestr(this.fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') '_' this.sName ];
            

            
            %TODO-RESTRUCTURING move to monitor
            
            % Init the mass log matrices - don't log yet, system's not
            % initialized yet! Just create with one row, for the initial
            % mass log. Subsequent logs dynamically allocate new memory -
            % bad for performance, but only happens every Xth tick ...
            
% %             this.mfTotalMass = zeros(0, this.oData.oMT.iSubstances);
% %             this.mfLostMass  = zeros(0, this.oData.oMT.iSubstances);
        
            
            
            % Bind the playFinishSound() method to the 'finished' event.
            this.bind('finish', @(~) this.playFinishSound());
        
        
            % Pre Init
            this.trigger('init_pre');
            % Now the child class constructor will run. After that is
            % finished, the initialize() method (that also sends init_post)
            % will have to be called explicitly (e.g. from vhab.sim) or in
            % .run() below (if first tick).
            %TODO make sure that sims are always created through vhab.sim()
            %     because if .init is not called directly, we might get
            %     issues with e.g. the debugger/logger not being able to
            %     sort out which object belong to which simulation obj?
        end
        
        
        function configureMonitors(this)
            % Do stuff like: add log propertis, define plots, ...
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
            
            iPhases = 0;
            iBranches = 0;
            
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
                    oChild.seal();
                    
                    iPhases = iPhases + oChild.iPhases;
                    iBranches = iBranches + oChild.iBranches;
                end

                
                if ismethod(oChild,'createThermalStructure')
                    oChild.createThermalStructure();
                end
                
                
                if ismethod(oChild,'createElectricalStructure')
                    oChild.createElectricalStructure();
                end
                
                oChild.createSolverStructure();
                
                %TODO Might have to add something like this here
                %if ismethod(oChild,'createDomainInterfaces')
                %   oChild.createDomainInterfaces();
                %end
            end
            
            disp(['Model Assembly Completed in ', num2str(toc(hTimer)), ' seconds!']);
            disp(['Model contains ', num2str(iBranches), ' Branches and ', num2str(iPhases), ' Phases.'])
            
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
                disp('--------------------------------------');
                disp('Starting simulation run...');
            end
            
            this.trigger('run');
            
            while true
                % Simulation finished?
                if this.bUseTime && (this.oSimulationContainer.oTimer.fTime >= this.fSimTime),       break;
                elseif ~this.bUseTime && (this.oSimulationContainer.oTimer.iTick >= this.iSimTicks), break;
                end
                
                this.tick();
                
                % Stopped?
                %TODO-RESTRUCTURING dumping to own logger/dumper monitor!
                %  STOP file check to own monitor? see STOP in vhab.m!
% %                 if this.bDumpToMat && (this.oTimer.iTick > 0) && (mod(this.oTimer.iTick, this.iPrealloc) == 0)
% %                     sFile = [ 'data/runs/' this.sStorageDir '/STOP' ];
% %                     
% %                     % Always do that!
% %                     disp('#############################################');
% %                     disp('Writing sim obj to .mat!');
% %                     this.finish();
% %                     
% %                     disp([ 'Checking for STOP file: ' sFile ]);
% %                     
% %                     if exist(sFile, 'file') == 2
% %                         disp('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
% %                         disp('STOPPED by STOP file. Har. Restart with "oLastSimObj.run()"');
% %                         
% %                         break;
% %                     end
% %                 end
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
            %TODO-RESTRUCTURING to own monitor, see above
            % Pre-check -> timer tick at -1 --> initial call. So do the
            % mass log, need the initial values.
% %             if this.oSimulationContainer.oSimulationContainer.oTimer.iTick == -1
% %                 this.masslog();
% %             end
            
            
            
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
            
            
            
            % Mass log?
            %TODO-RESTRUCTURING move to matter_observer
            %TODO do by time, not tick? Every 1s, 10s, 100s ...?
            %     see old main script, need a var like fNextLogTime, just
            %     compare this.oData.oTimer.fTIme >= this.fNexLogTime.
% %             if mod(this.oData.oTimer.iTick, this.iMassLogInterval) == 0
% %                 this.masslog();
% %             end
            
            % Sim finished?
            if (this.bUseTime && (this.oSimulationContainer.oTimer.fTime >= this.fSimTime)) || (~this.bUseTime && (this.oSimulationContainer.oTimer.iTick >= this.iSimTicks))
                %this.finish();
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
            
        
        %TODO-RESTRUCTURING see console_ouput
        function finish(this)
            
            %TODO-RESTRUCTURING move to monitors.exporter, monitors.logger or so?
% %             if this.bDumpToMat
% %                 if ~isdir([ 'data/runs/' this.sStorageDir ])
% %                     mkdir([ 'data/runs/' this.sStorageDir ]);
% %                 end
% %                 
% %                 sMat = [ 'data/runs/' this.sStorageDir '/_simObj.mat' ];
% %                 disp(['DUMPING - write to .mat: ' sMat]);
% %    
% %                 oLastSimObj = this;
% %                 save(sMat, 'oLastSimObj');
% %             end
        end
        
        
        
        %TODO-RESTRUCTURING move to own monitor
% %         function masslog(this)
% %             iIdx = size(this.mfTotalMass, 1) + 1;
% %             
% %             % Total mass: sum over all mass stored in all phases, for each
% %             % species separately.
% %             this.mfTotalMass(iIdx, :) = sum(reshape([ this.oData.oMT.aoPhases.afMass ], this.oData.oMT.iSubstances, []), 2)';
% %             
% %             % Lost mass: logged by phases if more mass is extracted then
% %             % available (for each substance separately).
% %             this.mfLostMass(iIdx, :) = sum(reshape([ this.oData.oMT.aoPhases.afMassLost ], this.oData.oMT.iSubstances, []), 2)';
% %             
% %             %TODO implement methods for that ... break down everything down
% %             %     to the moles and compare these?! So really count every
% %             %     atom, not the molecules ... compare enthalpy etc?
% %         end
        
        
        %TODO-RESTRUCTURING to .exporter / .importer or so, depends on
        %  settings if e.g. .mat files were written every Xth tick etc!
% %         function readData(this)
% %             if this.bDumpToMat
% %                 sDir    = [ 'data/runs/' this.sStorageDir '/' ];
% %                 tDir    = dir(sDir);
% %                 aiDumps = [];
% %                 
% %                 for iD = 1:length(tDir)
% %                     if (length(tDir(iD).name) > 5) && strcmp(tDir(iD).name(1:5), 'dump_')
% %                         %disp([ sDir tDir(iD).name ]);
% %                         aiDumps(end + 1) = str2double(tDir(iD).name(6:(end - 4)));
% %                     end
% %                 end
% %                 
% %                 aiDumps = sort(aiDumps);
% %                 
% %                 for iF = length(aiDumps):-1:1
% %                     tFile = load([ sDir 'dump_' num2str(aiDumps(iF)) '.mat' ]);
% %                     
% %                     this.mfLog = [ tFile.mfLog; this.mfLog ];
% %                 end
% %             end
% %         end
% % 
        function saveSim(this, sAppendix)
            %TODO move to own monitor, e.g. 'exporter'? Allow setting a
            %     custom name?
            %     If logger did dump data to .mat file, do not need to read
            %     that data before saving, can be done after user re-loaded
            %     the sim .mat in the workspace.
            
            %TODO rename to sAppendix
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

	