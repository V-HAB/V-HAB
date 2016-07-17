classdef GasExchange < matter.procs.p2p
    % This p2p processor moves "general" biomass from the biomass buffer
    % phase into the culture's phase to according to the culture's 
    % calculated growth rate.
    
    properties
        % parent system reference
        oParent;
        
        % species to be extracted
        arExtractPartialsO2;
        arExtractPartialsCO2;
        arExtractPartialsH2O;
    end
    
    methods
        function this = GasExchange(oParent, oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            this@matter.procs.p2p(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);

            this.oParent = oParent;
            
            % set 1 for substance to extract
            this.arExtractPartialsO2 = zeros(1, this.oMT.iSubstances);
            this.arExtractPartialsO2(this.oMT.tiN2I.O2) = 1;
            this.arExtractPartialsCO2 = zeros(1, this.oMT.iSubstances);
            this.arExtractPartialsCO2(this.oMT.tiN2I.CO2) = 1;
            this.arExtractPartialsH2O = zeros(1, this.oMT.iSubstances);
            this.arExtractPartialsH2O(this.oMT.tiN2I.H2O) = 1;
        end
        
        function update(this) 
            % extract specified substance with desired flow rate
            this.setMatterProperties(this.oParent.tfGasExchangeRates.fO2ExchangeRate,       this.arExtractPartialsO2);
            this.setMatterProperties(this.oParent.tfGasExchangeRates.fCO2ExchangeRate,      this.arExtractPartialsCO2);
            this.setMatterProperties(this.oParent.tfGasExchangeRates.fTranspirationRate,    this.arExtractPartialsH2O);
        end
    end
end