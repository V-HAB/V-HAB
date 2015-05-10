classdef co2_outlet < matter.procs.p2ps.flow
    properties (SetAccess = protected, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
    end
    
    
    methods
        function this = co2_outlet(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            % Preparation, see tutorials
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.CO2) = 1;
        end
        
        function update(this)
            % Just exhales all CO2
            [ afFlowRate, mrPartials ] = this.getInFlows();
            
            % Nothing flows in, so nothing absorbed ...
            if isempty(afFlowRate)
                this.setMatterProperties(0, this.arExtractPartials);
                
                return;
            end
            
            %TODO check if some CO2 in that phase, if yes, little more
            %     outflow? Just that it's cleaned out within a few seconds
            %     or so - solver/phase will automatically re-trigger this
            %     .update method if CO2 becomes too little
            fFlowRate = 0.8 * sum(afFlowRate .* mrPartials(:, this.oMT.tiN2I.CO2));
            %CHECK for the 80% -> see o2_to_co2 partial manip in this pkg!
            
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
    
end

