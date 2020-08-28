classdef FuelCellReaction < matter.manips.substance.stationary
    %     This manipulator calculates the conversion mass flows of hydrogen
    %     and oxygen into water based on the current of the fuel cell stack
    %     and its number of cells using Faraday#s Law
    
    methods
        function this = FuelCellReaction(sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);
            
        end
    end
    methods (Access = protected)
        function update(this)
            %calculate the resulting massflow [mol/sec]
            fH2_Molflow = this.oPhase.oStore.oContainer.iCells * ((this.oPhase.oStore.oContainer.fStackCurrent) / (2 * this.oMT.Const.fFaraday));
            
            % H2 + 0.5 O2 -> H2O
            fH2_Massflow  = fH2_Molflow * this.oMT.afMolarMass(this.oMT.tiN2I.H2);
            fO2_Massflow  = 0.5 * fH2_Molflow * this.oMT.afMolarMass(this.oMT.tiN2I.O2);
            
            %Initialize the array we pass back to the phase
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            %set the flowrates of the manip
            afPartialFlows(this.oMT.tiN2I.H2)  = - fH2_Massflow;
            afPartialFlows(this.oMT.tiN2I.O2)  = - fO2_Massflow;
            % To prevent potential small mass errors from slight
            % differences in the molar masses, we calculate the mass flow
            % of water by summing up the other two flow rates instead of
            % using the molar mass to calculate it
            afPartialFlows(this.oMT.tiN2I.H2O) = (fH2_Massflow + fO2_Massflow);
            
            % Now we can call the parent update method and pass on the
            % afPartials variable. The last parameter indicates that the
            % values in afPartials are absolute masses, so within the
            % update method they are converted to flow rates.
            update@matter.manips.substance.stationary(this, afPartialFlows);
            
            % Set the corresponding P2P Flowrates
            afPartialFlowsH2 = zeros(1, this.oPhase.oMT.iSubstances);
            afPartialFlowsH2(this.oMT.tiN2I.H2) = -afPartialFlows(this.oMT.tiN2I.H2);
            this.oPhase.oStore.toProcsP2P.H2_to_Membrane.setFlowRate(afPartialFlowsH2);
            
            afPartialFlowsO2 = zeros(1, this.oPhase.oMT.iSubstances);
            afPartialFlowsO2(this.oMT.tiN2I.O2) = -afPartialFlows(this.oMT.tiN2I.O2);
            this.oPhase.oStore.toProcsP2P.O2_to_Membrane.setFlowRate(afPartialFlowsO2);
            
            afPartialFlowsH2O = zeros(1, this.oPhase.oMT.iSubstances);
            afPartialFlowsH2O(this.oMT.tiN2I.H2O) = afPartialFlows(this.oMT.tiN2I.H2O);
            this.oPhase.oStore.toProcsP2P.Membrane_to_O2.setFlowRate(afPartialFlowsH2O);
            
            this.oPhase.oStore.oContainer.toStores.O2_WaterSeperation.toProcsP2P.Dryer.setFlowRate(afPartialFlowsH2O);
        end
    end
end