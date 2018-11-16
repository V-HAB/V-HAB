classdef AbsorberExample < matter.procs.p2ps.stationary & event.source
    %ABSORBEREXAMPLE An example for a p2p processor implementation
    %   The actual logic behind the absorbtion behavior is not based on any
    %   specific physical system. It is just implemented in a way to
    %   demonstrate the use of p2p processors
    
    properties (SetAccess = protected, GetAccess = public)
        % Substance to absorb
        sSubstance;
        
        % Maximum absorb capacity in kg
        fCapacity;
        
        % Max absorption rate in kg/s/Pa, partial pressure of the substance
        % to absorb
        %NOTE not used yet ...
        fMaxAbsorption = 1e-9;
        
        % Defines which substances are extracted
        arExtractPartials;
        
        % Ratio of actual loading and maximum load
        rLoad;
        
        
        % Exponent for characeristics (e.g. 0 -> no reduction through
        % loaded bed, 1 = linear,2 exponential etc.)
        fCharacteristics = 1;
    end
    
    
    methods
        function this = AbsorberExample(oStore, sName, sPhaseIn, sPhaseOut, sSubstance, fCapacity, fCharacteristics)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
            
            % Species to absorb, max absorption
            this.sSubstance  = sSubstance;
            this.fCapacity = fCapacity;
            
            if nargin >= 7
                this.fCharacteristics = fCharacteristics;
            end
            
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
        
        function update(this)
            
            %disp(this.oStore.oTimer.iTick);
            %disp('--------- P2P UPDATE pre ----------------');
            
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
            
            if this.fCapacity == 0, this.rLoad = 1; end;
            
            %this.rLoad = 0;
            
            % Test ...
            %this.rLoad = 0;
            
            % Get all positive (i.e. inflowing) flow rates and the
            % according partial masses. Flow rates are a row vector,
            % partials are a matrix - each row represents one flow, the
            % columns represent the different substances.
            [ afFlowRate, mrPartials ] = this.getInFlows();
            
            % Nothing flows in, so nothing absorbed ...
            if isempty(afFlowRate)
                this.setMatterProperties(0, this.arExtractPartials);
                this.trigger('update', 0);
                
                return;
            end
            
            % Now multiply the flow rates with the according partial mass
            % of the substance extracted. Then we have several flow rates,
            % representing exactly the amount of the mass of the according
            % species flowing into the filter.
            afFlowRate = afFlowRate .* mrPartials(:, iSpecies);
            
            
            if this.fCharacteristics > 0
                rAdsorp = (1 - this.rLoad^this.fCharacteristics);
            else
                rAdsorp = 1;
            end
            
            %keyboard();
            % Sum up flow rates and use the load of the filter to reduce 
            % the flow rate accordingly
            fFlowRate = rAdsorp * sum(afFlowRate);
            
            % Test ...
%             if this.oIn.oPhase.oTimer.iTick > 30
%                 fFlowRate = 1e-5;
%             else
%                 fFlowRate = 0;
%             end
            
            %%%disp([ 'UPDATE p2p: ' this.sName ' to ' num2str(fFlowRate) ]);
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            if fFlowRate < 0
                fMassChangeSinceUpdate = this.oOut.oPhase.afCurrentTotalInOuts(iSpecies) * (this.oTimer.fTime - this.oOut.oPhase.fLastMassUpdate);
                fTimeStep = abs((this.oOut.oPhase.afMass(iSpecies) + fMassChangeSinceUpdate) / fFlowRate);
                this.oOut.oPhase.oStore.setNextTimeStep(fTimeStep);
            end
            
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            
            this.trigger('update', fFlowRate);
            
            %disp('--------- P2P UPDATE post ----------------');
        end
    end
    
end

