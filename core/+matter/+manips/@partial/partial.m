classdef partial < matter.manip
    %PARTIAl
    %
    %TODO
    %   - differences for solid, gas, liquid ...?
    %   - helpers for required energy, catalyst, produced energy, etc, then
    %     some energy object input for e.g. heat
    
    
    properties (SetAccess = private, GetAccess = public)
        % Changes in partial masses in kg/s
        afPartial;
    end
    
    methods
        function this = partial(sName, oPhase)
            this@matter.manip(sName, oPhase);
        end
        
        function update(this, afPartial)
            this.afPartial = afPartial;
        end
    end
    
    methods (Access = protected)
        function afFlowRate = getTotalFlowRates(this)
            % Get all inwards and the stored partial masses as total kg/s
            % values.
            
            [ afFlowRates, mrInPartials ] = this.getInFlows();
            
            
            afFlowRate = sum(bsxfun(@times, afFlowRates, mrInPartials), 1);
            
        end
    end
end

