function [tOutputs] = calculateLocalHeatFlow(oCHX, tInput)

% q_dot_x: Calculation of heat flux, film surface temperature and condensation rate of a
% condensing heat exchanger at a local position x. Values are then applied to a finite cell 
% and the output values are calculated: Condensate mass flow, outlet temperatures of
% gas and coolant, heat flows (gas, condensate, coolant)

% Detailed description in semester thesis:
% Development of a dynamic Condensing Heat Exchanger Simulation Model for Virtual Habitat
% Alexander L. Schmid, 2018, lrt, Supervisor: Daniel Puetz
% ref.ed eqs. to be found there if not stated otherwise

% Calculations based on VDI Waermeatlas (Heat Atlas), 11th edition, 2013, ref.ed as [1]
% Chapters:
%	D1: Berechnungsmethoden fuer Stoffeigenschaften,
% 	G1:	Durchstroemte Rohre,
% 	J1: Filmkondensation reiner tInput.fCellAreaempfe and
% 	J2: Kondensation von Mehrstoffgemischen

% Some basic formulas from W. Polifke et al. Waermeuebertragung, 2nd edition, 2009, ref.ed as [2]

% ##### Definition ######
% #	heat flux: [W/m^2]	#
% #	heat flow: [W]		#
% #######################

fVaporisationEnthalpy = oCHX.mPhaseChangeEnthalpy(oCHX.oMT.tiN2I.(tInput.Vapor)); 	% Enthalpy of Vaporisation[J/kg]

% Thermal transmittance between coolant and wall of gas side [W/(m^2*K)]:
fHeatTransferCoeffWallCoolant = ((tInput.fThickness/tInput.fThermalConductivitySolid) + ((tInput.fFinThickness/tInput.fThermalConductivitySolid)*tInput.iFinCoolant) + (1/tInput.alpha_coolant))^(-1); % 

% Diffusion coefficient of binary gas mixture [m/s^2], (2.20)
DiffCoeff_Gas = Bin_diff_coeff(tInput.Vapor, tInput.Inertgas, tInput.fTemperatureGas, tInput.fPressureGas);

% Switch between calculation of vertical and horizontal pipe:
% Vertical:   Calculation with gravity acting on condensate film (flowing down)
% Horizontal: Calculation with simulated zero-gravity condition
tInput_Type = tInput.CHX_Type;

% Protection againt selecting 'HorizontalTube && GasFlow = false' that is not covered in these algorithms
if strcmp(tInput_Type,'HorizontalTube') && (tInput.GasFlow == false)
	warning('HorizontalTube only possible with GasFlow == true!');
	return
end

% Calculation of dimensionless quantities:
Re_Gas = ReynoldsNumberGas(tInput.fMassFlowGas, tInput.fDynamicViscosityGas, tInput.fHydraulicDiameter, tInput_Type);	% Reynolds-Number gas mixture [-], (2.12)

Pr_Gas = (tInput.fDynamicViscosityGas * tInput.fSpecificHeatCapacityGas) / tInput.fThermalConductivityGas;	% Prandtl-Number gas mixture [-], (2.41)

Nu_Gas_0 = NusseltNumberGas(Re_Gas, Pr_Gas, tInput.fHydraulicDiameter, tInput.fCharacteristicLength);											% Nusseltnumber of gas mixture [-], (2.40)

Sc_Gas = tInput.fKinematicViscosityGas / DiffCoeff_Gas;													% Schmidt-Number of gas mixture [-], (2.44)

% No this is not a typo, the Sherwood number can be calculated using the
% same equations as the nusselt number, by just using Sc instead of Pr. See
% the VDI heat atlas section which is mentioned in the function!
Sh_Gas_0 = NusseltNumberGas(Re_Gas, Sc_Gas, tInput.fHydraulicDiameter, tInput.fCharacteristicLength);												% Sherwood number of gas mixture [-], (2.43)

% -----

beta_Gas_0 = Sh_Gas_0 * DiffCoeff_Gas / tInput.fHydraulicDiameter;												% Mass transfer coefficient gas mixture [m/s], (2.45)

% Calculation of two separate heat flux paths from the gas through the condensate film and wall to the coolant (Algorithms 1 & 2):
% 
% Step 1: Variation of film surface temperature -> two different heat flux values:
% 			mfGasHeatFlux
% 			mfCoolantHeatFlux
% 
% Step 2: Calculation of intersection point of both curves 
% 			-> linear interpolation of actual heat flux, film surface temperature and specific vapor mass flow rate

