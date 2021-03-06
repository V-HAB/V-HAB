classdef infrastructure < base & event.source
    %INFRASTRUCTURE V-HAB Simulation Base Class
    %   Objects instatiated from this class contain all necessary
    %   information to run a V-HAB simulation. They include the root vsys
    %   object, the timer and data objects and logged simulation data.
    %   It also contains the step() method which advances the timer one
    %   time step (or tick) ahead until the total simulated time has
    %   reached the user-defined value.
    %   Put differently, objects instantiated from this class are the
    %   infrastructure (hence the class name) around the actual simulation
    %   model that makes running the simulation possible and provides tools
    %   to observe and record what is happening in the models. 
    %
    %   This class also provides a few methods that can be used after a
    %   simulation has finished or after it has paused to re-start the
    %   simulation or to move it forward in simulated time for specific
    %   intervals. These are: advanceFor(), advanceTo(), tickFor(),
    %   tickTo() and tick(). For more explanation on these methods, please
    %   refer to their descriptions in the code below. 
    
    properties (SetAccess = protected, GetAccess = public)
        % Default number of ticks
        iSimTicks = 100;
        
        % Default simulation time [s]
        fSimTime  = 3600;
        
        % Use time or ticks to check if simulation finished? Default is
        % time in seconds.
        bUseTime = true;
        
        % Boolean variable to suppress the console output at the beginning
        % and end of each simulation. This was mainly implemented for cases
        % when V-HAB is being called by TherMoS every simulated second and
        % we want to minimize clutter on the console. 
        bSuppressConsoleOutput = false;
        
        % Sometimes it may be helpful for the user to receive an acoustic
        % message when a simulation is complete. This can be enabled by
        % setting this flag to true.
        bPlayFinishSound = false;
        
        % Boolean variable to indicate if this simulation is being executed
        % using the parallel pool. This is here so the simulation
        % infrastructure itself, but also other parts of the simulation can
        % do things differently to account for running on a parallel worker
        % instead of a full MATLAB instance. 
        bParallelExecution = false;
        
        % If this simulation is being executed using the parallel pool, we
        % need to know its index within the array of simulations. This is
        % stored in this property. 
        iParallelSimulationID;
        
        % If this simulation is being executed using the parallel pool, we
        % need to update the main MATLAB instance with information about
        % the status of this individual simulation. By default we send and
        % update via a data queue after every simulation step. However, if
        % we are running many fast and simple simulations, the number of
        % sends is too large and blocks the entire system. So we use this
        % property to reduce the number of calls to send();
        iParallelSendInterval = 1;
    end
    
    properties (Transient, SetAccess = protected, GetAccess = public)
        % In order to communicate with the MATLAB client when this
        % simulation is run using the parallel pool, we need a parallel
        % data queue object to send updates to. This property is a handle
        % to that data queue. 
        oDataQueue;
    end
    
    % The following properties have private SetAccess due to the
    % fundamental nature of this class.
    properties (SetAccess = private, GetAccess = public)
        % Name of the simulation
        sName;
        
        % Simulation Contaienr (root sys), the actual simulation model
        oSimulationContainer;
        
        % Simulation runtime for the actual model
        fRuntimeTick  = 0;
        
        % Simulation runtime for everything but the actual model (e.g.
        % logging 
        fRuntimeOther = 0;
        
        % MATLAB date number recording when this particular simulation was
        % created
        fCreated = 0;
        
        % A string containing the time and date at which this simulation
        % was created (or started)
        sCreated = '';
        
        % A boolean variable recording if everything was correctly
        % initialized, e.g. create*Structure, event init_post was sent
        % etc.?
        bInitialized = false;
    
        % Defining the default monitors. These can be overwritten in each
        % simulation's setup.m file. See the individual monitor's class
        % files for more information. 
        ttMonitorCfg = struct(...
            ... % Logs the simulation process in the console - params are major, minor tick
            'oConsoleOutput', struct('sClass', 'simulation.monitors.consoleOutput', 'cParams', {{ 100, 10 }}), ...
            ... % Logs specific simulation values, can be specified throug helpers
            ... % First param is bDumpToMat --> active?
            'oLogger', struct('sClass', 'simulation.monitors.logger', 'cParams', {{ false }}), ...
            ... % Allows to e.g. pause the simulation
            'oExecutionControl', struct('sClass', 'simulation.monitors.executionControl'), ...
            ... % Logs mass loss/gain, TODO warn if too much mass loss / gain
            'oMatterObserver', struct('sClass', 'simulation.monitors.matterObserver'), ...
            ... % Currently only displays the number of branches and capacities after init
            'oThermalObserver', struct('sClass', 'simulation.monitors.thermalObserver')...
        );
        
        % A struct that contains the different monitor objects.
        toMonitors = struct();
        
        % A boolean indicating if the branches (all domains) have been
        % disconnected on the right side in order to save the simulation
        % object as a .mat file without exceeding the recursion limit. This
        % property is set to true when the object is saved and to false
        % when loaded. See the saveobj() and loadobj() method of this
        % class. The property is also queried during the calls to
        % advanceFor(), advanceTo(), tickFor() and tickTo() methods. 
        bBranchesDisconnected  = false;
        
        % A boolean to decide if a zip with the name "SimulationOutput.zip"
        % shall be created in the V-HAB base directory everytime new data
        % is dumped. This is usefull when V-HAB is executed on high
        % performance computers in batch mode, as the zip with fixed name
        % can be set as output file for the batch job
        bCreateSimulationOutputZIP = false;
        % In addition since batch jobs would overwrite the specific file if
        % multiple jobs all produce the same .ZIP file, a batch specific
        % output name, which the HPC also recognizes is necessary
        sOutputName;
    end
    
    % It is unknown why this property requires the dependent attribute to
    % be set to true.
    properties (GetAccess = public, Dependent = true)
        % This factor represents the simulated time / elapsed time. It
        % therefore represents how much faster than real time the
        % simulation is (if the factor is larger than 1) or how much slower
        % it is (smaller than 1)
        fSimFactor;
    end
    
    methods
        function this = infrastructure(sName, ptConfigParams, tSolverParams, tMonitors)
            % Setting the name property
            this.sName = sName;
            
            % Initializing the variables that can be set via the input
            % arguments. If the respective input arguments are empty,
            % placeholder variables are set. 
            if nargin < 2 || isempty(ptConfigParams), ptConfigParams = containers.Map(); end
            if nargin < 3 || isempty(tSolverParams),  tSolverParams  = struct(); end
            if nargin < 4 || isempty(tMonitors),      tMonitors      = struct(); end
            
            %% Setting up simulation monitors
            
            % To set up the monitors we need their names.
            csMonitors = fieldnames(tMonitors);
            
            % Looping through all of the monitors
            for iM = 1:length(csMonitors)
                % If the monitor doesn't exist, we create it
                if ~isfield(this.ttMonitorCfg, csMonitors{iM})
                    % The monitor can be passed in either in a struct with
                    % the format: struct('sClass','<Constructor Path>'), or
                    % as a string containing only the constructor path. In
                    % the latter case, we need to create the struct here. 
                    if ischar(tMonitors.(csMonitors{iM}))
                        this.ttMonitorCfg.(csMonitors{iM}) = struct('sClass', tMonitors.(csMonitors{iM}));
                    else
                        this.ttMonitorCfg.(csMonitors{iM}) = tMonitors.(csMonitors{iM});
                    end

                % If a struct with monitors is provided, we can now merge
                % and possibly overwrite the existing ones.
                elseif isstruct(tMonitors.(csMonitors{iM}))
                    
                    this.ttMonitorCfg.(csMonitors{iM}) = tools.mergeStructs(...
                        this.ttMonitorCfg.(csMonitors{iM}), ...
                        tMonitors.(csMonitors{iM}) ...
                    );
 
                % If the value is a string, overwrite or insert the monitor
                % and set value as sClass
                elseif ischar(tMonitors.(csMonitors{iM}))
                    if ~isfield(this.ttMonitorCfg, csMonitors{iM})
                        this.ttMonitorCfg.(csMonitors{iM}) = struct('sClass', tMonitors.(csMonitors{iM}));
                    else
                        this.ttMonitorCfg.(csMonitors{iM}).sClass = tMonitors.(csMonitors{iM});
                    end
                end
            end
            
            %% Create monitors
            
            % Getting the fieldnames 
            csMonitors = fieldnames(this.ttMonitorCfg);
            
            % Looping through all defined monitors
            for iM = 1:length(csMonitors)
                % Initializing the cParams cell
                cParams = {};
                
                % Taking the current constructor path and turning it into a
                % function handle
                hMonitorConstructor = str2func(this.ttMonitorCfg.(csMonitors{iM}).sClass);
                
                % If the monitor includes parameters, we retrieve them now
                % from the ttMonitorCfg struct property.
                if isfield(this.ttMonitorCfg.(csMonitors{iM}), 'cParams')
                    cParams = this.ttMonitorCfg.(csMonitors{iM}).cParams;
                end
                
                % Finally, we create the actual monitor.
                this.toMonitors.(csMonitors{iM}) = hMonitorConstructor(this, cParams{:});
            end
            
            %% Global objects and settings for constructors
            
            % Creating the global timer object
            oTimer = event.timer();
            
            % Starting a timer that we use to record how long it takes to
            % create the matter table object. 
            hTimer = tic();
            
            % If we are running this simulation in parallel with other
            % simulations, a key in the ptConfigParams container map must
            % be 'ParallelExecution'. If this key is present, some
            % parameters are passed in as a cell, which is in turn the
            % value for the 'ParallelExecution' key in ptConfigParams. So
            % we parse these parameters here. 
            if isKey(ptConfigParams, 'ParallelExecution')
                % Extracting the cell from the containers.Map.
                cConfigParams = ptConfigParams('ParallelExecution');
                
                % The matter table object will have been instantiated
                % outside of the parallel loop and is the first item in the
                % cell. So we just assign it here and check its validity.
                oMT = cConfigParams{1};
                if ~isa(oMT, 'matter.table')
                    this.throw('infrastructure','The provided object is not a matter table.');
                end
                
                % Now we can set the data queue object and identifier
                % properties as well. 
                this.oDataQueue = cConfigParams{2};
                this.iParallelSimulationID = cConfigParams{3};
                
                % Setting the parallel execution flag to true.
                this.bParallelExecution = true;
                
                % Remove the ParallelExecution key from ptConfigParams
                % because it contains a data queue which should not be
                % saved.
                remove(ptConfigParams, 'ParallelExecution');
            else
                % This simulation is being run individually, so we can just
                % call the matter table constructor directly.
                oMT = matter.table();
            end
            
            if isKey(ptConfigParams, 'BatchExecution')
                cConfigParams = ptConfigParams('BatchExecution');
                this.bCreateSimulationOutputZIP = cConfigParams{1};
                
                this.sOutputName = cConfigParams{2};
            end
            
            % Showing the user how long it took to create the matter table
            % object.
            disp(['Matter Table created in ', num2str(toc(hTimer)), ' seconds.'])
            
            % Getting the object containing the configuration parameters. 
            oCfgParams = simulation.configurationParameters(ptConfigParams);
            
            % Create the root object for the simulation, referencing the
            % global objects. Also the hierarchy root for the systems.
            this.oSimulationContainer = simulation.container(this.sName, oTimer, oMT, oCfgParams, tSolverParams);

            % Remember the date and time at which this simulation was
            % created. 
            this.fCreated = now();
            this.sCreated = datestr(this.fCreated);
            
            % Bind the playFinishSound() method to the 'finished' event.
            % The actual playing of the finish sound is off by default. It
            % can be turned on by setting the bPlayFinishSound property of
            % this class to true. 
            this.bind('finish', @(~) this.playFinishSound());
        
            % Triggering the pre-initialization event
            this.trigger('init_pre');
            
            % Now the child class constructor will run. After that is
            % finished, the initialize() method (that also sends init_post)
            % will have to be called explicitly (e.g. from vhab.sim) or in
            % .run() below (if first tick).
        end
        
        function initialize(this)
            %INITIALIZE Creates and seals the models, configures monitors
            
            % Just in case, if this was already done we abort.
            if this.bInitialized
                return;
            end
            
            % Getting a reference to the simulation container to make the
            % code more legible
            oRoot = this.oSimulationContainer;
            
            % Telling the user what is happening, things can take longer
            % here so it's good to let them know nothing has crashed. 
            disp('Assembling Simulation Model...')
            
            % For debugging purposes and general information we start a
            % timer here to see how long it takes to put the entire
            % simulation model together. 
            hTimer = tic();
            
            % Now we loop through all children of the root system and call
            % their create<DOMAIN>Structure() and seal<DOMAIN>Structure()
            % methods. These will also recursively call the same methods on
            % their child systems.
            for iC = 1:length(oRoot.csChildren)
                % Getting a reference to the current child system
                oChild = oRoot.toChildren.(oRoot.csChildren{iC});
                
                % Matter Domain
                if ismethod(oChild,'createMatterStructure')
                    oChild.createMatterStructure();
                    oChild.sealMatterStructure();
                end

                % Thermal Domain
                if ismethod(oChild,'createThermalStructure')
                    oChild.createThermalStructure();
                    oChild.createAdvectiveThermalBranches(oChild.aoBranches);
                    oChild.sealThermalStructure();
                end
                
                % Electrical Domain
                if ismethod(oChild,'createElectricalStructure')
                    oChild.createElectricalStructure();
                    oChild.sealElectricalStructure();
                end
                
                % Creating the solver structure, adding branches etc. to
                % their assigned solvers.
                oChild.createSolverStructure();
                
                % Making sure that all of our branches have a solver
                % assigned to them, just in case the user forgot to assign
                % one of them. 
                oChild.checkMatterSolvers();
                oChild.checkThermalSolvers();
            end
            
            % And were done with model assembly so we can now tell the user
            % how long it took. 
            disp(['Model Assembly Completed in ', num2str(toc(hTimer)), ' seconds!']);
            
            % Setting the boolean property to true so we don't do this
            % twice by accident. 
            this.bInitialized = true;

            % Setup monitors
            this.configureMonitors();
            
            % Trigger event so e.g. monitors can react
            this.trigger('init_post');
        end
        
        function run(this)
            %RUN Actually runs a simulation
            % Depending on the value of the bUseTime property the
            % simulation will either run to a pre-determined tick value or
            % time in seconds. 
            
            % If we are not yet initialized and this is the very first tick
            % (default value in the timer for the iTick property is -1) we
            % run that method. 
            if this.oSimulationContainer.oTimer.iTick == -1 && ~this.bInitialized
                this.initialize();
            end
            
            % If the simualtion object was saved as part of the dumpToMat()
            % method in the logger, the saveobj() method of this class will
            % have disconnected all branches on the right side. This is
            % done to prevent MATLAB from crashing due to the recursion
            % limit being exceeded. In that case the bBranchesDisconnected
            % property will be true and we need to reconnect all branches.
            if this.bBranchesDisconnected
                fprintf('Hold on, need to reconnect all branches...  ');
                this.reconnectBranches();
                fprintf('Done!\n');
            end
            
            % Some information for the users so they know what's going on
            % and also to visually structure the console output a bit. We
            % only output this, if we want to and the first time this is
            % run.
            if ~this.bSuppressConsoleOutput || this.oSimulationContainer.oTimer.iTick == -1
                disp('Initialization complete!');
                fprintf('+-----------------------------------------------------------------------------------+\n');
                disp('Starting simulation run...');
            end
            
            % Deploying a trigger so the monitors can react.
            this.trigger('run');
            
            % Actucally running the simulation. The use of 'while true'
            % will cause the simulation to run indefinitely, so every
            % iteration we check if either the time or tick limit has been
            % reached. 
            while true
                % Simulation finished?
                if this.bUseTime && (this.oSimulationContainer.oTimer.fTime >= this.fSimTime),       break;
                elseif ~this.bUseTime && (this.oSimulationContainer.oTimer.iTick >= this.iSimTicks), break;
                end
                
                % This call performs one single simulation step.
                this.step();
                
                if this.bParallelExecution
                    
                    if mod(this.oSimulationContainer.oTimer.iTick, this.iParallelSendInterval) == 0
                        if this.bUseTime
                            fProgress = this.oSimulationContainer.oTimer.fTime / this.fSimTime;
                        else
                            fProgress = this.oSimulationContainer.oTimer.iTick / this.iSimTicks;
                        end
                        
                        send(this.oDataQueue, [this.iParallelSimulationID, fProgress]);
                    end
                end
            end
            
            % Only trigger 'finish' if we actually want the console output
            % and if the simulation isn't paused. For the use case with
            % TherMoS calling V-HAB, the finish event is triggered
            % separately using the triggerFinish() method of this class.
            if ~this.bSuppressConsoleOutput && ~this.toMonitors.oExecutionControl.bPaused
                this.trigger('finish');
            end
            
        end
        
        function pause(this, varargin)
            %PAUSE Pauses the simulation after the current tick has been completed
            % Setting the end tick to the current tick
            this.iSimTicks = this.oSimulationContainer.oTimer.iTick;
            
            % Use ticks to determine the end of the simulation
            this.bUseTime  = false;
            
            % Trigger the pause event
            this.trigger('pause');
        end
        
        function advanceTo(this, fTime, oDataQueue, iParallelSimulationID, bCreateSimulationOutputZIP, sOutputName)
            %ADVANCETO Runs the simulation to a specific time in seconds
            %   This can be used if a simulation has been stopped or paused
            
            % Setting the end time to the provided value
            this.fSimTime = fTime;
            
            % Use the time in seconds to determine the end of the
            % simulation
            this.bUseTime = true;
            
            if nargin > 4
                this.sOutputName                = sOutputName;
                this.bCreateSimulationOutputZIP = bCreateSimulationOutputZIP;
            elseif nargin > 2
                % if a parellel execution for the advancement of the
                % simulation is used, then store the required paremeters
                % here_
                this.oDataQueue             = oDataQueue;
                this.iParallelSimulationID  = iParallelSimulationID;
            end
            % Running the simulation
            this.run();
        end
        
        function advanceFor(this, fSeconds)
            %ADVANCEFOR Runs the simulation for a specific number of seconds
            %   This can be used if a simulation has been stopped or paused
            
            % Setting the end time for now plus the given number of seconds
            this.fSimTime = this.oSimulationContainer.oTimer.fTime + fSeconds;
            
            % Use the time in seconds to determine the end of the
            % simulation
            this.bUseTime = true;
            
            % Running the simulation
            this.run();
        end
        
        
        
        function tickTo(this, iTick)
            %TICKTO Runs the simulation to a specific tick
            %   This can be used if a simulation has been stopped or paused
            
            % Setting the end tick to the provided value
            this.iSimTicks = iTick;
            
            % Use ticks to determine the end of the simulation
            this.bUseTime  = false;
            
            % Running the simulation
            this.run();
        end
        
        function tickFor(this, iTicks)
            %TICKFOR Runs the simulation for a specific number of ticks
            %   This can be used if a simulation has been stopped or paused
            
            % Setting the end tick as the current tick plus the given
            % number of ticks
            this.iSimTicks = this.oSimulationContainer.oTimer.iTick + iTicks;
            
            % Use ticks to determine the end of the simulation
            this.bUseTime  = false;
            
            % Running the simulation
            this.run();
        end
        
        
        
        function step(this)
            %STEP This method performs one simulation step
            %   The actual time of this simulation step is calculated in
            %   the timer. 
            
            % Triggering the pre step event. We want to track how long
            % these tasks take, so we start a timer before the event is
            % posted and add the end time to the fRuntimeOther property.
            hTimer = tic();
            this.trigger('step_pre');
            this.fRuntimeOther = this.fRuntimeOther + toc(hTimer);
            
            
            % Now we call the tick() method of the timer object where the
            % simulation model is advanced by one tick. Again, since we
            % want to track how long this takes, we start a timer before
            % the call is made and add the end time to the fRuntimeTick
            % property.
            hTimer = tic();
            this.oSimulationContainer.oTimer.tick();
            this.fRuntimeTick = this.fRuntimeTick + toc(hTimer);
            
            
            % Triggering the post step event. The same procedure as every
            % year, James. 
            hTimer = tic();
            this.trigger('step_post');
            this.fRuntimeOther = this.fRuntimeOther + toc(hTimer);
        end
        
        
        function triggerFinish(this)
            %TRIGGERFINISH Triggers the 'finish' event
            % This is just here so we can trigger the final simulation
            % console output from TherMoS.
            this.trigger('finish');
        end
        
        function saveSim(this, sAppendix)
            %SAVESIM Saves the entire simulation object in a .mat file
            
            % Checking if the user passed in a string to append to the file
            % name.
            if nargin < 2 || isempty(sAppendix)
                sAppendix = '';
            else
                sAppendix = [ '_' sAppendix ];
            end
            
            % Since we may be saving multiple times during the simulation,
            % we find out the current tick so we can add it to the file
            % name.
            sTick = [ '_tick' num2str(this.oSimulationContainer.oTimer.iTick) ];
            
            % Creating the file name using the fCreated property to make it
            % unique to this particular simulation object. 
            sPath = [  this.sName '_' datestr(this.fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') sTick sAppendix ];
            
            % We want the saved variable to have a different name than the
            % ambiguous 'this', so we create a reference. 
            oSimObj = this;
            
            % Actually performing the save operation.
            save([ 'data/' sPath '.mat' ], 'oSimObj');

        end
        
        function playFinishSound(this)
            %PLAYFINISHSOUND Plays a sound at the end of a simulation
            
            % Only do this if the user wants to
            if this.bPlayFinishSound
                % Loading the data for the finishing sound
                [afSampleData, afSampleRate] = audioread('lib/+special/V-HAB_Finish_Sound.mp3');
                % Playing the finishing sound
                sound(afSampleData, afSampleRate);
            end
        end
        
        function oPlotter = plot(this, sLogger)
            %PLOT Returns a reference to the plotter object
            %   In case the user has defined multiple loggers, the second
            %   input argument can be used to select which one. 
            
            % Checking if a certain logger is specified and then getting
            % either that one or the default logger. 
            if nargin >= 2
                oPlotter = tools.postprocessing.plotter(this, sLogger);
            else
                oPlotter = tools.postprocessing.plotter(this);
            end
        end

        
        function delete(this)
            %DELETE Deletes the monitor objects associated with this simulation
            
            % Getting the field names
            csMonitors = fieldnames(this.toMonitors);
            
            % Looping throuhg the toMonitors struct and deleting the
            % individual monitors. 
            for iM = 1:length(csMonitors)
                delete(this.toMonitors.(csMonitors{iM}));
            end
        end
    
        %% Getters / Setters
        function fSimFactor = get.fSimFactor(this)
            %GET.SIMFACTOR Calculates the ratio between simulated time and the time it took to complete the simulation 
            
            % Checking if the simulation has even started. If yes, return
            % NaN, otherwise perform the calculation.
            if isempty(this.oSimulationContainer.oTimer) || (this.oSimulationContainer.oTimer.fTime == -10)
                fSimFactor = nan;
            else
                fSimFactor = this.oSimulationContainer.oTimer.fTime / (this.fRuntimeTick + this.fRuntimeOther);
            end
        end
        
        function setSuppressConsoleOutput(this, bSuppressConsoleOutput)
            %SETSUPPRESSCONSOLEOUTPUT Set console output mode
            %   The setting is intended to suppress console output when
            %   multiple simulations are run in parallel, since they would
            %   spam the console of the main instance.
            this.bSuppressConsoleOutput = bSuppressConsoleOutput;
        end
        
        function setParallelSendInterval(this, iInterval)
            %SETPARALLELSENDINTERVAL Sets update frequency parameter
            %   When simulations are run in parallel updates are sent to
            %   the main MATLAB instance to display the simulation progress
            %   to the user. If simulations run too fast, i.e. the ticks
            %   are very short, these updates can slow the simulation down
            %   significantly. So this method allows the updates to be sent
            %   in intervals other than 1. 
            this.iParallelSendInterval = iInterval;
        end

        function disableParallelExecution(this, ~)
            %DISABLEPARALLELEXECUTION this function can be called on the
            % oLastSimObj of a simulation created with the parallel
            % execution script in core\+tools\generalParallelExecution.m
            % to continue the simulation without parallelization (e.g. for
            % debugging)
            this.bParallelExecution = false;
            this.iParallelSimulationID = [];
        end
        
        function oOutput = saveobj(oInput)
            %SAVEOBJ Saves modified simulation object
            %   Starting with MATLAB 2020b a limit exists for the length of
            %   the object hierarchy tree when they are saved to a MAT
            %   file. The limit seems to be 500 *unique* objects. Recursive
            %   pointers (i.e. parent->child and child-> parent) seem to
            %   have no effect on this limit. When more than 500 objects
            %   are referenced in a row, a warning is thrown and the object
            %   cannot be correctly saved. In some cases MATLAB crashes
            %   completely during the save process. Even though this limit
            %   can be increased via a MATLAB environment variable, it
            %   still causes crashes. 
            %   Part of the solution to this problem is this method. It
            %   overloads the saveobj() method of the internal MATLAB
            %   object. Below we loop through all systems and subsystems
            %   contained in this simulation object and disconnect the
            %   both sides of each matter, thermal and electrical branch.
            %   This will limit the length of the hierarchy tree. In the
            %   loadobj() method of this class (see below) this process is
            %   reversed.
            
            % For some weird reason the entire simulation object is saved
            % when tools.postprocessing.plotter.saveFigureAs is used. That
            % can lead to extremely large file sizes. To catch this we look
            % at the debug stack here, if this save method was invoked by
            % the savefig() function, we just return an empty variable. 
            tDBStack = dbstack;
            if strcmp(tDBStack(3).name, 'savefig')
                oOutput = [];
                return;
            end

            % Setting the output object handle to the input object handle.
            % The example in the MATLAB documentation does this as well,
            % otherwise I don't know if this is really necessary.
            oOutput = oInput;
            
            % Getting the names of all children (systems)
            csChildNames = fieldnames(oOutput.oSimulationContainer.toChildren);
            
            % Looping through all children and calling the
            % disconnectedBranchesForSaving() Method of the vsys class.
            for iI = 1:oOutput.oSimulationContainer.iChildren
                oOutput.oSimulationContainer.toChildren.(csChildNames{iI}).disconnectBranchesForSaving();
            end
            
            % Now that we are finished, we set the bBranchesDisconnected
            % property to true so future calls for execution know to
            % reconnect them.
            oOutput.bBranchesDisconnected = true;
        end
    end
    
    methods (Access = {?simulation.monitors.logger})
        function reconnectBranches(this)
            % Getting the names of all children (systems)
            csChildNames = fieldnames(this.oSimulationContainer.toChildren);
            
            % Looping throuhg all children and calling the
            % reconnectBranches() Method of the vsys class.
            for iI = 1:this.oSimulationContainer.iChildren
                this.oSimulationContainer.toChildren.(csChildNames{iI}).reconnectBranches();
            end
            
            % Now that we are finished, we can set the
            % bBranchesDisconnected property to false.
            this.bBranchesDisconnected = false;
        end
    end
    
    methods (Static)
        function oOutput = loadobj(oInput)
            %LOADOBJ Loads sim object from file and reconnects branches
            %   For a detailed discussion see description of saveobj()
            %   method. 
            
            % Setting the output object handle to the input object handle.
            % The example in the MATLAB documentation does this as well,
            % otherwise I don't know if this is really necessary.
            oOutput = oInput;
            
            % Getting the names of all children (systems)
            csChildNames = fieldnames(oOutput.oSimulationContainer.toChildren);
            
            % Looping throuhg all children and calling the
            % reconnectBranches() Method of the vsys class.
            for iI = 1:oOutput.oSimulationContainer.iChildren
                oOutput.oSimulationContainer.toChildren.(csChildNames{iI}).reconnectBranches();
            end
            
            % Now that we are finished, we can set the
            % bBranchesDisconnected property to false.
            oOutput.bBranchesDisconnected = false;
        end
    end
end
