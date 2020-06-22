classdef logger < simulation.monitor
    %LOGGER Logs simulation results
    % This class provides the necessary infrastructure to log values from
    % the simulation into a persistent log file.
    %
    % There are three groups of methods this class provides: Methods for
    % 1. the pre-run configuration of log items
    % 2. the activities that happen during a simulation
    % 3. post-run actions for clean-up and saving
    %
    % These groups are discussed in greater detail in the following.
    %
    % %%% PRE-RUN %%%
    %
    % The main method that is used to add values to the log is called
    % addValueToLog(). Since it is fairly complex and long it can be found
    % in a separate function file. It is, however, not intended to be used
    % directly, but is rather a backend for two other methods: addValue()
    % to add one specific value or add() to use a helper function to add
    % multiple items with just one function call. See the individual
    % function descriptions below for more information. Another function
    % that is available to add items to the log is addVirtualValue(). This
    % method can be used to add calculations, conversions etc. In contrast
    % to add() and addValue(), addVirtualValue() can be used even after a
    % simulation has run, because it uses existing log values to produce
    % its results and does not gather additional data during a simulation
    % run.
    % After initialization of the simulation is complete, the onInitPost()
    % method performs the pre-allocation of logging variables.
    %
    % %%% DURING RUN %%%
    % 
    % The actual logging of simulation data is performed in onStepPost().
    % This method may call the dumpToMat() method to save a chuck of
    % simulation data in a mat file. This is desired to keep the memory
    % usage during a simulation low and because it constitutes a save point
    % within the simulation from which a run can be continued, should the
    % simulation have to be aborted or it crashed. 
    %
    % %%% POST-RUN %%%
    % 
    % When a simulation is completed the onFinish() method is called that
    % saves the simulation object into a mat file as well, but only if the
    % bDumpToMat property is set to true. 
    % The get() and find() methods are interfaces to any plotting classes
    % that need to retrieve specific data from the log. 
    % If the dumpToMat() method was active during a simulation run, the
    % readFromMat() method can be used to re-load the dumped data back
    % into the simulation object. 
    
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
            { 'this.fMass * this.fMassToPressure', 'fMassToPressure', 'fMass', 'afMass', 'fFlowRate', 'fDensity', 'fTemperature', 'fPressure', 'afPP', 'fTotalHeatCapacity', 'fSpecificHeatCapacity', 'fConductivity', 'fHeatFlow', 'fPower', 'fCapacity', 'fResistance', 'fInductivity', 'fCurrent', 'fVoltage', 'fCharge', 'fBatteryCharge', 'fArea', 'fFrequency'}, ...
            { 'Pa',                                'Pa/kg',           'kg',    'kg',     'kg/s',      'kg/m^3',   'K',            'Pa',        'Pa',   'J/K',                'J/kgK',                 'W/K',           'W',         'W',      'F',         'Ohm',         'H',            'A',        'V',        'C',       'Ah',             'm^2',   'Hz'        }  ...
        );
        
        poUnitsToLabels = containers.Map(...
            { 's',    'kg',   'kg/s',      'g/s',       'L/min',     'K',           'degC',        'Pa',       'J/K',                 'J/kgK',                  'W/K',          'W',          'F',        'Ohm',        'H',           'A',       'V',       'C',      'mol/kg',        'ppm',           '%',       'Ah',     'kg/m^3',   'm/s',       'torr',     '-', 'J/kg',      'm^3',    'm^2',   'm^3/s',                'munits/L',         	'ng/L', 		'Hz',           'mol/m^3'}, ...
            { 'Time', 'Mass', 'Flow Rate', 'Flow Rate', 'Flow Rate', 'Temperature', 'Temperature', 'Pressure', 'Total Heat Capacity', 'Specific Heat Capacity', 'Conductivity', 'Heat Flow',  'Capacity', 'Resistance', 'Inductivity', 'Current', 'Voltage', 'Charge', 'Concentration', 'Concentration', 'Percent', 'Charge', 'Density',   'Velocity', 'Pressure', '' , 'Enthalpy',  'Volume', 'Area',  'Volumetric Flowrate',  'Concentration',	'Concentration',	'Frequency',    'Concentration'} ...
        );
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % The tLogValues property is a struc that contains all values that
        % this logger is supposed to log during a simulation. It contains
        % the following fields:
        %
        % sObjectPath: Path to the object starting with the first vsys.
        %              Shorthands will be replaced with the full path. The
        %              expression will be executed on this object.
        % sExpression: Can be an attribute or a method call of the object
        %              provided in sObjectPath. The string will be prefixed
        %              with the object path, so an object's property can be
        %              used directly (e.g. 'fMass'). The expression can
        %              also be a calculation between two or more separate
        %              values. In this case the notation must be the same
        %              that would be used inside of the object itself (e.g.
        %              'this.fMass * this.fMassToPressure'). In this case
        %              all 'this.' strings will be replaced with the object
        %              path.
        % sName:       A name associated with this log value. Does not have
        %              to be unique. If it is left empty, it will be 
        %              generated from sExpression
        % sUnit:       The unit of the log value. If left empty, the logger
        %              will try to derive the unit from the expression. If
        %              the logger fails to do so, the default unit is '-'.
        % sLabel:      A label that will be used for the y-axis during
        %              plotting. (The x-axis is time by default.)
        % sObjUuid:    The unique identifier for the object.
        % iIndex:      The index within the logging struct for this
        %              particular item. 
        tLogValues = struct('sObjectPath', {}, 'sExpression', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {}, 'sObjUuid', {}, 'iIndex', {});
        
        % The tVirtualValues property is similar to the tLogValues
        % property. It does not contain properties of simulation objects,
        % but rather calculated values. This means that they do not have to
        % be added prior to a simulation run, but also afterwards within
        % the plotting method. 
        % The fields all have the same function as they do for the
        % tLogValues property, so for further explanation, please see
        % above. The calculationHandle() field contains a function handle
        % that is used during plotting to calculate the virtual value. 
        tVirtualValues = struct('sExpression', {}, 'calculationHandle', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {});
        
        % Shortcut to the paths of variables to log, basically a
        % combination of the object path and expression from above. 
        csPaths;
        
        % Path to directory into which log files will be placed, if
        % bDumpToMat is set to true.
        sStorageDirectory;
        
        % Simulated time stamp for each log point
        afTime;
        
        % A matrix in which the actual logged data is stored. 
        mfLog;
        
        % The total number of items currently being logged
        iNumberOfLogItems;
        
        % Current index in the mfLog. This is required because mfLog will
        % be pre-allocated, meaning we can't just use 'end+1'
        iLogIndex = 0;
        
        % The number of rows in mfLog that are currently pre-allocated.
        % This number will increase by the value of iPreAllocatedRows if
        % the current log index reaches the value of iAllocated AND
        % pDumpToMat is false. If pDumpToMat is true, the log index will be
        % reset everytime it reaches iAllocated.
        iAllocated = 0;
        
        % The number of rows that are pre-allocated in mfLog, both
        % initially as well as in each chunk of data that will be dumped
        % into a mat file if bDumpToMat is true. 
        % This default value of ten thousand rows is based on experience
        % that 10k rows with 100 log items each is a good size, both for
        % keeping in memory as well as for saving to a file. If the user
        % does not provide a value for this property in the constructor, it
        % will be re-sized to retain the overall number of log entries
        % depending on the number of data points per tick the user will
        % record. See onInitPost() for more details.
        iPreAllocatedRows = 1e4;
        
        % A boolean variable indicating if the user provided a custom value
        % for iPreAllocatedRows to the constructor. We need a property for
        % that because the actual calculations will be performed in
        % onInitPost().
        bPreAllocationProvided;
        
        % A boolean variable indicating if the log data should be dumped
        % into a mat file periodically. This is desirable for two reasons:
        % 1. It keeps the memory footprint of a simulation small, because
        % not all of the logged data needs to be retained in one large
        % variable. 
        % 2. In case a simulation aborts it can be picked up from the
        % moment of the last dump, which may save significant time. 
        % For short, testing simulations this is not required. 
        bDumpToMat = false;
        
        % A function handle that will return ALL data from ALL objects for
        % the current tick. 
        hEvaluateLogData;
    end
    
    methods
        function this = logger(oSimulationInfrastructure, bDumpToMat, iPreallocatedRows)
            % Calling the parent constructor
            this@simulation.monitor(oSimulationInfrastructure, { 'step_post', 'init_post', 'finish' });
            
            % Setting the storage directory for dumping. We create this
            % file path dynamically and based on the current date and time
            % so we don't run the risk of accidentally overwriting our
            % previous simulation results.
            fCreated = now();
            this.sStorageDirectory = [ datestr(fCreated, 'yyyy-mm-dd_HH-MM-SS_FFF') '_' oSimulationInfrastructure.sName ];
            
            % Setting the bDumpToMat property, if it was provided. 
            if nargin >= 2 && islogical(bDumpToMat)
                this.bDumpToMat = bDumpToMat;
            end
            
            % Setting the iPreAllocatedRows property, if it was provided.
            % We also need to capture here if the user provided anything at
            % all, so we also set the bPreAllocationProvided property.
            if nargin >= 3 && isnumeric(iPreallocatedRows)
                this.iPreAllocatedRows = iPreallocatedRows;
                this.bPreAllocationProvided = true;
            else
                this.bPreAllocationProvided = false;
            end
        end
        
        function iIdx = addValue(this, sObjectPath, sExpression, sUnit, sLabel, sName)
            %ADDVALUE Adds a user-defined item to the log 
            % To be more specific, it populates a prop that is then passed
            % on to the addValueToLog() method of this class. But this is
            % the most common way to add a value to the log. 
            % The provided item will then be logged every tick of the
            % simulation. The method returns the index of the added item in
            % the tLogValues struct array property of this class.
            %
            % addValue() requires the following input arguments:
            % sObjectPath: Path to the object starting with the first vsys.
            %              Shorthands will be replaced with the full path.
            %              The expression will be executed on this object.
            % sExpression: Can be an attribute or a method call of the 
            %              object provided in sObjectPath. The string will
            %              be prefixed with the object path, so an object's
            %              property can be used directly (e.g. 'fMass').
            %              The expression can also be a calculation between
            %              two or more separate values. In this case the
            %              notation must be the same that would be used
            %              inside of the object itself (e.g. 'this.fMass *
            %              this.fMassToPressure'). In this case all 'this.'
            %              strings will be replaced with the object path.
            % 
            % addValue() accepts the following optional input arguments. If
            % not given by the user, these values will either be guessed or
            % automatically generated by the logger. 
            % sName:       A name associated with this log value. Does not 
            %              have to be unique. If it is left empty, it will
            %              be generated from sExpression
            % sUnit:       The unit of the log value. If left empty, the 
            %              logger will try to derive the unit from the
            %              expression. If the logger fails to do so, the
            %              default unit is '-'.
            % sLabel:      A label that will be used for the y-axis and 
            %              other user-facing dialogs during plotting. (The
            %              x-axis is time by default.)
            
            % First we initialize the empty struct will all of the required
            % fields.
            tProp = struct('sObjectPath', [], 'sExpression', [], 'sName', [], 'sUnit', [], 'sLabel', []);
            
            % Getting the object path via a helper
            tProp.sObjectPath = simulation.helper.paths.convertShorthandToFullPath(sObjectPath);
            
            % The expression can be directly used. 
            tProp.sExpression = sExpression;
            
            % Populating the optional fields, if they were provided.
            if nargin >= 4 && ~isempty(sUnit),  tProp.sUnit  = sUnit;  end
            if nargin >= 5 && ~isempty(sLabel), tProp.sLabel = sLabel; end
            if nargin >= 6 && ~isempty(sName),  tProp.sName  = sName;  end
            
            % Passing the struct on to the main method and returning the
            % log item's index.
            iIdx = this.addValueToLog(tProp);
        end
        
        function ciLogIndexes = add(this, xObject, xHelper, varargin)
            %ADD Adds multiple values to the log via a helper
            % This method can be used to add multiple items to the log
            % using helpers. It returns a cell with the log item's indexes
            % in the tLogValues struct array property as values.
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
            % are passed on to the helper class using varargin.
            
            
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
            
            % xHelper can be a function handle, or a string containing the
            % name of the function. In the latter case, it can be just the
            % name of the function or its path. We catch both cases here
            % and throw an error if neither works. 
            if ischar(xHelper)
                if ~isempty(which([ 'simulation.helper.logger.' xHelper ]))
                    hHelper = str2func([ 'simulation.helper.logger.' xHelper ]);
                elseif ~isempty(which(xHelper))
                    hHelper = str2func(xHelper);
                else
                    this.throw('add', 'Helper "%s" not found!', xHelper);
                end
            end
            
            % Initializing the template struct that the helper needs to
            % fill with the information on each log item. 
            tEmptyLogProps = struct('sObjectPath', {}, 'sExpression', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {});
            
            % Actually running the helper function.
            tNewLogProps = hHelper(tEmptyLogProps, oObject, varargin{:});
            
            % Calculating the number of items that are to be added
            iNumberOfItems = length(tNewLogProps);
            
            % Initializing the return variable
            ciLogIndexes = cell(iNumberOfItems,1);
            
            % Looping through all log items in tNewLogProps and adding them
            % to the log. 
            for iLogItem = 1:iNumberOfItems
                ciLogIndexes{iLogItem} = this.addValueToLog(tNewLogProps(iLogItem));
            end
        end
        
        function iIndex = addVirtualValue(this, sExpression, sUnit, sLabel, sName)
            %ADDVIRTUALVALUE Adds a virtual (calculated) value to the log
            % This method allows users to add virtual values to the log,
            % even after a simulation has completed. Virtual values are not
            % actual properties of simulation objects, but values
            % calculated from them. This can be used, for example, to
            % perform unit conversions and other types of mathematical
            % operations. 
            %
            % Expression needs to be valid MATLAB code. The non-virtual log
            % values that are used within the expressions can be addressed
            % using the name provided to addValue. Alternatively, they can
            % be addressed using their labels, however, the value then has
            % to be enclosed by quotes ('"') (e.g. '1 + "my label"').
            %
            % IMPORTANT: the expression has to be 'vector' compatible, as
            % the calculation is done only ONCE for all ticks! This means,
            % if you want to divide value_a by value_b, DO NOT WRITE:
            %
            %   'value_a / value_b'             <-- WRONG!
            %
            % BUT INSTEAD:
            %
            %   'value_a ./ value_b'            <-- CORRECT!
            %
            % See the Matlab documentation for vector operations.
            %
            % The expression is converted to an anonymous function handle
            % and saved along with the other information on each log item. 
            %
            % All kinds of auto-generation of label, name etc. done in
            % addValue - not done here! Expression, unit and label are
            % REQUIRED values; if the name is omitted it is generated from
            % the label.
            %
            % The virtual log items are stored in the tVirtualValues struct
            % property. The index that this method returns is the negative
            % of the actual index in the struct array. This is done to
            % differentiate virtual values from "real" ones, especially in
            % the get() method of this class. Here the negative index tells
            % the method to perform a calculation rather than just extract
            % values from the log. 
            %
            % NOTE: virtual values themselves are not available in
            %       subsequent calls to addVirtualValue - this could be
            %       implemented, but a check would have to exist that
            %       calculates required virtual values on the fly!
            
            
            % negative idx
            % store in separate tVirtProps
            % add sExpression as anonymous fct handle - names already
            % replaced with this.mfLog(:, XX)
            % in .get(), check for negative indices - calculate!
            
            % The expression can contain the names or labels of
            % the non-virtual log items. We need to replace these with
            % references to their actual locations (columns) in the mfLog
            % data matrix. So we first need to extract the names, labels
            % and indexes from all non-virtual log items.
            csNames   = { this.tLogValues.sName };
            csLabels  = { this.tLogValues.sLabel };
            aiIndexes = [ this.tLogValues.iIndex ];
            
            % Creating a new local variable that we will now modify by
            % replacing parts of the original expression.
            sParsed = sExpression;
            
            % Looping through all non-virtual log items
            for iN = 1:length(csNames)
                % Replacing the names with index references
                sParsed = strrep(sParsed, csNames{iN}, sprintf('mfLog(:, %i)', aiIndexes(iN)));
                
                % Replacing the labels with index references. 
                sParsed = strrep(sParsed, [ '"' csLabels{iN} '"' ], sprintf('mfLog(:, %i)', aiIndexes(iN)));
            end
            
            % Now we need to create an anonymous function handle that can
            % be used during plotting to create the virtual data. We try to
            % get the handle via the evaluate method and let the user know
            % if something went wrong. 
            try
                hFunctionHandle = eval([ '@(mfLog) ' sParsed ]);
            catch oError
                assignin('base', 'oLastErr', oError);
                this.throw('addVirtualValue', 'Invalid expression. Original expression was: "%s", which was converted to: "%s"\nThere seems to be a Matlab error during eval: "%s"', sExpression, sParsed, oError.message);
            end
            
            % In case the user did not provide a name we derive one from
            % the label by replacing all of the non-alphanumeric characters
            % with underscores. 
            if nargin < 5 || isempty(sName)
                sName = regexprep(sLabel, '[^a-zA-Z0-9]', '_');
            end
            
            % Creating a struct with all of the information of the log
            % item.
            tLogItem = struct(...
                              'sExpression', sExpression, ...
                              'calculationHandle', hFunctionHandle, ...
                              'sName', sName, ...
                              'sUnit', sUnit, ...
                              'sLabel', sLabel ...
                              );
                          
            % We need to check the tLogValues field names so we don't have
            % a conflict. BUT, since this method can also be called
            % multiple times during post-processing, if this is just a
            % repeat call to add the same value to the log, we can skip the
            % error.
            % So the first thing we do is to look for the item with the
            % same name in the tVirtualValues struct. 
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
        
        function readFromMat(this)
            %READFROMMAT Re-loads simulation data that was dumped
            % The dumpToMat() method of this class creates a number of mat
            % files that contain the contents of the mfLog and atTime
            % properties of this object for chunks of time. The size of the
            % chunks is pre-determined by the iPreAllocatedRows property.
            % This method looks at the storage directory for these files
            % for a specific simulation run and re-loads their contents
            % into the properties of the object instantiated from this
            % class. 
            % WARNING: When dealing with very large and/or very long
            % simulations the amount of data stored in the mat files can be
            % larger than the availabe RAM on the computer you are running
            % simulations. Depending on your operating system this may
            % cause problems. 
            
            % If the dump to mat feature is turned off, we can't do
            % anything so we tell the user and return.
            if ~this.bDumpToMat
                this.warn('The dump to mat function has been turned off for this simulation, there is nothing to read.');
                return;
            end
            
            % Getting the information on the storage directory in terms of
            % file names etc. 
            sDir    = [ 'data/runs/' this.sStorageDirectory '/' ];
            tDir    = dir(sDir);
            
            % If the files were somehow deleted, we catch it here. 
            if isempty(tDir)
                fprintf('[Logger] No dumped data files available, aborting.\n');
                return;
            end
            
            % Telling the user what's going on and providing a warning
            % regarding the continuation of simulations using the
            % oLastSimObj object that will be manipulated below. Every
            % simulation should additionally save itself as a separate
            % file, so if it needs to be continued, the object can be
            % re-loaded from there. 
            fprintf(['[Logger] Reading data from .mat files\n', ...
                     '         NOTE: logger will probably fail if the simulation is continued using this oLastSimObj!\n', ...
                     '         To avoid problems, delete the oLastSimObj and reload the object from the data/runs folder.\n']);
            
            
            % Cache current log values, which will be the end of the
            % simulation.
            mfLogCached  = this.mfLog;
            afTimeCached = this.afTime;
            
            % Removing all file references that have nothing to do with the
            % dump files.
            tDir(~contains({tDir.name}, 'dump_')) = [];
            
            % Extracting the tick values at which each dump took place from
            % the file names
            aiDumps = cellfun(@(cCell) str2double(cCell(6:(end-4))), {tDir.name});
            
            % Sort dumps by tick, because some operating systems (looking
            % at you Windows...) are not good at sorting files with
            % numbers in the correct order.
            aiDumps = sort(aiDumps);
            
            % Now we have to pre-allocate the variables into which we will
            % load the dumped data. We do this with a matrix and an array
            % of NaNs and we know how many fields we need to allocate
            % because we know how large one dumped data set is (number of
            % pre-allocated rows times the number of log values) and we
            % know how many dumps were made in total. 
            iNumberOfCachedTicks = length(this.mfLog(~isnan(this.mfLog(:,1))));
            mfLogNew  = nan(this.iPreAllocatedRows * length(aiDumps) + iNumberOfCachedTicks, length(this.tLogValues));
            afTimeNew = nan(1, this.iPreAllocatedRows * length(aiDumps) + iNumberOfCachedTicks);
            
            % Outputting the total size of what we are about to load to the
            % user so they know what to expect.
            fSize = size(mfLogNew);
            fprintf('[Logger] Pre-allocated %i rows and %i columns.\n', fSize(1), fSize(2));

            % Actually read the mat files
            for iDump = 1:length(aiDumps)
                % Outputting the current file information to the user
                % because depending on the file size, disk speed, etc. this
                % can take quite a while.
                fprintf('[Logger] Reading mat file dump_%i.mat ...', aiDumps(iDump));
                
                % Loading the contents of the file. Since these contain two
                % variables (mfLogMatrix and afTimeVector), the output is a
                % struct with the variable names as field names.
                tFile = load([ sDir 'dump_' num2str(aiDumps(iDump)) '.mat' ]);
                
                % Now we have to find out where in the pre-allocated
                % variables we have to copy this new batch of data.
                iStartIndex = (iDump - 1) * this.iPreAllocatedRows + 1;
                iEndIndex   = iStartIndex + this.iPreAllocatedRows - 1;
                
                % Again letting the user know we have moved on to the next
                % step and what it is.
                fprintf(' and writing to index %i:%i\n', iStartIndex, iEndIndex);
                
                % Actually copying the data into the pre-allocated
                % variables.
                mfLogNew(iStartIndex:iEndIndex, :) = tFile.mfLogMatrix;
                afTimeNew(iStartIndex:iEndIndex)   = tFile.afTimeVector;
            end
            
            % Now we are done loading the dumped data so we have to append
            % the 'end' of the data which was still in the mfLog property
            % at the end of the simulation and had not been dumped. 
            mfLogNew((iEndIndex + 1):end, :) = mfLogCached(~isnan(mfLogCached(:,1)),:);
            
            % Doing the same for the afTime array.
            afTimeNew((iEndIndex + 1):end)   = afTimeCached(1:iNumberOfCachedTicks); 
            
            % Now we are all done and we can set all of the properties on
            % the logger.
            this.iAllocated = size(mfLogNew, 1);
            this.iLogIndex  = this.iLogIndex + this.iPreAllocatedRows * length(aiDumps);
            this.mfLog      = mfLogNew;
            this.afTime     = afTimeNew;
            
            % Tell the user we are finished.
            fprintf('[Logger] Loading complete!\n');
        end
        
        function clearVirtualValues(this)
            %CLEARVIRTUALVALUES Deletes all virtual values
            % This function is intended for use during debugging and
            % post-processing of simulation results where it may be
            % necessary to add and then remove virtual values. 
            this.tVirtualValues = struct('sExpression', {}, 'calculationHandle', {}, 'sName', {}, 'sUnit', {}, 'sLabel', {});
        end
        
    end
    
    
    methods (Access = protected)
        
        function this = onInitPost(this, ~)
            %ONINITPOST Pre-allocates memory for log and tests the data gathering function handle
            % This function takes the information on all of the log items
            % the user added to pre-allocate a chunk of memory to store the
            % data during the simulation.
            % After pre-alloation is complete it creates the
            % hEvaluateLogData function handle that returns ALL data from
            % ALL objects for the current tick.
            
            % First we need to collect all paths of values to log, which
            % are provided in the 'sExpression' field of the tLogValues
            % struct. 
            this.csPaths = { this.tLogValues.sExpression };
            
            % Counting the number of items that are logged each tick
            this.iNumberOfLogItems = length(this.csPaths);
            
            % To do the pre-allocation of memory, we need to know how much
            % data should be saved in one chunk. In the constructor of this
            % class, the used can optionally provide a value for how many
            % ticks should be pre-allocated. If the user did not provide
            % this value we use the default value which is currently stored
            % in the iPreAllocatedRows property. 
            if ~this.bPreAllocationProvided
                % The default value in iPreAllocatedRows assumes that 100
                % items will be logged for ten thousand ticks. The actual
                % number of log items may be smaller, so to keep the total
                % size of preallocated memory the same, we recalculate the
                % number of rows that should be pre-allocated.
                this.iPreAllocatedRows  = floor(this.iPreAllocatedRows * 100 / this.iNumberOfLogItems);
            end
            
            % Pre-allocating the mfLog property with a matrix of NaNs
            this.mfLog             = nan(this.iPreAllocatedRows, this.iNumberOfLogItems);
            
            % Setting the property for currently allocated rows. This
            % number will increase by the value of iPreAllocatedRows if the
            % current log index reaches the value of iAllocated AND
            % pDumpToMat is false. If pDumpToMat is true, the log index
            % will be reset everytime it reaches iAllocated.
            this.iAllocated        = this.iPreAllocatedRows;
            
            % Letting the user know how much pre-allocation we just did.
            fprintf('[Logger] Pre-allocating %i rows and %i columns.\n', this.iPreAllocatedRows, this.iNumberOfLogItems);
            
            % Now we need to manipulate the strings a bit so the logger can
            % find the actual objects and properties. This has to be done
            % her so the user doesn't have to do it when the logging is set
            % up. So we loop through all the log items and edit them.
            for iL = 1:this.iNumberOfLogItems
                % To make life easy for a user, they can just enter the
                % name of the property of an object as the expression, for
                % example 'fMass'. To make this property reachable from the
                % logger, it has to be pre-pended with the entire path,
                % starting with this logger's reference to the simulation
                % infrastructure object. The user can also make
                % calculations within an object by entering something like
                % 'this.fMass * this.fMassToPressure'. Note that here the
                % properties include 'this.'. This is done so we can
                % replace 'this.' with the full path to that property.
                % Since we have to do that for the individual properties
                % (i.e. 'fMass') as well, we first pre-pend those
                % expressions with 'this.' that don't yet have it.
                if length(this.csPaths{iL}) < 5 || ~strcmp(this.csPaths{iL}(1:5), 'this.')
                    this.csPaths{iL} = [ 'this.' this.csPaths{iL} ];
                end
                
                % Now we can replace every instance of 'this.' with the
                % object's full path.
                this.csPaths{iL} = strrep(this.csPaths{iL}, ...
                    'this.', ...
                    [ 'this.oSimulationInfrastructure.oSimulationContainer.toChildren.' this.tLogValues(iL).sObjectPath '.' ] ...
                    );
            end
            
            % We will now combine the calls to ALL log values into one huge
            % function handle that returns an array of all values when
            % called. Since the paths to the values are all strings, we
            % will assemble the function handle as a string first and then
            % use the eval() function to return an anonymous function
            % handle that can be called at any time during the simulation.
            % Initializing the command string.
            sCommand = '[ ';
            
            % Now we loop through all of the log items and add their paths
            % to the command string, separating them with a comma (',').
            for iL = 1:this.iNumberOfLogItems
                sCommand = strcat( sCommand, this.csPaths{iL}, ',' );
            end
            
            % Adding the closed square brackets to the end.
            sCommand = strcat(sCommand, ' ]' );

            % Now we try to run the eval() function with our command string
            % and the prefix '@()' to signify that it is an anonymous
            % function. If something goes wrong here, it probably has
            % something to do with the way the log items are defined. So we
            % tell the user and provide as much information on the error as
            % we have. 
            try
                this.hEvaluateLogData = eval([ '@() ' sCommand ]);
            catch oError
                this.throw('V_HAB:Logger.onIinitPost',['Something went wrong during the initialization of the logger. \n', ...
                                                       'Please check your setup file and make sure all values are correctly added to the log.\n', ...
                                                       'Error message: %s\n'], oError.message);
            end
        end
        
        function onStepPost(this, ~)
            %ONSTEPPOST Performs the actual logging and (if required) dumping
            % This function executes the hEvaluateLogData function handle
            % property and saves the returned data into the mfLog property.
            % There are also a bunch of error handling steps in here,
            % should something go wrong. 
            % For cases where dumping is active, this function also checks
            % if a new dump is required and performs it if so, otherwise it
            % allocates more memory for the simulation to keep running
            % smoothly.
            
            % Trying to get the data via the hEvaluateLogData function
            % handle. 
            try
                this.mfLog(this.iLogIndex + 1, :) = this.hEvaluateLogData();
            catch oError %#ok<NASGU>
                % One reason for the above statement to fail is an 'empty'
                % variable. Then the length of the array returned by
                % this.hEvaluateLogData() will be shorter than this.mfLog
                % and a dimension mismatch error will be thrown. To prevent
                % this from halting the simulation, we will find the
                % item(s) that return(s) 'empty' and insert 'NaN' at its
                % index in the returned array.
                
                % First we get the return array directly. We assign it to a
                % 'fresh' variable instead of the fixed dimensions of
                % this.mfLog like above, that way it will not throw a
                % dimension mismatch error.
                try
                    afValues = this.hEvaluateLogData();
                catch sInitialError
                    % An error occured, so this is not an empty value, but
                    % something else. So we go through the log values to
                    % find the error
                    csError = cell(0);
                    for iI = 1:this.iNumberOfLogItems
                        try  
                            eval([ this.csPaths{iI} ';' ]);
                        catch sError
                            sErrorMessage = ['\n In the ', num2str(iI), 'th log entry with the following path: \n', this.csPaths{iI},  ' \nThe following error was caught: \n ', sError.message, '\n'];
                            csError{end+1} = sErrorMessage; %#ok<AGROW>
                        end
                    end
                    fprintf('\n During logging the following errors were encountered:\n');
                    for iError = 1:length(csError)
                        fprintf(csError{iError});
                    end
                    rethrow(sInitialError);
                end
                
                % Now we check it it is shorter than the width of mfLog
                if length(afValues) ~= length(this.mfLog(1,:))
                    % It is shorter, so one or more of the items must be
                    % returning empty. So now we go through the log items
                    % individually to find out which ones are.
                    for iI = 1:this.iNumberOfLogItems
                        if isempty(eval([ this.csPaths{iI} ';' ]))
                            % Now we extend the results array by one...
                            afValues(iI+1:end+1) = afValues(iI:end);
                            % ... and insert NaN at the found index.
                            afValues(iI) = NaN;
                        end
                    end
                    
                    % Finally we can write the array into the log.
                    this.mfLog(this.iLogIndex + 1,:) = afValues;
                end
            end
            
            % We have successfully logged data for this tick, so we add the
            % current time to the afTime array
            this.afTime(this.iLogIndex + 1) = this.oSimulationInfrastructure.oSimulationContainer.oTimer.fTime;
            
            % Incrementing the log index. We only increase it after the
            % actual logging is complete in case the user aborts the
            % simulation using ctrl+c.
            this.iLogIndex = this.iLogIndex + 1;
            
            % Now we need to check if we have reached the end of
            % pre-allocated memory. If yes, we need to perform some
            % actions.
            if this.iLogIndex == this.iAllocated
                if this.bDumpToMat
                    % If periodic dumping of the results into a .mat file
                    % is activated and the dumping interval hast passed, we
                    % call the appropriate method here.
                    this.dumpToMat();
                else
                    % If dumping is not implemented, we will expand the
                    % mfLog array by pre-allocating more memory. This makes
                    % writing into the log matrix faster. 
                    this.mfLog(this.iLogIndex + 1:(this.iLogIndex + this.iPreAllocatedRows), :) = nan(this.iPreAllocatedRows, length(this.tLogValues));
                    % Now we have to increase the iAllocated property so
                    % the next execution of this pre-allocation is
                    % iPreAllocatedRows Ticks in the future.
                    this.iAllocated = this.iAllocated + this.iPreAllocatedRows;
                end
            end
        end
        
        function onFinish(this, ~)
            %ONFINISH Saves the simulation object as a mat file if dumping is activated
            
            if this.bDumpToMat
                % First we need to check if the runs folder for this
                % specific simulation already exists. If the simulation
                % duration was too short for a dump to occur, this might
                % not be the case. 
                if ~isfolder([ 'data/runs/' this.sStorageDirectory ])
                    % The folder doesn't exist yet, so we create it.
                    mkdir([ 'data/runs/' this.sStorageDirectory ]);
                end
                
                % Constructing the file name
                sFileName = sprintf('data/runs/%s/oLastSimObj.mat', this.sStorageDirectory);
                
                % Telling the user what's happening
                fprintf('DUMPING - write to .mat: %s\n', sFileName);
                
                % We want the stored variable to have the same name that we
                % use for the object that is assigned in the base
                % workspace, so we create a reference to the infrastructure
                % object called 'oLastSimObj'.
                oLastSimObj = this.oSimulationInfrastructure; 
                
                % Actually saving the object into the mat file.
                save(sFileName, 'oLastSimObj');
            end
        end
        
        function dumpToMat(this)
            %DUMPTOMAT Dumps simulation data into a mat file
            % This function also saves the current simulation object as
            % well, but it is overwritten in the next dump. That way, if a
            % simulation crashes or is aborted, the simulation object that
            % matches the state of the simulation at the last dump is
            % available to continue the simulation. 
            
            % First we check if the simulation-specific folder has already
            % been created and if not, we do it now. 
            if ~isfolder([ 'data/runs/' this.sStorageDirectory ])
                mkdir([ 'data/runs/' this.sStorageDirectory ]);
            end
            
            % Constructing the file name for the dump
            sFileName = sprintf('data/runs/%s/dump_%i.mat', this.sStorageDirectory, this.oSimulationInfrastructure.oSimulationContainer.oTimer.iTick + 1 );
            
            fprintf('#############################################\n');
            fprintf('DUMPING - write to .mat: %s\n', sFileName);
            
            % Getting the current contents of the mfLog property. This will
            % be all of the data that fits into one pre-allocated chunk of
            % memory.
            mfLogMatrix = this.mfLog; 
            
            % Getting the current content of the afTime property. 
            afTimeVector = this.afTime; 
            
            % Actually saving the data to the file. 
            save(sFileName, 'mfLogMatrix', 'afTimeVector');
            
            % Tell the user we're finished. 
            disp('... done!');
            
            % Now we have to reset the mfLog, iLogIndex and afTime
            % properties
            this.mfLog(:, :) = nan(this.iPreAllocatedRows, this.iNumberOfLogItems);
            this.iLogIndex   = 0;
            this.afTime      = nan(this.iPreAllocatedRows, 1);
            
            % We will also now save the current simulation infrastructure
            % object into the same folder as a dump file. First we assemble
            % the file name.
            sFileName = sprintf('data/runs/%s/oLastSimObj.mat', this.sStorageDirectory);
            
            % Telling the user what is happening.
            fprintf('DUMPING - write to .mat: %s\n', sFileName);
            
            % We want the stored variable to have the same name that we use
            % for the object that is assigned in the base workspace, so we
            % create a reference to the infrastructure object called
            % 'oLastSimObj'.
            oLastSimObj = this.oSimulationInfrastructure;
            
            % Actually saving the object into the mat file.
            save(sFileName, 'oLastSimObj');
        end
        
    end
end