%% Step 1:
fDeltaTemp = tInput.fTemperatureGas - tInput.fTemperatureCoolant;

% if smaller than 1e-13 fDelta equals zero and everything else goes NaN
if fDeltaTemp > 1e-10
    
% Initially the algorithm simply calculates the heat flows at all
% temperatures in between the coolant and gas temperature, this step
% decides the inidividual steps made in that case in [K]
fSearchStep = 1;
if fDeltaTemp < fSearchStep
    fSearchStep = 0.5 * fDeltaTemp;
end
% TO DO: this could be further improved by first using a rough search step,
% and then using finer steps. However this plus linear interpolation should
% already yield quite good results.

mfTemperature = tInput.fTemperatureCoolant:fSearchStep:tInput.fTemperatureGas;
if mfTemperature(end) ~= tInput.fTemperatureGas
    mfTemperature(end+1) = tInput.fTemperatureGas;
end

iSteps = length(mfTemperature);

% Initialisation of arrays:
mfMolFractionVaporAtSurface     = zeros(iSteps,1);
mfSpecificMassFlowRate_Vapor    = zeros(iSteps,1);
mfBeta_Gas                      = zeros(iSteps,1);
mfGasHeatFlux                   = zeros(iSteps,1);
mfCoolantHeatFlux               = zeros(iSteps,1);
mfFilmFlowRate                  = zeros(iSteps,1);

