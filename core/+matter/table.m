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
    %   - heat/thermal conductivity
    %   - heat transfer coefficient between matter types, phases? provide
    %     that directly to a processor added between two phases?
    %   -> values dependant from temp, phase, ... -> different ways to
    %      provide them, e.g. lookup tables etc
    %      Each e.g. flow than has to specificly call MT and calculate heat
    %      capacity if needed.
    %
    %   - "meta" matter whose parameters are not defined that specificly?
    %     e.g. generic food types/contents for human

    properties (Constant = true, GetAccess = public)
        % Some constants
        %
        %   - gas constant (R_m) in J/(K Mol)
        %   - gravitational constant (fGravitationConst) in 10^-11 m^3/(kg s^2)
        %   - Avogadro constant (fAvogadroConst) in 10^23 1/Mol
        %   - Boltzmann constant (fBoltzmannConst) in 10^-23 J/K
        C = struct( ...
            'R_m', 8.314472, ...
            'fGravitationConst', 6.67384, ...
            'fAvogadroConst', 6.02214129, ...
            'fBoltzmannConst', 1.3806488 ...
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
        asWorksheets = [];
        
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
        % tafCp; No longer needed. Now dynamical generated
        tafDensity;
        
        % Refernce to all phases and flows that use this matter table
        aoPhases = []; %matter.phase.empty(); % ABSTRACT - can't do that!
        aoFlows  = matter.flow.empty();
        
        % Create 'empty' (placeholder) flow (for f2f, exme procs)
        oFlowZero;
        
    end
    
    properties (SetAccess = public, GetAccess = public)
        % Limit - determines how much can the property of a species change before an update
        % of the matter properties is allowed
        rMaxChange = 0.01;
        
        % liquids are considered inkompressible if this is true
        bLiquid = true;
        
        % solids are inkompressible if this is true
        bSolid = true;
        
    end
    
    methods
        function this = table(oParent, sSpeciesname)
            % constructor of class and handles calling of Mattercreation
            %
            % first execution at initialisation from class simulation with
            % no input arguments; imports worksheet MatterData
            %
            % following calls from class phase if species not found; import
            % from species worksheet if exist
            % gets matterobject from parent phaseclass and needed species
            % (sSpeciesname)
            
            % if no arguments from call received it creates the MatterData
            % from worksheet MatterData, else the Mattertableobject from
            % the parent are loaded and the arguments hand over to
            % createMatterData
            if nargin > 0
                this = oParent.oMT;
                this.createMatterData(oParent, sSpeciesname);
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
            %  fHeatCapacity  - specific heat capacity of mix, J/kgK�
            
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
                sPhase  = varargin{1}.sType;
                sName = varargin{1}.sName;
                afMass = varargin{1}.afMass;
                fT = varargin{1}.fTemp;
                fP = varargin{1}.fPressure;
                if isempty(fP); fP = 100000; end; % std pressure (Pa)
                
                % if no mass given also no heatcapacity possible
                if varargin{1}.fMass == 0 || sum(isnan(afMass)) == length(afMass)
                    return;
                end
                
                % not used
                %sId    = [ 'Phase ' varargin{1}.oStore.sName ' -> ' varargin{1}.sName ];
                
            % Assuming we have two or more params, the phase type, a vector with
            % the mass of each species and current temperature and pressure
            %CHECK: As far as I can see, only matter.flow.m uses this,
            %could change that file and get rid of this if condition.
            else
                sPhase  = varargin{1};
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
                    fT = 288.15; % std temperature (K)
                    fP = 100000; % std pressure (Pa)
                end
                
                % not used
                %sId = 'Manually provided vector for species masses';
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
                this.cfLastProps.sPhase  = sPhase;
                this.cfLastProps.sName  = sName;
            end
            
            % if same Phase and Type as lasttime, it has to be checked if
            % temperature, pressure or mass has changed more than x% from
            % last time
            % percentage of change can be handled over the public property
            % rMaxChange; std is 0.01 (1%)
            %disp(['phase: ', sPhase,' species ', sName]);
            if strcmp(sPhase, this.cfLastProps.sPhase) && strcmp(sName, this.cfLastProps.sName)
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
                    this.cfLastProps.sPhase = sPhase;
                    this.cfLastProps.sName = sName;
            end

            % look what species has mass so heatcapacity can calculated
            if any(afMass > 0) % needed? should always true because of check in firstplace
                aiIndexes = find(afMass>0);
                % go through all species that have mass and calculate the heatcapacity of each. then add this to the
                % rest
                for i=1:length(find(afMass>0))
                    fCp = this.FindProperty(this.csSpecies{aiIndexes(i)}, 'c_p', 'Temperature', fT, 'Pressure', fP, sPhase);
                    %fCp = this.FindProperty(fT, fP, this.csSpecies{aiIndexes(i)}, 'c_p', sType); % Old FindProperty
                    fHeatCapacity = fHeatCapacity + afMass(aiIndexes(i)) ./ sum(afMass) * fCp;
                end
                % save heatcapacity for next call of this routine
                this.cfLastProps.fCp = fHeatCapacity;

            end
            
            % if no species has a valid heatcapacity an error thrown out
            if isempty(fHeatCapacity) || isnan(fHeatCapacity)
                this.throw('calculateHeatCapacity','Error in HeatCapacity calculation!');
            end
        end
        %% old FindProperty
        % not used at moment
        % if new FindProperty is good, this function can be deleted
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
            % property c_p are often written as SHC (Are they the same values?
            if isempty(iColumn) && strcmp(sProperty, 'c_p')
                iColumn = this.FindColumn('SHC', sSpecies);
            end
            % property is not in worksheet
            if isempty(iColumn)
                this.throw('table:FindProperty',sprintf('Can�t find property %s in worksheet %s', sProperty, sSpecies));
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
                elseif fP < fMin
                    fP = fMin;
                    abOutOfRange(1) = true;
                end
                [fMin, fMax] = this.FindRange(sSpecies, 'fT');
                if fT > fMax
                    fT = fMax;
                    abOutOfRange(2) = true;
                elseif fT < fMin
                    fT = fMin;
                    abOutOfRange(2) = true;
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
                        temp = temp(rows,:); % maybe save temp for calculation over all columns
                        fProperty = interp1(temp(:,3),temp(:,iColumn),fP); 
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
                        temp = temp(rows,:); % maybe save temp for calculation over all columns
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
                    else
                        fProperty = 0;
                    end
                else
                    fProperty = this.ttxMatter.(sSpecies).import.num(rowPhase-2,iColumn-3);
                end
            end
            if isnan(fProperty); fProperty = 0; end;
        end
        
        %% FindProperty
        % same functionality as old FindProperty but indepentent of special dependency
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
            % sFirstDepName: name of dependency 1 (parameter for FindColumn), e.g. 'Temperature'
            % sFirstDepValue: value of dependency 1
            % sSecondDepName: name of dependency 2 (parameter for FindColumn), e.g. 'Pressure', optional
            % sFirstDepValue: value of dependency 2, optional
            % sPhase: only specific phase searched; selects only rows with that phase in MatterData, optional
            
            %fProperty = 0;
            
            % check inputs on correctness
            switch nargin
                case 8 %must be: this, Speciesname, Property, FirstDependency, FirstDependencyValue, SecondDependency, SecondDependenyValue, Phase
                    % check if all inputs have correct type
                    if ~ischar(sSpecies) || ~ischar(sProperty) || ~(ischar(sFirstDepName) || isempty(sFirstDepName)) || ~isnumeric(fFirstDepValue) || ~(ischar(sSecondDepName) || isempty(sSecondDepName)) || ~isnumeric(fSecondDepValue) || ~ischar(sPhase) || ~ischar(sSpecies)
                        this.trow('table:FindProperty','Some inputs have wrong type');
                    else
                        % number of dependencies
                        iDependencies = 2;
                    end
                case 7 %must be: this, Speciesname, Property, FirstDependency, FirstDependencyValue, SecondDependency, SecondDependenyValue
                    % check if all inputs have correct type
                    if ~ischar(sSpecies) || ~ischar(sProperty) || ~(ischar(sFirstDepName) || isempty(sFirstDepName)) || ~isnumeric(fFirstDepValue) || ~(ischar(sSecondDepName) || isempty(sSecondDepName)) || ~isnumeric(fSecondDepValue) || ~ischar(sSpecies)
                        this.trow('table:FindProperty','Some inputs have wrong type');
                    else
                        % number of dependencies
                        iDependencies = 2;
                        sPhase = [];
                    end
                case 6 %must be: this, Speciesname, Property, FirstDependency, FirstDependencyValue, Phase
                    % check if sPhase is given as last parameter
                    if isa(sSecondDepName, 'char') && strcmpi({'solid','liquid','gas'}, sSecondDepName)
                        sPhase = sSecondDepName;
                        sSecondDepName = [];
                        % number of dependencies
                        iDependencies = 1;
                    else
                        this.throw('table:FindProperty','Input phase is not correct');
                    end
                case 5 %must be: this, Speciesname, Property, FirstDependency, FirstDependencyValue
                    % check if value of first dependency is numeric
                    if isnumeric(fFirstDepValue)
                        sSecondDepName = [];
                        sPhase = [];
                        % number of dependencies
                        iDependencies = 1;
                    else
                        this.trow('table:FindProperty','Wrong inputtype for first dependency');
                    end
                otherwise
                    % at least one dependency has to be given over
                    this.trow('table:FindProperty','Not enough inputs');
            end
            
            % check if dependencies are valid; if only second valid -> handle it to firstdep
            if (isempty(sFirstDepName) || ischar(sFirstDepName)) && ~(isempty(sSecondDepName) || ischar(sSecondDepName))
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
                this.throw('table:FindProperty',sprintf('Can�t find property %s in worksheet %s', sProperty, sSpecies));
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
            if size(this.ttxMatter.(sSpecies).import.num, 1) > 3
                % get column of first dependency
                iColumnFirst = this.FindColumn(sFirstDepName, sSpecies);
                % if properties are given 2 times (e.g. Temperature has C and K columns), second column is used
                if length(iColumnFirst) > 1 
                    iColumnFirst = iColumnFirst(2);
                elseif isempty(iColumnFirst) && strcmp(sFirstDepName, 'c_p')
                % property c_p are often written as SHC (Are they the same values?)
                    iColumnFirst = this.FindColumn('SHC', sSpecies);
                end
                % if no column found, property is not in worksheet
                if isempty(iColumnFirst)
                    this.throw('table:FindProperty',sprintf('Can�t find property %s in worksheet %s', sFirstDepName, sSpecies));
                end
                
                % initialise array for checking if dependencies are out of table values
                abOutOfRange = [false; false];

                % look if data for first dependency is in range of table
                % if not in range, first look if data is given in worksheet MatterData before interpolate
                [fMin, fMax] = this.FindRange(sSpecies, iColumnFirst);
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
                           
                iRowsFirst = find(this.ttxMatter.(sSpecies).import.num(:,iColumnFirst) == fFirstDepValue);
                
                % only one dependency given
                if iDependencies == 1
                    
                    if ~isempty(iRowsFirst) && ~abOutOfRange(1)
                        % dependencyvalue in table and in range of table
                        % direct usage
                        fProperty = this.ttxMatter.(sSpecies).import.num((this.ttxMatter.(sSpecies).import.num(iRowsFirst,iColumnFirst) == fFirstDepValue), iColumn);
                    elseif ~abOutOfRange(1)
                        % only in range of table
                        % interpolation needed
                        % create a temporary array because inperp1 need stricly monotonic increasing data
                        afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst]);
                        afTemporary = sortrows(afTemporary,2);
                        [~,rows] = unique(afTemporary(:,2),'rows');
                        afTemporary = afTemporary(rows,:); % save afTemporary so that it doesn�t has to do it again for all columns?
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
                            % get the data from the MatterData-worksheet
                            % first get column of property
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
                    % get column of second dependency
                    iColumnSecond = this.FindColumn(sSecondDepName, sSpecies);
                    
                    % property c_p are often written as SHC (Are they the same values?)
                    if isempty(iColumnSecond) && strcmp(sSecondDepName, 'c_p')
                        iColumnSecond = this.FindColumn('SHC', sSpecies);
                    end
                    % if no column found, property is not in worksheet
                    if isempty(iColumnSecond)
                        this.throw('table:FindProperty',sprintf('Can�t find property %s in worksheet %s', sSecondDepName, sSpecies));
                    end
                    
                    % look if data for second dependency is in range of table
                    % if not in range, first look if data is given in worksheet MatterData before interpolate
                    [fMin, fMax] = this.FindRange(sSpecies, iColumnSecond);
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
                    iRowsSecond = find(this.ttxMatter.(sSpecies).import.num(:,iColumnSecond) == fSecondDepValue);

                    % look if both dependencies are in range of table
                    if ~(abOutOfRange(1) || abOutOfRange(2))
                        if ~isempty(iRowsFirst) && ~isempty(iRowsSecond) && intersect(iRowsFirst,iRowsSecond)
                            % both dependency directly given
                            % get propertyvalue
                            fProperty = this.ttxMatter.(sSpecies).import.num(intersect(iRowsFirst,iRowsSecond), iColumn);
                        else
                            % dependency not directly given
                            % interpolation over both dependencies needed
                            % look why warning is given out and/or suppres it
                            warning('off', 'all');
                            % before executing the slow scatteredInterpolant, look if all properties same as last time
                            try
                                if iColumn == this.cfLastProps.iColumn && iColumnFirst == this.cfLastProps.iColumnFirst && ...
                                    iColumnSecond == this.cfLastProps.iColumnSecond && strcmp(sProperty, this.cfLastProps.sProperty) && ...
                                    strcmp(sFirstDepName, this.cfLastProps.sFirstDepName) && strcmp(sSecondDepName, this.cfLastProps.sSecondDepName)
                                    aCheck{1} = [fFirstDepValue; this.cfLastProps.fFirstDepValue];
                                    aCheck{2} = [fSecondDepValue; this.cfLastProps.fSecondDepValue];
                                    aDiff = cell(1,length(aCheck));
                                    for i=1:length(aCheck)
                                        if aCheck{i}(1,:) ~= 0
                                            aDiff{i} = abs(diff(aCheck{i})/aCheck{i}(1,:));
                                        else
                                            aDiff{i} = 0;
                                        end
                                    end
                                    % more than 1% difference (or what is defined in rMaxChange) from last 
                                    % -> recalculate and save attributes for next run
                                    if any(cell2mat(aDiff) > this.rMaxChange) 
                                            % create temporary array because scatteredInterpolant doesn�t allow nan values
                                            afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                                            afTemporary(isnan(afTemporary)) = 0;
                                            afTemporary = sortrows(afTemporary,1);
                                            % interpolate linear with no extrapolation
                                            F = scatteredInterpolant(afTemporary(:,2),afTemporary(:,3),afTemporary(:,1),'linear','none');
                                            fProperty = F(fFirstDepValue, fSecondDepValue);
                                            % save properties for next run
                                            this.cfLastProps.fProperty = fProperty;
                                            this.cfLastProps.iColumn = iColumn;
                                            this.cfLastProps.iColumnFirst = iColumnFirst;
                                            this.cfLastProps.iColumnSecond = iColumnSecond;
                                            this.cfLastProps.sProperty = sProperty;
                                            this.cfLastProps.fFirstDepValue = fFirstDepValue;
                                            this.cfLastProps.sFirstDepName = sFirstDepName;
                                            this.cfLastProps.fSecondDepValue = fSecondDepValue;
                                            this.cfLastProps.sSecondDepName = sSecondDepName;
                                    else
                                            fProperty = this.cfLastProps.fProperty;
                                    end
                                else
                                    % create temporary array because scatteredInterpolant doesn�t allow nan values
                                    afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                                    afTemporary(isnan(afTemporary)) = 0;
                                    afTemporary = sortrows(afTemporary,1);
                                    % interpolate linear with no extrapolation
                                    F = scatteredInterpolant(afTemporary(:,2),afTemporary(:,3),afTemporary(:,1),'linear','none');
                                    fProperty = F(fFirstDepValue, fSecondDepValue);
                                    % save properties for next run
                                    this.cfLastProps.fProperty = fProperty;
                                    this.cfLastProps.iColumn = iColumn;
                                    this.cfLastProps.iColumnFirst = iColumnFirst;
                                    this.cfLastProps.iColumnSecond = iColumnSecond;
                                    this.cfLastProps.sProperty = sProperty;
                                    this.cfLastProps.fFirstDepValue = fFirstDepValue;
                                    this.cfLastProps.sFirstDepName = sFirstDepName;
                                    this.cfLastProps.fSecondDepValue = fSecondDepValue;
                                    this.cfLastProps.sSecondDepName = sSecondDepName;
                                end
                            catch 
                               % the struct has to be constructed for the first time
                                % create temporary array because griddata doesn�t allow nan values
                                afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                                afTemporary(isnan(afTemporary)) = 0;
                                afTemporary = sortrows(afTemporary,1);
                                % interpolate linear with no extrapolation
                                F = scatteredInterpolant(afTemporary(:,2),afTemporary(:,3),afTemporary(:,1),'linear','none');
                                fProperty = F(fFirstDepValue, fSecondDepValue);
                                % save properties for next run
                                this.cfLastProps.fProperty = fProperty;
                                this.cfLastProps.iColumn = iColumn;
                                this.cfLastProps.iColumnFirst = iColumnFirst;
                                this.cfLastProps.iColumnSecond = iColumnSecond;
                                this.cfLastProps.sProperty = sProperty;
                                this.cfLastProps.fFirstDepValue = fFirstDepValue;
                                this.cfLastProps.sFirstDepName = sFirstDepName;
                                this.cfLastProps.fSecondDepValue = fSecondDepValue;
                                this.cfLastProps.sSecondDepName = sSecondDepName;
                            end
                            %disp(['property: ', sProperty, ' first dep: ', sFirstDepName, ' first value: ', num2str(fFirstDepValue), ' second dep: ', sSecondDepName, ' second value: ', num2str(fSecondDepValue), ' column: ', num2str(iColumn)]);
                            %fProperty = griddata(afTemporary(:,2),afTemporary(:,3),(afTemporary(:,1)),fFirstDepValue,fSecondDepValue,'linear');
                            warning('on', 'all');
                            % check if found propertyvalue is in range of table (no extrapolation)
                            % not more needed
