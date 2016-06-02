classdef ConvertBiomass < matter.manips.substance.flow
    % This manipulator converts "general" biomass entering the culture 
    % phase from the biomass buffer phase into the culture's specific
    % biomass (lettuce, wheat, etc.).
    
    properties
        % parent system reference containing the manipulator
        oParent;
    end
    
    methods
        function this = ConvertBiomass(oParent, sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            
            this.oParent = oParent;
        end
    end
end