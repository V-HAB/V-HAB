classdef table < base
    %MATTERTABLE Summary of this class goes here
    %   Detailed explanation goes here
    %
    % MatterTable properties:
    %   tiN2I           - Struct to map the bu,md to blah
    %   afMolMass       - Vector with mol masses for each species,
    %                     extracted on initializion from ttxMatter
    %
    %TODO
    %   - heat capacity etc temperature dependent ...?
    %   - heat/thermal conductivity
    %   - heat transfer coefficient between matter types, phases? provide
    %     that directly to a processor added between two phases?
    %   -> values dependant from temp, phase, ... -> different ways to
    %      provide them, e.g. lookup tables etc
    %      Each e.g. flow than has to specificly call MT and calculate heat
    %      capacity if needed.
    %
    %   - import matter info from different sources -> ttxMatter not static
    %   - "meta" matter whose parameters are not defined that specificly?
    %     e.g. generic food types/contents for human

    properties (Constant = true, GetAccess = public)
        % Some constants
        %
        %   - gas constant (R_m) in J/(K Mol)
        %   - gravitational constant (fG) in 10^-11 m^3/(kg s^2)
        %   - Avogadro constant (fN_A) in 10^23 1/Mol
        %   - Boltzmann constant (fk_B) in 10^-23 J/K
        C = struct( ...
            'R_m', 8.314472, ...
            'fG', 6.67384, ...
            'fN_A', 6.02214129, ...
            'fk_B', 1.3806488 ...
        );
    end
    
    %QUESTION: Why can't these be included with the constant properties
    %above?
    %ANSWER: because now we create these dynamically on construction!
    properties (SetAccess = protected, GetAccess = public)
        % Mapping of species names to according index, cell with species
        % names and total amount of species
        %tiN2I = {'O2';'N2';'H2O';'CO2';'KO2';'KOH'};
        %tiN2I = struct('O2', 1, 'N2', 2, 'H2O', 3, 'CO2', 4, 'KO2', 5, 'KOH', 6);
        tiN2I;
        
        % cellarray of all saved species
        csSpecies;
        
        % number of species in phase
        iSpecies;
        
        % all proptertys and data for all species is stored in this struct
        ttxMatter;
        
        % Store the names of all Worksheets in file Matter.xlsx; used in function FindProperty
        % to look if maybe 'better'/new data than that in MatterData are saved for that species
        asWorksheets
        
        % caching of property values; used to look if last value is x%
        % other than the last run
        % fields: 
        % fT        - Temperature of Matter, used in calculateHeatCapacity
        % fP        - Pressure of Phase, used in calculateHeatCapacity
        % fMass     - Mass of Matter, used in calculateHeatCapacity
        % fCp       - HeatCapacity of Matter, used in calculateHeatCapacity
        cfLastProps = struct;
        
        % Molecular masses of the species in g/mol
        %TODO store as kg/mol so e.g. phases.gas doesn't has to convert
        %afMolMass = [32 28 18 44 72 57];
        afMolMass;
        
        % Heat capacities. Key is phase name. If value in specific matter
        % type not provided, -1 written. Same for densities.
%         tafCp;
        tafDensity;
        
        % Refernce to all phases and flows that use this matter table
        aoPhases = []; %matter.phase.empty(); % ABSTRACT - can't do that!
        aoFlows  = matter.flow.empty();
        
        % Create 'empty' (placeholder) flow (for f2f, exme procs)
        oFlowZero;
        
    end
    
    properties (SetAccess = public, GetAccess = public)
        % Limit - how much can the property of a species change before an update
        % of the matter properties is allowed?
        rMaxChange = 0.01;
        
        % liquids are considered inkompressible if this is true
        bLiquid = true;
        
        % solids are inkompressible if this is true
        bSolid = true;
        
    end
    
    methods
        function this = table(oParent, sKey)
            % constructor of class and handles calling of Mattercreation
            %
            % first execution at initialisation from class simulation with
            % no input arguments; imports worksheet MatterData
            %
            % following calls from class phase if species not found; import
            % from species worksheet if exist
            % gets matterobject from parent phaseclass and needed species
            % (sKey)
            
            % if no arguments from call received it creates the MatterData
            % from worksheet MatterData, else the Mattertableobject from
            % the parent are loaded and the arguments hand over to
            % createMatterData
            if nargin > 0
                this = oParent.oMT;
                this.createMatterData(oParent, sKey);
            else
                % Create zero/empty palceholder matter flow
                this.oFlowZero = matter.flow(this, []);
                this.createMatterData();
            end
        end
    end
    
    %% Methods for calculating matter properties %%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        function fMolecularMass = calculateMolecularMass(this, afMass)
            % Calculates the total molecular masses for a provided mass
            % vector based on the matter table. Can be used by phase, flow
            % and others to update their value.
            %
            % calculateMolecularMass returns
            %   fMolecularMass  - molecular mass of mix, g/mol
            
            fMass = sum(afMass);
            
            if fMass == 0
                fMolecularMass = 0;
                return;
            end
            
            fMolecularMass = afMass ./ fMass * this.afMolMass';
        end
        
        function fHeatCapacity = calculateHeatCapacity(this, varargin)
            % Calculates the total heat capacity, see calcMolMass. Needs
            % the whole phase object to get phase type, temperature etc
            % alternative way is hand over needed attributes manually
            %
            % calculateHeatCapacity returns
            %  fHeatCapacity  - specific heat capacity of mix, J/kgK 
            
            %TODO
            %   - enhanced Cp calculation (here or in derived class, or
            %     with some event/callback functionality?) to include the
            %     temperature dependency. Include a way to e.g. only do an
            %     actual recalculation if species masses/temperature
            %     changed more than X percent?
            fHeatCapacity = 0;
            
            % Case one - just a phase object provided
            if length(varargin) == 1
                if ~isa(varargin{1}, 'matter.phase')
                    this.throw('fHeatCapacity', 'If only one param provided, has to be a matter.phase (derivative)');
                end
                
                % initialise attributes from phase object
                sType  = varargin{1}.sType;
                sName = varargin{1}.sName;
                afMass = varargin{1}.afMass;
                fT = varargin{1}.fTemp;
                fP = varargin{1}.fPressure;
                if isempty(fP); fP = 100000; end; % std pressure (Pa)
                
                % if no mass given also no heatcapacity possible
                if varargin{1}.fMass == 0 || sum(isnan(afMass)) == length(afMass)
                    return;
                end
                

                sId    = [ 'Phase ' varargin{1}.oStore.sName ' -> ' varargin{1}.sName ];
                
            % Assuming we have two or more params, the phase type, a vector with
            % the mass of each species and current temperature and pressure
            %CHECK: As far as I can see, only matter.flow.m uses this,
            %could change that file and get rid of this if condition.
            else
                sType  = varargin{1};
                sName = 'manual'; % can anything else, just used for check of last attributes
                afMass = varargin{2};
                
                % if no mass given also no heatcapacity possible
                if sum(afMass) == 0 || sum(isnan(afMass)) == length(afMass)
                    return;
                end
                
                % if additional temperature and pressure given
                if nargin > 2
                    fT = varargin{3};
                    fP = varargin{4};
                else
                    fT = 273.15; % std temperature (K)
                    fP = 100000; % std pressure (Pa)
                end
                
                sId = 'Manually provided vector for species masses';
            end
            
            % Commented the following lines, handling of the decision
            % incompressible/compressible is done in the phases for now.
            
