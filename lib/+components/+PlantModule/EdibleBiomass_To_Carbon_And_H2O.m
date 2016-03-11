classdef EdibleBiomass_To_Carbon_And_H2O < matter.manips.substance.flow
    
    %A phase manipulator to simulate conversion of O2 into CO2 inside the
    %human body. It does not use any other inputs except for O2 so the mass
    %balance is not closed.
                                    
    
    properties (SetAccess = protected, GetAccess = public)
       fLastUpdate;
    end
    
    methods
        function this = EdibleBiomass_To_Carbon_And_H2O(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            this.fLastUpdate = 0;
        end
        
        function update(this)
            
            fTimeStep = this.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            if fTimeStep <= 0
                return
            end
            
            afFRs = this.getTotalFlowrates();
            afPartialFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            % Edible dry mass array
            afDrymass = [...
                tiN2I.DrybeanEdibleDry, ...
                tiN2I.LettucenEdibleDry, ...
                tiN2I.PeanutEdibleDry, ...
                tiN2I.RiceEdibleDry, ...
                tiN2I.SoybeanEdibleDry, ...
                tiN2I.SweetpotatoEdibleDry, ...
                tiN2I.TomatoEdibleDry, ...
                tiN2I.WheatEdibleDry, ...
                tiN2I.WhitepotatoEdibleDry];
            
            % edible fluid mass array
            afFluid = [...
                tiN2I.DrybeanEdibleFluid, ...
                tiN2I.LettucenEdibleFluid, ...
                tiN2I.PeanutEdibleFluid, ...
                tiN2I.RiceEdibleFluid, ...
                tiN2I.SoybeanEdibleFluid, ...
                tiN2I.SweetpotatoEdibleFluid, ...
                tiN2I.TomatoEdibleFluid, ...
                tiN2I.WheatEdibleFluid, ...
                tiN2I.WhitepotatoEdibleFluid];
            
            % convert edible drymass to C
            for iI = 1:length(afDrymass)
                iSubstance = afDrymass(iI);
                
                afPartialFlowrates(iSubstance) = -afFRs(iSubstance);
                afPartialFlowrates(tiN2I.C) = afPartialFlowrates(tiN2I.C) + afFRs(iSubstance);
            end
            
            % convert edible fluid mass to H2O
            for iI = 1:length(afFluid)
                iSubstance = afFluid(iI);
                
                afPartialFlowrates(iSubstance) = -afFRs(iSubstance);
                afPartialFlowrates(tiN2I.H2O) = afPartialFlowrates(tiN2I.H2O) + afFRs(iSubstance);
            end
            
            update@matter.manips.substance.flow(this, afPartialFlowRates);
            
            this.fLastUpdate = this.oPhase.oStore.oTimer.fTime;
        end
        
        
    end
end