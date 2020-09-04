classdef branch < base.branch
    %BRANCH Thermal branch 
    % Here all basic properties and methods that all thermal branches
    % require are defined. Domain independent definitions are inherited
    % from the base branch.
    
    properties (SetAccess = protected)
        
        % The thermal conductivity of the branch
        fConductivity; % [W/K] or [W/K^4] depending on the child class
        
        % Boolean property to easier identify whether this branch solves
        % radiative heat transfer
        bRadiative = false;
        bNoConductor = false;
        
        % The currently transmitted heat flow through this branch
        fHeatFlow = 0;  % [W]
        
        % Array containing the temperature between each conductor and
        % exmes. For example if a branch contains two conductors the array
        % will have 3 etnries describing the following temperatures:
        % LeftExme - afTemperatures(1) - coConductors(1) - afTemperatures(2) - coConductors(2) - afTemperatures(3) - RightExme
        afTemperatures;
        
        % Object cell array containing a reference to the conductor objects
        % inside this branch
        coConductors = cell(0,0);
        % Integer providing the number of conductors in this branch,
        % usefull for looping through the conductors
        iConductors;
        
        % Matter object which solves the matter flow rate of this thermal
        % branch. Can either be a matter.branch or a p2p processor
        oMatterObject;
        
        % Falg to decide if we need to trigger the setHeatFlow event. If
        % nothing is bound to this event, it is not triggered saving
        % calculation time
        bTriggersetHeatFlowCallbackBound = false;
        
        % If the RIGHT side of the branch is an interface (i.e. i/f to the
        % parent system), store its index on the aoFlows here to make it
        % possible to remove those connections later!
        iIfConductors;
        
        % This property can be used to deactivate heat transfer via this
        % branch
        bActive = true;
    end
    
    methods
        
        function this = branch(oContainer, xLeft, csProcs, xRight, sCustomName, oMatterObject)
            % The thermal branch uses the same definition as the matter
            % branch, just with thermal object. A store with the
            % respective thermal exme is required as interface on both the
            % left (xLeft) and right (xRight) side and multiple conductors
            % of the same type (Advective, Conduction/Convective,
            % Radiative) can be defined in csProcs (similar to f2f procs on
            % the matter side)
            %
            % Can be called with either stores/ports or interface names
            % (all combinations possible). Connections are always done from
            % subsystem to system.
            if nargin < 5
                sCustomName = [];
            end
            
            if isobject(xLeft) && ~isa(xLeft, 'thermal.capacity')
                error('Capacity:Constructor', 'The object you are using to create a thermal branch, ''%s'', is not a thermal capacity.', xLeft.sName);
            end
            
            if isobject(xRight) && ~isa(xRight, 'thermal.capacity')
                error('Capacity:Constructor', 'The object you are using to create a thermal branch, ''%s'', is not a thermal capacity.', xRight.sName);
            end
            
            this@base.branch(oContainer, xLeft, csProcs, xRight, sCustomName, 'thermal');
            
            % Since there are thermal branches which do not have a matter
            % object (e.g. radiative or conductive branches) the matter
            % object is only added in case it is provided as input
            if nargin > 5
                this.oMatterObject = oMatterObject;
            end
            
            try
                this.bRadiative = this.coConductors{1}.bRadiative;
            catch oErr
                %nothing to do, since in that case no conductor exists at
                %all, meaning there is no resistance and the case has to be
                %handled specifically
                if isempty(this.coConductors)
                    this.bNoConductor = true;
                else
                    rethrow(oErr);
                end
            end
            
            %% Adding the branch to our container
            this.oContainer.addThermalBranch(this);
            
            % Counting the number of conductors in the branch
            this.iConductors = length(this.coConductors);
            
        end
        
        function createProcs(this, csProcs)
            %% Loop through conductor procs and add them to this branch
            for iI = 1:length(csProcs)
                sProc = csProcs{iI};
                
                if ~isfield(this.oContainer.toProcsConductor, sProc)
                    this.throw('branch', 'Conductor %s not found on system this branch belongs to!', sProc);
                end
                
                this.coConductors{end + 1} = this.oContainer.toProcsConductor.(sProc);
            end
        end
        
        function setOutdated(this)
            % Can be used by capacities or conductors to request recalc-
            % ulation of the flow rate, e.g. after some internal parameters
            % changed.
            
            % Only trigger if not yet set
            if ~this.bOutdated
                this.bOutdated = true;

                % Trigger outdated so e.g. the branch solver can register a
                % postTick callback on the timer to recalc flow rate.
                this.trigger('outdated');
            end
        end
        
        function setIfLength(this, iLength)
            % This function is used in case the branch is a system -
            % subsystem interface to tell the other branch how many
            % conductors are present in the other IF branch
            this.iIfConductors = iLength;
        end
        
        function setConductors(this, coConductors)
            % This function is used for branches which describe an
            % interface to combine the two branches of the IF into one
            % complete branch with all conductors
            this.coConductors = coConductors;
            this.iConductors = length(this.coConductors);
        end
        
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            % Overwrite the general bind function to be able and write
            % specific trigger flags
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % Only for setHeatFlow we set the Trigger to true which tells
            % us that we actually have to trigger this. Otherwise it is not
            % triggered saving calculation time
            if strcmp(sType, 'setHeatFlow')
                this.bTriggersetHeatFlowCallbackBound = true;
            end
        end
        
        function setActive(this, bActive)
            this.bActive = bActive;
            this.setOutdated();
        end
    end
    
    methods (Access = {?solver.thermal.base.branch, ?base.branch})
        function setHeatFlow(this, fHeatFlow, afTemperatures)
            % The solver calls this function to set the fHeatFlow and
            % afTemperatures values of the branch based on its internal
            % calculations.
            if this.abIf(1), this.throw('setHeatFlow', 'Left side is interface, can''t set flowrate on this branch object'); end
            
            % The registerUpdateTemperature() of the connected capacities
            % must be called before this function is called. Usually while
            % registering the update for the solver
            
            % Set the new heat flow
            this.fHeatFlow = fHeatFlow;
                
            % Set new temperature vector
            this.afTemperatures = afTemperatures;
            
            % Now we are no longer outdated, but up-to-date
            this.bOutdated = false;
            
            % If any call is bound to the setHeatFlow trigger of the branch
            % we execute the trigger, otherwise it is skipped
            if this.bTriggersetHeatFlowCallbackBound
                this.trigger('setHeatFlow');
            end
        end
    end
    
    methods (Sealed = true)
        function seal(this)
            % Seal aoFlows, get FR func handle
            
            if this.bSealed
                this.throw('seal', 'Already sealed');
            end
            for iI = 1:length(this.coConductors)
                this.coConductors{iI}.seal(this);
            end
            
            % now we no longer need the function to get the exmes from the
            % other IF branch because we created a single branch from it
            this.hGetBranchData = [];
            
            this.bSealed = true;
        end
    end
end