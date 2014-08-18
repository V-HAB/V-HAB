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
        
        % liquids are considered inkompressible
        bLiquid = true;
        
        % solids are inkompressible
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
                   
            % Create zero/empty palceholder matter flow
            this.oFlowZero = matter.flow(this, []);
            
            % if no arguments from call received it creates the MatterData
            % from worksheet MatterData, else the Mattertableobject from
            % the parent are loaded and the arguments hand over to
            % createMatterData
            if nargin > 0
                this = oParent.oMT;
                this.createMatterData(oParent, sKey);
            else
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
                
                % if no mass given also no heatcapacity possible
                if varargin{1}.fMass == 0
                    return;
                end
                
                % initialise attributes from phase object
                sType  = varargin{1}.sType;
                sName = varargin{1}.sName;
                afMass = varargin{1}.afMass;
                fT = varargin{1}.fTemp;
                fP = varargin{1}.fPressure;
                if isempty(fP); fP = 100000; end; % std pressure (Pa)

                sId    = [ 'Phase ' varargin{1}.oStore.sName ' -> ' varargin{1}.sName ];
                
            % Assuming we have two or more params, the phase type, a vector with
            % the mass of each species and current temperature and pressure
            else
                sType  = varargin{1};
                sName = 'manual'; % can anything else, just used for check of last attributes
                afMass = varargin{2};
                
                % if no mass given also no heatcapacity possible
                if sum(afMass) == 0
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
            
            % fluids and/or solids are handled as incompressible usually
            % can be changed over the public properties bLiquid and bSolid 
            if strcmpi(sType, 'liquid') && this.bLiquid
                fP = 100000;
            elseif strcmpi(sType, 'solid') && this.bSolid
                fP = 100000;
            end
            
            % if all entries in Mass vector are NaN it has to be converted
            % to a zero vector
            if sum(isnan(afMass)) == length(afMass)
                afMass = zeros(1,length(afMass));
            end
            
            % initialise attributes for next run (only done first time)
            if ~isfield(this.cfLastProps, 'fCp')
                this.cfLastProps.fT = fT;
                this.cfLastProps.fP = fP;
                this.cfLastProps.afMass = afMass;
                this.cfLastProps.fCp = 0;
                this.cfLastProps.sType = sType;
                this.cfLastProps.sName= sName;
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
                iIndex = find(afMass>0);
                % go through all species that have mass and sum them up
                for i=1:length(find(afMass>0))
                    c_p = this.FindProperty(fT, fP, this.csSpecies{iIndex(i)}, 'c_p', sType);
                    fHeatCapacity = fHeatCapacity + afMass(iIndex(i)) ./ sum(afMass) * c_p;
                end
                % save heatcapacity for next run
                this.cfLastProps.fCp = fHeatCapacity;

            end
            
            % if no species has a valid heatcapacity an error trown out
            if isempty(fHeatCapacity)
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
        function createMatterData(this, oParent, sKey)
            % handles imported data. At first call at initialisation it
            % loads the standard worksheet MatterData and save the needed
            % structures etc. If called with arguments the parent object
            % must have a field with a valid phase and the species (sKey)
            % has to be handed over
            
            %% Zugriff auf bestimmte Reiter in der MatterXLS
            if nargin > 1
                % oParent: Partent object, needed for verification of phase
                % handle: handle what should be done (import etc.); not used at moment
                % sKey: speciesname (also worksheet name)
                % fTemp: temperature at which properties are searched
                % fPres: pressure at which propterties are searched
                Worksheet = sKey;
                this.ttxMatter.(sKey) = this.Matterimport(strrep('core\+matter\Matter.xlsx','\',filesep), Worksheet);%, fTemp, fPres);
                % look if species is already imported
                if isfield(this.ttxMatter, sKey)
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

                    if ~any(strcmp(this.csSpecies, sKey))
                        % new species, so some fields has to be extend if not already there
                        iIndex = this.iSpecies+1;
                        this.csSpecies{iIndex} = sKey;
                        this.tiN2I.(sKey) = iIndex;
                        this.iSpecies = iIndex;
                        this.afMolMass(iIndex) = this.ttxMatter.(sKey).fMolMass;
                        cPhases = fieldnames(this.tafDensity);

                        % go through all phases (solid, gas, liquid) and write correct value in array tafCp
                        % and tafDensity from new import
                        for i=1:length(cPhases)
                            % if value of density is stored in fRoh and is a number and in right phase
                            if isfield(this.ttxMatter.(sKey), 'fRoh') && ~isnan(this.ttxMatter.(sKey).fRoh) && strcmp(oParent.sType, cPhases{i})
                                this.tafDensity.(cPhases{i})(iIndex) = this.ttxMatter.(sKey).fRoh;
                            else % std is -1
                                this.tafDensity.(cPhases{i})(iIndex) = -1;
                            end

                        end
                    end
                    
                end
                
            else
                %% load standard Mattertable
                % this is executed at first (class simulation)
                this.ttxMatter = this.Matterimport(strrep('core\+matter\Matter.xlsx','\',filesep), 'MatterData');
            
                this.csSpecies = fieldnames(this.ttxMatter);
                this.iSpecies  = length(this.csSpecies);

                this.afMolMass = zeros(1, this.iSpecies);
                this.tiN2I     = struct();

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
            
            % store all worksheets form excelfile and look if is readable
            [sStatus, this.asWorksheets] = xlsfinfo(sFile);
            if ~any(strcmp(sStatus, {'Microsoft Excel Spreadsheet', 'Microsoft Macintosh Excel Spreadsheet'}))
                this.throw('table:Matterimport',sprintf('File %s has wrong format for Matterimport',sFile));
            end
            %% import worksheet MatterData (standard Mattertable)
            % this is executed at first (in class simulation)
            if strcmp(sIndex, 'MatterData') && any(strcmpi(this.asWorksheets, 'MatterData'))
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
                        % rownumbers of .num and .text/.raw are 2 rows
                        % different because of headers
                        iRow = iRow +2;
                        ttxImportMatter.(scSpecies{i}).import.num = import.num(iRow-2,:);
                        ttxImportMatter.(scSpecies{i}).import.num(:,iTableLength+1:end) = [];
                        ttxImportMatter.(scSpecies{i}).import.text = import.text(1:2,:);
                        ttxImportMatter.(scSpecies{i}).import.text = [ttxImportMatter.(scSpecies{i}).import.text; import.text(iRow,:)];
                        ttxImportMatter.(scSpecies{i}).import.text(:,iTableLength+1:end) = [];
                        ttxImportMatter.(scSpecies{i}).import.raw = import.raw(1:2,:);
                        ttxImportMatter.(scSpecies{i}).import.raw = [ttxImportMatter.(scSpecies{i}).import.raw; import.raw(iRow,:)];
                        ttxImportMatter.(scSpecies{i}).import.raw(:,iTableLength+1:end) = [];
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
                % first look if data is already imported
                if ~isfield(this.ttxMatter, sIndex)
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
                % check size of imported data (data from MatterData has max
                % size of 5)
                elseif size(this.ttxMatter.(sIndex).import.raw, 1) < 6
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
                    
                % data is already imported -> get back
                else
                    return;
                end
                
                % look if some values safed as kJ -> has to convert do J (*1000)
                iTableLength = size(ttxImportMatter.import.text, 2);
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
            % 
            % sPropertyName: search string
            % sSpecies: speciesname
            % iRow: rownumber in which the search string stays, optional
            
            % only calculate tablelength if is searched too
            if nargout == 2
                iTableLength = size(this.ttxMatter.(sSpecies).import.text,2);
            end
            
            % if rownumbers is also given
            if nargin > 3 && ~isempty(iRow)
                    iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(iRow,:),sPropertyName));
            else
                % if raw data has max 5 rows it has to be from worksheet MatterData (2 lines heading +max 3 phases)
                if size(this.ttxMatter.(sSpecies).import.raw,1)>5
                    iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(5,:),sPropertyName)); % row 5 is std propertyname
                    if isempty(iColumn)
                        iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(7,:),sPropertyName)); % search row 7 as alternative
                    end
                else
                    if strcmpi(sPropertyName,'c_p'); sPropertyName = 'SHC'; end;
                    iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(1,:),sPropertyName)); % row 1 is std propertyname in MatterData
                    if isempty(iColumn)
                        iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(2,:),sPropertyName)); % search row 2 as alternative
                    end
                end
            end
        end
        
        function [fMin, fMax] = FindRange(this, sSpecies, xForProp)
            % sSpecies: speciesname
            % xForProp: string of property or number of column
            
            % depending on the input, look for column of property
           if ischar(xForProp)
               iColumn = this.FindColumn(xForProp, sSpecies);
           elseif isnumeric(xForProp)
               iColumn = xForProp;
           end
           
           if nargout == 2
               
               fMax = max(this.ttxMatter.(sSpecies).import.num(:,iColumn));
           end
           fMin = min(this.ttxMatter.(sSpecies).import.num(:,iColumn));
        end
        
        function property = FindProperty(this, fT, fP, sSpecies, sProperty, sPhase)
            % fT: temperature
            % fP: pressure
            % sSpecies: species name for which property is searched
            % sProperty: name of the searched property
            % sPhase: phasetype, optional
            
            property = 0;
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
                this.createMatterData([], [], sSpecies);
            end
            
            
            [iColumn, ~] = this.FindColumn(sProperty, sSpecies);
            % property c_p are often written as SHC (Are they the same
            % values?
            if isempty(iColumn) && strcmp(sProperty, 'c_p')
                iColumn = this.FindColumn('SHC', sSpecies);
            end
            % property is not in worksheet
            if isempty(iColumn)
                this.throw('table:FindProperty',sprintf('Can´t find property %s in worksheet %s', sProperty, sSpecies));
            end
            
            if strcmpi(sPhase, 'solid') && this.bSolid
                iColumnPhase = this.FindColumn('Phase',sSpecies);
                rowsP = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,iColumnPhase), 'solid'));
                fP = 100000;
            elseif strcmpi(sPhase, 'liquid') && this.bLiquid
                iColumnPhase = this.FindColumn('Phase',sSpecies);
                rowsP = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,iColumnPhase), 'liquid'));
                fP = 100000;
            else
                rowsP = [];
            end
            % for checking of temp or pres out of table values
            abOutOfRange = [0; 0];
                    
            % over 3 rows in import.num only possible if not from worksheet
            % MatterData (max 3 phases)
            if size(this.ttxMatter.(sSpecies).import.num,1) > 3
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
                
                if isempty(rowsP)
                    % look if pressure is stored
                    rowsP = find(this.ttxMatter.(sSpecies).import.num(:,3) == fP);
                end
                % look if temperature is stored
                rowsT = find(this.ttxMatter.(sSpecies).import.num(:,2) == fT);
                if ~any(rowsP) && ~(abOutOfRange(1) && abOutOfRagne(2))
                    % pressure not in table
                    if any(rowsT)
                        % temperature found -> interpolation only over pressure
                        temp = this.ttxMatter.(sSpecies).import.num(rowsT,:);
                        temp = sortrows(temp,3);
                        [~,rows,~] = unique(temp(:,3),'rows');
                        temp = temp(rows,:); %!% temp speichern damit nicht für alle spalten neu ausgeführt werden muss?
                        property = interp1(temp(:,3),temp(:,iColumn),fP); %interp1(fPressure, fProperty, fP) 
                    else
                        % interpolation over temperature and pressure needed
                        temp = this.ttxMatter.(sSpecies).import.num;
                        temp(1:4,:) = [];
                        % noch nicht das Gelbe vom Ei :(
                        property = griddata(temp(:,2),temp(:,3),meshgrid(temp(:,iColumn)),fT,fP);
                        if property < min(temp(:,iColumn)) || property > max(temp(:,iColumn))
                            %disp(sprintf('out of range for species %s',sSpecies,' -> []'));
                            property = [];
                        end
                        
                    end
                else
                    % pressure in table
                     if any(rowsT)
                        % pressure and temperature given -> no interpolation needed
                        property = this.ttxMatter.(sSpecies).import.num((this.ttxMatter.(sSpecies).import.num(:,2) == fT & this.ttxMatter.(sSpecies).import.num(:,3) == fP), iColumn);
                     else
                        % temperature not in table -> interpolation over temperature needed
                        temp = this.ttxMatter.(sSpecies).import.num(rowsP,:);
                        temp = sortrows(temp,2);
                        [~,rows,~] = unique(temp(:,2),'rows');
                        temp = temp(rows,:); %!% temp speichern damit nicht für alle spalten neu ausgeführt werden muss?
                        property = interp1(temp(:,2),temp(:,iColumn),fT);
                    end
                end

                % when no property is found, look if maybe better data is stored from worksheet MatterData
                if (isempty(property) || isnan(property)) && isfield(this.ttxMatter.(sSpecies), 'MatterData')
                    
                    rowPhase = find(strcmpi(this.ttxMatter.(sSpecies).MatterData.text(:,3), sPhase), 1, 'first');
                    if isempty(rowPhase)
                        property = 0;
                    else
                        property = this.ttxMatter.(sSpecies).MatterData.num(rowPhase-2,iColumn-3);
                    end
                end
            else
                % look if a worksheet of that species exist when not std atm. or no phase is stored
                if any(strcmpi(this.asWorksheets, sSpecies))
                    this.createMatterData([], [], sSpecies);
                    property = this.FindProperty(fT, fP, sSpecies, sProperty, sPhase);
                else
                    rowPhase = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,3), sPhase), 1, 'first');
                    if isempty(rowPhase)
                        property = 0;
                    else
                        property = this.ttxMatter.(sSpecies).import.num(rowPhase-2,iColumn-3);
                    end
                end
            end
            if isnan(property); property = 0; end;
        end
 
        % same as FindProperty but has to indepentent of special dependency
        % (not Temp and/or Pres dependency)
        function property = FindProperty2(this, sSpecies, sProperty, xFirstDep, xSecondDep, sPhase)
            % fT: temperature
            % fP: pressure
            % caImport: all stored importdata (num, text, raw)
            % iColumn; column of property
            % iTableLength: lenght of table
            l = 1;
            property = 0;
            switch nargin
                case 5
                    if isa(xSecondDep, 'char') && strcmpi({'solid','liquid','gas'}, xSecondDep)
                        sPhase = xSecondDep;
                        xSecondDep = [];
                        dependencies = 1;
                    else
                        sPhase = [];
                        dependencies = 2;
                    end
                case 4
                    xSecondDep = [];
                    sPhase = [];
                    dependencies = 1;
                otherwise
                    dependencies = 2;
            end
            
            % check if dependencies valid; if only second valid -> handle it to firstdep
            if (isempty(xFirstDep) || isnan(fP)) && (isempty(xSecondDep) || isnan(xSecondDep))
                xFirstDep = xSecondDep;
                xSecondDep = [];
            else
                this.throw('table:FindProperty',sprintf('no valid dependency was transmitted for property %s',sProperty));
            end
            
            % check if Species is already imported
            if ~isfield(this.ttxMatter, sSpecies)
                this.createMatterData([], [], sSpecies);%, fT, fP);
            end
            
            [iColumn, iTableLength] = this.FindColumn(sProperty, sSpecies);
            
            % over 3 rows in import.num only possible if not from worksheet MatterData
            if size(this.ttxMatter.(sSpecies).import.num,1)>3
                if strcmpi(sPhase, 'solid') && this.bSolid
                    iColumnPhase = this.FindColumn('Phase',sSpecies);
                    rowsP = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,iColumnPhase), 'solid'));
                    fP = 100000;
                elseif strcmpi(sPhase, 'liquid') && this.bLiquid
                    iColumnPhase = this.FindColumn('Phase',sSpecies);
                    rowsP = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,iColumnPhase), 'liquid'));
                    fP = 100000;
                else
                    % look if pressure is stored
                    rowsP = find(this.ttxMatter.(sSpecies).import.num(:,3) == fP);
                end
                % look if temperature is stored
                rowsT = find(this.ttxMatter.(sSpecies).import.num(:,2)==fT);
                if ~any(rowsP)
                    % pressure not in table
                    if any(rowsT)
                        % temperature found -> interpolation only over pressure
                        temp = this.ttxMatter.(sSpecies).import.num(rowsT,:);
                        temp = sortrows(temp,3);
                        [~,rows,~] = unique(temp(:,3),'rows');
                        temp = temp(rows,:); %!% temp speichern damit nicht für alle spalten neu ausgeführt werden muss?
                        property = interp1(temp(:,3),temp(:,iColumn),fP); %interp1(fPressure, fProperty, fP) 
                    else
                        % interpolation over temperature and pressure needed
                        temp = this.ttxMatter.(sSpecies).import.num;
                        temp(1:4,:) = [];
                        property = griddata(temp(:,2),temp(:,3),temp(:,iColumn),fT,fP);
