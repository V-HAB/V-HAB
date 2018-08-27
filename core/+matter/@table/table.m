classdef table < base
    %MATTERTABLE Contains all matter related data and some functions
    %   NOTE: Starting with the early 2015 versions of V-HAB the
    %   nomenclature was changed from 'species' to 'substances' when
    %   describing bodys of matter.
    %
    % MatterTable properties:
    %   ttxMatter       - Contains all matter data
    %   afMolarMass     - Vector with molar masses for each substance,
    %                     extracted on initializion from ttxMatter
    %   tiN2I           - Struct to map the bu,md to blah
    %   csSubstances    - Cell array with all substance names
    %   iSubstances     - Number of substances in the table
    %
    %TODO
    % Get rid of all the flow, phase, masslog and whatever stuff. That
    % doesn't belong in the matter table.
    
    properties (Constant = true, GetAccess = public)
        % Struct containing global constants
        %
        %   - universal gas constant (fUniversalGas) in J/(K Mol)
        %   - gravitational constant (fGravitation) in m^3/(kg s^2)
        %   - Avogadro constant (fAvogadro) in 1/Mol
        %   - Boltzmann constant (fBoltzmann) J/K
        %   - Stefan-Boltzmann constant (fStefanBoltzmann) in W/(m^2 K^4)
        %   - Speed of light (fLightSpeed) in m/s
        %   - Planck constant (fPlanck) in (kg m^2) / s
        Const = struct( ...
            'fUniversalGas',     8.314472,      ...
            'fGravitation',      6.67384e-11,   ...
            'fAvogadro',         6.02214129e23, ...
            'fBoltzmann',        1.3806488e-23, ...
            'fStefanBoltzmann',  5.670373e-8,   ...
            'fLightSpeed',       2.998*10^8,    ...
            'fPlanck',           6.626*10^-34   ...
            );
        
        % Struct containing standard values for use in any place where an
        % actual value is not given or needed.
        Standard = struct( ...
            'Temperature', 288.15, ...    % K  (25 deg C)
            'Pressure',    101325  ...    % Pa (sea-level pressure)
            );
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % struct containing nutritional data of edible substances. read
        % independently but will added directly to matter table too for
        % according edible substances. tuhs only the adding part to the
        % matter table has to be adjusted in addition to the .csv files
        % when adding new edible substances (e.g. frozen astronaut food)
        ttxNutrientData;
        
        % This struct is the heart of the matter table. In it all data on
        % each substance is stored. The key for each substance is its name,
        % e.g. 'H2O' for water, or 'He' for Helium. In the case of complex
        % substances it does not have to be a chemical formula, e.g.
        % 'brine' or 'inedibleBiomass'.
        ttxMatter;
        
        % An array containing the molar masses of each substance in kg/mol.
        % We keep this in a separate array to enable fast calculation of
        % the total molar mass of a phase or flow. The order in which the
        % substances are stored is identical to the order in ttxMatter.
        % Also, using an array makes it easy to loop through the individual
        % values with simple for-loops.
        afMolarMass;
        
        % This struct maps all substance names according to an index, hence
        % the name N2I, for 'name to index'. The index corresponds to the
        % order in which the substances are stored in ttxMatter.
        % Since the flows and phases have all masses or partial masses in
        % an array rather than a struct or value class helps to loop
        % through all substances fast. With this struct, the index of
        % individual substances can be extracted when needed.
        tiN2I;
        
        % Reverse of tiN2I, a cell containing all the names of the
        % substances, accessible via their index. 
        csI2N;
        
        % cell array for all edible substances
        csEdibleSubstances;
        
        % A cell array with the names of all substances contained in the
        % matter table
        csSubstances;
        
        % The number of all substances contained in this matter table
        iSubstances;
        
        % a boolean array that has as many entries as there are substances
        % defined in the matter table and contains the entry true for each
        % substance that can absorb something else
        abAbsorber;
    end
    
    properties (Transient)%DELETE THESE WHEN READY
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
            
            disp('Checking for changes regarding the matter table source data.');
            
            % First we'll check if there is previously stored matter data.
            % Then we check if the source files for all the matter data and
            % this file itself have changed since this constructor was last
            % run. If not, then we can just use the existing data without
            % having to go through the entire import process again.
            if exist(strrep('data\MatterData.mat', '\', filesep),'file')
                % The file exists, so we check for changes.
                bMatterDataChanged  = tools.fileChecker.checkForChanges(fullfile('core','+matter','+data'),'MatterTable');
                bMatterTableChanged = tools.fileChecker.checkForChanges(fullfile('core','+matter','@table'),'MatterTable');
                
                % If there are no changes, we can load the previously saved
                % data.
                if ~(bMatterDataChanged || bMatterTableChanged)
                    % If the matter files or the matter table itself have
                    % not changed, we can load the MatterData.mat file, if
                    % it exists.
                    load(strrep('data\MatterData.mat', '\', filesep),'this');
                    
                    % There are a few properties that will have been saved
                    % by the previous run of V-HAB in the matter.table
                    % object that need to be reset to their initial values,
                    % otherwise there might be errors if the object classes
                    % were changed between runs.
                    %
                    % Also, objects here are included in e.g. mass balance
                    % calculations, leading to wrong results.
                    %
                    %TODO delete these as soon as aoPhases and aoFlows
                    %properties have been removed from this class.
                    this.aoPhases = [];
                    this.aoFlows  = matter.flow.empty();
                    
                    disp('Matter table loaded from stored version.');
                    
                    % The return command ends the constructor method
                    return;
                end
            end
            
            % Notify user that generating the matter data will take some time.
            disp('Regenerating matter table from stored data. This will take a moment ...');
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Introduction %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Now that we have determined, that there is no pre-existing
            % data we have to call importMatterData() a few times to fill
            % the ttxMatter struct with data from the .csv files in the
            % library.
            % There is one general matter data file which contains basic
            % information about every element in the periodic table and
            % some compounds. It also contains basic information about
            % substances which cannot be clealy defined (e.g. 'inedible
            % biomass' or 'brine'), but still need to be used in more
            % top-level simulations.
            % There are also files for individual substances. These 
            % substance-specific worksheets contain many datapoints for 
            % several key properties at different temperatures, pressures 
            % etc. both for isochoric and isobaric state changes. 
            % The findProperty() method uses these datapoints to 
            % interpolate between them if called.
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Importing data from 'MatterData.csv' file %%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % First we import all of the data contained in the general
            % 'MatterData.csv' file.
            
            % Calling the importMatterData method (strrep with filesep is
            % used for compatibility of MS and Mac OS, it replaces the
            % backslash with the current system fileseparator, on Macs and
            % Linux, this is the forward slash.)
            this.ttxMatter = importMatterData('MatterData');
             
            % get all substances
            this.csSubstances = fieldnames(this.ttxMatter);
            % get number of substances
            this.iSubstances  = length(this.csSubstances);
            
            % Initializing the class properties that will be subsequently
            % filled with data. This is done to preallocate the memory. If
            % it is not done, MATLAB gives a warning and suggests to do
            % this.
            this.afMolarMass = zeros(1, this.iSubstances);
            this.tiN2I       = struct();
            
            %%
            
            % Now we go through all substances in the 'MatterData'
            % worksheet and fill the ttxMatter struct
            for iI = 1:this.iSubstances
                
                % Creating a temporary variable to make the code more
                % readable.
                tSubstance = this.ttxMatter.(this.csSubstances{iI});
                
                % Since we are importing the data from the 'MatterData'
                % worksheet, rather than the individual worksheet, we set
                % the boolean variable indicating this to false.
                this.ttxMatter.(this.csSubstances{iI}).bIndividualFile = false;
                
                % Adding an entry to the name to index struct.
                this.tiN2I.(this.csSubstances{iI}) = iI;
                
                % If the molar mass of the substance is not directly
                % provided by the 'MatterData' worksheet, we try to
                % calculate it. This is only possible if the substance name
                % is given as a chemical formula, e.g. 'H2O' for water.
                if isempty(tSubstance.fMolarMass)
                    
                    % Extract the atomic elements from matter name
                    tElements  = this.extractAtomicTypes(this.csSubstances{iI});
                    % Saving the different elements of the substance into a
                    % cell array.
                    csElements = fieldnames(tElements);
                    
                    % Initializing the molar mass variable
                    fMolarMass   = 0;
                    
                    % Now we loop through all the elements of the
                    % substance, check if a molar mass is given, and add
                    % them up.
                    for iE = 1:length(csElements)
                        if isfield(this.ttxMatter, csElements{iE}) && isfield(this.ttxMatter.(csElements{iE}), 'fMolarMass')
                            fMolarMass = fMolarMass + tElements.(csElements{iE}) * this.ttxMatter.(csElements{iE}).fMolarMass;
                        else
                            % Throwing an error because there is no entry
                            % for this specific element
                            this.throw('table:constructor', 'No molar mass provided for element ''%s''', this.csSubstances{iI});
                        end
                    end
                    
                    % Now we add a struct with all the elements of the
                    % substance to its entry in the ttxMatter struct.
                    this.ttxMatter.(this.csSubstances{iI}).tElements  = tElements;
                    this.ttxMatter.(this.csSubstances{iI}).fMolarMass = fMolarMass;
                    
                else
                    
                    % If the molar mass is directly given, then we can
                    % just use the given value.
                    fMolarMass = tSubstance.fMolarMass;
                    
                end
                
                % And finally we create an entry in the molar mass array.
                this.afMolarMass(iI) = fMolarMass;
                
            end
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Importing from individual substance files %%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Now we import all of the data contained in the individual
            % substance files. The NIST Scraper tool creates a data file
            % that contains the information on how many and which
            % substances have individual files. So the first thing to do is 
            % to read this file.
            
            iFileID = fopen(strrep('+matter/+data/+NIST/NIST_Scraper_Data.csv', '/', filesep));
            csInput = textscan(iFileID, '%s', 'Delimiter','\n');
            csInput = csInput{1};
            sInput_1  = csInput{1};
            csSubstances = textscan(sInput_1,'%s','Delimiter',',');
            csSubstances = csSubstances{1};
            
            fclose(iFileID);
            
            for iI = 1:length(csSubstances)
                
                % Getting the substance name
                sSubstanceName = csSubstances{iI};
                
                % Calling the importMatterData method with the substance
                % name as the single parameter. It will be used by the
                % method to identify the individual files.
                this.ttxMatter.(sSubstanceName) = importMatterData(sSubstanceName);
                
                % Now we need to update some of the global information
                if ~any(strcmp(this.csSubstances, sSubstanceName))
                    
                    % First we increment the total number of substances
                    this.iSubstances = this.iSubstances+1;
                    
                    % Write new substancename into the cellarray
                    this.csSubstances{this.iSubstances} = sSubstanceName;
                    
                    % Add index of new substance to name to index struct
                    this.tiN2I.(sSubstanceName) = this.iSubstances;
                    
                    % Write molar mass of substance into molar mass array
                    this.afMolarMass(this.iSubstances) = this.ttxMatter.(sSubstanceName).fMolarMass;
                end
            end
            
            % Get list of substance indices.
            this.csI2N = fieldnames(this.tiN2I);
            
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Adding nutritional data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % The actual substances are also included in 'MatterData.csv',
            % this part of the code adds the nutritional data to these
            % substances. 
            
            % read from .csv file
            this.ttxNutrientData = importNutrientData();
            
            % get all edible substances
            this.csEdibleSubstances = fieldnames(this.ttxNutrientData);
            
            %%%%%%%%%%%%
            % WARNING! %
            %%%%%%%%%%%%
            
            % right now, Drybean has been substituted with values from
            % Kidney Beans and Redbeets have been substituted with Beets.
            % BVAD uses those substances but they are not listed on the
            % USDA Food Database as of time of writing.
            % Nutrients are always linked to the USDA NDB No. (iUSDAID in
            % the file), so check that if unsure!
            
            %%%%%%%%%%%%
            
            % loop over all edible substances
            for iJ = 1:length(this.csEdibleSubstances)
                try
                    if strcmp(this.csEdibleSubstances{iJ}, this.csSubstances{this.tiN2I.(this.csEdibleSubstances{iJ})})
                        this.ttxMatter.(this.csEdibleSubstances{iJ}).txNutrientData = this.ttxNutrientData.(this.csEdibleSubstances{iJ});
                    end
                catch
                    % substance not represented in matter table, but not an
                    % issue as long as this food type is not used in sim
                end
            end
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Adding absorber data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % The actual substances are also included in 'MatterData.csv',
            % this part of the code adds the absorber data to these
            % substances. 
            this.importAbsorberData();
            
             
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Saving the data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Now we save the data into a .mat file, so if the matter table
            % doesn't change, we don't have to run through the entire
            % constructor again. To do this, we just place the entire table
            % object into the file.
            
            % Creating the file name
            filename = strrep('data\MatterData.mat', '\', filesep);
            save(filename, 'this', '-v7');
            
            % Now we are done. All of the data has been written into the
            % matter table and the data has been saved for future use.
            % Let the simulations begin!
            
        end
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Helper methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        
        function csSubstanceList = getSubstancesFromVector(this, mfSubstances)
            csSubstanceList = this.asI2N(mfSubstances ~= 0);
        end
        
        function mbAreInside = areSubstancesInVector(this, csSubstances, mfSubstances)
            csSubstanceList = this.getSubstancesFromVector(mfSubstances);
            if ~iscell(csSubstances)
                csSubstances = {csSubstances};
            end
            iNumSubstances = numel(csSubstances);
            mbAreInside = false(iNumSubstances, 1);
            for i = 1:iNumSubstances
                mbAreInside(i) = any(strcmp(csSubstances{i}, csSubstanceList));
            end
        end
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Methods for handling of related phases and flows %%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function afMass = addPhase(this, oPhase)
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
                if isempty(this.aoPhases)
                    this.aoPhases = oPhase;
                else
                    this.aoPhases(end + 1) = oPhase;
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
        
        function afMass = addFlow(this, oFlow)
            % Add flow
            %disp('Add flow')
            if ~isa(oFlow, 'matter.flow')
                this.throw('addFlow', 'Provided object does not derive from or is a matter.flow');
            end
            
            % Preset with default: if phase not added, same vector returned
            afMass = oFlow.arPartialMass;
            
            if ~any(this.aoFlows == oFlow)
                this.aoFlows(length(this.aoFlows) + 1) = oFlow;
                
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
                % Well, this works fine, but if you convert the lower case
                % 'i' to a number using str2double MATLAB will read it as a
                % number in the sense of the square root of -1...
                % So we check if it is the letter 'i'... Usually that is
                % not a number associated with the number of atoms in a
                % molecule...
                if strcmp(sCurrentChar,'i')
                    bIsNaN = true;
                end
                
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
                        if isempty(sAtomCount), sAtomCount = '1'; end
                        
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
                if isempty(sAtomCount), sAtomCount = '1'; end
                
                % Now we can create the entry for the element in
                % the output struct using sCurrentElement as key and
                % sAtomCount as value, after we've converted it into a
                % number, of course.
                tElements.(sCurrentElement) = str2double(sAtomCount);
            end
        end
    end
end
