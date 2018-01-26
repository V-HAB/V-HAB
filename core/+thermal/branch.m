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
        coConductors;
        iConductors;
        
        coExmes;
        
        % Connected branches on the left (index 1, branch in subsystem) or
        % the right (index 2, branch in supsystem) side?
        % @type cell
        % @types object
        coBranches = { matter.branch.empty(1, 0); matter.branch.empty(1, 0) };
        
        % boolean value to check if the branch is already set for update
        bOutdated = false;
        
        bSealed = false;
        
        % Solver object responsible for the calculations in this branch
        oHandler;
        
        % boolean to decide if event should be triggered or not
        bTriggersetHeatFlowCallbackBound = false;
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
                this.iIfFlow = length(this.aoFlows);
                
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
            end
            
            % Adding the branch to our matter.container
            this.oContainer.addThermalBranch(this);
            
            this.iConductors = length(this.coConductors);
            
            % Add the branch to the exmes of this branch
            this.coExmes{1}.addBranch(this);
            this.coExmes{2}.addBranch(this);
        end
        
        function setOutdated(this)
            % Can be used by phases or conductors processors to request recalc-
            % ulation of the flow rate, e.g. after some internal parameters
            % changed.
            
            for iE = sif(this.fHeatFlow >= 0, 1:2, 2:-1:1)
                this.coExmes{iE}.oCapacity.updateTemperature();
            end
            
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
            
            
            this.fHeatFlow = fHeatFlow;
            
            % Connected capacities have to do a temperature update before we
            % set the new heat flow - so the thermal energy for the LAST
            % time step, with the old flow, is actually moved from tank to
            % tank.
            for iE = sif(this.fHeatFlow >= 0, 1:2, 2:-1:1)
                this.coExmes{iE}.oCapacity.updateTemperature();
            end
            
            
            this.bOutdated = false;
            
            this.afTemperatures = afTemperatures;
            
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
