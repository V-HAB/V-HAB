classdef AbsorberExample < matter.procs.p2ps.stationary
    %ABSORBEREXAMPLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        % Substance to absorb
        sSubstance;
        
        % Max absorb capacity in kg
        fCapacity;
        
        % Max absorption rate in kg/s/Pa, partial pressure of the species
        % to absorb
        % Default 1e-3 (to g) * 1e-5 (20000 Pa) -> 2g/s?
        %NOTE not used yet ...
        fMaxAbsorption = 1e-3 * 1e-5 * 1e-1;
        
        % Defines which species are extracted
        arExtractPartials;
        
        
        rLoad;
        
        oParent;
    end
    
    
    methods
        function this = AbsorberExample(oParent, oStore, sName, sPhaseIn, sPhaseOut, sSubstance, fCapacity)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.oParent = oParent;
            
            % Species to absorp, max absorption
            this.sSubstance  = sSubstance;
            this.fCapacity   = fCapacity;
            
            % The p2p processor can specify which species it wants to
            % extract from the phase. A vector with relative values has to
            % be provided, with the sum of all ratios being 1 (see the
            % matter.phase.arPartialMass vector) ...
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            % ... in this case using a vector with zeros at all indices
            % except the one holding the partial mass for the substances we
            % want to extract - which is set to 1, i.e. only this substance
            % is extracted.
            this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance)) = 1;
        end
        
        function update(this)
            % Called whenever a flow rate changes. The two EXMES (oIn/oOut)
            % have an oPhase attribute that allows us to get the phases on
            % the left/right side.
            % Here, the oIn is always the air phase, the oOut is the solid
            % absorber phase.
            
            % The tiN2I maps the name of the substances to the according index
            % in all the matter table vectors!
            iSubstances = this.oMT.tiN2I.(this.sSubstance);
            
            % Get the mass on the absorber phase (could use oPhase.fMass
            % instead of afMass(X), btw) to determine load.
            this.rLoad = this.oOut.oPhase.afMass(iSubstances) / this.fCapacity;
            
            if this.fCapacity == 0
                this.rLoad = 1;
            end
            
            %this.rLoad = 0;
            
            % Test ...
            %this.rLoad = 0;
            
            % Get all positive (i.e. inflowing) flow rates and the
            % according partial masses. Flow rates are a row vector,
            % partials are a matrix - each row represents one flow, the
            % columns represent the different substances.
            [ afInFlowrates, mrInPartials ] = getInFlows();
            
            afPartialInFlows = sum(afInFlowrates .* mrInPartials,1);
            
            % Nothing flows in, so nothing absorbed ...
            if isempty(afPartialFlowRates)
                this.setMatterProperties(0, this.arExtractPartials);
                
                return;
            end
            
            
            % Sum up flow rates and use the load of the filter to reduce 
            % the flow rate accordingly
            fFlowRate = (1 - this.rLoad) * sum(afPartialFlowRates(:, iSubstances));
            
            % If we do nothing else, there will be a huge spike in the 
            % adsorption rate at the beginning of the simulation, because 
            % the timestep will be really small and the amount of CO2 
            % relatively huge. So we set a maximum flow rate to make the
            % plots look nicer. 
            if fFlowRate > 0.000003
                fFlowRate = 0.000003;
            end
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all substances
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
    
end

