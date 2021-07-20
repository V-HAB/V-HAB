classdef Dryer < matter.procs.p2ps.flow
    % This p2p is designed to maintain a specific humidity in the gas side
    % flow. (Gas side is considered to be the in side)
    
    properties (SetAccess = protected, GetAccess = public)
        
        arPartialsAdsorption;
        rHumiditySetPoint = 0.8;
        
    end
    methods
        function this = Dryer(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut, rHumiditySetPoint)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            
            if nargin > 4
                this.rHumiditySetPoint = rHumiditySetPoint;
            end
            this.arPartialsAdsorption = zeros(1, this.oMT.iSubstances);
            this.arPartialsAdsorption(this.oMT.tiN2I.H2O) = 1;
        end
         function calculateFlowRate(this, afInFlowRates, aarInPartials, ~, ~)
            % This function is called by the multibranch solver, which also
            % calculates the inflowrates and partials (as the p2p flowrates
            % themselves should not be used for that we cannot use the gas
            % flow node values directly otherwise the P2P influences itself)
            if ~isempty(this.oIn.oPhase.fVirtualPressure)
                fPressure = this.oIn.oPhase.fVirtualPressure;
            else
                fPressure = this.oIn.oPhase.fPressure;
            end
            % should not happen, but just in case
            if fPressure < 0
                fPressure = 0;
            end

            if ~(isempty(afInFlowRates) || all(sum(aarInPartials) == 0))
                afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);

                afCurrentMolsIn     = (afPartialInFlows ./ this.oMT.afMolarMass);
                arFractions         = afCurrentMolsIn ./ sum(afCurrentMolsIn);
                afPP                = arFractions .*  fPressure; 
            else
                afPartialInFlows = zeros(1,this.oMT.iSubstances);

                %THIS IS A HACK I don't know what a better solution is
                %here. The call to get the afPP property only fails
                %during tick 0, I haven't followed up to see if it is
                %just never used again, or if in the other instances
                %the property is accessed outside of the update in the
                %multi-branch solver.
                try
                    afPP = this.oIn.oPhase.afPP;
                catch
                    return
                end
            end
            
            fVaporPressure = this.oMT.calculateVaporPressure(this.oIn.oPhase.fTemperature, 'H2O');
            
            rCurrentHumidity = afPP(this.oMT.tiN2I.H2O) / fVaporPressure;
            % from the humidity difference we can calculate the desired
            % pressure difference the P2P should create for H2O
            fPressureDifference = (rCurrentHumidity - this.rHumiditySetPoint) * fVaporPressure;
            if fPressureDifference < 0
                % This component is a dryer, it cannot produce humidity
                fPressureDifference = 0;
            end
            % And the pressure difference can be converted to a flow rate,
            % using the same approach that was used to calculate the afPP
            % value from the in flows
            rWaterFractionDifference = fPressureDifference / fPressure;
            fMolarFlowWater = rWaterFractionDifference * sum(afCurrentMolsIn);
            fFlowRate = fMolarFlowWater * this.oMT.afMolarMass(this.oMT.tiN2I.H2O);
            if fFlowRate > afPartialInFlows(this.oMT.tiN2I.H2O)
                fFlowRate = afPartialInFlows(this.oMT.tiN2I.H2O);
            end
            this.setMatterProperties(fFlowRate, this.arPartialsAdsorption);
         end
    end
end