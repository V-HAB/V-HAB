classdef simulation < base & event.source
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
        sStorageName;
        sDescription;
    end
    
    properties (SetAccess = public, GetAccess = public)
        % Amount of ticks
        % @type int
        iSimTicks = 100;
        
        % Simulation time [s]
        % @type int
        fSimTime  = 3600 * 1;
        
        % Use time or ticks to check if simulation finished?
        % @type int
        bUseTime = true;
        
        
        % Interval in which the mass balance logs are written
        iMassLogInterval = 100;
        
        
        % Preallocation - how much rows should be preallocated for logging?
        iPrealloc = 1000;
        
        % Dump mfLog to .mat file when re-preallocating?
        bDumpToMat = false;
        
        % Boolean variable to suppress the big output block at the end of each simulation as defined
        % in the finish() method of this class. This is mainly for cases when V-HAB is being called
        % by TherMoS every simulated second. 
        bFinishQuietly = false;
    end
    
    % Properties to be set by classes deriving from this one
    properties (SetAccess = protected, GetAccess = public)
        % Attributes to log
        %TODO: add |Recorder| class that handles logging
        csLog = {};
    end
    
    
    properties (SetAccess = private, GetAccess = public)
        % Name of sim
        % @type string
        sName;
        
        % Logged data
        mfLog;
        aiLog;
        
        % Current index in logging
        iLogIdx = 0;
        
        % How much allocated?
        iAllocated = 0;
        
        % Parsed/evald logginng!
        logData;
        
        % Root system
        % @type object
        oRoot;
        
        % Timer
        % @type object
        oTimer;
        
        % Data
        oData;
        
        
        fRuntimeTick = 0;
        fRuntimeLog  = 0;
        
        % Matlab date number -> object/sim created
        fCreated = 0;
        
        % @type string
        sCreated = '';
        
        % String for disk storage
        sStorageDir;
        
        % Variables holding the sum of lost mass / total mass, species-wise
        mfTotalMass = [];
        mfLostMass  = [];
    end
    
    properties (GetAccess = public, Dependent = true)
        fSimFactor;
    end
    
    methods
        function this = simulation(sName, fMinStep, tData)
            % Simulation class constructor.
            %
            %simulation parameters
            %   - sName*    name of the sim
            %   - fMinStep  Minimum time step (empty - 1e-8)
            %   - tData     Struct with attributes/keys for data object
            %               that will be attached to all systems
            %
            % If only tData needed, can be passed as first param as well.
            % Timer and matter table automatically created if not defined
            % as field in tData (oTimer, oMT, also oRoot).
            
            this.sName = sName;
            
            if (nargin == 2) && isstruct(fMinStep)
                tData    = fMinStep;
                fMinStep = [];
            elseif nargin < 3
                tData = struct();
            end
            
            if (nargin < 2) || isempty(fMinStep), fMinStep = 1e-8; end;


            %%% Global objects and settings for constructors

            if ~isfield(tData, 'oTimer')
                tData.oTimer = event.timer(fMinStep);
            end
            
            if ~isfield(tData, 'oMT')
                hTimer = tic();
                tData.oMT = matter.table();
                disp(['Matter Table created in ', num2str(toc(hTimer)), ' seconds.'])
            end
            
            % Basic parameters can be stored here. Reference systems by
            % their constructor names.
            if ~isfield(tData, 'oParams'), tData.oParams = containers.Map(); end;
            
            
            %%% Global parameters to tune solving process.
            
            % Used to adjust the rMaxChange parameter in (gas) phases. Can
            % still be set manually (after .seal() was called). Sets the
            % rMaxChange value according to the volume multiplied by this
            % parameter here.
            tData.rUpdateFrequency = 1;
            
            % Adaptive rMaxChange- if phase mass does not change, value is
            % decreased accordingly
            tData.rHighestMaxChangeDecrease = 0;
            
            %  For each (iterative) solver, a dampening value can be set in
            %  the constructor which is multiplied with this value
            tData.rSolverDampening = 1;
            
            %TODO increase accuracy/fidelity of solvers (i.e. shorter time
            %     steps, lower solving error allowed, etc).
            tData.rSolverFidelity  = 1;
            
            
            %%% Initialize root system, simulation parameters
            
            % Create data object
            this.oData = data(tData);
            
            % Create root object, set timer object to 'this' as well
            this.oRoot  = systems.root(this.sName, this.oData);
            this.oTimer = this.oData.oTimer;
            
            % Add the root system to the data object
            this.oData.set('oRoot', this.oRoot);
            
            % Remember the time of object creation
            this.fCreated = now();
            this.sCreated = datestr(this.fCreated);
            %this.sStorageDir = [ datestr(this.fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') '_' this.sUUID ];
            this.sStorageDir = [ datestr(this.fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') '_' this.sName ];
            
            % Init the mass log matrices - don't log yet, system's not
            % initialized yet! Just create with one row, for the initial
            % mass log. Subsequent logs dynamically allocate new memory -
            % bad for performance, but only happens every Xth tick ...
            this.mfTotalMass = zeros(0, this.oData.oMT.iSubstances);
            this.mfLostMass  = zeros(0, this.oData.oMT.iSubstances);
        end
        
        
        function run(this)
            % Run until tick/time (depending on bUseTime)
            % iSimTicks/fSimTime reached - directly set attributes to
            % influence behaviour
            
            while true
                % Simulation finished?
                if this.bUseTime && (this.oTimer.fTime >= this.fSimTime),       break;
                elseif ~this.bUseTime && (this.oTimer.iTick >= this.iSimTicks), break;
                end
                
                this.tick();
                
                % Stopped?
                if this.bDumpToMat && (this.oTimer.iTick > 0) && (mod(this.oTimer.iTick, this.iPrealloc) == 0)
                    sFile = [ 'data/runs/' this.sStorageDir '/STOP' ];
                    
                    % Always do that!
                    disp('#############################################');
                    disp('Writing sim obj to .mat!');
                    this.finish();
                    
                    disp([ 'Checking for STOP file: ' sFile ]);
                    
                    if exist(sFile, 'file') == 2
                        disp('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
                        disp('STOPPED by STOP file. Har. Restart with "oLastSimObj.run()"');
                        
                        break;
                    end
                end
            end
        end
        
        
        function pause(this, varargin)
            this.iSimTicks = this.oTimer.iTick;
            this.bUseTime  = false;
            disp('##################### PAUSE ###################');
        end
        
        
        function advanceTo(this, fTime)
            % Run to specific time and set to fSimTime
            
            this.fSimTime = fTime;
            this.bUseTime = true;
            
            this.run();
        end
        
        function advanceFor(this, fSeconds)
            % Run for specific duraction and set to fSimTime
            
            this.fSimTime = this.oTimer.fTime + fSeconds;
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
            
            this.iSimTicks = this.oTimer.iTick + iTicks;
            this.bUseTime  = false;
            
            this.run();
        end
        
        
        
        function tick(this)
            % Pre-check -> timer tick at -1 --> initial call. So do the
            % mass log, need the initial values.
            if this.oData.oTimer.iTick == -1
                this.masslog();
            end
            
            
            % Advance one tick
            
            this.trigger('tick.pre');
            
            % Tick and measure time
            hTimer = tic();
            this.oData.oTimer.step();
            this.fRuntimeTick = this.fRuntimeTick + toc(hTimer);
            
            % Log and measure time
            hTimer = tic();
            this.log();
            this.fRuntimeLog = this.fRuntimeLog + toc(hTimer);
            
            this.trigger('tick.post');
            
            
            % Mass log?
            %TODO do by time, not tick? Every 1s, 10s, 100s ...?
            %     see old main script, need a var like fNextLogTime, just
            %     compare this.oData.oTimer.fTIme >= this.fNexLogTime.
            if mod(this.oData.oTimer.iTick, this.iMassLogInterval) == 0
                this.masslog();
            end
            
            % Sim finished?
            if (this.bUseTime && (this.oTimer.fTime >= this.fSimTime)) || (~this.bUseTime && (this.oTimer.iTick >= this.iSimTicks))
                this.finish();
            end
        end
        
        
        function finish(this)
            %TODO put in vhab class -> just trigger 'finish' here!
            if ~this.bFinishQuietly
                disp('--------------------------------------');
                disp([ 'Sim Time:     ' num2str(this.oTimer.fTime) 's in ' num2str(this.oTimer.iTick) ' ticks' ]);
                disp([ 'Sim Runtime:  ' num2str(this.fRuntimeTick + this.fRuntimeLog) 's, from that for dumping: ' num2str(this.fRuntimeLog) 's' ]);
                disp([ 'Sim factor:   ' num2str(this.fSimFactor) ' [-] (ratio)' ]);
                disp([ 'Avg Time/Tick:' num2str(this.oTimer.fTime / this.oTimer.iTick) ' [s]' ]);
                disp([ 'Mass lost:    ' num2str(sum(this.mfLostMass(end, :))) 'kg' ]);
                disp([ 'Mass balance: ' num2str(sum(this.mfTotalMass(1, :)) - sum(this.mfTotalMass(end, :))) 'kg' ]);
                disp([ 'Minimum Time Step * Total Sim Time: ' num2str(this.oTimer.fMinimumTimeStep * this.oTimer.fTime) ]);
                disp([ 'Minimum Time Step * Total Ticks:    ' num2str(this.oTimer.fMinimumTimeStep * this.oTimer.iTick) ]);
                disp('--------------------------------------');
            end
            %TODO if bDump, write .mat!
            if this.bDumpToMat
                if ~isdir([ 'data/runs/' this.sStorageDir ])
                    mkdir([ 'data/runs/' this.sStorageDir ]);
                end
                
                sMat = [ 'data/runs/' this.sStorageDir '/_simObj.mat' ];
                disp(['DUMPING - write to .mat: ' sMat]);
   
                oLastSimObj = this;
                save(sMat, 'oLastSimObj');
            end
        end
        
        
        
        function log(this)
            %iTmpSize = size(this.mfLog, 1);
            this.iLogIdx = this.iLogIdx + 1;
            
            %TODO
            %   - instead of hardcoded 1000 - get from this.iPrealloc
            %   - value this.iDump (or make eq iPrealloc?) -> dump mfLog:
            %       - write to [uuid]/[cnt].mat, clean mfLog
            %       - at the end, for plotAll or so, do some .reloadLog()
            %       -> mat files within SimObj uuid Dir --> load all
            %          and re-create mfLog!
            
            % HERE if bDump and > iTmpSize - WRITE (use iCnt?) to MAT!
            %   then just reset vars to NaN on mfLog, do not append!
            
            %if this.oTimer.iTick > iTmpSize
            if this.iLogIdx > this.iAllocated
                if this.bDumpToMat
                    if ~isdir([ 'data/runs/' this.sStorageDir ])
                        mkdir([ 'data/runs/' this.sStorageDir ]);
                    end
                    
                    
                    sMat = [ 'data/runs/' this.sStorageDir '/dump_' num2str(this.oTimer.iTick) '.mat' ];
                    
                    disp('#############################################');
                    disp(['DUMPING - write to .mat: ' sMat]);
                    
                    mfLog = this.mfLog;
                    save(sMat, 'mfLog');
                    
                    disp('... done!');
                    
                    this.mfLog(:, :) = nan(this.iPrealloc, length(this.csLog));
                    this.iLogIdx     = 1;
                else
                    this.iAllocated = this.iAllocated + this.iPrealloc;
                    
                    %this.mfLog((iTmpSize + 1):(iTmpSize + this.iPrealloc), :) = nan(this.iPrealloc, length(this.csLog));
                    this.mfLog(this.iLogIdx:(this.iLogIdx + this.iPrealloc - 1), :) = nan(this.iPrealloc, length(this.csLog));
                end
            end
            
            % Create one loggin function!
            if isempty(this.logData)
                sCmd = '[';
                
                for iL = this.aiLog
                    sCmd = [ sCmd 'this.oRoot.' this.csLog{iL} ',' ];
                    %sCmd = [ sCmd sprintf('this.oRoot.%s,\n', this.csLog{iL}) ];
                end

                sCmd = [ sCmd(1:(end - 1)) ']' ];
                
                this.logData = eval([ '@() ' sCmd ]);
            end
            
            %this.mfLog(this.oTimer.iTick + 1, :) = this.logData();
            
            try
                this.mfLog(this.iLogIdx, :) = this.logData();
            catch
                % Don't know where in anonymous log function the error
                % happend, so go through logs one by one - one of them
                % should throw an error!
                for iL = this.aiLog
                    try
                        eval([ 'this.oRoot.' this.csLog{iL} ';' ]);
                    catch oErr
                        this.throw('simulation',['Error trying to log this.oRoot.%s.\n',...
                                                 'Error Message: %s\n', ...
                                                 'Please check your logging configuration in setup.m\n',...
                                                 'The log item in question is number %i.'], ...
                                                 this.csLog{iL}, oErr.message, iL);
                    end
                end
            end
        end
        
        function masslog(this)
            iIdx = size(this.mfTotalMass, 1) + 1;
            
            % Total mass: sum over all mass stored in all phases, for each
            % species separately.
            this.mfTotalMass(iIdx, :) = sum(reshape([ this.oData.oMT.aoPhases.afMass ], this.oData.oMT.iSubstances, []), 2)';
            
            % Lost mass: logged by phases if more mass is extracted then
            % available (for each substance separately).
            this.mfLostMass(iIdx, :) = sum(reshape([ this.oData.oMT.aoPhases.afMassLost ], this.oData.oMT.iSubstances, []), 2)';
            
            %TODO implement methods for that ... break down everything down
            %     to the moles and compare these?! So really count every
            %     atom, not the molecules ... compare enthalpy etc?
        end
        
        
        function readData(this)
            if this.bDumpToMat
                sDir    = [ 'data/runs/' this.sStorageDir '/' ];
                tDir    = dir(sDir);
                aiDumps = [];
                
                for iD = 1:length(tDir)
                    if (length(tDir(iD).name) > 5) && strcmp(tDir(iD).name(1:5), 'dump_')
                        %disp([ sDir tDir(iD).name ]);
                        aiDumps(end + 1) = str2double(tDir(iD).name(6:(end - 4)));
                    end
                end
                
                aiDumps = sort(aiDumps);
                
                for iF = length(aiDumps):-1:1
                    tFile = load([ sDir 'dump_' num2str(aiDumps(iF)) '.mat' ]);
                    
                    this.mfLog = [ tFile.mfLog; this.mfLog ];
                end
            end
        end

        function saveFullObj(this, sDir)

            this.readData();

            oSimObj = this;
            sMat    = sif(isempty(this.sStorageName), this.sStorageDir, this.sStorageName);

            save([ 'data/full/' sDir '/' sMat '.mat' ], 'oSimObj');

        end

    end
    
    
    %% Getters / Setters
    methods
        function set.csLog(this, csLog)
            this.csLog = csLog;
            this.aiLog = 1:length(csLog);
            
            %TODO What if sim already runs?
            this.mfLog      = nan(this.iPrealloc, length(csLog));
            this.iAllocated = this.iPrealloc;
        end
        
        function fSimFactor = get.fSimFactor(this)
            if isempty(this.oTimer) || (this.oTimer.fTime == -10)
                fSimFactor = nan;
            else
                fSimFactor = this.oTimer.fTime / (this.fRuntimeTick + this.fRuntimeLog);
            end
        end
    end
end

