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
        % and all subsystems
        iThermalBranches = 0;
        
        % Total number of capacities inside this thermal container
        iCapacities = 0;
        
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
            
            % Creating the thermal capacities associated with matter stores
            % and the thermal branches associated with p2p processors. The
            % thermal branches associated with matter branches will be
            % created seprarately in this.createAdvectiveThermalBranches(),
            % which is called in simulation.infrastructure.initialize().
            this.createMatterCounterParts();
            
            this.trigger('createdThermalStructure');
            
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
            this.aoThermalBranches(end + 1, 1) = oThermalBranch;
            
            % Check if the branch has a custom name, and if it does add it
            % to the struct containing all thermal branches using the
            % custom name. Otherwise use the generic name
            if ~isempty(oThermalBranch.sCustomName)
                if isfield(this.toThermalBranches, oThermalBranch.sCustomName)
                    error('VHAB:ThermalContainer:BranchAlreadyExists','A thermal branch with this custom name already exists')
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
                
                this.iThermalBranches = this.iThermalBranches + length(this.toChildren.(sChild).aoThermalBranches);
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
            this.trigger('ThermalSolverCheck_post');
        end
        
        function createMatterCounterParts(this)
            %CREATEMATTERCOUNTERPARTS Creates capacities and thermal branches
            % This method loops through all matter stores and their phases
            % and creates a thermal capacity. And while we're here, we also
            % create thermal branches for the advective heat transfer
            % through p2p processors.
            
            %CHECK: Should flow phase automatically be a network capacity?
            %Would need to also automatically connect that to the
            %multi-branch solver in setThermalSolvers().
            %-> No, because the multi-branch solver only supports phases
            %where the mass doesn't change. (Status on: 18.05.2020)
            
            % Getting all of the store names in this container
            csMatterStores = fieldnames(this.toStores);
            
            % Loop through all stores
            for sStore = csMatterStores'
                %% Create a capacity for each phase
                % Loop through all phases of the current store
                for iPhase = 1:this.toStores.(sStore{1}).iPhases
                    
                    % Get a reference to the current phase
                    oPhase = this.toStores.(sStore{1}).aoPhases(iPhase);
                    
                    % We need to create a specific type of capacity
                    % depending on what kind of phase it will be associated
                    % with. It can be either a "normal" phase, a boundary
                    % phase, a phase whose capacity shall be part of a
                    % thermal network or a network boundary. The following
                    % if-elseif-else block checks for these conditions and
                    % calls the appropriate constructor.
                    if isa(oPhase, 'matter.phases.boundary.boundary') && oPhase.bThermalNetworkNode
                        thermal.capacities.network(oPhase, oPhase.fTemperature, true);
                    elseif isa(oPhase, 'matter.phases.boundary.boundary')
                        thermal.capacities.boundary(oPhase, oPhase.fTemperature);
                    elseif oPhase.bThermalNetworkNode
                        thermal.capacities.network(oPhase, oPhase.fTemperature, false);
                    elseif isa(oPhase, 'matter.phases.flow.flow')
                        thermal.capacities.flow(oPhase, oPhase.fTemperature);
                    else
                        thermal.capacity(oPhase, oPhase.fTemperature);
                    end
                    
                    % Now update the matter properties
                    oPhase.oCapacity.updateSpecificHeatCapacity();
                end
                
                %% Create a branch for each P2P
                
                % Getting the names of all p2p processors in this store
                csProcs = fieldnames(this.toStores.(sStore{1}).toProcsP2P);
                
                for sProcessor = csProcs'
                    
                    oProcessor = this.toStores.(sStore{1}).toProcsP2P.(sProcessor{1});
                    
                    % Create the respective thermal interfaces for the thermal
                    % branch
                    % Split to store name / ExMe name
                    oExMeIn = oProcessor.coExmes{1};
                    thermal.procs.exme(oExMeIn.oPhase.oCapacity, oProcessor.coExmes{1}.sName);
                    
                    oExMeOut = oProcessor.coExmes{2};
                    thermal.procs.exme(oExMeOut.oPhase.oCapacity, oProcessor.coExmes{2}.sName);
                    
                    % Now we automatically create a fluidic processor for the
                    % thermal heat transfer bound to the matter transferred by the
                    % P2P
                    try
                        thermal.procs.conductors.fluidic(oProcessor.oStore.oContainer, oProcessor.sName, oProcessor);
                        sCustomName = oProcessor.sName;
                        % The operation can fail because the P2Ps are local within a
                        % store and therefore can share common names acros multiple
                        % stores (e.g. you can have 5 Stores, each containing a P2P
                        % called "Absorber"). However, as F2Fs the thermal conductors
                        % are added to the parent system, and therefore must be unique
                        % for each system. Therefore we count a number up until we find
                        % a name that is not yet taken for the fluidic processor
                    catch oError
                        if contains(oError.message, 'already exists.')
                            bError = true;
                            iCounter = 2;
                            while bError == true
                                % now we just try the name until we find one that
                                % is not yet taken, increasing the counter each
                                % time the creation of the proc failed
                                try
                                    thermal.procs.conductors.fluidic(oProcessor.oStore.oContainer, [oProcessor.sName, '_', num2str(iCounter)], oProcessor);
                                    bError = false;
                                catch oError
                                    if contains(oError.message, 'already exists.')
                                        iCounter = iCounter + 1;
                                    else
                                        % If it is another error than what we area looking for,
                                        % we do throw the error
                                        this.throw('P2P-thermal', oError.message)
                                    end
                                end
                                
                                % If we reach 1000 Iterations, throw an error as we
                                % are not likely to find a valid name anymore
                                if iCounter >= 1000
                                    this.throw('P2P-thermal',[ 'could not find a valid name for the thermal fluidic conductor of P2P ', oProcessor.sName])
                                end
                            end
                            sCustomName = [oProcessor.sName, '_', num2str(iCounter)];
                        else
                            % If it is another error than what we area looking for,
                            % we do throw the error
                            this.throw('P2P', oError.message)
                        end
                    end
                    
                    % Now we generically create the corresponding thermal branch
                    % using the previously created fluidic conductor.
                    sLeftPort  = [oProcessor.oStore.sName, '.', oExMeIn.sName];
                    sRightPort = [oProcessor.oStore.sName, '.', oExMeOut.sName];
                    oBranch = thermal.branch(oProcessor.oStore.oContainer, sLeftPort, {sCustomName}, sRightPort, sCustomName, oProcessor);
                    
                    % Setting a reference to this thermal branch on the P2P 
                    oProcessor.setThermalBranch(oBranch);
                end
            end
            
        end
        
        function createAdvectiveThermalBranches(this, aoBranches, bNoRecursion)
            %CREATEADVECTIVETHERMALBRANCHES Creates a thermal branch for each matter branch
            
            if nargin < 3
                bNoRecursion = false;
            end
            
            % First we loop through all children of this object and call
            % the method there as well. If there are P2P branches in a
            % system, we will pass on the aoP2PBranch array instead, and in
            % that case we don't want the recursion to the child objects to
            % happen. 
            if ~bNoRecursion
                csChildren = fieldnames(this.toChildren);
                for sChild = csChildren'
                    oChild = this.toChildren.(sChild{1});
                    oChild.createAdvectiveThermalBranches(oChild.aoBranches);
                end
            end
            
            % To model the mass-bound heat (advective) transfer we need a
            % thermal branch in parallel to each matter branch. So here we
            % loop through all matter branches in this container and create
            % some thermal branches.
            for iBranch = 1:length(aoBranches)
                oBranch = aoBranches(iBranch);
                
                % If there is one or more processor, we loop through them
                % and create corresponding fluidic conductors. 
                if oBranch.iFlowProcs >= 1
                    % Getting the names of all f2f-processors in the current
                    % branch
                    csProcs = {oBranch.aoFlowProcs.sName};
                    for iProc = 1:length(csProcs)
                        thermal.procs.conductors.fluidic(this, csProcs{iProc}, oBranch);
                    end
                else
                    % Branches without a f2f can exist (e.g. manual branches)
                    % however for the thermal branch we always require at least
                    % one conductor
                    
                    % Initializing/clearing the csProcs cell
                    csProcs = cell.empty();
                    
                    % Constructing the name of the thermal conductor by adding
                    % the string '_Conductor' to either the custom name or
                    % regular name of this branch.
                    if ~isempty(oBranch.sCustomName)
                        csProcs{1} = [oBranch.sCustomName, '_Conductor'];
                    else
                        csProcs{1} = [oBranch.sName, '_Conductor'];
                    end
                    
                    % Since this name will be used as a struct field name, we
                    % need to make sure it doesn't exceed the maximum field
                    % name length of 63 characters.
                    if length(csProcs{1}) > 63
                        % Generating some messages for the debugger
                        if ~base.oDebug.bOff
                            this.out(3,1,'thermal.branch','Truncating automatically generated thermal conductor name.');
                            this.out(3,2,'thermal.branch','Old name: %s', csProcs{1});
                        end
                        
                        % Truncating the name
                        csProcs{1} = csProcs{1}(1:63);
                        
                        % More debugging output
                        if ~base.oDebug.bOff
                            this.out(3,2,'thermal.branch','New name: %s', csProcs{1});
                        end
                    end
                    
                    % Now we can actually create the conductor.
                    thermal.procs.conductors.fluidic(this, csProcs{1}, oBranch);
                end
                
                % Getting the left and right capacities
                oLeftCapacity  = oBranch.coExmes{1}.oPhase.oCapacity;
                oRightCapacity = oBranch.coExmes{2}.oPhase.oCapacity;
                
                % Before the creation of this method, the thermal branches
                % associated with matter branches were created directly in
                % matter.branch. In order to better separate the matter and
                % thermal domains in V-HAB this method was created that is
                % called after the matter domain has been sealed. This has
                % the drawback, that when the matter branch is created, the
                % thermal capacities associated with the matter phases have
                % not yet been created, so no thermal exme can be created
                % either. 
                % As a result, the thermal exmes are created automatically
                % here by passing the capacity objects to the
                % thermal.branch constructor. However, some existing code
                % relies on the fact, that the thermal and matter exmes hav
                % the same name. In order to retain the names of the exmes,
                % the commented code below this text block was created. For
                % most cases it works, but it fails when interface branches
                % are involved that connect stores with the same name on
                % different system levels. This is a very complex edge case
                % to catch, so it was decided to create new exmes
                % automatically by passing the capacity objects. The matter
                % exmes corresponding to the thermal exmes can be obtained
                % via the oMatterObject property of the thermal branch. The
                % commented code below is left in just to show how this
                % problem was attempted to be circumvented. 
                
