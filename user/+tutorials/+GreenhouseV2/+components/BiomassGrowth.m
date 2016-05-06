classdef BiomassGrowth < matter.procs.p2ps.flow
    % This p2p processor moves "general" biomass from the biomass buffer
    % phase into the culture's phase to according to the culture's 
    % calculated growth rate.
    
    properties
        % parent system reference
        oParent;
        
        % species to be extracted
        arExtractPartials;
        
        % 
        fExtractionRate = 0;
    end
    
    methods
        function this = BiomassGrowth(oParent, oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);

            this.oParent = oParent;
             
            % set 1 for substance to extract
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.BiomassBalance) = 1;
        end
        
        function update(this) 
            % extract specified substance with desired flow rate
            this.setMatterProperties(this.fExtractionRate, this.arExtractPartials);
        end
    end
end