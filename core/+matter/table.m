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
    
    properties (SetAccess = protected, GetAccess = public)
        % Constant properties
        %   - Molar mass in g/mol
        %   - Specific heat capacity Cp in J/kg/K
        %   - Gas density in kg/m^3
        %   - Density in kg/m^3
        ttxMatter = struct ( ...
            ...
            ... Basic: if no ttxPhases, can't actually be really used
            ...
            'N', struct( ...
                'fMolMass', 14 ...
            ), ...
            'O', struct( ...
                'fMolMass', 16 ...
            ), ...
            'C', struct( ...
                'fMolMass', 12 ...
            ), ...
            'H', struct( ...
                'fMolMass', 1 ...
            ), ...
            ...
            'Ar', struct( ...
                'fMolMass', 39.9, ...
                'ttxPhases', struct( ...
                    'gas', struct( ...
                        'fCp', 524 ...
                    ) ...
                ) ...
            ), ...
            ...
            ... Molecules
            ...
            'O2', struct ( ...
                'ttxPhases', struct( ...
                    'gas', struct( ...
                        'fCp', 920, ...
                        ... %TODO density - not really needed for gases right? from mol mass ...
                        'fDensity', 1.429  ... % at STP
                    ) ...
                ) ...
            ), ...
            'H2', struct ( ...
                'ttxPhases', struct( ...
                    'gas', struct( ...
                        'fCp', 14320 ...
                    ) ...
                ) ...
            ), ...
            'H2O', struct ( ...
                'ttxPhases', struct( ...
                    'gas', struct( ...
                        'fCp', 1860, ...
                        'fDensity', 0.804  ... % at STP
                    ), ...
                    'liquid', struct( ...
                        'fCp', 4180, ...
                        'fDensity', 1  ... % at STP
                    ) ...
                ) ...
            ), ...
            'CO2', struct ( ...
                'ttxPhases', struct( ...
                    'gas', struct( ...
                        'fCp', 820, ...
                        'fDensity', 1.977  ... % at STP
                    ) ...
                ) ...
            ), ...
            'N2', struct ( ...
                'ttxPhases', struct( ...
                    'gas', struct( ...
                        'fCp', 1040 ...
                    ) ...
                ) ...
            ), ...
            'KO2', struct ( ...
                'fMolMass', 72, ...
                'fCp', 1090, ...
                'fSolidDensity', 2140 ...
            ), ...
            'KOH', struct ( ...
                'fMolMass', 57, ...
                'fCp', 1180, ...
                'fSolidDensity', 2044 ...
            ) ...
        )
        %TODO: Figure out a way how to make the values sensitive to
        %variations in temperature and pressure
        %TODO: Add the data source for each of these values directly into the code    
    end
    
    properties (Constant = true, GetAccess = public)
        % Some constants ... I SAID SOME!!!
        C = struct( ...
            'R_m', 8.314472 ...
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
        function this = table()
            %TODO: Implement code that reads from either an Excel sheet or
            %a database and automatically fills the properties
            
            % Create zero/empty palceholder matter flow
            this.oFlowZero = matter.flow(this, []);
            
            this.createMatterData();
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
        
        function fHeatCapacity = calculateHeatCapacity(this, oPhase)
            % Calculates the total heat capacity, see calcMolMass. Needs
            % the whole phase object to get phase type, temperature etc
            %
            %TODO
            %   - enhanced Cp calculation (here or in derived class, or
            %     with some event/callback functionality?) to include the
            %     temperature dependency. Include a way to e.g. only do an
            %     actual recalculation if species masses/temperature
            %     changed more than X percent?
            
            
            if oPhase.fMass == 0
                fHeatCapacity = 0;
                return;
            end
            
            
            % Check if phase exists in heat capacities (at least one
            % species defined it)
            if ~isfield(this.tafCp, oPhase.sType)
                this.throw('calculateHeatCapacity', 'Phase %s not known in Cps', oPhase.sType);
            
            % Make sure that no mass exists in this phase for which the
            % heat capacity is not defined
            else
                % Non existent ones are -1, so if any mass exists, the
                % result will be negative --> check!
                afCheck = this.tafCp.(oPhase.sType) .* tools.round.prec(oPhase.afMass);
                
                if any(afCheck < 0)
                    %TODO get negative indices with find(), display the
                    %     according species name that are a problem
                    this.throw('calculateHeatCapacity', 'Phase %s (type %s) in container %s contains mass for at least one species (first: %s) that have no heat capacity defined for this phase!', oPhase.sName, oPhase.sType, oPhase.oStore.sName, this.csSpecies{find(afCheck < 0, 1)});
                end
            end
            
            fHeatCapacity = oPhase.afMass ./ sum(oPhase.afMass) * this.tafCp.(oPhase.sType)';
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
        
        function createMatterData(this)
            % Calculate basic matter parameters (write components to matter
            % table, calc mol masses of composed matter types), write the
            % cached values for mol mass, cp, density etc
            %
            %TODO
            %   - see above - e.g. Cp here probably just basic default
            %     value, possibly later specific calculations for the
            %     different phases based on their type (gas, ...) and temp
            
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
                    this.afMolMass(iI) = tCfg.fMolMass;
                
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
                                %this.ttxMatter, csElements{iE}
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




