classdef branch < solver.matter.base.branch
    
    properties (SetAccess = protected, GetAccess = public)
        fRequestedFlowRate = 0;
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    properties (SetAccess = private, GetAccess = private, Transient = true)
        
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.matter.base.branch(oBranch, [], 'manual');
        end
        
        
        function this = setFlowRate(this, fFlowRate)
            
            this.fRequestedFlowRate = fFlowRate;
            
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        function update(this)
            % We can't set the flow rate directly on this.fFlowRate or on
            % the branch, but have to provide that value to the parent
            % update method.
            
            update@solver.matter.base.branch(this, this.fRequestedFlowRate);
            
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