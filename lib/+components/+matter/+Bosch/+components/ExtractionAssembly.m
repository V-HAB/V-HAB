classdef ExtractionAssembly < matter.procs.p2ps.flow
    % General Extraction Assembly used for H2 CO2 and H2O
    % 
    %   assumption:
    % 60% of the H2 is recovered
    % CO2 80% is recovered
    % H2O 100% is recovered
   
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Set the Substance to absorb as H2. 
        sSubstance;
        
        % Defines which species are extracted
        arExtractPartials = [];
        
        rEfficiency = 1;
    end
    
    methods
        
        function this = ExtractionAssembly(oStore, sName, sPhaseIn, sPhaseOut, sSubstance, rEfficiency)
            
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
          
            % The p2p processor can specify which substance it wants to
            % extract from the phase. A vector with relative values has to
            % be provided, with the sum of all ratios being 1 (see the
            % matter.phase.arPartialMass vector) ...
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            this.sSubstance = sSubstance;
            this.rEfficiency = rEfficiency;
            
            % ... in this case using a vector with zeros at all indices
            % except the one holding the partial mass for the substances we
            % want to extract - which is set to 1, i.e. only this substance
            % is extracted.
            this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance)) = 1;
            
        end
        
        function calculateFlowRate(this, afInFlowRates, aarInPartials, ~, ~)
            
            afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);

%             afCurrentMolsIn     = (this.afPartialInFlows ./ this.oMT.afMolarMass);
%             arFractions         = afCurrentMolsIn ./ sum(afCurrentMolsIn);
%             afPP                = arFractions .*  fPressure; 
            
            % Nothing flows in, so nothing absorbed ...
            if sum(afPartialInFlows) == 0
                this.setMatterProperties(0, this.arExtractPartials);
                return;
            end
            
            % In this case the amount of absorbed substance is independent
            % of the Load of the Filter, because we set 60% of the incoming
            % H2 is absorbed (using literature values).
            fFlowRate = this.rEfficiency * afPartialInFlows(this.oMT.tiN2I.(this.sSubstance));
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all substances
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
        end
    end
        
    methods (Access = protected)
        function update(~)
        end
    end
end