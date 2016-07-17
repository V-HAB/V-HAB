classdef CultureHarvest < matter.procs.p2p
    % This p2p processor moves biomass from the culture's phase into edible
    % or inedible biomass phase
    
    properties
        % mass flow property to be set from the parent system
        fMassFlow = 0;
        
        % substance to extract
        arExtractPartials;
    end
    
    methods
        function this = CultureHarvest(oParent, sName, sPhaseAndPortIn, sPhaseAndPortOut, sSubstance)
            this@matter.procs.p2p(oParent, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            
            % set 1 for substance to extract
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.(sSubstance)) = 1;
        end
        
        function update(this)
            % extract specified substance with desired flow rate
            this.setMatterProperties(this.fMassFlow, this.arExtractPartials);
        end
    end
end