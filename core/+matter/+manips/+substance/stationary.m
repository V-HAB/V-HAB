classdef stationary < matter.manips.substance
    %STATIONARY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        afPartialFlows;
    end
    
    methods
        function this = stationary(sName, oPhase)
            this@matter.manips.substance(sName, oPhase);
            
        end
    end
    
    methods (Access = protected)
        function afMass = getTotalMasses(this)
            % Get all inwards and the stored partial masses as total kg/s
            % values.
            
            [ afMasses, mrInPartials ] = this.getMasses();
            
            
            if ~isempty(afMasses)
                afMass = sum(bsxfun(@times, afMasses, mrInPartials), 1);
            else
                afMass = zeros(1, this.oPhase.oMT.iSpecies);
            end
            
        end
    end
    
end

