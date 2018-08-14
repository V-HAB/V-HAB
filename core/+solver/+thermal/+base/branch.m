classdef branch < base & event.source
    %BRANCH Basic solver branch class
    %   This is the base class for all thermal flow solvers in V-HAB, all
    %   other solver branch classes inherit from this class. 
    %
    properties (SetAccess = private, GetAccess = private)
        %TODO how to serialize function handles? Do differently in the
        %     first place, e.g. with some internal 'passphrase' that is
        %     generated and returned on registerHandlerFR and checked on
        %     setFlowRate?
        setBranchHeatFlow;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
    end
    
    properties (SetAccess = private, GetAccess = public)
        oBranch;
        fHeatFlow = 0;
        
        fLastUpdate = -10;
        
        % Branch to sync to - if that branch is executed/updated, also
        % update here!
        oSyncedSolver;
        bUpdateTrigger = false;
    end
    
    properties (SetAccess = private, GetAccess = protected) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
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
        % Update method is bound to this post tick priority. Some solvers
        % might need another priority to e.g. ensure that first, all other
        % branches update their flow rates.
        iPostTickPriority = -1;
        
        bResidual = false;
        
        % See matter.branch, bTriggerSetFlowRate, for more!
        bTriggerUpdateCallbackBound = false;
        bTriggerRegisterUpdateCallbackBound = false;
    end
    
    
    methods
        function this = branch(oBranch, sSolverType)
            
            if isempty(oBranch.coExmes{1}) || isempty(oBranch.coExmes{2})
                this.throw('branch:constructor',['The interface branch %s is not properly connected.\n',...
                                     'Please make sure you call connectIF() on the subsystem.'], oBranch.sName);
            end
            
            this.oBranch = oBranch;
            this.oMT     = oBranch.oMT;
            
            if nargin >= 3 && ~isempty(sSolverType)
                this.sSolverType = sSolverType;
                
            end
            
            % Branch allows only one solver to take control
            this.setBranchHeatFlow = this.oBranch.registerHandlerHeatFlow(this);
            
            %TODO check - which one?
            %this.setTimeStep = this.oBranch.oTimer.bind(@(~) this.registerUpdate(), inf);
            this.setTimeStep = this.oBranch.oTimer.bind(@this.executeUpdate, inf, struct(...
                'sMethod', 'executeUpdate', ...
                'sDescription', 'ExecuteUpdate in solver which does updateTemperature and then registers .update in post tick!', ...
                'oSrcObj', this ...
            ));
            
            % If the branch triggers the 'outdated' event, need to
            % re-calculate the heat flow!
            %CHECK-160514
            %this.oBranch.bind('outdated', @this.registerUpdate);
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
            if ~base.oLog.bOff, this.out(1, 1, 'executeUpdate', 'Call updateTemperature on both branches, depending on flow rate %f', { this.oBranch.fHeatFlow }); end
            
            for iE = sif(this.oBranch.fHeatFlow >= 0, 1:2, 2:-1:1)
                this.oBranch.coExmes{iE}.oCapacity.updateTemperature();
            end
            
            %CHECK-160514
            %this.update();
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        
        function registerUpdate(this, ~)
            if this.bRegisteredOutdated
                return;
            end
            
            if this.bTriggerRegisterUpdateCallbackBound
                this.trigger('register_update', struct('iPostTickPriority', this.iPostTickPriority));
            end

            if ~base.oLog.bOff, this.out(1, 1, 'registerUpdate', 'Registering .update method on post tick prio %i for solver for branch %s', { this.iPostTickPriority, this.oBranch.sName }); end;
            
            this.bRegisteredOutdated = true;
            this.oBranch.oTimer.bindPostTick(@this.update, this.iPostTickPriority);
        end
        
        
        function syncedUpdateCall(this)
            % Prevent loops
            if ~this.bUpdateTrigger
                this.update();
            end
        end
        
        function update(this, fHeatFlow, afTemperatures)
            % Inherited class can overload .update and write this.fFlowRate
            % and subsequently CALL THE PARENT METHOD by
            % update@solver.matter.base.branch(this);
            
            
            if ~base.oLog.bOff, this.out(1, 1, 'update', 'Setting heat flow %f for branch %s', { fHeatFlow, this.oBranch.sName }); end
            
            this.fLastUpdate = this.oBranch.oTimer.fTime;
            
            if nargin >= 2

                % If mass in inflowing tank is smaller than the precision
                % of the simulation, set flow rate and delta pressures to
                % zero
                oIn = this.oBranch.coExmes{sif(fHeatFlow >= 0, 1, 2)}.oCapacity.oPhase;

                if tools.round.prec(oIn.fMass, oIn.oStore.oTimer.iPrecision) == 0
                    fHeatFlow = 0;
                    afTemperatures = zeros(1, this.oBranch.iConductors);
                end

                this.fHeatFlow = fHeatFlow;

            end
            
            this.bRegisteredOutdated = false;
            
            % No temperatures given? Just make sure we have the variable
            % 'afPressures' set, the parent class knows what to do. Note
            % that this is only allowed if now matter bound mass transfer
            % occurs
            if nargin < 3
                afTemperatures = [];
            end
            
            this.fHeatFlow = fHeatFlow;
            
            this.setBranchHeatFlow(this.fHeatFlow, afTemperatures);
            
            %TODO Add a comment here to tell the user what this is actually
            %good for. I'm assuming this is only here to call a synced
            %solver? 
            this.bUpdateTrigger = true;
            
            if this.bTriggerUpdateCallbackBound
                this.trigger('update');
            end
            
            this.bUpdateTrigger = false;
        end
    end
end
