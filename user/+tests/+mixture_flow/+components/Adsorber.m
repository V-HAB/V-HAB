classdef Adsorber < matter.procs.p2ps.flow
    % P2P processor to model a very basic adsorption process
    properties
        afPartialInFlows;
    end
    
    methods
        function [this] = Adsorber(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);  
        end
        
        function calculateFlowRate(this, afInsideInFlowRates, aarInsideInPartials, ~, ~)
            if ~(isempty(afInsideInFlowRates) || all(sum(aarInsideInPartials) == 0))
                this.afPartialInFlows = sum((afInsideInFlowRates .* aarInsideInPartials),1);
            else
                this.afPartialInFlows = zeros(1,this.oMT.iSubstances);
            end
            
            % Since this calculation is called from both flow phases, the
            % liquid and the gas flow, we have to decide whether or not it
            % should actually be recalculated.
            if this.afPartialInFlows(this.oMT.tiN2I.N2) ~= 0 || all(this.afPartialInFlows == 0)
                fAdsorptionFlow = 0.9 * this.afPartialInFlows(this.oMT.tiN2I.CO2);
                arPartialsAdsorption = zeros(1,this.oMT.iSubstances);
                arPartialsAdsorption(this.oMT.tiN2I.CO2) = 1;

                this.setMatterProperties(fAdsorptionFlow, arPartialsAdsorption);
            end
        end
    end
    methods (Access = protected)
        function update(~)   
        end
    end
    
end