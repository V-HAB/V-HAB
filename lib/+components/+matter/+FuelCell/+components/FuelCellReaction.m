classdef FuelCellReaction < matter.manips.substance.stationary
    %     This manipulator calculates the conversion mass flows of hydrogen
    %     and oxygen into water based on the current of the fuel cell stack
    %     and its number of cells using Faraday#s Law
    
    methods
        function this = FuelCellReaction(sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);
            
        end
        
        function update(this)
            %calculate the resulting massflow [mol/sec]
            fH2_Molflow = this.oPhase.oStore.oContainer.iCells * ((this.oPhase.oStore.oContainer.fStackCurrent) / (2 * this.oMT.Const.fFaraday));
            
            % H2 + 0.5 O2 -> H2O
            fH2_Massflow  = fH2_Molflow * this.oMT.afMolarMass(this.oMT.tiN2I.H2);
            fO2_Massflow  = 0.5 * fH2_Molflow * this.oMT.afMolarMass(this.oMT.tiN2I.O2);
            
            %Initialize the array we pass back to the phase
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            %set the flowrates of the manip
            afPartialFlows(tiN2I.H2)  = - fH2_Massflow;
            afPartialFlows(tiN2I.O2)  = - fO2_Massflow;
            % To prevent potential small mass errors from slight
            % differences in the molar masses, we calculate the mass flow
            % of water by summing up the other two flow rates instead of
            % using the molar mass to calculate it
            afPartialFlows(tiN2I.H2O) =   fH2_Massflow + fO2_Massflow;
            
            % Now we can call the parent update method and pass on the
            % afPartials variable. The last parameter indicates that the
            % values in afPartials are absolute masses, so within the
            % update method they are converted to flow rates.
            update@matter.manips.substance.stationary(this, afPartialFlows);
        end
    end
end