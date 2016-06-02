classdef HourlyRatesMMEC < matter.procs.p2p
    % This p2p processor transports mass into or out from the biomass
    % balance phase. The mass flow rates correspond to the hourly rates
    % calculated using the MMEC equations ("Modified energy cascade model 
    % adapted for a multicrop Lunar greenhouse prototype", G. Boscheri et 
    % al., 2012)
    
    properties
        % mass flow property to be set from the parent system
        fMassFlow = 0;
        
        % which substance to extract
        arExtractPartials;
    end
    
    methods
        function this = HourlyRatesMMEC(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut, sSubstance)
            this@matter.procs.p2p(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            
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