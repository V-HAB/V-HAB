classdef o2_to_co2 < matter.manips.partial
    %SOMEABSORBEREXAMPLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    
    methods
        function this = o2_to_co2(sName, oPhase)
            this@matter.manips.partial(sName, oPhase);
        end
        
        function update(this)
            % Helper vars
            afFlowRate  = this.getTotalFlowRates();
            tiN2I       = this.oPhase.oMT.tiN2I;
            afMolMass   = this.oPhase.oMT.afMolMass;
            afFlowRates = zeros(1, this.oPhase.oMT.iSpecies);
            
            
            % Getting the total O2 mass in the phase (inflowing plus
            % already existing mass)
            %CHECK don't all O2, assuming some is converted to water (how
            %      much is that)? So just convert e.g. 80% of O2 to CO2,
            %      but when trying this - very slow sim. So just done in 
            %      CO2 outlet, i.e. only 80% of CO2 exhaled.
            %fO2 = 0.8 * afFlowRate(tiN2I.O2);
            fO2 = afFlowRate(tiN2I.O2);
            
            % Production of CO2
            fCO2 = fO2 * afMolMass(tiN2I.CO2) / afMolMass(tiN2I.O2);
            
            % Need to add some C
            fC = fCO2 * afMolMass(tiN2I.C) / afMolMass(tiN2I.CO2);
            
            
            % Set the according flow rates and pass to parent
            afFlowRates(tiN2I.O2)  = -1 * fO2;
            afFlowRates(tiN2I.C)   = -1 * fC;
            afFlowRates(tiN2I.CO2) = fCO2;
            
            update@matter.manips.partial(this, afFlowRates);
        end
    end
    
end

