classdef WaterAbsorber < matter.procs.p2ps.flow
    % This p2p processor moves "general" biomass from the biomass buffer
    % phase into the culture's phase to according to the culture's 
    % calculated growth rate.
    
    properties
        % parent system reference
        oParent;
        
        % species to be extracted
        arExtractPartials;
    end
    
    methods
        function this = WaterAbsorber(oParent, oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);

            this.oParent = oParent;
            
            % set 1 for substance to extract
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.H2O) = 1;
        end
        
        function update(this) 
            % get inflow rates
            [ afFlowRate, mrPartials ] = this.getInFlows();
            
            if isempty(afFlowRate)
                this.setMatterProperties(0, this.arExtractPartials);

                return;
            end
                
            afFlowRate = afFlowRate .* mrPartials(:, this.oMT.tiN2I.H2O);
            
            % completely extract inflowing H2O
            this.setMatterProperties(sum(afFlowRate), this.arExtractPartials);
        end
    end
end