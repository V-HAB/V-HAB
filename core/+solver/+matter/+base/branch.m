classdef branch < base & event.source
%
%
%TODO
%   - fFlowRate protected, not prive, and add setter?
%   - check - setTimeStep means solver .update() method is executed by the
%     timer during the 'normal' update call for e.g. phases etc.
%     If a phase triggers an solver .update, that happens in the post tick
%     loop.
%     Any problems with that? Possible that solver called multiple times at
%     a tick - shouldn't be a problem right?

    properties (SetAccess = private, GetAccess = private)
        %TODO how to serialize function handles? Do differently in the
        %     first place, e.g. with some internal 'passphrase' that is
        %     generated and returned on registerHandlerFR and checked on
        %     setFlowRate?
        setBranchFR;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
    end
    
    properties (SetAccess = private, GetAccess = public)
        oBranch;
        fFlowRate = 0;
        
        fLastUpdate = -10;
        
        
        % Branch to sync to - if that branch is executed/updated, also
        % update here!
        oSyncedSolver;
        bUpdateTrigger = false;
    end
    
    properties (SetAccess = private, GetAccess = protected, Transient = true)
        bRegisteredOutdated = false;
    end
    
    
    methods
        function this = branch(oBranch, fInitialFlowRate)
            this.oBranch = oBranch;
            
            % Branch allows only one solver to take control
            this.setBranchFR = this.oBranch.registerHandlerFR(this);
            
            % Use branches container timer reference to bind for time step
            %CHECK nope, Infinity, right?
            this.setTimeStep = this.oBranch.oContainer.oTimer.bind(@(~) this.update(), inf);
            
            % Initial flow rate?
            if (nargin >= 2) && ~isempty(fInitialFlowRate)
                this.fFlowRate = fInitialFlowRate;
            end
            
            % If the branch triggers the 'outdated' event, need to
            % re-calculate the flow rate!
            this.oBranch.bind('outdated', @this.registerUpdate);
        end
        
        
        function syncToSolver(this, oSolver)
            % 
            %
            %TODO
            % Allow several synced solvers!!
            
            if ~isempty(this.oSyncedSolver)
                this.throw('syncToSolver', 'Cannot set another synced solver');
            end
            
            this.oSyncedSolver = oSolver;
            this.oSyncedSolver.bind('update', @(~) this.syncedUpdateCall());
        end
    end
    
    methods (Access = protected)
        function this = registerUpdate(this, ~)
            %keyboard();
            %disp(['Branch - set Update at ' num2str(this.oBranch.oContainer.oTimer.iTick) ]);
            
            %CHECK1 deactivated - check done by branch itself!
            %if this.bRegisteredOutdated, this.warn('registerUpdate', 'see solver.matter.base.branch method registerUpdated, deactviated check for bRegisteredOutdated, is that ok?'); end;
            
            %if ~this.bRegisteredOutdated
                this.oBranch.oContainer.oTimer.bindPostTick(@this.update);
                this.bRegisteredOutdated = true;
            %end
        end
        
        
        function syncedUpdateCall(this)
            % Prevent loops
            if ~this.bUpdateTrigger
                this.update();
            end
        end
        
        function update(this, fFlowRate, afPressures, afTemps)
            % Inherited class can overload .update and write this.fFlowRate
            % and subsequently CALL THE PARENT METHOD by
            % update@solver.matter.base.branch(this);
            % (??)
            
            %TODO 13
            %   - names of solver packates? matter/basic/...?
            %   - also afPressures, afTemps for setBranchFR?
            %   - some solvers need possibility to preset flows with the
            %       mol mass, ..
            %       => NOT NOW! Solver just uses old values, and has to
            %       make sure that a short time step (0!!) is set when the
            %       flow rate direction changed!!
            %       -> setFlowRate automatically updates all!
            
            this.fLastUpdate = this.oBranch.oContainer.oTimer.fTime;
            
            
            if nargin >= 2
                this.fFlowRate = fFlowRate;
            end
            
            this.bRegisteredOutdated = false;
            
            
            % No temperature vector given? Create zeros - no temp change
            if nargin < 4 || isempty(afTemps)
                afTemps = zeros(1, this.oBranch.iFlowProcs);
            end
            
            % No pressure? Distribute equally.
            if nargin < 3 || isempty(afPressures)
                fPressureDiff = (this.oBranch.coExmes{1}.getPortProperties() - this.oBranch.coExmes{2}.getPortProperties());
                
                % Each flow proc produces the same pressure drop, the sum
                % being the actual pressure difference.
                %NOTE if e.g. 'right' pressure higher then left, pressure
                %     diffs here become negative, as if each component
                %     would be a fan producing a pressure rise. But this is
                %     only to cope with initial states until solver
                %     realizes that matter would actually flow the other
                %     direction.
                afPressures = ones(1, this.oBranch.iFlowProcs) * fPressureDiff / this.oBranch.iFlowProcs;
                
                if this.fFlowRate < 0, afPressures = -1 * afPressures; end;
            end
            
            
            this.setBranchFR(this.fFlowRate, afPressures, afTemps);
            
            this.bUpdateTrigger = true;
            this.trigger('update');
            this.bUpdateTrigger = false;
        end
    end
end