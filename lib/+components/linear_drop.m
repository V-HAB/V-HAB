classdef linear_drop < matter.procs.f2f
    %Valve Summary of this class goes here
    %   Detailed explanation goes here
    

    
    properties (SetAccess = protected, GetAccess = public)
        % fDrop = fDropCoeff * fFlowRate
        fDropCoeff = 0; % [-]
        
    end
    
    methods
        function  this = linear_drop(oContainer, sName, fDropCoeff)
            % Input Parameters:
            %   linear drop coeff
            
            this@matter.procs.f2f(oContainer, sName);
            
            if nargin >= 3 && ~isempty(fDropCoeff)
                this.fDropCoeff = fDropCoeff;
            end
            
            
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        
        
        
        
        function fDeltaPress = solverDeltas(this, fFlowRate)
            if this.fDropCoeff == inf
                fDeltaPress = inf;
                
                return;
                
            elseif (fFlowRate == 0) || (this.fDropCoeff == 0)
                fDeltaPress = 0;
                
                return;
            end
            
            
            fDeltaPress = this.fDropCoeff * abs(fFlowRate);
        end
    end
    
end

