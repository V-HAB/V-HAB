classdef WeakBaseAnion_P2P < matter.procs.p2ps.flow
    
    %% WBA P2P doing ion exchange in the Multifiltration beds based on
    % DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER PROCESSOR
    % written by David Robert Hokanson
    
    properties (SetAccess = public, GetAccess = public)
        
        afExchangeRateConstants; % [(m^3)^2 / eq^2]
        % Matrix containing the exchange rate constants for each ion in the
        % columns, and each row represents an ion. For the row all exchange
        % rate constant are represent in its column except for the exchange
        % rate constant of that ion itself
        mfExchangeRateConstants; % [(m^3)^2 / eq^2]
        
        % Vector containing the seperation factors for each ion
        afSeperationFactors;
        % Matrix containing the division of the specific ion seperation
        % factor with all other seperations factors as rows
        mfSeperationFactors;
        
        % total Volume of the cell 
        fCellVolume; % [m^3]
        % The void fraction of the cell volume (cell volume is the volume
        % of resin and fluid)
        rVoidFraction; % [-]
        % Resin mass (not the ion mass)!
        fResinMass; % [kg]
        
        % Boolean vector to find the specific ions from the V-HAB vectors
        abIons;
        
        % Stores the index of the presaturant for this bed
        iPresaturant;
        fInitialPresaturantMass;
        
        % Total Capacity in [eq/kg] 
        fTotalCapacity;
        
        % Object reference to the P2P handling desorption:
        oDesorptionP2P;
    end
    
    methods
        function this = WeakBaseAnion_P2P(oStore, sName, sPhaseIn, sPhaseOut, oDesorptionP2P)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn,sPhaseOut);
            
            this.oDesorptionP2P = oDesorptionP2P;
            this.rVoidFraction 	= oStore.oContainer.rVoidFraction;
            this.fResinMass     = oStore.oContainer.fResinMass      / oStore.oContainer.iCells;
            this.fCellVolume    = oStore.oContainer.fVolume         / oStore.oContainer.iCells;
            this.fTotalCapacity = oStore.oContainer.fTotalCapacity  / oStore.oContainer.iCells;
            this.iPresaturant   = oStore.oContainer.iPresaturant;
            this.fInitialPresaturantMass = this.oOut.oPhase.afMass(this.iPresaturant);
            
            % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
            % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
            % PROCESSOR", David Robert Hokanson, 2004, Table 2-16
            % The values in the table are given in L^2/meq^2 we convert it
            % into m^3 / eq. Since the conversion of L to m^3 is 1000 and
            % of meq to eq is also 1000, the conversion factor becomes 1!
            this.afExchangeRateConstants = zeros(1, this.oMT.iSubstances);
            this.afExchangeRateConstants(this.oMT.tiN2I.CMT)      = 3.44e4;
            this.afExchangeRateConstants(this.oMT.tiN2I.Clminus)  = 1.06e3;
            this.afExchangeRateConstants(this.oMT.tiN2I.C4H7O2)   = 541; % Butyrate
            this.afExchangeRateConstants(this.oMT.tiN2I.C2H3O2)   = 588; % Acetate
            this.afExchangeRateConstants(this.oMT.tiN2I.SO4)      = 1.47e4;
            this.afExchangeRateConstants(this.oMT.tiN2I.C3H5O3)   = 382; % Lactate
            
            
            this.mfExchangeRateConstants = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            this.mfExchangeRateConstants(this.oMT.tiN2I.CMT,        :)	= this.afExchangeRateConstants;
            this.mfExchangeRateConstants(this.oMT.tiN2I.Clminus,    :)	= this.afExchangeRateConstants;
            this.mfExchangeRateConstants(this.oMT.tiN2I.C4H7O2,     :) 	= this.afExchangeRateConstants;
            this.mfExchangeRateConstants(this.oMT.tiN2I.C2H3O2,     :) 	= this.afExchangeRateConstants;
            this.mfExchangeRateConstants(this.oMT.tiN2I.SO4,        :)	= this.afExchangeRateConstants;
            this.mfExchangeRateConstants(this.oMT.tiN2I.C3H5O3,     :)	= this.afExchangeRateConstants;
            % This variable is used to calculate the sum of the exchange
            % rate constants and the concentrations without the ion in
            % consideration itself. Therefore we set the diagonal entries
            % to 0
            this.mfExchangeRateConstants(logical(eye(this.oMT.iSubstances))) = 0;
            
            % Note that the seperation factors are not use in the
            % calculation, but in case they are required for future
            % calculations they were still added here!
            %
            % The seperation factors are again unitless and from the same
            % table as the exchange rate constants
            this.afSeperationFactors = zeros(1, this.oMT.iSubstances);
            this.afSeperationFactors(this.oMT.tiN2I.CMT)      = 32.4;
            this.afSeperationFactors(this.oMT.tiN2I.Clminus)  = 1;
            this.afSeperationFactors(this.oMT.tiN2I.C4H7O2)   = 0.510; % Butyrate
            this.afSeperationFactors(this.oMT.tiN2I.C2H3O2)   = 0.555; % Acetate
            this.afSeperationFactors(this.oMT.tiN2I.SO4)      = 13.9;
            this.afSeperationFactors(this.oMT.tiN2I.C3H5O3)   = 0.360; % Lactate

            this.abIons = (this.afSeperationFactors ~= 0);
            
            this.mfSeperationFactors = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            this.mfSeperationFactors(this.abIons, this.abIons) = this.afSeperationFactors(this.abIons)' ./ this.afSeperationFactors(this.abIons);
            this.mfSeperationFactors(logical(eye(this.oMT.iSubstances))) = 0;
        end
        
        function calculateFlowRate(this, afInsideInFlowRate, aarInsideInPartials, ~, ~)
            
            % calculate the current inflows
            afPartialInFlows = sum((afInsideInFlowRate .* aarInsideInPartials),1);
            afPartialInFlows = afPartialInFlows + this.oIn.oPhase.toManips.substance.afPartialFlows;
            afPartialInFlows(afPartialInFlows < 0) = 0;
            
            % Now we calculate the total molar equivalents flowing in the
            % liquid [mol * valence / s]
            afEquivalentInletFlows = zeros(1, this.oMT.iSubstances);
            afEquivalentInletFlows(this.abIons)  = (afPartialInFlows(this.abIons) ./ this.oMT.afMolarMass(this.abIons)) .* abs(this.oMT.aiCharge(this.abIons));

            fDensity = this.oMT.calculateDensity(this.oIn.oPhase);
            fVolumetricFlowRate = sum(afPartialInFlows) / fDensity; % [m^3/s]

            fInletHplusConcentration = ((afPartialInFlows(this.oMT.tiN2I.Hplus) / this.oMT.afMolarMass(this.oMT.tiN2I.Hplus)) * abs(this.oMT.aiCharge(this.oMT.tiN2I.Hplus))) / fVolumetricFlowRate;

            % We also require the current resin phase masses of the
            % adsorbents:
            oAdsorber = this.oOut.oPhase;

            % The following iterative scheme is based on:
            % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
            % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
            % PROCESSOR", David Robert Hokanson, 2004, Equation (VI-41)
            % and Equation (VI-22), which provides the equilibrium
            % condition used to calculate an initial guess for the
            % outlet concentration.
            %
            % Since the outlet concentration are unknown if we do not
            % model the fluid phase as a mass containing phase (which
            % would result in quite slow calculations) an iterative
            % solution process is required to solve the adsorption
            % flowrates. In addition the equation was adjusted to
            % directly calculate the adsorption flowrates of each Ion.
            % Only once these flowrates have converged do we calculate
            % the presaturant desorption flowrate.

            % Initial assumption for the outlet concentrations of the
            % ions is, that nothing flows out, which is true if the bed
            % is still far below its capacity. Since for a full bed,
            % the better assumption is that everything flows out, we
            % check the fill status of the bed and initialize
            % accordingly:
            rFillState = 1 - (this.oOut.oPhase.afMass(this.iPresaturant) / this.fInitialPresaturantMass);
            if rFillState > 0.9
                afCurrentOutletConcentrations   = afEquivalentInletFlows ./ fVolumetricFlowRate; % [eq/m^3]
            else
                afCurrentOutletConcentrations   = zeros(1, this.oMT.iSubstances); % [eq/m^3]
            end
            fOutletHplusConcentration       = fInletHplusConcentration;

            afCurrentLoading = (oAdsorber.afMass(this.abIons) ./ this.fResinMass) .* (abs(this.oMT.aiCharge(this.abIons)) ./ this.oMT.afMolarMass(this.abIons));

            afEquivalentOutletFlows     = zeros(1, this.oMT.iSubstances);
            dqdt                        = zeros(1, this.oMT.iSubstances);
            afPartialFlowRates          = zeros(1, this.oMT.iSubstances);
            afAdsorptionFlowRatesPrev   = ones(1, this.oMT.iSubstances);

                %afCurrentConcentration(this.oMT.tiN2I.OH) = 55.6 *  this.oMT.afDissociationConstant(this.oMT.tiN2I.H2O) / fOutletHplusConcentration;

            iIteration = 0;
            while any(abs(afPartialFlowRates - afAdsorptionFlowRatesPrev) > 1e-8) && iIteration < 500
                % Since this term appears multiple times, we calculate it
                % only once to speed up the computation
                afHelperVariable1 = (this.fTotalCapacity .* this.afExchangeRateConstants(this.abIons) .* fOutletHplusConcentration);

                fHelperVariable2 = (1 + (fOutletHplusConcentration .* sum(this.afExchangeRateConstants(this.abIons) .* afCurrentOutletConcentrations(this.abIons))));

                % afExchangeRateConstantSumsWithoutSelf = sum(this.mfExchangeRateConstants(this.abIons, this.abIons) .*  afCurrentOutletConcentrations(this.abIons), 2)';

                % adjusted Equation (VI-22):
                afCurrentEquilibriumOutletConcentration = afCurrentLoading .* fHelperVariable2 ./...
                                                         afHelperVariable1;

                afAdsorptionFlowRatesPrev = afPartialFlowRates;

                afOutletFlows = afCurrentEquilibriumOutletConcentration .* this.oMT.afMolarMass(this.abIons) ./ abs(this.oMT.aiCharge(this.abIons)) * fVolumetricFlowRate;

                afPartialFlowRates(this.abIons) = afPartialInFlows(this.abIons) - afOutletFlows;

                abLimitAdsorption = (afPartialInFlows < afPartialFlowRates);
                abLimitAdsorption(this.oMT.tiN2I.OH) = false;
                afPartialFlowRates(abLimitAdsorption) = afPartialInFlows(abLimitAdsorption);

                % With the new adsorption flowrates we can calculate
                % the new outlet concentrations:
                afEquivalentOutletFlows(this.abIons)  = ((afPartialInFlows(this.abIons) - afPartialFlowRates(this.abIons)) ./ this.oMT.afMolarMass(this.abIons)) .* abs(this.oMT.aiCharge(this.abIons));

                % The outlet H concentration should also change based
                % on the acid reactions
                afCurrentOutletConcentrations = afEquivalentOutletFlows ./ fVolumetricFlowRate;

                iIteration = iIteration + 1;
            end
            afPartialFlowRates(this.oMT.tiN2I.OH) = 0;
            
            
            afDesorptionTime = this.oOut.oPhase.afMass ./ afPartialFlowRates;
            afPartialFlowRates(afDesorptionTime > -20 & afDesorptionTime < 0) = - this.oOut.oPhase.afMass(afDesorptionTime > -20 & afDesorptionTime < 0) ./ 20;
            
            
            abLimitFlows = afPartialFlowRates > afPartialInFlows;
            afPartialFlowRates(abLimitFlows) = afPartialInFlows(abLimitFlows);
            %calculating arExtractPartials for Adsorption and Desorption:
            
            dqdt(this.abIons) = (abs(this.oMT.aiCharge(this.abIons)) ./ this.oMT.afMolarMass(this.abIons)) .* afPartialFlowRates(this.abIons);
            dqdt(this.oMT.tiN2I.OH) = 0;
            afPartialFlowRates(this.oMT.tiN2I.OH)       = - sum(dqdt * this.fResinMass) * this.oMT.afMolarMass(this.oMT.tiN2I.OH);

            
            afDesorptionFlowRates = zeros(1, this.oMT.iSubstances);
            afAdsorptionFlowRates = afDesorptionFlowRates;
            
            afAdsorptionFlowRates(afPartialFlowRates > 0) = afPartialFlowRates(afPartialFlowRates > 0);
            afDesorptionFlowRates(afPartialFlowRates < 0) = afPartialFlowRates(afPartialFlowRates < 0);
            abLimitDesorption = this.oOut.oPhase.afMass < 1e-12;
            afDesorptionFlowRates(abLimitDesorption) = 0;
            
            fDesorptionFlowRate = sum(afDesorptionFlowRates);
            if fDesorptionFlowRate == 0
                arExtractPartialsDesorption = zeros(1,this.oMT.iSubstances);
            else
                arExtractPartialsDesorption = afDesorptionFlowRates/fDesorptionFlowRate;
            end
            
            abLimitAdsorption = afAdsorptionFlowRates > afPartialInFlows;
            afAdsorptionFlowRates(abLimitAdsorption) = afPartialInFlows(abLimitAdsorption);
            fAdsorptionFlowRate = sum(afAdsorptionFlowRates);
            if fAdsorptionFlowRate == 0
                arExtractPartialsAdsorption = zeros(1,this.oMT.iSubstances);
            else
                arExtractPartialsAdsorption = afAdsorptionFlowRates/fAdsorptionFlowRate;
            end
            
            this.setMatterProperties(fAdsorptionFlowRate, arExtractPartialsAdsorption);
            this.oDesorptionP2P.setMatterProperties(fDesorptionFlowRate, arExtractPartialsDesorption);
            
        end
    end
    
    methods (Access = protected)
        function update(~)
        end
    end
end
