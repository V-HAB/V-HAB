classdef BiomassSplit < matter.procs.p2p
    properties
        arExtractPartials;
    end
    
    methods
        function this = BiomassSplit(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            this@matter.procs.p2p(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
        end
        
        function update(this)
            
        end
    end
end