classdef store < base
    %STORE Summary of this class goes here
    %   Detailed explanation goes here
    %
    %TODO
    %   - see comments at fVolume; also: creating new phases, what volume
    %     to set? should basically immediately derive from store, never
    %     directly be provided, right?
    %   - something like total pressure, if gas phases share a volume?
    
    properties (SetAccess = private, GetAccess = public)
        % Phases - mixin arrays, with the base class being matter.phase who
        % is abstract - therefore can't create empty - see matter.table ...
        aoPhases = [];
        
        % Amount of phases
        iPhases;
        
        % Processors - p2p (int/exme added to phase, f2f to container)
        toProcsP2P = struct(); %matter.procs.p2p.empty();
        csProcsP2P;
        
        % Matter table
        oMT;
        
        % Name of store
        sName;
        
        % If the initial configuration of the store and all its phases,
        % processors, stuff bluff blah is done - seal it, so no more phases
        % can be added to the store, no more port/exmes can be added to the
        % phases, no more MFs to the exme's (some interfaces flows that are
        % specificly defined can still be reconnected later, nothing else,
        % and they can only be connected to an interface branch of the
        % superior system)
        bSealed = false;
        
        
        
        % Timer object, needs to inherit from / implement event.timer
        oTimer;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Volume. Can be set through setVolume, subtracts volumes of fluid
        % and solid phases and distributes the rest equally throughout the
        % gas phases.
        %
        %TODO could be dependent on e.g. some geom.cube etc. If volume of a
        %     phase changes, might be some 'solved' process due to
        %     available vol energy for vol change - properties of phase
        %     (gas isochoric etc, solids, ...). Does not necessarily change
        %     store volume, but if store volume is reduced, the phase vol
        %     change things have to be taken into account.
        fVolume = 0;
    end
    
    
    methods
        function this = store(oMT, sName, fVolume)
            this.sName = sName;
            
            this.setMatterTable(oMT);
            
            if nargin >= 3, this.fVolume = fVolume; end;
        end
        
        function update(this, fTimeStep)
            % Update phases, then recalculate internal values as volume
            % available for phases.
            %
            %TODO don't update everything all the time? If one phase
            %     changes, do not necessarily to update all other phases as
            %     well? If liquid, need to update gas, but other way
            %     around?
            %     First update solids, then liquids, then gas?
            %     Smarter ways for volume distribution?
            
            for iI = 1:this.iPhases, this.aoPhases(iI).update(fTimeStep); end;
        end
    end
    
    
    %% Methods for the outer interface - manage ports, volume, ...
    methods
        function oProc = getPort(this, sPort)
            % Check all phases to find port
            %
            % If two phases have the same port (except 'default'), for now
            % trigger error, later implement functionality to handle that?
            % -> e.g. water tank - port could deliver water or air depen-
            %    ding on fill level - flow needs to cover two phases.
            %    Something like linked flows, diameter in MFs distriuted
            %    accordingly: D[iam] - D(solids, fluids) = D_available(gas)
            %
            %NOTE on adding phases and their ports, it has to be made sure
            %     that no port of any phase has the same name then one of
            %     the phases themselves.
            %
            %TODO 
            %   - throw an error if the port was found on several phases?
            %   - create index in seal() of phases and their ports!
            
            if strcmp(sPort, 'default')
                this.throw('getPort', 'To get the default port of a phase, the phases name has to be used!');
            end
            
            % Find out if default port of a phase should be used
            %TODO check for empty aoPhases ...
            iIdx = find(strcmp({ this.aoPhases.sName }, sPort), 1);
            
            if ~isempty(iIdx)
                sPort  = 'default';
            else
                %TODO make waaaay better!!
                for iI = 1:length(this.aoPhases)
                    if isfield(this.aoPhases(iI).toProcsEXME, sPort)
                        iIdx = iI;
                        
                        break;
                    end
                end
            end
            
            if isempty(iIdx) || ~isfield(this.aoPhases(iIdx).toProcsEXME, sPort)
                this.throw('getPort', 'Port %s could not be found', sPort);
            end
            
            oProc = this.aoPhases(iIdx).toProcsEXME.(sPort);
        end
        
        function this = addPhase(this, oPhase)
            % Adds a phase to a store. If phase already has a store set,
            % throws an error.
            
            
            if this.bSealed
                this.throw('addPhase', 'The store is sealed, so no phases can be added any more.');
            end
            
            if ~isempty(this.aoPhases) && any(strcmp({ this.aoPhases.sName }, oPhase.sName))
                this.throw('addPhase', 'Phase with such a name already exists!');
                
            elseif ~isempty(oPhase.oStore)
                this.throw('addPhase', 'Can only add phases that do not have a parent oStore set (i.e. just while constructing)!');
            
            else
                if isempty(this.aoPhases), this.aoPhases          = oPhase;
                else                       this.aoPhases(end + 1) = oPhase;
                end
            end
        end
        
        
        function oPhase = createPhase(this, sHelper, varargin)
            % Creates an instance of a matter phase with the use of a
            % helper method.
            
            if this.bSealed
                this.throw('createPhase', 'The store is sealed, so no phases can be added any more.');
            end
            
            %CHECK provide fVolume to helper automatically if varargin
            %      empty - should be required most of the time right?
            if isempty(varargin), varargin = { this.fVolume }; end;

            % Get params and default 
            [ cParams, sDefaultPhase ] = this.createPhaseParams(sHelper, varargin{:});
            
            % Function handle from phase class path and create object
            hClassConstr = str2func(sDefaultPhase);
            oPhase       = hClassConstr(cParams{:});
        end
        
        
        
        
        function seal(this, oTimer)
            % See doc for bSealed attr.
            %
            %TODO create indices of phases, their ports etc! Trigger event?
            %     -> external solver can build stuff ... whatever, matrix,
            %        function handle cells, indices ...
            %     also create indices for amount of phases, in phases for
            %     amount of ports etc
            
            if this.bSealed, return; end;
            
            
            if ~isa(oTimer, 'event.timer')
                this.throw('Timer needs to inherit from event.timer');
            end
            
            % Timer - oTimer.fTime is current time, e.g. used by phases to
            % determine how much mass has to be merged/extracted depending
            % on flow rate and elapsed time.
            this.oTimer = oTimer;
                        
            for iI = 1:length(this.aoPhases), this.aoPhases(iI).seal(); end;
            
            this.iPhases = length(this.aoPhases);
            this.bSealed = true;
            
            this.csProcsP2P = fieldnames(this.toProcsP2P);
            
            % Update volume on phases
            this.setVolume();
        end
        
        
        
        
        
        function addP2P(this, oProcP2P)
            % Get sName from oProcP2P, add to toProcsP2P
            %
            
            if this.bSealed
                this.throw('addP2P', 'Store already sealed!');
            elseif isfield(this.toProcsP2P, oProcP2P.sName)
                this.throw('addP2P', 'P2P proc already exists!');
            elseif this ~= oProcP2P.oStore
                this.throw('addP2P', 'P2P proc does not have this store set as parent store!');
            end
            
            this.toProcsP2P.(oProcP2P.sName) = oProcP2P;
        end
        
        function createP2P(this, varargin)
            % Helper to create a p2p proc - maybe use a helper method in
            % matter.helpers.procs.p2p.create.*? Provide oMT etc.
            %
            %TODO implement
        end
    end
    
    
    
    %% Internal methods for handling of table, phases, f2f procs %%%%%%%%%%
    methods (Access = protected)
        function setVolume(this, fVolume)
            % Change the volume.
            %
            %TODO Event?
            % Trigger 'set.fVolume' -> return values of callbacks say
            % something about the distribution throughout the phases?
            % Then trigger 'change.fVolume'?
            % Don't change if no callback registered for set.fVol or do
            % some default stuff then?
            %tRes = this.trigger('set.fVolume', fVolume);
            % Somehow process tRes ... how? Multiple callbacks possible?
            % Which wins?? Just distribution of volumes for gas/plasma, or
            % also stuff to change e.g. solid volumes (waste compactor)?
            %
            % Also: several gases in one phase - pressures need to be added
            % to get the total pressure.
            
            %TODO in .seal(), store the references to solid/liquid/gas/...?
            
            % Mabye just for update
            if nargin >= 2, this.fVolume = fVolume; end;
            
            % Update ...
            csVolPhases  = { 'solid', 'liquid' };
            iPhasesSet   = 0;
            fVolume      = this.fVolume;
            
            % Go through phases, subtract volume of solid/fluid phases and
            % count the gas/plasma phases
            for iI = 1:this.iPhases
                if any(strcmp(csVolPhases, this.aoPhases(iI).sType))
                    fVolume = fVolume - this.aoPhases(iI).fVolume;
                    
                else iPhasesSet = iPhasesSet + 1;
                end
            end
            
            % Set remaining volume for each phase - see above, need to
            % calculate an absolute pressure from all gas/plasma phases?
            for iI = 1:this.iPhases
                if ~any(strcmp(csVolPhases, this.aoPhases(iI).sType))
                    this.aoPhases(iI).setVolume(fVolume);
                end
            end
        end
        
        
        function setMatterTable(this, oMT)
            % Set matter table for store, also updates phases (and p2p?)
            %
            %TODO update p2p procs MT?
            
            if ~isa(oMT, 'matter.table'), this.throw('setMatterTable', 'Provided object ~isa matter.table'); end;
            
            this.oMT = oMT;
            
            % Call setMatterTable on the phases
            if ~isempty(this.aoPhases), this.aoPhases.updateMatterTable(); end;
            
            % Procs P2P
            csProcs = fieldnames(this.toProcsP2P);
            
            for iI = 1:length(csProcs)
                this.toProcsP2P.(csProcs{iI}).updateMatterTable();
            end
        end
        
        function [ cParams, sDefaultPhase ] = createPhaseParams(this, sHelper, varargin)
            % Returns a (row) cell with at least the first two parameters 
            % for the constructor of a phase class. First field is a refe-
            % rence  to this matter table, second the composition of the 
            % mass (struct with field names being the matter types). Depen-
            % ding on the helper, additional fields might be returned.
            %
            % create Parameters:
            %   sHelper     - Name of the helper in matter.helper.create.*
            %   varargin    - Possibly optional, paramters for the helper
            %
            % create Returns:
            %   cParams     - parameters for the phase constructor
            %   sPhaseName  - path (with package) to the according class,
            %                 only returned if requested
            
            % Check if the calling code (this.create() or external)
            % requests two outputs - also need to provide the name of the
            % phase class
            if nargout > 1
                % Helper needs to support two function outputs!
                if nargout(str2func([ 'matter.helper.phase.create.' sHelper ])) < 2
                    this.throw('createPhaseparams', 'Helper %s does not support to return a default phase class path.', sHelper);
                end
                
                [ cParams, sDefaultPhase ] = matter.helper.phase.create.(sHelper)(this, varargin{:});
            else
                cParams       = matter.helper.phase.create.(sHelper)(this, varargin{:});
                sDefaultPhase = '';
            end
            
            % The name of the phase will be automatically the helper name!
            % If that should be prevented, createPhaseParams has to be used
            % directly and phase constructor manually called.
            cParams = [ { this sHelper } cParams ];
            %cParams = { this sHelper cParams{:} };
        end
        
        
        
        
    end
    
end

