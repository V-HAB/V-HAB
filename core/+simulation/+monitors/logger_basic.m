classdef logger_basic < simulation.monitor
    %LOGGER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (GetAccess = public, Constant = true)
        poUnitsToLabels = containers.Map(...
            { 'kg',   'kg/s',      'K',           'Pa',       '-'}, ...
            { 'Mass', 'Flow Rate', 'Temperature', 'Pressure', '-' } ...
        );
    end
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Logged values - path, name, ...
        tLogValues = struct('sPath', {}, 'sName', {}, 'sUnit', {});%, 'iIndex', {});
        
        % Shortcut to the paths of variables to log
        csPaths;
        
        % Preallocation - how much rows should be preallocated for logging?
        iPrealloc = 1000;
        
        % Dump mfLog to .mat file when re-preallocating?
        bDumpToMat = false;
        
        
        
        % Sim time for each log point
        afTime;
        
        % Logged data
        mfLog;
        aiLog;
        
        % Current index in logging
        iLogIdx = 0;
        
        % How much allocated?
        iAllocated = 0;
        
        % Parsed/evald logginng!
        logDataEvald;
    end
    
    methods
        function this = logger_basic(oSimulationInfrastructure)
            %this@simulation.monitor(oSimulationInfrastructure, struct('tick_post', 'logData', 'init_post', 'init'));
            this@simulation.monitor(oSimulationInfrastructure, { 'tick_post', 'init_post' });
        end
        
        
        
        function this = add(this, xVsys, xHelper, varargin)
            % xVsys - if string, convert to full path and eval 
            %           (e.g. sys1/subsys1/subsubsys2)
            % xHelper - if string, check s2f('sim.helper.logger_basic.' 
            %           xHelper), if not present, check global
            %           s2f(xHelper)
            
            % varargin -> to helper, besides oVsys!
            
            % RETURN from helper --> should be struct --> add to tLogValues
            tEmptyLogProps = struct('sPath', {}, 'sName', {}, 'sUnit', {});
            
            % Vsys object can be provided directly, or a string containing
            % the path to the vsys can be passed.
            if ischar(xVsys)
                sVsys = simulation.helper.paths.convertShorthandToFullPath(xVsys);
                
                oVsys = eval([ 'this.oSimulationInfrastructure.oSimulationContainer.toChildren.' sVsys ]);
            else
                oVsys = xVsys;
            end
            
            % Helper can be function handle, or name of the function.
            if ischar(xHelper)
                if ~isempty(which([ 'simulation.helper.logger_basic.' xHelper ]))
                    xHelper = str2func([ 'simulation.helper.logger_basic.' xHelper ]);
                    
                elseif ~isempty(which(xHelper))
                    xHelper = str2func(xHelper);
                    
                else
                    this.throw('add', 'Helper "%s" not found!', xHelper);
                end
            end
            
            % Helper needs to return struct array
            tNewLogProps = xHelper(tEmptyLogProps, oVsys, varargin{:});
            
            % Merge
            for iL = 1:length(tNewLogProps)
                % Only add property if not yet logged!
                if isempty(find(strcmp({ this.tLogValues.sPath }, tNewLogProps(iL).sPath), 1))
                    this.tLogValues(end + 1) = tNewLogProps(iL);
                end
            end
        end
        
        
        function this = addValue(this, sPath, sName, sUnit)
            %TODO if no sUnit - try to guess / default units?
            
            sPath = simulation.helper.paths.convertShorthandToFullPath(sPath);
            
            if nargin < 4, sUnit = '-'; end;
            
            if isempty(find(strcmp({ this.tLogValues.sPath }, sPath), 1))
                this.tLogValues(end + 1) = struct('sPath', sPath, 'sName', sName, 'sUnit', sUnit);
            end
        end
        
        
        function [ axData, tConfig, sLabel ] = get(this, sPath)
            % Convert to full path
            % Get index from tLogValues
            
            sPath = simulation.helper.paths.convertShorthandToFullPath(sPath);
            iIdx  = find(strcmp({ this.tLogValues.sPath }, sPath), 1, 'first');
            
            axData  = this.mfLog(:, iIdx);
            tConfig = this.tLogValues(iIdx);
            sLabel  = this.poUnitsToLabels(tConfig.sUnit);
        end
    end
    
    
    methods (Access = protected)
        
        function this = onInitPost(this)
            % Indices to tLogValues (?, or on add?)
            % Eval Code!
            % Names / Paths to Cell for fast comp!
            disp('LOG onInitPost');
            
            
            % Collect all paths of values to log
            this.csPaths = { this.tLogValues.sPath };
            
            % Replace the root/container sys name by the path to get there
            sLen = length(this.oSimulationInfrastructure.oSimulationContainer.sName) + 1;
            
            for iL = 1:length(this.csPaths)
                %this.csPaths{iL} = [ 'this.oSimulationInfrastructure.oSimulationContainer' this.csPaths{iL}(sLen:end) ];
                this.csPaths{iL} = strrep(this.csPaths{iL}, ...
                    [ this.oSimulationInfrastructure.oSimulationContainer.sName '.' ], ...
                    'this.oSimulationInfrastructure.oSimulationContainer.' ...
                );
            end
            
            
            
            
            this.aiLog      = 1:length(this.csPaths);
            this.mfLog      = nan(this.iPrealloc, length(this.csPaths));
            this.iAllocated = this.iPrealloc;
            
            
            % Create pre-evald loggin' function!
            
            sCmd = '[';
                
            for iL = this.aiLog
                %sCmd = [ sCmd 'this.oRoot.' this.csLog{iL} ',' ];
                %sCmd = [ sCmd sprintf('this.oRoot.%s,\n', this.csLog{iL}) ];
                
                % sS((length(sN) + 1):end)
                sCmd = [ sCmd this.csPaths{iL} ',' ];
            end

            sCmd = [ sCmd(1:(end - 1)) ']' ];

            this.logDataEvald = eval([ '@() ' sCmd ]);
        end
        
        
        function onTickPost(this)
%             disp('LOG onTickPost');
%             disp(this.oSimulationInfrastructure.oSimulationContainer.oTimer.fTime);
            
            
            this.iLogIdx = this.iLogIdx + 1;
            
            
            this.afTime(this.iLogIdx) = this.oSimulationInfrastructure.oSimulationContainer.oTimer.fTime;
            
            try
                this.mfLog(this.iLogIdx, :) = this.logDataEvald();
            catch
                % Don't know where in anonymous log function the error
                % happend, so go through logs one by one - one of them
                % should throw an error!
                for iL = this.aiLog
                    try
                        eval([ this.csPaths{iL} ';' ]);
                    catch oErr
                        this.throw('simulation','Error trying to log this.oRoot.%s.\nError Message: %s\nPlease check your logging configuration in setup.m!', this.csPaths{iL}, oErr.message);
                    end
                end
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
                        this.throw('simulation','Error trying to log this.oRoot.%s.\nError Message: %s\nPlease check your logging configuration in setup.m!', this.csLog{iL}, oErr.message);
                    end
                end
            end
            %for iL = this.aiLog
            %    this.mfLog(this.oTimer.iTick + 1, iL) = eval([ 'this.oRoot.' this.csLog{iL} ]);
            %end
        end
    end
end

