classdef logger_basic < simulation.monitor
    %LOGGER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    %
    %TODO see old master -> simulation.m ==> bDumpToMat!
    %       1) in regular intervals, dump mfLog data to .mat file
    %       2) provide readData method -> re-read data from .mat files
    
    properties (GetAccess = public, Constant = true)
        % Loops through keys, comparison only with length of key
        % -> 'longer' keys need to be defined first (fMass * fMassToPress)
        poExpressionToUnit = containers.Map(...
            { 'this.fMass * this.fMassToPressure', 'fMassToPressure', 'fMass', 'afMass', 'fFlowRate', 'fTemperature', 'fPressure', 'afPP', 'fTotalHeatCapacity', 'fSpecificHeatCapacity', 'fConductivity', 'fPower', 'fCapacity', 'fResistance', 'fInductivity', 'fCurrent', 'fVoltage', 'fCharge' }, ...
            { 'Pa',                                'Pa/kg',           'kg',    'kg',     'kg/s',      'K',            'Pa',        'Pa',   'J/K',                'J/kgK',                 'W/K',           'W',      'F',         '?',           'H',            'A',        'V',        'C'       }  ...
        );
        
        poUnitsToLabels = containers.Map(...
            { 'kg',   'kg/s',      'K',           'Pa',       'J/K',                 'J/kgK',                  'W/K',          'W',     'F',        '?',          'H',           'A',       'V',       'C',      '-'}, ...
            { 'Mass', 'Flow Rate', 'Temperature', 'Pressure', 'Total Heat Capacity', 'Specific Heat Capacity', 'Conductivity', 'Power', 'Capacity', 'Resistance', 'Inductivity', 'Current', 'Voltage', 'Charge', '' } ...
        );
    end
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Logged values - path, name, ...
        % sObjectPath: path to the object starting first vsys. Shorthands
        %              will be replaced with real path. Expression will be
        %              executed on this object.
        % sExpression: can be attribute or method call. Will be prefixed
        %              with 'this.' if not present, afterwards all 'this.'
        %              strings will be replaced with the object path. This
        %              means that e.g. 'this.oMT.tiN2I.O2' can be used.
        % sName: if empty, will be generated from sExpression
        tLogValues = struct('sObjectPath', {}, 'sExpression', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {}, 'sObjUuid', {}, 'iIndex', {});%, 'iIndex', {});
        
        % Shortcut to the paths of variables to log
        csPaths;
        
        % Path to directory into which log files will be placed, if
        % bDumpToMat is set to true.
        sStorageDirectory;
        
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
    
    properties  (SetAccess = public, GetAccess = public)
        % Preallocation - how much rows should be preallocated for logging?
        iPrealloc = 10000;
        
        % Dump mfLog to .mat file when re-preallocating
        bDumpToMat = false;
        
    end
    
    methods
        function this = logger_basic(oSimulationInfrastructure)
            %this@simulation.monitor(oSimulationInfrastructure, struct('tick_post', 'logData', 'init_post', 'init'));
            this@simulation.monitor(oSimulationInfrastructure, { 'tick_post', 'init_post' });
            
            % Setting the storage directory for dumping
            fCreated = now();
            this.sStorageDirectory = [ datestr(fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') '_' oSimulationInfrastructure.sName ];
        end
        
        
        
        function tiLogIndices = add(this, xVsys, xHelper, varargin)
            % xVsys - if string, convert to full path and eval 
            %           (e.g. sys1/subsys1/subsubsys2)
            % xHelper - if string, check s2f('sim.helper.logger_basic.' 
            %           xHelper), if not present, check global
            %           s2f(xHelper)
            
            % varargin -> to helper, besides oVsys!
            
            % RETURN from helper --> should be struct --> add to tLogValues
            tEmptyLogProps = struct('sObjectPath', {}, 'sExpression', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {});
            
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
            tiLogIndices = struct();
            
            % Merge
            for iL = 1:length(tNewLogProps)
                iIndex = this.addValueToLog(tNewLogProps(iL));
                
                % Get from this.tLogValues, maybe sName was empty!
                tiLogIndices.(this.tLogValues(iIndex).sName) = iIndex;
            end
        end
        
        
        function iIdx = addValue(this, sObjectPath, sExpression, sUnit, sLabel, sName)
            % sObjPath and sExp have to be provided.
            % Unit, label will be guessed, name auto-added.
            
            tProp = struct('sObjectPath', [], 'sExpression', [], 'sName', [], 'sUnit', [], 'sLabel', []);
            
            tProp.sObjectPath = simulation.helper.paths.convertShorthandToFullPath(sObjectPath);
            tProp.sExpression = sExpression;
            
            if nargin >= 4 && ~isempty(sUnit),  tProp.sUnit  = sUnit;  end;
            if nargin >= 5 && ~isempty(sLabel), tProp.sLabel = sLabel; end;
            if nargin >= 6 && ~isempty(sName),  tProp.sName  = sName;  end;
            
            
            iIdx = this.addValueToLog(tProp);
        end
        
        
        
        
        
        function aiIdx = find(this, aiIdx, tFilter)
            % If aiIdx empty - get all!
            
            if nargin < 2 || isempty(aiIdx)
                aiIdx = 1:length(this.tLogValues);
            end
            
            %sPath = simulation.helper.paths.convertShorthandToFullPath(sPath);
            %iIdx  = find(strcmp({ this.tLogValues.sPath }, sPath), 1, 'first');
            
            if nargin >= 3 && ~isempty(tFilter) && isstruct(tFilter)
                csFilters = fieldnames(tFilter);
                
                for iF = 1:length(csFilters)
                    sFilter = csFilters{iF};
                    sValue  = tFilter.(sFilter);
                    
                    %{
                    abDelete = false(length(aiIdx), 1);
                    
                    for iI = length(aiIdx):-1:1
                        if ~strcmp(this.tLogValues(aiIdx(iI)).(sFilter), sValue)
                            %aiIdx(iI) = [];
                            abDelete(iI) = true;
                            
                            %iI = iI - 1;
                        end
                    end
                    %}
                    
                    abDelete = ~strcmp({ this.tLogValues(aiIdx).(sFilter) }', sValue);
                    
                    aiIdx(abDelete) = [];
                end
            end
        end
        
        
        
        
        function [ mxData, tConfig ] = get(this, aiIdx)
            % Need to truncate mfLog to iTick - preallocation!
            %iTick = this.oSimulationInfrastructure.oSimulationContainer.oTimer.iTick + 1;
            iTick = length(this.afTime);
            
            mxData  = this.mfLog(1:iTick, aiIdx);
            tConfig = this.tLogValues(aiIdx);
        end
    end
    
    
    methods (Access = protected)
        
        function iIndex = addValueToLog(this, tLogProp)
            %IMPORTANT NOTE: tLogProp definition HAS to be as in tLogProps
            
            oObj   = [];
            
            % Replace shorthand to full path (e.g. :s: to .toStores.) and
            % prefix so object is reachable through eval().
            tLogProp.sObjectPath = simulation.helper.paths.convertShorthandToFullPath(tLogProp.sObjectPath);
            
            try
                oObj = eval([ 'this.oSimulationInfrastructure.oSimulationContainer.toChildren.' tLogProp.sObjectPath ]);
                
                tLogProp.sObjUuid = oObj.sUUID;
            catch oErr
                assignin('base', 'oLastErr', oErr);
                this.throw('addValueToLog', 'Object does not seem to exist: %s (message was: %s)', tLogProp.sObjectPath, oErr.message);
            end
            
            
            % Only add property if not yet logged!
            aiObjMatches = find(strcmp({ this.tLogValues.sObjUuid }, tLogProp.sObjUuid));
            
            if any(aiObjMatches)
                aiExpressionMatches = find(strcmp({ this.tLogValues(aiObjMatches).sExpression }, tLogProp.sExpression));
                
                if any(aiExpressionMatches)
                    iIndex = this.tLogValues(aiObjMatches(aiExpressionMatches(1))).iIndex;
                    
                    return;
                end
            end
            
            
            if ~isfield(tLogProp, 'sName') || isempty(tLogProp.sName)
                % Only accept alphanumeric - can be used for storage e.g.
                % on a struct using sName as the key!
                %tLogProp.sName = [ oObj.sUUID '__' regexprep(tLogProp.sExpression, '[^a-zA-Z0-9]', '_') ];
                
                tLogProp.sName = [ regexprep(tLogProp.sExpression, '[^a-zA-Z0-9]', '_') '__' oObj.sUUID '_' ];
                tLogProp.sName = strrep(tLogProp.sName, 'this_', '');
                
                if length(tLogProp.sName) > 63
                    tLogProp.sName = tLogProp.sName(1:63);
                end
            end
            
            
            
            if ~isfield(tLogProp, 'sUnit') || isempty(tLogProp.sUnit)
                tLogProp.sUnit = '-';
                csKeys         = this.poExpressionToUnit.keys();
                
                
                for iI = 1:length(csKeys)
                    sKey   = csKeys{iI};
                    iLen   = length(sKey);
                    
                    if iLen > length(tLogProp.sExpression)
                        iLen = length(tLogProp.sExpression);
                    end
                    
                    if strcmp(sKey, tLogProp.sExpression(1:iLen))
                        tLogProp.sUnit = this.poExpressionToUnit(sKey);
                        
                        break;
                    end
                end
                
                %if .isKey(tLogProp.sExpression)
                %    this.sUnit = this.poExpressionToUnit(tLogProp.sExpression);
                %end
            end
            
            
            if ~isfield(tLogProp, 'sLabel') || isempty(tLogProp.sLabel)
                % Does object have 'sName'? If not, use path!
                try
                    tLogProp.sLabel = oObj.sName;
                    
                catch 
                    tLogProp.sLabel = tLogProp.sObjectPath;
                    
                end
                
                % Unit to Label? if not, expression!
                try
                    tLogProp.sLabel = [ tLogProp.sLabel ' - ' this.poUnitsToLabels(tLogProp.sUnit) ];
                    
                catch 
                    tLogProp.sLabel = tLogProp.sExpression;
                    
                end
            end
            
            
            
            % Add element to log struct array
            iIndex          = length(this.tLogValues) + 1;
            tLogProp.iIndex = iIndex;
            
            this.tLogValues(tLogProp.iIndex) = tLogProp;
        end
        
        
        
        function this = onInitPost(this, ~)
            % Indices to tLogValues (?, or on add?)
            % Eval Code!
            % Names / Paths to Cell for fast comp!
            %disp('LOG onInitPost');
            
            
            % Collect all paths of values to log
            this.csPaths = { this.tLogValues.sExpression };
            
            % Replace the root/container sys name by the path to get there
            %sLen = length(this.oSimulationInfrastructure.oSimulationContainer.sName) + 1;
            
            for iL = 1:length(this.csPaths)
                %this.csPaths{iL} = [ 'this.oSimulationInfrastructure.oSimulationContainer' this.csPaths{iL}(sLen:end) ];
                
                
                % Insert object path into expression
                if length(this.csPaths{iL}) < 5 || ~strcmp(this.csPaths{iL}(1:5), 'this.')
                    this.csPaths{iL} = [ 'this.' this.csPaths{iL} ];
                end
                
                
                this.csPaths{iL} = strrep(this.csPaths{iL}, ...
                    'this.', ...
                    [ 'this.oSimulationInfrastructure.oSimulationContainer.toChildren.' this.tLogValues(iL).sObjectPath '.' ] ...
                );
                
                %tLogProp.sExpression = strrep(tLogProp.sExpression, 'this.', [ tLogProp.sObjectPath '.' ]);
            end
            
            
            
            
            this.aiLog      = 1:length(this.csPaths);
            this.mfLog      = nan(this.iPrealloc, length(this.csPaths));
            this.iAllocated = this.iPrealloc;
            
            
            % Create pre-evald loggin' function!
            
            sCmd = '[ ';
                
            for iL = this.aiLog
                %sCmd = [ sCmd 'this.oRoot.' this.csLog{iL} ',' ];
                %sCmd = [ sCmd sprintf('this.oRoot.%s,\n', this.csLog{iL}) ];
                
                % sS((length(sN) + 1):end)
                sCmd = strcat( sCmd, this.csPaths{iL}, ',' );
            end

            sCmd = [ sCmd(1:(end - 1)) ' ]' ];

            try
                this.logDataEvald = eval([ '@() ' sCmd ]);
            catch
                this.throw('logger_basic','Something went wrong during logging. Please check your setup file.');
            end
        end
        
        
        function onTickPost(this, ~)
%             disp('LOG onTickPost');
%             disp(this.oSimulationInfrastructure.oSimulationContainer.oTimer.fTime);
            
            
            
            
            try
                this.mfLog(this.iLogIdx + 1, :) = this.logDataEvald();
            catch
                % One reason for the above statement to fail is an 'empty'
                % variable. Then the length of the array returned by
                % this.logDataEvald() will be shorter than this.mfLog and a
                % dimension mismatch error will be thrown. 
                % To prevent this from halting the simulation, we will find
                % the item that returns 'empty' and insert 'NaN' at its
                % index in the returned array. 
                
                % First we get the return array directly.
                afValues = this.logDataEvald();
                
                % Now we check it it is shorter than the width of mfLog
                if length(afValues) ~= length(this.mfLog(1,:))
                    % It is shorter, so one of the items must be returning
                    % empty. So now we go through the log items
                    % individually to find out which one it is. 
                    for iI = this.aiLog
                        if isempty(eval([ this.csPaths{iI} ';' ]))
                            % If this is the item that returns empty, we
                            % break the for loop and iI is the index of the
                            % item we are looking for. 
                            break;
                        end
                    end
                    
                    % Now we extend the results array by one...
                    afValues(iI+1:end+1) = afValues(iI:end);
                    % ... and insert NaN at the found index.
                    afValues(iI) = NaN;
                    
                    % Finally we can write the array into the log. 
                    this.mfLog(this.iLogIdx + 1,:) = afValues;
                else
                    % Something else must have gone wrong. Since we don't
                    % know where in anonymous log function the error
                    % happend, we go through logs one by one - one of them
                    % should throw an error!
                    for iL = this.aiLog
                        try
                            eval([ this.csPaths{iL} ';' ]);
                        catch oErr
                            this.throw('simulation','Error trying to log %s.\nError Message: %s\nPlease check your logging configuration in setup.m!', this.csPaths{iL}, oErr.message);
                        end
                    end
                end
            end
            
            
            this.afTime(this.iLogIdx + 1) = this.oSimulationInfrastructure.oSimulationContainer.oTimer.fTime;
            
            % Increase after actual logging in case of ctrl+c interruption!
            this.iLogIdx = this.iLogIdx + 1;
            
            
            if this.iLogIdx == this.iAllocated
                if this.bDumpToMat
                    % If periodic dumping of the results into a .mat file
                    % is activated and the dumping interval hast passed, we
                    % call the appropriate method here.
                    %WARNING: At this time (08.03.2016) the plotter_basic
                    %class does NOT support reading data from these .mat
                    %files. This functionality has to be re-implemeted.
                    this.dumpToMat();
                else
                    % If dumping is not implemented, we will expand the
                    % mfLog array by pre-allocating more memory. This makes
                    % writing into the log matrix faster. 
                    this.mfLog(this.iLogIdx + 1:(this.iLogIdx + this.iPrealloc), :) = nan(this.iPrealloc, length(this.tLogValues));
                    % Now we have to increase the iAllocated property so
                    % the next execution of this pre-allocation is
                    % iPrealloc Ticks in the future.
                    this.iAllocated = this.iAllocated + this.iPrealloc;
                end
            end
        end
        
        
        function dumpToMat(this)
            % First we check if the 
            if ~isdir([ 'data/runs/' this.sStorageDirectory ])
                mkdir([ 'data/runs/' this.sStorageDirectory ]);
            end
            
            sMat = sprintf('data/runs/%s/dump_%i.mat', this.sStorageDirectory, this.oSimulationInfrastructure.oSimulationContainer.oTimer.iTick + 1 );
            
            fprintf('#############################################\n');
            fprintf('DUMPING - write to .mat: %s\n', sMat);
            
            mfLogMatrix = this.mfLog; %#ok<NASGU>
            save(sMat, 'mfLogMatrix');
            
            disp('... done!');
            
            this.mfLog(:, :) = nan(this.iPrealloc, length(this.tLogValues));
            this.iLogIdx     = 0;
        end
    end
end
