classdef OrganicBed_P2P < matter.procs.p2ps.flow
    
    properties (SetAccess = protected, GetAccess = public)
        abBigOrganics;
    end
    
    methods
        function this = OrganicBed_P2P(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn,sPhaseOut);
            
            this.abBigOrganics = false(1, this.oMT.iSubstances);
            % Currently only one big organic component considered here:
            this.abBigOrganics(this.oMT.tiN2I.C30H50) = true;
        end
        
        function calculateFlowRate(this, afInsideInFlowRate, aarInsideInPartials, ~, ~)
            
            fFlowRate = 0;
            arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            % Removes big organic compound until the ionic beds are full
            % and experience a breakthrough
            if ~all(this.oStore.oContainer.mfCurrentFillState > 0.99)
                afPartialInFlows = sum((afInsideInFlowRate .* aarInsideInPartials),1);
                
                afPartialFlowsOrganics = arExtractPartials;
                afPartialFlowsOrganics(this.abBigOrganics) = afPartialInFlows(this.abBigOrganics);

                fFlowRate = sum(afPartialFlowsOrganics);
                if fFlowRate ~= 0
                    arExtractPartials = afPartialFlowsOrganics ./ fFlowRate;
                end
            end
            
            this.setMatterProperties(fFlowRate, arExtractPartials);
        end
    end
    
    methods (Access = protected)
        function update(~)
           
        end
    end
end



