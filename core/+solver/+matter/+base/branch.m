classdef branch < base & event.source
    %BRANCH Basic solver branch class
    %   This is the base class for all matter flow solvers in V-HAB, all
    %   other solver branch classes inherit from this class. 
    
    properties (SetAccess = private, GetAccess = private)
        % handle from th
        setBranchFR;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Reference to the matter.branch object this solver calculates
        oBranch;
        
        % Current flowrate of the branch, only set during post tick
        % calculation!
        fFlowRate = 0;
        
        % last total time in seconds at which this solver was updated
        fLastUpdate = -10;
    
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Handle bound to the specific solver which can be used to set the
        % flowrate
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
        
        % This is the handle to bind a post tick update for the solver.
        % Note solvers should ONLY be updated in the post tick! Simply use
        % the XXX.hBindPostTickUpdate() to bind and update
        hBindPostTickUpdate;
        % This is the same as above but for the time step calculation of
        % the solver, if one is used
        hBindPostTickTimeStepCalculation;
        
        % See matter.branch, bTriggerSetFlowRate, for more!
        bTriggerUpdateCallbackBound = false;
        bTriggerRegisterUpdateCallbackBound = false;
    end
    
    
    methods
        function this = branch(oBranch, fInitialFlowRate, sSolverType)
            
            if isempty(oBranch.coExmes{1}) || isempty(oBranch.coExmes{2})
                this.throw('branch:constructor',['The interface branch %s is not properly connected.\n',...
                                     'Please make sure you call connectIF() on the subsystem.'], oBranch.sName);
            end
            
            this.oBranch = oBranch;
            this.oMT     = oBranch.oMT;
            
            if nargin >= 3 && ~isempty(sSolverType)
                this.sSolverType = sSolverType;
                
                % Cache the solver objects for quick access later
                this.aoSolverProps = solver.matter.base.type.(this.sSolverType).empty(0, size(this.oBranch.aoFlowProcs, 2));
                
                for iP = 1:length(this.oBranch.aoFlowProcs)
                    if ~isfield(this.oBranch.aoFlowProcs(iP).toSolve, this.sSolverType)
                        this.throw('branch:constructor', 'F2F processor ''%s'' does not support the %s solving method!', this.oBranch.aoFlowProcs(iP).sName, this.sSolverType);
                    end

                    this.aoSolverProps(iP) = this.oBranch.aoFlowProcs(iP).toSolve.(this.sSolverType);
                end
            end
            
            % Branch allows only one solver to take control
            this.setBranchFR = this.oBranch.registerHandler(this);
            
            this.setTimeStep = this.oBranch.oTimer.bind(@this.executeUpdate, inf, struct(...
                'sMethod', 'executeUpdate', ...
                'sDescription', 'ExecuteUpdate in solver which does massupdate and then registers .update in post tick!', ...
                'oSrcObj', this ...
            ));
            
            % Initial flow rate?
            if (nargin >= 2) && ~isempty(fInitialFlowRate)
                this.fFlowRate = fInitialFlowRate;
            end
            
            % If the branch triggers the 'outdated' event, need to
            % re-calculate the flow rate!
            this.oBranch.bind('outdated', @this.executeUpdate);
            
        end
        
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
            if ~base.oDebug.bOff, this.out(1, 1, 'executeUpdate', 'Call massupdate on both branches, depending on flow rate %f', { this.oBranch.fFlowRate }); end
            
            % if the mass branch is outdated it means the flowrate changed,
            % which requires us to update the corresponding thermal branch
            % as well
            this.oBranch.oThermalBranch.setOutdated();
            
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        
        function registerUpdate(this, ~)
            % This functions registers a post tick update for this branch
            % in the timer. The post tick level is specified by the solver
            if this.bRegisteredOutdated
                return;
            end
            
            % performs the massupdate on both sides since we first have to
            % finish transferring mass at the current flowrate in both
            % phases before we can change the flowrate. Otherwise the mass
            % balance would be incorrect
            for iE = 1:2
                this.oBranch.coExmes{iE}.oPhase.registerMassupdate();
            end
            
            % Allows other functions to register an event to this trigger
            % and provides the post tick level for the ones who register
            if this.bTriggerRegisterUpdateCallbackBound
                this.trigger('register_update');
            end

            if ~base.oDebug.bOff, this.out(1, 1, 'registerUpdate', 'Registering update() method on post tick for solver for branch %s', { this.oBranch.sName }); end
            
            this.bRegisteredOutdated = true;
            % this finally binds the update function to the specified post
            % tick level
            this.hBindPostTickUpdate();
        end
        
        function update(this, fFlowRate, afPressures)
            % Inherited class can overload .update and write this.fFlowRate
            % and subsequently CALL THE PARENT METHOD by
            % update@solver.matter.base.branch(this);
            
            if ~base.oDebug.bOff, this.out(1, 1, 'update', 'Setting flow rate %f for branch %s', { fFlowRate, this.oBranch.sName }); end
            
            this.fLastUpdate = this.oBranch.oTimer.fTime;
            
            if nargin >= 2

                % If mass in inflowing tank is smaller than the precision
                % of the simulation, set flow rate and delta pressures to
                % zero
                if fFlowRate >= 0
                    oIn = this.oBranch.coExmes{1}.oPhase;
                else
                    oIn = this.oBranch.coExmes{2}.oPhase;
                end
                
                if ~oIn.bFlow && tools.round.prec(oIn.fMass, oIn.oStore.oTimer.iPrecision) == 0
                    fFlowRate = 0;
                    afPressures = zeros(1, this.oBranch.iFlowProcs);
                end

                this.fFlowRate = fFlowRate;

            end
            
            this.bRegisteredOutdated = false;
            
            % No pressure given? Just make sure we have the variable
            % 'afPressures' set, the parent class knows what to do. In this
            % case it will distribute the pressure drops equally onto all 
            % flows.
            if nargin < 3
                afPressures = [];
            end
            
            this.setBranchFR(this.fFlowRate, afPressures);
            
            if this.bTriggerUpdateCallbackBound
                this.trigger('update');
            end
        end
    end
end
