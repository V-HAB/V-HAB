classdef ConvertBiomass < matter.manips.substance.flow
    % This manipulator converts "general" biomass entering the culture 
    % phase from the biomass buffer phase into the culture's specific
    % biomass (lettuce, wheat, etc.).
    
    properties
    end
    
    methods
        function this = ConvertBiomass(oParent, sName)
            this@matter.manips.substance.flow(oParent, sName);
        end
    end
end