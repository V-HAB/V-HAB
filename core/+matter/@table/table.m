classdef table < base
    %MATTERTABLE Contains all matter related data and some functions
    %   NOTE: Starting with the early 2015 versions of V-HAB the
    %   nomenclature was changed from 'species' to 'substances' when
    %   describing bodys of matter.
    %
    % MatterTable properties:
    %   ttxMatter       - Contains all matter data
    %   afMolMass       - Vector with mol masses for each substance,
    %                     extracted on initializion from ttxMatter
    %   tiN2I           - Struct to map the bu,md to blah
    %   csSubstances    - Cell array with all substance names
    %   iSubstances     - Number of substances in the table
    %
    %TODO
    % Get rid of all the flow, phase, masslog and whatever stuff. That
    % doesn't belong in the matter table.
    
    properties (Constant = true, GetAccess = public)
        % Some constants
        %
        %   - universal gas constant (fUniversalGas) in J/(K Mol)
        %   - gravitational constant (fGravitation) in m^3/(kg s^2)
        %   - Avogadro constant (fAvogadro) in 1/Mol
        %   - Boltzmann constant (fBoltzmann) J/K
        %   - Stefan-Boltzmann constant (fStefanBoltzmann) in W/(m^2 K^4)
        
        Const = struct( ...
            'fUniversalGas',     8.314472,      ...
            'fGravitation',      6.67384e-11,   ...
            'fAvogadro',         6.02214129e23, ...
            'fBoltzmann',        1.3806488e-23, ...
            'fStefanBoltzmann',  5.670373e-8    ...
            );
        
        % Some standard values for use in any place where an actual value
        % is not given or needed.
        
        Standard = struct( ...
            'Temperature', 288.15, ...   % K (25 deg C)
            'Pressure',    101325  ...    % Pa (sea-level pressure)
            );
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % This struct is the heart of the matter table. In it all data on
        % each substance is stored. The key for each substance is its name,
        % e.g. 'H2O' for water, or 'He' for Helium. In the case of complex
        % substances it does not have to be a chemical formula, e.g.
        % 'brine' or 'inedibleBiomass'.
        ttxMatter;
        
        % An array containing the molecular masses of each substance in
        % g/mol. We keep this in a separate array to enable fast
        % calculation of the total molecular mass of a phase or flow. The
        % order in which the substances are stored is identical to the
        % order in ttxMatter. Also, using an array makes it easy to loop
        % through the individual values with simple for-loops.
        %TODO store as kg/mol so e.g. phases.gas doesn't have to convert
        afMolMass;
        afMolarMass;
        
        % This struct maps all substance names according to an index, hence
        % the name N2I, for 'name to index'. The index corresponds to the
        % order in which the substances are stored in ttxMatter.
        % Since the flows and phases have all masses or partial masses in
        % an array rather than a struct or value class helps to loop
        % through all substances fast. With this struct, the index of
        % individual substances can be extracted when needed.
        tiN2I;
        
        % A cell array with the names of all substances contained in the
        % matter table
        csSubstances;
        
        % The number of all substances contained in this matter table
        iSubstances;
    end
    
    properties %DELETE THESE WHEN READY
        % Why do we need all of this? Seems like this should be in a
        % separate class.
        % Refernce to all phases and flows that use this matter table
        aoPhases = []; %matter.phase.empty(); % ABSTRACT - can't do that!
        aoFlows  = matter.flow.empty();
        % Create 'empty' (placeholder) flow (for f2f, exme procs)
        oFlowZero;
        
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Class constructor %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        function this = table()
            % Class constructor
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Check for pre-existing data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % First we'll check if the Excel source file for all the matter
            % data has changed since this constructor was last run. If not,
            % then we can just use the existing data without having to go
            % through the entire import process again.
            
            % Loading the previously saved information about the current
            % matter data, if it exists.
            tOldFileInfo = dir(strrep('data\MatterDataInfo.mat', '\', filesep));
            
            if ~isempty(tOldFileInfo) && ~isempty(dir(strrep('data\MatterData.mat', '\', filesep)))
                % If there is existing data, we get the file information on
                % the current Matter.xlsx file so we can compare the two.
                load(strrep('data\MatterDataInfo.mat', '\', filesep));
                tNewFileInfo = dir(strrep('core\+matter\Matter.xlsx', '\', filesep));
                if tNewFileInfo.datenum <= tMatterDataInfo.datenum
                    % If the current Excel file is not newer than the one
                    % used to create the stored data, we can just use that.
                    load(strrep('data\MatterData.mat', '\', filesep));
                    % The return command ends the constructor method
                    return;
                end
            end
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Introduction %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Now that we have determined, that there is no pre-existing
            % data we have to call importMatterData() a few times to fill
            % the ttxMatter struct with data from the given Excel file.
            % The Excel file has one general worksheet which contains basic
            % information about every element in the periodic table and
            % some compounds. It also contains basic information about
            % substances which cannot be clealy defined (e.g. 'inedible
            % biomass' or 'brine'), but still need to be used in more
            % top-level simulations.
            % The Excel file also contains worksheets for individual
            % substances. These substance-specific worksheets contain many
            % datapoints for several key properties at different
            % temperatures, pressures etc. The findProperty() method uses
            % these datapoints to interpolate between them if called.
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Importing data from 'MatterData' worksheet %%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % First we import all of the data contained in the general
            % 'MatterData' worksheet.
            
            % Calling the importMatterData method (strrep with filesep is
            % used for compatibility of MS and Mac OS, it replaces the
            % backslash with the current system fileseparator, on Macs and
            % Linux, this is the forward slash.)
            [ this.ttxMatter, csWorksheets ] = importMatterData(this, strrep('core\+matter\Matter.xlsx','\',filesep), 'MatterData');
            
            % get all substances
            this.csSubstances = fieldnames(this.ttxMatter);
            % get number of substances
            this.iSubstances  = length(this.csSubstances);
            
            % Initializing the class properties that will be subsequently
            % filled with data. This is done to preallocate the memory. If
            % it is not done, MATLAB gives a warning and suggests to do
            % this.
            this.afMolMass   = zeros(1, this.iSubstances);
            this.afMolarMass = zeros(1, this.iSubstances);
            this.tiN2I       = struct();
            
            % Now we go through all substances in the 'MatterData'
            % worksheet and fill the ttxMatter struct
            for iI = 1:this.iSubstances
                % Creating a temporary variable to make the code more
                % readable.
                tSubstance = this.ttxMatter.(this.csSubstances{iI});
                
                % Since we are importing the data from the 'MatterData'
                % worksheet, rather than the individual worksheet, we set
                % the boolean variable indicating this to false.
                this.ttxMatter.(this.csSubstances{iI}).bIndividualWorksheet = false;
                
                % Adding an entry to the name to index struct
                this.tiN2I.(this.csSubstances{iI}) = iI;
                
                
                % If the molecular mass of the substance is not directly
                % provided by the 'MatterData' worksheet, we try to
                % calculate it. This is only possible if the substance name
                % is given as a chemical formula, e.g. 'H2O' for water.
                if ~isfield(tSubstance, 'fMolMass')
                    % Extract the atomic elements from matter name
                    tElements  = matter.table.extractAtomicTypes(this.csSubstances{iI});
                    % Saving the different elements of the substance into a
                    % cell array.
                    csElements = fieldnames(tElements);
                    
                    % Initializing the mol mass variable
                    fMolMass   = 0;
                    fMolarMass   = 0;
                    
                    %%% Temporary Duplication for transition to molar mass in kg/mol %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    
                    % Now we loop through all the elements of the
                    % substance, check if a molecular mass is given an add
                    % them up.
                    for iE = 1:length(csElements)
                        if isfield(this.ttxMatter, csElements{iE}) && isfield(this.ttxMatter.(csElements{iE}), 'fMolMass')
                            fMolMass = fMolMass + tElements.(csElements{iE}) * this.ttxMatter.(csElements{iE}).fMolMass;
                        else
                            % Throwing an error because there is no entry
                            % for this specific element
                            this.throw('table:constructor', 'No molecular mass provided for element ''%s''', this.csSubstances{iI});
                        end
                    end
                    
                    % Now we loop through all the elements of the
                    % substance, check if a molecular mass is given an add
                    % them up.
                    for iE = 1:length(csElements)
                        if isfield(this.ttxMatter, csElements{iE}) && isfield(this.ttxMatter.(csElements{iE}), 'fMolarMass')
                            fMolarMass = fMolarMass + tElements.(csElements{iE}) * this.ttxMatter.(csElements{iE}).fMolarMass;
                        else
                            % Throwing an error because there is no entry
                            % for this specific element
                            this.throw('table:constructor', 'No molecular mass provided for element ''%s''', this.csSubstances{iI});
                        end
                    end
                    
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    
                    % Now we add a struct with all the elements of the
                    % substance to its entry in the ttxMatter struct.
                    this.ttxMatter.(this.csSubstances{iI}).tElements = tElements;
                    
                else
                    
                    % If the molecular mass is directly given, then we can
                    % just use the given value.
                    fMolMass = tSubstance.fMolMass;
                    fMolarMass = tSubstance.fMolarMass;
                end
                
                % And finally we create an entry in the mol mass array.
                this.afMolMass(iI)   = fMolMass;
                this.afMolarMass(iI) = fMolarMass;
            end
            
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Importing from individual worksheets %%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Now we import all of the data contained in the individual
            % worksheets of the Excel file.
            
            % Looping through all of the worksheets. The first worksheet
            % ('Info') just contains information on how to add data to the
            % Exel file. We just imported the second worksheet,
            % 'MatterData', so now we start at number 3.
            for iI = 3:length(csWorksheets)
                
                % Getting the substance name from the worksheet name.
                sSubstancename = csWorksheets{iI};
                
                % Calling the importMatterData method (strrep with filesep is
                % used for compatibility of MS and Mac OS, it replaces the
                % backslash with the current system fileseparator, on Macs and
                % Linux, this is the forward slash.)
                this.ttxMatter.(sSubstancename) = importMatterData(this, strrep('core\+matter\Matter.xlsx','\',filesep), sSubstancename);
                
                % Since we are importing the data from an individual
                % worksheet, we set the boolean variable indicating this to
                % true.
                this.ttxMatter.(sSubstancename).bIndividualWorksheet = true;
                
                % Now we need to update some of the global information
                if ~any(strcmp(this.csSubstances, sSubstancename))
                    
                    % First we increment the total number of substances
                    this.iSubstances = this.iSubstances+1;
                    % Write new substancename into the cellarray
                    this.csSubstances{this.iSubstances} = sSubstancename;
                    % Add index of new substance to name to index struct
                    this.tiN2I.(sSubstancename) = this.iSubstances;
                    % Write mol mass of substance into mol mass array
                    this.afMolMass(this.iSubstances) = this.ttxMatter.(sSubstancename).fMolMass;
                    % Write mol mass of substance into mol mass array
                    this.afMolarMass(this.iSubstances) = this.ttxMatter.(sSubstancename).fMolarMass;
                end
            end
            
            % Now we save the data into a .mat file, so if the matter table
            % doesn't change, we don't have to run through the entire
            % constructor again. To do this, we just place the entire table
            % object into the file.
            
            % Creating the file name
            filename = strrep('data\MatterData.mat', '\', filesep);
            save(filename, 'this');
            
            % To make it a little easier and faster to handle, we'll save
            % the Excel file information into a separate file. That way we
            % only have to load a small file rather than the entire matter
            % table at the beginning of this constructor.
            tMatterDataInfo = dir(strrep('core\+matter\Matter.xlsx','\',filesep));
            filename = strrep('data\MatterDataInfo.mat', '\', filesep);
            save(filename, 'tMatterDataInfo');
            
            
            % Now we are done. All of the data has been written into the
            % matter table and the data has been saved for future use.
            % Let the simulations begin!
            
        end
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Method for calculating matter properties %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        
        function fProperty = findProperty(this, sSubstance, sProperty, sFirstDepName, fFirstDepValue, sSecondDepName, fSecondDepValue, sPhaseType)
            % This function searches for property values that are dependent
            % on one or two other values. One dependency is mandatory, the
            % second one is optional.
            % If the desired value is not given directly in the ttxMatter
            % struct, the function will perform a linear interpolation to
            % find the value.
            % The function does NOT perform extrapolation. If the
            % dependencies are out of the bounds of the data in ttxMatter,
            % the value neares to the given dependency values will be
            % returned. A message will be displayed when this happens.
            %
            % FindProperty returns
            %  fProperty - (interpolated) value of searched property
            %
            % Input parameters
            % sSubstance: substance name for structfield
            % sProperty: property name for column
            % sFirstDepName: name of dependency 1 (parameter for findColumn), e.g. 'Temperature'
            % sFirstDepValue: value of dependency 1
            % sSecondDepName: name of dependency 2 (parameter for findColumn), e.g. 'Pressure', optional
            % sFirstDepValue: value of dependency 2, optional
            % sPhase: only specific phase searched; selects only rows with that phase in MatterData,
            %         'gas', 'liquid' or 'solid', optional
            %
            % Example input: this.FindProperty('CO2','c_p','Pressure',120000,'alpha',0.15,'liquid')
            
            %TODO See if we actually need the phase and flow object input
            % possiblity. Might also be better to do this in the externally
            % defined functions like calculateHeatCapacity etc.
            % Right now it still just takes parameters, no objects.
            % varargin
            % Can either be a phase or flow object (oPhase, oFlow), one or
            % two dependencies, and the phase of the substance
            % sFirstDepName: name of dependency 1 (parameter for findColumn), e.g. 'Temperature'
            % sFirstDepValue: value of dependency 1
            % sSecondDepName: name of dependency 2 (parameter for findColumn), e.g. 'Pressure', optional
            % sFirstDepValue: value of dependency 2, optional
            % sPhase: only specific phase searched; selects only rows with that phase in MatterData,
            %         'gas', 'liquid' or 'solid', optional
            %
            % If phase or flow objects are given, the two dependencies will
            % be set to temperature and pressure
            
            %% Initializing the return variable
            
            fProperty = [];
            
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Checking inputs for correctness %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            switch nargin
                %---------------------------------------------------------%
                case 8 % Two dependencies plus phase type
                    
                    % input parameters must be:
                    % this, Substancename, Property,
                    % FirstDependency, FirstDependencyValue,
                    % SecondDependency, SecondDependenyValue,
                    % Phase type
                    
                    % check if all inputs have correct type
                    if ~ischar(sSubstance) || ~ischar(sProperty) || ~(ischar(sFirstDepName) || ...
                            isempty(sFirstDepName)) || ~isnumeric(fFirstDepValue) ||...
                            ~(ischar(sSecondDepName) || isempty(sSecondDepName)) ||...
                            ~isnumeric(fSecondDepValue) || ~ischar(sPhaseType) || ~ischar(sSubstance)
                        this.throw('table:FindProperty','Some inputs have wrong type');
                    else
                        % number of dependencies
                        iDependencies = 2;
                    end
                    %---------------------------------------------------------%
                case 7 % Two dependencies without phase type
                    
                    % input parameters must be:
                    % this, Substancename, Property,
                    % FirstDependency, FirstDependencyValue,
                    % SecondDependency, SecondDependenyValue,
                    
                    % check if all inputs have correct type
                    if ~ischar(sSubstance) || ~ischar(sProperty) || ~(ischar(sFirstDepName) ||...
                            isempty(sFirstDepName)) || ~isnumeric(fFirstDepValue) ||...
                            ~(ischar(sSecondDepName) || isempty(sSecondDepName)) ||...
                            ~isnumeric(fSecondDepValue) || ~ischar(sSubstance)
                        this.throw('table:FindProperty','Some inputs have wrong type');
                    else
                        % number of dependencies
                        iDependencies = 2;
                        sPhaseType = [];
                    end
                    %---------------------------------------------------------%
                case 6 % One dependency plus phase type
                    
                    % input parameters must be:
                    % this, Substancename, Property,
                    % FirstDependency, FirstDependencyValue,
                    % Phase type
                    
                    % check if sPhase is given as last parameter
                    if isa(sSecondDepName, 'char') && strcmpi({'solid','liquid','gas'}, sSecondDepName)
                        sPhaseType = sSecondDepName;
                        sSecondDepName = [];
                        % number of dependencies
                        iDependencies = 1;
                    else
                        this.throw('table:FindProperty','Input phase is not correct');
                    end
                    %---------------------------------------------------------%
                case 5 % One dependency without phase type
                    
                    % input parameters must be:
                    % this, Substancename, Property,
                    % FirstDependency, FirstDependencyValue,
                    
                    % check if value of first dependency is numeric
                    if isnumeric(fFirstDepValue)
                        sSecondDepName = [];
                        sPhaseType = [];
                        % number of dependencies
                        iDependencies = 1;
                    else
                        this.throw('table:FindProperty','Wrong inputtype for first dependency');
                    end
                    %---------------------------------------------------------%
                otherwise
                    % at least one dependency has to be given over
                    this.throw('table:FindProperty','Not enough inputs');
                    %---------------------------------------------------------%
            end
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Determining the number of dependencies %%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check if dependencies are valid
            % if only second dependency is valid -> make it the first
            if (isempty(sFirstDepName) || ~ischar(sFirstDepName)) && ~(isempty(sSecondDepName) || ischar(sSecondDepName))
                sFirstDepName = sSecondDepName;
                sSecondDepName = [];
                fFirstDepValue = fSecondDepValue;
                fSecondDepValue = [];
                % number of dependencies
                iDependencies = 1;
            end
            
            % last check of parameters
            if isempty(sFirstDepName) || ~ischar(sFirstDepName) || isempty(fFirstDepValue)
                this.throw('table:FindProperty',sprintf('no valid dependency was transmitted for property %s',sProperty));
            end
            
            % get column of searched property
            iColumn = this.findColumn(sProperty, sSubstance);
            
            % if no column found, property is not in worksheet
            if isempty(iColumn)
                this.throw('table:FindProperty',sprintf('Cannot find property %s in worksheet %s', sProperty, sSubstance));
            end
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Finding properties in dedicated data worksheet %%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % See if this substance has an individual worksheet
            if this.ttxMatter.(sSubstance).bIndividualWorksheet
                
                % Initialize array for checking if dependencies are out of
                % table value range
                abOutOfRange = [false; false];
                
                %---------------------------------------------------------%
                % Getting the first dependency and check for out of range
                %---------------------------------------------------------%
                
                % get column of first dependency
                iColumnFirst = this.findColumn(sFirstDepName, sSubstance);
                % if properties are given 2 times (e.g. Temperature has C and K columns), second column is used
                if length(iColumnFirst) > 1
                    iColumnFirst = iColumnFirst(2);
                end
                % if no column found, property is not in worksheet
                if isempty(iColumnFirst)
                    this.throw('table:FindProperty',sprintf('Cannot find property %s in worksheet %s', sFirstDepName, sSubstance));
                end
                
                % look if data for first dependency is in range of table
                % if not in range, first look if data is given in worksheet MatterData before interpolate
                [fMin, fMax] = this.FindRange(sSubstance, iColumnFirst);
                if fFirstDepValue > fMax
                    % First dependency is greater than max value in table
                    % set dependency equal max table value
                    fFirstDepValue = fMax;
                    abOutOfRange(1) = true;
                elseif fFirstDepValue < fMin
                    % First dependency is less than min value in table
                    % set dependency equal min table value
                    fFirstDepValue = fMin;
                    abOutOfRange(1) = true;
                end
                
                iRowsFirst = find(this.ttxMatter.(sSubstance).import.num(:,iColumnFirst) == fFirstDepValue);
                
                %---------------------------------------------------------%
                % Only one dependency is given
                %---------------------------------------------------------%
                
                if iDependencies == 1
                    
                    if ~isempty(iRowsFirst) && ~abOutOfRange(1)
                        % dependencyvalue in table and in range of table
                        % direct usage
                        fProperty = this.ttxMatter.(sSubstance).import.num((this.ttxMatter.(sSubstance).import.num(iRowsFirst,iColumnFirst) == fFirstDepValue), iColumn);
                    elseif ~abOutOfRange(1)
                        % only in range of table
                        % interpolation needed
                        % create a temporary array because interp1 need stricly monotonic increasing data
                        afTemporary = this.ttxMatter.(sSubstance).import.num(:,[iColumn, iColumnFirst]);
                        afTemporary = sortrows(afTemporary,2);
                        [~,rows] = unique(afTemporary(:,2),'rows');
                        afTemporary = afTemporary(rows,:);
                        fProperty = interp1(afTemporary(:,2),afTemporary(:,1),fFirstDepValue);
                    else
                        % dependencyvalue is out of range
                        % look if phase of substance is in MatterData
                        iRowsFirstMatterData = find(strcmpi(this.ttxMatter.(sSubstance).MatterData.text(:,3), sPhaseType), 1, 'first');
                        if isempty(iRowsFirstMatterData)
                            % not in MatterData
                            % get 'best' value in Range of substancetable
                            fProperty = this.ttxMatter.(sSubstance).import.num((this.ttxMatter.(sSubstance).import.num(iRowsFirst,iColumnFirst) == fFirstDepValue), iColumn);
                        else
                            % get the data from the MatterData-worksheet
                            % first get column of property
                            iColumn = find(strcmp(this.ttxMatter.(sSubstance).MatterData.text(1,:), sProperty)); % row 1 is std propertyname in MatterData
                            % get the propertyvalue
                            fProperty = this.ttxMatter.(sSubstance).MatterData.num(iRowsFirstMatterData-2,iColumn-3);
                        end
                    end
                else
                    
                    %---------------------------------------------------------%
                    % Two dependencies are given.
                    % Getting the second dependency and check for out of range
                    %---------------------------------------------------------%
                    % get column of second dependency
                    iColumnSecond = this.findColumn(sSecondDepName, sSubstance);
                    
                    % if no column found, property is not in worksheet
                    if isempty(iColumnSecond)
                        this.throw('table:FindProperty',sprintf('Cannot find property %s in worksheet %s', sSecondDepName, sSubstance));
                    end
                    
                    % look if data for second dependency is in range of table
                    % if not in range, first look if data is given in worksheet MatterData before interpolate
                    [fMin, fMax] = this.FindRange(sSubstance, iColumnSecond);
                    if fSecondDepValue > fMax
                        % Second dependency is greater than max value in table
                        % set dependency equal max table value
                        fSecondDepValue = fMax;
                        abOutOfRange(2) = true;
                    elseif fSecondDepValue < fMin
                        % Second dependency is less than min value in table
                        % set dependency equal min table value
                        fSecondDepValue = fMin;
                        abOutOfRange(2) = true;
                    end
                    
                    % get columns with already given values of searched second dependency
                    iRowsSecond = find(this.ttxMatter.(sSubstance).import.num(:,iColumnSecond) == fSecondDepValue);
                    
                    if ~(abOutOfRange(1) || abOutOfRange(2))
                        
                        %-------------------------------------------------%
                        % Both dependencies are in range
                        %-------------------------------------------------%
                        if ~isempty(iRowsFirst) && ~isempty(iRowsSecond) && intersect(iRowsFirst,iRowsSecond)
                            % If the desired property for the given
                            % dependencies is directly given in the matter
                            % table, we just get it.
                            fProperty = this.ttxMatter.(sSubstance).import.num(intersect(iRowsFirst,iRowsSecond), iColumn);
                            
                        else
                            % If the property is not directly given an
                            % interpolation over both dependencies is
                            % needed.
                            
                            % Check and see, if this interpolation has been
                            % done before and use those values for better
                            % performance.
                            
                            % First we need to create the unique ID for
                            % this specific interpolation to see, if it
                            % already exists.
                            % We start by getting the columns used for this
                            % specific interpolation.
                            iNumberOfColumns = length(this.ttxMatter.(sSubstance).import.text(:,5));
                            
                            % Now we create an array filled with zeros and
                            % set the columns used to 1
                            aiID = zeros(iNumberOfColumns, 1);
                            aiID([iColumn, iColumnFirst, iColumnSecond]) = 1;
                            
                            % To get an ID that can be used as a key in a
                            % struct, we turn the resulting binary number
                            % into a decimal and then into a string.
                            sID = ['ID',num2str(bi2de(aiID.'))];
                            
                            % Now we check if this interpolation already
                            % exists. If yes, we just use the saved
                            % function.
                            
                            bInterpolationPresent = false;
                            
                            if isfield(this.ttxMatter.(sSubstance), 'tInterpolations') 
                                if isfield(this.ttxMatter.(sSubstance).tInterpolations, strrep(sProperty, ' ', ''))
                                    if isfield(this.ttxMatter.(sSubstance).tInterpolations.(strrep(sProperty, ' ', '')), sID)
                                        bInterpolationPresent = true;
                                    end
                                end
                            end
                            
                            if bInterpolationPresent
                                % We know there is data, so we use it. 
                                fProperty = this.ttxMatter.(sSubstance).tInterpolations.(strrep(sProperty, ' ', '')).(sID)(fFirstDepValue, fSecondDepValue);

                            else
                                % The interpolation function does not yet
                                % exist, so we have to go and run the
                                % interpolation.
                                
                                % create temporary array because scatteredInterpolant doesn't allow NaN values
                                afTemporary = this.ttxMatter.(sSubstance).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                                
                                % Now we remove all rows that contain NaN values
                                afTemporary(any(isnan(afTemporary), 2), :) = [];
                                
                                % Only unique values are needed (also scatteredInterpolant would give out a warning in that case)
                                afTemporary = unique(afTemporary,'rows');
                                % Sometimes there are also multiple values for
                                % the same combination of dependencies. Here we
                                % get rid of those too.
                                [ ~, aIndices ] = unique(afTemporary(:, [2 3]), 'rows');
                                afTemporary = afTemporary(aIndices, :);
                                
                                % interpolate linear with no extrapolation
                                %CHECK Does it make sense not to extrapolate?
                                F = scatteredInterpolant(afTemporary(:,2),afTemporary(:,3),afTemporary(:,1),'linear','none');
                                fProperty = F(fFirstDepValue, fSecondDepValue);
                                
                                % To make this faster the next time around, we
                                % save the scatteredInterpolant into the matter
                                % table.
                                
                                this.ttxMatter.(sSubstance).tInterpolations.(strrep(sProperty, ' ', '')).(sID) = F;
                                
                                % This addition to the matter table will be
                                % overwritten, when the next simulation
                                % starts, even if Matter.xlsx has not
                                % changed. To prevent this, we need to save
                                % the table object again.
                                filename = strrep('data\MatterData.mat', '\', filesep);
                                save(filename, 'this');
                            end
                            
                            
                        end
                    else
                        %-------------------------------------------------%
                        % one or more dependencies are out of range
                        %-------------------------------------------------%
                        
                        % look if data is in MatterData
                        if isfield(this.ttxMatter.(sSubstance), 'MatterData')
                            iRowsFirstMatterData = find(strcmpi(this.ttxMatter.(sSubstance).MatterData.text(:,3), sPhaseType), 1, 'first');
                        else
                            iRowsFirstMatterData = [];
                        end
                        
                        if iRowsFirstMatterData
                            % data found in MatterData
                            % first get column of property
                            iColumn = find(strcmp(this.ttxMatter.(sSubstance).MatterData.text(1,:), sProperty)); % row 1 is std propertyname in MatterData
                            % get the propertyvalue
                            fProperty = this.ttxMatter.(sSubstance).MatterData.num(iRowsFirstMatterData-2,iColumn-3);
                        else
                            % no data found in MatterData
                            % get 'best' value in Range of substancetable
                            
                            % create temporary array because scatteredInterpolant doesn't allow NaN values
                            afTemporary = this.ttxMatter.(sSubstance).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                            
                            % Now we remove all rows that contain NaN values
                            afTemporary(any(isnan(afTemporary), 2), :) = [];
                            
                            % only unique values are needed (also scatteredInterpolant would give out a warning in that case)
                            afTemporary = unique(afTemporary,'rows');
                            
                            % Sometimes there are also multiple values for
                            % the same combination of dependencies. Here we
                            % get rid of those too.
                            [ ~, aIndices ] = unique(afTemporary(:, [2 3]), 'rows');
                            afTemporary = afTemporary(aIndices, :);
                            
                            % interpolate linear with no extrapolation
                            %CHECK Does it make sense not to extrapolate?
                            F = scatteredInterpolant(afTemporary(:,2),afTemporary(:,3),afTemporary(:,1),'linear','none');
                            fProperty = F(fFirstDepValue, fSecondDepValue);
                        end
                    end
                    
                end
                
                
            else
                %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % Finding properties in generic MatterData worksheet %%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                % get the rows of the phase of the substance
                % dynamic search of column phase?
                rowPhase = find(strcmp(this.ttxMatter.(sSubstance).import.text(:,3), sPhaseType), 1, 'first');
                if rowPhase
                    % get the propertyvalue
                    fProperty = this.ttxMatter.(sSubstance).import.raw{rowPhase,iColumn};
                end
                
            end
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Check to see if what we got in the end is an actual value %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if isnan(fProperty) || isempty(fProperty)
                keyboard();
                this.throw('findProperty', 'Error using findProperty. No valid value for %s of %s found in matter table.', sProperty, sSubstance);
            end
        end
        
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Methods for handling of related phases and flows %%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function afMass = addPhase(this, oPhase, oOldMT)
            % Add phase
            %disp('Add phase')
            if ~isa(oPhase, 'matter.phase')
                this.throw('addPhase', 'Provided object does not derive from or is a matter.phase');
            end
            
            % Preset with default: if phase not added, same vector returned
            afMass = oPhase.afMass;
            
            if isempty(this.aoPhases) || ~any(this.aoPhases == oPhase)
                % The basic matter.phases is abstract so aoPhases can not
                % pre-initialized with an empty mixin vector - therefore
                % need to distinguish between first and following phases.
                if isempty(this.aoPhases), this.aoPhases          = oPhase;
                else                       this.aoPhases(end + 1) = oPhase;
                end
                
                if (nargin > 2) && ~isempty(oOldMT)
                    if ~isa(oOldMT, 'matter.table')
                        this.throw('addPhase', 'The provided object for the old matter table is not a and doesn''t derive from matter.table');
                    end
                    
                    afMass = this.mapMassesToNewMT(oOldMT, afMass);
                end
            end
        end
        
        function this = removePhase(this, oPhase)
            %disp('Remove phase')
            iInd = find(this.aoPhases == oPhase, 1); % Just find first result - phase never added twice
            
            if isempty(iInd)
                this.throw('removePhase', 'Provided phase not assinged to this matter table!');
            else
                this.aoPhases(iInd) = [];
            end
        end
        
        function afMass = addFlow(this, oFlow, oOldMT)
            % Add flow
            %disp('Add flow')
            if ~isa(oFlow, 'matter.flow')
                this.throw('addFlow', 'Provided object does not derive from or is a matter.flow');
            end
            
            % Preset with default: if phase not added, same vector returned
            afMass = oFlow.arPartialMass;
            
            if ~any(this.aoFlows == oFlow)
                this.aoFlows(length(this.aoFlows) + 1) = oFlow;
                
                % Remap matter substance?
                if (nargin > 2) && ~isempty(oOldMT)
                    if ~isa(oOldMT, 'matter.table')
                        this.throw('addFlow', 'The provided object for the old matter table is not a and doesn''t derive from matter.table');
                    end
                    
                    afMass = this.mapMassesToNewMT(oOldMT, afMass);
                end
            end
        end
        
        function this = removeFlow(this, oFlow)
            %disp('Remove flow')
            iInd = find(this.aoFlows == oFlow, 1); % Just find first result - flow never added twice
            
            if isempty(iInd)
                this.throw('removeFlow', 'Provided flow not assinged to this matter table!');
            else
                this.aoFlows(iInd) = [];
            end
        end
        
    end
    
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Protected, internal methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods (Access = protected)
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Helper methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [iColumn, iTableLength] = findColumn(this, sProperty, sSubstance, iRow)
            % This function is used to find the column of a property and if
            % desired wished the columnlength of the table
            %
            % findColumn returns
            %  iColumn - number of column
            %  iTableLength - length of table
            %
            % inputs:
            % sProperty: name of searched property
            % sSubstance: substancename
            % iRow: rownumber in which the search string stays, optional
            
            % only calculate tablelength if is searched too
            if nargout == 2
                iTableLength = size(this.ttxMatter.(sSubstance).import.text,2);
            end
            
            if nargin > 3 && ~isempty(iRow)
                % if rownumbers is also given we can just get the column
                iColumn = find(strcmp(this.ttxMatter.(sSubstance).import.text(iRow,:),sProperty));
                
                % Check if the substance has an individual worksheet or if the
                % data is in the 'MatterData' worksheet
            elseif this.ttxMatter.(sSubstance).bIndividualWorksheet
                % row 5 is the fixed location of the property name
                iColumn = find(strcmp(this.ttxMatter.(sSubstance).import.text(5,:),sProperty));
                % Maybe the user didn't pay attention, but just in
                % case, if someone entered the variable name as 'char'
                % here, it will still return the correct value. Boy, we
                % are nice programmers...
                if isempty(iColumn)
                    iColumn = find(strcmp(this.ttxMatter.(sSubstance).import.text(7,:),sProperty));
                end
            else
                % Since we don't have a specific worksheet for this
                % species, we use the column as given in the MatterData
                % worksheet. Here the property name is in row 1
                iColumn = find(strcmp(this.ttxMatter.(sSubstance).import.text(1,:),sProperty)); % row 1 is std propertyname in MatterData
                
                % Again we try to correct for user error if the
                % variable name was entered instead of the property
                % name.
                if isempty(iColumn)
                    iColumn = find(strcmp(this.ttxMatter.(sSubstance).import.text(2,:),sProperty)); % search row 2 as alternative
                end
            end
        end
        
        function [fMin, fMax] = FindRange(this, sSubstance, xProperty)
            % This function gets the range of values for a specific
            % property.
            % Used in findProperty to look if searched values are in range
            % of the given worksheetdata
            %
            % FindRange returns
            %  fMin: minimum value of column
            %  fMax: maximum value of column
            %
            % inputs:
            % sSubstance: substance name
            % xProperty: property name as string or number of column
            
            % depending on the input, look for column or property
            if isnumeric(xProperty)
                iColumn = xProperty;
            elseif ischar(xProperty)
                iColumn = this.findColumn(xProperty, sSubstance);
            else
                this.thow('table:FindRange','Wrong input');
            end
            
            % only look for maximum values if searched too
            if nargout == 2
                % get maximum value
                fMax = max(this.ttxMatter.(sSubstance).import.num(:,iColumn));
            end
            % get minimum value
            fMin = min(this.ttxMatter.(sSubstance).import.num(:,iColumn));
        end
        
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Static helper methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods (Static = true)
        function tElements = extractAtomicTypes(sMolecule)
            % Extracts the single atoms out of a molecule string, e.g. CO2
            % leads to struct('C', 1, 'O', 2)
            % Elements have to be written as Na, i.e. first letter is
            % uppercase, following ones are lowercase (e.g. Na2O2)
            % Input parameter is a string
            
            % Initializing some variables:
            tElements = struct();   % Return struct
            sCurrentElement = '';          %
            sAtomCount   = '';
            
            % Going through the input string character by character
            for iI = 1:length(sMolecule)
                % Setting a variable for the current letter for better
                % readability
                sCurrentChar = sMolecule(iI);
                
                % Check for number or uppercase
                bIsNaN = isnan(str2double(sCurrentChar));
                bUpper = bIsNaN && isstrprop(sCurrentChar, 'upper');
                
                % If the letter is uppercase it's the start of a new
                % element
                if bUpper
                    % If the sCurrentElement variable is NOT empty, there is
                    % information about the previous element to be saved.
                    if ~isempty(sCurrentElement)
                        % If the sAtomCount variable is empty, then there is
                        % only one atom of this element in the compound. So
                        % we can set sCount to 1.
                        if isempty(sAtomCount), sAtomCount = '1'; end;
                        
                        % Now we can create the entry for the element in
                        % the output struct using sCurrentElement as key and
                        % sAtomCount as value, after we've converted it into a
                        % number, of course.
                        tElements.(sCurrentElement) = str2double(sAtomCount);
                    end
                    
                    % Setting the current element string
                    sCurrentElement = sCurrentChar;
                    % Resetting the atom counter, since we've just stared a
                    % new one.
                    sAtomCount   = '';
                    
                    % If the character is a number, we append it to the end
                    % of sAtomCount. The appending is necessary if the
                    % number of elements has 2 or more digits.
                elseif ~bIsNaN
                    sAtomCount = [ sAtomCount sCurrentChar ]; %#ok<AGROW>
                    
                else % Lower case letter
                    % If the sCurrentElement string is empty, then
                    % something went wrong. Throw an error.
                    if isempty(sCurrentElement)
                        error('matter:table:extractAtomicTypes', 'Molecule string does not start with uppercase (see help for format)');
                    end
                    
                    % If the current character is lower case, we just
                    % append it to the previous letter
                    sCurrentElement = [ sCurrentElement sCurrentChar ]; %#ok<AGROW>
                end
            end
            
            
            % When the for-loop is complete, we still have to add the last
            % element to the struct, since the previous additions were all
            % made, as soon as the next element is detected by its upper
            % case letter. Now there is no 'next' element.
            if ~isempty(sCurrentElement)
                % If the sAtomCount variable is empty, then there is
                % only one atom of this element in the compound. So
                % we can set sCount to 1.
                if isempty(sAtomCount), sAtomCount = '1'; end;
                
                % Now we can create the entry for the element in
                % the output struct using sCurrentElement as key and
                % sAtomCount as value, after we've converted it into a
                % number, of course.
                tElements.(sCurrentElement) = str2double(sAtomCount);
            end
        end
    end
end
