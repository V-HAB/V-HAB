classdef branch < solver.matter.base.branch
    
    properties (SetAccess = protected, GetAccess = public)
        fRequestedFlowRate = 0;
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.matter.base.branch(oBranch, [], 'manual');
        end
        
        
        function this = setFlowRate(this, afFlowRates)
            
            % since this branch is working like a P2P we deactivated the
            % setData function in the branch to set the partial flowrates
            % etc ourselfs here!
            this.oBranch.aoFlows.setMatterPropertiesBranch(afFlowRates);
            
            this.fRequestedFlowRate = sum(afFlowRates);
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        function update(this)
            % We can't set the flow rate directly on this.fFlowRate or on
            % the branch, but have to provide that value to the parent
            % update method.

            %TODO distribute pressure drops equally over flows?
            
            update@solver.matter.base.branch(this, this.fRequestedFlowRate);
            
        end
    end
end