%% Calculation of the heatflows from gas to film and coolant to film for all temperatures in between the coolant and gas temperature
for iStep = 1:iSteps
	% Molar fraction of vapor right above the condensate film surface [-], based on Antoine equation, (2.39)
    try
        % It is faster to store the interpolation in the CHX:
        mfMolFractionVaporAtSurface(iStep) = oCHX.hVaporPressureInterpolation(mfTemperature(iStep)) / tInput.fPressureGas;
    catch oErr
        mfMolFractionVaporAtSurface(iStep) = oCHX.oMT.calculateVaporPressure(mfTemperature(iStep), tInput.Vapor) / tInput.fPressureGas;
        
        oCHX.hVaporPressureInterpolation = oCHX.oMT.ttxMatter.(tInput.Vapor).tInterpolations.VaporPressure;
    end
    if tInput.fMassFlowFilm == 0
        mfMolFractionVaporAtSurface(iStep) = 0;
    end
 
    % Consideration of Stefan diffusion in mass transfer coefficient [m/s], (2.36)
    if tInput.fMolarFractionVapor == 0 && tInput.fMassFlowFilm == 0
        % In this case we neither have a vapor nor a film, so there will no
        % diffusion
        mfSpecificMassFlowRate_Vapor(iStep) = 0;
    else
        mfBeta_Gas(iStep) = beta_Gas_0 * (tInput.fMolarFractionVapor - mfMolFractionVaporAtSurface(iStep))^(-1) * log((1 - mfMolFractionVaporAtSurface(iStep))/(1 - tInput.fMolarFractionVapor));

        % Wall-normal area-specific diffusive vapor mass flow [kg/(s*m^2)], (2.33)
        mfSpecificMassFlowRate_Vapor(iStep) = mfBeta_Gas(iStep) * tInput.fDensityGas * (tInput.fMolarFractionVapor - mfMolFractionVaporAtSurface(iStep));
    end
    % Heat transfer coefficient between gas and film [W/(m^2 K)], (2.42)
    fHeatTransferCoeff_Gas_0 = (Nu_Gas_0 * tInput.fThermalConductivityGas) / tInput.fHydraulicDiameter;

    % Factor for Ackermann-Correction [-], (2.35)
    a_q = (mfSpecificMassFlowRate_Vapor(iStep) * tInput.fSpecificHeatCapacityGas) / fHeatTransferCoeff_Gas_0;

    % Heat transfer coefficient between gas and film with Ackermann-Correction (considers Stefan diffusion as further above) [W/m^2 K], (2.34)
    fHeatTransferCoeffGas = fHeatTransferCoeff_Gas_0 * a_q / (1 - exp(-a_q));

    % New condensate film mass flow rate (inflow + new condensed water) [kg/s]
    mfFilmFlowRate(iStep) = tInput.fMassFlowFilm + mfSpecificMassFlowRate_Vapor(iStep) * tInput.fCellArea;
    % Consideration of possible vaporization
    if mfFilmFlowRate(iStep) < 0
        if tInput.fMassFlowFilm < 0
            mfSpecificMassFlowRate_Vapor(iStep) = 0;
        else
            mfSpecificMassFlowRate_Vapor(iStep) = - tInput.fMassFlowFilm / tInput.fCellArea;
        end
        mfFilmFlowRate(iStep) = 0;
    end
    
    % Heat flux between gas and film (includes latent heat of condensing vapor!)
    mfGasHeatFlux(iStep) = fHeatTransferCoeffGas * (tInput.fTemperatureGas - mfTemperature(iStep)) + mfSpecificMassFlowRate_Vapor(iStep) * fVaporisationEnthalpy;

    % Calculation of regular heat exchanger in case of no condensate film, e.g. if gas is still to warm to start condensing
    if mfFilmFlowRate(iStep) == 0
		% Calculation for the case without condensation -> normal HX equations!
		% Heat transfer coefficient between wall on gas side and coolant [W/m^2 K]
        fHeatTransferCoeffCoolant   = ((tInput.fFinThickness/tInput.fThermalConductivitySolid)*tInput.iFinAir) + (1/tInput.alpha_coolant + tInput.fThickness / tInput.fThermalConductivitySolid)^-1; %

        % Heat flux towards coolant [W/m^2]
        mfCoolantHeatFlux(iStep) = fHeatTransferCoeffCoolant * (mfTemperature(iStep) - tInput.fTemperatureCoolant);
        % if nothing evaporates the gas heat flow must be recalculated
        if mfSpecificMassFlowRate_Vapor(iStep) <= 0
            fHeatTransferCoeffGas = (1/tInput.alpha_gas)^-1;
            mfGasHeatFlux(iStep)  = fHeatTransferCoeffGas     * (tInput.fTemperatureGas - mfTemperature(iStep));
        end
    % Calculation of condensing heat exchanger if condensate film exists
    else
        Re_Film = ReynoldsNumberFilm(mfFilmFlowRate(iStep), tInput.fDynamicViscosityFilm, tInput.fHydraulicDiameter, tInput_Type);	% Reynolds number Condensate Film [-], (2.55)
        if Re_Film >= 10000
            warning('Re_Film >= 10000: Range of validity exceeded!');
            return
        end

        Pr_Film = tInput.fDynamicViscosityFilm * tInput.fSpecificHeatCapacityFilm / tInput.fThermalConductivityFilm;			% Prandtl number of condensate film [-], (2.56)
        if Pr_Film <= 0.5 || Pr_Film >=500
            warning('Pr_Film: Range of validity exceeded!');
            return
        end

        % Nusselt number of laminar film with wavy surface influence [-], (2.60)
        Nu_Film_lam = 0.7 * Re_Film^(-0.29);

        % Nusselt number of turbulent film [-], (2.54)
        Nu_Film_turb = (0.0283 * Re_Film^(7/24) * Pr_Film^(1/3))/(1 + 9.66 * Re_Film^(-3/8) * Pr_Film^(-1/6));

        %% ---- Consideration of gas flow influence on heat transfer within the condensate film ----
        switch tInput.GasFlow
            case true % Consideration of gas flow influence on heat transfer in condensate film
                Re_Gas_Film = Re_Gas;	% Simplification for low condensation rates at low pressure

                % Calculation of gas flow velocity
                switch tInput_Type
                    case {'VerticalTube','HorizontalTube'}
                        velocity_Gas_mean = (4 * tInput.fMassFlowGas)/(pi * tInput.fDensityGas * tInput.fHydraulicDiameter^2);
                    otherwise
                        warning('velocity_Gas_mean: Only VerticalTube and HorizontalTube implemented yet\n')
                        return
                end

                % Calculation of flow parameter F [-] according to [1] J1 eq. (32), thesis: (2.77)
                fFlowparameter_numerator_1 = (2 * Re_Film)^0.5;
                fFlowparameter_numerator_2 = 0.132 * Re_Film^0.9;
                fFlowparameter_numerator = max(fFlowparameter_numerator_1, fFlowparameter_numerator_2);
                fFlowparameter = (fFlowparameter_numerator / (Re_Gas_Film^0.9)) * (tInput.fDynamicViscosityFilm / tInput.fDynamicViscosityGas) * sqrt(tInput.fDensityGas/tInput.fDensityFilm);

                % Dimensionless friction coefficient for hydraulically smooth pipe, (2.78)
                fFrictionCoeffSmoothPipe = 0.184 * Re_Gas_Film^(-0.2);

                % Calculation of film thickness (value only valid within gas flow formulas!)
                switch tInput_Type
                    case 'VerticalTube'		% Gravity acting on condensate film
                        fDelta_Film_plus = 6.59 * fFlowparameter * tInput.fHydraulicDiameter / sqrt(1 + 1400 * fFlowparameter);	% Condensate film thickness [m], (2.76)
                    case 'HorizontalTube'	% Gravity ** not ** acting on condensate film
                        fVolumetricVaporFraction = 1 - 1 / (1 + (1 / (8.48 * fFlowparameter)));					% Volumetric vapor fraction [-], (2.87)
                        fDelta_Film_plus = (1 - fVolumetricVaporFraction)/4 * tInput.fHydraulicDiameter;									% Condensate film thickness [m], (2.86)
                        % Validity check:
                        if fVolumetricVaporFraction < 0.67
                        	warning('volGasFraction has to be >= 0.67!')
                        	return
                        end
                    otherwise
                        warning('Please choose VerticalTube or HorizontalTube as tInput_Type')
                        return
                end

                % Shear stress of hydraulically smooth pipe [N/m^2], (2.75)
                fShearStressGas_SmoothPipe = (fFrictionCoeffSmoothPipe / 8) * tInput.fDensityGas * velocity_Gas_mean^2;
                % Dimensionless shear stress of hydraulically smooth pipe [-], (2.71)
                fShearStressGas_SmoothPipe_star = fShearStressGas_SmoothPipe / (tInput.fDensityFilm * 9.81 * fDelta_Film_plus);

                % Exponent selection for describing ratio of shear stress and gravitational force of condensate film, (2.72)
                if fShearStressGas_SmoothPipe_star > 1
                    fShearStress_exp = 0.3;
                else
                    fShearStress_exp = 0.85;
                end

                fShearStressGas_star = fShearStressGas_SmoothPipe_star;		% Initial value for iteration loop

                fError_ShearStressGas = 1;					% Initial error value
                iCounter_ShearStressGas = 0;				% Initial counter value

                % Iteration to calculate dim.less shear stress
                while (fError_ShearStressGas > 1e-5) && (iCounter_ShearStressGas < 10000)
                    fShearStressGas_star_new = fShearStressGas_SmoothPipe_star * (1 + 550 * fFlowparameter * fShearStressGas_star^fShearStress_exp);	% [N/m^2], (2.70)
                    fError_ShearStressGas = abs(fShearStressGas_star_new - fShearStressGas_star);									% Difference between values (n) and (n-1)

                    fShearStressGas_star = fShearStressGas_star_new;

                    iCounter_ShearStressGas = iCounter_ShearStressGas + 1;
                end

                % Factor for including alteration of near-wall sublayer due to gas flow above film in Nusselt number
                switch tInput_Type
                    case 'VerticalTube'
                        K_Wall_lam  = (1 + 1.5 * fShearStressGas_star)^(1/3);	% [-], (2.66)
                        K_Wall_turb = (1 + fShearStressGas_star)^(1/3);			% [-], (2.67)
                    case 'HorizontalTube'
                        K_Wall_lam = fShearStressGas_star^(1/3);				% [-], (2.85)
                        K_Wall_turb = K_Wall_lam;						% [-], (2.85)
                    otherwise
                        warning('Please choose VerticalTube or HorizontalTube as tInput_Type')
                end

     			% Including alteration of near-wall sublayer due to gas flow above film in Nusselt number
                Nu_Film_lam_plus  = K_Wall_lam * Nu_Film_lam;				% [-], (2.64)
                Nu_Film_turb_plus = K_Wall_turb * Nu_Film_turb;				% [-], (2.65)

                % Factor for including excitation of turbulences in the near-surface bountInput.fCellAreary layer
                K_PhB_lam  = 1 + (Pr_Film^0.56 - 1) * tanh(fShearStressGas_star);	% [-], (2.68)
                K_PhB_turb = 1 + (Pr_Film^0.08 - 1) * tanh(fShearStressGas_star);	% [-], (2.69)

                % Superpositioning lam. & turb. Nusselt number [-], (2.83)
                Nu_Film = sqrt((K_PhB_lam * Nu_Film_lam_plus)^2 + (K_PhB_turb * Nu_Film_turb_plus)^2);

            case false 	% No consideration of gas flow influence on heat transfer in condensate film
            	% Superpositioning lam. & turb. Nusselt numbers [-], (2.62)
                Nu_Film = sqrt(Nu_Film_lam^2 + Nu_Film_turb^2);

            otherwise
                warning('Boolean Value needed for GasFlow toggle.');
                warndlg('Boolean Value needed for GasFlow toggle','Warning');
                return
        end

        fKinViscosity_Film = tInput.fDynamicViscosityFilm / tInput.fDensityFilm;		% Kinematic viscosity of film [m^2/s]

        L = (fKinViscosity_Film^2 / 9.81)^(1/3);									% Characteristic Length of Film Flow [m], (2.52)

        fHeatTransferCoeffFilm = Nu_Film * tInput.fThermalConductivityFilm / L;	% Heat transfer coefficient at film surface [W/m^2 K], (2.51)

        % Thermal transmittance between gas and coolant [W/m^2 K], (2.50)
        fThermalTransmittanceFilm = ((1/fHeatTransferCoeffFilm) + ((tInput.fFinThickness/tInput.fThermalConductivitySolid)*tInput.iFinAir) + (1/fHeatTransferCoeffWallCoolant))^(-1); % 

        % Calculation of heat flux between film surface and coolant [W/m^2], (2.48)
        mfCoolantHeatFlux(iStep) = fThermalTransmittanceFilm * (mfTemperature(iStep) - tInput.fTemperatureCoolant);
    end
