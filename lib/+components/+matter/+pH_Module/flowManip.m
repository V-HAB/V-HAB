classdef flowManip < matter.manips.substance.flow
    %% pH flowManip
    % This manipulator can be used to calculate the pH value in an aquaous
    % solution and converting all participating substances correspondingly
    % If new substances where added to the matter table which take part in
    % the pH value calculation, you have to adjust the miComplex variable
    % accordingly! Substances that do not directly dissocicate with water
    % like for example CaCO3 must be split seperatly before they are
    % considered correctly in these equations!
    %
    % The solved system of equations includes the acid/base dissociations
    % charge balance, mass balance and molar balances of inidivual ion
    % groups (e.g. PO4^(3-) in all forms like H3PO4 etc)
    properties (SetAccess = protected, GetAccess = public)
        
        fpH = 7;
        
        abDissociation;
        abRelevantSubstances;
        
        afConversionRates;
        
        miComplex;
        
        aiInitialReactants;
        iInitialReactants;
        
        % The actual linear system of equations we have to solve is
        % generated from different matrices, one contains the references to
        % the dissocication constants, one to the H+ concentration and one
        % to molar balance equations:
        mfDissociationMatrix;
        mfHydrogenMatrix;
        mfOHMatrix;
        mfMolarSumMatrix;
        afBaseLeftSideVector;
        
        arLastIonPartials;
    end
    
    
    methods
        function this = flowManip(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            
            if ~oPhase.bFlow
                error('Flow manips only work with flow phases')
            end
            
            this.abDissociation = this.oMT.afDissociationConstant ~= 0;
            
            this.afConversionRates = zeros(1, this.oMT.iSubstances);
            
            this.miComplex = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            
            % Each row asscociates one substance to a dissocication
            % complex, with the dissocication products ordered in the order
            % in which they occur. Note that only the initial substance has
            % entries here! If you want to add a new substance which should
            % be included in the pH calculations you have to adjust this
            % property!
            
            % EDTA dissocication complex:
            this.miComplex(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA), this.oMT.tiN2I.(this.oMT.tsN2S.EDTA))       = 1;
            this.miComplex(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA), this.oMT.tiN2I.(this.oMT.tsN2S.EDTAminus))  = 2;
            this.miComplex(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA), this.oMT.tiN2I.(this.oMT.tsN2S.EDTA2minus)) = 3;
            this.miComplex(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA), this.oMT.tiN2I.(this.oMT.tsN2S.EDTA3minus)) = 4;
            this.miComplex(this.oMT.tiN2I.(this.oMT.tsN2S.EDTA), this.oMT.tiN2I.(this.oMT.tsN2S.EDTA4minus)) = 5;
            
            % Phosphoric Acid
            this.miComplex(this.oMT.tiN2I.(this.oMT.tsN2S.PhosphoricAcid), this.oMT.tiN2I.(this.oMT.tsN2S.PhosphoricAcid))       = 1;
            this.miComplex(this.oMT.tiN2I.(this.oMT.tsN2S.PhosphoricAcid), this.oMT.tiN2I.(this.oMT.tsN2S.DihydrogenPhosphate))  = 2;
            this.miComplex(this.oMT.tiN2I.(this.oMT.tsN2S.PhosphoricAcid), this.oMT.tiN2I.(this.oMT.tsN2S.HydrogenPhosphate))    = 3;
            this.miComplex(this.oMT.tiN2I.(this.oMT.tsN2S.PhosphoricAcid), this.oMT.tiN2I.(this.oMT.tsN2S.Phosphate))            = 4;
            
            % HNO2
            this.miComplex(this.oMT.tiN2I.HNO3, this.oMT.tiN2I.HNO3)    = 1;
            this.miComplex(this.oMT.tiN2I.HNO3, this.oMT.tiN2I.NO3)     = 2;
            
            % HNO2
            this.miComplex(this.oMT.tiN2I.HNO2, this.oMT.tiN2I.HNO2)    = 1;
            this.miComplex(this.oMT.tiN2I.HNO2, this.oMT.tiN2I.NO2)     = 2;
            
            % H2SO4
            this.miComplex(this.oMT.tiN2I.H2SO4, this.oMT.tiN2I.H2SO4)  = 1;
            this.miComplex(this.oMT.tiN2I.H2SO4, this.oMT.tiN2I.HSO4)   = 2;
            this.miComplex(this.oMT.tiN2I.H2SO4, this.oMT.tiN2I.SO4)    = 3;
            
            % Carbon Dioxide
            this.miComplex(this.oMT.tiN2I.CO2, this.oMT.tiN2I.CO2)      = 1;
            this.miComplex(this.oMT.tiN2I.CO2, this.oMT.tiN2I.HCO3)     = 2;
            this.miComplex(this.oMT.tiN2I.CO2, this.oMT.tiN2I.CO3)      = 3;
            
            % NH3
            this.miComplex(this.oMT.tiN2I.NH3, this.oMT.tiN2I.NH3)      = 1;
            this.miComplex(this.oMT.tiN2I.NH3, this.oMT.tiN2I.NH4)      = 2;
            
            % NaOH
            this.miComplex(this.oMT.tiN2I.NaOH, this.oMT.tiN2I.NaOH)    = 1;
            this.miComplex(this.oMT.tiN2I.NaOH, this.oMT.tiN2I.Naplus)  = 2;
            
            % KOH
            this.miComplex(this.oMT.tiN2I.KOH, this.oMT.tiN2I.KOH)      = 1;
            this.miComplex(this.oMT.tiN2I.KOH, this.oMT.tiN2I.Kplus)    = 2;
            
            this.aiInitialReactants = find(this.miComplex(logical(eye(this.oMT.iSubstances, this.oMT.iSubstances))));
            this.iInitialReactants  = length(this.aiInitialReactants);
            
            this.createLinearSystem();
            
            this.arLastIonPartials = zeros(1, sum(this.oMT.aiCharge ~= 0));
        end
        function calculateConversionRate(this, afInFlowRates, aarInPartials)
            %getting inflowrates
            afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
            % Since we also consider P2P flowrates for these in flows, we
            % have to check to not use negative total flowrates here:
            afPartialInFlows(afPartialInFlows < 0) = 0;
            
            if any(afPartialInFlows(this.abDissociation))
                afIonFlows = afPartialInFlows(this.oMT.aiCharge ~= 0);
                arIonPartials = afIonFlows ./ sum(afIonFlows);
                
                if all(abs(this.arLastIonPartials - arIonPartials) < 0.05)
                    afResultingFlows = afPartialInFlows + this.afPartialFlows;
                    if ~any(afResultingFlows < 0)
                        return
                    end
                end
                this.arLastIonPartials = arIonPartials;
                % Volumetric flowrate in l/s!
                fVolumetricFlowRate = (sum(afPartialInFlows) / this.oPhase.fDensity) * 1000;

                fDissociationConstantWater = this.oMT.afDissociationConstant(this.oMT.tiN2I.H2O);
                % Concentrations in mol/L!
                afInitialConcentrations = ((afPartialInFlows ./ this.oMT.afMolarMass) ./ fVolumetricFlowRate);

                % Charge sum of ions for which the concentration is not
                % solved by the system of equations
                fInitialChargeSum = this.oMT.aiCharge(~this.abRelevantSubstances) * afInitialConcentrations(~this.abRelevantSubstances)';
                fInitialMassSum = sum(afPartialInFlows) / fVolumetricFlowRate;

                afCurrentConcentration  = afInitialConcentrations;
                afConcentrations        = afInitialConcentrations';
                % Now we calculate the correct equilibrium solution that
                % ensures chemical equilibrium and charge balance. However, the
                % actual mass conversion is not considered in this system,
                % therefore the mass balance must be ensured seperatly. It is
                % possible that the system would strive toward a different
                % equilibrium than is currently possible with the exisiting
                % phase content
                fError = inf;
                iCounter = 0;

                % if PH is higher than 10 the interval represents the OH-
                % concentration
                fCurrentPH = -log10(afInitialConcentrations(this.oMT.tiN2I.Hplus));

                mfInitializationIntervall = [1e-20, 1e-14, 1e-13, 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-3, 1e-2, 1e-1, 100];
                fMaxError = 1e-18;

                mfInitializatonError = zeros(1, length(mfInitializationIntervall));

                warning('OFF', 'all')
                for iBoundary = 1:length(mfInitializationIntervall)

                    if fCurrentPH > 7
                        afCurrentConcentration(this.oMT.tiN2I.Hplus) = 10^-(-log10(fDissociationConstantWater) - -log10(mfInitializationIntervall(iBoundary)));
                    else
                        afCurrentConcentration(this.oMT.tiN2I.Hplus) = mfInitializationIntervall(iBoundary);
                    end 

                    afCurrentConcentration(this.oMT.tiN2I.OH) = 55.6 * fDissociationConstantWater / afCurrentConcentration(this.oMT.tiN2I.Hplus);

                    afLeftSide = this.afBaseLeftSideVector + this.mfMolarSumMatrix * afInitialConcentrations';
                    afLeftSide(this.oMT.tiN2I.OH) = fInitialMassSum; % [kg/l]
                    afLeftSide(this.oMT.tiN2I.Hplus) = fInitialChargeSum; 

                    mfLinearSystem = this.mfDissociationMatrix +...
                                     this.mfHydrogenMatrix .* afCurrentConcentration(this.oMT.tiN2I.Hplus) +...
                                     this.mfOHMatrix .* afCurrentConcentration(this.oMT.tiN2I.OH) +...
                                     this.mfMolarSumMatrix;

                    % You can select a reduced linear system:
                    % A = mfLinearSystem(this.abRelevantSubstances, this.abRelevantSubstances);
                    % b = afLeftSide (this.abRelevantSubstances);

                    afConcentrations(this.abRelevantSubstances) = mfLinearSystem(this.abRelevantSubstances, this.abRelevantSubstances) \ afLeftSide(this.abRelevantSubstances);
                    mfInitializatonError(iBoundary) = afConcentrations(this.oMT.tiN2I.Hplus) - afCurrentConcentration(this.oMT.tiN2I.Hplus);
                end
