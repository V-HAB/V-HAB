classdef container < sys
    %CONTAINER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public)
        % Stores stored as struct.
        %CHECK change to mixin array? Do we need that?
        %aoStores = matter.store.empty();
        % @type struct
        % @types object
        toStores = struct();
        
        % Branches stored as mixin (?) array, so e.g. all flow rates can be
        % extracted with [ this.aoBranches.fFlowRate ]
        % @type array
        % @types object
        aoBranches = matter.branch.empty();
        
        % Processors - also stored in the branch they belong to, but might
        % be helpfull to access them here through their name to e.g.
        % execute some methods (close valve, switch off fan, ...)
        toProcsF2F = struct(); %matter.procs.f2f.empty();
        
        % Cached names
        csStores;
        csProcsF2F;
        
        % Reference to the branches, by name
        toBranches = struct();
        
        iBranches = 0;
        iPhases = 0;
        
        oThermalContainer;
        
        % Sealed?
        bMatterSealed = false;
    end
    
    properties (SetAccess = private, GetAccess = public) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        oMT;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        tSolverParams;
    end
    
    
    methods
        function this = container(oParent, sName)
            this@sys(oParent, sName);
            
            % Copy solver params so they can be adapted locally!
            this.tSolverParams = this.oParent.tSolverParams;
            
            
            if ~isa(this.oRoot.oMT, 'matter.table'), this.throw('container', 'Provided object ~isa matter.table'); end;
            
            this.oMT    = this.oRoot.oMT;
        end
        
        function afMass = getTotalPartialMasses(this)
            % Example method - get masses of each species within all phases
            % from all stores referenced in this container.
            
            % Create object array of all phases. Need the [] since Matlab
            % returns the results the same way a cell with {:} does.
            % OLD - aoStores now toStores!
            %aoPhases = [ this.aoStores.aoPhases ];
            % Convert struct to cell, get all elements, and make array!
            %CHECK speed? switch back to aoStores?
            coStores = struct2cell(this.toStores);
            aoStores = [ coStores{:} ];
            aoPhases = [ aoStores.aoPhases ];
            
            % Get masses - one long row vector, since masses are stored as
            % row vector within the phase objects
            afMassesVector = [ aoPhases.afMass ];
            
            % Therefore reshape the afMass vector, with the first dimension
            % being the amount of species stored in the matter table since
            % that's the amount of elements all the afMass vectors have.
            mfMass = reshape(afMassesVector, this.oData.oMT.iSpecies, []);
            
            % Now the mfMass contains a matrix where the columns represent
            % each phase, the rows represent the species (therefore the
            % second parameter to sum)
            afMass = sum(mfMass, 2);
            
            % afMass now contains the sum for each species from all phases,
            % well should, not tested :-)
        end
    end
    
    
    %% Internal methods
    % References to the store, f2f etc are stored one-way, i.e. store
    % does not point to container.
    methods (Access = protected)
