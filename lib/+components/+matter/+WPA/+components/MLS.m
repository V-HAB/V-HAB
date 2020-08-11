classdef MLS < matter.procs.p2ps.flow
    
    % MLS removes 99,975% of the incoming gases
    
    methods
        function this = MLS(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn,sPhaseOut);
            
            
        end
        
        function calculateFlowRate(this, afInsideInFlowRate, aarInsideInPartials, ~, ~)
            
            afPartialInFlows = sum((afInsideInFlowRate .* aarInsideInPartials),1);
            
            afPP = ones(1, this.oMT.iSubstances) .* 1e5;
            
            miPhases = this.oMT.determinePhase( afPartialInFlows, 293, afPP);
                
            abGas = miPhases == 3;
            
            abGas(this.oMT.tiN2I.Clminus)   =   0; %Chloride is an solved ion
            abGas(this.oMT.tiN2I.CH2O)      =   0; %formalaldehyde dissolves
            
            afPartialFlowRatesGases = zeros(1, this.oMT.iSubstances);
            afPartialFlowRatesGases(abGas) = afPartialInFlows(abGas);
            
            fFlowRate = sum(afPartialFlowRatesGases);
            if fFlowRate == 0
                arExtractPartials = zeros(1,this.oMT.iSubstances);
            else
                arExtractPartials = afPartialFlowRatesGases/fFlowRate;
            end
            %setting flowrates to 99.975%
            this.setMatterProperties(fFlowRate*0.99975, arExtractPartials);
        end
    end
    
    methods (Access = protected)
        function update(~)
        end
    end
end

