classdef Set_Plants_O2GasExchange < matter.procs.p2ps.flow
    % Short description:
    %  This p2p-processor conducts the H2O gas exchange between the
    %  plants-phase and the air-phase insides the PlantCultivationStore.
    
    properties 
        % parent system object in which the phase/store containing the p2p
        % is located
        oParent;
        
        % Defines which species are extracted
        arExtractPartials;
    end
    
    
    methods
        function this = Set_Plants_O2GasExchange(oStore, sName, sPhaseIn, sPhaseOut, oParent)
            % call superconstructor
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.oParent  = oParent;

            % The p2p processor can specify which species it wants to
            % extract from the phase. A vector with relative values has to
            % be provided, with the sum of all ratios being 1 (see the
            % matter.phase.arPartialMass vector) ...
            % ... in this case using a vector with zeros at all indices
            % except the one holding the partial mass for the species we
            % want to extract - which is set to 1, i.e. only this species
            % is extracted.
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.O2) = 1;

        end
        
        function update(this)
            % get flowrate from struct in parent system
            % TODO: maybe can take directly from CreateBiomass manipulator
            fFlowRate =  this.oParent.oCreateBiomass.fO2Exchange;

            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
    
end