%             % fluids and/or solids are handled as incompressible usually
%             % can be changed over the public properties bLiquid and bSolid 
%             if strcmpi(sType, 'liquid') && this.bLiquid
%                 fP = 100000;
%             elseif strcmpi(sType, 'solid') && this.bSolid
%                 fP = 100000;
%             end
            
            % initialise attributes for next run (only done first time)
            if ~isfield(this.cfLastProps, 'fCp')
                this.cfLastProps.fT     = fT;
                this.cfLastProps.fP     = fP;
                this.cfLastProps.afMass = afMass;
                this.cfLastProps.fCp    = 0;
                this.cfLastProps.sType  = sType;
                this.cfLastProps.sName  = sName;
            end
            
            % if same Phase and Type as lasttime, it has to be checked if
            % temperature, pressure or mass has changed more than x% from
            % last time
            % percentage of change can be handled over the public property
            % rMaxChange; std is 0.01 (1%)
            if strcmp(sType, this.cfLastProps.sType) && strcmp(sName, this.cfLastProps.sName)
                aCheck{1} = [fT; this.cfLastProps.fT];
                aCheck{2} = [fP; this.cfLastProps.fP];
                aCheck{3} = [afMass; this.cfLastProps.afMass];
                aDiff = cell(1,length(aCheck));
                for i=1:length(aCheck)
                    if aCheck{i}(1,:) ~= 0
                        aDiff{i} = abs(diff(aCheck{i})/aCheck{i}(1,:));
                    else
                        aDiff{i} = 0;
                    end
                end
                % more than 1% difference (or what is defined in
                % rMaxChange) from last -> recalculate c_p and save
                % attributes for next run
                if any(cell2mat(aDiff) > this.rMaxChange) 
                    this.cfLastProps.fT = fT;
                    this.cfLastProps.fP = fP;
                    this.cfLastProps.afMass = afMass;
                else
                    fHeatCapacity = this.cfLastProps.fCp;
                    if fHeatCapacity
                        return;
                    end
                end
            else 
                    this.cfLastProps.fT = fT;
                    this.cfLastProps.fP = fP;
                    this.cfLastProps.afMass = afMass;
                    this.cfLastProps.sType = sType;
                    this.cfLastProps.sName = sName;
            end

            % look what species has mass so heatcapacity can calculated
            if any(afMass > 0) % needed? should always true because of check in firstplace
                aiIndexes = find(afMass>0);
                % go through all species that have mass and sum them up
                for i=1:length(find(afMass>0))
                    fCp = this.FindProperty(this.csSpecies{aiIndexes(i)}, 'c_p', 'Temperature', fT, 'Pressure', fP, sType);
                    %fCp = this.FindProperty(fT, fP, this.csSpecies{aiIndexes(i)}, 'c_p', sType);
                    fHeatCapacity = fHeatCapacity + afMass(aiIndexes(i)) ./ sum(afMass) * fCp;
                end
                % save heatcapacity for next run
                this.cfLastProps.fCp = fHeatCapacity;

            end
            
            % if no species has a valid heatcapacity an error trown out
            if isempty(fHeatCapacity) || isnan(fHeatCapacity)
                this.throw('calculateHeatCapacity','Error in HeatCapacity calculation!');
            end
        end
    end
    
    
    %% Methods for handling of related phases and flows %%%%%%%%%%%%%%%%%%%
    methods
        
        function afMass = addPhase(this, oPhase, oOldMT)
            % Add phase
            
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
            iInd = find(this.aoPhases == oPhase, 1); % Just find first result - phase never added twice
            
            if isempty(iInd)
                this.throw('removePhase', 'Provided phase not assinged to this matter table!');
            else
                this.aoPhases(iInd) = [];
            end
        end
        
        
        
        
        function afMass = addFlow(this, oFlow, oOldMT)
            % Add flow
            
            if ~isa(oFlow, 'matter.flow')
               this.throw('addFlow', 'Provided object does not derive from or is a matter.flow');
            end
            
            % Preset with default: if phase not added, same vector returned
            afMass = oFlow.arPartialMass;
            
            if ~any(this.aoFlows == oFlow)
                this.aoFlows(length(this.aoFlows) + 1) = oFlow;
                
                % Remap matter species?
                if (nargin > 2) && ~isempty(oOldMT)
                    if ~isa(oOldMT, 'matter.table')
                        this.throw('addFlow', 'The provided object for the old matter table is not a and doesn''t derive from matter.table');
                    end
                    
                    afMass = this.mapMassesToNewMT(oOldMT, afMass);
                end
            end
        end
        
        function this = removeFlow(this, oFlow)
            iInd = find(this.aoFlows == oFlow, 1); % Just find first result - flow never added twice
            
            if isempty(iInd)
                this.throw('removeFlow', 'Provided flow not assinged to this matter table!');
            else
                this.aoFlows(iInd) = [];
            end
        end
    
    end
    %% Protected, internal methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods (Access = protected)
        
        function afNewMass = mapMassesToNewMT(this, oOldMT, afMass)
            % Rearranges the afMass vector used in phases or flows to match
            % a new matter table. Old matter table required!
            
            afNewMass = zeros(1, this.iSpecies);
            
            for iI = 1:length(afMass)
                % Assume all species exist
                %TODO clean error catching
                afNewMass(this.tiN2I.(oOldMT.csSpecies{iI})) = afMass(iI);
            end
        end
        
    %% Methods for import of data
        function this = createMatterData(this, oParent, sKey)
            % handles import of data. At first call (at initialisation) it
            % loads the standard worksheet MatterData and save the needed
            % structures etc. If called with arguments the parent object
            % must have a field with a valid phase and the species (sKey)
            % has to be handed over
            %
            % createMatterData returns
            %  this  - oMT object 
            %
            % inputs:
            % oParent: Partent object, needed for verification of phase
            % sKey: speciesname (also worksheet name)
            
            %% Access specific worksheets in MatterXLS
            % executed if no inputs handed over
            if nargin > 1
                % call of Matterimport that imports the needed worksheetdata then 
                % it checks if correct phase from parent object is handed over
                % after that it checks also type of pressure and corrects vaulues if needed
                % fields that created at the first exection and used in other classes 
                % had to include the new species

                % import from worksheet
                this.ttxMatter.(sKey) = this.Matterimport(strrep('core\+matter\Matter.xlsx','\',filesep), sKey);
                
                % check if phase in parent object are present
                if isobject(oParent)
                    if ~isprop(oParent, 'sType')
                        this.throw('table:import','no phasetype from parent class received');
                    elseif ~any(strcmpi({'solid','gas','liquid'},oParent.sType))
                        this.trow('table:import','no valid phasetype from parent class received');
                    end
                end

                % handle Pressure values (convert bar in Pa)
                iColumn = this.FindColumn('Pressure', sKey);
                if strcmpi(this.ttxMatter.(sKey).import.text(6,iColumn), 'bar')
                    this.ttxMatter.(sKey).import.num(5:end,iColumn) = this.ttxMatter.(sKey).import.num(5:end,iColumn)*100000;
                elseif strcmpi(this.ttxMatter.(sKey).import.text(6,iColumn), 'Pa')
                    % nothing, all good
                else
                    this.throw('table:createMatterData',sprintf('Pressure-type %s unkown', this.ttxMatter.(sKey).import.text(6,iColumn)));
                end
                
                % new species, so some fields has to be extend if not already there
                if ~any(strcmp(this.csSpecies, sKey))
                    % index of new species is one times higher than last one 
                    iIndex = this.iSpecies+1;
                    % write new speciesname in cellarray
                    this.csSpecies{iIndex} = sKey;
                    % index of new species into number2index array
                    this.tiN2I.(sKey) = iIndex;
                    this.iSpecies = iIndex;
                    % molmass of species into molmass array
                    this.afMolMass(iIndex) = this.ttxMatter.(sKey).fMolMass;

                    % go through all phases (solid, gas, liquid) and write correct value in array tafCp
                    % and tafDensity from new import
                    cPhases = fieldnames(this.tafDensity);
                    for i=1:length(cPhases)
                        % if value of density is stored in fRoh and is a number and in right phase
                        if isfield(this.ttxMatter.(sKey), 'fRoh') && ~isnan(this.ttxMatter.(sKey).fRoh) && strcmp(oParent.sType, cPhases{i})
                            this.tafDensity.(cPhases{i})(iIndex) = this.ttxMatter.(sKey).fRoh;
                        else % std is -1
                            this.tafDensity.(cPhases{i})(iIndex) = -1;
                        end

                    end
                end
                                    
            else
                %% load MatterData (standard Mattertable)
                % this is executed at first (from class simulation)
                
                % import worksheet MatterData
                this.ttxMatter = this.Matterimport(strrep('core\+matter\Matter.xlsx','\',filesep), 'MatterData');
            
                % get all species
                this.csSpecies = fieldnames(this.ttxMatter);
                % get number of species
                this.iSpecies  = length(this.csSpecies);

                % preallocation
                this.afMolMass = zeros(1, this.iSpecies);
                this.tiN2I     = struct();

                % write attributes of all species
                for iI = 1:this.iSpecies
                    % Configuration
                    tCfg = this.ttxMatter.(this.csSpecies{iI});

                    % Name to index
                    this.tiN2I.(this.csSpecies{iI}) = iI;


                    % Molecular mass - directly provided
                    if isfield(tCfg, 'fMolMass')
                        this.afMolMass(iI) = tCfg.fMolMass(1);

                    else
                        % Extract the atomic elements from matter name and
                        % check if molecular mass provided for each of them
                        tElements  = matter.table.extractAtomicTypes(this.csSpecies{iI});
                        csElements = fieldnames(tElements);
                        b404       = isempty(csElements);
                        fMolMass   = 0;

                        if ~b404
                            for iE = 1:length(csElements)
                                % Check if element exists and has mol mass def
                                if isfield(this.ttxMatter, csElements{iE}) || isfield(this.ttxMatter.(csElements{iE}), 'fMolMass')
                                    %this.Mattertable.ttxMatter, csElements{iE}
                                    fMolMass = fMolMass + tElements.(csElements{iE}) * this.ttxMatter.(csElements{iE}).fMolMass;
                                else
                                    b404 = true;
                                    break;
                                end
                            end
                        end

                        if b404
                            % Some elements not found so reset (might be there
                            % from previous calcs?)
                            if isfield(this.ttxMatter.(this.csSpecies{iI}), 'tComponents')
                                this.ttxMatter.(this.csSpecies{iI}).tComponents = struct();
                            end

                            %this.throw('createMatterData', 'Type %s has no molecular mass provided and not all elements of matter type (molecule) could be found to calculate molecular mass', this.csSpecies{iI});
                            this.afMolMass(iI) = -1;
                        else
                            % Write components on matter definition
                            this.ttxMatter.(this.csSpecies{iI}).tComponents = tElements;
                            this.afMolMass(iI) = fMolMass;
                        end
                    end

                    % Go through phases and write density/heat capacity
                    if isfield(tCfg, 'ttxPhases')
                        csPhases = fieldnames(tCfg.ttxPhases);

                        for iP = 1:length(csPhases)
                            sP = csPhases{iP};

                            % densities phase not there yet? Preset with -1
                            if ~isfield(this.tafDensity, sP)
                                this.tafDensity.(sP) = -1 * ones(1, this.iSpecies);
                            end

                            % Density given?
                            if isfield(tCfg.ttxPhases.(sP), 'fDensity')
                                this.tafDensity.(sP)(iI) = tCfg.ttxPhases.(sP).fDensity;
                            end
                        end
                    end

                end
            end
        end
        
        function ttxImportMatter = Matterimport(this, sFile, sIndex)
            % importfunction that handles import from species worksheet for
            % one species or at initialisation the import from worksheet
            % MatterData
            % first it looks if speciesdata is already importet (for a specific species)
            % after import with xlsread it gets the data in the right
            % format for later use
            %
            % Matterimport returns
            %  ttxImportMatter - struct with all data
            %
            % inputs
            % sFile: complete filename of MatterXLS
            % sIndex: worksheet/species name
            
            % store all worksheets form excelfile and look if file is readable
            % worksheetnames used in FindProperty to look if maybe more
            % data is availeable
            [sStatus, this.asWorksheets] = xlsfinfo(sFile);
            if ~any(strcmp(sStatus, {'Microsoft Excel Spreadsheet', 'Microsoft Macintosh Excel Spreadsheet'}))
                this.throw('table:Matterimport',sprintf('File %s has wrong format for Matterimport',sFile));
            end
            
            %% import worksheet MatterData (standard Mattertable)
            % this is executed at first (from class simulation)
            if strcmp(sIndex, 'MatterData') && any(strcmpi(this.asWorksheets, 'MatterData'))
                % import of worksheet
                [import.num, import.text, import.raw] = xlsread(sFile, sIndex);
                % store tablelength and column of density ("codename" of first property to store in phase) to save all properties
                % search for empty cell in first row; column before is last Tablecolumn
                [~, emptyColumns] = find(strcmp(import.text(1,:),''));
                iTableLength = emptyColumns(1)-1;
                iColumn = find(strcmp(import.text(2,:),'fDensity'));
                % only unique species are needed
                scSpecies = unique(import.text(3:end,1)); 
                % construct the struct in which all species are later stored
                ttxImportMatter = struct;
                % go through all unique species
                for i = 1:length(scSpecies)
                    % set speciesname as fieldname
                    ttxImportMatter = setfield(ttxImportMatter, scSpecies{i},'');
                    
                    % select all rows of that species
                    % species can have more than one phase
                    iRow = find(strcmp(import.text(3:end,1),scSpecies{i})); 
                    %disp(scSpecies{i});
                    if ~isempty(iRow)
                        % rownumbers of .num and .text/.raw are 2 rows different because of headers
                        iRow = iRow +2;
                        ttxImportMatter.(scSpecies{i}).import.num = import.num(iRow-2,:);
                        ttxImportMatter.(scSpecies{i}).import.num(:,iTableLength+1:end) = []; % overhead not needed
                        ttxImportMatter.(scSpecies{i}).import.text = import.text(1:2,:);
                        ttxImportMatter.(scSpecies{i}).import.text = [ttxImportMatter.(scSpecies{i}).import.text; import.text(iRow,:)];
                        ttxImportMatter.(scSpecies{i}).import.text(:,iTableLength+1:end) = []; % overhead not needed
                        ttxImportMatter.(scSpecies{i}).import.raw = import.raw(1:2,:);
                        ttxImportMatter.(scSpecies{i}).import.raw = [ttxImportMatter.(scSpecies{i}).import.raw; import.raw(iRow,:)];
                        ttxImportMatter.(scSpecies{i}).import.raw(:,iTableLength+1:end) = []; % overhead not needed
                        % go through all properties before density
                        for j = 4:iColumn-1
                            if ~isnan(import.num(iRow(1)-2,j-3))
                                ttxImportMatter.(scSpecies{i}).(import.text{2,j}) = import.num(iRow(1)-2,j-3);
                            end
                        end
                        % go through phases and save all remaining properties for that phase
                        for z = 1:length(iRow) 
                            for j = iColumn:iTableLength 
                                if ~isnan(import.num(iRow(z)-2,j-3))
                                    ttxImportMatter.(scSpecies{i}).ttxPhases.(import.text{iRow(z),3}).(import.text{2,j}) = import.num(iRow(z)-2,j-3);
                                end
                            end

                        end
                        
                    end
                end
            %% import specific species worksheet
            else
                % first look if data is not already imported
                if ~isfield(this.ttxMatter, sIndex)
                    % import worksheet
                    [import.num, import.text, import.raw] = xlsread(sFile, sIndex);
                    % save data for later use
                    ttxImportMatter.import.text = import.text;
                    ttxImportMatter.import.num = import.num;
                    ttxImportMatter.import.raw = import.raw;
                    ttxImportMatter.SpeciesName = import.text{1,1};
                    % get length of columns
                    iTableLength = size(import.text,2);
                    % save all constants of species defined in first four rows 
                    for i = 4:iTableLength
                        if ~isempty(import.text{3,i}) &&  ~isnan(import.num(1,i))
                            ttxImportMatter.(import.text{3,i}) = import.num(1,i);
                        end
                    end
                    % numeric import is mostly minor than other because in
                    % the first lines are often no numbers
                    % for easier handling in later functions get this the
                    % same size
                    iLengthRaw = size(import.raw,1);
                    iLengthNum = size(import.num,1);
                    if iLengthRaw > iLengthNum
                        afNewArray(iLengthRaw,size(import.num,2)) = 0;
                        afNewArray(:,:) = nan;
                        afNewArray((iLengthRaw-iLengthNum)+1:end,:) = ttxImportMatter.import.num;
                        ttxImportMatter.import.num = afNewArray;
                    end
                % check size of imported data (data from MatterData has max
                % size of 5)
                elseif length(this.ttxMatter.(sIndex).import.raw(:,1)) < 6
                    % save data from worksheet MatterData
                    ttxImportMatter.MatterData.raw = this.ttxMatter.(sIndex).import.raw;
                    ttxImportMatter.MatterData.num = this.ttxMatter.(sIndex).import.num;
                    ttxImportMatter.MatterData.text = this.ttxMatter.(sIndex).import.text;
                    % import from species worksheet
                    [import.num, import.text, import.raw] = xlsread(sFile, sIndex);
                    % save data for later use
                    ttxImportMatter.import.text = import.text;
                    ttxImportMatter.import.num = import.num;
                    ttxImportMatter.import.raw = import.raw;
                    ttxImportMatter.SpeciesName = import.text{1,1};
                    iTableLength = size(import.text,2);
                    % save all constants of species defined in first four rows 
                    for i = 4:iTableLength
                        if ~isempty(import.text{3,i}) &&  ~isnan(import.num(1,i))
                            ttxImportMatter.(import.text{3,i}) = import.num(1,i);
                        end
                    end
                    % numeric import is mostly minor than other because in
                    % the first lines are often no numbers
                    % for easier handling in later functions get this the
                    % same size
                    iLengthRaw = size(import.raw,1);
                    iLengthNum = size(import.num,1);
                    if iLengthRaw > iLengthNum
                        afNewArray(iLengthRaw,size(ttxImportMatter.import.num,2)) = 0;
                        afNewArray(:,:) = nan;
                        afNewArray((iLengthRaw-iLengthNum)+1:end,:) = ttxImportMatter.import.num;
                        ttxImportMatter.import.num = afNewArray;
                    end
                % data is already imported -> get back
                else
                    return;
                end
                
                % look if some values safed as kJ -> has to convert do J (*1000)
                iTableLength = size(ttxImportMatter.import.text,2);
                for i = 1:iTableLength
                    if strncmp(ttxImportMatter.import.text{6,i}, 'kJ', 2)
                       ttxImportMatter.import.text{6,i} = strrep(ttxImportMatter.import.text{6,i}, 'kJ', 'J');
                       ttxImportMatter.import.num(:,i) = ttxImportMatter.import.num(:,i)*1000;
                    end
                end
                                
            end
        end
        
    %% helper methods
        function [iColumn, iTableLength] = FindColumn(this, sPropertyName, sSpecies, iRow)
            % most used function (call often in loops)
            % finds the column of a property and if wished the columnlength of
            % the table
            %
            % FindColumn returns
            %  iColumn - number of column
            %  iTableLength - length of table
            %
            % inputs:
            % sPropertyName: name of searched property
            % sSpecies: speciesname
            % iRow: rownumber in which the search string stays, optional
            
            % only calculate tablelength if is searched too
            if nargout == 2
                iTableLength = size(this.ttxMatter.(sSpecies).import.text,2);
            end
            
            % if rownumbers is also given
            if nargin > 3 && ~isempty(iRow)
                    iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(iRow,:),sPropertyName));
                    return
            else
                % if raw data has max 5 rows it has to be from worksheet MatterData (2 lines heading +max 3 phases)
                if length(this.ttxMatter.(sSpecies).import.raw(:,1)) > 5
                    iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(5,:),sPropertyName)); % row 5 is std propertyname
                    if isempty(iColumn)
                        iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(7,:),sPropertyName)); % search row 7 as alternative
                    end
                    return
                else
                    if strcmpi(sPropertyName,'c_p'); sPropertyName = 'SHC'; end;
                    iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(1,:),sPropertyName)); % row 1 is std propertyname in MatterData
                    if isempty(iColumn)
                        iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(2,:),sPropertyName)); % search row 2 as alternative
                    end
                    return
                end
            end
        end
        
        function [fMin, fMax] = FindRange(this, sSpecies, xForProp)
            % looks what maximum and minimum values are in a column
            % used in FindProperty to look if searched values are in range
            % of the given worksheetdata
            %
            % FindRange returns
            %  fMin: minimum value of column
            %  fMax: maximum value of column
            %
            % inputs:
            % sSpecies: speciesname
            % xForProp: string of property or number of column
            
            % depending on the input, look for column or property
           if ischar(xForProp)
               iColumn = this.FindColumn(xForProp, sSpecies);
           elseif isnumeric(xForProp)
               iColumn = xForProp;
           else
               this.thow('table:FindRange','Wrong input');
           end
           
           % only look for maximum values if searched too
           if nargout == 2
               % get maximum value
               fMax = max(this.ttxMatter.(sSpecies).import.num(:,iColumn));
           end
           % get minimum value
           fMin = min(this.ttxMatter.(sSpecies).import.num(:,iColumn));
        end
        
        % old FindProperty
        % not used at moment
        function fProperty = FindProperty_old(this, fT, fP, sSpecies, sProperty, sPhase)
            % fT: temperature
            % fP: pressure
            % sSpecies: species name for which property is searched
            % sProperty: name of the searched property
            % sPhase: phasetype, optional
            
            fProperty = 0;
            if nargin < 5
                sPhase = [];
            end
            if isempty(fT)
                fT = 273.15; % std temperature
            end
            if isempty(fP) || isnan(fP)
                fP = 100000; % std pressure (Pa)
            end
            % check if Species is already imported
            if ~isfield(this.ttxMatter, sSpecies)
                this.createMatterData([], sSpecies);
            end
            
            
            iColumn = this.FindColumn(sProperty, sSpecies);
            % property c_p are often written as SHC (Are they the same
            % values?
            if isempty(iColumn) && strcmp(sProperty, 'c_p')
                iColumn = this.FindColumn('SHC', sSpecies);
            end
            % property is not in worksheet
            if isempty(iColumn)
                this.throw('table:FindProperty',sprintf('Can´t find property %s in worksheet %s', sProperty, sSpecies));
            end
            
            iRowsP = [];
            if strcmpi(sPhase, 'solid') && this.bSolid
                iColumnPhase = this.FindColumn('Phase',sSpecies);
                iRowsP = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,iColumnPhase), 'solid'));
                fP = 100000;
            elseif strcmpi(sPhase, 'liquid') && this.bLiquid
                iColumnPhase = this.FindColumn('Phase',sSpecies);
                iRowsP = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,iColumnPhase), 'liquid'));
                fP = 100000;
            end
                    
            % over 3 rows in import.num only possible if not from worksheet
            % MatterData (max 3 phases)
            if length(this.ttxMatter.(sSpecies).import.num(:,1)) > 3
                % for checking of temp or pres out of table values
                abOutOfRange = [false; false];

                % look if data is in range of table
                [fMin, fMax] = this.FindRange(sSpecies, 'fP');
                if fP > fMax
                    fP = fMax;
                    abOutOfRange(1) = true;
                    %disp('fPmax');
                elseif fP < fMin
                    fP = fMin;
                    abOutOfRange(1) = true;
                    %disp(sprintf('fPmin %s', sSpecies));
                end
                [fMin, fMax] = this.FindRange(sSpecies, 'fT');
                if fT > fMax
                    fT = fMax;
                    abOutOfRange(2) = true;
                    %disp('fTmax');
                elseif fT < fMin
                    fT = fMin;
                    abOutOfRange(2) = true;
                    %disp('fTmin');
                end
                
                if isempty(iRowsP)
                    % look if pressure is stored
                    iRowsP = find(this.ttxMatter.(sSpecies).import.num(:,3) == fP);
                end
                % look if temperature is stored
                iRowsT = find(this.ttxMatter.(sSpecies).import.num(:,2) == fT);
                if ~any(iRowsP) && ~(abOutOfRange(1) || abOutOfRange(2))
                    % pressure not in table
                    if any(iRowsT)
                        % temperature found -> interpolation only over pressure
                        temp = this.ttxMatter.(sSpecies).import.num(iRowsT,:);
                        temp = sortrows(temp,3);
                        [~,rows,~] = unique(temp(:,3),'rows');
                        temp = temp(rows,:); %!% temp speichern damit nicht für alle spalten neu ausgeführt werden muss?
                        fProperty = interp1(temp(:,3),temp(:,iColumn),fP); %interp1(fPressure, fProperty, fP) 
                    else
                        % interpolation over temperature and pressure needed
                        temp = this.ttxMatter.(sSpecies).import.num;
                        temp(1:4,:) = [];
                        % noch nicht das Gelbe vom Ei :(
                        fProperty = griddata(temp(:,2),temp(:,3),meshgrid(temp(:,iColumn)),fT,fP);
                        if fProperty < min(temp(:,iColumn)) || fProperty > max(temp(:,iColumn))
                            fprintf(2,'out of range for species %s',sSpecies,' -> []');
                            fProperty = [];
                        end
                        
                    end
                elseif ~(abOutOfRange(1) || abOutOfRange(2))
                    % pressure in table
                     if any(iRowsT)
                        % pressure and temperature given -> no interpolation needed
                        fProperty = this.ttxMatter.(sSpecies).import.num((this.ttxMatter.(sSpecies).import.num(:,2) == fT & this.ttxMatter.(sSpecies).import.num(:,3) == fP), iColumn);
                     else
                        % temperature not in table -> interpolation over temperature needed
                        temp = this.ttxMatter.(sSpecies).import.num(iRowsP,:);
                        temp = sortrows(temp,2);
                        [~,rows] = unique(temp(:,2),'rows');
                        temp = temp(rows,:); %!% temp speichern damit nicht für alle spalten neu ausgeführt werden muss?
                        fProperty = interp1(temp(:,2),temp(:,iColumn),fT);
                     end
                end

                % when no property is found, look if maybe better data is stored from worksheet MatterData
                if (isempty(fProperty) || isnan(fProperty) || fProperty == 0) && isfield(this.ttxMatter.(sSpecies), 'MatterData')
                    
                    rowPhase = find(strcmpi(this.ttxMatter.(sSpecies).MatterData.text(:,3), sPhase), 1, 'first');
                    if isempty(rowPhase)
                        fProperty = 0;
                    else
                        iColumn = find(strcmp(this.ttxMatter.(sSpecies).MatterData.text(1,:), sPropertyName)); % row 1 is std propertyname in MatterData
                        if isempty(iColumn) && strcmp(sProperty, 'c_p')
                            iColumn = find(strcmp(this.ttxMatter.(sSpecies).MatterData.text(1,:), 'SHC')); 
                        end
                        fProperty = this.ttxMatter.(sSpecies).MatterData.num(rowPhase-2,iColumn-3);
                    end
                end
            elseif isfield(this.ttxMatter.(sSpecies), 'MatterData')
                    rowPhase = find(strcmpi(this.ttxMatter.(sSpecies).MatterData.text(:,3), sPhase), 1, 'first');
                    if isempty(rowPhase)
                        fProperty = 0;
                    else
                        fProperty = this.ttxMatter.(sSpecies).MatterData.num(rowPhase-2,iColumn-3);
                    end
                
            else
                % look if a worksheet of that species exist when not std atm. or no phase is stored
                rowPhase = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,3), sPhase), 1, 'first');
                if isempty(rowPhase)
                    if any(strcmpi(this.asWorksheets, sSpecies))
                        this.createMatterData([], sSpecies);
                        fProperty = this.FindProperty(sSpecies, sProperty, 'Temperature', fT, 'Pressure', fP, sPhase);
                        %fProperty = this.FindProperty(fT, fP, sSpecies, sProperty, sPhase);
                    else
                        fProperty = 0;
                    end
                else
                    fProperty = this.ttxMatter.(sSpecies).import.num(rowPhase-2,iColumn-3);
                end
            end
            if isnan(fProperty); fProperty = 0; end;
        end
 
        % same as old FindProperty but indepentent of special dependency
        % (not only Temp and/or Pres dependency)
        % e.g. this.FindProperty('CO2','c_p','Pressure',120000,'alpha',0.15,'liquid') 
        function fProperty = FindProperty(this, sSpecies, sProperty, sFirstDepName, fFirstDepValue, sSecondDepName, fSecondDepValue, sPhase)
            % search for property values for specific dependency-values 
            % one dependency is needed and a second one is optional
            % interpolates given worksheetdata if not in worksheet MatterData
            %
            % FindProperty returns
            %  fProperty - (interpolated) value of searched property
            %
            % inputs:
            % sSpecies: speciesname for structfield
            % sProperty: propertyname for column
            % sFirstDepName: name of dependency 1 for column, e.g. 'Temperature'
            % sFirstDepValue: value of dependency 1
            % sSecondDepName: name of dependency 2 for column, e.g. 'Pressure', optional
            % sFirstDepValue: value of dependency 2, optional
            % sPhase: phase for row in MatterData, optional
            
            fProperty = 0;
            % check inputs on correctness
            switch nargin
                case 8 
                    % check if all inputs have correct type
                    if ~ischar(sSpecies) || ~ischar(sProperty) || ~(ischar(sFirstDepName) || isempty(sFirstDepName)) || ~isnumeric(fFirstDepValue) || ~(ischar(sSecondDepName) || isempty(sSecondDepName)) || ~isnumeric(fSecondDepValue) || ~ischar(sPhase) || ~ischar(sSpecies)
                        this.trow('table:FindProperty','Some inputs have wrong type');
                    else
                        % number of dependencies
                        iDependencies = 2;
                    end
                case 7
                    % check if all inputs have correct type
                    if ~ischar(sSpecies) || ~ischar(sProperty) || ~(ischar(sFirstDepName) || isempty(sFirstDepName)) || ~isnumeric(fFirstDepValue) || ~(ischar(sSecondDepName) || isempty(sSecondDepName)) || ~isnumeric(fSecondDepValue) || ~ischar(sSpecies)
                        this.trow('table:FindProperty','Some inputs have wrong type');
                    else
                        % number of dependencies
                        iDependencies = 2;
                    end
                case 6 
                    % check if sPhase is given
                    if isa(sSecondDepName, 'char') && strcmpi({'solid','liquid','gas'}, sSecondDepName)
                        sPhase = sSecondDepName;
                        sSecondDepName = [];
                        iDependencies = 1;
                    else
                        this.throw('table:FindProperty','Input phase is not correct');
                    end
                case 5
                    % check if value of first dependency is numeric
                    if isnumeric(fFirstDepValue)
                        sSecondDepName = [];
                        sPhase = [];
                        iDependencies = 1;
                    else
                        this.trow('table:FindProperty','Wrong inputtype for first dependency');
                    end
                otherwise
                    % at least one dependency has to be given over
                    this.trow('table:FindProperty','Not enough inputs');
            end
            
            % check if dependencies are valid; if only second valid -> handle it to firstdep
            if isempty(sFirstDepName) && ~(isempty(sSecondDepName) || isnan(sSecondDepName))
                sFirstDepName = sSecondDepName;
                sSecondDepName = [];
                fFirstDepValue = fSecondDepValue;
                fSecondDepValue = [];
                iDependencies = 1;
            end
            % last check on correctness
            if isempty(sFirstDepName) || ~isa(sFirstDepName,'char') || isempty(fFirstDepValue)
                this.throw('table:FindProperty',sprintf('no valid dependency was transmitted for property %s',sProperty));
            end
            
            % check if Species is already imported
            if ~isfield(this.ttxMatter, sSpecies)
                this.createMatterData([], sSpecies);
            end
            
            % get column of searched property
            iColumn = this.FindColumn(sProperty, sSpecies);
            % property c_p are often written as SHC (Are they the same values?)
            if isempty(iColumn) && strcmp(sProperty, 'c_p')
                iColumn = this.FindColumn('SHC', sSpecies);
            end
            % if no column found, property is not in worksheet
            if isempty(iColumn)
                this.throw('table:FindProperty',sprintf('Can´t find property %s in worksheet %s', sProperty, sSpecies));
            end
            
            iRowsFirst = [];
            % get column of first dependency
            iColumnFirst = this.FindColumn(sFirstDepName, sSpecies);
            % sometimes property Temperature are given 2 times (C and K)
            % second column is used
            if length(iColumnFirst) > 1 && strcmpi(sFirstDepName, 'Temperature')
                iColumnFirst = iColumnFirst(2);
            end
            % handling of incompressible phases
