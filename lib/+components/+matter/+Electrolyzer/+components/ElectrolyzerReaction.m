classdef ElectrolyzerReaction < matter.manips.substance.stationary
    % manipulator to model the water splitting reaction occuring within the
    % electrolyzer
    
    methods
        function this = ElectrolyzerReaction(sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);
            
        end
    end
    methods (Access = protected)
        function update(this)
            %calculate the resulting molar flow
            fMolarH2Flow = this.oPhase.oStore.oContainer.fStackCurrent / (2 * this.oMT.Const.fFaraday);
            
            % Initialize the array we pass back to the phase once we're
            % done
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            %set the flowrates of the manip
            afPartialFlows(tiN2I.H2)  = fMolarH2Flow * this.oMT.afMolarMass(this.oMT.tiN2I.H2);
            afPartialFlows(tiN2I.O2)  = 0.5 * fMolarH2Flow * this.oMT.afMolarMass(this.oMT.tiN2I.H2);
            afPartialFlows(tiN2I.H2O) = - sum(afPartialFlows);
            
            % update method they are converted to flow rates.
            update@matter.manips.substance.stationary(this, afPartialFlows);
        end
    end
end