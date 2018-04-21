classdef branch < base & event.source
    % Thermal base branch class definition. Here all basic properties and
    % methodes that all thermal branches require are defined
    
    properties (SetAccess = protected)
        
        % The thermal conductivity of the branch
        fConductivity; % [W/K] or [W/K^4] depending on the child class
        
        fHeatFlow = 0;
        
        afTemperatures;
        
        % Reference to the system containing this thermal branch
        oContainer;
        % Reference to the matter table
        oMT;
        % Reference to the timer
        oTimer;
        
        % Cell Array containg the names of the thermal extract merge
        % processors of this branch
        csNames;
        
        % Generically generated name of the branch
        sName;
        
        % User defined name of the branch
        sCustomName;
        
        % Interfaces left/right?
        abIf = [ false; false ];
        
        % Object array containing a reference to the conductor objects
        % inside this branch
        coConductors = cell(0,0);
        iConductors;
        
        coExmes;
        
        % Connected branches on the left (index 1, branch in subsystem) or
        % the right (index 2, branch in supsystem) side?
        % @type cell
        % @types object
        coBranches = { thermal.branch.empty(1, 0); thermal.branch.empty(1, 0) };
        
        % boolean value to check if the branch is already set for update
        bOutdated = false;
        
        bSealed = false;
        
        % Solver object responsible for the calculations in this branch
        oHandler;
        
        % boolean to decide if event should be triggered or not
        bTriggersetHeatFlowCallbackBound = false;
    end
    
    properties (SetAccess = private, GetAccess = private)
        % Function handle to the protected flow method setData, used to
        % update values within the flow objects array
        hSetFlowData;
        
        % If the RIGHT side of the branch is an interface (i.e. i/f to the
        % parent system), store its index on the aoFlows here to make it
        % possible to remove those connections later!
        iIfConductors;
        
        
        % Callback function handle; called when a new branch is connected
        % here on the right side to tell the branch on the left side, if
        % one exists, to update its flow rate handles and right phase
        hUpdateConnectedBranches;
        
        % Get flow rate handles and phase from right side branch (passes
        % that through if another branch on its right side)
        hGetBranchData;
        
        % Callback to tell the right side branch to disconnect from this
        % branch here
        hSetDisconnected;
        
        % Callback from the interface flow seal method, can be used to
        % disconnect the i/f flow and the according f2f proc in the supsys
        hRemoveIfProc;
    end
    
    methods
        
        function this = branch(oContainer, sLeft, csProcs, sRight, sCustomName, oMassBranch)
            % The thermal branch uses the same definition as the matter
            % branch, just with thermal object. A matter phase with the
            % respective thermal exme is rerquire as interface on both the
            % left and right side and multiple conductors of the same type
            % (Advective, Conduction/Convective, Radiative) can be defined
            % in csProcs (similar to f2f procs on the matter side)
            %
            % Can be called with either stores/ports or interface names
            % (all combinations possible). Connections are always done from
            % subsystem to system.
            
            % Reference to the matter.container and some shorthand refs.
            this.oContainer = oContainer;
            this.oMT        = oContainer.oMT;
            this.oTimer     = oContainer.oTimer;
            
            this.csNames    = strrep({ sLeft; sRight }, '.', '__');
            sTempName      = [ this.csNames{1} '___' this.csNames{2} ];
            
            % We need to jump through some hoops because the
            % maximum field name length of MATLAB is only 63
            % characters, so we delete the rest of the actual
            % branch name... 
            % namelengthmax is the MATLAB variable that stores the
            % maximum name length, so in case it changes in the
            % future, we don't have to change this code!
            if length(sTempName) > namelengthmax
                sTempName = sTempName(1:namelengthmax);
            end
            this.sName = sTempName;
            
            if nargin >= 5
                this.sCustomName = sCustomName;
            end
            
            if nargin >= 6
                this.oMassBranch = oMassBranch;
            end
            
            
            % Interface on left side?
            if ~contains(sLeft, '.')
                this.abIf(1) = true;
                
                % Checking if the interface name is already present in this
                % system. Only do this if there any branches at all, of course. 
                if ~isempty(this.oContainer.aoThermalBranches) && any(strcmp(subsref([ this.oContainer.aoThermalBranches.csNames ], struct('type', '()', 'subs', {{ 1, ':' }})), sLeft))
                    this.throw('branch', 'An interface called ''%s'' already exists in ''%s''! Please choose a different name.', sLeft, this.oContainer.sName);
                end
            else
                % Split to store name / port name
                [ sStore, sPort ] = strtok(sLeft, '.');
                
                % Get store name from parent
                if ~isfield(this.oContainer.toStores, sStore), this.throw('branch', 'Can''t find provided store %s on parent system', sStore); end;
                
                % Get EXME port/proc ...
                oPort = this.oContainer.toStores.(sStore).getThermalPort(sPort(2:end));
                
                this.coExmes{1} = oPort;
                
                % Add the branch to the exmes of this branch
                this.coExmes{1}.addBranch(this);
            end
            
            
            % Loop through conductor procs
            for iI = 1:length(csProcs)
                sProc = csProcs{iI};
                
                if ~isfield(this.oContainer.toProcsConductor, sProc)
                    this.throw('branch', 'Conductor %s not found on system this branch belongs to!', sProc);
                end
                
                this.coConductors{end + 1} = this.oContainer.toProcsConductor.(sProc);
            end
            
            %%%% HANDLE RIGHT SIDE
            
            % Interface on right side?
            if ~contains(sRight, '.')
                
                this.abIf(2) = true;
                this.iIfConductors = length(this.coConductors);
                
                % Checking if the interface name is already present in this
                % system. Only do this if there any branches at all, of course. 
                if ~isempty(this.oContainer.aoThermalBranches) && any(strcmp(subsref([ this.oContainer.aoThermalBranches.csNames ], struct('type', '()', 'subs', {{ 2, ':' }})), sRight))
                    this.throw('branch', 'An interface called ''%s'' already exists in ''%s''! Please choose a different name.', sRight, this.oContainer.sName);
                end
            else
                % Split to store name / port name
                [ sStore, sPort ] = strtok(sRight, '.');
                
                % Get store name from parent
                if ~isfield(this.oContainer.toStores, sStore), this.throw('branch', 'Can''t find provided store %s on parent system', sStore); end;
                
                % Get EXME port/proc ...
                oPort = this.oContainer.toStores.(sStore).getThermalPort(sPort(2:end));
                
                this.coExmes{2} = oPort;
                % Add the branch to the exmes of this branch
                this.coExmes{2}.addBranch(this);
            end
            
            % Adding the branch to our matter.container
            this.oContainer.addThermalBranch(this);
            
            this.iConductors = length(this.coConductors);
            
        end
        
        
        function connectTo(this, sInterface)
            % The sInterface parameter has to be the name of a valid
            % interface for subsystems of a branch in the parent system,
            % i.e. on the 'left' side of the branch. 
            % Write the aoFlows from the other branch, and the oPhase/oFlow
            % (end flow) to this branch here, store indices to be able to
            % remove the references later.
            %
            %TODO Check connectTo branch - is EXME? Then some specific
            %     handling of the connection to EXME ... see above
            
            % Find matching interface branch
            % See container -> connectIF, need to get all left names of
            % branches of parent system, since they depict the interfaces
            % to subsystems
            iBranch = find(strcmp(...
                subsref([ this.oContainer.oParent.aoThermalBranches.csNames ], struct('type', '()', 'subs', {{ 1, ':' }})), ...
                sInterface ...
            ), 1);
            
            
            if isempty(iBranch)
                this.throw('connectTo', 'Can''t find an interface branch %s on the parent system', sInterface);
            
            elseif ~this.abIf(2)
                this.throw('connectTo', 'Right side of this branch is not an interface, can''t connect to anyone!');
            
            elseif ~isempty(this.coBranches{2})
                this.throw('connectTo', 'Branch already connected to su*p*system (parent system) branch!');
                
            end
            
            % If this branch is a pass-through branch, then this.abIf = [1;1]
            % In this case the branch we are trying to connect to on the
            % super system should actually connect to the branch connected
            % to us on the left side, because that one is the actual final
            % branch which will always 'belong' to the lowest system in the
            % chain of connected interface branches. We (this) are just the
            % leftover stub. 
            
            this.coBranches{2} = this.oContainer.oParent.aoThermalBranches(iBranch);
            
            % Maybe other branch doesn't like us, to try/catch
            try
                if ~all(this.abIf)
                    [ this.hGetBranchData, this.hSetDisconnected ] = this.coBranches{2}.setConnected(this, @this.updateConnectedBranches);
                else
                    oBranch = this.coBranches{1};
                    [ this.hGetBranchData, this.hSetDisconnected ] = this.coBranches{2}.setConnected(oBranch, @oBranch.updateConnectedBranches);
                end
                
                % Error - reset the coBRanches
            catch oErr
                this.coBranches{2} = [];
                
                rethrow(oErr);
            end
            
            % Does this branch we are connecting to have any flow to flow
            % processors?
            if this.coBranches{2}.iConductors == 0
                % Is the branch we are connecting to a pass-through branch?
                if ~all(this.coBranches{2}.abIf)
                    % Since this non-pass-through branch has no flow
                    % processors, we can connect directly to the exme on
                    % the right side of this branch. It can't be on the
                    % left side, of course, since this is where the
                    % interface is!
                    oProc = this.coBranches{2}.coExmes{2};
                else
                    this.throw('Pass-through branches currently require at least one conductor processor. Branch %s has none.', this.coBranches{2}.sName);
                end
            else
                oProc = this.coBranches{2}.coConductors{1};
            end
            
            % To help with debugging, we now change this branch's sName
            % property to reflect the actual flow path between two exmes
            % that it models. First we split the branch name at the three
            % consecutive underscores '___' which delimit the left and
            % right side of a branch name. 
            csLeftBranchName  = strsplit(this.sName, '___');
            csRightBranchName = strsplit(this.coBranches{2}.sName, '___');
            
            % Before we delete it, we'll save the old branch name
            % temporarily, because we'll need it one more time. We also
            % need to check, if this branch had a custom name assigned to
            % it, because in that case we will have to replace that name.
           	if ~isempty(this.sCustomName)
                sOldName = this.sCustomName;
            else
                sOldName = this.sName;
            end
            
            % Now we set the new name for this branch, inserting the
            % letters 'if' in the middle, so when looking at the name, we
            % know that this is a subsystem to supersystem branch.
            this.sName = [ csLeftBranchName{1}, '___if___', csRightBranchName{2} ];
            
            % Now we call the updateBranchNames() method on our container,
            % so the updated branch names are also visible there. 
            this.oContainer.updateThermalBranchNames(this, sOldName);
            
            % If this is a pass-through branch, this branch will be deleted
            % once the full branch is completely assembled. So we also have
            % to rename the subsystem branch that we connected earlier.
            % Here we create the name that is then passed on via the
            % updateConnectedBranches() method.
            if all(this.abIf)
                sLeftBranchName = strrep(oBranch.sName, this.csNames{2}, '');
                sNewSubsystemBranchName = [ sLeftBranchName, 'Interface', csRightBranchName{2} ];
            else
                sNewSubsystemBranchName = '';
            end
            
            % Now, if the left side of this branch is a store, not an
            % interface, gather all the data from connected branches; if it
            % is an interface and is connected, call update method there
            this.updateConnectedBranches(sNewSubsystemBranchName);
            
        end
        
        function disconnect(this)
            % Can only deconnect the connection to an interface branch on
            % the PARENT system (= supsystem).
            
            if ~this.abIf(2)
                this.throw('connectTo', 'Right side of this branch is not an interface, can''t connect to anyone!');
            
            elseif isempty(this.coBranches{2})
                this.throw('connectTo', 'No branch connected on right side!');
                
            end
            
            
            % Disconnect here
            oOldBranch         = this.coBranches{2};
            this.coBranches{2} = [];
            
            % Call disconnect on the branch - if it fails, need to
            % reset the coBranches
            try
                this.hSetDisconnected();
                
            catch oErr
                this.coBranches{2} = oOldBranch;
                
                rethrow(oErr);
            end
            
            % Remove function handles
            this.hGetBranchData   = [];
            this.hSetDisconnected = [];
            
            
            % Remove flow connection of if flow
            this.hRemoveIfProc();
            
            
            % If left side is NOT an interface (i.e. store), remove the
            % stored references on flows, procs, func handles
            if ~this.abIf(1)
                % Index of "out of system" entries
                iF = this.iIfFlow + 1;
                
                this.aoFlows    (iF:end) = [];
                %this.chSetFRs   (iF:end) = [];
                % One flow proc less than flows
                this.aoFlowProcs((iF - 1):end) = [];
                
                % Phase shortcut, also remove
                %this.coPhases{2} = [];
                this.coExmes{2} = [];
                
                this.iFlows     = length(this.aoFlows);
                this.iFlowProcs = length(this.aoFlowProcs);
            end
        end
        
        
        
        
        
        
        function setOutdated(this)
            % Can be used by phases or conductors processors to request recalc-
            % ulation of the flow rate, e.g. after some internal parameters
            % changed.
            
            % Only trigger if not yet set
            %CHECK inactivated here --> solvers and other "clients" should
            %      check themselves!
            if ~this.bOutdated
                this.bOutdated = true;

                % Trigger outdated so e.g. the branch solver can register a
                % postTick callback on the timer to recalc flow rate.
                this.trigger('outdated');
            end
        end
        
        
        function setHeatFlow = registerHandlerHeatFlow(this, oHandler)
            % Only one handler can be registered
            %   and gets a fct handle to the internal setHeatFlow method.
            %   One solver obj per branch, atm no possibility for de-
            %   connect that one.
            %TODO Later, either check if solver obj is
            %     deleted and if yes, allow new one; or some sealed methods
            %     and private attrs on the basic branch solver class, and
            %     on setFRhandler, the branch solver provides fct callback
            %     to release the solver -> deletes the stored fct handle to
            %     the setHeatFlow method of the branch. The branch calls
            %     this fct before setting a new solver.
            
            if ~isempty(this.oHandler)
                this.throw('registerHandlerFR', 'Can only set one handler!');
            end
            
            this.oHandler = oHandler;
            
            setHeatFlow   = @this.setHeatFlow;
            %setHeatFlow   = @(varargin) this.setHeatFlow(varargin{:});
        end
        
    end
    
    methods (Access = protected)
        
        function setHeatFlow(this, fHeatFlow, afTemperatures)
            
            if this.abIf(1), this.throw('setHeatFlow', 'Left side is interface, can''t set flowrate on this branch object'); end
            
            
            % Connected capacities have to do a temperature update before we
            % set the new heat flow - so the thermal energy for the LAST
            % time step, with the old flow, is actually moved from tank to
            % tank.
            for iE = sif(this.fHeatFlow >= 0, 1:2, 2:-1:1)
                this.coExmes{iE}.oCapacity.updateTemperature();
            end
            
            this.fHeatFlow = fHeatFlow;
            
            
            this.bOutdated = false;
            
            this.afTemperatures = afTemperatures;
            
            if this.bTriggersetHeatFlowCallbackBound
                this.trigger('setHeatFlow');
            end
        end
        
        
        function updateConnectedBranches(this, sNewBranchName)
            
            if ~this.abIf(2)
                this.throw('updateConnectedBranches', 'Right side not an interface, can''t get data from no branches.');
            end
            
            % If we're "in between" (branches connected on left and right)
            % just call the left branch update method
            if this.abIf(1)
                if ~isempty(this.coBranches{1})
                    this.hUpdateConnectedBranches(sNewBranchName);
                end
                
            else
                % Get set flow rate function callbacks and phase on the
                % right side of the overall branch and write the right side
                % phase to cell.
                [ this.coExmes{2}, coRightSideConductors ] = this.hGetBranchData();
                
                
                % Only do if we got a right phase, i.e. the (maybe several)
                % connected branches connect two stores.
                if ~isempty(this.coExmes{2})
                    
                    % One flow proc less than flows
                    this.coConductors = { this.coConductors{1:(this.iIfConductors)}, coRightSideConductors{:} };
                    
                    this.iConductors = length(this.coConductors);
                    
                    for iConductor = 1:this.iConductors
                        try
                            if ~isempty(this.sCustomName)
                                this.coConductors{iConductor}.updateConnectedMatterBranch(this.oContainer.toBranches.(this.sCustomName));
                            else
                                this.coConductors{iConductor}.updateConnectedMatterBranch(this.oContainer.toBranches.(this.sName));
                            end
                        catch
                            % well have to see if the non fluidic
                            % conductors require something as well
                        end
                    end

                end
                
                % If the current method was called from a pass-through
                % branch, there will be a new Name for this branch. If not,
                % then the 'sNewBranchName' variable is empty.
                if ~(strcmp(sNewBranchName,''))
                    %sOldName = this.sName;
                    this.sName = sNewBranchName;
                    %this.oContainer.updateBranchNames(this, sOldName);                 
                end
            end
        end
        
        function setDisconnected(this)
            % Remove connected left (subsystem) branch
            
            if ~this.abIf(1)
                this.throw('setDisconnected', 'Left side not an interface');
                
            elseif isempty(this.coBranches{1})
                this.throw('setDisconnected', 'Left side not connected to branch');
            
            elseif this.coBranches{1}.coBranches{2} == this
                this.throw('setDisconnected', 'Left side branch still connected to this branch');
            
            end
            
            
            this.coBranches{1}            = [];
            this.hUpdateConnectedBranches = [];
        end
        
        function [ oRightPhase, coConductors ] = getBranchData(this)
            % if coBranch{2} set, pass through. add own callbacks to cell,
            % leave phase untouched
            
            if ~this.abIf(1) || isempty(this.coBranches{1})
                this.throw('getBranchData', 'Left side no interface / not connected');
            end
            
            % Branch set on the right
            if ~isempty(this.coBranches{2})
                [ oRightPhase, coConductors ] = this.hGetBranchData();
                
                % No branch set on the right side, but got an interface on that
                % side, so return empty for the right phase!
            else
                if this.abIf(2)
                    oRightPhase = [];
                    
                else
                    oRightPhase = this.coExmes{2};
                end
                
                coConductors = this.coConductors;
                
            end
        end
        
        function [ hGetBranchData, hSetDisconnected ] = setConnected(this, oSubSysBranch, hUpdateConnectedBranches)
            if ~this.abIf(1)
                this.throw('setConnected', 'Left side of this branch is not an interface!');
            
            elseif ~isempty(this.coBranches{1})
                this.throw('setConnected', 'Branch already connected to subsystem branch!');
                
            elseif ~isa(oSubSysBranch, 'thermal.branch')
                this.throw('setConnected', 'Input object is not a matter.branch!');
                
            elseif oSubSysBranch.coBranches{1} ~= this
                this.throw('setConnected', 'Branch coBranches{1} (left branch) not pointing to this branch!');
                
            end
            
            % Set left branch and update function handle
            this.coBranches{1}            = oSubSysBranch;
            this.hUpdateConnectedBranches = hUpdateConnectedBranches;
            
            % Return handles to get data and disconnect
            hGetBranchData   = @this.getBranchData;
            hSetDisconnected = @this.setDisconnected;
        end
    end
    methods (Sealed = true)
        function seal(this)
            % Seal aoFlows, get FR func handle
            
            if this.bSealed
                this.throw('seal', 'Already sealed');
            end
%             TO DO: implement subsystem interface branches for thermal
%             system
%             for iI = 1:length(this.aoFlows)
%                 % If last flow and right interface, provide true as param,
%                 % which means that the .seal() returns a remove callback
%                 % which allows us to deconnect the flow from the f2f proc
%                 % in the "outer" system (supsystem).
%                 if this.abIf(2) && (this.iIfFlow == iI)
%                     [ this.hSetFlowData, this.hRemoveIfProc ] = this.aoFlows(iI).seal(true);
%                 
%                 % Only need the callback reference once ...
%                 elseif iI == 1
%                     this.hSetFlowData = this.aoFlows(iI).seal(false, this);
%                 else
%                     this.aoFlows(iI).seal(false, this);
%                 end
%             end
            
            for iI = 1:length(this.coConductors)
                this.coConductors{iI}.seal(this);
            end
            
            this.bSealed = true;
        end
    end
end
