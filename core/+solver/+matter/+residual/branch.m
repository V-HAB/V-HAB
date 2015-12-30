classdef branch < solver.matter.manual.branch
    % Calculates sum of flow rates of other branches and p2p procs and set
    % remaining flowrate for own branch.
    %
    %TODO
    %   * at the moment, using the 'left' phase to calculate flow rate.
    %     Make user-selectable?
    %   * check if in phase is bSynced, check if added as last solver?
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.matter.manual.branch(oBranch);
            
            
            this.iPostTickPriority = -1;
        end
    end
    
    methods (Access = protected)
        function update(this)
            % CALC GET THE FLOW RATE
            fResidualFlowRate  = 0;
            oPhase             = this.oBranch.coExmes{1}.oPhase;
            
            % Branches and p2p flows - they're also branches!
            for iE = 1:oPhase.iProcsEXME
                oExme   = oPhase.coProcsEXME{iE};
                oBranch = oExme.oFlow.oBranch;
                
                if oBranch == this.oBranch
                    continue;
                end
                
                fResidualFlowRate = fResidualFlowRate + oExme.iSign * oExme.oFlow.fFlowRate;
            end
            
            this.fRequestedFlowRate = fResidualFlowRate;
            
            %fprintf('[%fs] Branch %s Residual Solver - set Flow Rate %f\n', this.oBranch.oContainer.oData.oTimer.fTime, this.oBranch.sName, this.fRequestedFlowRate);
            
            update@solver.matter.manual.branch(this);
        end
    end
end