%                     A = mfLinearSystem([1:10, this.oMT.tiN2I.H2O, this.oMT.tiN2I.OH, this.oMT.tiN2I.Hplus], [1:10, this.oMT.tiN2I.H2O, this.oMT.tiN2I.OH, this.oMT.tiN2I.Hplus]);
%                     B = afLeftSide([1:10, this.oMT.tiN2I.H2O, this.oMT.tiN2I.OH, this.oMT.tiN2I.Hplus]);

                for iError = 1:length(mfInitializatonError)-1
                    if sign(mfInitializatonError(iError)) ~= sign(mfInitializatonError(iError+1))

                        mfError(1) = mfInitializatonError(iError);
                        mfError(2) = mfInitializatonError(iError+1);

                        mfIntervall(1) = mfInitializationIntervall(iError);
                        mfIntervall(2) = mfInitializationIntervall(iError+1);

                        fIntervallSize = mfIntervall(2) - mfIntervall(1);
                        break
                    end
                end

                fNewBoundary = mfIntervall(2);
                while ((abs(fError) > fMaxError) && fIntervallSize > fMaxError || afConcentrations(this.oMT.tiN2I.Hplus) < 0)  && iCounter < 1000 

                    iCounter = iCounter + 1;

                    fIntervallSize = mfIntervall(2) - mfIntervall(1);

                    fOldBoundary = fNewBoundary;
                    fNewBoundary = sum(mfIntervall) / 2;
                    % The algorithm can become stuck in a negativ value for
                    % H+ in case of small values. Then the old boundary and
                    % new boundary are identical. In that case we set the
                    % boundary to the value where positive H+
                    % concentrations were calculated to allow the loop to
                    % finish
                    if fOldBoundary == fNewBoundary
                        fNewBoundary = mfIntervall(2);
                    end

                    if fCurrentPH > 7
                        afCurrentConcentration(this.oMT.tiN2I.Hplus) = 10^-(-log10(fDissociationConstantWater) - -log10(fNewBoundary));
                    else
                        afCurrentConcentration(this.oMT.tiN2I.Hplus) = fNewBoundary;
                    end

                    afCurrentConcentration(this.oMT.tiN2I.OH) = 55.6 * fDissociationConstantWater / afCurrentConcentration(this.oMT.tiN2I.Hplus);

                    afLeftSide = this.afBaseLeftSideVector + this.mfMolarSumMatrix * afInitialConcentrations';
                    afLeftSide(this.oMT.tiN2I.OH) = fInitialMassSum; % [kg/l]
                    afLeftSide(this.oMT.tiN2I.Hplus) = fInitialChargeSum; 

                    mfLinearSystem = this.mfDissociationMatrix +...
                                     this.mfHydrogenMatrix .* afCurrentConcentration(this.oMT.tiN2I.Hplus) +...
                                     this.mfOHMatrix .* afCurrentConcentration(this.oMT.tiN2I.OH) +...
                                     this.mfMolarSumMatrix;

                    afConcentrations(this.abRelevantSubstances) = mfLinearSystem(this.abRelevantSubstances, this.abRelevantSubstances) \ afLeftSide(this.abRelevantSubstances);
                    fError = afConcentrations(this.oMT.tiN2I.Hplus) - afCurrentConcentration(this.oMT.tiN2I.Hplus);

                    if fIntervallSize < 1e-6
                        afCurrentConcentration(this.oMT.tiN2I.H2O)   = afConcentrations(this.oMT.tiN2I.H2O);
                    end

                    if sign(fError) == sign(mfError(1))
                        mfError(1)      = fError;
                        mfIntervall(1)  = fNewBoundary;

                    elseif sign(fError) == sign(mfError(2))
                        mfError(2) = fError;
                        mfIntervall(2)  = fNewBoundary;
                    end
                end

                warning('ON', 'all')

                % Since the solution of the system of equation is numerical
                % slight negative values might occur from numerical erros,
                % these are rounded. Other errors result in a stop
                abNegative = afConcentrations < 0;
                if all(abs(afConcentrations(abNegative)) < 1e-10)
                    afConcentrations(abNegative) = 0;
                else
                    error(['something in the pH calculation of phase ', this.oPhase.sName, ' in store ', this.oPhase.oStore.sName, ' went wrong'])
                end

                afInitialConcentrations = ((afPartialInFlows ./ this.oMT.afMolarMass) ./ fVolumetricFlowRate);

                afConcentrationDifference = afConcentrations' - afInitialConcentrations;

                % Set very small concentration changes to 0
                afConcentrationDifference(abs(afConcentrationDifference) < 1e-16) = 0;

                this.afConversionRates = afConcentrationDifference .* fVolumetricFlowRate .* this.oMT.afMolarMass;

                this.fpH = -log10(afConcentrations(this.oMT.tiN2I.Hplus));
            else
                this.afConversionRates = zeros(1, this.oMT.iSubstances); %[kg/s]
            end
            this.update();
        end
        
        function createLinearSystem(this)
            % See "Development Status of the Virtual Habitat (V-HAB)
            % Simulation System", ICES-2019-160, Daniel Pütz et.al equation
            % 3 for an example of the matrix that is generated here
            %
            % The Basic equation for the general reactions can be written
            % as:
            % a*A + b*B <-> c*C + d*D
            %
            % K = [C]^c * [D]^d / [A]^a * [B]^b
            % https://authors.library.caltech.edu/25050/6/Chapter_05.pdf
            
            this.mfDissociationMatrix   = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            this.mfHydrogenMatrix       = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            this.mfOHMatrix             = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            this.mfMolarSumMatrix       = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
            this.abRelevantSubstances   = false(1, this.oMT.iSubstances);
            
            this.mfDissociationMatrix(logical(eye(this.oMT.iSubstances, this.oMT.iSubstances))) = this.oMT.afDissociationConstant';
            
            for iReactant = 1:this.iInitialReactants
                iBaseSubstance = this.aiInitialReactants(iReactant);
                
                aiComplex = this.miComplex(iBaseSubstance,:);
                
                aiSubstances = find(aiComplex);
                
                iTotalReactants = length(aiSubstances);
                % Reorder the substances to be sure we loop through them in
                % the order of dissocication
                for iK = 1:iTotalReactants
                    aiSubstances(iK) = find(aiComplex == iK);
                    this.abRelevantSubstances(aiSubstances(iK)) = true;
                end
                
                for iK = 2:iTotalReactants
                    iSubstance          = aiSubstances(iK);
                    iPreviousSubstance  = aiSubstances(iK - 1);
                    if this.oMT.aiCharge(iSubstance) > 0
                        this.mfOHMatrix(iPreviousSubstance, iSubstance)       = -1;
                    else
                        this.mfHydrogenMatrix(iPreviousSubstance, iSubstance) = -1;
                    end
                end
                
                iFinalSubstance = aiSubstances(iTotalReactants);
                
                for iK = 1:iTotalReactants
                    iSubstance = aiSubstances(iK);
                    this.mfMolarSumMatrix(iFinalSubstance, iSubstance) = 1;
                end
            end
            
            % This line of the system of equations represents the charge
            % balance
            this.mfMolarSumMatrix(this.oMT.tiN2I.Hplus, :) = this.oMT.aiCharge;
            
            % This line represents the mass balance. If we multiply the
            % concentrations in mol/l with the molar mass with kg/mol we
            % receive kg/l and have to multiply it with the volume to get
            % the current mass
            this.mfMolarSumMatrix(this.oMT.tiN2I.OH, :) = this.oMT.afMolarMass;
            
            this.mfHydrogenMatrix(this.oMT.tiN2I.H2O, this.oMT.tiN2I.OH) = 1;
            this.mfDissociationMatrix(this.oMT.tiN2I.H2O, this.oMT.tiN2I.H2O) = 0;
            
            this.afBaseLeftSideVector = zeros(this.oMT.iSubstances,1);
            this.afBaseLeftSideVector(this.oMT.tiN2I.H2O) = this.oMT.afDissociationConstant(this.oMT.tiN2I.H2O);
            % The molar sums of the left side vector can be calculated by
            % the equation: this.mfMolarSumMatrix * afConcentrations' and
            % this must be added to this left side vector
            
            this.abRelevantSubstances(this.oMT.tiN2I.Hplus) = true;
            this.abRelevantSubstances(this.oMT.tiN2I.OH)    = true;
            this.abRelevantSubstances(this.oMT.tiN2I.H2O)   = true;
        end
        
    end
    
    methods (Access = protected)
        function update(this)
            update@matter.manips.substance.flow(this, this.afConversionRates);
        end
    end
end