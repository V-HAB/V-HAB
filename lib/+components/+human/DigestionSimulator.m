classdef DigestionSimulator < matter.manips.substance.flow
    
    % A phase manipulator to simulate conversion of food to
    % feces,urine,carbon dioxide and metabolic water due to 
    % metabolic stoichiometric reactions of oxidation of 
    % carbohydrates, fats, proteins
    %    
    % C6H12O6 (carbohydrates)  + 6  O2     =    6 CO2 + 6H2O
    % C16H32O2 (fats)          + 23 O2     =    16 CO2 + 16H20
    % 2C4H5ON  (protein)       + 7  O2     =    C2H6O2N2 (urine solids) + 6CO2 + 2H2O 
    %
    % 5C4H5ON + C6H12O6 + C16H32O2 = C42H69O13N5 (feces solids composition)
    properties (SetAccess = protected, GetAccess = public)
        
        % According to BVAD page 50 table 3.26 each crew member produces
        % 132 g of feces per day that consist of 32g solids and 100 g water
        fFecesWaterPercent = 0.746;     
        fUrineWaterPercent = 0.9644;    
        
        fTotalMassError = 0;
    end
    
    methods
        function this = DigestionSimulator(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            
            this.afPartialFlows= zeros(1, this.oPhase.oMT.iSubstances);
            
            
        end

        
        function update(this)
            % Takes data from the crew
            
            afPartialFlows= zeros(1, this.oPhase.oMT.iSubstances);
            
            % for debugging purposes we store the total mass error this
            % manipulator produced from numerical errors
            this.fTotalMassError = this.fTotalMassError + sum(afPartialFlowRates);
            
            
            update@matter.manips.substance.flow(this, afPartialFlowRates);
            
        end
    end
end