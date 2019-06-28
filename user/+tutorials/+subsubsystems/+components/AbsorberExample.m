classdef AbsorberExample < matter.procs.p2ps.stationary
    %ABSORBEREXAMPLE An example for a p2p processor implementation
    %   The actual logic behind the absorbtion behavior is not based on any
    %   specific physical system. It is just implemented in a way to
    %   demonstrate the use of p2p processors
    
    properties (SetAccess = protected, GetAccess = public)
        % Substance to absorb
        sSubstance;
        
        % Maximum absorb capacity in kg
        fCapacity;
        
        % Defines which substances are extracted
        arExtractPartials;
        
        % Ratio of actual loading and maximum load
        rLoad;
    end
    
    
    methods
        function this = AbsorberExample(oStore, sName, sPhaseIn, sPhaseOut, sSubstance, fCapacity)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
            
            % Species to absorb, max absorption
            this.sSubstance  = sSubstance;
            this.fCapacity = fCapacity;
            
            % The p2p processor can specify which substance it wants to
            % extract from the phase. A vector with relative values has to
            % be provided, with the sum of all ratios being 1 (see the
            % matter.phase.arPartialMass vector) ...
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            % ... in this case using a vector with zeros at all indices
            % except the one holding the partial mass for the substance we
            % want to extract - which is set to 1, i.e. only this species
            % is extracted.
            this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance)) = 1;
        end
    end
    
    methods (Access = protected)
        function update(this)
            % Called whenever a flow rate changes. The two EXMES (oIn/oOut)
            % have an oPhase attribute that allows us to get the phases on
            % the left/right side.
            % Here, the oIn is always the air phase, the oOut is the solid
            % absorber phase.
            
            % The tiN2I maps the name of the substance to the according index
            % in all the matter table vectors!
            iSpecies = this.oMT.tiN2I.(this.sSubstance);
            
            % Get the mass on the absorber phase (could use oPhase.fMass
            % instead of afMass(X), btw) to determine load.
            this.rLoad = this.oOut.oPhase.afMass(iSpecies) / this.fCapacity;
            
            if this.fCapacity == 0, this.rLoad = 1; end
            
            % Get all positive (i.e. inflowing) flow rates and the
            % according partial masses. Flow rates are a row vector,
            % partials are a matrix - each row represents one flow, the
            % columns represent the different substances.
            [ afFlowRate, mrPartials ] = this.getInFlows();
            
            % Nothing flows in, so nothing absorbed ...
            if isempty(afFlowRate)
                this.setMatterProperties(0, this.arExtractPartials);
                
                return;
            end
            
            % Now multiply the flow rates with the according partial mass
            % of the substance extracted. Then we have several flow rates,
            % representing exactly the amount of the mass of the according
            % species flowing into the filter.
            afFlowRate = afFlowRate .* mrPartials(:, iSpecies);
            
            % Sum up flow rates and use the load of the filter to reduce 
            % the flow rate accordingly
            fFlowRate = exp(-this.rLoad) * sum(afFlowRate);
            
            % If the calculated flow rate is below the global precision
            % threshold, we just set it to zero. 
            if tools.round.prec(fFlowRate, this.oStore.oTimer.iPrecision) == 0
                fFlowRate = 0;
            end
            
            % Since an actual absorbtion behavior is not modeled here, we
            % can do whatever we want. Turns out the absorption speed was
            % way to high, so we just devide it by four. 
            fFlowRate = fFlowRate / 4;

            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
    
end

