classdef branch < solver.matter.manual.branch
    % Calculates sum of flow rates of other branches and p2p procs and set
    % remaining flowrate for own branch.
    %
    %TODO
    %   * check if in phase is bSynced, check if added as last solver?
    %
    % please note that the residual solver will not work if you create a
    % loop of several residual solvers!
    
    properties (SetAccess = protected, GetAccess = public)
        % Boolean variable to set if the residual flow rate is calculated
        % using the 'left' or the 'right' phase with respect to the matter
        % branch object. Can be changed by the user using the 
        % setPositiveFlowDirection() method. 
        bPositiveFlowDirection = true;
        
        bMultipleResidualSolvers = false;
        aoAdjacentResidualSolver;
        fResidualFlowRatePrev = 0;
        
        bActive = true;
        
        fAllowedFlowRate = 0;
        
        fLastUpdateTime = -1;
        
        hBindPostTickFindAdajcentResiduals;
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.matter.manual.branch(oBranch);
            
            this.iPostTickPriority = 2;
            
            this.hBindPostTickUpdate      = this.oTimer.registerPostTick(@this.update, 'matter' , 'residual_solver');
            this.hBindPostTickFindAdajcentResiduals      = this.oTimer.registerPostTick(@this.update, 'matter' , 'residual_solver');
            
        end
        
        function setPositiveFlowDirection(this, bPositiveFlowDirection)
            this.bPositiveFlowDirection = bPositiveFlowDirection;
            this.hBindPostTickFindAdajcentResiduals();
            
            % If this command is used all adjacent residual solvers on both
            % sides also have to update their adjacent residual solvers!
             for iExme = 1:2
                oPhase = this.oBranch.coExmes{iExme}.oPhase;

                % Branches and p2p flows - they're also branches!
                for iE = 1:oPhase.iProcsEXME
                    oExme   = oPhase.coProcsEXME{iE};
                    oBranch = oExme.oFlow.oBranch;

                    if oBranch == this.oBranch
                        continue;
                    elseif ~oExme.bFlowIsAProcP2P && isa(oBranch.oHandler, 'solver.matter.residual.branch')
                        
                        oHandler = oBranch.oHandler;
                        oBranch.oTimer.bindPostTick(@oHandler.findAdjacentResidualSolvers, -3);
                    end
                end
             end
        end
        
        function setActive(this, bActive)
            this.bActive = bActive;
            this.setPositiveFlowDirection(this.bPositiveFlowDirection);
        end
        
        
        function setAllowedFlowRate(this, fFlowRate)
            % for positive values, the residual solver will allow a mass
            % increase of the phase for which it is supposed to keep the
            % mass constant (with the flowrate specified here) for negative
            % ones it will allow a mass decrease.
            this.fAllowedFlowRate = fFlowRate;
            this.update();
        end
    end
    
    methods (Access = protected)
        
        function findAdjacentResidualSolvers(this, ~)
            
            this.aoAdjacentResidualSolver = matter.branch.empty;
            % implemented a fix for the residual solver, as for what it
            % does:

            % Assume Residual Solver A is attached to Phase A and B and is
            % supposed to keep the mass of Phase A constant. If then
            % Residual Solver B is attached to Phase B and C and is
            % supposed to keep the mass of Phase B constant then residual
            % solver B is required to update in case that residual solver A
            % changes its flowrate. The issue here is that obviously all
            % residual solvers are executed with the same post tick prio.
            % The solution was to implement a check if any other residual
            % solvers are attached to the same outlet phase as the current
            % residual solver. So while residual solver A keeps the mass of
            % Phase A constant, it checks if any residual solvers are
            % connected to Phase B and orders a new posttick update if that
            % is the case. Therefore the exme (and therefore the phase)
            % through which is iterated here is the exact opposite of the
            % one through which the iteration runs during the calculation
            % of the residual flowrate for the current solver ;)
            if this.bPositiveFlowDirection
                iExme = 2;
            else 
                iExme = 1;
            end
            
            oPhase = this.oBranch.coExmes{iExme}.oPhase;
            
            % Branches and p2p flows - they're also branches!
            for iE = 1:oPhase.iProcsEXME
                oExme   = oPhase.coProcsEXME{iE};
                oBranch = oExme.oFlow.oBranch;
                
                if oBranch == this.oBranch
                    continue;
                elseif ~oExme.bFlowIsAProcP2P && isa(oBranch.oHandler, 'solver.matter.residual.branch')
                    % if another residual branch is connected to the same
                    % phase as this one, the flowrate of the other residual
                    % solver could change after this solver was already
                    % calculated. In this case the solver has to rebind his
                    % update until the residual flowrate from the previous
                    % calculation is identical to the one calculated in the
                    % current calculation. This variable is used to decide
                    % wether this is the case
                    this.bMultipleResidualSolvers = true;
                    
                    % Only the residual solver that actually manages the
                    % mass of the phase into which the flowrates has
                    % changed is considered adjacent and has to be updated
                    % again!
                    if ((oExme.iSign == -1 && oBranch.oHandler.bPositiveFlowDirection) || (oExme.iSign == 1 && ~oBranch.oHandler.bPositiveFlowDirection)) && oBranch.oHandler.bActive
                        this.aoAdjacentResidualSolver(end+1) = oBranch;
                    end
                end
            end
        end
        function update(this)
            if ~this.bActive
                this.fRequestedFlowRate = 0;
                update@solver.matter.manual.branch(this);
                this.updateFlowProcs();
                return
            end
            
            % CALC GET THE FLOW RATE
            if this.bPositiveFlowDirection
                iExme = 1;
                iDir  = 1;
            else 
                iExme = 2;
                iDir  = -1;
            end
            
            oPhase = this.oBranch.coExmes{iExme}.oPhase;
            
            mfFlowRateExme = zeros(oPhase.iProcsEXME,1);
            % Branches and p2p flows - they're also branches!
            for iE = 1:oPhase.iProcsEXME
                oExme   = oPhase.coProcsEXME{iE};
                oBranch = oExme.oFlow.oBranch;
                
                if oBranch == this.oBranch
                    continue;
                end
                mfFlowRateExme(iE) = oExme.iSign * oExme.oFlow.fFlowRate;
            end
            fResidualFlowRate = sum(mfFlowRateExme);
            
            if fResidualFlowRate > this.fAllowedFlowRate
                this.fRequestedFlowRate = (fResidualFlowRate - this.fAllowedFlowRate) * iDir;
            else
                this.fRequestedFlowRate = 0;
            end
            
            %fprintf('%i\t(%.7fs)\tBranch %s Residual Solver - set Flow Rate %f\n', this.oBranch.oTimer.iTick, this.oBranch.oTimer.fTime, this.oBranch.sName, this.fRequestedFlowRate);
                
            if (this.fRequestedFlowRate ~= this.fResidualFlowRatePrev)
                update@solver.matter.base.branch(this, this.fRequestedFlowRate);
                this.updateFlowProcs();
                this.fLastUpdateTime = this.oBranch.oTimer.fTime;
                
                if this.bMultipleResidualSolvers
                    % If there are multiple residual solvers attached to the
                    % same phase as this residual solver, and the flowrate of
                    % this solver has changed, then all the other residual
                    % solvers have to be updated as well. This is necessary to
                    % allow one residual solver to end in a phase (keeping the
                    % mass of the phase attached to it constant) and the next
                    % residual solver keeping the mass of this phase constant
                    for iK = 1:length(this.aoAdjacentResidualSolver)
                        this.aoAdjacentResidualSolver(iK).oHandler.update();
                    end
                end
                
            else
                % manual solver update has to be called even if the overall
                % flowrate did not change, because the composition of the phase
                % can have changed!
                update@solver.matter.base.branch(this, this.fRequestedFlowRate);
                this.updateFlowProcs();
                this.fLastUpdateTime = this.oBranch.oTimer.fTime;
            end
            
            this.fResidualFlowRatePrev = this.fRequestedFlowRate;
        end
        
        function updateFlowProcs(this,~)
            % Checking if there are any active processors in the branch,
            % if yes, update them.
            if ~isempty(this.oBranch.aoFlowProcs)
            
                % Checking if there are any active processors in the branch,
                % if yes, update them.
                abActiveProcs = zeros(1, length(this.oBranch.aoFlowProcs));
                for iI=1:length(this.oBranch.aoFlowProcs)
                    if isfield(this.oBranch.aoFlowProcs(iI).toSolve, 'manual')
                        abActiveProcs(iI) = this.oBranch.aoFlowProcs(iI).toSolve.manual.bActive;
                    else
                        abActiveProcs(iI) = false;
                    end
                end
    
                for iI = 1:length(abActiveProcs)
                    if abActiveProcs(iI)
                        this.oBranch.aoFlowProcs(iI).toSolve.manual.update();
                    end
                end
                
            end
        end
    end
    
end
