classdef baseMixedBed_P2P < base
    
    %% Mixed Bed = P2P doing ion exchange in the Multifiltration beds based on
    % DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER PROCESSOR
    % written by David Robert Hokanson
    
    properties (SetAccess = public, GetAccess = public)
        
        % Vector containing the seperation factors for each ion
        afSeperationFactors; % [-]
        % Matrix containing the division of the specific ion seperation
        % factor with all other seperations factors as rows
        mfSeperationFactors; % [-]
        
        % total Volume of the cell 
        fCellVolume; % [m^3]
        % The void fraction of the cell volume (cell volume is the volume
        % of resin and fluid)
        rVoidFraction; % [-]
        % Resin mass (not the ion mass)!
        fResinMass; % [kg]
        
        % Boolean to decide if this is a cation or anion bed
        bCationResin;
        
        % Boolean vector to find the specific ions from the V-HAB vectors
        abIons;
        
        % Object reference to the P2P handling desorption:
        oDesorptionP2P;
        
        % Current equivalent inlet flows
        afEquivalentInletFlows; % [mol * valence / s]
        % sum of total equivalent inlet flows
        fTotalEquivalentFlows;  % [mol * valence / s]
        fVolumetricFlowRate;    % [m^3 /s]
        % Current loading (also called q in equations) of the adsorbent in
        % mol*valence / resin mass.
        afCurrentLoading;       % [mol*valence / kg]
        % The total contact time of water with the adsorbent in this cell
        fEmptyBedContactTime;   % [s]
        
        hCalculateLoadingChangeRate;
        
        % Matter index of the presaturant ion (either H+ oder OH-)
        iPresaturant;
        
        % Stores the previous calculate flowrates from the ODE, to be
        % reused in case the changes are small
        afPreviousFlowRates;
        
        tOdeOptions = odeset('RelTol', 1e-3, 'AbsTol', 1e-4);
    end
    
    methods
        function this = baseMixedBed_P2P(oStore, oDesorptionP2P)
            
            this.oDesorptionP2P = oDesorptionP2P;
            this.bCationResin   = oStore.oContainer.bCationResin;
            this.rVoidFraction 	= oStore.oContainer.rVoidFraction;
            this.fResinMass     = oStore.oContainer.fResinMass  / oStore.oContainer.iCells;
            this.fCellVolume    = oStore.oContainer.fVolume     / oStore.oContainer.iCells;
            this.fEmptyBedContactTime = oStore.oContainer.fEmptyBedContactTime     / oStore.oContainer.iCells;
            
            if this.bCationResin
                % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
                % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
                % PROCESSOR", David Robert Hokanson, 2004, Table 2-14
                this.afSeperationFactors = zeros(1, this.oMT.iSubstances);
                this.afSeperationFactors(this.oMT.tiN2I.Hplus)    = 1;
                this.afSeperationFactors(this.oMT.tiN2I.Naplus)   = 1.68;
                this.afSeperationFactors(this.oMT.tiN2I.Kplus)    = 2.15;
                this.afSeperationFactors(this.oMT.tiN2I.Ca2plus)  = 72.7;
                this.afSeperationFactors(this.oMT.tiN2I.NH4)      = 1.9;
                
                this.abIons = (this.afSeperationFactors ~= 0);
                
                this.iPresaturant = this.oMT.tiN2I.Hplus;
            else
                % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
                % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
                % PROCESSOR", David Robert Hokanson, 2004, Table 2-15
                this.afSeperationFactors = zeros(1, this.oMT.iSubstances);
                this.afSeperationFactors(this.oMT.tiN2I.OH)       = 1;
                this.afSeperationFactors(this.oMT.tiN2I.CMT)      = 214;
                this.afSeperationFactors(this.oMT.tiN2I.Clminus)  = 16.7;
                this.afSeperationFactors(this.oMT.tiN2I.C4H7O2)   = 3.21;
                this.afSeperationFactors(this.oMT.tiN2I.C2H3O2)   = 1.99;
                this.afSeperationFactors(this.oMT.tiN2I.HCO3)     = 4.99;
                this.afSeperationFactors(this.oMT.tiN2I.SO4)      = 149;
                this.afSeperationFactors(this.oMT.tiN2I.C3H5O3)   = 2.266;
                
                this.abIons = (this.afSeperationFactors ~= 0);
                
                this.iPresaturant = this.oMT.tiN2I.OH;
            end
            
            this.mfSeperationFactors = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            
            this.mfSeperationFactors(this.abIons, this.abIons) = this.afSeperationFactors(this.abIons)' ./ this.afSeperationFactors(this.abIons);
            
            this.mfSeperationFactors(logical(eye(this.oMT.iSubstances))) = 0;
            
            this.afEquivalentInletFlows = zeros(sum(this.abIons),1);
            this.afCurrentLoading = zeros(1, sum(this.abIons));
            this.afPreviousFlowRates = zeros(1, this.oMT.iSubstances);
            
            % Define rate of change function for ODE solver.
            this.hCalculateLoadingChangeRate = @(t, afCurrentLoading) this.calculateLoadingChangeRate(afCurrentLoading, t);
        end
        
        function dqdt = calculateLoadingChangeRate(this, afCurrentLoading, ~)
            % This function is used in the ode45 solver to calculate the
            % loading change in the bed
            abZeroLoading = afCurrentLoading == 0;
            afCurrentLoading(abZeroLoading) = 1e-12;
            
            % Here we calculate the sum of the seperation factors (called
            % alpha_ij in the Dissertation) and the current adsorbent mass
            % ratios (q_j in the Dissertation). We directly do so for all
            % Ions i over all ions j!
            afSeperationFactorSumValues = sum(this.mfSeperationFactors(this.abIons,this.abIons) .* afCurrentLoading, 2);
            
            afSeperationFactorSumWithoutSelf = sum(this.mfSeperationFactors(this.abIons,this.abIons) .* afCurrentLoading, 2);
            
            % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
            % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
            % PROCESSOR", David Robert Hokanson, 2004, Equation (III-65)
            % for Cations or (III-68) for Anions on page 181/182
            %
            % The variable C_T,C or C_T,A is the total equivalent cation/anion
            % concentration. This should be equal at the in and outlet and
            % we therefore use the inlet conditions as these are known
            dqdt = this.afEquivalentInletFlows - this.fTotalEquivalentFlows * (afCurrentLoading ./ afSeperationFactorSumValues) ./...
                 (this.fResinMass + this.rVoidFraction .* this.fCellVolume .* (this.fTotalEquivalentFlows / this.fVolumetricFlowRate) .* afSeperationFactorSumWithoutSelf ./ afSeperationFactorSumValues.^2);

            dqdt(dqdt < 0 & abZeroLoading) = 0;
            % Charge balance must be maintained, the equivalent change in
            % loading of other ions must replace the equivalent charge of
            % presaturant ions
            if this.bCationResin
                iLocalPresaturant = sum(this.abIons(1:this.oMT.tiN2I.Hplus));
                dqdt(iLocalPresaturant)    = 0;
                dqdt(iLocalPresaturant)    = - sum(dqdt);
            else
                iLocalPresaturant = sum(this.abIons(1:this.oMT.tiN2I.OH));
                dqdt(iLocalPresaturant)       = 0;
                dqdt(iLocalPresaturant)       = - sum(dqdt);
            end
            
        end
        
        function afPartialFlowRates = calculateExchangeRates(this, afPartialInFlows)
            
            % Now we calculate the total molar equivalents flowing in the
            % liquid [mol * valence / s]
            afNewEquivalentInletFlows  = (afPartialInFlows(this.abIons) ./ this.oMT.afMolarMass(this.abIons)) .* abs(this.oMT.aiCharge(this.abIons));

            % From these we can also calculate the total equivalent flow,
            % simply by summing it up
            this.fTotalEquivalentFlows = sum(afNewEquivalentInletFlows); %[eq/s]

            fDensity = this.oIn.oPhase.fDensity;
            this.fVolumetricFlowRate = sum(afPartialInFlows) / fDensity;

            % We also require the current resin phase ratios of the
            % adsorbents:
            afNewLoading = (this.oOut.oPhase.afMass(this.abIons) .* abs(this.oMT.aiCharge(this.abIons))) ./ (this.fResinMass .* this.oMT.afMolarMass(this.abIons));

            arChangeInletConcentrations = (abs(this.afEquivalentInletFlows' - afNewEquivalentInletFlows) ./ afNewEquivalentInletFlows);
            arChangeLoading = (abs(this.afCurrentLoading - afNewLoading) ./ afNewLoading);

            arChangeInletConcentrations(afNewEquivalentInletFlows == 0) = 0;
            arChangeLoading(afNewLoading == 0) = 0;

            % Check if we should recalculate the differntial equation, or
            % if the changes compared to the last calculation are only
            % small ( < 5%):
            if any(arChangeInletConcentrations > 0.02) || any(arChangeLoading > 0.02)

                this.afCurrentLoading = afNewLoading;
                this.afEquivalentInletFlows  = afNewEquivalentInletFlows';

                % we use the empty bed contact time of the cell to
                % calculate the outlet concentrations of this cell. This
                % allows us to "model" the cell length without actually
                % implementing the delay in the simulation as a mass, as
                % that would slow down the simulation
                fStepBeginTime = this.oTimer.fTime;
                fStepEndTime = this.oTimer.fTime + this.fEmptyBedContactTime;

                [~, mfSolutionLoading] = ode45(this.hCalculateLoadingChangeRate, [fStepBeginTime, fStepEndTime], this.afCurrentLoading, this.tOdeOptions);

                afSolutionLoading = mfSolutionLoading(end, :);

                % The equilibrium equations III-59 and III-66 can now be
                % used to calculate the outlet concentration of the ions:
                afSeperationFactorSumValues = sum(this.mfSeperationFactors(this.abIons,this.abIons) .* afSolutionLoading, 2);
                afSeperationFactorSumValues = afSeperationFactorSumValues';
                afOutletConcentrations = this.fTotalEquivalentFlows * (afSolutionLoading ./ afSeperationFactorSumValues);

                afOutletFlows = afOutletConcentrations .* this.oMT.afMolarMass(this.abIons) ./ abs(this.oMT.aiCharge(this.abIons)) * this.fVolumetricFlowRate;

                afPartialFlowRates = zeros(1, this.oMT.iSubstances);
                afPartialFlowRates(this.abIons) = afPartialInFlows(this.abIons) - afOutletFlows;

                this.afPreviousFlowRates = afPartialFlowRates;
            else
                % Otherwise, get the previous P2P flowrates and use them
                % for the calculation
                afPartialFlowRates =  this.afPreviousFlowRates;
            end

            abLimitFlows = afPartialFlowRates > afPartialInFlows;
            afPartialFlowRates(abLimitFlows) = afPartialInFlows(abLimitFlows);

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
            
            % "DEVELOPMENT OF ION EXCHANGE MODELS FOR WATER TREATMENT
            % ANDAPPLICATION TO THE INTERNATIONAL SPACE STATION WATER
            % PROCESSOR", David Robert Hokanson, 2004, Equation (III-63)
            %
            % This equation basically states that for each equivalent that
            % is adsorbed by the ion exchange bed, the equivalent mol
            % number of presaturated ions must be released from the resin
            afEquivalentFlows(this.iPresaturant) = 0;
            afPartialFlowRates(this.iPresaturant)    = - sum(afEquivalentFlows) * this.oMT.afMolarMass(this.iPresaturant);
        end
    end
end