%                             if fProperty < min(afTemporary(:,1)) || fProperty > max(afTemporary(:,1))
%                                 fprintf(2,'out of range for species %s',sSpecies,' -> []');
%                                 fProperty = [];
%                             end
                        end
                    else
                        % one or more dependencies are out of range
                        % look if data is in MatterData
                        if isfield(this.ttxMatter.(sSpecies), 'MatterData')
                            iRowsFirstMatterData = find(strcmpi(this.ttxMatter.(sSpecies).MatterData.text(:,3), sPhase), 1, 'first');
                        else
                            iRowsFirstMatterData = [];
                        end
                        if iRowsFirstMatterData
                            % data found in MatterData
                            % first get column of property
                            iColumn = find(strcmp(this.ttxMatter.(sSpecies).MatterData.text(1,:), sPropertyName)); % row 1 is std propertyname in MatterData
                            if isempty(iColumn) && strcmp(sProperty, 'c_p')
                                % if heatcapacity (c_p) is searched, it is written as SHC in MatterData
                                iColumn = find(strcmp(this.ttxMatter.(sSpecies).MatterData.text(1,:), 'SHC')); 
                            end
                             % get the propertyvalue
                            fProperty = this.ttxMatter.(sSpecies).MatterData.num(iRowsFirstMatterData-2,iColumn-3);
                        else
                            % no found data in MatterData
                            % get 'best' value in Range of speciestable
                            warning('off', 'all');
                            % before executing the slow scatteredInterpolant, look if all properties same as last time
                            try
                                if iColumn == this.cfLastProps.iColumn && iColumnFirst == this.cfLastProps.iColumnFirst && ...
                                    iColumnSecond == this.cfLastProps.iColumnSecond && strcmp(sProperty, this.cfLastProps.sProperty) && ...
                                    strcmp(sFirstDepName, this.cfLastProps.sFirstDepName) && strcmp(sSecondDepName, this.cfLastProps.sSecondDepName)
                                    aCheck{1} = [fFirstDepValue; this.cfLastProps.fFirstDepValue];
                                    aCheck{2} = [fSecondDepValue; this.cfLastProps.fSecondDepValue];
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
                                        % create temporary array because griddata doesn�t allow nan values
                                        afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                                        afTemporary(isnan(afTemporary)) = 0;
                                        afTemporary = sortrows(afTemporary,1);
                                        % interpolate linear with no extrapolation
                                        F = scatteredInterpolant(afTemporary(:,2),afTemporary(:,3),afTemporary(:,1),'linear','none');
                                        fProperty = F(fFirstDepValue, fSecondDepValue);
                                        % save properties for next run
                                        this.cfLastProps.fProperty = fProperty;
                                        this.cfLastProps.iColumn = iColumn;
                                        this.cfLastProps.iColumnFirst = iColumnFirst;
                                        this.cfLastProps.iColumnSecond = iColumnSecond;
                                        this.cfLastProps.sProperty = sProperty;
                                        this.cfLastProps.fFirstDepValue = fFirstDepValue;
                                        this.cfLastProps.sFirstDepName = sFirstDepName;
                                        this.cfLastProps.fSecondDepValue = fSecondDepValue;
                                        this.cfLastProps.sSecondDepName = sSecondDepName;
                                    else
                                        fProperty = this.cfLastProps.fProperty;
                                    end
                                else
                                    % create temporary array because griddata doesn�t allow nan values
                                    afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                                    afTemporary(isnan(afTemporary)) = 0;
                                    afTemporary = sortrows(afTemporary,1);
                                    % interpolate linear with no extrapolation
                                    F = scatteredInterpolant(afTemporary(:,2),afTemporary(:,3),afTemporary(:,1),'linear','none');
                                    fProperty = F(fFirstDepValue, fSecondDepValue);
                                    % save properties for next run
                                    this.cfLastProps.fProperty = fProperty;
                                    this.cfLastProps.iColumn = iColumn;
                                    this.cfLastProps.iColumnFirst = iColumnFirst;
                                    this.cfLastProps.iColumnSecond = iColumnSecond;
                                    this.cfLastProps.sProperty = sProperty;
                                    this.cfLastProps.fFirstDepValue = fFirstDepValue;
                                    this.cfLastProps.sFirstDepName = sFirstDepName;
                                    this.cfLastProps.fSecondDepValue = fSecondDepValue;
                                    this.cfLastProps.sSecondDepName = sSecondDepName;
                                end
                            catch 
                               % the struct has to be constructed for the first time
                                % create temporary array because griddata doesn�t allow nan values
                                afTemporary = this.ttxMatter.(sSpecies).import.num(:,[iColumn, iColumnFirst, iColumnSecond]);
                                afTemporary(isnan(afTemporary)) = 0;
                                afTemporary = sortrows(afTemporary,1);
                                % interpolate linear with no extrapolation
                                F = scatteredInterpolant(afTemporary(:,2),afTemporary(:,3),afTemporary(:,1),'linear','none');
                                fProperty = F(fFirstDepValue, fSecondDepValue);
                                % save properties for next run
                                this.cfLastProps.fProperty = fProperty;
                                this.cfLastProps.iColumn = iColumn;
                                this.cfLastProps.iColumnFirst = iColumnFirst;
                                this.cfLastProps.iColumnSecond = iColumnSecond;
                                this.cfLastProps.sProperty = sProperty;
                                this.cfLastProps.fFirstDepValue = fFirstDepValue;
                                this.cfLastProps.sFirstDepName = sFirstDepName;
                                this.cfLastProps.fSecondDepValue = fSecondDepValue;
                                this.cfLastProps.sSecondDepName = sSecondDepName;
                            end
                            %disp(['property: ', sProperty, ' first dep: ', sFirstDepName, ' first value: ', num2str(fFirstDepValue), ' second dep: ', sSecondDepName, ' second value: ', num2str(fSecondDepValue), ' column: ', num2str(iColumn)]);
                            %fProperty = griddata(afTemporary(:,2),afTemporary(:,3),(afTemporary(:,1)),fFirstDepValue,fSecondDepValue,'linear');
                            warning('on', 'all');
                        end
                    end
                    
                end
                
            % get species property from MatterData     
            else
                % get the rows of the phase of the species
                % dynamic search of column phase?
                rowPhase = find(strcmp(this.ttxMatter.(sSpecies).import.text(:,3), sPhase), 1, 'first');
                if rowPhase
                    % get the propertyvalue
                    fProperty = this.ttxMatter.(sSpecies).import.raw{rowPhase,iColumn};%fProperty = this.ttxMatter.(sSpecies).MatterData.num(rowPhase-2,iColumn-3);
                else
                    % no phase for species found
                    fProperty = 0;
                end
             
            end
            
            % final check when found propertyvalue is nan
            if isnan(fProperty); fProperty = 0; end;
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
        function this = createMatterData(this, oParent, sSpeciesname)
            % handles import of data. At first call (at initialisation) it
            % loads the standard worksheet MatterData and save the needed
            % structures etc. If called with arguments the parent object
            % must have a field with a valid phase and the species (sSpeciesname)
            % has to be handed over
            %
            % createMatterData returns
            %  this  - oMT object�
            %
            % inputs:
            % oParent: Partent object, needed for verification of phase
            % sSpeciesname: speciesname (also worksheet name!)
            
            %% Access specific worksheets in MatterXLS
            % executed if no inputs handed over
            if nargin > 1
                % First it checks if correct phase from parent object is handed over.
                % Then call of Matterimport that imports the needed worksheetdata.
                % After that it checks also type of pressure and corrects vaulues if needed
                % fields that created at the first exection and used in other classes 
                % had to include the new species
                
                % check if phase in parent object are present
                if isobject(oParent)
                    if ~isprop(oParent, 'sType')
                        this.throw('table:import','no phasetype from parent class received');
                    elseif ~any(strcmpi({'solid','gas','liquid'},oParent.sType))
                        this.trow('table:import','no valid phasetype from parent class received');
                    end
                end

                % import from worksheet sSpeciesname (strrep with filesep is used for compatibility of MS and Mac OS)
                this.ttxMatter.(sSpeciesname) = this.Matterimport(strrep('core\+matter\Matter.xlsx','\',filesep), sSpeciesname);

                % handle Pressure values (convert bar in Pa if necessary)
                iColumn = this.FindColumn('Pressure', sSpeciesname);
                if strcmpi(this.ttxMatter.(sSpeciesname).import.text(6,iColumn), 'bar')
                    this.ttxMatter.(sSpeciesname).import.num(5:end,iColumn) = this.ttxMatter.(sSpeciesname).import.num(5:end,iColumn)*100000;
                elseif strcmpi(this.ttxMatter.(sSpeciesname).import.text(6,iColumn), 'Pa')
                    % nothing, all good
                else
                    this.throw('table:createMatterData',sprintf('Pressure-type %s unkown', this.ttxMatter.(sSpeciesname).import.text(6,iColumn)));
                end
                
                % new species, so some fields, like number of species and molmass array, has to be extend
                if ~any(strcmp(this.csSpecies, sSpeciesname))
                    % index of new species is one times higher than last one 
                    iIndex = this.iSpecies+1;
                    % write new speciesname in cellarray
                    this.csSpecies{iIndex} = sSpeciesname;
                    % index of new species into number2index array
                    this.tiN2I.(sSpeciesname) = iIndex;
                    this.iSpecies = iIndex;
                    % molmass of species into molmass array
                    this.afMolMass(iIndex) = this.ttxMatter.(sSpeciesname).fMolMass;

                    % go through all phases (solid, gas, liquid) and write correct value in array tafCp
                    % and tafDensity from new import
                    cPhases = fieldnames(this.tafDensity);
                    for i=1:length(cPhases)
                        % if value of density is stored in fRoh and is a number and in right phase
                        if isfield(this.ttxMatter.(sSpeciesname), 'fRoh') && ~isnan(this.ttxMatter.(sSpeciesname).fRoh) && strcmp(oParent.sType, cPhases{i})
                            this.tafDensity.(cPhases{i})(iIndex) = this.ttxMatter.(sSpeciesname).fRoh;
                        else % std is -1
                            this.tafDensity.(cPhases{i})(iIndex) = -1;
                        end

                    end
                end
                                    
            else
                %% load MatterData (standard Mattertable)
                % this is executed at initialisation (from class simulation)
                
                % import from worksheet MatterData (strrep with filesep is used for compatibility of MS and Mac OS)
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

                    % Go through phases and write density
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
        
        function ttxImportMatter = Matterimport(this, sFile, sWorksheetname)
            % importfunction that handles import from species worksheet for
            % one species or at initialisation the import from worksheet MatterData.
            % First it looks if speciesdata is already importet (for a specific species).
            % After import with xlsread it gets the data in the right
            % format for later use
            %
            % Matterimport returns
            %  ttxImportMatter - struct with all data
            %
            % inputs
            % sFile: complete filename of MatterXLS
            % sWorksheetname: worksheet name
            % store all worksheets form excelfile and look if file is readable
            % worksheetnames used in FindProperty to look if maybe more
            % data is availeable
            if isempty(this.asWorksheets)
                [sStatus, this.asWorksheets] = xlsfinfo(sFile);
                if ~any(strcmp(sStatus, {'Microsoft Excel Spreadsheet', 'Microsoft Macintosh Excel Spreadsheet'}))
                    this.throw('table:Matterimport',sprintf('File %s has wrong format for Matterimport',sFile));
                end
            end
            
            %% import worksheet MatterData (standard Mattertable)
            % this is executed at initialisation (from class simulation)
            if strcmp(sWorksheetname, 'MatterData') && any(strcmpi(this.asWorksheets, 'MatterData'))
                
                % import of worksheet
                %[import.num, import.text, import.raw] = xlsread(sFile, sWorksheetname);
                
                [import.num, import.text, import.raw] = this.customXlsread(sFile, sWorksheetname);
                
                % Search for empty cell in first row.; Column before is last Tablecolumn. All data after that is not
                % imported.
                % Then store tablelength and column of density ("codename" of first property to store in phase) to
                % save all properties. 
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
                    ttxImportMatter.(scSpecies{i}) = [];
                    %ttxImportMatter = setfield(ttxImportMatter, scSpecies{i},'');
                    
                    % select all rows of that species
                    % species can have more than one phase
                    iRows = find(strcmp(import.text(3:end,1),scSpecies{i})); 
                    if ~isempty(iRows)
                        % rownumbers of .num and .text/.raw are 2 rows different because of headers
                        iRows = iRows +2;
                        % store all data of current species
                        ttxImportMatter.(scSpecies{i}).import.num = import.num(iRows-2,:);
                        ttxImportMatter.(scSpecies{i}).import.num(:,iTableLength+1:end) = []; % overhead not needed
                        ttxImportMatter.(scSpecies{i}).import.text = import.text(1:2,:);
                        ttxImportMatter.(scSpecies{i}).import.text = [ttxImportMatter.(scSpecies{i}).import.text; import.text(iRows,:)];
                        ttxImportMatter.(scSpecies{i}).import.text(:,iTableLength+1:end) = []; % overhead not needed
                        ttxImportMatter.(scSpecies{i}).import.raw = import.raw(1:2,:);
                        ttxImportMatter.(scSpecies{i}).import.raw = [ttxImportMatter.(scSpecies{i}).import.raw; import.raw(iRows,:)];
                        ttxImportMatter.(scSpecies{i}).import.raw(:,iTableLength+1:end) = []; % overhead not needed
                        % go through all properties before density
                        % this properties are constant and only needed one time
                        for j = 4:iColumn-1
                            if ~isnan(import.num(iRows(1)-2,j-3))
                                ttxImportMatter.(scSpecies{i}).(import.text{2,j}) = import.num(iRows(1)-2,j-3);
                            end
                        end
                        % go through all phases and save all remaining properties for that specific phase
                        for z = 1:length(iRows) 
                            for j = iColumn:iTableLength 
                                if ~isnan(import.num(iRows(z)-2,j-3))
                                    ttxImportMatter.(scSpecies{i}).ttxPhases.(import.text{iRows(z),3}).(import.text{2,j}) = import.num(iRows(z)-2,j-3);
                                end
                            end

                        end
                        
                    end
                end
            %% import specific species worksheet
            else
                % first look if data is not already imported
                % if data is imported check size of imported data (data from MatterData has max size of 5)
                if isfield(this.ttxMatter, sWorksheetname) && length(this.ttxMatter.(sWorksheetname).import.raw(:,1)) < 6
                    
                    % save data of species from worksheet MatterData
                    ttxImportMatter.MatterData.raw = this.ttxMatter.(sWorksheetname).import.raw;
                    ttxImportMatter.MatterData.num = this.ttxMatter.(sWorksheetname).import.num;
                    ttxImportMatter.MatterData.text = this.ttxMatter.(sWorksheetname).import.text;
                                        
                % data is already imported -> get back
                elseif isfield(this.ttxMatter, sWorksheetname)
                    return;
                end
                
                % import worksheet sWorksheetname
                [import.num, import.text, import.raw] = this.customXlsread(sFile, sWorksheetname);
                %[import.num, import.text, import.raw] = xlsread(sFile, sWorksheetname);

                % save data for later use
                ttxImportMatter.import.text = import.text;
                ttxImportMatter.import.num = import.num;
                ttxImportMatter.import.raw = import.raw;
                ttxImportMatter.SpeciesName = import.text{1,1};

                % get last column (length of table)
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
            % most used function (often called in loops)
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
                if size(this.ttxMatter.(sSpecies).import.raw, 1) > 5
                    iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(5,:),sPropertyName)); % row 5 is std propertyname
                    if isempty(iColumn)
                        iColumn = find(strcmp(this.ttxMatter.(sSpecies).import.text(7,:),sPropertyName)); % search row 7 as alternative
                    end
                    return
                else
                    % Heatcapacity is written SHC in worksheet MatterData
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
           if isnumeric(xForProp)
               iColumn = xForProp;
           elseif ischar(xForProp)
               iColumn = this.FindColumn(xForProp, sSpecies);
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
        
        function [numOut, textOut, rawOut] = customXlsread(~, sFile, sWorksheetname)
           % this is a customised xlsread function
           % no unnecessary functionality like xml import function and lots of queries removed
           % it is used in Matterimport
           %
           % customXlsread returns
           %  numOut: numeric data from worksheet
           %  textOut: string data from worksheet
           %  rawOut: all data from worksheet
           %
           % inputs:
           % sFile: filename of excelfile
           % sWorksheetname: name of worksheet for import
           
           % no arguments handed over, abort function
           if nargin < 3 || isempty(sFile) || isempty(sWorksheetname)
               numOut = [];
               textOut = [];
               rawOut = [];
               return
           end
           
           % used activeXserver is only available at windows
           basicMode = ~ispc;
           
            % Try to reuse an existing COM server instance if possible
            try
                Excel = actxGetRunningServer('excel.application');
                % no crash so probably succeeded to connect to a running server
            catch
                % Never mind - try to continue normally to start the COM server and connect to it
                try
                    Excel = actxserver('excel.application');
                catch
                    % no activeXserver available or excel not installed, use basic mode of xlsread
                    basicMode = true;
                end
            end
            
            % use xlsread in basic mode
            if basicMode
                [numOut, textOut, rawOut] = xlsread(sFile, sWorksheetname, '', 'basic');
                return
            end
            
            % try to get full path of file
            try
                sFile = validpath(sFile);
            catch exception
                error(message('MATLAB:xlsread:FileNotFound', sFile, exception.message));
            end
            
            readOnly = true;
            Excel.DisplayAlerts = 0;

            % Associate event handler for COM object event at run time
            registerevent(Excel,{'WorkbookActivate', @WorkbookActivateHandler});
            % open worksheet in readonly mode
            Excel.workbooks.Open(sFile, 0, readOnly);
            
            % wait for response from activeXserver to open worksheet
            for i = 1:500
                try
                    workbook.FileFormat;
                    break;
                catch exception %#ok<NASGU>
                    pause(0.01);
                end
            end

            WorkSheets = workbook.Worksheets;

            % Get name of specified worksheet from workbook
            try
                TargetSheet = get(WorkSheets,'item',sWorksheetname);
            catch  %#ok<CTCH>
                error(message('MATLAB:xlsread:WorksheetNotFound', sWorksheetname));
            end

            %Activate silently fails if the sheet is hidden
            set(TargetSheet, 'Visible','xlSheetVisible');
            % activate worksheet
            Activate(TargetSheet);

            % get range of worksheet
            DataRange = workbook.ActiveSheet.UsedRange;
            
            % get data from worksheet
            rawOut = DataRange.Value;
            if ~iscell(rawOut)
                rawOut = {rawOut};
            end

            % get numeric and text data splited from worksheetdata
            [numOut, textOut] = xlsreadSplitNumericAndText(rawOut); 

            % nested functions
            % used from private folder iofun on matlabpath
            % -------------------------------------------------------------------------
            % for workbook activation
            function WorkbookActivateHandler(varargin)
                    workbook = varargin{3};
            end
            % -------------------------------------------------------------------------
            % for Split Numeric And Text
            function [numericData, textData] = xlsreadSplitNumericAndText(data)
                % xlsreadSplitNumericAndText parses raw data into numeric and text arrays.
                %   [numericData, textData] = xlsreadSplitNumericAndText(DATA) takes cell
                %   array DATA from spreadsheet and returns a double array numericData and
                %   a cell string array textData.
                %
                %   See also XLSREAD, XLSWRITE, XLSFINFO.

                %   Copyright 1984-2012 The MathWorks, Inc.


                % ensure data is in cell array
                if ischar(data)
                    data = cellstr(data);
                elseif isnumeric(data) || islogical(data)
                    data = num2cell(data);
                end

                % Check if raw data is empty
                if isempty(data)
                    % Abort when all data cells are empty.
                    textData = {};
                    numericData = [];
                    return
                end

                % Initialize textData as an empty cellstr of the right size.
                textData = cell(size(data));
                textData(:) = {''};

                % Find non-numeric entries in data cell array
                isTextMask = cellfun('isclass',data,'char');

                % Place text cells in text array
                if any(isTextMask(:))
                    textData(isTextMask) = data(isTextMask);
                else
                    textData = {};
                end
                % Excel returns COM errors when it has a #N/A field.
                textData = strrep(textData,'ActiveX VT_ERROR: ','#N/A');

                % Trim the leading and trailing empties from textData
                emptyTextMask = cellfun('isempty', textData);
                textData = filterDataUsingMask(textData, emptyTextMask);

                % place NaN in empty numeric cells
                if any(isTextMask(:))
                    data(isTextMask)={NaN};
                end

                % Find non-numeric entries in data cell array
                isLogicalMask = cellfun('islogical',data);

                % Convert cell array to numeric array through concatenating columns then
                % rows.
                cols = size(data,2);
                tempDataColumnCell = cell(1,cols);
                % Concatenate each column first
                for n = 1:cols
                    tempDataColumnCell{n} = cat(1, data{:,n});
                end
                % Now concatenate the single column of cells into a numeric array.
                numericData = cat(2, tempDataColumnCell{:});

                % Trim all-NaN leading and trailing rows and columns from numeric array
                isNaNMask = isnan(numericData);
                if all(isNaNMask(:))
                    numericData = [];
                else
                    [numericData, isNaNMask] = filterDataUsingMask(numericData, isNaNMask);
                end

                % Restore logical type if all values were logical.
                if any(isLogicalMask(:)) && ~any(isNaNMask(:))
                    numericData = logical(numericData);
                end

                % Ensure numericArray is 0x0 empty.
                if isempty(numericData)
                    numericData = [];
                end
            end 
            function  [row, col] = getCorner(mask, firstlast)
                isLast = strcmp(firstlast,'last');

                % Find first (or last) row that is not all true in the mask.
                row = find(~all(mask,2), 1, firstlast);
                if isempty(row)
                    row = emptyCase(isLast, size(mask,1));
                end

                % Find first (or last) column that is not all true in the mask.
                col = find(~all(mask,1), 1, firstlast);
                % Find returns empty if there are no rows/columns that contain a false value.
                if isempty(col)
                    col = emptyCase(isLast, size(mask,2));
                end    
            end
            function [data, mask] = filterDataUsingMask(data, mask)
                [rowStart, colStart] = getCorner(mask, 'first');
                [rowEnd, colEnd] = getCorner(mask, 'last');
                data = data(rowStart:rowEnd, colStart:colEnd);
                mask = mask(rowStart:rowEnd, colStart:colEnd);
            end
            function dim = emptyCase(isLast, dimSize)
                if isLast
                    dim = dimSize;
                else
                    dim = 1;
                end
            end
            % -------------------------------------------------------------------------
            % for generation of full filepath
            function filenameOut = validpath(filename)
                % VALIDPATH builds a full path from a partial path specification
                %   FILENAME = VALIDPATH(FILENAME) returns a string vector containing full
                %   path to a file. FILENAME is string vector containing a partial path
                %   ending in a file or directory name. May contain ..\  or ../ or \\. The
                %   current directory (pwd) is prepended to create a full path if
                %   necessary. On UNIX, when the path starts with a tilde, '~', then the
                %   current directory is not prepended.
                %
                %   See also XLSREAD, XLSWRITE, XLSFINFO.

                %   Copyright 1984-2012 The MathWorks, Inc.

                %First check for wild cards, since that is not supported.
                if strfind(filename, '*') > 0
                    error(message('MATLAB:xlsread:Wildcard', filename));
                end

                % break partial path in to file path parts.
                [Directory, file, ext] = fileparts(filename);

                if ~isempty(ext)
                    filenameOut = getFullName(filename);
                else
                    extIn = matlab.io.internal.xlsreadSupportedExtensions;
                    for ii = 1:length(extIn)
                        try                                                                %#ok<TRYNC>
                            filenameOut = getFullName(fullfile(Directory, [file, extIn{i}]));
                            return;
                        end
                    end
                    error(message('MATLAB:xlsread:FileDoesNotExist', filename));    
                end
            end
            function absolutepath=abspath(partialpath)

                % parse partial path into path parts
                [pathname, filename, ext] = fileparts(partialpath);
                % no path qualification is present in partial path; assume parent is pwd, except
                % when path string starts with '~' or is identical to '~'.
                if isempty(pathname) && strncmp('~', partialpath, 1)
                    Directory = pwd;
                elseif isempty(regexp(partialpath,'(.:|\\\\)', 'once')) && ...
                        ~strncmp('/', partialpath, 1) && ...
                        ~strncmp('~', partialpath, 1);
                    % path did not start with any of drive name, UNC path or '~'.
                    Directory = [pwd,filesep,pathname];
                else
                    % path content present in partial path; assume relative to current directory,
                    % or absolute.
                    Directory = pathname;
                end

                % construct absolute filename
                absolutepath = fullfile(Directory,[filename,ext]);
            end
            function filename = getFullName(filename)
                FileOnPath = which(filename);
                if isempty(FileOnPath)
                    % construct full path to source file
                    filename = abspath(filename);
                    if isempty(dir(filename)) && ~isdir(filename)
                        % file does not exist. Terminate importation of file.
                        error(message('MATLAB:xlsread:FileDoesNotExist', filename));
                    end
                else
                    filename = FileOnPath;
                end
            end
            % -------------------------------------------------------------------------
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




