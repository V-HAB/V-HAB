classdef branch < solver.matter.manual.branch
    % Calculates sum of flow rates of other branches and p2p procs and set
    % remaining flowrate for own branch.
    %
    %TODO
    %   * check if in phase is bSynced, check if added as last solver?
    
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
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.matter.manual.branch(oBranch);
            
            this.iPostTickPriority = 1;
            this.oBranch.oTimer.bindPostTick(@this.update, this.iPostTickPriority);
            
            this.findAdjacentResidualSolvers();
        end
        
        function setPositiveFlowDirection(this, bPositiveFlowDirection)
            this.bPositiveFlowDirection = bPositiveFlowDirection;
            this.findAdjacentResidualSolvers();
        end
        
        function setActive(this, bActive)
            this.bActive = bActive;
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
                    
                    % Note that it would be preferable that only the
                    % residual solvers that are supposed to keep the mass
                    % in this phase constant are reupdated (as there should be
                    % only one) but ensuring that this remains the case
                    % even if the other solver changes the positive flow
                    % direction of the residual is fairly difficult and
                    % left for future work ;)
                    this.aoAdjacentResidualSolver(end+1) = oBranch;
                    continue
                end
            end
        end
        function update(this)
            if ~this.bActive
                this.fRequestedFlowRate = 0;
                update@solver.matter.manual.branch(this);
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
            
            if this.bMultipleResidualSolvers && (fResidualFlowRate ~= this.fResidualFlowRatePrev)
                % If there are multiple residual solvers attached to the
                % same phase as this residual solver, and the flowrate of
                % this solver has changed, then all the other residual
                % solvers have to be updated as well. This is necessary to
                % allow one residual solver to end in a phase (keeping the
                % mass of the phase attached to it constant) and the next
                % residual solver keeping the mass of this phase constant
                iPostTickPriority = 1;
                for iK = 1:length(this.aoAdjacentResidualSolver)
                    oBranch = this.aoAdjacentResidualSolver(iK);
                    oBranch.oTimer.bindPostTick(@oBranch.update, iPostTickPriority);
                end
            end
                    
            this.fResidualFlowRatePrev = fResidualFlowRate;
            
            this.fRequestedFlowRate = fResidualFlowRate * iDir;
            
            %fprintf('%i\t(%.7fs)\tBranch %s Residual Solver - set Flow Rate %f\n', this.oBranch.oTimer.iTick, this.oBranch.oTimer.fTime, this.oBranch.sName, this.fRequestedFlowRate);
            
            update@solver.matter.manual.branch(this);
        end
        end
    
end