%TODO
%DELETE? Is never called...
%SCJO: yes and no. Within vsys .exec(), this method COULD be called. The
%      idea was that matter procs like F2Fs are updated here. Maybe this
%      does not make sense, and rather proc update methods have to be
%      called explicitly by the user in vsys.exec?
%
%         function exec(this, fTimeStep)
%             
%             
%             % Stores call phases call exme .update(). Phases/Exme do the
%             % actual mass moving, so if just update of internal parameters
%             % desired, call oPhase.update(0).
%             %TODO Call EXEC, not update!
%             for iI = 1:length(this.csStores), this.toStores.(this.csStores{iI}).exec(fTimeStep); end;
%             
%             %TODO .exec, not .update (see above)
%             for iI = 1:length(this.csProcsF2F), this.toProcsF2F.(this.csProcsF2F{iI}).exec(fTimeStep); end;
%         end
        
        
        
    end
    
    methods (Access = public)
        
        function sealMatterStructure(this)
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
            % existin branches first. 
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
                    % already sealed, so we only have to seal the non-interface
                    % branches and the
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
            % Call in child elems
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                
                this.toChildren.(sChild).createMatterStructure();
            end
        end
        
        function addStore(this, oStore)
            % Adds the store to toStores. Might be overloaded by derived
            % classes to e.g. implement some dynamic handling of store
            % volumes or other stuff.
            
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
            % Adds a f2f proc.
            %
            %TODO tell the flow proc about that? Or just one-way?
            
            if this.bSealed
                this.throw('addProcF2F', 'The container is sealed, so no f2f procs can be added any more.');
            end
            
            
            if ~isa(oProcF2F, 'matter.procs.f2f')
                this.throw('addF2F', 'Provided object ~isa matter.procs.f2f.');
                
            elseif isfield(this.toProcsF2F, oProcF2F.sName)
                this.throw('addF2F', 'Proc %s already exists.', oProcF2F.sName);
                
            elseif this ~= oProcF2F.oContainer
                this.throw('addP2P', 'F2F proc does not have this vsys set as a container!');
            
            end
            
            this.toProcsF2F.(oProcF2F.sName) = oProcF2F;
        end
        
        
        
        function this = addBranch(this, oBranch)
            if this.bSealed
                this.throw('addBranch', 'Can''t create branches any more, sealed.');
                
            elseif ~isa(oBranch, 'matter.branch')
                this.throw('addBranch', 'Provided branch is not a and does not inherit from matter.branch');
                
            elseif isfield(this.toBranches, oBranch.sName)
                this.throw('addBranch', 'Branch with name "%s" alreay exists!', oBranch.sName);
                
            end
            
            
            
            this.aoBranches(end + 1, 1)     = oBranch;
            if ~isempty(oBranch.sCustomName)
                if isfield(this.toBranches, oBranch.sCustomName)
                    error('A branch with this custom name already exists')
                else
                    this.toBranches.(oBranch.sCustomName) = oBranch;
                end
            else
                this.toBranches.(oBranch.sName) = oBranch;
            end
        end
        
        
        
        
        function connectSubsystemInterfaces(this, sLeftSysAndIf, sRightSysAndIf, csProcsLeft, csProcsRight, fVolume)
            %TODO error check if sys, if etc doesn't exist
            
            if nargin < 4 || isempty(csProcsLeft),  csProcsLeft  = {}; end;
            if nargin < 5 || isempty(csProcsRight), csProcsRight = {}; end;
            if nargin < 6, fVolume = []; end;
            
            % Get left, right child sysmtes
            [ sLeftSys, sLeftSysIf ] = strtok(sLeftSysAndIf, '.');
            sLeftSysIf = sLeftSysIf(2:end);
            
            [ sRightSys, sRightSysIf ] = strtok(sRightSysAndIf, '.');
            sRightSysIf = sRightSysIf(2:end);
            
            
            oLeftSys = this.toChildren.(sLeftSys);
            oRightSys = this.toChildren.(sRightSys);
            
            
            % Get branches
            csBranchIfs   = [ oLeftSys.aoBranches.csNames ];
            oLeftBranch = this.aoBranches(find(strcmp(csBranchIfs(2, :), sLeftSysIf), 1));
            
            csBranchIfs   = [ oRightSys.aoBranches.csNames ];
            oRightBranch = this.aoBranches(find(strcmp(csBranchIfs(2, :), sRightSysIf), 1));
            
            % Phases
            oLeftPhase  = oLeftBranch.coExmes{1}.oPhase;
            oRightPhase = oRightBranch.coExmes{1}.oPhase;
            
            
            % Smaller phase -> use for matter properties
            oRefPhase = sif(oLeftPhase.fVolume > oRightPhase.fVolume, oRightPhase, oLeftPhase);
            
            
            if isa(oLeftPhase, 'matter.phases.gas') && isa(oRightPhase, 'matter.phases.gas')
                sPhaseType = 'gas_virtual';
                
                if isempty(fVolume)
                    % Set to 10% percent of smaller phase
                    fVolume = 0.1 * oRefPhase.fVolume;
                end
                
                
            elseif isa(oLeftPhase, 'matter.phases.liquid') && isa(oRightPhase, 'matter.phases.liquid')
                sPhaseType = 'liquid';
                
                if isempty(fVolume)
                    % Throw?
                end
                
            else
                this.throw('connectIfBranches', 'Cannot handle phase types (either not equal, or not gas/liquid!');
            end
            
            % Create phases
            tfMass = struct();
            
            for iS = 1:length(oRefPhase.afMass)
                tfMass.(this.oMT.csSubstances{iS}) = oRefPhase.afMass(iS);
            end
            
            
            % Create store and phase
            sStoreName = sprintf('conn_%s_%s_and_%s_%s', sLeftSys, sLeftSysIf, sRightSys, sRightSysIf);
            sPhaseName = 'conn';
            
            
            matter.store(this, sStoreName, fVolume);
            
            oPhase = matter.phases.(sPhaseType)(this, sPhaseName, tfMass, fVolume, oRefPhase.fTemperature);
            
            
            matter.procs.exmes.gas(oPhase, 'left');
            matter.procs.exmes.gas(oPhase, 'right');
            
            
            % Create branches (left if -> phase, right if -> phase)
            sLeftIf  = sprintf('from_subs_%s_if_%s', sLeftSys, sLeftSysIf);
            sRightIf = sprintf('from_subs_%s_if_%s', sRightSys, sRightSysIf);
            
            
            matter.branch(this, sLeftIf,  csProcsLeft,  [ sPhaseName '.left' ]);
            matter.branch(this, sRightIf, csProcsRight, [ sPhaseName '.right' ]);
            
            
            % Connect
            oLeftSys.connectIF(sLeftSysIf, sLeftIf);
            oRightSys.connectIF(sRightSysIf, sRightIf);
            
        end
    end
    
    
    
    % Changed --> allow external access, e.g. scheduler needs to be able to
    % change the IFs ... or the Sub-System need to implement methods for
    % that, e.g. Human.goToFridge(sFridgeName) --> the human executes
    % this.connectIF('foodPort', sFridgeName) -> the galley/kitchen system
    % has to be already set as parent to human. Fridge would be a subsystem
    % of the according galley, an an interface branch already connected
    % from the fridge 'store' to the gally (door!). Human can connect to
    % that and get food.
    methods (Access = public, Sealed = true)
        
        function connectIF(this, sLocalInterface, sParentInterface)
            % Connect two branches, first (local) branch needs right side
            % interface, second (parent system) branch needs left side
            % interface.
            %
            % Find local branch, check for right side IF, then find parent
            % sys branch and check left side (abIFs)
            
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
            
            %DONE In following method?
