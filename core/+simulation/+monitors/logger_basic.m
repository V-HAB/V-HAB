classdef logger_basic < simulation.monitor
    %LOGGER_BASIC Summary of this class goes here
    %   Detailed explanation goes here
    %
    %TODO see old master -> simulation.m ==> bDumpToMat!
    %       1) in regular intervals, dump mfLog data to .mat file
    %       2) provide readData method -> re-read data from .mat files
    %
    %   check if sim already running (set bSealed in onInitPost) -> not
    %   possible to add additional log values!
    %
    %   find(): besides aiIndex, allow passing in path(s) to different
    %       systems or other objects, and only properties logged for these are
    %       returned? [e.g. plot all [W] for HX 1, 2 and 3]
    
    properties (GetAccess = public, Constant = true)
        % Loops through keys, comparison only with length of key
        % -> 'longer' keys need to be defined first (fMass * fMassToPress)
        poExpressionToUnit = containers.Map(...
            { 'this.fMass * this.fMassToPressure', 'fMassToPressure', 'fMass', 'afMass', 'fFlowRate', 'fTemperature', 'fPressure', 'afPP', 'fTotalHeatCapacity', 'fSpecificHeatCapacity', 'fConductivity', 'fPower', 'fCapacity', 'fResistance', 'fInductivity', 'fCurrent', 'fVoltage', 'fCharge', 'fBatteryCharge' }, ...
            { 'Pa',                                'Pa/kg',           'kg',    'kg',     'kg/s',      'K',            'Pa',        'Pa',   'J/K',                'J/kgK',                 'W/K',           'W',      'F',         '?',           'H',            'A',        'V',        'C',       'Ah'             }  ...
        );
        
        poUnitsToLabels = containers.Map(...
            { 's',    'kg',   'kg/s',      'g/s',       'K',           '°C',          'Pa',       'J/K',                 'J/kgK',                  'W/K',          'W',     'F',        'Ohm',        'H',           'A',       'V',       'C',      'mol/kg',        'ppm',           '%',       'Ah',     '-'}, ...
            { 'Time', 'Mass', 'Flow Rate', 'Flow Rate', 'Temperature', 'Temperature', 'Pressure', 'Total Heat Capacity', 'Specific Heat Capacity', 'Conductivity', 'Power', 'Capacity', 'Resistance', 'Inductivity', 'Current', 'Voltage', 'Charge', 'Concentration', 'Concentration', 'Percent', 'Charge', '' } ...
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
        % sName:       if empty, will be generated from sExpression
        tLogValues = struct('sObjectPath', {}, 'sExpression', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {}, 'sObjUuid', {}, 'iIndex', {});%, 'iIndex', {});
        
        %QUESTION What are these derived values? Are they the same as the
        % virtual value?
        tDerivedLogValues = struct('sObjectPath', {}, 'sExpression', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {}, 'sObjUuid', {}, 'iIndex', {});%, 'iIndex', {});
        
        tVirtualValues = struct('sExpression', {}, 'calculationHandle', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {});
        
        
        % Shortcut to the paths of variables to log
        csPaths;
        
        % Path to directory into which log files will be placed, if
        % bDumpToMat is set to true.
        sStorageDirectory;
        
        % Sim time for each log point
        afTime;
        
        % Logged data
        mfDerivedLog;
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
        % Preallocation - how much data should be preallocated for logging?
        % iPrealloc = 10000;
        % CHANGED: in the past, that value refered to the numer of rows
        % that should be pre-allocated. Now, iPreallocData refers to the 
        % total fields that should be pre-allocated, i.e. rows * columns!
        % This way, the value can be translated into the amount of RAM or,
        % in case dump to mat is active, size of the .mat files for each
        % pre-allocation cycle.
        %
        % By default, set to 10k rows with 100 columns.
        iPreallocData = 1e4 * 100; %10000;
        % Old pre-alloc value - will be calculated based on amount of log
        % values!
        iPrealloc = [];
        
        
        
        % Dump mfLog to .mat file when re-preallocating
        bDumpToMat = false;
        
    end
    
    methods
        function this = logger_basic(oSimulationInfrastructure, bDumpToMat, iPreallocRows)
            % bDumpToMat -> each time preallocation happens, dump data to
            % .mat file instead and empty mfLog? After the simulation, the
            % data needs to be re-read with this.readDataFromMat()
            %   
            
            %this@simulation.monitor(oSimulationInfrastructure, struct('tick_post', 'logData', 'init_post', 'init'));
            this@simulation.monitor(oSimulationInfrastructure, { 'tick_post', 'init_post', 'finish' });
            
            % Setting the storage directory for dumping
            fCreated = now();
            this.sStorageDirectory = [ datestr(fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') '_' oSimulationInfrastructure.sName ];
            
            if nargin >= 2 && islogical(bDumpToMat)
                this.bDumpToMat = bDumpToMat;
            end
            
            if nargin >= 3 && isnumeric(iPreallocRows)
                this.iPreallocData = iPreallocRows * 100;
            end
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
            % sObjectPath and sExpression have to be provided.
            % Unit, label will be guessed, name auto-added.
            
            tProp = struct('sObjectPath', [], 'sExpression', [], 'sName', [], 'sUnit', [], 'sLabel', []);
            
            tProp.sObjectPath = simulation.helper.paths.convertShorthandToFullPath(sObjectPath);
            tProp.sExpression = sExpression;
            
            if nargin >= 4 && ~isempty(sUnit),  tProp.sUnit  = sUnit;  end
            if nargin >= 5 && ~isempty(sLabel), tProp.sLabel = sLabel; end
            if nargin >= 6 && ~isempty(sName),  tProp.sName  = sName;  end
            
            
            iIdx = this.addValueToLog(tProp);
        end
        
        
        function iIndex = addVirtualValue(this, sExpression, sUnit, sLabel, sName)
            %TODO-addVirtVal
            
            % Expression needs to be valid Matlab code. Log values can be
            % addressed using the name provided to addValue. Alternatively,
            % they can be addressed using their labels, however, the value
            % then has to be enclosed by " - e.g. '1 + "my label"'
            %
            % Important: the expression has to be 'vector' compatible, as
            % the calculation is done only ONCE for all ticks! This means,
            % if you want to divide value_a by value_b, DO NOT WRITE:
            %   'value_a / value_b'             <-- WRONG!
            % BUT INSTEAD:
            %   'value_a ./ value_b'
            % See the Matlab documentation for vector operations.
            %
            %
            % All kinds of auto-generation of label, name etc done in
            % addValue - not done here! Expression, unit and label are
            % REQUIRED values; if name omitted, generated from label.
            %
            %
            %NOTE virtual values themselves are not available in subsequent
            %     calls to addVirtualValue - this could be implemented, but
            %     a check would have to exist that calculates required virt
            %     values on the fly!
            
            
            % negative idx
            % store in separate tVirtProps
            % add sExpression as anonymous fct handle - names already
            % replaced with this.mfLog(:, XX)
            % in .get(), check for negative indices - calculate!
            
            csNames   = { this.tLogValues.sName };
            csLabels  = { this.tLogValues.sLabel };
            aiIndices = [ this.tLogValues.iIndex ];
            sParsed   = sExpression;
            
            for iN = 1:length(csNames)
                sParsed = strrep(sParsed, csNames{iN}, sprintf('mfLog(:, %i)', aiIndices(iN)));
                sParsed = strrep(sParsed, [ '"' csLabels{iN} '"' ], sprintf('mfLog(:, %i)', aiIndices(iN)));
            end
            
            
            funcHandle = [];
            
            try
                funcHandle = eval([ '@(mfLog) ' sParsed ]);
            catch oErr
                assignin('base', 'oLastErr', oErr);
                
                this.throw('addVirtualValue', 'Invalid expression. Original expression was: "%s", which was converted to: "%s"\nThere seems to be a Matlab error during eval: "%s"', sExpression, sParsed, oErr.message);
            end
            
            
            if nargin < 5 || isempty(sName)
                sName = regexprep(sLabel, '[^a-zA-Z0-9]', '_');
            end
            
            % Do not check for tLogValues names - they always take
            % precedence anyways
            if ~isempty(find(strcmp(sName, { this.tVirtualValues.sName }), 1, 'first')) 
                this.throw('addVirtualValue', 'The name "%s" is already in use!', sName);
            end
            
            
            
            this.tVirtualValues(end + 1) = struct(...
                'sExpression', sExpression, ...
                'calculationHandle', funcHandle, ...
                'sName', sName, ...
                'sUnit', sUnit, ...
                'sLabel', sLabel ...
            );
        
        
            iIndex = -1 * length(this.tVirtualValues);
        end
        
        
        function aiIndex = find(this, cxItems, tFilter)
            % This method returns an array of integers for the items that
            % are contained in the cxItems variable. This variable can
            % either be empty or a cell. The cell can contain either
            % integers representing the index of the item within the log
            % matrix, strings representing the lable of the item or strings
            % representing the name of the item. This method will detect
            % which one it is and extract the index accordingly. 
            % Using the tFilter input argument, the selection of items can
            % be reduced by providing a struct containing filter criteria.
            % These can be any values of the fields of the tLogValues
            % struct, however it is mostly used to filter by unit (key
            % 'sUnit') or a specific system or object (key 'sObjectPath').
            
            %% Getting Indexes
            
            % If cxItems is empty we'll just get all items in the log and
            % return them.
            if nargin < 2 || isempty(cxItems)
                aiIndex = 1:length(this.tLogValues);
                
            elseif iscell(cxItems)
                % If csItems is a cell, we now translate all of the items
                % in the cell to indexes that are then returned via
                % aiIndex.
                % This is done prior to the application of any filters,
                % because it represents a pre-selection, just as if an
                % array of integers had been passed in directly.
                
                % Initializing some variables
                iLength  = length(cxItems);
                aiIndex = nan(1, iLength);
                
                % Getting the names and lables of all items in the current
                % log object.
                csNames  = { this.tLogValues.sName };
                csLabels = { this.tLogValues.sLabel };
                
                % Getting the names and lables of all virtual items in the
                % current log object.
                csVirtualNames  = { this.tVirtualValues.sName };
                csVirtualLabels = { this.tVirtualValues.sLabel };
                
                
                % Now we'll loop through all of the items of cxItems and
                % translate them to integers representing their index in
                % the log array. 
                for iI = 1:iLength
                    % If the item is an integer, then we can just write it
                    % directly to aiIndex and continue on with the next
                    % item. 
                    if isnumeric(cxItems{iI})
                        aiIndex(iI) = cxItems{iI};
                        
                        continue;
                    end
                    
                    % Since the current item is a string, we now have to
                    % search through the four cells containing all of the
                    % names and lables of all items in the log until we
                    % find it. 
                    
                    % First, we'll try the cell with the item names
                    iIndex = find(strcmp(csNames, cxItems{iI}), 1, 'first');
                    
                    % If the previous search returned nothing, we'll try
                    % the virtual values.
                    if isempty(iIndex)
                        iIndex = -1 * find(strcmp(csVirtualNames, cxItems{iI}), 1, 'first');
                    end
                    
                    % If the previous search returned nothing, we'll try
                    % the labels.
                    if isempty(iIndex)
                        iIndex = find(strcmp(csLabels, cxItems{iI}(2:(end - 1))), 1, 'first');
                    end
                    
                    % If the previous search returned nothing, we'll try
                    % the virtual labels.
                    if isempty(iIndex)
                        iIndex = -1 * find(strcmp(csVirtualLabels, cxItems{iI}(2:(end - 1))), 1, 'first');
                    end
                    
                    
                    % If we still haven't found anything, there is no item
                    % in the log with this name or lable, so we abort and
                    % tell the user. 
                    if isempty(iIndex)
                        this.throw('find', 'Cannot find log value! String given: >>%s<< (if you were searching by label, pass in the label name enclosed by ", i.e. { ''"%s"'' })', cxItems{iI}, cxItems{iI});
                    end
                    
                    % We can now write the found index to the return
                    % variable. 
                    aiIndex(iI) = iIndex;
                end
            end
            
            % If there is nothing to be logged, we also tell the user and
            % return.
            if isempty(aiIndex)
                this.out(4, 1, 'Nothing found in log.');
                return;
            end
            
            %% Applying Filters
            
            % Now that we have our aiIndex array, we have to check if there
            % are any filters to be applied and if yes, do so. 
            if nargin >= 3 && ~isempty(tFilter) && isstruct(tFilter)
                % The field names of the tFilter variable must correspond
                % to field names in the tLogValues struct. 
                csFilters     = fieldnames(tFilter);
                
                % Initializing a boolean array that indicates which items
                % are to be deleted from aiIndex.
                abDeleteFinal = false(length(aiIndex), 1);
                
                % Now we loop through all of the filters to figure out,
                % which items to delete. 
                for iF = 1:length(csFilters)
                    % Initializing some local variables for the current
                    % filter. sFilter is the field name in the tLogValues
                    % struct and xsValue is the value that shall be
                    % filtered. This variable can be a string or a struct.
                    % An example would be a filter for units 'W' and 'K',
                    % so the resulting values would only be power and
                    % temperature values. 
                    sFilter = csFilters{iF};
                    xsValue = tFilter.(sFilter);
                    
                    % If xsValue is a cell, we have to extract all items in
                    % it and do a separate search for each of them. 
                    if iscell(xsValue)
                        % First we'll get the values from each item in the
                        % tLogValues struct in the according field.
                        csLogValues = { this.tLogValues(aiIndex).(sFilter) }';
                        
                        % Now we're creating a boolean array of false
                        % values with the same length.
                        abNoDelete  = false(length(csLogValues), 1);
                        
                        % Looping throuhg the different filter criteria.
                        for iV = 1:length(xsValue)
                            % Using the 'or' operator and a string
                            % comparison between the log values and the
                            % filter values, we can change the values in
                            % the boolean array to true that we want to
                            % filter. 
                            abNoDelete = abNoDelete | strcmp(csLogValues, xsValue{iV});
                        end
                        
                        % As this array will be used to delete items from
                        % the aiIndex array, we have to negate it. 
                        abDelete = ~abNoDelete;
                    else
                        % If there is only one value for this filter, we
                        % can write the negated string comparison directly
                        % to the abDelete boolean array.
                        abDelete = ~strcmp({ this.tLogValues(aiIndex).(sFilter) }', xsValue);
                    end
                    
                    % Now we use the 'or' operator again to update the
                    % abDeleteFinal boolean array with the values to be
                    % deleted for the current filter. 
                    abDeleteFinal = abDeleteFinal | abDelete;
                end
                
                % Finally, we remove all unwanted items from the aiIndex
                % array.
                aiIndex(abDeleteFinal) = [];
            end
        end
        
        
        
        
        function [ aafData, afTime, atConfiguration ] = get(this, aiIndexes, sIntervalMode, fIntervalValue)
            % This method gets the actual logged data from the mfLog
            % property in addition to the configuration data struct and
            % returns both in arrays. The aiIndex input parameters is an
            % array of integers representing the log item's indexes in the
            % mfLog matrix. 
            
            % First we need get the actual last tick of the simulation.
            % That is not logged anywhere and the only indication of how
            % log we have run is the length of the afTime property. We need
            % the last tick so we can truncate the mfLog data, because it
            % is preallocated, meaning there are most likely hundreds of
            % rows filled with NaNs at the end, that would mess up
            % everything.
            iTick = length(this.afTime);
            aafLogTmp = this.mfLog(1:iTick, :);
            
            % We now initialize our return array with NaNs
            aafData = nan(size(aafLogTmp, 1), length(aiIndexes));
            
            % Going through each of the indexes being queried and getting
            % the information
            for iI = 1:length(aiIndexes)
                % For easier reading we get the current index into a local
                % variable.
                iIndex = aiIndexes(iI);
                
                % If the index is smaller than zero, this indicates that we
                % are dealing with a virtual value; one that was not logged
                % directly, but calculated from other logged values. We
                % have to do some additional stuff here. 
                if iIndex < 0
                    % First we can get the configuration struct from the
                    % tVirtualValues property.
                    tConfiguration  = this.tVirtualValues(-1 * iIndex);
                    
                    % Now we have to preset some values in tConfiguration
                    % that are present in regularly logged values but not
                    % virtual ones. 
                    tConfiguration.sObjUuid    = [];
                    tConfiguration.sObjectPath = [];
                    tConfiguration.iIndex      = iIndex;
                    
                    
                    % Using the function handle stored with the virtual
                    % value we now perform the calculations that are to be
                    % made here. 
                    afData = tConfiguration.calculationHandle(aafLogTmp);
                    
                    % Finally, to be equal to a normally logged value, we
                    % remove field containing the function handle.
                    tConfiguration = rmfield(tConfiguration, 'calculationHandle');
                else
                    % The current index is not a virtual value so we can
                    % just copy the data from the log matrix and the
                    % tLogValues property.
                    afData = aafLogTmp(:, iIndex);
                    tConfiguration  = this.tLogValues(iIndex);
                end
                
                % Copying the data from the current index into the return
                % variable. 
                aafData(:, iI) = afData;
                
                % If this is the first loop iteration, we initialize the
                % return variable for the configuration data here. If it a
                % following iteration, we append the array. 
                if iI == 1
                    atConfiguration = tConfiguration;
                else
                    atConfiguration(iI) = tConfiguration;
                end
            end
            
            if nargin > 2
                abDeleteData = true(1,iTick);
                switch sIntervalMode
                    case 'Tick'
                        if fIntervalValue > 1
                            abDeleteData(1:fIntervalValue:iTick) = false;
                        else
                            abDeleteData = false(1,iTick);
                        end
                    case 'Time'
                        fTime = 0;
                        
                        for iI = 1:iTick
                            if this.afTime(iI) >= fTime
                                abDeleteData(iI) = false;
                                
                                fTime = fTime + fIntervalValue;
                            end
                        end
                        
                    otherwise
                        this.throw('get','The plotting interval mode you have provided (%s) is unknown. Can either be ''Tick'' or ''Time''.', sIntervalMode);
                end
                
                aafData(abDeleteData,:) = [];
                afTime = this.afTime(~abDeleteData);
            else
                afTime = this.afTime;
            end
        end
        
        function readDataFromMat(this)
            if ~this.bDumpToMat
                return;
            end
            
            % First read all dumps and parse tick number
            sDir    = [ 'data/runs/' this.sStorageDirectory '/' ];
            tDir    = dir(sDir);
            aiDumps = [];
            
            if isempty(tDir)
                fprintf('LOGGER: No dumped data files available, aborting.\n');
                return;
            end
            
            fprintf(['LOGGER: reading data from .mat files - NOTE: logger will probably fail if the simulation is continued using this oLastSimObj!\n', ...
                     'To avoid problems, delete the oLastSimObj and reload the object from the data/runs folder.\n']);
            
            
            % Cache current log values
            mfLogCached  = this.mfLog;
            afTimeCached = this.afTime;
            
            for iD = 1:length(tDir)
                if (length(tDir(iD).name) > 5) && strcmp(tDir(iD).name(1:5), 'dump_')
                    %disp([ sDir tDir(iD).name ]);
                    aiDumps(end + 1) = str2double(tDir(iD).name(6:(end - 4))); %#ok<AGROW>
                end
            end
            
            % Sort dumps by tick (just in case)
            aiDumps = sort(aiDumps);
            
            % Preallocate
            mfLogNew  = nan(this.iPrealloc * (length(aiDumps) + 1), length(this.tLogValues));
            afTimeNew = nan(1, this.iPrealloc * length(aiDumps));
            
            disp(size(mfLogNew));
            

            % Actually read the mat files
            for iF = 1:length(aiDumps) % length(aiDumps):-1:1
                fprintf('LOGGER: reading mat file dump_%i.mat ...', aiDumps(iF));
                
                tFile = load([ sDir 'dump_' num2str(aiDumps(iF)) '.mat' ]);
                
                iStartIdx = (iF - 1) * this.iPrealloc + 1;
                iEndIdx   = iStartIdx + this.iPrealloc - 1;
                
                fprintf(' and writing to index %i:%i\n', iStartIdx, iEndIdx);
                
                %this.mfLog = [ tFile.mfLog; this.mfLog ];
                mfLogNew(iStartIdx:iEndIdx, :) = tFile.mfLogMatrix;
                afTimeNew(iStartIdx:iEndIdx)   = tFile.afTimeVector;
            end
            
            
            % Append final data
            mfLogNew((iEndIdx + 1):end, :) = mfLogCached;
            
            % No preallocation for afTime - just as long as current log idx
            for iTime = 1:length(afTimeCached)
                afTimeNew(end + 1) = afTimeCached(iTime); %#ok<AGROW>
            end
            
            % Now we are all done and we can set all of the properties on
            % the logger.
            this.iAllocated = size(mfLogNew, 1);
            this.iLogIdx    = this.iLogIdx + this.iPrealloc * length(aiDumps); %size(this.mfLog, 1);
            this.mfLog      = mfLogNew;
            this.afTime     = afTimeNew;
        end
        
        function [ iNumberOfUnits, csUniqueUnits ] = getNumberOfUnits(this, aiIndexes)
            % This function determines the number of units in a single plot
            % and returns the value as an integer.
            
            % Initializing a cell that can hold all of the unit strings.
            csUnits = cell(length(aiIndexes),1);
            
            % Going through each of the indexes being queried and getting
            % the information
            for iI = 1:length(aiIndexes)
                % For easier reading we get the current index into a local
                % variable.
                iIndex = aiIndexes(iI);
                
                % If the index is smaller than zero, this indicates that we
                % are dealing with a virtual value; one that was not logged
                % directly, but calculated from other logged values. We
                % have to get the units from somewhere else then. 
                if iIndex < 0
                    csUnits{iI} = this.tVirtualValues(-1 * iIndex).sUnit;
                else
                    csUnits{iI}  = this.tLogValues(iIndex).sUnit;
                end
            end
            
            % Now we can just get the number of unique entries in the cell
            % and we have what we came for!
            csUniqueUnits  = unique(csUnits);
            iNumberOfUnits = length(csUniqueUnits);
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
                this.throw('addValueToLog', 'Object does not seem to exist: %s \n(message was: %s)', tLogProp.sObjectPath, oErr.message);
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
                
                try
                    [~] = eval(this.csPaths{iL});
                catch oError
                    this.throw('\n\nSomething went wrong while logging ''%s'' on ''%s''. \nMATLAB provided the following error message:\n%s\n', this.tLogValues(iL).sExpression, this.tLogValues(iL).sObjectPath, oError.message);
                end
            
                %tLogProp.sExpression = strrep(tLogProp.sExpression, 'this.', [ tLogProp.sObjectPath '.' ]);
            end
            
            
            % 
            this.iPrealloc  = floor(this.iPreallocData / length(this.csPaths));
            this.aiLog      = 1:length(this.csPaths);
            this.mfLog      = nan(this.iPrealloc, length(this.csPaths));
            this.iAllocated = this.iPrealloc;
            
            
            fprintf('LOGGER: allocating rows:%i\n', this.iPrealloc);
            
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
            catch oError
                this.throw('logger_basic','Something went wrong during logging. Please check your setup file.\nMessage: %s', oError.message);
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
                % NOTE: This only works if there is one 'empty' return
                % variable. If there are two or more, this check will still
                % return an error.
                
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
        
        
        function onFinish(this, ~)
            if this.bDumpToMat
                if ~isdir([ 'data/runs/' this.sStorageDirectory ])
                    mkdir([ 'data/runs/' this.sStorageDirectory ]);
                end
                
                sMat = sprintf('data/runs/%s/oLastSimObj.mat', this.sStorageDirectory);

                fprintf('DUMPING - write to .mat: %s\n', sMat);

                oLastSimObj = this.oSimulationInfrastructure; %#ok<NASGU>
                save(sMat, 'oLastSimObj');
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
            afTimeVector = this.afTime; %#ok<NASGU>
            save(sMat, 'mfLogMatrix', 'afTimeVector');
            
            disp('... done!');
            
            this.mfLog(:, :) = nan(this.iPrealloc, length(this.tLogValues));
            this.iLogIdx     = 0;
            this.afTime      = [];
            
            
            sMat = sprintf('data/runs/%s/oLastSimObj.mat', this.sStorageDirectory);
            
            fprintf('DUMPING - write to .mat: %s\n', sMat);
            
            oLastSimObj = this.oSimulationInfrastructure; %#ok<NASGU>
            save(sMat, 'oLastSimObj');
        end
        
        
    end
end