%             if strcmpi(sPhase, 'solid') && this.bSolid
%                 iColumnPhase = this.FindColumn('Phase',sSpecies);
%                 iRowsFirst = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,iColumnPhase), 'solid'));
%             elseif strcmpi(sPhase, 'liquid') && this.bLiquid
%                 iColumnPhase = this.FindColumn('Phase',sSpecies);
%                 iRowsFirst = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,iColumnPhase), 'liquid'));
%             end
                    
            % over 3 rows in import.num only possible if not from worksheet
            % MatterData (max 3 phases)
            if size(this.ttxMatter.(sSpecies).import.num,1) > 3
                % initialise array for checking if dependencies are out of table values
                abOutOfRange = [false; false];

                % look if data for first dependency is in range of table
                [fMin, fMax] = this.FindRange(sSpecies, sFirstDepName);
                if fFirstDepValue > fMax
                    fFirstDepValue = fMax;
                    abOutOfRange(1) = true;
                    %disp('fPmax');
                elseif fFirstDepValue < fMin
                    fFirstDepValue = fMin;
                    abOutOfRange(1) = true;
                    %disp(sprintf('fPmin %s', sSpecies));
                end
                % some checks only needed if second dependency is given
                if iDependencies == 2
                    % look if data for second dependency is in range of table
                    [fMin, fMax] = this.FindRange(sSpecies, sSecondDepName);
                    if fSecondDepValue > fMax
                        fSecondDepValue = fMax;
                        abOutOfRange(2) = true;
                        %disp('fTmax');
                    elseif fSecondDepValue < fMin
                        fSecondDepValue = fMin;
                        abOutOfRange(2) = true;
                        %disp('fTmin');
                    end
                    % get column of second dependency
                    iColumnSecond = this.FindColumn(sSecondDepName, sSpecies);
                    % get columns with already given values of searched second dependency
                    iRowsSecond = find(this.ttxMatter.(sSpecies).import.num(:,iColumnSecond) == fSecondDepValue);
                end
                
                
                if isempty(iRowsFirst)
                    % get columns with already given values of searched first dependency
                    % sometimes it doesn´t find it right, why?
                    iRowsFirst = find(this.ttxMatter.(sSpecies).import.num(:,iColumnFirst) == fFirstDepValue);
                end
                % only one dependency
                if iDependencies == 1
                    % check if is in range of table
                    if ~isempty(iRowsFirst) && ~abOutOfRange(1)
                        % dependencyvalue in table
                        % direct usage
                        fProperty = this.ttxMatter.(sSpecies).import.num((this.ttxMatter.(sSpecies).import.num(iRowsFirst,iColumnFirst) == fFirstDepValue), iColumn);
                    elseif ~abOutOfRange(1)
                        % only in range of table
                        % interpolation needed
                        % create a temporary array because inperp1 need
                        % stricly monotonic increasing data
                        afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst]);
                        afTemporary = sortrows(afTemporary,2);
                        [~,rows] = unique(afTemporary(:,2),'rows');
                        afTemporary = afTemporary(rows,:); %!% temp speichern damit nicht für alle spalten neu ausgeführt werden muss?
                        fProperty = interp1(afTemporary(:,2),afTemporary(:,1),fFirstDepValue); % interp1(aFirstDepValue, aProperty, fFirstDepValue) 
                    else
                        % dependencyvalue is out of range 
                        % look if phase of species is in MatterData
                        iRowsFirstMatterData = find(strcmpi(this.ttxMatter.(sSpecies).MatterData.text(:,3), sPhase), 1, 'first');
                        if isempty(iRowsFirstMatterData)
                            % not in MatterData 
                            % get 'best' value in Range of speciestable
                            fProperty = this.ttxMatter.(sSpecies).import.num((this.ttxMatter.(sSpecies).import.num(iRowsFirst,iColumnFirst) == fFirstDepValue), iColumn);
                        else
                            % get the data from the MatterDataworksheet
                            % get column of property
                            iColumn = find(strcmp(this.ttxMatter.(sSpecies).MatterData.text(1,:), sPropertyName)); % row 1 is std propertyname in MatterData
                            if isempty(iColumn) && strcmp(sProperty, 'c_p')
                                % if heatcapacity (c_p) is searched, it is written as SHC in MatterData
                                iColumn = find(strcmp(this.ttxMatter.(sSpecies).MatterData.text(1,:), 'SHC')); 
                            end
                            % get the propertyvalue
                            fProperty = this.ttxMatter.(sSpecies).MatterData.num(iRowsFirstMatterData-2,iColumn-3);
                        end
                    end
                else
                    % two Dependencies
                    % look if both dependencies are in range of table
                    if ~(abOutOfRange(1) || abOutOfRange(2))
                        if ~isempty(iRowsFirst) && ~isempty(iRowsSecond) && intersect(iRowsFirst,iRowsSecond)
                            % both dependency directly given
                            % get propertyvalue
                            fProperty = this.ttxMatter.(sSpecies).import.num(intersect(iRowsFirst,iRowsSecond), iColumn);
                        else
                            % dependency not directly given
                            % interpolation over both dependencies needed
                            % create temporary array because inperpolation
                            % doesn´t allow nan values
                            afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                            afTemporary(isnan(afTemporary)) = 0;
                            afTemporary = sortrows(afTemporary,1);
                            % noch nicht das gelbe vom ei :(griddata
                            fProperty = griddata(afTemporary(:,2),afTemporary(:,3),(afTemporary(:,1)),fFirstDepValue,fSecondDepValue);
                            % check if found propertyvalue is in range of table (no extrapolation)
                            if fProperty < min(afTemporary(:,1)) || fProperty > max(afTemporary(:,1))
                                fprintf(2,'out of range for species %s',sSpecies,' -> []');
                                fProperty = [];
                            end
                        end
                    else
                        % one or more dependencies are out of range
                        % look if data is in MatterData
                        iRowsFirstMatterData = find(strcmpi(this.ttxMatter.(sSpecies).MatterData.text(:,3), sPhase), 1, 'first');
                        if isempty(iRowsFirstMatterData)
                            % no found data in MatterData
                            % get 'best' value in Range of speciestable
                            % create temporary array because inperpolation
                            % doesn´t allow nan values
                            afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                            afTemporary(isnan(afTemporary)) = 0;
                            afTemporary = sortrows(afTemporary,1);
                            % noch nicht das gelbe vom ei :(
                            fProperty = griddata(afTemporary(:,2),afTemporary(:,3),meshgrid(afTemporary(:,1)),fFirstDepValue,fSecondDepValue);
                            % check if found propertyvalue is in range of table (no extrapolation)
                            if fProperty < min(afTemporary(:,1)) || fProperty > max(afTemporary(:,1))
                                fprintf(2,'out of range for species %s',sSpecies,' -> []');
                                fProperty = [];
                            end
                        else
                            % data found in MatterData
                            % get column of property
                            iColumn = find(strcmp(this.ttxMatter.(sSpecies).MatterData.text(1,:), sPropertyName)); % row 1 is std propertyname in MatterData
                            if isempty(iColumn) && strcmp(sProperty, 'c_p')
                                % if heatcapacity (c_p) is searched, it is written as SHC in MatterData
                                iColumn = find(strcmp(this.ttxMatter.(sSpecies).MatterData.text(1,:), 'SHC')); 
                            end
                             % get the propertyvalue
                            fProperty = this.ttxMatter.(sSpecies).MatterData.num(iRowsFirstMatterData-2,iColumn-3);
                        end
                    end
                    
                end
            % check if species is in MatterData     
            elseif isfield(this.ttxMatter.(sSpecies), 'MatterData')
                % get the rows of the phase of the species
                rowPhase = find(strcmpi(this.ttxMatter.(sSpecies).MatterData.text(:,3), sPhase), 1, 'first');
                if isempty(rowPhase)
                    % no phase for species found
                    fProperty = 0;
                else
                    % get the propertyvalue
                    fProperty = this.ttxMatter.(sSpecies).MatterData.num(rowPhase-2,iColumn-3);
                end
                
            else
                % look if a worksheet of that species exist when not std atm. or no phase is stored
                rowPhase = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,3), sPhase), 1, 'first');
                if isempty(rowPhase)
                    % no phase found
                    % look if a worksheet for the species exitst in MatterXLS
                    if any(strcmpi(this.asWorksheets, sSpecies))
                        % import the speciesworksheet
                        this.createMatterData([], sSpecies);
                        % get the propertyvalue
                        fProperty = this.FindProperty(sSpecies, sProperty, 'Temperature', fT, 'Pressure', fP, sPhase);
                    else
                        % no worksheet found
                        fProperty = 0;
                    end
                else
                    % get the propertyvalue
                    fProperty = this.ttxMatter.(sSpecies).import.num(rowPhase-2,iColumn-3);
                end
            end
            % final check when found propertyvalue is nan
            if isnan(fProperty); fProperty = 0; end;
        end
    end
    
    %% Static helper methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods (Static = true)
        function tElements = extractAtomicTypes(sMolecule)
            % Extracts the single atoms out of a molecule string, e.g. CO2
            % leads to struct('C', 1, 'O', 2)
            % Atoms have to be written as Na, i.e. first letter is
            % uppercase, following ones are lowercase (e.g. Na2O2)
            
            tElements = struct();
            sCurrent = '';
            sCount   = '';
            
            for iI = 1:length(sMolecule)
                sC = sMolecule(iI);
                
                % Check for numer, uppercase
                bIsNaN = isnan(str2double(sC));
                bUpper = bIsNaN && isstrprop(sC, 'upper');
                
                % Upper - new element!
                if bUpper
                    % Add current to tSpecies struct
                    if ~isempty(sCurrent)
                        % No count? One!
                        if isempty(sCount), sCount = '1'; end;
                        
                        tElements.(sCurrent) = str2double(sCount);
                    end
                    
                    sCurrent = sC;
                    sCount   = '';
                    
                % Number - starting with/appending to the counter
                elseif ~bIsNaN
                    sCount = [ sCount sC ]; %#ok<AGROW>
                    
                % Lowercase - add to sCurrent
                else
                    if isempty(sCurrent)
                        error('matter:table:extractAtomicTypes', 'Molecule string does not start with uppercase (see help for format)');
                    end
                    
                    % Append to current element
                    sCurrent = [ sCurrent sC ]; %#ok<AGROW>
                end
            end
            
            
            % Final add for last element
            if ~isempty(sCurrent)
                if isempty(sCount), sCount = '1'; end;

                tElements.(sCurrent) = str2double(sCount);
            end
        end
    end
end




