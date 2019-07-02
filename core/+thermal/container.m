classdef container < sys
    %CONTAINER A collection of thermal capacities
    %   Container is the base class of the thermal domain in V-HAB. It
    %   contains capacities and branches. Together with the other
    %   containers (matter, electrical) a complete container is built which
    %   contains all necessary functions for all the domains.    
        
    properties (SetAccess = protected, GetAccess = public)
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
        
        % A cell containing all capacities in this container. This needs to
        % be a cell and not a struct because a capacity is linked to matter
        % phases and they can have identical names. This property is
        % included to enable looping through all capacities.
        coCapacities;
        
        % Reference to the branches, by name
        toThermalBranches = struct();
        
        % Total number of thermal branches inside this thermal container
        iThermalBranches = 0;
        
        % Total number of capacities inside this thermal container
        iCapacities = 0;
        
        % Reference to the corresponding matter container
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
            %CREATETHERMALSTRUCTURE Calls this function on all child objects
            %   This method will contain the definiton of the thermal
            %   system in the classes that inherit from this class. The
            %   only thing we have to do here is therefore to call it on
            %   all child objects.
            
            % Getting the names of all child systems
            csChildren = fieldnames(this.toChildren);
            
            % now loop through all children and calld this function
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                
                this.toChildren.(sChild).createThermalStructure();
            end
        end
        
        function this = addProcConductor(this, oConductor)
            % Function used to add a conductor to the system. The
            % conductors first have to be added to the system in order for
            % them to be available in the definition of the thermal branch
            
            % Check if the system is already sealed. If it is we cannot add
            % anything anymore
            if this.bThermalSealed
                this.throw('addProcConductor', 'The container is sealed, so no conductors can be added any more.');
            end
            
            % Check if the correct input is used for this function
            if ~isa(oConductor, 'thermal.procs.conductor')
                this.throw('addProcConductor', 'Provided object is not a thermal.procs.conductor');
                
            elseif isfield(this.toProcsConductor, oConductor.sName)
                this.throw('addProcConductor', 'Conductor %s already exists.', oConductor.sName);
                
            elseif this ~= oConductor.oContainer
                this.throw('addProcConductor', 'Conductor does not have this vsys set as a container!');
            
            end
            
            % if everything checks out add the conductor to the system
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
            
            % add the branch to the array containing all thermal branches
            % as new field
            this.aoThermalBranches(end + 1, 1)     = oThermalBranch;
            
            % Check if the branch has a custom name, and if it does add it
            % to the struct containing all thermal branches using the
            % custom name. Otherwise use the generic name
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
            % seal the thermal structure and delete no longer required
            % "stubs" of interface branches
            
            if this.bThermalSealed
                this.throw('sealThermalStructure', 'Already sealed');
            end
            
            % get the names of all children
            csChildren = fieldnames(this.toChildren);
            
            % loop through all children and seal their thermal structure.
            % Then set the iThermalbranches property
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
            % automatically adding solver for branches which do not yet
            % have a handler
            for iBranch = 1:this.iThermalBranches
                if isempty(this.aoThermalBranches(iBranch).oHandler)
                    % If the exmes are still empty the branch is a pass
                    % through branch from a subsystem of this system to a
                    % suprasystem and is defined correctly at another time
                    if ~isempty(this.aoThermalBranches(iBranch).coExmes)
                        if isempty(this.aoThermalBranches(iBranch).coConductors)
                            solver.thermal.infinite.branch(this.aoThermalBranches(iBranch));
                        elseif isa(this.aoThermalBranches(iBranch).coConductors{1}, 'thermal.procs.conductors.fluidic')
                            solver.thermal.basic_fluidic.branch(this.aoThermalBranches(iBranch));
                        else
                            solver.thermal.basic.branch(this.aoThermalBranches(iBranch));
                        end
                    end
                end
            end
        end
        
        function checkThermalSolvers(this)
            % Check if all branches have a solver, both here and in our
            % children.
            
            csChildren = fieldnames(this.toChildren);
            for iChild = 1:this.iChildren
                this.toChildren.(csChildren{iChild}).checkThermalSolvers();
            end
            
            for iBranch = 1:length(this.aoThermalBranches)
                % If the branch handler is empty, there is an error. 
                if isempty(this.aoThermalBranches(iBranch).oHandler)
                    error(['Error in System ''%s''. The branch ''%s'' has no solver.\n', ... 
                           'Make sure you are calling the setThermalSolvers() method in the \n',...
                           'createSolverStructure() method in ''%s''.'], ...
                           this.sName, this.aoThermalBranches(iBranch).sName, this.sName);
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
                aoBranchStubs = this.aoThermalBranches(mbIf(1,:) & mbIf(2,:));
                % Now we delete the branches from the aoBranches property.
                this.aoThermalBranches(mbIf(1,:) & mbIf(2,:)) = [];
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
                    
                    % We also need to decrease the iThermalBranches
                    % property by one. 
                    this.iThermalBranches = this.iThermalBranches - 1;
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
        
        function addCapacity(this, oCapacity)
            % Adds a capacity to the coCapacities cell
            this.coCapacities{end+1} = oCapacity;
            
            % Incrementing the capacity counter
            this.iCapacities = this.iCapacities + 1;
        end
    end
end