classdef Food_H2O_Addition < matter.procs.p2ps.flow
    
    % A phase manipulator to add the required water to prepare dried food
    
    properties (SetAccess = public, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
        
        fRequestedFlowRate = 0;
    end
    
    methods
        function this = Food_H2O_Addition(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.H2O)   = 1;
            
        end
        
        function update(this)
            this.setMatterProperties(this.fRequestedFlowRate, this.arExtractPartials);
        end
        
        function setFlowRate(this, fFlowRate)
            this.fRequestedFlowRate = fFlowRate;
            this.update();
        end
    end
end