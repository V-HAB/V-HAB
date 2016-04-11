classdef circuit < base & event.source
    %CIRCUIT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Reference to a voltage or current source. Is initialized empty so
        % during seal() the system can determine if it is the master object
        % for the overall circuit, or just a subsystem part of a circuit.
        oSource = [];
        
        % Reference to the parent electrical system
        oParent;
        
        % Name of this circuit
        sName;
        
        aoStores = [];
        
        toStores = struct();
        
        aoNodes = electrical.node.empty();
        
        toNodes = struct();
        
        iNodes;
        
        aoComponents = [];
        
        toComponents = struct();
        
        aoBranches = electrical.branch.empty();
        
        toBranches = struct();
        
        iBranches;
        
        csLoops = cell.empty;
        
        mbConnections; 
        
        bSealed;
        
        % Reference to the timer
        % @type object
        oTimer;
    end
    
    methods
        
        function this = circuit(oParent, sName)
            this.oParent = oParent;
            this.sName = sName;
            this.oTimer = this.oParent.oRoot.oTimer;
            
            this.oParent.addCircuit(this);
            
        end
        
        function addStore(this, oStore)
            % Adds the store to toStores. Might be overloaded by derived
            % classes to e.g. implement some dynamic handling of store
            % volumes or other stuff.
            
            if this.bSealed
                this.throw('addStore', 'The container is sealed, so no stores can be added any more.');
            end
            
            if ~isa(oStore, 'electrical.store')
                this.throw('addStore', 'Provided object is not a electrical.store!');
            
            elseif isfield(this.toStores, oStore.sName)
                this.throw('addStore', 'Store with name %s already exists!', oStore.sName);
                
            elseif isa(oStore, 'electrical.stores.constantVoltageSource') || ...
                   isa(oStore, 'electrical.stores.constantCurrentSource')
               
               if isempty(this.oSource)
                   this.oSource = oStore;
               else
                   this.throw('addStore', 'This circuit (%s) already has a source. A circuit can only have one source.', this.sName);
               end
               
            end
            
            % Stores do not contain a reference to the container, so no
            % method needs to be called there.
            this.toStores.(oStore.sName) = oStore;
            
            if isempty(this.aoStores)
                this.aoStores = oStore;
            else
                this.aoStores(end + 1) = oStore;
            end
            
            
        end
        
        function addNode(this, oNode)
            if this.bSealed
                this.throw('addNode', 'The container is sealed, so no nodes can be added any more.');
            end
            
            if ~isa(oNode, 'electrical.node')
                this.throw('addNode', 'Provided object is not a electrical.node!');
            
            elseif isfield(this.toNodes, oNode.sName)
                this.throw('addNode', 'Node with name %s already exists!', oNode.sName);
            end
            
            this.toNodes.(oNode.sName) = oNode;
            
            if isempty(this.aoNodes)
                this.aoNodes = oNode;
            else
                this.aoNodes(end + 1) = oNode;
            end
            
            
        end
        
        function this = addBranch(this, oBranch)
            if this.bSealed
                this.throw('addBranch', 'Can''t create branches any more, sealed.');
                
            elseif ~isa(oBranch, 'electrical.branch')
                this.throw('addBranch', 'Provided branch is not a and does not inherit from matter.branch');
                
            elseif isfield(this.toBranches, oBranch.sName)
                this.throw('addBranch', 'Branch with name "%s" alreay exists!', oBranch.sName);
                
            end
            
            this.aoBranches(end + 1)     = oBranch;
           
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
        
        function addComponent(this, oComponent)
            % Adds a new component to the circuit.
            if this.bSealed
                this.throw('addComponent', 'The circuit is sealed, so no components can be added any more.');
            end
            
            if ~isa(oComponent, 'electrical.component')
                this.throw('addStore', 'Provided object is not a electrical.component!');
            
            elseif isfield(this.toComponents, oComponent.sName)
                this.throw('addStore', 'Component with name %s already exists!', oComponent.sName);
            
            end
            
            % Stores do not contain a reference to the container, so no
            % method needs to be called there.
            this.toComponents.(oComponent.sName) = oComponent;
            
            if isempty(this.aoComponents)
                this.aoComponents = oComponent;
            else
                this.aoComponents(end + 1) = oComponent;
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
        
        function seal(this)
            
            % Sealing the nodes
            this.iNodes    = length(this.aoNodes);
            for iI = 1:this.iNodes
                this.aoNodes(iI).seal();
            end
            
            %%% Copied from matter.container
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
                
                this.iBranches = length(this.aoBranches);
                
                for iI = 1:length(this.aoBranches)
                    % So now the stubs are deleted and the pass-through are
                    % already sealed, so we only have to seal the non-interface
                    % branches and the
                    if sum(this.aoBranches(iI).abIf) <= 1
                        this.aoBranches(iI).seal();
                    end
                end
                
%                 % Now that we've taken care of all the branches in this
%                 % container, we also no longer need the pass-through branches
%                 % on the subsystems beneath us. So we go through all of them
%                 % and call a removal method.
%                 if this.iChildren > 0
%                     for iI = 1:this.iChildren
%                         this.toChildren.(this.csChildren{iI}).removePassThroughBranches();
%                     end
%                 end
            end
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
                    sBranchName = aoBranchStubs(iI).sName;
                    if length(sBranchName) > namelengthmax
                        sBranchName = sBranchName(1:namelengthmax);
                    end
                    this.toBranches = rmfield(this.toBranches, sBranchName);
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
        
        function setOutdated(this)
            % Can be used by stores or components to request recalculation
            % of the currents and voltages, e.g. after some internal
            % parameters changed (closing switch).
            
            % Only trigger if not yet set
            if ~this.bOutdated
                this.bOutdated = true;

                % Trigger outdated so e.g. the branch solver can register a
                % postTick callback on the timer to recalc flow rate.
                this.trigger('outdated');
            end
        end
        
        function update(this, afValues)
            % Uses data in afValues from solver to set the currents in the
            % branches, the voltages in the nodes and the signs on the
            % terminals.
        end
        
    end
end

