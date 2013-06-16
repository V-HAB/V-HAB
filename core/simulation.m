classdef simulation < base & event.source
    %SIM Summary of this class goes here
    %   Detailed explanation goes here
    %
    % The constructor of the derived class needs to or should set csLog,
    % and either iSimTicks of fSimTime.
    
    properties
        % Amount of ticks
        iSimTicks = 100;
        
        % Simulation time [s]
        fSimTime  = 3600 * 1;
        
        % Use time or ticks to check if simulation finished?
        bUseTime = true;
    end
    
    % Properties to be set by classes deriving from this one
    properties (SetAccess = protected, GetAccess = public)
        % Attributes to log
        csLog = {};
    end
    
    
    properties (SetAccess = private, GetAccess = public)
        % Name of sim
        sName;
        
        % Logged data
        mfLog;
        aiLog;
        
        % Root system
        oRoot;
        
        % Timer
        oTimer;
        
        % Data
        oData;
        
        
        fRuntimeTick = 0;
        fRuntimeLog  = 0;
        
        % Matlab date number -> object/sim created
        fCreated = 0;
        sCreated = '';
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
            
            if ~isfield(tData, 'oTimer')
                tData.oTimer = event.timer(fMinStep);
            end
            
            if ~isfield(tData, 'oMT')
                tData.oMT = matter.table();
            end
            
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
            end
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
        end
        
        function log(this)
            iTmpSize = size(this.mfLog, 1);

            if this.oTimer.iTick > iTmpSize
                this.mfLog((iTmpSize + 1):(iTmpSize + 1000), :) = nan(1000, length(this.csLog));
            end

            for iL = this.aiLog
                this.mfLog(this.oTimer.iTick + 1, iL) = eval([ 'this.oRoot.' this.csLog{iL} ]);
            end
        end
    end
    
    
    %% Getters / Setters
    methods
        function set.csLog(this, csLog)
            this.csLog = csLog;
            this.aiLog = 1:length(csLog);
            
            %TODO What if sim already runs?
            this.mfLog = nan(1000, length(csLog));
        end
    end
end

