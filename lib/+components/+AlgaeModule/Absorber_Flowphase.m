classdef Absorber_Flowphase < matter.procs.p2ps.flow
    %ABSORBEREXAMPLE An example for a p2p processor implementation
    %   The actual logic behind the absorbtion behavior is not based on any
    %   specific physical system. It is just implemented in a way to
    %   demonstrate the use of p2p processors
    
    properties (SetAccess = public, GetAccess = public)
        % Species to absorb
        sSubstance1;
        %sSubstance2;
        sSubstance3;
        
        % Maximum absorb capacity in kg
        fCapacity;
        
        
        % Max absorption rate in kg/s/Pa, partial pressure of the species
        % to absorb
        %NOTE not used yet ...
%         fMaxAbsorptionCO2 = 0;
%         fMaxAbsorptionNO3 = 0;
%         fMaxAbsorptionO2  = 0;
        % Defines which species are extracted
        arExtractPartials;
        
        fPower;
        fDilution ;
%         fVolume_FreshWater;
%         fMass_Algae;
%         fCO2Mass;
%         fNuMass;
%         fP1 = 0;
%         fP2 = 0;
%         fP3 = 0;
%         fP4 = 0;
%         fP5 = 0;
%         fP6 = 0;
%         fP7 = 0;
%         fP8 = 0;
%         fP9 = 0;
%         fAerationPower;
%         fProductivity = 0;
%         fX = 0;
%         fY = 0;
%         fU = 0;
%         fVolume = 187.2;
%         % Ratio of actual loading and maximum load
%         rLoad;
            fHarvest;
    end
    
    
    methods
        function this = Absorber_Flowphase(oStore, sName, sPhaseIn, sPhaseOut, sSubstance1, sSubstance3, fHarvest)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            % Species to absorb, max absorption
            this.sSubstance1  = sSubstance1;
            %this.sSpecies2  = sSpecies2;
            this.sSubstance3  = sSubstance3;
            
            this.fHarvest = fHarvest;
            
            
           
            % The p2p processor can specify which species it wants to
            % extract from the phase. A vector with relative values has to
            % be provided, with the sum of all ratios being 1 (see the
            % matter.phase.arPartialMass vector) ...
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            % ... in this case using a vector with zeros at all indices
            % except the one holding the partial mass for the species we
            % want to extract - which is set to 1, i.e. only this species
            % is extracted.
            this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance1)) = 1;
            %this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance2)) = 1;
            %this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance3)) = 0;
            
           
            
        end
      
%         
         function update(this)

            
           fFlowRate=(this.oOut.oPhase.coProcsP2P{1,2}.fFlowRate*this.oOut.oPhase.coProcsP2P{1,2}.arExtractPartials(this.oMT.tiN2I.(this.sSubstance1)));
            
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
         
         end
    end
end


