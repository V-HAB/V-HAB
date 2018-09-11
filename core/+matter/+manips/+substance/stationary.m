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
        
        function update(this, afPartialFlows)
            % Checking if any of the flow rates being set are NaNs. It is
            % necessary to do this here so the origin of NaNs can be found
            % easily during debugging. 
            if any(isnan(afPartialFlows))
                error('Error in manipulator %s. Some of the flow rates are NaN.', this.sName);
            end
            
            this.afPartialFlows = afPartialFlows;
        end
    end
    
    methods (Access = protected)
        function afMass = getTotalMasses(this)
            % Get all inward mass flows multiplied with the time step and 
            % add them the stored partial masses to get an absolute value 
            % in kg. 
            
            [ afMasses, mrInPartials ] = this.getMasses();
            
            
            if ~isempty(afMasses)
                afMass = sum(bsxfun(@times, afMasses, mrInPartials), 1);
            else
                afMass = zeros(1, this.oMT.iSpecies);
            end
            
        end
    end
    
end

