classdef phase < base & matlab.mixin.Heterogeneous
    %MATTERPHASE Summary of this class goes here
    %   Detailed explanation goes here
    %
    %
    %TODO need a clean separation between processors (move stuff from one
    %     phase to another, change flows, phase to flow processors) and
    %     manipulators (change volume/temperature/..., split up molecules,
    %     and other stuff that happens within a phase).
    %     Best way to introduce those manipulators? Just callbacks/events,
    %     or manipulator classes? One object instance per manipulator, and
    %     relate all phases that are using this manipulator, or one object
    %     per class?
    %     Package manip.change.vol -> manipulators .isobaric, .isochoric
    %     etc - one class/function each. Then, as for meta model in VHP, 
    %     registered as callbacks for e.g. set.fVolume in phase, and return
    %     values of callbacks determine what happens?
    
    
    % Abstracts - matter.phase can't be used directly, just derivatives!
    properties (SetAccess = protected, GetAccess = public, Abstract = true)
        % Type of phase - abstract to force the derived classes to set the
        % value and to ensure that matter.phase is never used directly!
        sType;
    end
    
    % Basic parameters
    properties (SetAccess = protected, GetAccess = public)
        % Masses for every species, temperature of phase
        afMass;             % [kg]
        fTemp;              % [K]
        
        %%%% Dependent variables:
        % Partial masses for every species and total mass
        arPartialMass;    % [%]
        fMass;              % [kg]
        
        % Mol mass, heat capacity
        fMolMass;           % [g/mol]
        fHeatCapacity;      % [J/K]
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Parent - store
        oStore;
        
        % Matter table
        oMT;
        
        % Name of phase
        sName;
        
        % Internal processors have to be used if a specific parameter shall
        % be changed.
        %TODO object references or function handles?
        %     internal processors renamed to manipulator.
        %ttoProcs = struct('internal', struct(), 'extract', struct(), 'merge', struct());
        
        
        % Extract/Merge processors - "ports", so key of struct (set to the
        % processors name) can be used to receive that port. If 'default'
        % as name, several flows can be connected.
        %TODO rename to f2p processor?
        toProcsEXME = struct();
        
        % Cache for procs ... see .update()
        coProcsEXME;
        iProcsEXME;
     end
    
    % Derived values
    properties (SetAccess = protected, GetAccess = public)
        % Not handled by Matter, has to be set by derived state class
        fDensity = -1;      % [kg/m^3]
    end
    
    methods
        function this = phase(oStore, sName, tfMass, fTemp)
            % Constructor for the matter.phase class. Input parameters can
            % be provided to define the contained masses and temperature,
            % additionally the internal, merge and extract processors.
            %
            % phase parameters:
            %   oStore  - object reference to the store, matter table also
            %             received from there
            %   sName   - name of the phase
            %   aoPorts - ports (exme procs instances); can be empty or not
            %             provided, but then no mass can be extracted or
            %             merged.
            %   tfMass  - optional. Struct containing the initial masses. 
            %             Keys refer to the name of the according species
            %   fTemp 	- temperature of the initial mass, has to be given
            %             if  tfMass is provided
            
            % Parent has to be a or derive from matter.store
            if ~isa(oStore, 'matter.store'), this.throw('phase', 'Provided oStore parameter has to be a matter.store'); end;
            
            
            % Set name
            this.sName = sName;
            
            
            % Parent store - FIRST call addPhase on parent, THEN set the
            % store as the parent - matter.store.addPhase only does that if
            % the oStore attribute here is empty!
            this.oStore = oStore.addPhase(this);
            
            % Set the matter table
            %this.oMT = oMT;
            this.updateMatterTable();
            
            % Preset masses
            this.afMass = zeros(1, this.oMT.iSpecies);
            
            % Mass provided?
            %TODO do all that in a protected addMass method? Especially the
            %     partial masses calculation -> has to be done on .update()
            if (nargin >= 3) && ~isempty(tfMass) && ~isempty(fieldnames(tfMass))
                % If tfMass is provided, fTemp also has to be there
                if nargin < 4 || isempty(fTemp) || ~isnumeric(fTemp) || (fTemp <= 0)
                    this.throw('phase', 'If tfMass is provided, the fTemp parameter also has to be provided (Kelvin, non-empty number, greater than zero).');
                end
                
                % Extract initial masses from tfMass and set to afMass
                csKeys = fieldnames(tfMass);
                
                for iI = 1:length(csKeys)
                    sKey = csKeys{iI};
                    
                    if ~isfield(this.oMT.tiN2I, sKey), this.throw('phase', 'Matter type %s unkown to matter.table', sKey); end;
                    
                    this.afMass(this.oMT.tiN2I.(sKey)) = tfMass.(sKey);
                end

                % Calculate total mass
                this.fMass = sum(this.afMass);

                % Calculate the partial masses
                for iI = 1:length(csKeys)
                    sKey = csKeys{iI};
                    this.arPartialMass(this.oMT.tiN2I.(sKey)) = this.afMass(this.oMT.tiN2I.(sKey)) / this.fMass;
                end
                
                % Handle temperature
                this.fTemp = fTemp;
            else
                % No mass - no temp
                this.fTemp = 0;
            end
            
            % Immediately calc matter params
            %TODO check - if mass 0 --> NaNs!
            this.update(0);
        end
        
        function this = update(this, fTimeStep)
            % The .update method does actually add or subtract the mass
            % depending on the flow rates on exmes and the time step. So if
            % only an update of internal parameters is desired, call this
            % method without a parameter or .update(0)
            
            % Don't execute the merge/extract if time step = 0 -> just
            % update of matter properties
            %TODO two separate methods? make a method similar to flows to
            %     merge/extract on a number of phases at once, maybe some
            %     vector operations (same matter table!).
            %     See below, setParam -> some static, class (and not obj)
            %     based event for params like volume, always exec .update
            %     after that event.
            bNoEXMEs = (nargin < 2) || isempty(fTimeStep) || (fTimeStep == 0);
            
            %TODO first do all mergers, then calc all new things, then exs?
            % mergers, p2p mergers, .update(), p2p extract, extract, update
            %   - with p2p -> first outer merge, inner merge, then inner
            %     extract (selective exme), outer extract
            %   - e.g. arPartials of phase required in each EXME for
            %     relatives, update after EACH exme or once at the end?
            %     Because probably else problem if selective ex/normal ex?
            
            if ~bNoEXMEs
                for iI = 1:this.iProcsEXME
                    this.coProcsEXME{iI}.update(fTimeStep, 'merge');
                end
            end
            
            
            if strcmp(this.sName, 'air') && strcmp(this.oStore.sName, 'Filter')
                %disp(this.afMass);
            end
            
            
            %TODO only recalculate after extract?
            this.fMass         = sum(this.afMass);
            % No mass - partials zero
            if this.fMass > 0, this.arPartialMass = this.afMass / this.fMass;
            else               this.arPartialMass = this.afMass; % afMass is just zeros
            end
            
            
            
            % Now update the matter properties
            this.fMolMass = this.oMT.calculateMolecularMass(this.afMass);
            
            %TODO see table - maybe Cps dependent on temperature and other
            %     stuff here - so maybe calcHeatCaps has to re-calc the mix
            %     total heat capacity with a callback to get the single
            %     heat capacities of the matter types depenedent on phase,
            %     temperature etc
            %     Might be a more or less simple 2d interpolation if just
            %     lookup tables, right?
            this.fHeatCapacity = this.oMT.calculateHeatCapacity(this);
            
            
            
            if ~bNoEXMEs
                for iI = 1:this.iProcsEXME
                    this.coProcsEXME{iI}.update(fTimeStep, 'extract');
                    
                end
            end
            
            % And again update partials in case of selective EXMEs
            this.fMass         = sum(this.afMass);
            % No mass - partials zero
            if this.fMass > 0, this.arPartialMass = this.afMass / this.fMass;
            else               this.arPartialMass = this.afMass;
            end
            
            this.fMolMass = this.oMT.calculateMolecularMass(this.afMass);
            this.fHeatCapacity = this.oMT.calculateHeatCapacity(this);
        end
    end
    
    
    %% Methods for adding ports etc
    % The EXME procs get an instance to this object on construction and
    % call the addProcEXME here, therefore not protected - but checks
    % the store's bSealed attr, so nothing can be changed later.
    methods
        
        function setAttribute = addProcEXME(this, oProcEXME)
            % Adds a exme proc, i.e. a port. Returns a function handle to
            % the this.setAttribute method (actually the one of the derived
            % class) which allows manipulation of all set protected
            % attributes within the phase.
            
            if this.oStore.bSealed
                this.throw('addProcEXME', 'The store to which this phase belongs is sealed, so no ports can be added any more.');
            end
            
            if ~isa(oProcEXME, 'matter.procs.exme')
                this.throw('addProcEXME', 'Provided object ~isa matter.procs.f2f.');
                
            elseif ~isempty(oProcEXME.oPhase)
                this.throw('addProcEXME', 'Processor has already a phase set as parent.');
                
            elseif isfield(this.toProcsEXME, oProcEXME.sName)
                this.throw('addProcEXME', 'Proc %s already exists.', oProcEXME.sName);
                
            end
            
            
            
            this.toProcsEXME.(oProcEXME.sName) = oProcEXME;
            setAttribute = @this.setAttribute;
        end
        
        function seal(this)
            if ~this.oStore.bSealed
                this.coProcsEXME = struct2cell(this.toProcsEXME)';
                this.iProcsEXME  = length(this.coProcsEXME);
            end
        end
    end
    
    
    %% Internal, protected methods
    methods (Access = protected)
        function this = updateMatterTable(this)
            % Update matter table from parent oStore. The afMass vector is 
            % automatically rearranged to fit the new matter table.
            %
            %TODO
            %   - first set this.oMT to [], then removePhase - and
            %     removePhase/addPhase both check if phase oMT empty?
            %   - also update exme procs MT!!
            
            if ~isempty(this.oMT)
                oOldMT = this.oMT.removePhase(this);
            else
                oOldMT = [];
            end
            
            this.oMT = this.oStore.oMT;
            
            % addPhase returns the old afMass mappend to the new MT
            this.afMass = this.oMT.addPhase(this, oOldMT);
        end
        
        
        
        
        
        
        
        
        
        function setAttribute(this, sAttribute, xValue)
            % Internal method that needs to be copied to every child.
            % Required to enable the phase class to adapt values on the
            % child through processors.
            %
            %TODO see manipulators (not done with procs any more) - new way
            %     of handling that. Remove?
            
            this.(sAttribute) = xValue;
        end
        
        function [ bSuccess txValues ] = setParameter(this, sParamName, xNewValue)
            % Helper for executing internal processors.
            %
            %TODO OLD - change to 'manipulators' etc ... some other
            %           functionality to map manips to phases?
            %
            % setParameter parameters:
            %   sParamName  - attr/param to set
            %   xNewValue   - value to set param to
            %   setValue    - function handle to set the struct returned by
            %                 the processor (params key, value).
            
            bSuccess = false;
            txValues = [];
            
            %TODO work with events, or direct callbacks, or ...? 'static
            %     events' that happen generally on e.g.
            %     matter.phase.setVolume?
            this.setAttribute(sParamName, xNewValue);
            this.update(0);
            
            return;
            
            % Check if processor was registered for that parameter
            if isfield(this.ttoProcs.internal, sParamName)
                % Found a processor - true
                bSuccess = true;
                
                % Struct returned by callback is written onto the object,
                % i.e. arbitrary attributes can be changed by processor!
                %TODO use (int procs, also ex/me procs) a events system?
                %     So several procs can register? Same mode, they can
                %     return a struct with the class props to modify ...
                txValues = this.ttoProcs.internal.(sParamName)(this, xNewValue, sParamName);
                
                % If returned value not empty ...
                if ~isempty(txValues)
                    % ... get the keys (= attribute names) from struct ...
                    csAttrs = fieldnames(txValues);
                    
                    % ... and write the values on this object
                    for iI = 1:length(csAttrs)
                        %setValue(csAttrs{iI}, txValues.(csAttrs{iI}));
                        %this.(csAttrs{iI}) = txValues.(csAttrs{iI});
                        this.setAttribute(csAttrs{iI}, txValues.(csAttrs{iI}));
                    end
                end
            end
        end
    end
    
    
    
    methods(Sealed)
        % Seems like we need to do that for heterogeneous, if we want to
        % compare the objects in the mixin array with one object ...
        function varargout = eq(varargin)
            varargout{:} = eq@base(varargin{:});
        end
    end
    
    %% Abstract methods
    methods (Abstract = true)
        %calcMolMasses(this)
        %calcHeatCapacity(this)
    end
    
    
    
    %% Getters and Setters for on the fly calculations
    methods
%         function fPressure = get.fPressure(this)
%             fPressure = 3;
%         end

          
    end
end

