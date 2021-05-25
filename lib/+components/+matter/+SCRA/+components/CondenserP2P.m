classdef CondenserP2P < matter.procs.p2ps.flow
    
    
    properties (SetAccess = protected, GetAccess = public)
        oCondenser;
    end
    
    methods
        function this = CondenserP2P(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut, oCondenser)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            this.oCondenser = oCondenser;
        end
        
        function calculateFlowRate(this, afInFlowRates, aarInPartials, ~, ~)
            
            afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
            fFlowRate = sum(afPartialInFlows);
            arPartials    = zeros(1,this.oMT.iSubstances);
            if fFlowRate ~= 0
                if ~isempty(this.oIn.oPhase.fVirtualPressure)
                    fPressure = this.oIn.oPhase.fVirtualPressure;
                else
                    fPressure = this.oIn.oPhase.fPressure;
                end
                % should not happen, but just in case
                if fPressure < 0
                    fPressure = 0;
                end
                arPartials(this.oMT.tiN2I.H2O) = 1;
                arPartialMass       = afPartialInFlows ./ fFlowRate;
                afCurrentMolsIn     = (afPartialInFlows ./ this.oMT.afMolarMass);
                arFractions         = afCurrentMolsIn ./ sum(afCurrentMolsIn);
                afPP                = arFractions .*  fPressure;

                fPressureDifferenceH2O = afPP(this.oMT.tiN2I.H2O) - this.oCondenser.rHumiditySetPoint * this.oMT.calculateVaporPressure(this.oCondenser.fTemperature, 'H2O');
                if fPressureDifferenceH2O > 0
                    if fPressureDifferenceH2O > 0
                        fCondensateFlow = (fPressureDifferenceH2O / afPP(this.oMT.tiN2I.H2O)) * fFlowRate * arPartialMass(this.oMT.tiN2I.H2O);
                    else
                        fCondensateFlow = 0;
                    end
                else
                    fCondensateFlow = 0;
                end

            else
                fCondensateFlow = 0;
            end
            this.setMatterProperties(fCondensateFlow, arPartials);
        end
    end
end