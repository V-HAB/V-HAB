classdef Adsorption_P2P < matter.procs.p2ps.flow & event.source
    % This a P2P processor to model the uptake of gaseous substances (e.g.
    % CO2 and H2O) into an absorber bed of amine/ionic liquid. It uses
    % substance-specific functions to calculate water content, CO2 content,
    % and temperature-dependant properties.
    % 
    % orignial creator: Jordan Holquist --> jholquist@gmail.com
    % for references, see:
    % M:\02-Forschung\01-Projekte_aktuell\V-HAB\References\HFC & Ionic
    % Liquids on the TUM LRT Staff Server Repository.
    %
    % ways to improve this P2P:
    % include   - thermal solvers (issue: no verification data)
    %           - specific heat capacity vs. water & temp.
    %               NOTE: Roemich et al (2012) has data vs. water and temp.
    %           - heat of absorption of CO2 
    %               NOTE: Shiflett and Yokozeki (2012) Table 8
    %           - heat of absorption of H2O
    %               NOTE: Rocha & Siflett (2019)
    %           - better phase equilibrium calculation for CO2 & H2O in ILs
    %               NOTE: Stevanovic et al (2012) has data at low ppCO2 with
    %               and without water present (water affects CO2 solubility)
    %               AND Ziobrowski and Rotkegel (2017) have some supporting
    %               data that may be used to test this effect with BMIMAc and
    %               EMIMAc ILs. Roemich et al (2012) and Passos et al (2014)
    %               have data and equations on H2O phase equilibrium. Baj
    %               et al (2015) have max. absorption estimates of CO2 as
    %               function of H2O in BMIMAc.
    %               
    %           - improved desorption model
    %           - improved vacuum or pump model & data tracking (plot)

    % Uses the linear driving force (LDF) assumption to calculate the 
    % current adsorption or desorption flowrate for the different substances. 
    % Since adsorption and desorption can both take place at the same time 
    % for different substances the adsorption P2P must be used in conjuction 
    % with a desorption P2P. The full calculation for both flowrates takes 
    % place in this P2P. This allows the modelling of an arbitrary number
    % of adsorbing and desorbing substances with only two P2Ps.
    %
    % The P2P is intended to be used in a discretized adsorber bed with
    % cell numbers for the different adsorption and desorption P2Ps using
    % gas flow nodes and the multi branch solver to dsicretize the adsorber
    % bed (see CDRA for an example)
    
    properties
        % String containing the current number of the numerical cell in
        % which this P2P is located. Necessary to address the correct
        % desorption processor
        sCell;
        % Integer containing the cell number
        iCell;
        
        % currently generated or consumed heat of adsorption
        fAdsorptionHeatFlow = 0;
        
        % Mass averaged value of the adsorption enthalpy (in case multiple
        % different adsorber substances are used in the same bed).
        % Otherwise it contains the adsorption enthalphy from the matter
        % table for the adsorber directly.
        mfAbsorptionEnthalpy;
        
        % partial inflowrates of all substances into the gas phase attached
        % to the adsorption P2P
        afLumenPartialInFlows;
        afShellPartialInFlows;
        
        % Boolean to decide if the P2P is currently desorbing or not, can
        % be set by the parent system for example to use simplified
        % calculations
        bDesorption;
        
        % To simplify the logging of the overall flowrates (and since they
        % are calculated anyway) we store both the adsorption and
        % desorption flows in this property
        mfFlowRates;
        
        % Include geometries of the absorber and the flow in order to use
        % surface area and residence time of gas in the flow to determine
        % mass transfer rate into the absorbing substance (IL)
        tGeometry;
        oLumen;
        oShell;
        tEquilibriumCurveFits;
        fHenrysConstant = 0;
        fEstimatedMassTransferCoefficient;
 
        fLumenResidenceTime = 0;
        fShellResidenceTime = 0;
    end
    
    methods
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% Constructor %%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [this] = Adsorption_P2P(oStore, sName, sPhaseIn, sPhaseOut, tGeometry, tEquilibriumCurveFits, fEstimatedMassTransferCoefficient)
            % oPhase.sType = 'gas' = oLumen ALWAYS
            % oPhase.sType = 'mixture' or 'liquid' = oShell ALWAYS
            % when bDesorption = false, solute substances (CO2 + H2O) are
            % removed from oLumen and put into oShell by this P2P
            % when bDesorption = true, solute substances (CO2 + H2O) are
            % removed from oShell and put into oLumen by this P2P
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);

            this.tGeometry = tGeometry;
            this.tEquilibriumCurveFits = tEquilibriumCurveFits;
            this.fEstimatedMassTransferCoefficient = fEstimatedMassTransferCoefficient;
                      
            % get the cell numbers from the name of the P2P
            this.sCell = this.sName(~isletter(this.sName));
            this.iCell = str2double(this.sCell(2:end));
            
            % get the adsorption enthalpies as mass averaged values in case
            % that multiple types of adsorbers are used. The following
            % if-statement is a catch in case the phases were provided in a
            % different order than expected.
            if strcmp(this.oIn.oPhase.sType, 'gas')
                this.oLumen = this.oIn;
                this.oShell = this.oOut;
            elseif strcmp(this.oIn.oPhase.sType, 'liquid') || strcmp(this.oIn.oPhase.sType, 'mixture')
                this.oShell = this.oIn;
                this.oLumen = this.oOut;
            elseif strcmp(this.oIn.oPhase.sType, 'solid') || strcmp(this.oOut.oPhase.sType, 'solid')
                fprintf('this P2P does not work with solids!')
                return;
            end
            afMass = this.oShell.oPhase.afMass;
            csAbsorbers = this.oMT.csSubstances(((afMass ~= 0) .* this.oMT.abAbsorber) ~= 0);

            fAbsorberMass = sum(afMass(this.oMT.abAbsorber));
            mfAbsorptionEnthalpyHelper = zeros(1,this.oMT.iSubstances);
            for iAbsorber = 1:length(csAbsorbers)
                rAbsorberMassRatio = afMass(this.oMT.tiN2I.(csAbsorbers{iAbsorber}))/fAbsorberMass;
                mfAbsorptionEnthalpyHelper = mfAbsorptionEnthalpyHelper + rAbsorberMassRatio * this.oMT.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.mfAbsorptionEnthalpy;
            end
            this.mfAbsorptionEnthalpy = mfAbsorptionEnthalpyHelper;
        end
        
        function calculateFlowRate(this, afInsideInFlowRates, aarInsideInPartials, afOutsideInFlowRates, aarOutsideInPartials)
            % This function is called by the multibranch solver, which also
            % calculates the inflowrates and partials (as the p2p flowrates
            % themselves should not be used for that we cannot use the gas
            % flow node values directly otherwise the P2P influences itself)                      
            
            %% discretize the absorption/desorption process spatially
            iCellNumber = this.tGeometry.iCellNumber;
            % fContactArea is the interface between gas and liquid, i.e. a
            % virtual "membrane" of the membrane's area
            fContactArea = this.tGeometry.Fiber.fContactArea / iCellNumber;     % [m^2/cell]
            fLength = this.tGeometry.Fiber.fLength / iCellNumber;    % [m/cell]
            
            % lumen side-specific properties and discretization (gas)
            fLumenVolume = this.tGeometry.Fiber.fVolumeLumenTotal / iCellNumber;    % [m^3/cell]
            fLumenCrossSection = this.tGeometry.Fiber.fCrossSectionLumenTotal;      % [m^2]
            fLumenTemperature = this.oLumen.oPhase.fTemperature;                    % [K]
                if ~isempty(this.oLumen.oPhase.fVirtualPressure)
                    fLumenPressure = this.oLumen.oPhase.fVirtualPressure;  % [Pa]
                else
                    fLumenPressure = this.oLumen.oPhase.fPressure;         % [Pa]
                end
                % should not happen, but just in case
                if fLumenPressure < 0
                    fLumenPressure = 0;                                 % [Pa]
                end
            fLumenDensity = this.oMT.calculateDensity(this.oLumen.oPhase); % [kg/m^3]
            
            fLumenMassFlowRate = sum(afInsideInFlowRates);  % [kg/s]
            if fLumenMassFlowRate < 1e-7
                fLumenMassFlowRate = 0;     % [kg/s]
                fLumenVelocity = 0;         % [m/s]
                this.fLumenResidenceTime = 0;    % [s/cell]
            else
                fLumenFlowRate = fLumenMassFlowRate / fLumenDensity;    % [m^3/s]
                fLumenVelocity = fLumenFlowRate / fLumenCrossSection;   % [m/s]
                this.fLumenResidenceTime = fLength / fLumenVelocity;         % [s/cell]
            end
            
            % shell side-specific properties and discretization (liquid)
            fShellVolume = this.tGeometry.Tube.fVolumeShell / iCellNumber;     % [m^3/cell]
            % shell cross-section area is multiplied by two because of how
            % the flow comes in at two inlet ports and converges on a
            % single exit port in the experiment.
            fShellCrossSection = this.tGeometry.Tube.fCrossSectionShell;            % [m^2]

            fShellDensity = components.matter.HFC.functions.calculateILDensity(this.oShell.oPhase);      % [kg/m^3]
            fShellViscosity = components.matter.HFC.functions.calculateILViscosity(this.oShell.oPhase);  % [mPa-s OR cP]
            fShellKinematicViscosity = fShellViscosity / fShellDensity * 1e-3;              % [m^2/s] Kinematic viscosity

            fShellMassFlowRate = sum(afOutsideInFlowRates);         % [kg/s]
            fShellFlowRate = fShellMassFlowRate / fShellDensity;    % [m^3/s] = 1.51e-6 X-Hab IL flow rate (90.6 ml/min)
            fShellVelocity = fShellFlowRate / fShellCrossSection;   % [m/s]
            
            this.fShellResidenceTime = this.tGeometry.Tube.fLength / fShellVelocity;    % [s/cell]
            
            %% mass transfer coefficient calculation
            this.tGeometry.mfMassTransferCoefficient = zeros(1,this.oMT.iSubstances);
            fMolarVolumeCO2_NBP = 33.3;     % [cm^3/mol] NBP = normal boiling point (Morgan 2005)
            fMolarVolumeH2O_NBP = 18.798;   % [cm^3/mol]
            fNullDiffusivityCO2 = 1E-4 * 2.66E-3 / (fShellViscosity^0.66 * fMolarVolumeCO2_NBP^1.04);   % [m^2/s]
            fDiffusionEnergy = 30.74;       % [kJ/mol] for BMIMAc
            % fDiffusionEnergy = 27.91 [kJ/mol] for EMIMAc
            
            % Arrhenius model of CO2 diffusion coefficient
            % [m^2/s], see Santos, Albo, and Irabien (2014)
            fDiffusivityCO2 = fNullDiffusivityCO2 .* exp(-fDiffusionEnergy/this.oMT.Const.fUniversalGas/fLumenTemperature);
            
            % local variables for H2O diffusion calculation (maybe make
            % this into a separate function)
            fShellTemperature = fLumenTemperature;  % [K] (wrong, but ok for now without thermal model)
            H0 = 18*this.oMT.Const.fBoltzmann*fShellTemperature;
            H1 = 40*this.oMT.Const.fBoltzmann*fShellTemperature;
            S1 = 38*this.oMT.Const.fBoltzmann;
            fBaylesConstant = 0.004;        % [m^2/s] (Bayles et al 2019)
            afShellMolFractions    = (this.oShell.oPhase.arPartialMass ./ this.oMT.afMolarMass) ./ sum(this.oShell.oPhase.arPartialMass ./ this.oMT.afMolarMass);
            
            % Arrhenius (Temperature) & Water content model of H2O
            % diffusion coefficient [m^2/s]
            % source: Bayles et al (2019)
            % assumption: IM (imidazolium) cation, no interaction from Ac anion
            fDiffusivityH2O = fBaylesConstant .* exp(-H0/this.oMT.Const.fBoltzmann/fShellTemperature) .* exp((H1/this.oMT.Const.fBoltzmann/fShellTemperature - S1/this.oMT.Const.fBoltzmann).*afShellMolFractions(this.oMT.tiN2I.H2O));
            % ESTIMATE: 1.7 x10^-11 [m^2/s] in BMIMAc at 294.85K, 77.8 mol% H2O, Rocha and Shiflett (2019)
            % ESTIMATE: 2.8 x10^-11 [m^2/s] in BMIMAc at 303.15K, 78.1 mol% H2O, Rocha and Shiflett (2019)
            % ALTERNATIVE CALCULATION
            % (Following Morgan et al (2005)
            % fDiffusivityH2O = 1E-4 * 2.66E-3 / (fShellViscosity^0.66 * fMolarVolumeH2O_NBP^1.04);
            
            % GENERAL EQUATIONS
            % these equations are used in some form in MOST hollow fiber
            % contactor papers, of which there are many in the VHAB/HFC
            % references. The exact coefficients are the hard part to
            % estimate. The X-Hab team made a tool to estimate fFitCoeffA,
            % but fFitCoeffB and fFitCoeffC were left untouched.
            % Sh = a * Re^b * Sc^c (sherwood number)
            % k = Sh * DCO2 / od (mass transfer coefficient)
            fReynoldsNumber = this.tGeometry.Tube.fHydraulicDiameter ...
                * (fShellVelocity) ...
                * (1 / fShellKinematicViscosity);
            fSchmidtNumberCO2 = fShellKinematicViscosity / fDiffusivityCO2;
            fSchmidtNumberH2O = fShellKinematicViscosity / fDiffusivityH2O;
            
            % Fitting Coefficients Experimentally Determined
            % FROM X-Hab paper, fFitCoeffA = 5.58
            % FROM my calculation with their fit tool and updated params
            % fFitCoeffA = 0.5714
            % to use this tool, use HFCModelCalibration.m in
            % VHAB/STEPS/+users/+examples/+HFC/HFCModelCalibration.m
            fFitCoeffA = 12.83;
            fFitCoeffB = 0.67;
            fFitCoeffC = 0.33;

            fSherwoodNumberCO2 = fFitCoeffA * (fReynoldsNumber^fFitCoeffB) ...
                * (fSchmidtNumberCO2^fFitCoeffC);
            fSherwoodNumberH2O = 0.8 .* (fReynoldsNumber^0.47) ...
                * (fSchmidtNumberH2O^fFitCoeffC);
            % ALTERNATIVE CALCULATIONS
%             fSherwoodNumberCO2 = (3.67^3 + 1.62^3 * fShellVelocity ...
%                 * this.tGeometry.Fiber.fInnerDiameter^2 ...
%                 / fDiffusivityCO2 / this.tGeometry.Fiber.fLength)^(1/3);
%             fSherwoodNumberCO2 = 1.45.*(fReynoldsNumber*fSchmidtNumberCO2*this.tGeometry.Fiber.fOuterDiameter./this.tGeometry.Tube.fLength)^0.33;

            % units of MassTransferCoefficients = [m/s]
            this.tGeometry.mfMassTransferCoefficient(this.oMT.tiN2I.CO2) = fSherwoodNumberCO2 * fDiffusivityCO2 / this.tGeometry.Tube.fHydraulicDiameter;
            this.tGeometry.mfMassTransferCoefficient(this.oMT.tiN2I.H2O) = fSherwoodNumberH2O * fDiffusivityH2O / this.tGeometry.Tube.fHydraulicDiameter;
            
            %% get flow rates and flow partials
            % Calculate for the Lumen (Inside) of the P2P
            if ~(isempty(afInsideInFlowRates) || all(sum(aarInsideInPartials) == 0))
                this.afLumenPartialInFlows = sum((afInsideInFlowRates .* aarInsideInPartials),1);   % substance-specific [kg/s in at tick]
            else
                this.afLumenPartialInFlows = zeros(1,this.oMT.iSubstances);                         % substance-specific [kg/s in at tick]
            end
            afLumenCurrentMolsIn    = (this.afLumenPartialInFlows ./ this.oMT.afMolarMass);         % substance-specific [mol/s in at tick]
            arLumenFractions        = afLumenCurrentMolsIn ./ sum(afLumenCurrentMolsIn);            % substance-specific [ratio in at tick]
            afPP                    = arLumenFractions .*  fLumenPressure;                          % substance-specific [Pa in at tick]
            
            % Calculate for the Shell (Outside) of the P2P
            if ~(isempty(afOutsideInFlowRates) || all(sum(aarOutsideInPartials) == 0))
                this.afShellPartialInFlows = sum((afOutsideInFlowRates .* aarOutsideInPartials),1); % substance-specific [kg in at tick]
            else
                this.afShellPartialInFlows = zeros(1,this.oMT.iSubstances);                         % substance-specific [kg in at tick]
            end
            afShellCurrentMolsIn    = (this.afShellPartialInFlows ./ this.oMT.afMolarMass);         % substance-specific [mol in at tick]
            arShellFractions        = afShellCurrentMolsIn ./ sum(afShellCurrentMolsIn);            % substance-specific [ratio in at tick]
                        
            %% actual p2p process for CO2 and H2O from Lumen (gas) to Shell (mixture/liquid)            
            % similar to the small partial pressures, we also ignore
            % very small absorber masses to prevent osciallations
%             afShellMass(afShellMass < 1e-9) = 0;

            % i.e. moles CO2 / volume CO2-IL-H2O mixture
            % X-Hab absorption rates are based on inlet molar concentration, mass
            % transfer coefficient, and residence time
            afLumenFlowMols = afLumenCurrentMolsIn .* this.fLumenResidenceTime;     % [mol/tick]
            afLumenFlowMolsPerVolume = afLumenFlowMols ./ fLumenVolume;             % [mol/m^3-tick]
            afShellFlowMols = afShellCurrentMolsIn .* this.fShellResidenceTime;     % [mol/tick]
            afShellFlowMolsPerVolume = afShellFlowMols ./ fShellVolume;             % [mol/m^3-tick]
            
            %% Calculating Absorption and Desorption Flow Rates of Substances
            [fWaterEQPressure, rWaterEQMolFractionInGas] = components.matter.HFC.functions.calculateWaterILEquilibrium(this.oLumen.oPhase, this.oShell.oPhase);            
            [fEquilibriumCO2Pressure, this.fHenrysConstant] = components.matter.HFC.functions.calculateILEquilibriumImproved(this.oLumen.oPhase, this.oShell.oPhase, this.tEquilibriumCurveFits, fShellDensity);
            % if fWaterEQPressure is lower than the current ppH2O in the
            % gas phase, then H2O will absorb into the IL from the gas
            % phase until the ppH2O in the gas phase is reduced to the
            % fWaterEQPressure. A positive fDeltaWaterVaporPressure means
            % flow into the liquid phase from the gas phase.
            % Currently uses flow moles.
            % HENRY'S CONSTANT:
            % See Costa Gomes and Lepre (2017) for calculation of this
            % H = 77.8 is for pure BMIMAc, so it is multiplied by ratio of
            % how much BMIMAc is present in the shell assuming linear
            % dependence on molar ratio. This is a simplification.
            % Results look decent.
            this.fHenrysConstant = 77.8 .* arShellFractions(this.oMT.tiN2I.BMIMAc);  % TESTING

            fEQDeltaWaterVaporPressure = afPP(this.oMT.tiN2I.H2O) - fWaterEQPressure;
            fEQDeltaWaterVaporMols = fEQDeltaWaterVaporPressure .* fLumenVolume ./ this.oMT.Const.fUniversalGas ./ fLumenTemperature;
            fEQDeltaWaterVaporMolsPerVolume = fEQDeltaWaterVaporMols ./ fLumenVolume;
            
            %% calculate the equilibrium loading at current conditions
            % ALL VALUES
            afDeltaFlowMolesPerVolume = afLumenFlowMolsPerVolume - afShellFlowMolsPerVolume;            % [delta mol/m^3-tick]
            afMolarFluxRates = afDeltaFlowMolesPerVolume .* this.tGeometry.mfMassTransferCoefficient;   % [mol/m^2*s]
            afMassFluxRates = afMolarFluxRates .* this.oMT.afMolarMass;         % [kg/m^2*s]
            this.mfFlowRates = afMassFluxRates .* fContactArea;                 % [kg/s]
            
            % CARBON DIOXIDE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            fLogMeanMolarConcDifference = (arLumenFractions(this.oMT.tiN2I.CO2) - (fEquilibriumCO2Pressure./fLumenPressure)) / log(arLumenFractions(this.oMT.tiN2I.CO2)/((fEquilibriumCO2Pressure./fLumenPressure)));           
            
            % TEST - using different concentration difference drivers
            fEQDeltaCO2MolesPerVolume = fLogMeanMolarConcDifference .* fLumenPressure ./ this.oMT.Const.fUniversalGas ./ fLumenTemperature;
%             fEQDeltaCO2MolesPerVolume = (afPP(this.oMT.tiN2I.CO2) - fEquilibriumCO2Pressure) ./ this.oMT.Const.fUniversalGas ./ fLumenTemperature;
%             fEQDeltaCO2MolesPerVolume = afLumenFlowMolsPerVolume(this.oMT.tiN2I.CO2) - fEQDeltaCO2MolesPerVolume;            

            % TEST - using estimated mass xfer coeff. & Henry's coefficient
            fMolarFluxRatesCO2 = fEQDeltaCO2MolesPerVolume .* this.tGeometry.mfMassTransferCoefficient(this.oMT.tiN2I.CO2);  
            afMolarFluxRates(this.oMT.tiN2I.CO2) = fMolarFluxRatesCO2 .* this.fHenrysConstant;
%             fMolarFluxRatesCO2 = fEQDeltaCO2MolesPerVolume .* this.tGeometry.mfMassTransferCoefficient(this.oMT.tiN2I.CO2);
%             fMolarFluxRatesCO2 = fEQDeltaCO2MolesPerVolume .* this.fEstimatedMassTransferCoefficient;

            % TEST - using estimated mass xfer coeff. & Henry's coefficient
            % afMolarFluxRates(this.oMT.tiN2I.CO2) = fMolarFluxRatesCO2;
            afMassFluxRates(this.oMT.tiN2I.CO2) = afMolarFluxRates(this.oMT.tiN2I.CO2) .* this.oMT.afMolarMass(this.oMT.tiN2I.CO2);
            this.mfFlowRates(this.oMT.tiN2I.CO2) = afMassFluxRates(this.oMT.tiN2I.CO2) .* fContactArea;
            
            % WATER %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            fMolarFluxRatesH2O = fEQDeltaWaterVaporMolsPerVolume .* this.tGeometry.mfMassTransferCoefficient(this.oMT.tiN2I.H2O);
            afMolarFluxRates(this.oMT.tiN2I.H2O) = fMolarFluxRatesH2O;
            afMassFluxRates(this.oMT.tiN2I.H2O) = afMolarFluxRates(this.oMT.tiN2I.H2O) .* this.oMT.afMolarMass(this.oMT.tiN2I.H2O);         % [kg/m^2*s]
            this.mfFlowRates(this.oMT.tiN2I.H2O) = afMassFluxRates(this.oMT.tiN2I.H2O) .* fContactArea;                 % [kg/s]
                        
            % split flow rate into adsorption and desorption
            mfFlowRatesAdsorption = zeros(1,this.oMT.iSubstances);
            mfFlowRatesDesorption = zeros(1,this.oMT.iSubstances);
            mfFlowRatesAdsorption(this.mfFlowRates > 0) = this.mfFlowRates(this.mfFlowRates > 0);
            mfFlowRatesDesorption(this.mfFlowRates < 0) = this.mfFlowRates(this.mfFlowRates < 0);
            
            % In the calculation of the adsorption flow, it is possible
            % that the calculated flowrate we try to adsorb is higher than
            % the current inflowing mass of a substance. Therefore, we
            % limit the value
            abAbsorptionLimitFlows = mfFlowRatesAdsorption > this.afLumenPartialInFlows;
            abDesorptionLimitFlows = mfFlowRatesDesorption > this.afShellPartialInFlows;
            mfFlowRatesAdsorption(abAbsorptionLimitFlows) = this.afLumenPartialInFlows(abAbsorptionLimitFlows);
            mfFlowRatesDesorption(abDesorptionLimitFlows) = -this.afShellPartialInFlows(abDesorptionLimitFlows);
            
            %% IF TREE
            % use fShellCurrentMolFraction of CO2 to set rate of direction
            % of CO2 mass transfer (absorption/desorption)
            % for initial case (bypass flow) set combined flow rates to 0
            fAdsorptionFlowRate = 0;
            fDesorptionFlowRate = 0;
            arPartialsAdsorption = zeros(1,this.oMT.iSubstances);
            arPartialsDesorption = zeros(1,this.oMT.iSubstances);
            if this.fLumenResidenceTime == 0
                this.mfFlowRates = 0;
            else
                if afPP(this.oMT.tiN2I.CO2) > fEquilibriumCO2Pressure
                    % if there is still more CO2 capacity in shell
                    if this.bDesorption == false
                        % absorber function (Tube 1)
                        % then the Lumen CO2 IS absorbed into the Shell
                        fAdsorptionFlowRate   	= sum(mfFlowRatesAdsorption);
                        if fAdsorptionFlowRate ~= 0
                            arPartialsAdsorption(mfFlowRatesAdsorption~=0)  = abs(mfFlowRatesAdsorption(mfFlowRatesAdsorption~=0)./sum(mfFlowRatesAdsorption));
                        end
                        mfFlowRatesAdsorption = fAdsorptionFlowRate .* arPartialsAdsorption;
                        
                    else
                        % NOTE: Without a robust desorption model, this section
                        % will need to be fudged somehow, as the current model
                        % only extends to relatively high CO2 partial pressure
                        %
                        % desorber function (Tube 2)
                        % then the Shell CO2 is NOT desorbed into the Lumen
                        fDesorptionFlowRate = sum(mfFlowRatesDesorption);
                        if fDesorptionFlowRate ~= 0
                            arPartialsDesorption(mfFlowRatesDesorption~=0)  = abs(mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./sum(mfFlowRatesDesorption));
                        end
                        mfFlowRatesDesorption = fDesorptionFlowRate .* arPartialsDesorption;
                    end
                else
                    % if shell is full of CO2, can only desorb
                    if this.bDesorption == false
                        % absorber function (Tube 1)
                        % then the Lumen CO2 is NOT absorbed into the Shell
                        fAdsorptionFlowRate   	= sum(mfFlowRatesAdsorption);
                        if fAdsorptionFlowRate ~= 0
                            arPartialsAdsorption(mfFlowRatesAdsorption~=0)  = abs(mfFlowRatesAdsorption(mfFlowRatesAdsorption~=0)./sum(mfFlowRatesAdsorption));
                        end
                        mfFlowRatesAdsorption = fAdsorptionFlowRate .* arPartialsAdsorption;
                    else
                        % desorber function (Tube 2)
                        % then the Shell CO2 IS desorbed into the Lumen
                        % set this flow rate based on the mass transfer coefficient
                        fDesorptionFlowRate = sum(mfFlowRatesDesorption);
                        if fDesorptionFlowRate ~= 0
                            arPartialsDesorption(mfFlowRatesDesorption~=0)  = abs(mfFlowRatesDesorption(mfFlowRatesDesorption~=0)./sum(mfFlowRatesDesorption));
                        end
                        mfFlowRatesDesorption = fDesorptionFlowRate .* arPartialsDesorption;
                    end
                end
                
            end

            %% Set the values for the two P2Ps
            this.oStore.toProcsP2P.(['AdsorptionProcessor',this.sCell]).setMatterProperties(fAdsorptionFlowRate, arPartialsAdsorption);
            this.oStore.toProcsP2P.(['DesorptionProcessor',this.sCell]).setMatterProperties(fDesorptionFlowRate, arPartialsDesorption);
            
        end
    end
    methods (Access = protected)
        function update(~)
            % this must be here since the normal V-HAB logic tries to
            % call the update
        end
    end
end
