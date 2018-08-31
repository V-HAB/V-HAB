classdef filter < matter.procs.p2ps.flow
    %ABSORBEREXAMPLE An example for a p2p processor implementation
    %   The actual logic behind the absorbtion behavior is not based on any
    %   specific physical system. It is just implemented in a way to
    %   demonstrate the use of p2p processors
    %
    %TODO implement priorities / filter ratios, e.g. if H2O is filtered
    %     first and then CO2
    
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
        % loaded bed, 1 = linear, 2 exponential etc.)
        fCharacteristics = 1;
    end
    
    
    methods
        function this = filter(oStore, sName, sPhaseIn, sPhaseOut, sSubstance, fCapacity, fCharacteristics)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
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
        
        
        function arFilterRates = calculateFilterRatesXXX(this, sPhase)
            % Calculates the ratio of filtered flow rate (by adsorption,
            % absorption, ...) for each connected branch.
            %
            % Cannot be used if manip exists in phase!
            
            if (nargin < 2) || isempty(sPhase), sPhase = 'in'; end
            
            iSubstance  = this.oMT.tiN2I.(this.sSubstance);
            rFilterLoad = sif(this.fCapacity == 0, 1, this.oOut.oPhase.afMass(iSubstance) / this.fCapacity);
            
            % Calculate filter rate
            if this.fCharacteristics > 0
                rFilterRate = (1 - rFilterLoad^this.fCharacteristics);
            else
                rFilterRate = 1;
            end
            
            
            % Get connected branch compositions
            oPhase        = sif(strcmp(sPhase, 'in'), this.oIn.oPhase, this.oOut.oPhase);
            arFilterRates = zeros(oPhase.iProcsEXME, 1);
            
            
            for iI = 1:oPhase.iProcsEXME
                % Hmm other p2p? Ignore!
                if isa(oPhase.coProcsEXME{iI}.oFlow, 'matter.procs.p2p')
                    continue;
                end
                
                % Need to get the composition of the flow stream from the
                % opposite phase! The coeff is only valid/used for
                % INflowing flow rates!
                oB = oPhase.coProcsEXME{iI}.oFlow.oBranch;
                iE = sif(oB.coExmes{1}.oPhase == oPhase, 2, 1);
                
                arFlowPartials = oB.coExmes{iE}.oPhase.arPartialMass;
                
                % arFlowPartials is ratio/% of the filtered substance in
                % the connected branch.
                arFilterRates(iI) = arFlowPartials(iSubstance) * rFilterRate;
            end
            
            
            arFilterRates = tools.round.prec(arFilterRates, this.oIn.oTimer.iPrecision);
            
            %disp(arFilterRates(arFilterRates ~= 0));
        end
        
        
        
        
        
        function [ fFlowRate, arExtractPartials ] = calculateFilterRate(this, afFlowRate, mrPartials)
            %disp('>>>>');
            %disp(mrPartials);
            %disp('<<<<');
            arExtractPartials = this.arExtractPartials;
            %arExtractPartials = mrPartials;
            
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
            
            %this.rLoad = 0;
            
            % Test ...
            %this.rLoad = 0;
            
            
            % Nothing flows in, so nothing absorbed ...
            if isempty(afFlowRate)
                fFlowRate = 0;
                %this.setMatterProperties(0, this.arExtractPartials);
                
                return;
            end
            
            % Now multiply the flow rates with the according partial mass
            % of the substance extracted. Then we have several flow rates,
            % representing exactly the amount of the mass of the according
            % species flowing into the filter.
            afFlowRate = afFlowRate .* mrPartials(:, iSpecies);
            %%COMMENT
            
            
            if this.fCharacteristics > 0
                rAdsorp = (1 - this.rLoad^this.fCharacteristics);
            else
                rAdsorp = 1;
            end
            
            %keyboard();
            % Sum up flow rates and use the load of the filter to reduce 
            % the flow rate accordingly
            fFlowRate = rAdsorp * sum(afFlowRate);
            
            
            
            % ROUND
            %fFlowRate = tools.round.prec(fFlowRate, this.oIn.oTimer.iPrecision);
            
            if ~base.oLog.bOff
                this.out(1, 1, 'calc-fr', 'p2p calc flowrate of %s, ads rate %f is: %.34f', { this.sName, rAdsorp, fFlowRate });
                this.out(1, 2, 'calc-fr', '%.16f\t', { afFlowRate });
            end
        end
        
        function update(this)
            
            if ~base.oLog.bOff, this.out(1, 1, 'set-fr', 'p2p update flowrate of %s', { this.sName }); end
            %keyboard();
            [ afFlowRate, aarPartials ] = this.getInFlows();
            
            
            [ fFlowRate, ~ ] = this.calculateFilterRate(afFlowRate, aarPartials);
            
            
            % Test ...
            %fFlowRate = 0;
            %fprintf('[%i|%fs] p2p! In Phase last massupd %.12f, last update %.12f !!\n', this.oIn.oTimer.iTick, this.oIn.oTimer.fTime, this.oIn.oPhase.fLastMassUpdate, this.oIn.oPhase.fLastUpdate);
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
    
end

