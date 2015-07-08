classdef AbsorbingO2 < matter.procs.p2ps.flow
    %Derived from 'AbsorberExample' --> V-HAB Tutorial
    %   The actual logic behind the absorbtion behavior is not based on any
    %   specific physical system. It is just implemented in a way to
    %   demonstrate the use of p2p processors
    
    properties 
        % Substance to absorb
            sSubstance;
        
        % Setting the absorption rate of the absorber
            fO2AbsorptionRate;
            
        % Defines which species are extracted
            arExtractPartials;
        
    end
    
    
    methods
        function this = AbsorbingO2(oStore, sName, sPhaseIn, sPhaseOut, sSubstance)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            % Species to absorb, max absorption
                this.sSubstance  = sSubstance;
            
            
           
            % The p2p processor can specify which species it wants to
            % extract from the phase. A vector with relative values has to
            % be provided, with the sum of all ratios being 1 (see the
            % matter.phase.arPartialMass vector) ...
                this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            % ... in this case using a vector with zeros at all indices
            % except the one holding the partial mass for the species we
            % want to extract - which is set to 1, i.e. only this species
            % is extracted.
           
        end
        
        function update(this)
            % Called whenever a flow rate changes. The two EXMES (oIn/oOut)
            % have an oPhase attribute that allows us to get the phases on
            % the left/right side.
            % Here, the oIn is always the air phase, the oOut is the solid
            % absorber phase.
                this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance)) = 1;
            %this.fwater_exchange/(this.fwater_exchange+this.fO2_exchange+10^-16);
            %this.fwater_exchange/(this.fwater_exchange+this.fO2_exchange+this.fCO2_exchange);
            % The tiN2I maps the name of the species to the according index
            % in all the matter table vectors!
                iSubstance = this.oMT.tiN2I.(this.sSubstance);
            
            
            % Get all positive (i.e. inflowing) flow rates and the
            % according partial masses. Flow rates are a row vector,
            % partials are a matrix - each row represents one flow, the
            % columns represent the different species.
                [ afFlowRate, mrPartials ] = this.getInFlows();
            
            % Nothing flows in, so nothing absorbed ...
                if isempty(afFlowRate)
                    this.setMatterProperties(0, this.arExtractPartials);

                    return;
                end
            
            % Now multiply the flow rates with the according partial mass
            % of the species extracted. Then we have several flow rates,
            % representing exactly the amount of the mass of the according
            % species flowing into the filter.
                afFlowRate = afFlowRate .* mrPartials(:, iSubstance);
            
            %keyboard();
            % Sum up flow rates and use the load of the filter to reduce 
            % the flow rate accordingly
                fFlowRate =  this.fO2AbsorptionRate; % [kg/s]
           
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
                this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
    
end

