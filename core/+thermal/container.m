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
                this.toBranches.(oThermalBranch.sName) = oThermalBranch;
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
                        this.toThermalBranches = rmfield(this.toBranches, aoBranchStubs(iI).sCustomName);
                    else
                        this.toThermalBranches = rmfield(this.toBranches, aoBranchStubs(iI).sName);
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
            
            this.iThermalBranches = this.iThermalBranches + length(this.aoThermalBranches);
            
            this.bThermalSealed = true;
        end
    end
end

