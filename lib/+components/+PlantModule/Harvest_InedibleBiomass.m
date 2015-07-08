classdef Harvest_InedibleBiomass < matter.procs.p2ps.flow

% Short description:
%  This p2p-processor extracts all inedible plant-components from the
%  Plants-phase to the HarvestInedible-phase inside the PlantCultivationStore
    
    properties %(SetAccess = protected, GetAccess = public)

        afMass;
        
        aiSubstanceArray;
        
        % Defines which species are extracted
        arExtractPartials;

    end
    
    
    methods
        function this = Harvest_InedibleBiomass(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
                    
        
            this.afMass=this.oStore.aoPhases(1,2).afMass;
            
            
            % The p2p processor can specify which species it wants to
            % extract from the phase. A vector with relative values has to
            % be provided, with the sum of all ratios being 1 (see the
            % matter.phase.arPartialMass vector) ...
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            % ... in this case using a vector with zeros at all indices
            % except the one holding the partial mass for the species we
            % want to extract - which is set to 1, i.e. only this species
            % is extracted.
        end
        
        function update(this)
            % Called whenever a flow rate changes. The two EXMES (oIn/oOut)
            % have an oPhase attribute that allows us to get the phases on
            % the left/right side.
            % Here, the oIn is always the air phase, the oOut is the solid
            % absorber phase.
            
          

            this.aiSubstanceArray=[this.oMT.tiN2I.DrybeanInedibleFluid, ...
                this.oMT.tiN2I.DrybeanInedibleDry, ...
                this.oMT.tiN2I.LettuceInedibleFluid, ...
                this.oMT.tiN2I.LettuceInedibleDry, ...
                this.oMT.tiN2I.PeanutInedibleFluid, ...
                this.oMT.tiN2I.PeanutInedibleDry, ...
                this.oMT.tiN2I.RiceInedibleFluid, ...
                this.oMT.tiN2I.RiceInedibleDry, ...
                this.oMT.tiN2I.SoybeanInedibleFluid, ...
                this.oMT.tiN2I.SoybeanInedibleDry, ...
                this.oMT.tiN2I.SweetpotatoInedibleFluid, ...
                this.oMT.tiN2I.SweetpotatoInedibleDry, ...
                this.oMT.tiN2I.TomatoInedibleFluid, ...
                this.oMT.tiN2I.TomatoInedibleDry, ...
                this.oMT.tiN2I.WheatInedibleFluid, ...
                this.oMT.tiN2I.WheatInedibleDry, ...
                this.oMT.tiN2I.WhitepotatoInedibleFluid, ...
                this.oMT.tiN2I.WhitepotatoInedibleDry];
               

            for i=1:1:18
                 iSpecies = this.aiSubstanceArray(i);
                 if this.afMass(iSpecies)>0.1
                    this.arExtractPartials(iSpecies) = 1;%mrPartials(iSpecies)/(sum(mrPartials(SpeciesArray))+0.0000000000000000000000000000000000000001);

                 else
                     this.arExtractPartials(iSpecies) = 0;
                 end;
            end;
           
            fFlowRate = 0.001; %[kg/s]



            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
    
end

