classdef flowMixedBed_P2P < matter.procs.p2ps.flow & components.matter.WPA.components.baseMixedBed_P2P
    
    properties
    end
    
    methods
        function [this] = flowMixedBed_P2P(oStore, sName, sPhaseIn, sPhaseOut, oDesorptionP2P)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);  
            this@components.matter.WPA.components.baseMixedBed_P2P(oStore, oDesorptionP2P);  
        end
        
        function calculateFlowRate(this, afInsideInFlowRate, aarInsideInPartials, ~, ~)
             % calculate the current inflows
            afPartialInFlows = sum((afInsideInFlowRate .* aarInsideInPartials),1);
            
            %afPartialInFlows = afPartialInFlows + this.oIn.oPhase.toManips.substance.afPartialFlows;
            afPartialInFlows(afPartialInFlows < 0) = 0;

            afPartialFlowRates = calculateExchangeRates(this, afPartialInFlows);
            
            afDesorptionFlowRates = zeros(1, this.oMT.iSubstances);
            afAdsorptionFlowRates = afDesorptionFlowRates;

            afAdsorptionFlowRates(afPartialFlowRates > 0) = afPartialFlowRates(afPartialFlowRates > 0);
            if afAdsorptionFlowRates > afPartialInFlows
                afAdsorptionFlowRates(afAdsorptionFlowRates > afPartialInFlows) = afPartialInFlows(afAdsorptionFlowRates > afPartialInFlows);
            end
            afDesorptionFlowRates(afPartialFlowRates < 0) = afPartialFlowRates(afPartialFlowRates < 0);
            abLimitDesorption = this.oOut.oPhase.afMass < 1e-12;
            afDesorptionFlowRates(abLimitDesorption) = 0;

            fDesorptionFlowRate = sum(afDesorptionFlowRates);
            if fDesorptionFlowRate == 0
                arExtractPartialsDesorption = zeros(1,this.oMT.iSubstances);
            else
                arExtractPartialsDesorption = afDesorptionFlowRates/fDesorptionFlowRate;
            end

            fAdsorptionFlowRate = sum(afAdsorptionFlowRates);
            if fAdsorptionFlowRate == 0
                arExtractPartialsAdsorption = zeros(1,this.oMT.iSubstances);
            else
                arExtractPartialsAdsorption = afAdsorptionFlowRates/fAdsorptionFlowRate;
            end
                
            if fAdsorptionFlowRate ~= this.fFlowRate || ~all(arExtractPartialsAdsorption == this.arPartialMass)
                this.setMatterProperties(fAdsorptionFlowRate, arExtractPartialsAdsorption);
            end
            if fDesorptionFlowRate ~= this.oDesorptionP2P.fFlowRate || ~all(arExtractPartialsDesorption == this.oDesorptionP2P.arPartialMass)
                this.oDesorptionP2P.setMatterProperties(fDesorptionFlowRate, arExtractPartialsDesorption);
            end
        end
    end
    
    methods (Access = protected)
        function update(~)   
        end
    end
end