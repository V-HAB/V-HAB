classdef logger < simulation.monitor
    %LOGGER Logs simulation results
    % This class provides the necessary structure to log values from the
    % simulation into a persistent log file. If values are not selected for
    % the log only the currently stored values from the current tick can be
    % accessed in the oLastSimObj
    
    % Pre-run configuration of log items
    %
    % addValueToLog() main method to add stuff to the log. Two ways to get
    % there: 1. addValue() to add one specific value or 2. add() to use a
    % helper. 
    % 
    % Also available: addVirtualValue(). Add calculations, conversions etc.
    % even after a simulation has run.
    %
    % After initialization do pre-allocation of logging variables in
    % onInitPost()
    %
    %
    % Stuff that happens during a simulation
    % 
    % Of course actual logging in onStepPost()
    %
    % bDumpToMat -> each time preallocation happens, dump data to .mat file
    % instead and empty mfLog? After the simulation, the data needs to be
    % re-read with this.readDataFromMat()
    %
    % Stuff for after a simulation
    % Needs to interface with plotter
    % 
    % get(), find(), getNumberOfUnits(), readDataFromMat(), onFinish()
    
            
    
    properties (GetAccess = public, Constant = true)
        % These properties enable automatic label generation for the plots.
        % They map specific expressions from the V-HAB simulation to
        % specific physical values and units. If you receive an error
        % pointing you here because the unit is missing from this property
        % you can either add the corresponding values or use a custom label
        % for your axis.
        %
        % The methods of this class loop through the keys and compare them
        % to the provided expressions. The comparison is by length of each
        % key so 'longer' keys need to be defined first 
        % (e.g. 'this.fMass * this.fMassToPressure').
        poExpressionToUnit = containers.Map(... 
            { 'this.fMass * this.fMassToPressure', 'fMassToPressure', 'fMass', 'afMass', 'fFlowRate', 'fTemperature', 'fPressure', 'afPP', 'fTotalHeatCapacity', 'fSpecificHeatCapacity', 'fConductivity', 'fPower', 'fCapacity', 'fResistance', 'fInductivity', 'fCurrent', 'fVoltage', 'fCharge', 'fBatteryCharge'}, ...
            { 'Pa',                                'Pa/kg',           'kg',    'kg',     'kg/s',      'K',            'Pa',        'Pa',   'J/K',                'J/kgK',                 'W/K',           'W',      'F',         '?',           'H',            'A',        'V',        'C',       'Ah'            }  ...
        );
        
        poUnitsToLabels = containers.Map(...
            { 's',    'kg',   'kg/s',      'g/s',       'L/min',     'K',           '°C',          'Pa',       'J/K',                 'J/kgK',                  'W/K',          'W',     'F',        'Ohm',        'H',           'A',       'V',       'C',      'mol/kg',        'ppm',           '%',       'Ah',     'kg/m^3',   'm/s',       'torr',     '-', 'J/kg',      'm^3'}, ...
            { 'Time', 'Mass', 'Flow Rate', 'Flow Rate', 'Flow Rate', 'Temperature', 'Temperature', 'Pressure', 'Total Heat Capacity', 'Specific Heat Capacity', 'Conductivity', 'Power', 'Capacity', 'Resistance', 'Inductivity', 'Current', 'Voltage', 'Charge', 'Concentration', 'Concentration', 'Percent', 'Charge', 'Density',   'Velocity', 'Pressure', '' , 'Enthalpy',  'Volume' } ...
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
        
        tVirtualValues = struct('sExpression', {}, 'calculationHandle', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {});
        
        
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
        % Preallocation - how much data should be preallocated for logging?
        % iPrealloc = 10000;
        % iPreallocData refers to the total fields that should be
        % pre-allocated, i.e. rows * columns! This way, the value can be
        % translated into the amount of RAM or, in case dump to mat is
        % active, size of the .mat files for each pre-allocation cycle.
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
        function this = logger(oSimulationInfrastructure, bDumpToMat, iPreallocRows)
            this@simulation.monitor(oSimulationInfrastructure, { 'step_post', 'init_post', 'finish' });
            
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
        
        function iIdx = addValue(this, sObjectPath, sExpression, sUnit, sLabel, sName)
            % This method adds a user-defined item to the log. The item 
            % will then be logged every tick of the simulation. The method
            % returns the index of the added item in the tLogValues struct
            % array property of this class. 
            %
            % addValue() requires the following input arguments:
            % - sObjectPath     The path to the simulation object as a
            %                   string. The string can also be in shorthand
            %                   form (e.g use :s: instead of .toStores.).
            % - sExpression     In the simplest form, this can just be the
            %                   name of the item to be logged, so the
            %                   property of an object, like 'fMass' for
            %                   instance. It can also be a mathematical
            %                   operation on two properties of the same
            %                   object, in that case however, the property
            %                   names need to be prefixed with 'this.' due
            %                   to the way V-HAB then processes these
            %                   operations. (e.g. fMass * fMassToPressure).
            % 
            % addValue() accepts the following optional input arguments. If
            % not given by the user, these values will either be guessed or
            % automatically generated by the logger. 
            % - sUnit           Unit of the log item as a string
            % - sLabel          Label of the item as a string, this will be 
            %                   used in user-facing dialogs and in the
            %                   legend and axis labels of the plot
            %                   containing the item. It can contain spaces,
            %                   special characters, etc.
            % - sName           Name of the item as astring. This is used
            %                   internally to reference the log item and
            %                   must therfore be compatible with things
            %                   like struct field names. This means it
            %                   cannot contain spaces or special
            %                   characters. If it does, then it will be
            %                   automatically cleaned. 
            
            tProp = struct('sObjectPath', [], 'sExpression', [], 'sName', [], 'sUnit', [], 'sLabel', []);
            
            tProp.sObjectPath = simulation.helper.paths.convertShorthandToFullPath(sObjectPath);
            tProp.sExpression = sExpression;
            
            if nargin >= 4 && ~isempty(sUnit),  tProp.sUnit  = sUnit;  end
            if nargin >= 5 && ~isempty(sLabel), tProp.sLabel = sLabel; end
            if nargin >= 6 && ~isempty(sName),  tProp.sName  = sName;  end
            
            
            iIdx = this.addValueToLog(tProp);
        end
        
        function ciLogIndexes = add(this, xObject, xHelper, varargin)
            % This method can be used to add multiple items to the log
            % using helpers. It returns a struct array with the log item's
            % names as field names and their indexes in the tLogValues
            % struct array as values. 
            %
            % add() requires the following input arguments:
            % - xObject     A reference to a simulation object (e.g. vsys,
            %               phase, store, branch, etc.). xObject can be
            %               passed in either as a path string (e.g.
            %               sys1/subsys1/subsubsys2), or the object
            %               reference itself.
            % - xHelper     A reference to the helper class. Can ether be a
            %               string or a function handle. 
            %
            % Any additional arguments that are provided beyond these two
            % are passed on to the helper class. 
            
            
            % RETURN from helper --> should be struct --> add to tLogValues
            tEmptyLogProps = struct('sObjectPath', {}, 'sExpression', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {});
            
            % The object can be provided directly, or as a string
            % containing the path to the object can be passed in.
            if ischar(xObject)
                % If the string is in shorthand, we convert it to the full
                % path first.
                sObject = simulation.helper.paths.convertShorthandToFullPath(xObject);
                
                % Now we get the reference to the actual object.
                oObject = eval([ 'this.oSimulationInfrastructure.oSimulationContainer.toChildren.' sObject ]);
            else
                % The object was passed in directly, so we can use it. 
                oObject = xObject;
            end
            
            % Helper can be function handle, or name of the function.
            if ischar(xHelper)
                if ~isempty(which([ 'simulation.helper.logger.' xHelper ]))
                    hHelper = str2func([ 'simulation.helper.logger.' xHelper ]);
                    
                elseif ~isempty(which(xHelper))
                    hHelper = str2func(xHelper);
                    
                else
                    this.throw('add', 'Helper "%s" not found!', xHelper);
                end
            end
            
            tNewLogProps = hHelper(tEmptyLogProps, oObject, varargin{:});
            
            iNumberOfItems = length(tNewLogProps);
            ciLogIndexes = cell(iNumberOfItems,1);
            
            for iLogItem = 1:iNumberOfItems
                ciLogIndexes{iLogItem} = this.addValueToLog(tNewLogProps(iLogItem));
            end
        end
        
        function iIndex = addVirtualValue(this, sExpression, sUnit, sLabel, sName)
            % This method allows users to add virtual values to the log,
            % even after a simulation has completed. Virtual values are not
            % actual properties of simulation objects, but values
            % calculated from them. This can be used, for example, to
            % perform unit conversions and other types of mathematical
            % operations. 
            %
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
            %     a check would have to exist that calculates required
            %     virtual values on the fly!
            
            
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
            
            % Creating a struct with all of the information of the log
            % item.
            tLogItem = struct(...
                              'sExpression', sExpression, ...
                              'calculationHandle', funcHandle, ...
                              'sName', sName, ...
                              'sUnit', sUnit, ...
                              'sLabel', sLabel ...
                              );
                          
            % We need to check the tLogValues field names so we don't have
            % a conflict. BUT, since this method can also be called during
            % post-processing, if this is just a repeat call to add the
            % same value to the log, we can skip the error. 
            iFoundIndex = find(strcmp(sName, { this.tVirtualValues.sName }), 1, 'first');
            if ~isempty(iFoundIndex)
                % So at least the same name is used here. Now we have to
                % find out, if the new and old log items are the same.
                % Unfortunately, MATLAB cannot compare anonymous function
                % handles, so before we can make the comparison, we have to
                % convert the function handles in both structs to strings. 
                tNewLogItem = tLogItem;
                tNewLogItem.calculationHandle = func2str(tNewLogItem.calculationHandle);
                tOldLogItem = this.tVirtualValues(iFoundIndex);
                tOldLogItem.calculationHandle = func2str(tOldLogItem.calculationHandle);
                % Now we can finally compare the new and existing log
                % items. 
                if isequal(tNewLogItem, tOldLogItem)
                    % They are equal, so we just set the index to the one
                    % we found and return it. 
                    iIndex = -1 * iFoundIndex;
                    return;
                end
                
                % The values to be logged are not equal to existing ones,
                % so someone is actually trying to add a new log item with
                % a name that is already in use. That's not possible, so we
                % fail here and let the user know why. 
                this.throw('addVirtualValue', 'The name "%s" is already in use!', sName);
            end
            
            
            % Everything checks out now, so we can add the new log item to
            % the end of the tVirtualValues struct.
            this.tVirtualValues(end + 1) = tLogItem;
        
            % Returning the negative index. 
            iIndex = -1 * length(this.tVirtualValues);
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
                fprintf('[Logger] No dumped data files available, aborting.\n');
                return;
            end
            
            fprintf(['[Logger] reading data from .mat files - NOTE: logger will probably fail if the simulation is continued using this oLastSimObj!\n', ...
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
                fprintf('[Logger] reading mat file dump_%i.mat ...', aiDumps(iF));
                
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
            end
            
            this.iPrealloc  = floor(this.iPreallocData / length(this.csPaths));
            this.aiLog      = 1:length(this.csPaths);
            this.mfLog      = nan(this.iPrealloc, length(this.csPaths));
            this.iAllocated = this.iPrealloc;
            
            
            fprintf('[Logger] Allocating %i rows\n', this.iPrealloc);
            
            % Create pre-evald loggin' function!
            
            sCmd = '[ ';
                
            for iL = this.aiLog
                sCmd = strcat( sCmd, this.csPaths{iL}, ',' );
            end

            sCmd = [ sCmd(1:(end - 1)) ' ]' ];

            try
                this.logDataEvald = eval([ '@() ' sCmd ]);
            catch oError
                this.throw('logger','Something went wrong during logging. Please check your setup file.\nMessage: %s', oError.message);
            end
        end
        
        
        function onStepPost(this, ~)
            
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
                if ~isfolder([ 'data/runs/' this.sStorageDirectory ])
                    mkdir([ 'data/runs/' this.sStorageDirectory ]);
                end
                
                sMat = sprintf('data/runs/%s/oLastSimObj.mat', this.sStorageDirectory);

                fprintf('DUMPING - write to .mat: %s\n', sMat);

                oLastSimObj = this.oSimulationInfrastructure; 
                save(sMat, 'oLastSimObj');
            end
            
            
        end
        
        
        function dumpToMat(this)
            % First we check if the 
            if ~isfolder([ 'data/runs/' this.sStorageDirectory ])
                mkdir([ 'data/runs/' this.sStorageDirectory ]);
            end
            
            sMat = sprintf('data/runs/%s/dump_%i.mat', this.sStorageDirectory, this.oSimulationInfrastructure.oSimulationContainer.oTimer.iTick + 1 );
            
            fprintf('#############################################\n');
            fprintf('DUMPING - write to .mat: %s\n', sMat);
            
            mfLogMatrix = this.mfLog; 
            afTimeVector = this.afTime; 
            save(sMat, 'mfLogMatrix', 'afTimeVector');
            
            disp('... done!');
            
            this.mfLog(:, :) = nan(this.iPrealloc, length(this.tLogValues));
            this.iLogIdx     = 0;
            this.afTime      = [];
            
            
            sMat = sprintf('data/runs/%s/oLastSimObj.mat', this.sStorageDirectory);
            
            fprintf('DUMPING - write to .mat: %s\n', sMat);
            
            oLastSimObj = this.oSimulationInfrastructure;
            save(sMat, 'oLastSimObj');
        end
        
    end
end
