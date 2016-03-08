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
            
            
            this.iPostTickPriority = -1;
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
            
            oPhase             = this.oBranch.coExmes{iExme}.oPhase;
            
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
            
            %fprintf('[%fs] Branch %s Residual Solver - set Flow Rate %f\n', this.oBranch.oContainer.oData.oTimer.fTime, this.oBranch.sName, this.fRequestedFlowRate);
            
            update@solver.matter.manual.branch(this);
        end
        end
    
end
