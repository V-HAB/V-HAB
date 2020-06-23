classdef baseManip < base
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
        % Current pH Value of the phase in which this manipulator is
        % located
        fpH = 7;
        
        % Boolean to speed up the decision which substances actually
        % dissociated
        abDissociation;
        % Boolean for all relevant substances (which include substances
        % that do not disscociate because they are the final stage of
        % dissociation)
        abRelevantSubstances;
        
        % Current conversion rates of the manipulator in kg/s
        afConversionRates;
        
        % Current calculated concentrations in mol/l
        afConcentrations;
        
        % Matrix that provides the connectivity information between
        % dissocication complexes
        miComplex;
        
        % Vector containing the matter table indices for all participating
        % reactants
        aiReactants;
        % Total number of reactants
        iReactants;
        
        % The actual linear system of equations we have to solve is
        % generated from different matrices, one contains the references to
        % the dissocication constants, one to the H+ concentration and one
        % to molar balance equations:
        mfDissociationMatrix;
        mfHydrogenMatrix;
        mfOHMatrix;
        mfMolarSumMatrix;
        afBaseLeftSideVector;
        
        % To speed up simulation we store the last information of partial
        % mass ratios where we calculated the manip here, and only
        % recalculate it if a sufficient change occured
        arLastPartials;
        
        % Maximum percentage value by which a partial mass has to change to
        % warant recalculatuion
        rMaxChange = 0.01;
        
    end
    
    
    methods
        function this = baseManip(oPhase)
            this.abDissociation = oPhase.oMT.afDissociationConstant ~= 0;
            
            this.afConversionRates = zeros(1, oPhase.oMT.iSubstances);
            this.afConcentrations  = zeros(1, oPhase.oMT.iSubstances);
            
            % Each row asscociates one substance to a dissocication
            % complex, with the dissocication products ordered in the order
            % in which they occur. Note that only the initial substance has
            % entries here! If you want to add a new substance which should
            % be included in the pH calculations you have to adjust this
            % property!
            this.miComplex = zeros(this.oMT.iSubstances, this.oMT.iSubstances);

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

            this.aiReactants = find(this.miComplex(logical(eye(this.oMT.iSubstances, this.oMT.iSubstances))));
            this.iReactants  = length(this.aiReactants);
            
            createLinearSystem(this);
            
            this.arLastPartials    = zeros(1, sum(this.abRelevantSubstances));
        end
        function setMaxChange(this, rMaxChange)
            % This function can be used to overwrite the percentage limit
            % for recalculations in the manip.
            this.rMaxChange = rMaxChange;
        end
    end
    
    methods (Access = protected)
        
        function afConcentrations = calculateNewConcentrations(this, afInitialConcentrations, fInitialMassSum, fCurrentPH)
            % This function is used by the pH Manipulators to calculate the new
            % concentrations for the phase in equilibrium. For flow phases these are
            % assumed to be the outflow concentrations. For stationary manips, we
            % assume it takes 1 second to reach the equilibrium
            afCurrentConcentration  = afInitialConcentrations;
            afConcentrations        = afInitialConcentrations';

            fDissociationConstantWater = this.oMT.afDissociationConstant(this.oMT.tiN2I.H2O);
            % Charge sum of ions for which the concentration is not
            % solved by the system of equations
            fInitialChargeSum = this.oMT.aiCharge(~this.abRelevantSubstances) * afInitialConcentrations(~this.abRelevantSubstances)';

            % Now we calculate the correct equilibrium solution that
            % ensures chemical equilibrium and charge balance. However, the
            % actual mass conversion is not considered in this system,
            % therefore the mass balance must be ensured seperatly. It is
            % possible that the system would strive toward a different
            % equilibrium than is currently possible with the exisiting
            % phase content
            fError = inf;
            iCounter = 0;

            mfInitializationIntervall = [1e-20, 1e-14, 1e-13, 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-3, 1e-2, 1e-1, 100];
            fMaxError = 1e-7;
            fMaxIntervallSize = 1e-18;
            
            mfInitializatonError = zeros(1, length(mfInitializationIntervall));

            warning('OFF', 'all')
            for iBoundary = 1:length(mfInitializationIntervall)
                
                if fCurrentPH > 8
                    % For high pH Values it is more stable to use the OH
                    % concentration for the pH Calculation
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
            while ((abs(fError) > fMaxError) || fIntervallSize > fMaxIntervallSize || afConcentrations(this.oMT.tiN2I.Hplus) < 0)  && iCounter < 1000 

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
                    fIntervallSize = 0;
                    if mfError(2) > 0
                        fNewBoundary = mfIntervall(2);
                    else
                        fNewBoundary = mfIntervall(1);
                    end
                end
                % In some cases the correct value can move outside of
                % the current intervall because the concentration of
                % water also changes. To catch these cases we check if
                % the error of the right side intervall is still
                % positive every 100 iterations and if not reset the
                % right side boundary. Therefore we set the value here
                % to the right side boundary and then check after the
                % calculation if the error is still positive. If that
                % is not the case, we reset it to the initially
                % calculated boundary.
                if mod(iCounter,100) == 1
                    fNewBoundary = mfIntervall(2);
                end

                if fCurrentPH > 8
                    % For high pH Values it is more stable to use the OH
                    % concentration for the pH Calculation
                    afCurrentConcentration(this.oMT.tiN2I.Hplus) = 10^-(-log10(fDissociationConstantWater) - -log10(fNewBoundary));
                else 
                    afCurrentConcentration(this.oMT.tiN2I.Hplus) = fNewBoundary;
                end
                
                afCurrentConcentration(this.oMT.tiN2I.OH) = afCurrentConcentration(this.oMT.tiN2I.H2O) * fDissociationConstantWater / afCurrentConcentration(this.oMT.tiN2I.Hplus);

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

                % In some edge cases even the right boundary can move
                % outside of the valid region, then we shift the
                % boundary by one order of magnitude to ensure we have
                % a valid solution within the intervall
                if mod(iCounter,100) == 1
                    if abs(mfInitializationIntervall(iError+1) - mfIntervall(2)) < abs(mfInitializationIntervall(iError) - mfIntervall(1))
                        mfInitializationIntervall(iError+1) = mfInitializationIntervall(iError+1) * 10^floor(iCounter/100);
                        mfIntervall(2) = mfInitializationIntervall(iError+1);
                    else
                        mfInitializationIntervall(iError) = mfInitializationIntervall(iError) / 10^floor(iCounter/100);
                        mfIntervall(1) = mfInitializationIntervall(iError);
                    end
                end

                % Reset boundary in case both boundaries have a
                % negative error
                if mod(iCounter,100) == 0 && fError < 0
                    if mfError(2) > 0
                        mfIntervall(2) = mfInitializationIntervall(iError+1);
                    else
                        mfIntervall(1) = mfInitializationIntervall(iError);
                    end
                end
            end

            warning('ON', 'all')
            
            % Now we check that we do not create any substance through
            % numerical errors in the calculation:
            for iReactant = 1:this.iReactants
                abSubstances = this.miComplex(this.aiReactants(iReactant), :) > 0;
                if sum(afInitialConcentrations(abSubstances)) == 0
                    afConcentrations(abSubstances) = 0;
                end
            end

            % Since the solution of the system of equation is numerical
            % slight negative values might occur from numerical erros,
            % these are rounded. Other errors result in an error as
            % then something unexpected occured
            abNegative = afConcentrations < 0;
            if all(abs(afConcentrations(abNegative)) < 1e-10) && iCounter < 1000
                afConcentrations(abNegative) = 0;
            else
                error(['something in the pH calculation of phase ', this.oPhase.sName, ' in store ', this.oPhase.oStore.sName, ' went wrong'])
            end
            
            this.afConcentrations = afConcentrations;
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

            for iReactant = 1:this.iReactants
                iBaseSubstance = this.aiReactants(iReactant);

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
end