end

% Calculation of intersection point of both heat flux curves and 
% linear interpolation of actual heat flux, film surface temperature 
% and specific vapor mass flow rate

bRepeat = true;
mfDifference = mfGasHeatFlux - mfCoolantHeatFlux;	% Difference array of all heat flux values
while bRepeat
    
    if all(mfDifference == inf)
        % could not find an intersection, using smallest difference
        mfDifference = mfGasHeatFlux - mfCoolantHeatFlux;		% Difference array of all heat flux values
        iIntersection = find(abs(mfDifference) == min(abs(mfDifference)));	% Finding point closest to intersection
        
        if mfDifference(iIntersection) > 0
            iLowerPoint = iIntersection;
            iUpperPoint = iIntersection + 1;
        else
            iLowerPoint = iIntersection - 1;
            iUpperPoint = iIntersection;
        end

        % In case intersection point is far left or right: selection of point at bountInput.fCellAreary
        if iIntersection == 1
            iLowerPoint = 1;
            iUpperPoint = 2;
        elseif iIntersection == iSteps
            iLowerPoint = iSteps - 1;
            iUpperPoint = iSteps;
        end
        
        fTemperature = (mfTemperature(iUpperPoint) + mfTemperature(iLowerPoint)) / 2;
        fDeltaTemperature = mfTemperature(iUpperPoint) - mfTemperature(iLowerPoint);
        fCoolantSlope = (mfCoolantHeatFlux(iUpperPoint) - mfCoolantHeatFlux(iLowerPoint)) / fDeltaTemperature;
        fCoolantOffset =  mfCoolantHeatFlux(iLowerPoint) - fCoolantSlope * mfTemperature(iLowerPoint);
        break
    end
    iIntersection = find(mfDifference == min(mfDifference));

    if size(iIntersection,1) > 1
            iIntersection(2:end) = [];
    end
    
    iLowerPoint = iIntersection - 1;
    iUpperPoint = iIntersection + 1;
    if iIntersection == 1
        iLowerPoint = 1;
    elseif iIntersection == iSteps
        iUpperPoint = iSteps;
    end
    
    %%
    % Now we use linear interpolation to find the correct temperature, heat
    % flow and condensate flowrate!
    fDeltaTemperature = mfTemperature(iUpperPoint) - mfTemperature(iLowerPoint);

    % Equation for gas heat flux: fHeatFlux = mGasSlope * fTemperature + mGasOffset
    fGasSlope = (mfGasHeatFlux(iUpperPoint) - mfGasHeatFlux(iLowerPoint)) / fDeltaTemperature;
    fGasOffset =  mfGasHeatFlux(iLowerPoint) - fGasSlope * mfTemperature(iLowerPoint);

    % Equation for coolant heat flux: fHeatFlux = mCoolantSlope * fTemperature + mCoolantOffset
    fCoolantSlope = (mfCoolantHeatFlux(iUpperPoint) - mfCoolantHeatFlux(iLowerPoint)) / fDeltaTemperature;
    fCoolantOffset =  mfCoolantHeatFlux(iLowerPoint) - fCoolantSlope * mfTemperature(iLowerPoint);

    % intersection point between the two equations:
    fTemperature = (fGasOffset - fCoolantOffset) / (fCoolantSlope - fGasSlope); % Calculation of interpolated film surface temperature [K], (3.3)
    % it is possible (for a large step size) that the smalles temperature
    % difference does not occur close to the intersection point but
    % elsewhere. This calculation ensures that the current linear
    % interpolation actually contains the intersection point
    if fTemperature > mfTemperature(iUpperPoint) || fTemperature < mfTemperature(iLowerPoint)
        mfDifference(iIntersection) = inf;
    else
        bRepeat = false;
    end
