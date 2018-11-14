classdef branch < base.branch
    % Thermal base branch class definition. Here all basic properties and
    % methodes that all thermal branches require are defined
    
    properties (SetAccess = protected)
        
        % The thermal conductivity of the branch
        fConductivity; % [W/K] or [W/K^4] depending on the child class
        
        fHeatFlow = 0;
        
        afTemperatures;
        
        % Object array containing a reference to the conductor objects
        % inside this branch
        coConductors = cell(0,0);
        iConductors;
        
        % Matter object which solves the matter flow rate of this thermal
        % branch. Can either be a matter.branch or a p2p processor
        oMatterObject;
        
        % Do we need to trigger the setHeatFlow event?
        bTriggersetHeatFlowCallbackBound = false;
        
        % If the RIGHT side of the branch is an interface (i.e. i/f to the
        % parent system), store its index on the aoFlows here to make it
        % possible to remove those connections later!
        iIfConductors;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % heat flow handler - only one can be set!
        oHandler;
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
            if nargin < 5
                sCustomName = [];
            end
            this@base.branch(oContainer, xLeft, csProcs, xRight, sCustomName, 'thermal');
            
            % Since there are thermal branches which do not have a matter
            % object (e.g. radiative or conductive branches) the matter
            % object is only added in case it is provided as input
            if nargin > 5
                this.oMatterObject = oMatterObject;
            end
            
            
            
            %% Adding the branch to our matter.container
            this.oContainer.addThermalBranch(this);
            
            % Counting the number of conductors in the branch
            this.iConductors = length(this.coConductors);
            
        end
        
        function createProcs(this, csProcs)
            %% Loop through conductor procs
            for iI = 1:length(csProcs)
                sProc = csProcs{iI};
                
                if ~isfield(this.oContainer.toProcsConductor, sProc)
                    this.throw('branch', 'Conductor %s not found on system this branch belongs to!', sProc);
                end
                
                this.coConductors{end + 1} = this.oContainer.toProcsConductor.(sProc);
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
        
        function setIfLength(this, iLength)
            this.iIfConductors = iLength;
        end
        
        function setConductors(this, coConductors)
            this.coConductors = coConductors;
            this.iConductors = length(this.coConductors);
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
        
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % Only do for set
            if strcmp(sType, 'setHeatFlow')
                this.bTriggersetHeatFlowCallbackBound = true;
            end
        end
        
    end
    
    methods (Access = protected)
        
        function setHeatFlow(this, fHeatFlow, afTemperatures)
            
            if this.abIf(1), this.throw('setHeatFlow', 'Left side is interface, can''t set flowrate on this branch object'); end
            
            
            % Connected capacities have to do a temperature update before we
            % set the new heat flow - so the thermal energy for the LAST
            % time step, with the old flow, is actually moved from tank to
            % tank.
            if this.fHeatFlow >= 0; aiExmes = 1:2; else; aiExmes = 2:-1:1; end
            for iE = aiExmes
                this.coExmes{iE}.oCapacity.registerUpdateTemperature();
            end
            
            this.fHeatFlow = fHeatFlow;
            
            
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
            for iI = 1:length(this.coConductors)
                this.coConductors{iI}.seal(this);
            end
            
            this.bSealed = true;
        end
    end
end