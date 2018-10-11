classdef branch < base & event.source
    %BRANCH Describes flow path between two ExMe processors
    %   The positive flow direction is defined as 'from left to right', the
    %   left side being the ExMe that is given via the second input 
    %   parameter and the right side being the ExMe that is given as the 
    %   fourth input parameter. 
    %   In between the ExMes there can be any number of flow to flow 
    %   processors that influence the behaviour of the flow between the two 
    %   exams, either through pressure or temperature changes.
    %
    %   Inputs are the parent store (oContainer), the left ExMe (xLeft), a 
    %   cell array of f2f processors (csProcs) and the right ExMe (xRight). 
    %   The ExMes are given either as a string in the following format: 
    %   <store name>.<ExMe Name>, or implicitly by passing in a phase
    %   object handle as the second or fourth input parameter. 
    %   If one of the ends of the branch is an interface to other system 
    %   levels, the string can be anything as long as it doesn't contain a 
    %   period character('.'). If the interface is to a higher system
    %   level, it has to be given instead of the right ExMe. If the
    %   interface is to a lower system level, it has to be given instead of
    %   the left ExMe.
    %
    %   The constructor recognises if this is an interface branch or not 
    %   and accordingly creates the branch object and the matter.flow 
    %   objects between the f2f processors and exme processors.
    
    properties (SetAccess = protected, GetAccess = public)
        % Reference to the parent matter container
        oContainer;
        
        % Created from the store/interface names provided to the
        % createBranch method on matter.container (store1_port1__ifName, or
        % store1_port1__otherStore_somePort)
        sName;
        
        % Optional property where the user can define a specific name for
        % the branch to easier identify it in the toBranches struct (which
        % uses the custom names, if they are available)
        sCustomName;
        
        % Names for left/right (cell with 1/2, can be accessed like
        % [ aoBranches.csNames ] --> cell with names, two rows, n cols
        csNames = { ''; '' };
        
        % Interfaces left/right?
        abIf = [ false; false ];
        
        % When branch fully connected, contains references to the EXMEs at
        % the end of the branch (also if several branches coupled, will be
        % automatically set for branch on the left side
        %coPhases = { matter.phase.empty(1, 0); matter.phase.empty(1, 0) };
        %coPhases = { []; [] };
        coExmes = { []; [] };
        
        % Connected branches on the left (index 1, branch in subsystem) or
        % the right (index 2, branch in supsystem) side?
        coBranches = { matter.branch.empty(1, 0); matter.branch.empty(1, 0) };
        
        % Flows belonging to this branch
        aoFlows = matter.flow.empty();
        
        % Array with f2f processors in between the flows
        aoFlowProcs = matter.procs.f2f.empty();
        
        % Amount of flows / procs
        iFlows = 0;
        iFlowProcs = 0;
        
        % Current flow rate on branch
        fFlowRate = 0;
        
        % Last couple of flow rates - used to test if below rounding prec
        afFlowRates = ones(1, 10);
        
        bSealed = false;
        
        % Does the branch need an update of e.g. a flow rate solver? Can be
        % set e.g. through a flow proc that changed some internal state.
        bOutdated = false;
        
        % Do we need to trigger the setFlowRate event?
        bTriggerSetFlowRateCallbackBound = false;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Reference to the matter table
        oMT;
        
        % Reference to the timer
        oTimer;
        
        % Flow rate handler - only one can be set!
        oHandler;
        
        % Thermal branch which solves the thermal energy transport of this
        % matter branch
        oThermalBranch;
    end
    
    properties (SetAccess = private, GetAccess = private)
        % Function handle to the protected flow method setData, used to
        % update values within the flow objects array
        hSetFlowData;
        
        % If the RIGHT side of the branch is an interface (i.e. i/f to the
        % parent system), store its index on the aoFlows here to make it
        % possible to remove those connections later!
        iIfFlow;
        
        
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
        function this = branch(oContainer, xLeft, csProcs, xRight, sCustomName)
            % Can be called with either stores/ports, phase object handles
            % or interface names (all combinations possible). Connections
            % are always done from subsystem to system.
            
            % Reference to the matter.container and some shorthand refs.
            this.oContainer = oContainer;
            this.oMT        = oContainer.oRoot.oMT;
            this.oTimer     = oContainer.oRoot.oTimer;
            
            %% Handle the left side of the branch
            sLeftSideName = this.handleSide('left', xLeft);
            
            %% Creating flow objects between the processors
            % Looping through f2f procs
            for iI = 1:length(csProcs)
                sProc = csProcs{iI};
                
                if ~isfield(this.oContainer.toProcsF2F, sProc)
                    this.throw('branch', 'F2F proc %s not found on system this branch belongs to!', sProc);
                end
                
                % Unless this is the first processor in a branch with an
                % interface flow at its left side, we connect the last flow
                % in the aoFlows property to the currently selected
                % processor.
                if ~this.abIf(1) || (iI ~= 1)
                    % Connect to previous flow (the 'left' port of the proc
                    % goes to the 'out' port of the previous flow)
                    this.oContainer.toProcsF2F.(sProc).addFlow(this.aoFlows(end));
                end
                
                % Create flow
                oFlow = matter.flow(this);
                this.aoFlows(end + 1) = oFlow;
                
                % Connect the new flow - 'right' of proc to 'in' of flow
                % Because of the possibility that the proc is not connected
                % to an in flow (interface branch - in flow not yet known),
                % we explicitly provide the port to connect the flow to.
                this.aoFlowProcs(end + 1) = this.oContainer.toProcsF2F.(sProc).addFlow(oFlow, 2);
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
            if nargin == 5
                this.sCustomName = sCustomName;
            end
            
            % Adding the branch to our matter.container
            this.oContainer.addBranch(this);
            
            % Counting the number of flows and processors in this branch
            this.iFlows     = length(this.aoFlows);
            this.iFlowProcs = length(this.aoFlowProcs);
            
            %% Construct asscociated thermal branch
            % To model the mass-bound heat (advective) transfer we need a
            % thermal branch in parallel to the matter branch. The required
            % thermal exmes on the capacities have already been created in
            % conductor for every f2f processor in this branch. 
            if length(csProcs) >= 1
                for iProc = 1:length(csProcs)
                    thermal.procs.conductors.fluidic(this.oContainer, csProcs{iProc}, this);
                end
            else
                % Branches without a f2f can exist (e.g. manual branches)
                % however for the thermal branch we always require at least
                % one conductor
                if ~isempty(this.sCustomName)
                    csProcs{1} = [this.sCustomName, '_Conductor'];
                else
                    csProcs{1} = [this.sName, '_Conductor'];
                end
                thermal.procs.conductors.fluidic(this.oContainer, csProcs{1}, this);
            end
            
            % Now we have everything we need, so we can call the thermal
            % branch constructor. 
            this.oThermalBranch = thermal.branch(this.oContainer, xLeft, csProcs, xRight, this.sCustomName, this);
        end
        
        
        function connectTo(this, sInterface)
            % The sInterface parameter has to be the name of a valid
            % interface for subsystems of a branch in the parent system,
            % i.e. on the 'left' side of the branch. 
            % Write the aoFlows from the other branch, and the oPhase/oFlow
            % (end flow) to this branch here, store indices to be able to
            % remove the references later.
            %
            % Find matching interface branch
            % See container -> connectIF, need to get all left names of
            % branches of parent system, since they depict the interfaces
            % to subsystems
            iBranch = find(strcmp(...
                subsref([ this.oContainer.oParent.aoBranches.csNames ], struct('type', '()', 'subs', {{ 1, ':' }})), ...
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
            
            this.coBranches{2} = this.oContainer.oParent.aoBranches(iBranch);
            
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
            if this.coBranches{2}.iFlowProcs == 0
                % Is the branch we are connecting to a pass-through branch?
                if ~all(this.coBranches{2}.abIf)
                    % Since this non-pass-through branch has no flow
                    % processors, we can connect directly to the ExMe on
                    % the right side of this branch. It can't be on the
                    % left side, of course, since this is where the
                    % interface is!
                    oProc = this.coBranches{2}.coExmes{2};
                else
                    this.throw('Pass-through branches currently require at least one f2f processor. Branch %s has none.', this.coBranches{2}.sName);
                end
            else
                oProc = this.coBranches{2}.aoFlowProcs(1);
            end
            
            oProc.addFlow(this.aoFlows(this.iIfFlow));
            
            % To help with debugging, we now change this branch's sName
            % property to reflect the actual flow path between two ExMes
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
            this.oContainer.updateBranchNames(this, sOldName);
            
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
        
        function [ hGetBranchData, hSetDisconnected ] = setConnected(this, oSubSysBranch, hUpdateConnectedBranches)
            % This function is used to connect two seperate interfaces
            % branches of a parent and child system and create a single
            % branch from them
            if ~this.abIf(1)
                this.throw('setConnected', 'Left side of this branch is not an interface!');
            
            elseif ~isempty(this.coBranches{1})
                this.throw('setConnected', 'Branch already connected to subsystem branch!');
                
            elseif ~isa(oSubSysBranch, 'matter.branch')
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
            % Can be used by phases or f2f processors to request recalc-
            % ulation of the flow rate, e.g. after some internal parameters
            % changed (closing a valve).
            
            for iE = sif(this.fFlowRate >= 0, 1:2, 2:-1:1)
                this.coExmes{iE}.oPhase.hBindPostTickMassUpdate();
            end
            
            % If the flowrate changed, the thermal branch also has to be
            % recalculated
            this.oThermalBranch.setOutdated();
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
        
        
        function setFlowRate = registerHandlerFR(this, oHandler)
            % Only one handler can be registered
            %   and gets a fct handle to the internal setFlowRate method.
            %   One solver obj per branch, atm no possibility for de-
            %   connect that one.
            
            if ~isempty(this.oHandler)
                this.throw('registerHandlerFR', 'Can only set one handler!');
            end
            
            this.oHandler = oHandler;
            
            setFlowRate   = @this.setFlowRate;
        end
        
    
        function oExme = getInEXME(this)

            if this.fFlowRate == 0
                % We have no flow rate, so we use the properties of the
                % phase that contains more mass than the other! This 
                % ensures that the matter properties don't become zero if
                % the coExmes{1} phase is empty.
                
                afPressure = [ this.coExmes{1}.getPortProperties(), this.coExmes{2}.getPortProperties() ];
                iWhichExme = sif(afPressure(1) >= afPressure(2), 1, 2);
                
                for iI = 1:this.iFlowProcs
                    if isa(this.aoFlowProcs(iI), 'components.valve') && ~this.aoFlowProcs(iI).bValveOpen
                        oExme = [];
                        return;
                    end
                    
                    if isa(this.aoFlowProcs(iI), 'components.fan')
                        iWhichExme = sif(this.aoFlowProcs(iI).iBlowDirection == 1, 1, 2);
                    end
                end
            else
                iWhichExme = (this.fFlowRate < 0) + 1;
            end

            oExme = this.coExmes{iWhichExme};

        end
        
        
        function update(~)
            %TODO just get the matter properties from the inflowing EXME
            %     and set (arPartialMass, Molar Mass, Heat Capacity)?
        end
        
        
        % Catch 'bind' calls, so we can set a specific boolean property to
        % true so the .trigger() method will only be called if there are
        % callbacks registered.
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % Only do for set
            if strcmp(sType, 'setFlowRate')
                this.bTriggerSetFlowRateCallbackBound = true;
            end
        end
    end
    
    
    % Methods provided to a connected subsystem branch
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
                if ~isempty(this.oContainer.aoBranches) && any(strcmp(subsref([ this.oContainer.aoBranches.csNames ], struct('type', '()', 'subs', {{ iSideIndex, ':' }})), xInput))
                    this.throw('branch', 'An interface called ''%s'' already exists in ''%s''! Please choose a different name.', xInput, this.oContainer.sName);
                end
                
                % The side name is just the interface name for now
                sSideName = xInput;
                
                % If this is the right side of the branch, we also need to
                % set the iIfFlow property.
                if strcmp(sSide, 'right')
                    this.iIfFlow = length(this.aoFlows);
                end
                
            else
                % This side is not an interface, so we are either starting
                % or ending a branch here. 
                
                if bCreateExMe
                    % This side was provided as a phase onbject, so we need
                    % to create an ExMe there first.
                    
                    % To automatically generate the ExMe name
                    if isempty(xInput.toProcsEXME)
                        iNumber = 1;
                    else
                        iNumber = numel(fieldnames(xInput.toProcsEXME)) + 1;
                    end
                    
                    sPortName = sprintf('Port_%i',iNumber);
                    oPort = matter.procs.exmes.(xInput.sType)(xInput, sPortName);
                    
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
                    oPort = this.oContainer.toStores.(sStore).getPort(sPort(2:end));
                    
                    % The side name is of the format
                    % <StoreName>__<ExMeName>, so we just need to do some
                    % replacing in the xInput variable.
                    sSideName = strrep(xInput, '.', '__');
                    
                    % Since we will be creating a thermal branch to run in
                    % parallel with this matter branch, we need to create a
                    % thermal ExMe that corresponds to this matter ExMe.
                    thermal.procs.exme(oPort.oPhase.oCapacity, sPort(2:end));

                end
                
                % We create branches from left to right. If this is a
                % left side, we need to create the first flow object. If
                % this is a right side, we can just use the last flow
                % object in the aoFlows property. 
                switch sSide
                    case 'left'
                        % Create a flow
                        oFlow = matter.flow(this);
                        
                        % Add flow to index
                        this.aoFlows(end + 1) = oFlow;
                    case 'right'
                        % It may be the case that a branch has no flow
                        % objects if there are no f2f processors and this
                        % branch has an interface on the left side or if it
                        % is a pass-through branch. The latter case will
                        % cause an error later on when the subsystem is
                        % connected. The former case is okay as long as the
                        % solver used on this branch can handle that.
                        if ~isempty(this.aoFlows)
                            oFlow = this.aoFlows(end);
                        else
                            oFlow = [];
                        end
                        
                end
                
                % ... and add flow, if there is one.
                if ~isempty(oFlow)
                    oPort.addFlow(oFlow);
                end
                
                % Add port to the coExmes property
                this.coExmes{iSideIndex} = oPort;
            end
        end
        
        function setFlowRate(this, fFlowRate, afPressure)
            % Set flowrate for all flow objects
            %
            % NOTE: afPressure is pressure DROPS, not total pressures!
            
            if this.abIf(1), this.throw('setFlowRate', 'Left side is interface, can''t set flowrate on this branch object'); end
            
            % Connected phases have to do a massupdate before we set the
            % new flow rate - so the mass for the LAST time step, with the
            % old flow rate, is actually moved from tank to tank.
            for iE = sif(this.fFlowRate >= 0, 1:2, 2:-1:1)
                this.coExmes{iE}.oPhase.hBindPostTickMassUpdate();
            end
            
            this.afFlowRates = [ this.afFlowRates(2:end) fFlowRate ];
            
            % If sum of the last ten flow rates is < precision, set flow
            % rate to zero
            if tools.round.prec(sum(this.afFlowRates), 30) == 0
                fFlowRate = 0;
                
                afPressure = zeros(1,this.iFlowProcs);
                
            end
            
            this.fFlowRate = fFlowRate;
            this.bOutdated = false;
            
            % No pressure? Distribute equally.
            if nargin < 3 || isempty(afPressure)
                fPressureDiff = (this.coExmes{1}.getPortProperties() - this.coExmes{2}.getPortProperties());
                
                % Each flow proc produces the same pressure drop, the sum
                % being the actual pressure difference.
                afPressure = ones(1, this.iFlowProcs) * (fPressureDiff) / this.iFlowProcs;
                
                % Note: no matter the flow direction, positive values on
                % afPRessure always denote a pressure DROP
            end
            
            % Update data in flows
            this.hSetFlowData(this.aoFlows, this.getInEXME(), fFlowRate, afPressure);
            
            if this.bTriggerSetFlowRateCallbackBound
                this.trigger('setFlowRate');
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
                [ this.coExmes{2}, aoRightSideFlows, aoRightSideFlowProcs ] = this.hGetBranchData();
                
                
                % Only do if we got a right phase, i.e. the (maybe several)
                % connected branches connect two stores.
                if ~isempty(this.coExmes{2})
                    % Just select to this.iIfFlow, maytbe chSetFrs was
                    % already extended previously
                    this.aoFlows  = [ this.aoFlows(1:this.iIfFlow) aoRightSideFlows ];
                    
                    % One flow proc less than flows
                    this.aoFlowProcs = [ this.aoFlowProcs(1:(this.iIfFlow - 1)) aoRightSideFlowProcs ];
                    
                    this.iFlows     = length(this.aoFlows);
                    this.iFlowProcs = length(this.aoFlowProcs);

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
        
        function [ oRightPhase, aoFlows, aoFlowProcs ] = getBranchData(this)
            % if coBranch{2} set, pass through. add own callbacks to cell,
            % leave phase untouched
            
            if ~this.abIf(1) || isempty(this.coBranches{1})
                this.throw('getBranchData', 'Left side no interface / not connected');
            end
            
            % Branch set on the right
            if ~isempty(this.coBranches{2})
                [ oRightPhase, aoFlows, aoFlowProcs ] = this.hGetBranchData();
                
                aoFlows  = [ this.aoFlows aoFlows ];
                
                aoFlowProcs = [ this.aoFlowProcs aoFlowProcs ];
                
            % No branch set on the right side, but got an interface on that
            % side, so return empty for the right phase!
            else
                if this.abIf(2)
                    oRightPhase = [];
                
                else
                    oRightPhase = this.coExmes{2};
                end
                
                aoFlows     = this.aoFlows;
                aoFlowProcs = this.aoFlowProcs;
                
            end
        end
    end
    
    
    
    methods (Sealed = true)
        function seal(this)
            % Seal aoFlows, get FR func handle
            
            if this.bSealed
                this.throw('seal', 'Already sealed');
            end
            
            for iI = 1:length(this.aoFlows)
                % If last flow and right interface, provide true as param,
                % which means that the .seal() returns a remove callback
                % which allows us to deconnect the flow from the f2f proc
                % in the "outer" system (supsystem).
                if this.abIf(2) && (this.iIfFlow == iI)
                    [ this.hSetFlowData, this.hRemoveIfProc ] = this.aoFlows(iI).seal(true);
                
                % Only need the callback reference once ...
                elseif iI == 1
                    this.hSetFlowData = this.aoFlows(iI).seal(false, this);
                else
                    this.aoFlows(iI).seal(false, this);
                end
            end
            
            for iI = 1:length(this.aoFlowProcs)
                this.aoFlowProcs(iI).seal(this);
            end
            
            
            this.bSealed = true;
        end
    end
    
end
