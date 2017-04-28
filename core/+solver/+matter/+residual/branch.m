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
        
        fLastUpdate = -1;
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.matter.manual.branch(oBranch);
            
            this.iPostTickPriority = 1;
            this.oBranch.oTimer.bindPostTick(@this.update, this.iPostTickPriority);
            
            this.oBranch.oTimer.bindPostTick(@this.findAdjacentResidualSolvers, -3);
        end
        
        function setPositiveFlowDirection(this, bPositiveFlowDirection)
            this.bPositiveFlowDirection = bPositiveFlowDirection;
            this.oBranch.oTimer.bindPostTick(@this.findAdjacentResidualSolvers, -3);
            
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
                if this.oBranch.fFlowRate ~= 0
                    update@solver.matter.manual.branch(this);
                else
                    this.oBranch.setUpdated();
                    this.oBranch.oHandler.setUpdated();
                end
                return
            end
            
            % CALC GET THE FLOW RATE
            fResidualFlowRate  = 0;
            
            if this.bPositiveFlowDirection
                iExme = 1;
                iDir  = 1;
            else 
                iExme = 2;
                iDir  = -1;
            end
            
            oPhase = this.oBranch.coExmes{iExme}.oPhase;
            
            % Branches and p2p flows - they're also branches!
            for iE = 1:oPhase.iProcsEXME
                oExme   = oPhase.coProcsEXME{iE};
                oBranch = oExme.oFlow.oBranch;
                
                if oBranch == this.oBranch
                    continue;
                end
                
                fResidualFlowRate = fResidualFlowRate + oExme.iSign * oExme.oFlow.fFlowRate;
            end
             
            this.fRequestedFlowRate = (fResidualFlowRate - this.fAllowedFlowRate) * iDir;
            
            %fprintf('%i\t(%.7fs)\tBranch %s Residual Solver - set Flow Rate %f\n', this.oBranch.oTimer.iTick, this.oBranch.oTimer.fTime, this.oBranch.sName, this.fRequestedFlowRate);
                
            if (this.fRequestedFlowRate ~= this.fResidualFlowRatePrev)
                update@solver.matter.base.branch(this, this.fRequestedFlowRate);
                this.fLastUpdate = this.oBranch.oTimer.fTime;
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
                if this.fRequestedFlowRate > 0
                    oPhase = this.oBranch.coExmes{1}.oPhase;
                elseif this.fRequestedFlowRate == 0
                    this.oBranch.setUpdated();
                    this.oBranch.oHandler.setUpdated();
                    return
                else
                    oPhase = this.oBranch.coExmes{2}.oPhase;
                end
                
                if oPhase.fLastMassUpdate > this.fLastUpdate
                    update@solver.matter.base.branch(this, this.fRequestedFlowRate);
                    this.fLastUpdate = this.oBranch.oTimer.fTime;
                end

                this.oBranch.setUpdated();
                this.oBranch.oHandler.setUpdated();
                
            end
            this.fResidualFlowRatePrev = this.fRequestedFlowRate;
        end
        end
    
end
