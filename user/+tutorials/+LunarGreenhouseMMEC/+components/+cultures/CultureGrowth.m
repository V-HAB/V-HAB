classdef CultureGrowth < matter.procs.p2p
    % This p2p processor moves "general" biomass from the biomass buffer
    % phase into the culture's phase to according to the culture's 
    % calculated growth rate.
    
    properties
        % mass flow property to be set from the parent system
        fMassFlow = 0;
        
        % species to be extracted
        arExtractPartials;
    end
    
    methods
        function this = CultureGrowth(oParent, sName, sPhaseAndPortIn, sPhaseAndPortOut, sSubstance)
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