end
% Note you can use this command to view the two linear equation that
% are solved if you set a breakpoint here:
% plot(mfTemperature, mfGasHeatFlux, mfTemperature, mfCoolantHeatFlux)


% Now we also use linear equations to calculate the other values at the
% corresponding temperature. Simply using averaged values is not the way to
% go, since the intersection point does not necessarily lie in the middle
% of the intervall!
fVaporSlope     = (mfSpecificMassFlowRate_Vapor(iUpperPoint) - mfSpecificMassFlowRate_Vapor(iLowerPoint)) / fDeltaTemperature;
fVaporOffset    =  mfSpecificMassFlowRate_Vapor(iLowerPoint) - fVaporSlope * mfTemperature(iLowerPoint);
    
fSpecificMassFlowRate_Vapor = fVaporSlope * fTemperature + fVaporOffset;

% Important, the heat fluxes include the latent heat from condensation,
% that heat does not result in a temperature change for the gas but only
% for the coolant! Therefore we have to calculate two different heat flows

% Calculation of coolant heat flux [W/m^2], (3.2)
fSpecificHeatFlowRateCoolant = fCoolantSlope * fTemperature + fCoolantOffset;

fCondensateMassFlow = fSpecificMassFlowRate_Vapor * tInput.fCellArea;		% Condensate mass flow rate [kg/s]
% We cannot vaporize more water than what has already condensed
if (tInput.fMassFlowFilm + fCondensateMassFlow) < 0
    fCondensateMassFlow = -tInput.fMassFlowFilm;