%                         property = interp2(unique(temp(:,2),'rows','sorted'),unique(temp(:,3),'rows','sorted'),unique(temp(:,iColumn),'rows','sorted'),fT,fP);
%                         X = caImport.num(~isnan(caImport.num(:,2)),2);
%                         Y = caImport.num(~isnan(caImport.num(:,3)),3);
%                         V = caImport.num(~isnan(caImport.num(:,iColumn)),iColumn);
%                         temp = scatteredInterpolant(X,Y,V);
%                         property = temp(fT,fP); 
                        
                    end
                else
                    % pressure in table
                     if any(rowsT)
                        % pressure and temperature given -> no interpolation needed
                        property = this.ttxMatter.(sSpecies).import.num((this.ttxMatter.(sSpecies).import.num(:,2) == fT & this.ttxMatter.(sSpecies).import.num(:,3) == fP), iColumn);
                     else
                        % temperature not in table -> interpolation over temperature needed
                        temp = this.ttxMatter.(sSpecies).import.num(rowsP,:);
                        temp = sortrows(temp,2);
                        [~,rows,~] = unique(temp(:,2),'rows');
                        temp = temp(rows,:); %!% temp speichern damit nicht für alle spalten neu ausgeführt werden muss?
                        property = interp1(temp(:,2),temp(:,iColumn),fT);
                    end
                end

                l = l + iTableLength;
            else
                rowsP = find(strcmpi(this.ttxMatter.(sSpecies).import.text(:,3), sPhase));
                if isempty(rowsP)
                    property = 0;
                else
                    property = this.ttxMatter.(sSpecies).import.num(rowsP-2,iColumn-3);
                end
            end
            if isnan(property); property = 0; end;
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




