classdef branch < base & event.source
    %BRANCH Describes flow path between two exme processors
    %   The positive flow direction is defined as 'from left to right', the
    %   left side being the exme that is given as the second input 
    %   parameter and the right side being the exme that is given as the 
    %   fourth input parameter. 
    %   In between the exmes there can be any number of flow to flow 
    %   processors that influence the behaviour of the flow between the two 
    %   exams, either through pressure or temperature changes.
    %
    %   Inputs are the parent store (oContainer), the left exme (sLeft), a 
    %   cell array of f2f processors (csProcs) and the right exme (sRight). 
    %   The exams are given as a string in the following format: 
    %   <store name>.<exme Name>
    %   If one of the ends of the branch is an interface to other system 
    %   levels, the string can be anything as long as it doesn?t contain a 
    %   period character('.'). If the interface is to a higher system
    %   level, it has to be given instead of the right exme. If the
    %   interface is to a lower system level, it has to be given instead of
    %   the left exme.
    %
    %   The constructor recognises if this is an interface branch or not 
    %   and accordingly creates the branch object and the matter.flow 
    %   objects between the f2f processors and exme processors. 
    %
    %   TODO
    %   - set flow rate and also partial ratios? Or do via normal .update
    %     command in solver, which is executed properly in direction of the
    %     flow rate? Call .update on FLOWS, with partial mass (or they get
    %     the partial mass from the flow before them?
    %     --> this.oIn.aoFlows(1) or this.oOut.aoFlows(2), depending on Fr,
    %         if positive, the former, negative, the latter!
    %   - EXME I/F -> special matter.branchEXME < matter.branch, only has 
    %     to change the setConnected / setDisconnected methods; no aoFlows,
    %     chSetFRs etc -> no flow in that branch! only one exme!
    %     -> can add several if branches from subsystems there!
    %     => JUST THIS CLASS, check if csProcs empty in constructor and
    %        right side actually a store, AND if port is called 'default',
    %        then allow for several branches to dock on the left side; no
    %        setFRs returned (automatically, empty), return right phase
    %        completely normally as always.
    
    properties (SetAccess = protected, GetAccess = public)
        % Reference to the parent matter container
        % @type object
        oContainer;
        
        % Created from the store/interface names provided to the
        % createBranch method on matter.container (store1_port1__ifName, or
        % store1_port1__otherStore_somePort)
        % @type string
        sName;
        
        sCustomName;
        
        % Names for left/right (cell with 1/2, can be accessed like
        % [ aoBranches.csNames ] --> cell with names, two rows, n cols
        % @type cell
        % @types string
        csNames = { ''; '' };
        
        % Interfaces left/right?
        % @type array
        % @types int
        abIf = [ false; false ];
        
        % When branch fully connected, contains references to the EXMEs at
        % the end of the branch (also if several branches coupled, will be
        % automatically set for branch on the left side
        %coPhases = { matter.phase.empty(1, 0); matter.phase.empty(1, 0) };
        %coPhases = { []; [] };
        % @type cell
        % @types object
        coExmes = { []; [] };
        
        % Connected branches on the left (index 1, branch in subsystem) or
        % the right (index 2, branch in supsystem) side?
        % @type cell
        % @types object
        coBranches = { matter.branch.empty(1, 0); matter.branch.empty(1, 0) };
        
        % Flows belonging to this branch
        % @type array
        % @types object
        aoFlows = matter.flow.empty();
        
        % Array with f2f processors in between the flows
        % @type array
        % @types object
        aoFlowProcs = matter.procs.f2f.empty();
        
        % Amount of flows / procs
        %TODO make transient!
        iFlows = 0;
        iFlowProcs = 0;
        
        % Current flow rate on branch
        % @type float
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
        % @type object
        oMT;
        
        % Reference to the timer
        % @type object
        oTimer;
        
        % Flow rate handler - only one can be set!
        oHandler;
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
        function this = branch(oContainer, sLeft, csProcs, sRight, sCustomName)
            % Can be called with either stores/ports or interface names
            % (all combinations possible). Connections are always done from
            % subsystem to system.
            %
            %TODO
            %   - does store.getPort have a throw if port not found? Else
            %     throw here.
            
            % Reference to the matter.container and some shorthand refs.
            this.oContainer = oContainer;
            this.oMT        = oContainer.oRoot.oMT;
            this.oTimer     = oContainer.oRoot.oTimer;
            
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
            
            if nargin == 5
                this.sCustomName = sCustomName;
            end
            
            oFlow = [];
            
            %%%% HANDLE LEFT SIDE
            
            
            % Interface on left side?
            if isempty(strfind(sLeft, '.'))
                this.abIf(1) = true;
                
                % Checking if the interface name is already present in this
                % system. Only do this if there any branches at all, of course. 
                if ~isempty(this.oContainer.aoBranches) && any(strcmp(subsref([ this.oContainer.aoBranches.csNames ], struct('type', '()', 'subs', {{ 1, ':' }})), sLeft))
                    this.throw('branch', 'An interface called ''%s'' already exists in ''%s''! Please choose a different name.', sLeft, this.oContainer.sName);
                end
  
            else
                % Create first flow, get matter table from oData (see @sys)
                oFlow = matter.flow(this);
                
                % Add flow to index
                this.aoFlows(end + 1) = oFlow;
                
                % Split to store name / port name
                [ sStore, sPort ] = strtok(sLeft, '.');
                
                
                % Get store name from parent
                if ~isfield(this.oContainer.toStores, sStore), this.throw('branch', 'Can''t find provided store %s on parent system', sStore); end;
                
                % Get EXME port/proc ...
                oPort = this.oContainer.toStores.(sStore).getPort(sPort(2:end));
                
                if isa(oPort, 'matter.procs.exmes.absorber')
                    this.throw('branch','You cannot connect an absorber exme (%s->%s->%s->%s) to a matter branch (%s). In can only connect to a P2P processor. ',...
                               oPort.oPhase.oStore.oContainer.sName, oPort.oPhase.oStore.sName, oPort.oPhase.sName, oPort.sName, this.sName);
                end
                
                % ... and add flow
                oPort.addFlow(oFlow);
                
                % Add as a normal proc
                %this.aoFlowProcs(end + 1) = oPort;
                
                % Get phase from flow and add to index
                %this.coPhases{1} = oPort.oPhase;
                this.coExmes{1} = oPort;
            end
            
            
            
            
            %%%% CREATE FLOWS FOR PROCS
            
            % Loop f2f procs
            for iI = 1:length(csProcs)
                sProc = csProcs{iI};
                
                if ~isfield(this.oContainer.toProcsF2F, sProc)
                    this.throw('branch', 'F2F proc %s not found on system this branch belongs to!', sProc);
                end
                
                
                % IF flow - FIRST proc - NO FLOW! That will be done when
                % the branch is actually connected to another one (to be
                % more exact, another branch connects to this here).
                if ~this.abIf(1) || (iI ~= 1)
                    % Connect to previous flow (the 'left' port of the proc
                    % goes to the 'out' port of the previous flow)
                    this.oContainer.toProcsF2F.(sProc).addFlow(oFlow);
                end
                
                % Create flow
                oFlow = matter.flow(this);
                this.aoFlows(end + 1) = oFlow;
                
                % Connect the new flow - 'right' of proc to 'in' of flow
                % Because of the possibility that the proc is not connected
                % to an in flow (if branch - in flow not yet known), we
                % explicitly provide the port to connect the flow to
                this.aoFlowProcs(end + 1) = this.oContainer.toProcsF2F.(sProc).addFlow(oFlow, 2);
            end
            
            
            
            %%%% HANDLE RIGHT SIDE
            
            
            
            % Interface on right side?
            if isempty(strfind(sRight, '.'))
                
                this.abIf(2) = true;
                this.iIfFlow = length(this.aoFlows);
                
                % Checking if the interface name is already present in this
                % system. Only do this if there any branches at all, of course. 
                if ~isempty(this.oContainer.aoBranches) && any(strcmp(subsref([ this.oContainer.aoBranches.csNames ], struct('type', '()', 'subs', {{ 2, ':' }})), sRight))
                    this.throw('branch', 'An interface called ''%s'' already exists in ''%s''! Please choose a different name.', sRight, this.oContainer.sName);
                end
                
            else
                % Split to store name / port name
                [ sStore, sPort ] = strtok(sRight, '.');
                
                % Get store name from container
                if ~isfield(this.oContainer.toStores, sStore), this.throw('branch', 'Can''t find provided store %s on parent system', sStore); end;
                
                % Get Port ...
                oPort = this.oContainer.toStores.(sStore).getPort(sPort(2:end));
                
                % ... and add flow IF not empty, could be if on the left,
                % no procs --> no oFlow, the IF flow from the subsystem
                % will connect to this EXME directly.
                %TODO still problem if no proc, and left IF to right store.
                %     That would basically be a exmeIFport to subsystems,
                %     so implement that (several subs can dock), see above
                if ~isempty(oFlow)
                    oPort.addFlow(oFlow);
                end
                
                % Get phase from flow and add to index
                this.coExmes{2} = oPort;
            end
            
            % Adding the branch to our matter.container
            this.oContainer.addBranch(this);
            
            this.iFlows     = length(this.aoFlows);
            this.iFlowProcs = length(this.aoFlowProcs);
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
                    % processors, we can connect directly to the exme on
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
                this.coExmes{iE}.oPhase.massupdate();
            end
            
            % Only trigger if not yet set
            %CHECK inactivated here --> solvers and otehr "clients" should
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
            %TODO Later, either check if solver obj is
            %     deleted and if yes, allow new one; or some sealed methods
            %     and private attrs on the basic branch solver class, and
            %     on setFRhandler, the branch solver provides fct callback
            %     to release the solver -> deletes the stored fct handle to
            %     the setFlowRate method of the branch. The branch calls
            %     this fct before setting a new solver.
            
            if ~isempty(this.oHandler)
                this.throw('registerHandlerFR', 'Can only set one handler!');
            end
            
            this.oHandler = oHandler;
            
            setFlowRate   = @this.setFlowRate;
            %setFlowRate   = @(varargin) this.setFlowRate(varargin{:});
        end
        
    
        function oExme = getInEXME(this)

            if this.fFlowRate == 0
                % We have no flow rate, so we use the properties of the
                % phase that contains more mass than the other! This 
                % ensures that the matter properties don't become zero if
                % the coExmes{1} phase is empty.
                
                %CHECK: we use getPortProperties() to get the pressure (gas
                %       and liquid) or some equivalent (soldids ...?)
                %       instead of mass - see e.g. const_press_exme!
                %aoPhases   = [ this.coExmes{1}.oPhase, this.coExmes{2}.oPhase ];
                %iWhichExme = sif(aoPhases(1).fMass >= aoPhases(2).fMass, 1, 2);
                
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
                %iWhichExme = sif(this.fFlowRate < 0, 2, 1);
                iWhichExme = (this.fFlowRate < 0) + 1; % Faster?
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
        
        function setFlowRate(this, fFlowRate, afPressure)
            % Set flowrate for all flow objects
            %
            %NOTE/CHECK: afPressure is pressure DROPS, not total pressures!
            
            if this.abIf(1), this.throw('setFlowRate', 'Left side is interface, can''t set flowrate on this branch object'); end;
            
            
            
            % Connected phases have to do a massupdate before we set the
            % new flow rate - so the mass for the LAST time step, with the
            % old flow rate, is actually moved from tank to tank.
            for iE = sif(this.fFlowRate >= 0, 1:2, 2:-1:1)
                this.coExmes{iE}.oPhase.massupdate();
            end
            
            
            this.afFlowRates = [ this.afFlowRates(2:end) fFlowRate ];
            
            % If sum of the last ten flow rates is < precision, set flow
            % rate to zero
            if tools.round.prec(sum(this.afFlowRates), this.oContainer.oTimer.iPrecision) == 0
                fFlowRate = 0;
                
                afPressure = zeros(1,this.iFlowProcs);
                
            elseif this.fFlowRate == 0 %&& false
                % If flow rate is already zero, more strict rounding! Don't
                % re-set a flow rate until its larger then the precision!
                if tools.round.prec(fFlowRate, this.oContainer.oTimer.iPrecision) == 0
                    fFlowRate = 0;
                    
                    afPressure = zeros(1,this.iFlowProcs);
                end
            end
            
            
            
            
            this.fFlowRate = fFlowRate;
            this.bOutdated = false;
            
            
            % No pressure? Distribute equally.
            if nargin < 3 || isempty(afPressure)
                fPressureDiff = (this.coExmes{1}.getPortProperties() - this.coExmes{2}.getPortProperties());
                
                % Each flow proc produces the same pressure drop, the sum
                % being the actual pressure difference.
                %CHECK need the abs() of the pressure diff because need to
                %      make sure pressure drops are positive?
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
                
                %TODO check ... do 'reseal' or something??
%                 % Since the subsystem branch is already sealed, we have to
%                 % do it manually here for the new members of this sealed
%                 % branch. First the flows...
%                 for iI = 1:this.iFlows
%                     if ~this.aoFlows(iI).bSealed
%                         this.aoFlows(iI).seal(false, this);
%                     end
%                 end
%                 
%                 % Now we seal the new flow processors.
%                 for iI = 1:this.iFlowProcs
%                     if ~this.aoFlowProcs(iI).bSealed
%                         this.aoFlowProcs(iI).seal(this);
%                     end
%                 end
                
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