%                 sLeftStoreName = oBranch.coExmes{1}.oPhase.oStore.sName;
%                 sLeftExMeName  = oBranch.coExmes{1}.sName;
%                 sLeftSide      = [sLeftStoreName, '.', sLeftExMeName];
%                 
%                 thermal.procs.exme(oLeftCapacity, sLeftExMeName);
%                 
%                 sRightStoreName = oBranch.coExmes{2}.oPhase.oStore.sName;
%                 sRightExMeName  = oBranch.coExmes{2}.sName;
%                 sRightSide      = [sRightStoreName, '.', sRightExMeName];
%                 
%                 thermal.procs.exme(oRightCapacity, sRightExMeName);
%                 
%                 oThermalBranch = thermal.branch(this, sLeftSide, csProcs, sRightSide, oBranch.sCustomName, oBranch);
                
                % Now we have everything we need, so we can call the thermal
                % branch constructor.
                oThermalBranch = thermal.branch(this, oLeftCapacity, csProcs, oRightCapacity, oBranch.sCustomName, oBranch);
                
                % Giving the matter branch associated with this thermal branch
                % a reference. 
                oBranch.setThermalBranch(oThermalBranch);
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
    
    methods (Access = protected)
        function disconnectThermalBranchesForSaving(this)
            %DISCONNECTTHERMALBRANCHESFORSAVING Disconnects all thermal branches
            %   This is necessary when the simulation object is saved to a
            %   MAT file. In large and/or networked systems the number of
            %   consecutive, unique objects that are referenced in a row
            %   cannot be larger than 500. In order to break these chains,
            %   we delete the reference to the branch on all thermal ExMes
            %   on both sides of all branches. Since the branch object
            %   retains references to the ExMes, we can easily reconnect
            %   them on load. 
            
            % Getting the names of all branches
            csBranchNames = fieldnames(this.toThermalBranches);
            
            % Looping through all branches and calling the
            % disconnectBranch() method on the ExMes.
            for iBranch = 1:length(csBranchNames)
                this.toThermalBranches.(csBranchNames{iBranch}).coExmes{1}.disconnectBranch();
                this.toThermalBranches.(csBranchNames{iBranch}).coExmes{2}.disconnectBranch();
            end
            
        end
        
        function reconnectThermalBranches(this)
            %RECONNECTTHERMALBRANCHES Reconnects all thermal branches
            %   This reverses the action performed in
            %   disconnectThermalBranchesForSaving().
            
            % Getting the names of all branches
            csBranchNames = fieldnames(this.toThermalBranches);
            
            % Looping through all branches and calling the
            % reconnectBranch() method on the ExMes, passing in the
            % currently selected branch as an argument.
            for iBranch = 1:length(csBranchNames)
                this.toThermalBranches.(csBranchNames{iBranch}).coExmes{1}.reconnectBranch(this.toThermalBranches.(csBranchNames{iBranch}));
                this.toThermalBranches.(csBranchNames{iBranch}).coExmes{2}.reconnectBranch(this.toThermalBranches.(csBranchNames{iBranch}));
            end
        end
    end
end