%             %TODO bind/trigger events to make sure reconnecting of branches
%             %     is possible during simulation, see disconnectIF etc!
%             %     -> register on oBranch branch.connected if that one
%             %        get's reconnected!
            
            if ~oBranch.abIf(1) && ~isempty(oBranch.coExmes{2})
                % ... trigger event if anyone wants to know
                this.trigger('branch.connected', iLocalBranch);
            end
            
            % every matter interface has a respective thermal interface
            this.connectThermalIF(sLocalInterface, sParentInterface);
        end
        
        function disconnectIF(this, sLocalInterface)
            iLocalBranch = find(strcmp({ this.aoBranches.sNameLeft }, sLocalInterface), 1);
            
            if isempty(iLocalBranch)
                this.throw('connectIF', 'Local interface %s not found', sLocalInterface);
            end
            
            oBranch = this.aoBranches(iLocalBranch);
            
            if ~oBranch.abIfs(2)
                this.throw('connectIF', 'Branch doesn''t have an interface on the right side (connected to store).');
            end
            
            %TODO See above, handle events for disconnect during sim
            %bTrigger = ~oBranch.abIfs(1) && ~isempty(oBranch.coPhases{2});
            bTrigger = ~oBranch.abIfs(1) && ~isempty(oBranch.coExmes{2});
            
            oBranch.disconnect();
            
            % Do the trigger after the actual disconnect
            if bTrigger
                this.trigger('branch.disconnected', iLocalBranch);
            end
        end
        
        function removePassThroughBranches(this)
            % If a branch is a pass-through branch from a subsystem to a
            % supersystem via an intermediate system, abIf = [1; 1]. So we
            % just find all branches with an abIf like that and delete
            % them.
            
            % We should, however, only do this, if this method is called by
            % the supersystem. So before we do anything, we'll check if
            % this system is already sealed. If yes, we'll just return
            % without doing anything.
            
            %TODO insert a low level warning here, once the debug output
            %system is implemented. It might be usefull to alert the user
            %that someone is trying to delete the pass-through branches
            %here, although that should happen later. Template for the
            %warning message inserted below.
            
            if ~this.bSealed
                %this.throw('container.seal','The pass-through branches on %s cannot be deleted yet. First the container must be sealed.',this.sName);
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
                end
            end
        end
        
        function updateBranchNames(this, oBranch, sOldName)
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
end

