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
        
        
        % Sealed?
        bSealed = false;
    end
    
    methods
        function this = container(oParent, sName)
            this@sys(oParent, sName);
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
%DELETE? Is never called...
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
        
        
        
        function seal(this)
            if this.bSealed
                this.throw('seal', 'Already sealed');
            end
            
            this.csStores = fieldnames(this.toStores);
            this.csProcsF2F = fieldnames(this.toProcsF2F);
            
            for iI = 1:length(this.csStores)
                % Stores need a timer object, to be accessed by the phases
                % to e.g. register updates, find out elapsed time
                this.toStores.(this.csStores{iI}).seal(this.oTimer, this.oData);
            end
            
            
            for iI = 1:length(this.aoBranches)
                % Sealing off all of the branches
                this.aoBranches(iI).seal();
            end
            
            this.bSealed = true;
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
            
            elseif oStore.oMT ~= this.oData.oMT
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
                
            end
            
            this.toProcsF2F.(oProcF2F.sName) = oProcF2F;
        end
        
        
    end
    
    
    methods (Access = protected, Sealed = true)
%DELETE? Isn't this covered by the whole createBranch method?
%         function createPort(this, sStore)
%             % Creates a branch-like thing, basically directly connecting an
%             % EXME processor as an interface for branches from SUBsystems
%             % to connect to. If the EXME name is 'default', as for normal
%             % exmes several branches can be connected, representing e.g.
%             % several people in a room that all 'connect' to the atmospere
%             % for breathing.
%             %
%             % Name of I/F will be the store/port name (. replaced by _).
%             %
%             %TODO implement!
%             
%         end
        
        function [oBranch] = createBranch(this, sLeft, csProcs, sRight)
            
            
            if this.bSealed
                this.throw('createBranch', 'Can''t create branches any more, sealed.');
            end
            
            oBranch = matter.branch(this, sLeft, csProcs, sRight);
            
            this.aoBranches(end + 1, 1) = oBranch;
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
    end
end

