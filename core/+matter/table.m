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
    %{
%     properties (SetAccess = protected, GetAccess = public)
%         % Constant properties
%         %   - Molar mass in g/mol
%         %   - Specific heat capacity Cp in J/kg/K
%         %   - Gas density in kg/m^3
%         %   - Density in kg/m^3
%         % ttxMatter
%         ttxMatter = struct ( ...
%             ...
%             ... Basic: if no ttxPhases, can't actually be really used
%             ...
%             'N', struct( ...
%                 'fMolMass', 14 ...
%             ), ...
%             'O', struct( ...
%                 'fMolMass', 16 ...
%             ), ... 
%             'C', struct( ...
%                 'fMolMass', 12, ... 
%                 'ttxPhases', struct( ...
%                     'gas', struct( ...
%                         'fCp', 600 ...
%                     ) ...
%                 ) ...
%            ), ... 
%            'H', struct( ...
%                 'fMolMass', 1 ...
%             ), ... 
%             'Ar', struct( ...
%                 'fMolMass', 39.9, ... 
%                 'ttxPhases', struct( ...
%                     'gas', struct( ...
%                         'fCp', 524 , ... 
%                         'fDensity', 1.784 ...
%                     ) ...
%                 ) ...
%             ), ...
%              'K', struct( ...
%                 'fMolMass', 39, ... 
%                 'fDensity', 862 ...  %reference: http://www.periodensystem.info/elemente/kalium/
%             ), ...
%                ... 
%                ... Molecules 
%                ... 
%                'O2', struct ( ...
%                 'ttxPhases', struct( ...
%                     'gas', struct( ...
%                         'fCp', 920, ... ... %TODO density - not really needed for gases right? from mol mass ...
%                         'fDensity', 1.429  ... % at STP 
%                         ), ...
%                     'liquid', struct(... % Same values as gas. Why? Because we can't do suspensions yet...
%                         'fCp', 920, ... 
%                         'fDensity', 1.429  ... % at STP 
%                         ) ...
%                 ) ...
%             ), ... 
%             'H2', struct ( ...
%                 'ttxPhases', struct( ...
%                     'gas', struct( ...
%                         'fCp', 14320 ... 
%                         ), ...
%                     'liquid', struct(... % Same values as gas. Why? Because we can't do suspensions yet...
%                         'fCp', 14320 ... 
%                         ) ...
%                 ) ...
%             ), ... 
%             'H2O', struct ( ...
%                 'ttxPhases', struct( ...
%                     'gas', struct( ...
%                         'fCp', 1860, ... 
%                         'fDensity', 0.804  ... % at STP
%                     ), ... 
%                     'liquid', struct( ...
%                         'fCp', 4180, ... 
%                         'fDensity', 1  ... % at STP
%                     ) ...
%                 ) ...
%             ), ... 
%             'CO2', struct ( ...
%                 'ttxPhases', struct( ...
%                     'gas', struct( ...
%                         'fCp', 820, ... 
%                         'fDensity', 1.977  ... % at STP
%                         ), ...
%                     'liquid', struct(... % Same values as gas. Why? Because we can't do suspensions yet...
%                         'fCp', 820, ... 
%                         'fDensity', 1.977 ... 
%                         ) ...
%                 ) ...
%             ), ...
%             'N2', struct ( ...
%                 'ttxPhases', struct( ...
%                     'gas', struct( ...
%                         'fCp', 1040, ...
%                         'fDensity', 1.250 ...
%                         ), ...
%                     'liquid', struct(... % Same values as gas. Why? Because we can't do suspensions yet...
%                         'fCp', 1040, ...
%                         'fDensity', 1.250 ...
%                         ) ...
%                 ) ...
%             ), ...
%             'KO2', struct ( ...
%                 'ttxPhases', struct( ...
%                     'solid', struct(...
%                         'fCp', 1090, ...
%                         'fDensity', 2140 ...
%                     )...
%                 )...
%             ), ...
%             'KOH', struct ( ...
%                 'ttxPhases', struct( ...
%                     'solid', struct(...
%                         'fCp', 1180, ...
%                         'fDensity', 2044 ...
%                         ), ...
%                     'liquid', struct(... % Same values as solid. Why? Because we can't do suspensions yet...
%                         'fCp', 1180, ...
%                         'fDensity', 2044 ...
%                         ) ...
%                     )...
%             ) ...
%        )
%         %TODO: Figure out a way how to make the values sensitive to
%         %variations in temperature and pressure
%         %TODO: Add the data source for each of these values directly into the code    
%     end
    %}
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
        csSpecies;
        iSpecies;
        ttxMatter;
        ttxSpeciesTable = struct;
        
        sInputtype
        sInputvalue
        sSpecies
        sSwitch
        sPhase
        
        % Molecular masses of the species in g/mol
        %TODO store as kg/mol so e.g. phases.gas doesn't has to convert
        %afMolMass = [32 28 18 44 72 57];
        afMolMass;
        
        % Heat capacities. Key is phase name. If value in specific matter
        % type not provided, -1 written. Same for densities.
        tafCp;
        tafDensity;
        
        % Refernce to all phases and flows that use this matter table
        aoPhases = []; %matter.phase.empty(); % ABSTRACT - can't do that!
        aoFlows  = matter.flow.empty();
        
        % Create 'empty' (placeholder) flow (for f2f, exme procs)
        oFlowZero;
        
    end
    
    methods
        function this = table(oParent, handle, sKey, fTemp, fPres)
            % get from phase: this,'import',sKey, fTemp
            %TODO: Implement code that reads from either an Excel sheet or
            %a database and automatically fills the properties
                   
            % Create zero/empty palceholder matter flow
            this.oFlowZero = matter.flow(this, []);
            
            if nargin == 4 
                if ~isempty(fTemp)
                    fPres = 1;
                else
                    fTemp = 300;
                end
            elseif nargin == 3
                fTemp = 300;
                fPres = 1;
            elseif nargin < 3 && nargin > 0
                this.throw('table:create','Not all neccessary inputs are given');
                return;
            end

            if nargin > 0
                this = oParent.oMT;
                this.createMatterData(oParent, handle, sKey, fTemp, fPres);
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
            %
            %TODO
            %   - enhanced Cp calculation (here or in derived class, or
            %     with some event/callback functionality?) to include the
            %     temperature dependency. Include a way to e.g. only do an
            %     actual recalculation if species masses/temperature
            %     changed more than X percent?
            
            
            % Case one - just a phase object provided
            if length(varargin) == 1
                if ~isa(varargin{1}, 'matter.phase')
                    this.throw('fHeatCapacity', 'If only one param provided, has to be a matter.phase (derivative)');
                end
                
                if varargin{1}.fMass == 0
                    fHeatCapacity = 0;
                    return;
                end
                
                sType  = varargin{1}.sType;
                afMass = varargin{1}.afMass;
                sId    = [ 'Phase ' varargin{1}.oStore.sName ' -> ' varargin{1}.sName ];
                
            % Assuming we have two params, the phase type and a vector with
            % the mass of each species.
            else
                sType  = varargin{1};
                afMass = varargin{2};
            
                if sum(afMass) == 0
                    fHeatCapacity = 0;
                    return;
                end
                
                sId = 'Manually provided vector for species masses';
            end
            
            
            % Check if phase exists in heat capacities (at least one
            % species defined it)
            if ~isfield(this.tafCp, sType)
                this.throw('calculateHeatCapacity', 'Phase %s not known in Cps', sType);
            
            % Make sure that no mass exists in this phase for which the
            % heat capacity is not defined
            else
                % Non existent ones are -1, so if any mass exists, the
                % result will be negative --> check!
                afCheck = this.tafCp.(sType) .* tools.round.prec(afMass);
                
                if any(afCheck < 0)
                    %TODO get negative indices with find(), display the
                    %     according species name that are a problem
                    this.throw('calculateHeatCapacity', '%s contains mass for at least one species (first: %s) that has no heat capacity defined for this phase!', sId, this.csSpecies{find(afCheck < 0, 1)});
                end
            end
            
            fHeatCapacity = afMass ./ sum(afMass) * this.tafCp.(sType)';
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
        
        function createMatterData(this, oParent, handle, sKey, fTemp, fPres)
            %% Zugriff auf bestimmte Reiter in der MatterXLS
            if nargin > 1
                % oParent: Partent object, needed for verification of phase
                % handle: handle what should be done (import etc.); not used at moment
                % sKey: speciesname (also worksheet name)
                % fTemp: temperature at which properties are searched
                % fPres: pressure at which propterties are searched
                Worksheet = sKey;
                % look if species is already imported
                if isfield(this.ttxMatter, sKey)
                    % look if data for species at given temperature and pressure is already stored 
                    if this.ttxSpeciesTable.(sKey).fTemp == fTemp && this.ttxSpeciesTable.(sKey).fPres == fPres
                        return
                    else
                        this.ttxMatter.(sKey) = this.Matterimport('core\+matter\Matter.xlsx', Worksheet, fTemp, fPres);
                        this.ttxMatter.(sKey).fTemp = fTemp;
                        this.ttxMatter.(sKey).fPres = fPres;
                    end
                else
                    % convert object to struct for errorchecking
                    check = struct(oParent);
                    if ~isfield(check, 'sType')
                        this.throw('table:import','no phasetype from parent class received');
                    elseif ~any(strcmp({'solid','gas','liquid'},check.sType))
                        this.trow('table:import','no valid phasetype from parent class received');
                    end

                    % import species at given temperature and pressure
                    this.ttxMatter.(sKey) = this.Matterimport('core\+matter\Matter.xlsx', Worksheet, fTemp, fPres);
                    this.ttxMatter.(sKey).fTemp = fTemp;
                    this.ttxMatter.(sKey).fPres = fPres;
                    this.ttxMatter.(sKey).sPhase = oParent.sType;
                    
                    % new species, so some fields has to be extend
                    iIndex = this.iSpecies+1;
                    this.csSpecies{iIndex} = sKey;
                    this.tiN2I.(sKey) = iIndex;
                    this.iSpecies = iIndex;
                    this.afMolMass(iIndex) = this.ttxMatter.(sKey).fMolMass;
                    cPhases = fieldnames(this.tafCp);
                    % go through all phases (solid, gas, liquid) and write correct value in array tafCp
                    % and tafDensity from new import
                    for i=1:length(cPhases)
                        % if value of specific heat capacity is stored in fCp and is a number and in right phase 
                        if isfield(this.ttxMatter.(sKey), 'fCp') && ~isnan(this.ttxMatter.(sKey).fCp) && strcmp(this.ttxMatter.(sKey).sPhase, cPhases{i})
                            this.tafCp.(cPhases{i})(iIndex) = this.ttxMatter.(sKey).fCp;
                        % else if value is stored in fSHC
                        elseif isfield(this.ttxMatter.(sKey), 'fSHC') && ~isnan(this.ttxMatter.(sKey).fSHC) && strcmp(this.ttxMatter.(sKey).sPhase, cPhases{i})
                            this.tafCp.(cPhases{i})(iIndex) = this.ttxMatter.(sKey).fSHC;
                        % std is -1
                        else
                            this.tafCp.(cPhases{i})(iIndex) = -1;
                        end
                        % if value of density is stored in fRoh and is a number and in right phase
                        if isfield(this.ttxMatter.(sKey), 'fRoh') && ~isnan(this.ttxMatter.(sKey).fRoh) && strcmp(this.ttxMatter.(sKey).sPhase, cPhases{i})
                            this.tafDensity.(cPhases{i})(iIndex) = this.ttxMatter.(sKey).fRoh;
                        % std is -1
                        else
                            this.tafDensity.(cPhases{i})(iIndex) = -1;
                        end

                    end
                    
                end
                
                this.sSpecies = sKey;
                this.sPhase = oParent.sType;
                
            else
                %% load standard Mattertable
                % this is executed at first (class simulation)
                this.ttxMatter = this.Matterimport('core\+matter\Matter.xlsx', 'MatterData');
            
                %{ 
                erstmal weg
                if ~isempty(varargin)
                    switch length(varargin{1,1})
                        case 1
                            this.throw('mattertable', 'Zu wenige Eingabeparameter');
                        case 2
                            this.sSwitch = varargin{1,1}{1,1};
                            this.sSpecies = varargin{1,1}{1,2};
                        case 3
                            this.sSwitch = varargin{1,1}{1,2};
                            this.sSpecies = varargin{1,1}{1,3};
                            this.sPhase = varargin{1,1}{1,1}.sType;
                        otherwise
                            this.sSwitch = varargin{1,1}{1,2};
                            this.sSpecies = varargin{1,1}{1,3};
                            this.sPhase = varargin{1,1}{1,1}.sType;
                    end

                    switch this.sSwitch
                        case 'check'
                            % add Mattertype to struct
                            this.ttxMatter.(this.sSpecies) = {};
                        case 'import'
                            [import.filename, import.pathname] = uigetfile({'*.XLS; *.XLSX; *.XLSM; *.XLTX; *.XLTM','spreadsheets (*.XLS, *.XLSX, *.XLSM, *.XLTX, *.XLTM)';'*.MAT','mat file (*.MAT)'}, 'Select a file for import');
                            [~,~,import.ext] = fileparts(import.filename);
                            switch import.ext
                                case {'.xls','.xlsx','.xlsm','.xltx','xltm'}
                                    [~, import.sheets] = xlsfinfo([import.pathname import.filename]);
                                    for k = 1:length(import.sheets)
                                        [import.num, import.text, import.raw] = xlsread([import.pathname import.filename], import.sheets{k},'','basic');
                                        ttxImport.(import.sheets{k}).num = import.num;
                                        ttxImport.(import.sheets{k}).text = import.text;
                                        ttxImport.(import.sheets{k}).raw = import.raw;
                                    end
                                    clear k;
                                    [import.FileName,import.PathName] = uiputfile;
                                    save([import.PathName import.FileName],'ttxImport');
                                case '.mat'
                                    load(import.filename,'-mat');
                                otherwise
                                    load(import.filename);
                            end
                            % weiterverarbeitung der Importierten Daten durch automatische
                            % untersuchung wenn möglich
                        case 'insert'
                            if any(isfield(this.ttxMatter, this.sSpecies))
                                this.throw('mattertable', 'species exists in Mattertable'); % better disp instead?
                            else 
                                str = '';
                                while ~strcmpi(str,'n')
                                    if isempty(this.sPhase)
                                        this.sPhase = input(sprintf('What Phase (gas/liquid/solid) has %s? ', this.sSpecies),'s');
                                    end
                                    this.sInputtype = input(sprintf('What property of %s at Phase %s do you want to insert? ', this.sSpecies, this.sPhase),'s');
                                    this.sInputvalue = input(sprintf('What is the value of %s? ', this.sInputtype));
                                    if ~isempty(this.sInputtype) && ~isempty(this.sInputvalue)
                                        this.ttxMatter.(this.sSpecies).ttxPhases.(this.sPhase).(this.sInputtype) = this.sInputvalue;
                                    else
                                        this.throw('mattertable', 'wrong input');
                                    end
                                    str = input(sprintf('Do you want to insert another property of %s? ', this.sSpecies),'s');
                                end
                                ttxMatter = this.ttxMatter;
                                save([pwd,'\core\+matter\Matter.mat'],'ttxMatter');
                                %error('Alle Änderungen wurden gespeichert. Bitte starten Sie ihr Programm erneut.');
                                %disp('Alle Änderungen wurden gespeichert. Bitte starten Sie ihr Programm erneut');
                                %exit;
                                %return;
                            end
                        case 'change'
                        case 'delete'
                    end

                end
                %}
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
                            if ~isfield(tCfg, 'ttxPhases')
                                a = sum(cell2mat(struct2cell(tElements)));
                                b = cell2mat(struct2cell(tElements));
                                c = char(fieldnames(tElements));
                                for i = 1:length(c)
                                    d(i) = this.ttxMatter.(char(cellstr(c(i,:)))).ttxPhases.gas.fCp;
                                end;
                                e = b ./ a .* d';
                                this.tafCp.gas(iI) = sum(e);
                            end
                        end
                    end

                    % Go through phases and write density/heat capacity
                    if isfield(tCfg, 'ttxPhases')
                        csPhases = fieldnames(tCfg.ttxPhases);

                        for iP = 1:length(csPhases)
                            sP = csPhases{iP};

                            % Heat capacity phase not there yet? Preset with -1
                            if ~isfield(this.tafCp, sP)
                                this.tafCp.(sP) = -1 * ones(1, this.iSpecies);
                            end

                            % Heat capacity given?
                            if isfield(tCfg.ttxPhases.(sP), 'fCp')
                                this.tafCp.(sP)(iI) = tCfg.ttxPhases.(sP).fCp;
                            end


                            % Same for densities
                            if ~isfield(this.tafDensity, sP)
                                this.tafDensity.(sP) = -1 * ones(1, this.iSpecies);
                            end

                            % Density given?
                            if isfield(tCfg.ttxPhases.(sP), 'fDensity')
                                this.tafDensity.(sP)(iI) = tCfg.ttxPhases.(sP).fDensity;
                            end
                        end
                    end

                    % ...?
                end
            end
        end
        
                
        %% data import from xls-file
        function ttxImportMatter = Matterimport(this, sFile, sIndex, fTemp, fPres)
            
            %% load standard Mattertable
            % this is executed at first (class simulation)
            if strcmp(sIndex, 'MatterData')
                [import.num, import.text, import.raw] = xlsread(sFile, sIndex);
                % store tablelength and column of density ("codename" of first property to store in phase) to save all properties
                [iColumn, iTableLength] = this.FindColumn(import.text, 'fDensity', 2);
                % only unique species are needed
                scSpecies = unique(import.text(3:end,1)); 
                % convert speciescell to a struct for dynamic access to individual species
                ttxImportMatter = cell2struct(scSpecies,scSpecies,1);
                % go through all unique species
                for i = 1:length(scSpecies)
                    % select all rows of that species
                    % species can have more than one phase
                    iRow = find(strcmp(import.text(3:end,1),scSpecies{i})); 
                    disp(scSpecies{i});
                    if ~isempty(iRow)
                        % go through all properties before density
                        for j = 4:iColumn-1
                            if ~isnan(import.num(iRow(1),j-3))
                                ttxImportMatter.(scSpecies{i}).(import.text{2,j}) = import.num(iRow(1),j-3);
                            end
                        end
                        % go through phases and save all remaining properties for that phase
                        for z = 1:length(iRow) 
                            for j = iColumn:iTableLength 
                                if ~isnan(import.num(iRow(z),j-3))
                                    ttxImportMatter.(scSpecies{i}).ttxPhases.(import.text{iRow(z)+2,3}).(import.text{2,j}) = import.num(iRow(z),j-3);
                                end
                            end

                        end
                        
                    end
                end
            % load specific species data
            else
                % first look if data is already imported
                if ~isfield(this.ttxMatter,(sIndex))
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
                else
                    import.num = this.ttxMatter.(sIndex).import.num;
                    import.text = this.ttxMatter.(sIndex).import.text;
                    import.raw = this.ttxMatter.(sIndex).import.raw;
                    iTableLength = size(import.text,2);
                end
                
                % calc and save properties
                for i = 4:iTableLength
                    if isempty(import.text(7,i))
                        this.trow('table:import','row 7 of matter.xlsx is not allowed to be empty!');
                    else
                        property = this.FindProperty(fTemp, fPres, import, i, iTableLength);
                        ttxImportMatter.(import.text{7,i}) = property;
                    end
                end
                                
            end
        end
        
        function [iColumn, iTableLength] = FindColumn(~, asText, sProperty_name, iRow)
            % asText: cellarray of strings who needs to be searched
            % sProperty_name: search string
            % iRow: rownumber in which the search string stays, optional
            iTableLength = length(asText(1,:));

            if nargin > 3 && ~isempty(iRow)
                iColumn = find(strcmp(asText(iRow,:),sProperty_name));
            else
                iColumn = find(strcmp(asText(1,:),sProperty_name));
            end
        end
        
        function property = FindProperty(~, fT, fP, caImport, iColumn, iTableLength)
            % fT: temperature
            % fP: pressure
            % caImport: all stored importdata (num, text, raw)
            % iColumn; column of property
            % iTableLength: lenght of table
            l = 1;
            property = 0;

            while property == 0
                % look if pressure is stored
                rowsP = find(caImport.num(:,3)==fP);
                % look if temperature is stored
                rowsT = find(caImport.num(:,2)==fT);
                if ~any(rowsP)
                    % pressure not in table
                    if any(rowsT)
                        % temperature found -> interpolation only over pressure
                        temp = caImport.num(rowsT,:);
                        temp = sortrows(temp,3);
                        [~,rows,~] = unique(temp(:,3),'rows');
                        temp = temp(rows,:); %!% temp speichern damit nicht für alle spalten neu ausgeführt werden muss?
                        property = interp1(temp(:,3),temp(:,iColumn),fP);
                    else
                        % interpolation over temperature and pressure needed
                        temp = caImport.num;
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
                        property = caImport.num((caImport.num(:,2)==fT&caImport.num(:,3)==fP),iColumn);
                     else
                        % temperature not in table -> interpolation over temperature needed
                        temp = caImport.num(rowsP,:);
                        temp = sortrows(temp,2);
                        [~,rows,~] = unique(temp(:,2),'rows');
                        temp = temp(rows,:); %!% temp speichern damit nicht für alle spalten neu ausgeführt werden muss?
                        property = interp1(temp(:,2),temp(:,iColumn),fT);
                    end
                end

                l = l + iTableLength;
            end
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




