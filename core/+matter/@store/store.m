classdef store < base
    %STORE A store contains one or multiple phases that contain mass
    % The volume of all phases together is restricted by the store, however
    % the store does not handle calculations regarding how much volume each
    % phase should occupy. If that functionality the
    % addStandardVolumeManipulators() function of the store should be used
    % to add the required volume manipulators. Alternative the user can
    % define volume manipulators, see example.mixture_flow for an example
    % of that implementation.
    % In general having multiple gas phases within one store is not valid,
    % the only exception is a discretization using gas flow phases
    
    
    properties (SetAccess = private, GetAccess = public)
        %% Basic properties
        % This is an object array containing reference to all Phases in the
        % store - mixin arrays, with the base class being matter.phase who
        % is abstract - therefore can't create empty - see matter.table ...
        aoPhases = [];
        
        % struct which has the phase names as fields and the corresponding
        % phase objects as values of these fields
        toPhases = struct();
        
        % Total number of phases. Note that this parameter is set while
        % sealing the phase, if it is used before that the value will be
        % empty!
        iPhases;
        
        % Processors - p2p (int/exme added to phase, f2f to container)
        toProcsP2P = struct();
        
        % cell array containing the names of all P2Ps inside the store
        csProcsP2P = {};
        
        % array containing the indices of all stationary P2Ps in the store.
        % The indices refer to the csProcsP2P cell array
        aiProcsP2Pstationary;
        
        % Name of store
        sName;
        
        % If the initial configuration of the store and all its phases,
        % processors is done - seal it, so no more phases can be added to
        % the store, no more port/exmes can be added to the phases, no more
        % MFs to the exme's (some interfaces flows that are specificly
        % defined can still be reconnected later, nothing else, and they
        % can only be connected to an interface branch of the superior
        % system)
        bSealed = false;
        
        % Matter table
        oMT;
        
        % Reference to the vsys (matter.container) in which this store is 
        % contained
        oContainer;
        
        % Timer object, needs to inherit from / implement event.timer
        oTimer;
        
        % A cell containing the names of all ExMe processors in this store.
        % This is used to ensure that all ExMe names are unique.
        csExMeNames = '';
        
        %% Geometry Properties
        % This is only important for gravity or likewise driven systems 
        % where the position of ports and geometry of the store is no longer
        % insignifcant.
        % Geometry struct of the store with the possible inputs: (atm only
        % Box shape)
        % tGeometryParameters = struct('Shape', 'Box', 'Area', 0.5)
        %   "Box"       : Could be a rectangular shaped store or a zylinder
        %                 with its axis congruent to the acceleration
        tGeometryParameters = struct('Shape','Box', 'Area', 1);
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Volume. Can be set through setVolume, subtracts volumes of fluid
        % and solid phases and distributes the rest equally throughout the
        % gas phases.
        fVolume = 0;
    end
    
    methods
        function this = store(oContainer, sName, fVolume, tGeometryParams)
            %% Store Class Constructor
            % Create a new matter store object to which phases can then be
            % added. The required input parameters are:
            % oContainer:   A reference to the parent system of the store.
            % sName:        The name of the store (choose something easily
            %               recognizable for your system, not Store1)
            % fVolume:      Overall volume of the store
            %
            % And the optional input parameters are:
            % tGeometryParams:  As an optional input parameter a struct
            %                   describing the geometry of the store can be
            %                   passed in. This can then be used together
            %                   with e.g. liquid exmes to model gravity
            %                   driven flows in non 0-g environments
            
            this.sName      = sName;
            this.oContainer = oContainer;
            
            % Add this store object to the matter.container
            this.oContainer.addStore(this);
            
            this.oMT    = this.oContainer.oRoot.oMT;
            this.oTimer = this.oContainer.oRoot.oTimer;
            
            % A store with no volume does not make sense, so we catch this
            % if the user entered an illegal value by accident here. 
            if fVolume <= 0
                this.throw('store','The store %s cannot have a volume of zero or less. Only positive, non-zero values are allowed.', sName);
            else
                this.fVolume = fVolume;
            end

            if nargin >= 4
                this.tGeometryParameters = tGeometryParams;
            end
        end
    end
    
    %% Methods for the outer interface - manage ports, volume, ...
    methods
        function oExMe = getExMe(this, sExMe)
            %% getExMe
            % Since branches are defined with store and port name, a
            % function is required to loop through all phases and find the
            % corresponding ExMe for the definition. However, this function
            % can also be used to find the ExMe at a store in any other
            % case
            
            iIdx = [];
            % loop through phases and compare the toProcsEXME struct which
            % contains the name of all exmes for that phase as fieldname
            for iI = 1:length(this.aoPhases)
                if isfield(this.aoPhases(iI).toProcsEXME, sExMe)
                    iIdx = iI;
                    % Once we have found the ExMe we can stop looping
                    break;
                end
            end
            
            if isempty(iIdx) || ~isfield(this.aoPhases(iIdx).toProcsEXME, sExMe)
                this.throw('getExMe', 'ExMe %s could not be found', sExMe);
            end
            
            oExMe = this.aoPhases(iIdx).toProcsEXME.(sExMe);
        end
        
        function addExMeName(this, sName)
            %% addExMeName
            % In order to ensure that the ExMe names in this store are
            % unique, we save their names to the csExMeNames property.
            this.csExMeNames{end+1} = sName;
        end
        
        function oProc = getThermalExMe(this, sExMe)
            %% getThermalExMe
            % Since branches are defined with store and port name, a
            % function is required to loop through all phases and find the
            % corresponding ExMe for the definition. However, this function
            % can also be used to find the ExMe at a store in any other
            % case
            
            % loop through capacities and compare the toProcsEXME struct
            % which contains the name of all exmes for that phase as
            % fieldname
            iIdx = [];
            for iI = 1:length(this.aoPhases)
                if isfield(this.aoPhases(iI).oCapacity.toProcsEXME, sExMe)
                    iIdx = iI;
                    % Once we have found the ExMe we can stop looping
                    break;
                end
            end
            
            if isempty(iIdx) || ~isfield(this.aoPhases(iIdx).oCapacity.toProcsEXME, sExMe)
                this.throw('getExMe', 'ExMe %s could not be found', sExMe);
            end
            
            oProc = this.aoPhases(iIdx).oCapacity.toProcsEXME.(sExMe);
        end
        
        function this = addPhase(this, oPhase)
            %% addPhase
            % INTERNAL FUNCTION! Is called directly in the constructor of
            % matter.phase and therefore the user does NOT have to call
            % this individually. If phase already has a store set, throws
            % an error.
            %
            % Adds a phase to this store
            
            % Check for possible errors and throw appropriate error
            % messages
            if this.bSealed
                this.throw('addPhase', 'The store is sealed, so no phases can be added any more.');
                
            elseif ~isempty(this.aoPhases) && any(strcmp({ this.aoPhases.sName }, oPhase.sName))
                this.throw('addPhase', 'Phase with such a name already exists!');
                
            elseif ~isempty(oPhase.oStore) && (oPhase.oStore ~= this)
                this.throw('addPhase', 'Can only add phases that do not have a parent oStore set (i.e. just while constructing)!');
            
            else
                % If no errors were catched we add the phase to the
                % aoPhases and toPhases properties of this store
                if isempty(this.aoPhases) 
                    this.aoPhases = oPhase;
                else
                    this.aoPhases(end + 1) = oPhase;
                end
                
                this.toPhases.(oPhase.sName) = oPhase;
            end
        end
        
        function oPhase = createPhase(this, sHelper, varargin)
            %% createPhase
            % Creates an instance of a matter phase with the use of a
            % helper method. Possible Inputs for this function depend on
            % the helper function, but the basic inputs are always:
            %
            % sHelper:  reference to the helper function used to define the
            %           phase. The possible helper functions are located in
            %           matter.helper.phase.create and the input name is
            %           the name of the helper as a string
            %
            % optional inputs:
            %
            % sType:    If the helper should not create a normal phase, but
            %           a flow or boundary phase, the second input argument
            %           must be 'flow' or 'boundary'. Otherwise the next
            %           helper dependent inputs can be used directly after
            %           the sHelper input!
            %
            % sName:    Name of the phase that should be created. if this
            %           is not provided the phase is created with an
            %           automatic generated name from the store name and
            %           the current number of phases in the store (e.g.
            %           Tank_1_Phase_2). if it is not provided proceed
            %           directly with the helper dependent inputs
            %
            % The helper dependent inputs can be viewed at the specific
            % helper and are always the required input of that helper
            % without the first oStore input. For example the gas helper
            % function has the inputs:
            %
            % fVolume, tfPartialPressure, fTemperature, rRelativeHumidity
            %
            % in this order. Therefore if you want to define a gas phase
            % using the gas helper with this function you have to use the
            % call:
            % createPhase(  'gas',   'sName',   fVolume , tfPartialPressure,	fTemperature,	rRelativeHumidity)
            %
            % If you want to define a flow gas phase instead you can use:
            %
            % createPhase(  'gas', 'flow',  'sName',   fVolume , tfPartialPressure,	fTemperature,	rRelativeHumidity)
            %
            % Or for a boundary gas phase:
            %
            % createPhase(  'gas', 'boundary',  'sName',   fVolume , tfPartialPressure,	fTemperature,	rRelativeHumidity)
            %
            % If for example you would like to use the water helper to
            % create a water phase with the correct mass for the defined
            % volume you would use the call:
            %
            % createPhase(  'water',   'sName',   fVolume , fTemperature,	fPressure)
            %
            % Instead adding flow or boundary phases requires the same
            % adaption as for the gas phase above!
            %
            % Also see
            % https://wiki.tum.de/display/vhab/1.4.2+Stores+and+Phases
            % for information on how to create phases in V-HAB and examples
            % on how to do this with specific values etc!
            
            if this.bSealed
                this.throw('createPhase', 'The store is sealed, so no phases can be added any more.');
            end
            
            % Check the input arguments for optional inputs to decide if
            % flow or boundary phases should be defined
            if isempty(varargin)
                cInputs = { this.fVolume };
                bFlowNode = false;
                bBoundaryNode = false;
            elseif strcmp(varargin{1}, 'flow')
                bFlowNode = true;
                bBoundaryNode = false;
                cInputs = varargin(2:end);
            elseif strcmp(varargin{1}, 'boundary')
                bFlowNode = false;
                bBoundaryNode = true;
                cInputs = varargin(2:end);
            else
                cInputs = varargin;
                bFlowNode = false;
                bBoundaryNode = false;
            end

            % Get params and default 
            [ cParams, sDefaultPhase ] = this.createPhaseParams(sHelper, cInputs{:});
            
            % Function handle from phase class path and create object
            if bFlowNode
                sDefaultPhase = strrep(sDefaultPhase, 'phases.' , 'phases.flow.');
            elseif bBoundaryNode
                sDefaultPhase = strrep(sDefaultPhase, 'phases.' , 'phases.boundary.');
                if length(cInputs) == 3
                    cParams{end+1} = cInputs{3};
                end
            end
            hClassConstr = str2func(sDefaultPhase);
            oPhase       = hClassConstr(cParams{:});
        end
        
        function seal(this)
            %% seal
            % INTERNAL METHOD! This is called by the sealMatterStructure
            % function of the container
            % Seales the store and prevents further changes to it regarding
            % exmes etc. Only IF exmes are allowed to change after this, to
            % allow e.g. a human to move through a habitat.
            
            if this.bSealed, return; end
            
            % Count phases and create other processor/phase specific
            % parameters which help to access the objects connected to this
            % store
            this.iPhases    = length(this.aoPhases);
            this.csProcsP2P = fieldnames(this.toProcsP2P);
            
            % Find stationary p2ps
            for iI = 1:length(this.csProcsP2P)
                if isa(this.toProcsP2P.(this.csProcsP2P{iI}), 'matter.procs.p2ps.stationary')
                    this.aiProcsP2Pstationary(end + 1) = iI;
                end
            end
            
            % Check if volume of the store is equal or smaller than total
            % phase volume
            fPhaseVolume = 0;
            for iI = 1:this.iPhases
                if ~this.aoPhases(iI).bBoundary
                    fPhaseVolume = fPhaseVolume + this.aoPhases(iI).fVolume;
                end
            end
            if tools.round.prec(this.fVolume - fPhaseVolume, this.oTimer.iPrecision) < 0
                this.throw('sealStore', ['The values you have entered for the phase volumes of the store ', this.sName ' are larger than the store itself by ', num2str(fPhaseVolume - this.fVolume), ' m^3. Either increase the store volume or turn on the store calculations to automatically set the volumes!']);
            end
            
            % Seal phases
            for iI = 1:length(this.aoPhases)
                this.aoPhases(iI).seal(); 
            end
            this.bSealed = true;
        end
        
        function addP2P(this, oProcP2P)
            %% addP2P
            % INTERNAL FUNCTION! is called by the constructor of
            % matter.procs.p2p to add the P2P to the store
            
            % Get sName from oProcP2P, add to toProcsP2P
            if this.bSealed
                this.throw('addP2P', 'Error while adding P2P %s, the store %s is already sealed!', oProcP2P.sName, oProcP2P.oStore.sName);
            elseif isfield(this.toProcsP2P, oProcP2P.sName)
                this.throw('addP2P', 'Error while adding P2P %s in store %s, the P2P proc already exists!', oProcP2P.sName, oProcP2P.oStore.sName);
            elseif this ~= oProcP2P.oStore
                this.throw('addP2P', 'Error while adding P2P %s, P2P proc does not have the store %s set as parent store but instead has the store %s as parent!', oProcP2P.sName, this.sName, oProcP2P.oStore.sName);
            end
            
            this.toProcsP2P.(oProcP2P.sName) = oProcP2P;
        end
        
        function addStandardVolumeManipulators(this)
            %% addStandardVolumeManipulators
            %
            % This function can be used to automatically add compressible
            % volume manipulators to phases considered compressible (gas)
            % and incompressible volume manipulators to other phases.
            for iPhase = 1:length(this.aoPhases)
                if strcmp(this.aoPhases(iPhase).sType, 'gas') || (strcmp(this.aoPhases(iPhase).sType, 'mixture') && strcmp(this.aoPhases(iPhase).sPhaseType, 'gas'))
                    oCompressibleManip = matter.manips.volume.StoreVolumeCalculation.compressibleMedium([this.aoPhases(iPhase).sName, '_CompressibleManip'], this.aoPhases(iPhase));
                end
            end
            
            for iPhase = 1:length(this.aoPhases)
                if ~(strcmp(this.aoPhases(iPhase).sType, 'gas') || (strcmp(this.aoPhases(iPhase).sType, 'mixture') && strcmp(this.aoPhases(iPhase).sPhaseType, 'gas')))
                    matter.manips.volume.StoreVolumeCalculation.incompressibleMedium([this.aoPhases(iPhase).sName, '_IncompressibleManip'], this.aoPhases(iPhase), oCompressibleManip);
                end
            end
        end
        
        function setVolume(this, fVolume)
            %% setVolume
            %
            % This function can be used to change the volume of the store.
            % In order to work correctly the phases within the store
            % require matter.manips.volume.StoreVolumeCalculation.compressibleMedium
            % or incompressibleMedium volume manipulators to recalculate
            % the phase volumes accordingly if this function is used!
            
            if nargin >= 2, this.fVolume = fVolume; end
            
            for iPhase = this.iPhases
                if ~isempty(this.aoPhases(iPhase).toManips.volume) && isprop(this.aoPhases(iPhase).toManips.volume ,'bCompressible')
                    this.aoPhases(iPhase).toManips.volume.registerUpdate();
                    % we also register a phase update to directly update
                    % the volume of the phase
                    this.aoPhases(iPhase).registerUpdate();
                else
                    error('The volume for store %s was changed using the setVolume function but the phases within the store do not have the necessary volume manipulators to handle that change. Use the store function addStandardVolumeManipulators to add the manips or add them by hand!', this.sName)
                end
            end
        end
    end
    
    %% Internal methods for handling of phases, f2f procs %%%%%%%%%%
    methods (Access = protected)
        function [ cParams, sDefaultPhase ] = createPhaseParams(this, sHelper, varargin)
            %% createPhaseParams
            % INTERNAL FUNCTION!, called by the createPhase function of the
            % store which should be used to create Phases using helpers!
            %
            % Returns a (row) cell with at least the first two parameters 
            % for the constructor of a phase class. First field is a refe-
            % rence  to this matter table, second the composition of the 
            % mass (struct with field names being the matter types). Depen-
            % ding on the helper, additional fields might be returned.
            %
            % Input Parameters:
            %   sHelper     - Name of the helper in matter.helper.create.*
            %   varargin    - Possibly optional, paramters for the helper
            %
            % Output Parameters:
            %   cParams     - parameters for the phase constructor as a row
            %                 of cells
            %   sPhaseName  - path (with package) to the according class,
            %                 only returned if requested
            
            % If the first item of varargin is a string, then it is a
            % user-provided name for the phase to be created. If it is
            % anything else, it is one of the parameters.
            if ~isempty(varargin) && ischar(varargin{1})
                sPhaseName   = varargin{1};
                cPhaseParams = varargin(2:end);
            else
                sPhaseName = [this.sName, '_Phase_', num2str(length(this.aoPhases)+1)];
                cPhaseParams = varargin; 
            end
            
            % Check if the calling code (this.create() or external)
            % requests two outputs - also need to provide the name of the
            % phase class
            if nargout > 1
                % Helper needs to support two function outputs!
                if nargout(str2func([ 'matter.helper.phase.create.' sHelper ])) < 2
                    this.throw('createPhaseparams', 'Helper %s does not support to return a default phase class path.', sHelper);
                end
                [ cParams, sDefaultPhase ] = matter.helper.phase.create.(sHelper)(this, cPhaseParams{:});
            else
                cParams       = matter.helper.phase.create.(sHelper)(this, cPhaseParams{:});
                sDefaultPhase = '';
            end
            
            % The name of the phase will be automatically the helper name!
            % If that should be prevented, createPhaseParams has to be used
            % directly and phase constructor manually called.
            cParams = [ { this sPhaseName } cParams ];
        end
    end
end