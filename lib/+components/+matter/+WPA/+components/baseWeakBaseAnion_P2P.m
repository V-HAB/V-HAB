classdef baseWeakBaseAnion_P2P < base
    
    %% WBA P2P doing ion exchange in the Multifiltration beds based on
    % DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER PROCESSOR
    % written by David Robert Hokanson
    
    properties (SetAccess = public, GetAccess = public)
        
        afExchangeRateConstants;        % [(m^3)^2 / eq^2]
        % Matrix containing the exchange rate constants for each ion in the
        % columns, and each row represents an ion. For the row all exchange
        % rate constant are represent in its column except for the exchange
        % rate constant of that ion itself
        mfExchangeRateConstants;        % [(m^3)^2 / eq^2]
        
        % Vector containing the seperation factors for each ion
        afSeperationFactors;
        % Matrix containing the division of the specific ion seperation
        % factor with all other seperations factors as rows
        mfSeperationFactors;
        
        % The current inlet concentrations
        afCurrentInletConcentrations;   % [eq / m^3]
        fVolumetricFlowRate = 0;        % [m^3 / s]
        afCurrentLoading;
        % The total contact time of water with the adsorbent in this cell
        fEmptyBedContactTime;   % [s]
        
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
        
        % Stores the previous calculate flowrates from the ODE, to be
        % reused in case the changes are small
        afPreviousFlowRates;
        
        hCalculateOutletConcentrationChangeRate;
        
        tOdeOptions = odeset('RelTol', 1e-3, 'AbsTol', 1e-4);
    end
    
    methods
        function this = baseWeakBaseAnion_P2P(oStore, oDesorptionP2P)
            
            this.oDesorptionP2P = oDesorptionP2P;
            this.rVoidFraction 	= oStore.oContainer.rVoidFraction;
            this.fResinMass     = oStore.oContainer.fResinMass      / oStore.oContainer.iCells;
            this.fCellVolume    = oStore.oContainer.fVolume         / oStore.oContainer.iCells;
            this.iPresaturant   = oStore.oContainer.iPresaturant;
            this.fInitialPresaturantMass = this.oOut.oPhase.afMass(this.iPresaturant);
            this.fEmptyBedContactTime = oStore.oContainer.fEmptyBedContactTime     / oStore.oContainer.iCells;
            
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
            
            this.afCurrentInletConcentrations = zeros(1, this.oMT.iSubstances);
            this.afPreviousFlowRates = zeros(1, this.oMT.iSubstances);
            this.afCurrentLoading = zeros(1, sum(this.abIons));
                
            % Define rate of change function for ODE solver.
            this.hCalculateOutletConcentrationChangeRate = @(t, afOutletConcentrations) this.calculateOutletConcentrationChangeRate(afOutletConcentrations, t);
        end
        
        function afOutletConentrationChange = calculateOutletConcentrationChangeRate(this, afOutletConcentrations, ~)
            % Function used to calculate the change in outlet concentration
            % over time using an ode solver of Matlab
            fOutletHplusConcentration = afOutletConcentrations(this.oMT.tiN2I.Hplus);
            
            % q_t * b_i * C_H
            afHelperVariable1 = (this.fTotalCapacity .* this.afExchangeRateConstants(this.abIons) .* fOutletHplusConcentration);

            % C_H * Sum of b_k*C_K over all ions
            fHelperVariable2 = (1 + (fOutletHplusConcentration .* sum(this.afExchangeRateConstants(this.abIons)' .* afOutletConcentrations(this.abIons))));

            afExchangeRateConstantSumsWithoutSelf = sum(this.mfExchangeRateConstants(this.abIons, this.abIons) .*  afOutletConcentrations(this.abIons), 2)';

            afOutletConentrationChange = zeros(this.oMT.iSubstances, 1);
            
            % Equation VI-24 from David Hokanson 2004
            afOutletConentrationChange(this.abIons) = this.fVolumetricFlowRate .* (this.afCurrentInletConcentrations(this.abIons)' - afOutletConcentrations(this.abIons)) ./ ...
                                         (this.fResinMass .* (((1 + fOutletHplusConcentration .* afExchangeRateConstantSumsWithoutSelf') .* afHelperVariable1') ./ ...
                                          fHelperVariable2.^2) + this.fCellVolume .* this.rVoidFraction);
        end
        
        function afPartialFlowRates = calculateExchangeRates(this, afPartialInFlows)
            
            % Now we calculate the total molar equivalents flowing in the
            % liquid [mol * valence / s]
            afNewEquivalentInletFlows  = (afPartialInFlows ./ this.oMT.afMolarMass) .* abs(this.oMT.aiCharge);
            afNewEquivalentInletFlows(~this.abIons) = 0;
            
            fDensity = this.oIn.oPhase.fDensity;
            this.fVolumetricFlowRate = sum(afPartialInFlows) / fDensity; % [m^3/s]

            this.fTotalCapacity = (this.oOut.oPhase.afMass(this.iPresaturant) / this.oMT.afMolarMass(this.iPresaturant)) / this.fResinMass;
            
            % The following calculation based on:
            % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
            % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
            % PROCESSOR", David Robert Hokanson, 2004, Equation (VI-41)
            % and Equation (VI-24), which provides the differential
            % equation solved here
            
            % Initial assumption for the outlet concentrations of the
            % ions is, that nothing flows out, which is true if the bed
            % is still far below its capacity. Since for a full bed,
            % the better assumption is that everything flows out, we
            % check the fill status of the bed and initialize
            % accordingly:
            afCurrentOutletConcentrations   = 0.1 .* afNewEquivalentInletFlows ./ this.fVolumetricFlowRate; % [eq/m^3]
            
            if afCurrentOutletConcentrations(this.oMT.tiN2I.Hplus) == 0
                afCurrentOutletConcentrations(this.oMT.tiN2I.Hplus)       = 10^-7 *1000;
            end
            fOutletHplusConcentration = afCurrentOutletConcentrations(this.oMT.tiN2I.Hplus);

            afNewInletConcentrations = afNewEquivalentInletFlows ./ this.fVolumetricFlowRate; % [eq/m^3]
            afNewLoading = (this.oOut.oPhase.afMass(this.abIons) ./ this.fResinMass) .* (abs(this.oMT.aiCharge(this.abIons)) ./ this.oMT.afMolarMass(this.abIons));

            arChangeInletConcentrations = (abs(this.afCurrentInletConcentrations - afNewInletConcentrations) ./ afNewInletConcentrations);
            arChangeLoading = (abs(this.afCurrentLoading - afNewLoading) ./ afNewLoading);
            
            abBothValueZeros = afNewInletConcentrations(this.abIons) == 0 & afNewLoading == 0;
            arChangeInletConcentrations(abBothValueZeros) = 0;
            arChangeLoading(abBothValueZeros) = 0;
            
            % Check if we should recalculate the differntial equation, or
            % if the changes compared to the last calculation are only
            % small ( < 5%):
            if any(arChangeInletConcentrations > 0.02) || any(arChangeLoading > 0.02)
                
                this.afCurrentInletConcentrations = afNewInletConcentrations; % [eq/m^3]
                this.afCurrentLoading = afNewLoading;

                afPartialFlowRates          = zeros(1, this.oMT.iSubstances);
                afCurrentEquilibriumAdsorbedMasses  = zeros(1, this.oMT.iSubstances);

                % we use the empty bed contact time of the cell to
                % calculate the outlet concentrations of this cell. This
                % allows us to "model" the cell length without actually
                % implementing the delay in the simulation as a mass, as
                % that would slow down the simulation
                fStepBeginTime = this.oTimer.fTime;
                fStepEndTime = this.oTimer.fTime + this.fEmptyBedContactTime;

                [~, mfSolutionOutletConcentrations] = ode45(this.hCalculateOutletConcentrationChangeRate, [fStepBeginTime, fStepEndTime], afCurrentOutletConcentrations, this.tOdeOptions);

                afOutletConcentrations = mfSolutionOutletConcentrations(end, :);

                % q_t * b_i * C_H
                afHelperVariable1 = (this.fTotalCapacity .* this.afExchangeRateConstants(this.abIons) .* fOutletHplusConcentration);

                % problem, this sums over all elements, bu according to
                % VI-23 it should leave out the ion currently beeing
                % considered. I guess it must be checked if the equation
                % is correctly used here or if we have to use equation
                % VI-24
                % C_H * Sum of b_k*C_K over all ions
                fHelperVariable2 = (1 + (fOutletHplusConcentration .* sum(this.afExchangeRateConstants(this.abIons) .* afOutletConcentrations(this.abIons))));

                afCurrentEquilibriumLoading = afOutletConcentrations(this.abIons) .* afHelperVariable1 ./ fHelperVariable2;

                afCurrentEquilibriumAdsorbedMasses(this.abIons) = this.fResinMass .* (afCurrentEquilibriumLoading ./ (abs(this.oMT.aiCharge(this.abIons)) ./ this.oMT.afMolarMass(this.abIons)));

                afOutletFlows = afOutletConcentrations(this.abIons) .* this.oMT.afMolarMass(this.abIons) ./ abs(this.oMT.aiCharge(this.abIons)) * this.fVolumetricFlowRate;

                afPartialFlowRates(this.abIons) = afPartialInFlows(this.abIons) - afOutletFlows;

                this.afPreviousFlowRates = afPartialFlowRates;
            else
                % Otherwise, get the previous P2P flowrates and use them
                % for the calculation
                afPartialFlowRates =  this.afPreviousFlowRates;
            end
            
            abLimitAdsorption = (afPartialInFlows < afPartialFlowRates);
            abLimitAdsorption(this.oMT.tiN2I.OH) = false;
            afPartialFlowRates(abLimitAdsorption) = afPartialInFlows(abLimitAdsorption);

            afPartialFlowRates(this.iPresaturant) = 0;
            
            afEquivalentFlows               = zeros(1, this.oMT.iSubstances);
            afEquivalentFlows(this.abIons)	= (abs(this.oMT.aiCharge(this.abIons)) ./ this.oMT.afMolarMass(this.abIons)) .* afPartialFlowRates(this.abIons);

            % The p2p can only adsorb mass if presaturant is still adsorbed
            % to the resin. Therefore, we set the adsorption flowrates to
            % zero if that is the case. The resin can now desorb matter and
            % adsorb other matter but not limitless adsorb matter
            if this.oOut.oPhase.afMass(this.iPresaturant) < 1e-12
                afPartialFlowRates(afEquivalentFlows > 0) = 0;
                afEquivalentFlows(afEquivalentFlows > 0) = 0;
            end
            
            % calculating arExtractPartials for Adsorption and Desorption:
            afEquivalentFlows(this.iPresaturant) = 0;
            afPartialFlowRates(this.iPresaturant)       = - sum(afEquivalentFlows) * this.oMT.afMolarMass(this.oMT.tiN2I.OH);
        end
    end
    
    methods (Access = protected)
        function update(~)
        end
    end
end
