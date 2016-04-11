classdef branch < base & event.source
    %BRANCH Describes flow path between two terminals
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Reference to the parent electrical circuit
        % @type object
        oCircuit;
        
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
        
        % @type cell
        % @types object
        coTerminals = { []; [] };
        
        % Connected branches on the left (index 1, branch in subsystem) or
        % the right (index 2, branch in supsystem) side?
        % @type cell
        % @types object
        coBranches = { electrical.branch.empty(1, 0); electrical.branch.empty(1, 0) };
        
        % Flows belonging to this branch
        % @type array
        % @types object
        aoFlows = electrical.flow.empty();
        
        % Array with f2f processors in between the flows
        % @type array
        % @types object
        aoComponents = [];
        
        % Number of flows / components
        %TODO make transient!
        iFlows = 0;
        iComponents = 0;
        
        % Overall branch resistance in Ohm.
        fResistance = 0;
        
        % Current electrical current on branch
        % @type float
        fCurrent = 0;
        
        % Last couple of currents - used to test if below rounding prec
        afCurrents = ones(1, 10);
        
        bSealed = false;
        
        % Does the branch need an update of e.g. a current solver? Can be
        % set e.g. through a component that changed some internal state.
        bOutdated = false;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Reference to the timer
        % @type object
        oTimer;
        
        % Current handler - only one can be set!
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
        function this = branch(oCircuit, sLeft, csComponents, sRight, sCustomName)
            % Can be called with either stores/ports or interface names
            % (all combinations possible). Connections are always done from
            % subsystem to system.
            %
            %TODO
            %   - does store.getPort have a throw if port not found? Else
            %     throw here.
            
            % Reference to the electrical.circuit and some shorthand refs.
            this.oCircuit = oCircuit;
            this.oTimer   = oCircuit.oTimer;
            
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
                if ~isempty(this.oCircuit.aoBranches) && any(strcmp(subsref([ this.oCircuit.aoBranches.csNames ], struct('type', '()', 'subs', {{ 1, ':' }})), sLeft))
                    this.throw('branch', 'An interface called ''%s'' already exists in ''%s''! Please choose a different name.', sLeft, this.oCircuit.sName);
                end
  
            else
                % Create first flow
                oFlow = electrical.flow(this);
                
                % Add flow to index
                this.aoFlows(end + 1) = oFlow;
                
                % Split to store or node name and terminal name
                [ sStoreOrNode, sTerminal ] = strtok(sLeft, '.');
                
                % Get store name from parent
                if isfield(this.oCircuit.toStores, sStoreOrNode)
                    sType = 'store';
                elseif isfield(this.oCircuit.toNodes,  sStoreOrNode)
                    sType = 'node';
                else
                    this.throw('branch', 'Can''t find provided store or node %s on parent circuit', sStoreOrNode);
                end;
                
                if strcmp(sType, 'store')
                    oTerminal = this.oCircuit.toStores.(sStoreOrNode).getTerminal(sTerminal(2:end));
                elseif strcmp(sType, 'node')
                    oTerminal = this.oCircuit.toNodes.(sStoreOrNode).getTerminal(sTerminal(2:end));
                end
                
                % ... and add flow
                oTerminal.addFlow(oFlow);
                
                this.coTerminals{1} = oTerminal;
            end
            
            
            
            
            %%%% CREATE FLOWS FOR COMPONENTS
            
            % Loop f2f procs
            for iI = 1:length(csComponents)
                sComponent = csComponents{iI};
                
                if ~isfield(this.oCircuit.toComponents, sComponent)
                    this.throw('electrical.branch', 'Component %s not found on circuit this branch belongs to!', sComponent);
                end
                
                
                % Interface flow - FIRST proc - NO FLOW! That will be done when
                % the branch is actually connected to another one (to be
                % more exact, another branch connects to this here).
                if ~this.abIf(1) || (iI ~= 1)
                    % Connect to previous flow (the 'left' port of the proc
                    % goes to the 'out' port of the previous flow)
                    this.oCircuit.toComponents.(sComponent).addFlow(oFlow);
                end
                
                % Create flow
                oFlow = electrical.flow(this);
                this.aoFlows(end + 1) = oFlow;
                
                % Connect the new flow - 'right' of the component to 'in' of flow
                % Because of the possibility that the component is not connected
                % to an in flow (if branch - in flow not yet known), we
                % explicitly provide the port to connect the flow to
                
                oComponent = this.oCircuit.toComponents.(sComponent).addFlow(oFlow, 'Right');
                
                if isempty(this.aoComponents)
                    this.aoComponents = oComponent;
                else
                    this.aoComponents(end + 1) = oComponent;
                end
                
            end
            
            
            
            %%%% HANDLE RIGHT SIDE
            
            
            
            % Interface on right side?
            if isempty(strfind(sRight, '.'))
                
                this.abIf(2) = true;
                this.iIfFlow = length(this.aoFlows);
                
                % Checking if the interface name is already present in this
                % system. Only do this if there any branches at all, of course. 
                if ~isempty(this.oCircuit.aoBranches) && any(strcmp(subsref([ this.oCircuit.aoBranches.csNames ], struct('type', '()', 'subs', {{ 2, ':' }})), sRight))
                    this.throw('branch', 'An interface called ''%s'' already exists in ''%s''! Please choose a different name.', sRight, this.oCircuit.sName);
                end
                
            else
                % Split to store name / port name
                [ sStoreOrNode, sTerminal ] = strtok(sRight, '.');
                
                
                % Get store name from parent
                if isfield(this.oCircuit.toStores, sStoreOrNode)
                    sType = 'store';
                elseif isfield(this.oCircuit.toNodes,  sStoreOrNode)
                    sType = 'node';
                else
                    this.throw('branch', 'Can''t find provided store or node ''%s'' on parent circuit', sStoreOrNode);
                end;
                
                if strcmp(sType, 'store')
                    oTerminal = this.oCircuit.toStores.(sStoreOrNode).getTerminal(sTerminal(2:end));
                elseif strcmp(sType, 'node')
                    oTerminal = this.oCircuit.toNodes.(sStoreOrNode).getTerminal(sTerminal(2:end));
                end
                
                % ... and add flow if not empty, could be if on the left,
                % no procs --> no oFlow, the IF flow from the subsystem
                % will connect to this terminal directly.
                if ~isempty(oFlow)
                    oTerminal.addFlow(oFlow);
                end
                
                this.coTerminals{2} = oTerminal;
                
            end
            
            % Adding the branch to our electrical.container
            this.oCircuit.addBranch(this);
            
            this.iFlows      = length(this.aoFlows);
            this.iComponents = length(this.aoComponents);
            
            this.calculateResistance();
            
            
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
                subsref([ this.oCircuit.aoBranches.csNames ], struct('type', '()', 'subs', {{ 1, ':' }})), ...
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
            
            this.coBranches{2} = this.oCircuit.aoBranches(iBranch);
            
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
            
            % Connect the interface flow here to the first f2f proc in the
            % newly connected branch - but first check if it has flow
            % procs, if not check for right exme!
            if this.coBranches{2}.iFlowProcs == 0
                % RIGHT one - can't have a left exme!
                oProc = this.coBranches{2}.coExmes{2};
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
            
            % Now we set the new name for this branch, inserting the word
            % 'Interface' in the middle, so when looking at the name, we
            % know that this is a subsystem to supersystem branch.
            this.sName = [ csLeftBranchName{1}, '___Interface___', csRightBranchName{2} ];
            
            % Now we call the updateBranchNames() method on our container,
            % so the updated branch names are also visible there. 
            this.oCircuit.updateBranchNames(this, sOldName);
            
            % If this is a pass-through branch, this branch will be deleted
            % once the full branch is completely assembled. So we also have
            % to rename the subsystem branch that we connected earlier.
            % Here we create the name that is then passed on via the
            % updateConnectedBranches() method.
            if all(this.abIf)
                sLeftBranchName = strrep(oBranch.sName, this.csNames{2}, '');
                sNewSubsystemBranchName = [ sLeftBranchName, 'Interface', sRightBranchName ];
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
            if tools.round.prec(sum(this.afFlowRates), this.oCircuit.oTimer.iPrecision) == 0
                fFlowRate = 0;
                
                afPressure = zeros(1,this.iFlowProcs);
                
            elseif this.fFlowRate == 0 %&& false
                % If flow rate is already zero, more strict rounding! Don't
                % re-set a flow rate until its larger then the precision!
                if tools.round.prec(fFlowRate, this.oCircuit.oTimer.iPrecision) == 0
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
                afPressure = ones(1, this.iFlowProcs) * fPressureDiff / this.iFlowProcs;
                
                % Note: no matter the flow direction, positive values on
                % afPRessure always denote a pressure DROP
            end
            
            
            
            % Update data in flows
            this.hSetFlowData(this.aoFlows, this.getInEXME(), fFlowRate, afPressure);
            
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
            
            % Seal the components and calculate the overall branch
            % resistance
            for iI = 1:length(this.aoComponents)
                this.aoComponents(iI).seal(this);
            end
            
            this.bSealed = true;
        end
        
        function calculateResistance(this)
            
            if this.iComponents > 0
                for iI = 1:length(this.aoComponents)
                    if isa(this.aoComponents(iI), 'electrical.components.resistor')
                        this.fResistance = this.fResistance + this.aoComponents(iI).fResistance;
                    end
                end
            else
                this.fResistance = 0;
            end
        end
    end
    
end