end
fHeatFlowCoolant = fSpecificHeatFlowRateCoolant * tInput.fCellArea;                                                     % Calculation of coolant heat flow [W], (2.102)
fHeatFlowGas     = fSpecificHeatFlowRateCoolant * tInput.fCellArea  - ( fCondensateMassFlow * fVaporisationEnthalpy);	% Calculation of gas heat flow [W], without latent heat of condensed vapor! (2.101)
if fHeatFlowGas < 0
    fHeatFlowGas = 0;
    fCondensateMassFlow = fHeatFlowCoolant / fVaporisationEnthalpy;
end

% Calculation of outlet temperatures:
tOutputs.fTemperatureGasOutlet     = tInput.fTemperatureGas - (fHeatFlowGas / (tInput.fMassFlowGas * tInput.fSpecificHeatCapacityGas));						% [K], (2.103)
tOutputs.fTemperatureCoolantOutlet = tInput.fTemperatureCoolant + (fHeatFlowCoolant / (tInput.fMassFlowCoolant * tInput.fSpecificHeatCapacityCoolant));	% [K], (2.104)

else
   fCondensateMassFlow = 0; 
   tOutputs.fTemperatureGasOutlet       = tInput.fTemperatureGas;
   tOutputs.fTemperatureCoolantOutlet   = tInput.fTemperatureCoolant;
   fHeatFlowCoolant = 0;
   fHeatFlowGas = 0;
end

% fPressureH2O = tInput.fMolarFractionVapor * tInput.fPressureGas;
% fVaporPressure =  oCHX.hVaporPressureInterpolation(fTemperature);
% fMaximumCondensateFlow = (fPressureH2O - fVaporPressure) * (tInput.fMassFlowGas / tInput.fDensityGas) / (tInput.fTemperatureGas * oCHX.oMT.Const.fUniversalGas / oCHX.oMT.afMolarMass(oCHX.oMT.tiN2I.H2O));
    
% Construction of output struct
tOutputs.fCondensateMassFlow        = fCondensateMassFlow;
tOutputs.fTotalHeatFlow             = fHeatFlowCoolant;
tOutputs.fGasHeatFlow               = fHeatFlowGas;
tOutputs.fHeatFlowCondensate        = fHeatFlowCoolant - fHeatFlowGas;

%additional Outputs
tOutputs.fMassFlowGas               = tInput.fMassFlowGas;
% tOutputs.fThermalResistance         = fHeatTransferCoeffWallCoolant+ fThermalTransmittanceFilm;




end
