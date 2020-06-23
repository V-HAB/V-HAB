classdef Dryer <  matter.procs.p2ps.flow
    
    properties (SetAccess = protected, GetAccess = public)
        % Drying Efficiency
        fDryingEfficiency = 0.9;
        
        arPartialsAdsorption;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % function handle registered at the timer object that allows this
        % phase to set a time step, which is then enforced by the timer
        setTimeStep;
    end
    
    methods
        function this = Dryer(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut, fDryingEfficiency, sSubstance)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            
            this.fDryingEfficiency = fDryingEfficiency;
            
            this.arPartialsAdsorption    = zeros(1,this.oMT.iSubstances);
            this.arPartialsAdsorption(this.oMT.tiN2I.(sSubstance)) = 1;
        end
        function calculateFlowRate(this, afInFlowRates, aarInPartials, ~, ~)
            afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
            
            fWaterFlowRate = afPartialInFlows(this.oMT.tiN2I.H2O);
            
            this.setMatterProperties(this.fDryingEfficiency * fWaterFlowRate, this.arPartialsAdsorption, this.oOut.oPhase.fTemperature, this.oOut.oPhase.fPressure);
        end
    end
    methods (Access = protected)
        function update(~)
            % this must be here since the normal V-HAB logic tries to
            % call the update
        end
    end
end