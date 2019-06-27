classdef container < sys
    %CONTAINER A system that contains matter objects
    %   Container is the base class of the matter domain in V-HAB. It
    %   contains stores and branches and provides methods for adding and
    %   removing stores, branches and associated processors. It also
    %   provides functions that enable branches to be passed between system
    %   and subsystem levels. 
    %   For more information on the individual functions, please see their
    %   descriptions. 
    
    properties (SetAccess = private, GetAccess = public)
        % Stores stored as struct.
        toStores = struct();
        
        % An array of all branch objects
        aoBranches = matter.branch.empty();
        
        % A struct with all processors in the container 
        % These are also stored in the branch they belong to, but might be
        % helpfull to access them here through their name to e.g. execute
        % some methods (close valve, switch off fan, ...)
        toProcsF2F = struct();
        
        % Name strings of all stores
        csStores;
        
        % Name strings of all f2f processors
        csProcsF2F;
        
        % Reference to the branches, by name as a struct
        toBranches = struct();
        
        % Number of branches in this container
        iBranches = 0;
        
        % Number of phases in this container
        iPhases = 0;
        
        % Indicator if this container is sealed or not
        bMatterSealed = false;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Matter table object reference
        oMT;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Solver parameters, see simulation.container for a detailed
        % description
        tSolverParams;
    end
    
    
    methods
        function this = container(oParent, sName)
            %% matter container class constructor
            %
            % Creates a new matter container class, the matter container
            % represents a system consisting of multiple store, branches
            % etc. within V-HAB.
            %
            % Required Inputs:
            % oParent:  The parent system reference, can either be another
            %           vsys or a simulation.container class
            % sName:    The name for this system
            this@sys(oParent, sName);
            
            % Copy solver params so they can be adapted locally!
            this.tSolverParams = this.oParent.tSolverParams;
            
            
            if ~isa(this.oRoot.oMT, 'matter.table'), this.throw('container', 'Provided object ~isa matter.table'); end
            
            this.oMT    = this.oRoot.oMT;
        end
    end
    
    
    %% Public methods
    methods (Access = public)
        
        function sealMatterStructure(this)
            %% sealMatterStructure
            % Seals all stores and branches in this container and calls
            % this method on any subsystems
            if this.bMatterSealed
                this.throw('sealMatterStructure', 'Already sealed');
            end
            
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                
                this.toChildren.(sChild).sealMatterStructure();
                
                this.iPhases = this.iPhases + this.toChildren.(sChild).iPhases;
                this.iBranches = this.iBranches + length(this.toChildren.(sChild).toBranches);
            end
            
            this.csStores = fieldnames(this.toStores);
            this.csProcsF2F = fieldnames(this.toProcsF2F);
            
            for iI = 1:length(this.csStores)
                % Stores need a timer object, to be accessed by the phases
                % to e.g. register updates, find out elapsed time
                this.toStores.(this.csStores{iI}).seal();
                
                this.iPhases = this.iPhases + this.toStores.(this.csStores{iI}).iPhases;
            end
            
            % Now we seal off all of the branches. Some of them may be
            % interface branches to subsystems. These leftover stubs of
            % branches are no longer needed and can be deleted. These stubs
            % will have an abIf property that looks like this: [1; 0]
            % meaning their left side is an interface while their right
            % side is connected to an exme processor. If the branch is a
            % subsystem interface branch to a supersystem, abIf = [0; 1].
            % If the branch is a pass-through branch from a subsystem to a
            % supersystem via an intermediate system, abIf = [1; 1]. So we
            % only want to delete if abIf = [1; 0].
            
            % Of course, we only have to do this, if there are any branches
            % in the container at all. In some cases, there can be 
            % subsystems with no branches. The heat exchanger component is 
            % an example. It only provides two processors. So we check for 
            % existing branches first. 
            if ~isempty(this.aoBranches)
                % Now we can get the 2xN matrix for all the branches in the
                % container.
                mbIf = subsref([this.aoBranches.abIf], struct('type','()','subs',{{ 1:2, ':' }}));
                % Using the element-wise AND operator '&' we delete only the
                % branches with abIf = [1; 0].
                % First we create a helper array.
                aoBranchStubs = this.aoBranches(mbIf(1,:) & ~mbIf(2,:));
                % Now we delete the branches from the aoBranches property.
                this.aoBranches(mbIf(1,:) & ~mbIf(2,:)) = [];
                % Now, using the helper array, we delete the fields from
                % the toBranches struct.
                for iI = 1:length(aoBranchStubs)
                    if ~isempty(aoBranchStubs(iI).sCustomName)
                        this.toBranches = rmfield(this.toBranches, aoBranchStubs(iI).sCustomName);
                    else
                        this.toBranches = rmfield(this.toBranches, aoBranchStubs(iI).sName);
                    end
                end
                
                for iI = 1:length(this.aoBranches)
                    % So now the stubs are deleted and the pass-through are
                    % already sealed, so we only have to seal the
                    % non-interface branches.
                    if sum(this.aoBranches(iI).abIf) <= 1
                        this.aoBranches(iI).seal();
                    end
                end
                
                % Now that we've taken care of all the branches in this
                % container, we also no longer need the pass-through branches
                % on the subsystems beneath us. So we go through all of them
                % and call a removal method.
                if this.iChildren > 0
                    for iI = 1:this.iChildren
                        this.toChildren.(this.csChildren{iI}).removePassThroughBranches();
                    end
                end
            end
            
            this.iBranches = this.iBranches + length(this.aoBranches);
            
            this.bMatterSealed = true;
        end
        
        function createMatterStructure(this)
            %% createMatterStructure
            % within derived classes (actual systems, e.g. CDRA) the
            % definition of all matter domain components takes place in the
            % createMaterStructure function. However, this function must
            % still be called to execute the createMatterStructure
            % functions of all child systems
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                
                this.toChildren.(sChild).createMatterStructure();
            end
        end
        
        function addStore(this, oStore)
            %% addStore
            % INTERNAL FUNCTION! Called by the store class constructor!
            %
            % Adds the provided store object reference to the systems
            % toStores property
            % Required Inputs:
            % oStore:   Object reference to the store that should be added
            
            if this.bSealed
                this.throw('addStore', 'The container is sealed, so no stores can be added any more.');
            end
            
            if ~isa(oStore, 'matter.store')
                this.throw('addStore', 'Provided object ~isa matter.store!');
            
            elseif isfield(this.toStores, oStore.sName)
                this.throw('addStore', 'Store with name %s already exists!', oStore.sName);
            
            elseif oStore.oMT ~= this.oMT
                this.throw('addStore', 'Matter tables don''t match ... should probably not happen? See doc of this method, create stores through container?');
            end
            
            % Stores do not contain a reference to the container, so no
            % method needs to be called there.
            this.toStores.(oStore.sName) = oStore;
            
        end
        
        function this = addProcF2F(this, oProcF2F)
            %% addProcF2F
            % INTERNAL FUNCTION! Called by the f2f class constructor!
            %
            % Adds the provided f2f object reference to the systems
            % toProcsF2F property
            % Required Inputs:
            % oProcF2F:   Object reference to the f2f that should be added
            
            if this.bSealed
                this.throw('addProcF2F', 'The container is sealed, so no f2f procs can be added any more.');
            end
            
            
            if ~isa(oProcF2F, 'matter.procs.f2f')
                this.throw('addF2F', 'Provided object ~isa matter.procs.f2f.');
                
            elseif isfield(this.toProcsF2F, oProcF2F.sName)
                this.throw('addF2F', 'Proc %s already exists.', oProcF2F.sName);
                
            elseif this ~= oProcF2F.oContainer
                this.throw('addF2F', 'F2F proc does not have this vsys set as a container!');
            
            end
            
            this.toProcsF2F.(oProcF2F.sName) = oProcF2F;
        end
        
        function this = addBranch(this, oBranch)
            %% addBranch
            % INTERNAL FUNCTION! Called by the branch class constructor!
            %
            % Adds the provided branch object reference to the systems
            % toBranches  and aoBranches property.
            %
            % Required Inputs:
            % oProcF2F:   Object reference to the f2f that should be added
            if this.bSealed
                this.throw('addBranch', 'Can''t create branches any more, sealed.');
                
            elseif ~isa(oBranch, 'matter.branch')
                this.throw('addBranch', 'Provided branch is not a and does not inherit from matter.branch');
                
            elseif isfield(this.toBranches, oBranch.sName)
                this.throw('addBranch', 'Branch with name "%s" already exists!', oBranch.sName);
                
            end
            
            this.aoBranches(end + 1, 1)     = oBranch;
            if ~isempty(oBranch.sCustomName)
                if isfield(this.toBranches, oBranch.sCustomName)
                    this.throw('addBranch', 'Branch with custom name "%s" already exists!', oBranch.sCustomName);
                else
                    this.toBranches.(oBranch.sCustomName) = oBranch;
                end
            else
                this.toBranches.(oBranch.sName) = oBranch;
            end
        end
        
        function checkMatterSolvers(this)
            %% checkMatterSolvers
            % INTERNAL FUNCTION! Called by simulation.infrastructure while
            % setting up the simulation (in the initialize function) to
            % ensure that all branches have a solver, as otherwise strange
            % errors can occur
            
            csChildren = fieldnames(this.toChildren);
            for iChild = 1:this.iChildren
                this.toChildren.(csChildren{iChild}).checkMatterSolvers();
            end
            
            for iBranch = 1:length(this.aoBranches)
                if isempty(this.aoBranches(iBranch).oHandler)
                    error('Error in System ''%s''. The branch ''%s'' has no solver.', this.sName, this.aoBranches(iBranch).sName);
                end
                
            end
        end
    end
    
    methods (Access = public, Sealed = true)
        
        function connectIF(this, sLocalInterface, sParentInterface)
            %% connectIF
            % 
            % Connect two interface branches, first (local) branch needs right side
            % interface, second (parent system) branch needs left side
            % interface. For the initial system definition this is
            % performed automatically while the system is finished.
            % However, in the future the idea is to also use this function
            % to remake connection during a simulation (e.g. human moving
            % through a system)
            %
            % Required Inputs:
            % sLocalInterface:  Name of the Interface on the Subsystem Side
            % sParentInterface: Name of the Interface on the Parent System
            %                   side
            
            % Get cell with branch end names, 2nd row is right names (the
            % csNames is two rows, one col with left/right name --> get
            % from several branches, col vectors appended to 2xN matrix)
            csLocalIfs   = [ this.aoBranches.csNames ];
            iLocalBranch = find(strcmp(csLocalIfs(2, :), sLocalInterface), 1);
            
            if isempty(iLocalBranch)
                this.throw('connectIF', 'Local interface %s not found', sLocalInterface);
            end
            
            oBranch = this.aoBranches(iLocalBranch);
            
            if ~oBranch.abIf(2)
                this.throw('connectIF', 'Branch doesn''t have an interface on the right side (connected to store).');
            end
            
            % If already connected, throws a ball (xkcd.com/1188)
            oBranch.connectTo(sParentInterface);
            
            % If this branch is connected to a store on the left side, and
            % the right phase is set (which means that the newly connected
            % branch on the suPsystem or one of the following branches is
            % connected to a store!) ...
            
            if ~oBranch.abIf(1) && ~isempty(oBranch.coExmes{2})
                % ... trigger event if anyone wants to know
                this.trigger('branch.connected', iLocalBranch);
            end
            
            % every matter interface has a respective thermal interface
            this.connectThermalIF(sLocalInterface, sParentInterface);
        end
        
        function disconnectIF(this, sLocalInterface)
            %% disconnectIF
            %
            % This function can be used to disconnect an existing
            % connection between two interface branches. Allowing it to be
            % reconnected with another IF.
            iLocalBranch = find(strcmp({ this.aoBranches.sNameLeft }, sLocalInterface), 1);
            
            if isempty(iLocalBranch)
                this.throw('connectIF', 'Local interface %s not found', sLocalInterface);
            end
            
            oBranch = this.aoBranches(iLocalBranch);
            
            if ~oBranch.abIfs(2)
                this.throw('connectIF', 'Branch doesn''t have an interface on the right side (connected to store).');
            end
            
            bTrigger = ~oBranch.abIfs(1) && ~isempty(oBranch.coExmes{2});
            
            oBranch.disconnect();
            
            % Do the trigger after the actual disconnect
            if bTrigger
                this.trigger('branch.disconnected', iLocalBranch);
            end
        end
        
        
        
        function updateBranchNames(this, oBranch, sOldName)
            %% updateBranchNames
            % INTERNAL FUNCTION! Called by base.branch connectTo function
            % to update the branch names. It removes the old branch names
            % from the toBranches struct and then readds the branches with
            % the new names
            %
            % Required Inputs:
            % oBranch:  Branch Object for which the name should be changed
            % sOldName: The old name of the branch
            
            % First we make sure, that the calling branch is actually a
            % branch in this container. 
            if any(this.aoBranches == oBranch)
                % We need to jump through some hoops because the maximum
                % field name length of MATLAB is only 63 characters, so we 
                % delete the rest of the actual branch name...
                % namelengthmax is the MATLAB variable that stores the 
                % maximum name length, so in case it changes in the future, 
                % we don't have to change this code!
                if length(sOldName) > namelengthmax
                    sOldName = sOldName(1:namelengthmax);
                end
                this.toBranches = rmfield(this.toBranches, sOldName);
                % Now we'll add the branch to the struct again, but with
                % its new name. 
                if ~isempty(oBranch.sCustomName)
                    this.toBranches.(oBranch.sCustomName) = oBranch;
                else
                    this.toBranches.(oBranch.sName) = oBranch;
                end
            else
                % In case the calling branch is not in this container, we
                % throw an error message.
                this.throw('container:updateBranchNames','The provided branch does not exist in this matter container.');
            end
        end
    end
    
    methods (Access = private)
        function removePassThroughBranches(this)
            %% removePassThroughBranches
            % INTERNAL FUNCTION! Called by sealMatterStructure function of
            % the matter container.
            % If a branch is a pass-through branch from a subsystem to a
            % supersystem via an intermediate system, then the propery abIf
            % = [1; 1]. So we just find all branches with an abIf like that
            % and delete them.
            
            % We should, however, only do this, if this method is called by
            % the supersystem. So before we do anything, we'll check if
            % this system is already sealed. If yes, we'll just return
            % without doing anything.
            
            if ~this.bSealed
                return;
            end
            
            % Of course, we only have to do this, if there are any branches
            % in the container at all. In some cases, there can be 
            % subsystems with no branches. The heat exchanger component is 
            % an example. It only provides two processors. So we check for 
            % existin branches first. 
            if ~isempty(this.aoBranches)
                % First we get the 2xN matrix for all the branches in the
                % container.
                mbIf = subsref([this.aoBranches.abIf], struct('type','()','subs',{{ 1:2, ':' }}));
                
                % Using the element-wise AND operator '&' we delete only the
                % branches with abIf = [1; 1].
                % First we create a helper array.
                aoBranchStubs = this.aoBranches(mbIf(1,:) & mbIf(2,:));
                % Now we delete the branches from the aoBranches property.
                this.aoBranches(mbIf(1,:) & mbIf(2,:)) = [];
                % Now, using the helper array, we delete the fields from
                % the toBranches struct.
                for iI = 1:length(aoBranchStubs)
                    % We need to jump through some hoops because the
                    % maximum field name length of MATLAB is only 63
                    % characters, so we delete the rest of the actual
                    % branch name... 
                    % namelengthmax is the MATLAB variable that stores the
                    % maximum name length, so in case it changes in the
                    % future, we don't have to change this code!
                    sName = aoBranchStubs(iI).sName;
                    if length(sName) > namelengthmax
                        sName = sName(1:namelengthmax);
                    end
                    this.toBranches = rmfield(this.toBranches, sName);
                    
                    % We also need to decrease the iBranches property by
                    % one.
                    this.iBranches = this.iBranches - 1;
                end
            end
        end
    end
end