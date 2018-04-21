classdef container < sys
    %CONTAINER A collection of thermal capacities
    %   Detailed explanation goes here
        
    properties (SetAccess = protected, GetAccess = public)
        % TO DO: add stores here as well? toStores = struct();
        
        % Branches stored as mixin (?) array, so e.g. all flow rates can be
        % extracted with [ this.aoBranches.fFlowRate ] @type array @types
        % object
        aoThermalBranches = thermal.branch.empty();
        
        % Processors - also stored in the branch they belong to, but might
        % be helpfull to access them here through their name to e.g.
        % execute some methods (close valve, switch off fan, ...)
        toProcsConductor = struct();
        
        % Cached names
        csConductors;
        
        % Reference to the branches, by name
        toThermalBranches = struct();
        
        iThermalBranches = 0;
        iCapacities = 0;
        
        oMatterContainer;
        
        % Sealed?
        bThermalSealed = false;
    end
    
    methods
        
        function this = container(oParent, sName)
            % Create a new container object and call the |sys| parent
            % constructor. 
            
            % Call the |sys| (parent) constructor. This should register the
            % container with the parent (see |sys.setParent|) and get/set
            % some data from the parent. 
            this@sys(oParent, sName);
            
        end
        
        function createThermalStructure(this)
            % Call in child elems
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                
                this.toChildren.(sChild).createThermalStructure();
            end
        end
        
        function this = addProcConductor(this, oConductor)
            % Adds a conductor.
            
            if this.bThermalSealed
                this.throw('addProcConductor', 'The container is sealed, so no conductors can be added any more.');
            end
            
            
            if ~isa(oConductor, 'thermal.procs.conductor')
                this.throw('addProcConductor', 'Provided object ~isa thermal.procs.conductor');
                
            elseif isfield(this.toProcsConductor, oConductor.sName)
                this.throw('addProcConductor', 'Conductor %s already exists.', oConductor.sName);
                
            elseif this ~= oConductor.oContainer
                this.throw('addProcConductor', 'Conductor does not have this vsys set as a container!');
            
            end
            
            this.toProcsConductor.(oConductor.sName) = oConductor;
        end
        
        function this = addThermalBranch(this, oThermalBranch)
            % add a thermal branch to the system and check if a branch of
            % the same name already exists on the system
            if this.bThermalSealed
                this.throw('addThermalBranch', 'Can''t create branches any more, sealed.');
                
            elseif ~isa(oThermalBranch, 'thermal.branch')
                this.throw('addThermalBranch', 'Provided branch is not a thermal.branch and does not inherit from thermal.branch');
                
            elseif isfield(this.toThermalBranches, oThermalBranch.sName)
                this.throw('addBranch', 'Branch with name "%s" alreay exists!', oThermalBranch.sName);
                
            end
            
            this.aoThermalBranches(end + 1, 1)     = oThermalBranch;
            if ~isempty(oThermalBranch.sCustomName)
                if isfield(this.toThermalBranches, oThermalBranch.sCustomName)
                    error('A thermal branch with this custom name already exists')
                else
                    this.toThermalBranches.(oThermalBranch.sCustomName) = oThermalBranch;
                end
            else
                this.toThermalBranches.(oThermalBranch.sName) = oThermalBranch;
            end
        end
        
        function sealThermalStructure(this, ~)
            if this.bThermalSealed
                this.throw('sealThermalStructure', 'Already sealed');
            end
            
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                
                this.toChildren.(sChild).sealThermalStructure();
                
                this.iThermalBranches = this.iThermalBranches + length(this.toChildren.(sChild).toThermalBranches);
            end
            
            this.csConductors = fieldnames(this.toProcsConductor);
            
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
            if ~isempty(this.aoThermalBranches)
                % Now we can get the 2xN matrix for all the branches in the
                % container.
                mbIf = subsref([this.aoThermalBranches.abIf], struct('type','()','subs',{{ 1:2, ':' }}));
                % Using the element-wise AND operator '&' we delete only the
                % branches with abIf = [1; 0].
                % First we create a helper array.
                aoBranchStubs = this.aoThermalBranches(mbIf(1,:) & ~mbIf(2,:));
                % Now we delete the branches from the aoBranches property.
                this.aoThermalBranches(mbIf(1,:) & ~mbIf(2,:)) = [];
                % Now, using the helper array, we delete the fields from
                % the toBranches struct.
                for iI = 1:length(aoBranchStubs)
                    if ~isempty(aoBranchStubs(iI).sCustomName)
                        this.toThermalBranches = rmfield(this.toThermalBranches, aoBranchStubs(iI).sCustomName);
                    else
                        this.toThermalBranches = rmfield(this.toThermalBranches, aoBranchStubs(iI).sName);
                    end
                end
                
                for iI = 1:length(this.aoThermalBranches)
                    % So now the stubs are deleted and the pass-through are
                    % already sealed, so we only have to seal the non-interface
                    % branches and the
                    if sum(this.aoThermalBranches(iI).abIf) <= 1
                        this.aoThermalBranches(iI).seal();
                    end
                end
                
                % Now that we've taken care of all the branches in this
                % container, we also no longer need the pass-through branches
                % on the subsystems beneath us. So we go through all of them
                % and call a removal method.
                if this.iChildren > 0
                    for iI = 1:this.iChildren
                        this.toChildren.(this.csChildren{iI}).removePassThroughThermalBranches();
                    end
                end
            end
            
            this.iThermalBranches = length(this.aoThermalBranches);
           
            this.bThermalSealed = true;
            
            this.trigger('ThermalSeal_post');
            
        end
        
        function setThermalSolvers(this, ~)
            % automatically assing solver for branches which do not yet
            % have a handler
            for iBranch = 1:this.iThermalBranches
                if isempty(this.aoThermalBranches(iBranch).oHandler)
                    
                    if isa(this.aoThermalBranches(iBranch).coConductors{1}, 'thermal.procs.conductors.fluidic')
                         solver.thermal.basic_fluidic.branch(this.aoThermalBranches(iBranch));
                    else
                         solver.thermal.basic.branch(this.aoThermalBranches(iBranch));
                    end
                end
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
        
        function connectThermalIF(this, sLocalInterface, sParentInterface)
            % Connect two branches, first (local) branch needs right side
            % interface, second (parent system) branch needs left side
            % interface.
            %
            % Find local branch, check for right side IF, then find parent
            % sys branch and check left side (abIFs)
            
            % Get cell with branch end names, 2nd row is right names (the
            % csNames is two rows, one col with left/right name --> get
            % from several branches, col vectors appended to 2xN matrix)
            csLocalIfs   = [ this.aoThermalBranches.csNames ];
            iLocalBranch = find(strcmp(csLocalIfs(2, :), sLocalInterface), 1);
            
            if isempty(iLocalBranch)
                this.throw('connectIF', 'Local interface %s not found', sLocalInterface);
            end
            
            oBranch = this.aoThermalBranches(iLocalBranch);
            
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
        
        function disconnectThermalIF(this, sLocalInterface)
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
        
        function removePassThroughThermalBranches(this)
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
            if ~isempty(this.aoThermalBranches)
                % First we get the 2xN matrix for all the branches in the
                % container.
                mbIf = subsref([this.aoThermalBranches.abIf], struct('type','()','subs',{{ 1:2, ':' }}));
                
                % Using the element-wise AND operator '&' we delete only the
                % branches with abIf = [1; 0].
                % First we create a helper array.
                aoBranchStubs = this.aoThermalBranches(mbIf(1,:) & ~mbIf(2,:));
                % Now we delete the branches from the aoBranches property.
                this.aoThermalBranches(mbIf(1,:) & ~mbIf(2,:)) = [];
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
                    this.toThermalBranches = rmfield(this.toThermalBranches, sName);
                end
            end
        end
        
        function updateThermalBranchNames(this, oBranch, sOldName)
            % First we make sure, that the calling branch is actually a
            % branch in this container. 
            if any(this.aoThermalBranches == oBranch)
                % We need to jump through some hoops because the maximum
                % field name length of MATLAB is only 63 characters, so we 
                % delete the rest of the actual branch name...
                % namelengthmax is the MATLAB variable that stores the 
                % maximum name length, so in case it changes in the future, 
                % we don't have to change this code!
                if length(sOldName) > namelengthmax
                    sOldName = sOldName(1:namelengthmax);
                end
                this.toThermalBranches = rmfield(this.toThermalBranches, sOldName);
                % Now we'll add the branch to the struct again, but with
                % its new name. 
                if ~isempty(oBranch.sCustomName)
                    this.toThermalBranches.(oBranch.sCustomName) = oBranch;
                else
                    this.toThermalBranches.(oBranch.sName) = oBranch;
                end
            else
                % In case the calling branch is not in this container, we
                % throw an error message.
                this.throw('container:updateThermalBranchNames','The provided branch does not exist in this thermal container.');
            end
        end
    end
end

