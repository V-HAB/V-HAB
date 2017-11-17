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
        
        bActive = true;
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.matter.manual.branch(oBranch);
            
            % AFTER p2ps/manips, but BEFORE calcTS of phase!
            %this.iPostTickPriority = 2;
        end
        
        function setPositiveFlowDirection(this, bPositiveFlowDirection)
            this.bPositiveFlowDirection = bPositiveFlowDirection;
        end
        
        function setActive(this, bActive)
            this.bActive = bActive;
        end
    end
    
    methods (Access = protected)
        function update(this)
            
            %disp(this.oBranch.oTimer.iTick);
            %disp('--------- RESIDUAL UPDATE pre ----------------');
            
            
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
            
            this.fRequestedFlowRate = fResidualFlowRate * iDir;
            
            
            
            % If this residual solver sets an outwards flow rate, its flow
            % rate should be calculated AFTER the p2ps of the reference
            % phase update - therefore, the changes in their flow rate are
            % reflected immediately as well.
            % This does not necessarily work perfectly for a chain of
            % residual solvers with p2ps in the connecting phases, but
            % that case will be covered (hopefully) by the time step logic
            % of those phases.
            if fResidualFlowRate > 0
                this.iPostTickPriority = abs(this.iPostTickPriority);
            else
                this.iPostTickPriority = -1 * abs(this.iPostTickPriority);
            end
            
            %fprintf('%i\t(%.7fs)\tBranch %s Residual Solver - set Flow Rate %f\n', this.oBranch.oTimer.iTick, this.oBranch.oTimer.fTime, this.oBranch.sName, this.fRequestedFlowRate);
            
            update@solver.matter.manual.branch(this);
            
            
            
            %disp('--------- RESIDUAL UPDATE post ----------------');
        end
    end
    
end
