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
        coBranches = { thermal.branch.empty(1, 0); thermal.branch.empty(1, 0) };
        
        % boolean value to check if the branch is already set for update
        bOutdated = false;
        
        bSealed = false;
        
        % Solver object responsible for the calculations in this branch
        oHandler;
        
        % boolean to decide if event should be triggered or not
        bTriggersetHeatFlowCallbackBound = false;
        
        % Matter object which solves the matter flow rate of this thermal
        % branch. Can either be a matter.branch or a p2p processor
        oMatterObject;
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
        
        function this = branch(oContainer, xLeft, csProcs, xRight, sCustomName, oMatterObject)
            % The thermal branch uses the same definition as the matter
            % branch, just with thermal object. A matter phase with the
            % respective thermal exme is required as interface on both the
            % left and right side and multiple conductors of the same type
            % (Advective, Conduction/Convective, Radiative) can be defined
            % in csProcs (similar to f2f procs on the matter side)
            %
            % Can be called with either stores/ports or interface names
            % (all combinations possible). Connections are always done from
            % subsystem to system.
            
            % Reference to the matter.container and some shorthand refs.
            this.oContainer    = oContainer;
            this.oMT           = oContainer.oMT;
            this.oTimer        = oContainer.oTimer;
            % Since there are thermal branches which do not have a matter
            % object (e.g. radiative or conductive branches) the matter
            % object is only added in case it is provided as input
            if nargin > 5
                this.oMatterObject = oMatterObject;
            end
            
            %% Handle the left side of the branch
            sLeftSideName = this.handleSide('left', xLeft);
            
            %% Loop through conductor procs
            for iI = 1:length(csProcs)
                sProc = csProcs{iI};
                
                if ~isfield(this.oContainer.toProcsConductor, sProc)
                    this.throw('branch', 'Conductor %s not found on system this branch belongs to!', sProc);
                end
                
                this.coConductors{end + 1} = this.oContainer.toProcsConductor.(sProc);
            end
            
            %% Handle the right side of the branch
            sRightSideName = this.handleSide('right', xRight);
            
            %% Setting the name property for this branch object
            
            % Setting the csNames property
            this.csNames = {sLeftSideName; sRightSideName};
            
            % Creating a temporary name first
            sTempName = [ sLeftSideName, '___', sRightSideName ];
            
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
            
            % Setting the sName property
            this.sName = sTempName;
            
            % If the user provided a custom name, we also set that
            % property.
            if nargin >= 5
                this.sCustomName = sCustomName;
            end
            
            %% Adding the branch to our matter.container
            this.oContainer.addThermalBranch(this);
            
            % Counting the number of conductors in the branch
            this.iConductors = length(this.coConductors);
            
        end
        
        
        function connectTo(this, sInterface)
            % The sInterface parameter has to be the name of a valid
            % interface for subsystems of a branch in the parent system,
            % i.e. on the 'left' side of the branch. 
            % Write the aoFlows from the other branch, and the oPhase/oFlow
            % (end flow) to this branch here, store indices to be able to
            % remove the references later.
            
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
            sTempName = [ csLeftBranchName{1}, '___if___', csRightBranchName{2} ];
            
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
            
            % Setting the sName property
            this.sName = sTempName;
            
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
                % One flow proc less than flows
                this.aoFlowProcs((iF - 1):end) = [];
                
                % Phase shortcut, also remove
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
            
            if ~isempty(this.oHandler)
                this.throw('registerHandlerFR', 'Can only set one handler!');
            end
            
            this.oHandler = oHandler;
            
            setHeatFlow   = @this.setHeatFlow;
        end
        
    end
    
    methods (Access = protected)
        
        function sSideName = handleSide(this, sSide, xInput)
            %HANDLESIDE Does a bunch of stuff related to the left or right
            %side of a branch.
            
            % Setting an index variable depending on which side we are
            % looking at.
            switch sSide
                case 'left'
                    iSideIndex = 1;
                    
                case 'right'
                    iSideIndex = 2;
            end
            
            % The xInput input parameter can have one of three forms: 
            %   - <StoreName>.<ExMeName>
            %   - <InterfaceName>
            %   - phase object handle
            %
            % The following code is there to determine which of the three
            % it is. 
            
            % If xInput is a phase object handle, we need to create an
            % ExMe for that phase. This will be captured in the boolean
            % variable below.
            bCreateExMe = false;
            
            % If xInput is the name of an interface, this boolean variale
            % will be set to true. 
            bInterface  = false;
            
            % Check what type of variable xInput is, it can be either a
            % string or a phase object handle.
            if isa(xInput,'matter.phase')
                % It's a phase object, so we set the boolean to true.
                bCreateExMe = true;
            elseif ~contains(xInput, '.')
                % It's not a phase and the string provided does not contain
                % the '.' character, therfore it must be an interface name.
                bInterface  = true;
            end
            
            if bInterface
                % This side is an interface, so we only need to set the
                % abIf(iSideIndex) entry to true.
                this.abIf(iSideIndex) = true;
                
                % Checking if the interface name is already present in this
                % system. Only do this if there any branches at all, of course.
                if ~isempty(this.oContainer.aoThermalBranches) && any(strcmp(subsref([ this.oContainer.aoThermalBranches.csNames ], struct('type', '()', 'subs', {{ iSideIndex, ':' }})), xInput))
                    this.throw('branch', 'An interface called ''%s'' already exists in ''%s''! Please choose a different name.', xInput, this.oContainer.sName);
                end
                
                % The side name is just the interface name for now
                sSideName = xInput;
                
                % If this is the right side of the branch, we also need to
                % set the iIfFlow property.
                if strcmp(sSide, 'right')
                    this.iIfConductors = length(this.coConductors);
                end
                
            else
                % This side is not an interface, so we are either starting
                % or ending a branch here. 
                
                if bCreateExMe
                    % This side was provided as a phase onbject, so we need
                    % to get the appropriate port from the phase's
                    % associated capacity object. 
                    
                    % To automatically generate the ExMe name
                    if isempty(xInput.oCapacity.toProcsEXME)
                        iNumber = 1;
                    else
                        iNumber = numel(fieldnames(xInput.toProcsEXME)) + 1;
                    end
                    
                    sPortName = [xInput.sName, '_Port_', num2str(iNumber)];
                    oPort = thermal.procs.exme(xInput.oCapacity, sPortName);
                    
                    % The side name is of the format
                    % <StoreName>__<ExMeName>.
                    sSideName = [xInput.oStore.sName, '__', sPortName];
                else
                    % xInput is a string containing the name of a store and
                    % an ExMe.
                    
                    % Split to store name / port name
                    [ sStore, sPort ] = strtok(xInput, '.');
                    
                    % Check if store exists
                    if ~isfield(this.oContainer.toStores, sStore)
                        this.throw('branch', 'Can''t find provided store %s on parent system', sStore); 
                    end
                    
                    % Get a handle to the ExMe 
                    oPort = this.oContainer.toStores.(sStore).getThermalPort(sPort(2:end));
                    
                    % The side name is of the format
                    % <StoreName>__<ExMeName>, so we just need to do some
                    % replacing in the xInput variable.
                    sSideName = strrep(xInput, '.', '__');
                end
                
                % Add port to the coExmes property
                this.coExmes{iSideIndex} = oPort;
                
                % Add the branch to the exmes of this branch
                this.coExmes{iSideIndex}.addBranch(this);
                
            end
        end
        
        function setHeatFlow(this, fHeatFlow, afTemperatures)
            
            if this.abIf(1), this.throw('setHeatFlow', 'Left side is interface, can''t set flowrate on this branch object'); end
            
            
            % Connected capacities have to do a temperature update before we
            % set the new heat flow - so the thermal energy for the LAST
            % time step, with the old flow, is actually moved from tank to
            % tank.
            if this.fHeatFlow >= 0; aiExmes = 1:2; else; aiExmes = 2:-1:1; end
            for iE = aiExmes
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
                    this.coConductors = [ this.coConductors(1:(this.iIfConductors)), coRightSideConductors(:)' ];
                    
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
                    this.sName = sNewBranchName;              
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
            for iI = 1:length(this.coConductors)
                this.coConductors{iI}.seal(this);
            end
            
            this.bSealed = true;
        end
    end
end