classdef branch < base & event.source
    %BRANCH Basic solver branch class
    %   This is the base class for all thermal flow solvers in V-HAB, all
    %   other solver branch classes inherit from this class. 
    
    properties (SetAccess = private, GetAccess = private)
        % a handle to the setHeatFlow function of the thermal.branch object
        % Cannot be accessed from outside a solver to prevent inconsistent
        % setting
        setBranchHeatFlow;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % reference to the thermal.branch object solved by this solver
        oBranch;
        
        % last time at which this solver was updated
        fLastUpdate = -10; % [s]
        
        % maximum allowed time between a recalculation of this solver.
        % Other events can trigger an earlier recalculation (e.g. the
        % matter.branch update also triggers an update of this solver)
        fTimeStep = inf;
        
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % flag to check if this solver is already outdated
        bRegisteredOutdated = false;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Solving mechanism supported by the solver
        sSolverType;
        
        % Cached solving objects (from [procs].toSolver.hydraulic)
        aoSolverProps;
        
        % Reference to the matter table
        % @type object
        oMT;
    end
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Handle to bind an update to the corresponding post tick. Simply
        % use XXX.hBindPostTickUpdate() to register an update. Solvers
        % should ONLY be updated in the post tick!
        hBindPostTickUpdate;
        
        % Flag to decide if this solver needs to be recalculate for every
        % change in the heat flows of the attached capacities (e.g.
        % infinite conduction thermal solver). Flag is called residual
        % because the matter side residual solver was the first solver
        % which required this
        bResidual = false;
        
        % See matter.branch, bTriggerSetFlowRate, for more!
        bTriggerUpdateCallbackBound = false;
        bTriggerRegisterUpdateCallbackBound = false;
    end
    
    
    methods
        function this = branch(oBranch, sSolverType)
            % create a basic thermal solver. Required inputs are:
            % oBranch:  thermal.branch object which is solved by this
            %           solver
            % sSolverType: Type of the solver
            
            % Check if the thermal.branch solved by this solver is
            % connected correctly
            if isempty(oBranch.coExmes{1}) || isempty(oBranch.coExmes{2})
                this.throw('branch:constructor',['The interface branch %s is not properly connected.\n',...
                                     'Please make sure you call connectIF() on the subsystem.'], oBranch.sName);
            end
            
            % set reference objects
            this.oBranch = oBranch;
            this.oMT     = oBranch.oMT;
            
            if nargin >= 3 && ~isempty(sSolverType)
                this.sSolverType = sSolverType;
            end
            
            % Branch allows only one solver to take control, which is
            % checked by registering this handler (aka solver) with the
            % thermal.branch object. If it already has a solver an error is
            % thrown
            this.setBranchHeatFlow = this.oBranch.registerHandler(this);
            
            % bin the setTimeStep method for this solver to the timer,
            % allowing the solver to enforce updated
            this.setTimeStep = this.oBranch.oTimer.bind(@this.executeUpdate, inf, struct(...
                'sMethod', 'executeUpdate', ...
                'sDescription', 'ExecuteUpdate in solver which does updateTemperature and then registers .update in post tick!', ...
                'oSrcObj', this ...
            ));
            
            % If the thermal.branch triggers the 'outdated' event, we need
            % to re-calculate the heat flow by updating this solver!
            this.oBranch.bind('outdated', @this.executeUpdate);
        end
        
        % overwrite the bind function to check for specific calls and then
        % only trigger them in case anything is actually bound to them
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            if strcmp(sType, 'update')
                this.bTriggerUpdateCallbackBound = true;
            
            elseif strcmp(sType, 'register_update')
                this.bTriggerRegisterUpdateCallbackBound = true;
            
            end
        end
    end
    
    methods (Access = private)
        function executeUpdate(this, ~)
            % executeUpdate informs the thermal solver that a update is
            % necessary and also triggers the connected capacities to
            % update their temperatures. This is necessary to ensure
            % consistency in the transferred energy (similar to the mass
            % side, see Wiki for video information on this
            % https://wiki.tum.de/display/vhab/6.+Mass+Balance)
            if ~base.oDebug.bOff, this.out(1, 1, 'executeUpdate', 'Call updateTemperature on both branches, depending on flow rate %f', { this.oBranch.fHeatFlow }); end
            
            for iE = 2
                this.oBranch.coExmes{iE}.oCapacity.registerUpdateTemperature();
            end
            
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        
        function registerUpdate(this, ~)
            % register the update of the solver with the timer in the post
            % tick.
            
            % Check if we are already outdated, if that is the case this
            % was already executed
            if this.bRegisteredOutdated
                return;
            end
            
            % If anything else wants to be informed about this solver
            % beeing outdated, we trigger the corresponding event, also
            % informing about the post tick priority of this solver
            if this.bTriggerRegisterUpdateCallbackBound
                this.trigger('register_update', struct('iPostTickPriority', this.iPostTickPriority));
            end

            if ~base.oDebug.bOff, this.out(1, 1, 'registerUpdate', 'Registering .update method on post tick prio %i for thermal solver for branch %s', { this.iPostTickPriority, this.oBranch.sName }); end
            
            this.bRegisteredOutdated = true;
            this.hBindPostTickUpdate();
        end
        
        function update(this, fHeatFlow, afTemperatures)
            % Inherited class can overload .update method with a specific
            % calculation method for the respective solver. But to set the
            % fHeatFlow property of the thermal.branch correctly this
            % function still needs to be called by using:
            % update@solver.thermal.base.branch(this, fHeatFlow, afTemperatures);
            
            
            if ~base.oDebug.bOff, this.out(1, 1, 'update', 'Setting heat flow %f for branch %s', { fHeatFlow, this.oBranch.sName }); end
            
            % store the time at which this solver was last updated for
            % information
            this.fLastUpdate = this.oBranch.oTimer.fTime;
            
            
            if nargin >= 2
                % If mass in inflowing tank is smaller than the precision
                % of the simulation, set heat flow and delta temperature to
                % zero
                if fHeatFlow >= 0
                    oIn = this.oBranch.coExmes{1}.oCapacity.oPhase;
                else
                    oIn = this.oBranch.coExmes{2}.oCapacity.oPhase;
                end

                if tools.round.prec(oIn.fMass, oIn.oStore.oTimer.iPrecision) == 0
                    fHeatFlow = 0;
                    afTemperatures = zeros(1, this.oBranch.iConductors);
                end
            end
            
            % set the heat flow and the temperatures to the thermal.branch
            this.setBranchHeatFlow(fHeatFlow, afTemperatures);
            
            % now we are no longer outdated
            this.bRegisteredOutdated = false;
            
            % trigger an event to allow other functions/objects to bind to
            % the update of this thermal solver
            if this.bTriggerUpdateCallbackBound
                this.trigger('update');
            end
        end
    end
end