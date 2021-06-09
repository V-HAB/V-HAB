function tfMMECRates = CalculateMMECRates(this, fInternalTime, fPressureAtmosphere, fDensityAtmosphere, fRelativeHumidityAtmosphere, fHeatCapacityAtmosphere, fDensityH2O, fCO2)
    
    %% WARNING!! -- FILE CONTENT NOT IN SI UNITS!!! %%%%%%%%%%%%%%%%%%%%%%%
    
    
    % This function contains all necessary calculations for plant growth
    % according to the MMEC model. source for numbered equations: 
    % "Advances in Space Research 50 (2012) 941–951"
    % TODO: using PLANTPARAMETERS.xyz as placeholder until matter table
    % layout stuff has been decided
    
    % 8 target parameters to be calculated (in no particular order)
    % HWC ..... Hourly Water Consumption            [g m^-2 h^-1]
    % HTR ..... Hourly Transpiration Rate           [g m^-2 h^-1]
    % HOC ..... Hourly Oxygen Consumption           [g m^-2 h^-1]
    % HOP ..... Hourly Oxygen Prodcution            [g m^-2 h^-1]
    % HCO2C ... Hourly Carbon dioxide Consumption   [g m^-2 h^-1]
    % HCO2P ... Hourly Carbon dioxide Production    [g m^-2 h^-1]
    % HNC ..... Hourly Nutrient Consumption         [g m^-2 h^-1]
    % HWCGR ... Hourly Wet Crop Growth Rate         [g m^-2 h^-1]

    %% Calculate 6 Out Of 8 Target Parameters
    
    % determine if it is day or night for the current culture
    % TODO: improve later after system is running as it is one (the?)
    % reason photoperiod is linked to planting time and not a more general
    % setting
    if mod(fInternalTime, 86400) < (this.txInput.fPhotoperiod * 3600)
        bI = 1;
        
        if this.bLight == 0
            this.fLightTimeFlag = this.oTimer.fTime;
            this.bLight = 1;
        end 
    else
        bI = 0;
        
        if this.bLight == 1
            this.fLightTimeFlag = this.oTimer.fTime;
            this.bLight = 0;
        end
    end
    
    % calculate 24-hour carbon use efficiency (CUE_24)
    % CUE_24 constant for non-legumes, different for legumes
    if this.txPlantParameters.bLegume == 1
        % before time of onset of canopy senescence
        if fInternalTime <= (this.txPlantParameters.fT_Q * 86400)
            fCUE_24 = this.txPlantParameters.fCUE_Max;
            % after time of onset of canopy senescence but before time of
            % crop maturity
        elseif (this.txPlantParameters.fT_Q * 86400) < fInternalTime <= (this.txPlantParameters.fT_M * 86400)
            fCUE_24 = this.txPlantParameters.fCUE_Max - (this.txPlantParameters.fCUE_Max - this.txPlantParameters.fCUE_Min) * ((fInternalTime / 86400) - this.txPlantParameters.fT_Q) * (this.txPlantParameters.fT_M - this.txPlantParameters.fT_Q)^-1;
        end
    % CUE_24 constant for non-legumes
    else
        fCUE_24 = this.txPlantParameters.fCUE_Max;
    end
    
    % calculate effective photosynthetic photon flux density (PPFD_E) 
    % [µmol m^-2 s-^1]
%     fPPFD_E = this.txInput.fPPFD * (this.txInput.fPhotoperiod * this.txPlantParameters.fH_0^-1);
    
    % TODO: is it really necessary? day-night cycle already implemented.
    
    % calculate time of canopy closure (T_A)
    % calculate maximum canopy qunatum yield (CQY_Max)
    % [µmol_Carbon.Fixed * µmol_Absorbed.PPFD)^-1]
    % source: "Advances in Space Research 34 (2004) 1528–1538"
%     fT_A = ...
%         [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * ...                     % row vector for CO2
%         this.txPlantParameters.mfMatrix_T_A * ...           % coefficient matrix
%         [1/fPPFD_E; 1; fPPFD_E; fPPFD_E^2; fPPFD_E^3] * ...     % column vector for PPFD
%         86400;                                                  % T_A needs to be in seconds
    
    fT_A = ...
        [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * ...                     % row vector for CO2
        this.txPlantParameters.mfMatrix_T_A * ...           % coefficient matrix
        [1/this.txInput.fPPFD; 1; this.txInput.fPPFD; this.txInput.fPPFD^2; this.txInput.fPPFD^3] * ...             % column vector for PPFD
        86400;                                                  % T_A needs to be in seconds
    
    % calculate fraction of PPFD absorbed by canopy (A)
    % before time of canopy closure
    if fInternalTime < fT_A
        fA = this.txPlantParameters.fA_Max * (fInternalTime / fT_A)^this.txPlantParameters.fN;
    % after time of canopy closure
    elseif fInternalTime >= fT_A
        fA = this.txPlantParameters.fA_Max;
    end
    
    % calculate maximum canopy qunatum yield (CQY_Max)
    % [µmol_Carbon.Fixed * µmol_Absorbed.PPFD)^-1]
    % source: "Advances in Space Research 34 (2004) 1528–1538"
    fCQY_Max = ...
        [1/fCO2 1 fCO2 fCO2^2 fCO2^3] * ...                 % row vector for CO2
        this.txPlantParameters.mfMatrix_CQY * ...       % coefficient matrix
        [1/this.txInput.fPPFD; 1; this.txInput.fPPFD; this.txInput.fPPFD^2; this.txInput.fPPFD^3]; % column vector for PPFD
    
    % calculate canopy quantum yield (CQY) 
    % [µmol_Carbon.Fixed * µmol_Absorbed.PPFD)^-1] 
    % CQY description: canopy gross photosynthesis divided by absorbed PAR
    % before time of onset of canopy senescence
    if (fInternalTime <= (this.txPlantParameters.fT_Q * 86400))
        fCQY = fCQY_Max;
    % after time of onset of canopy senescence but before time of
     % crop maturity    
    elseif this.txPlantParameters.fT_Q < (fInternalTime / 86400) && (fInternalTime / 86400) <= (this.txPlantParameters.fT_M)
        fCQY = fCQY_Max - (fCQY_Max - this.txPlantParameters.fCQY_Min) * ((fInternalTime / 86400) - this.txPlantParameters.fT_Q) * (this.txPlantParameters.fT_M - this.txPlantParameters.fT_Q)^-1;
    else
        fCQY = 0;
    end
    
    if fCQY < this.txPlantParameters.fCQY_Min
        fCQY = this.txPlantParameters.fCQY_Min;
    elseif fCQY > fCQY_Max
        fCQY = fCQY_Max;
    end
    
    % hourly carbon gain [mol_Carbon m^-2 h^-1]
    % HCG = alpha * CUE_24 * A * CQY * PPFD * I (Eq. 2)
    fHCG = this.txPlantParameters.fAlpha * fCUE_24 * fA * fCQY * this.txInput.fPPFD * bI * 3600^-1; % [kg m^-2 s-^1]
    
    % hourly crop growth rate (dry) [g m^-2 h^-1]
    % HCGR = HCG * MW_C * BCF^-1 (Eq. 6)
    fHCGR = fHCG * this.oMT.afMolarMass(this.oMT.tiN2I.C) * this.txPlantParameters.fBCF ^-1;    % [kg m^-2 s-^1]
    
    % hourly wet crop growth rate [g m^-2 h^-1]
    % HWCGR = HCGR * (1 - WBF)^-1 (Eq. 7)
    % if T_E exceeded -> use total water fraction, if not only inedible
    % biomass is produced -> water fraction = 0.9 (BVAD 2015, table 4.98)
    if fInternalTime >= (this.txPlantParameters.fT_E * 86400)
        fHWCGR = fHCGR * (1 - this.txPlantParameters.fWBF_Edible) ^-1;   % [kg m^-2 s-^1]
    else
        fHWCGR = fHCGR * (1 - this.txPlantParameters.fWBF_Inedible)^-1;	% [kg m^-2 s-^1]
    end
    
    % hourly oxygen production [g m^-2 h^-1]
    % HOP = HCG * CUE_24 ^-1 * OPF * MW_O2 (Eq. 8)
    fHOP = fHCG * fCUE_24 ^-1 * this.txPlantParameters.fOPF * this.oMT.afMolarMass(this.oMT.tiN2I.O2);  % [kg m^-2 s-^1]
    
    % hourly oxygen consumption [g m^-2 h^-1]
    % HOC = HCG * I^-1 * (1 - CUE_24) * CUE_24^-1 * OPF * MW_O2 * H * 24^-1
    % (Eq. 9)
    fHOC = (this.txPlantParameters.fAlpha * fCUE_24 * fA * fCQY * this.txInput.fPPFD * 3600^-1) * (1 - fCUE_24) * fCUE_24^-1 * this.txPlantParameters.fOPF * this.oMT.afMolarMass(this.oMT.tiN2I.O2) * this.txInput.fPhotoperiod * 24^-1;   % [kg m^-2 s-^1]

    % hourly CO2 consumption [g m^-2 h^-1]
    % HCO2C = HOP * MW_CO2 * MW_O2^-1 (Eq. 14)
    fHCO2C = fHOP * this.oMT.afMolarMass(this.oMT.tiN2I.CO2) * this.oMT.afMolarMass(this.oMT.tiN2I.O2) ^-1;     % [kg m^-2 s-^1]
    
    % hourly CO2 production [g m^-2 h^-1]
    % HCO2P = HOC * MW_CO2 * MW_O2^-1 (Eq. 15)
    fHCO2P = fHOC * this.oMT.afMolarMass(this.oMT.tiN2I.CO2) * this.oMT.afMolarMass(this.oMT.tiN2I.O2) ^-1;     % [kg m^-2 s-^1]
    
    % hourly plant macronutirent uptake [g m^-2 h^-1]
    % HNC = HCGR * DRY_fr * NC_fr (Eq. 15.5, has no number, but is listed 
    % between Eq. 15 and Eq. 16))
    fHNC = fHCGR * this.txPlantParameters.fDRY_Fraction * this.txPlantParameters.fNC_Fraction;  % [kg m^-2 s-^1]
    
    %% Calculate Plant Transpiration
    
    % Transpiration Model is based on the FAO Model 
    % (Penman-Montheith Equation)
    
    % Vapor Pressure for Light and Dark Phases (kept both, probably just
    % need the one if referencing from atmsophere. check again later
    fVaporPressureLight = 0.6108 * exp(17.27 * this.txPlantParameters.fTemperatureLight / (this.txPlantParameters.fTemperatureLight + 237.3)); 
    fVaporPressureDark = 0.6108 * exp(17.27 * this.txPlantParameters.fTemperatureDark / (this.txPlantParameters.fTemperatureDark + 237.3));

    fE_S = (fVaporPressureLight + fVaporPressureDark) / 2 * 1000;

    fE_A = fE_S * fRelativeHumidityAtmosphere; %%% relative humidity consant factor in closed environemnts ! simplified equation
    
    % P_net: net canopy photosynthesis [µmol_Carbon m^2 s]
    fP_gross = fA * fCQY * this.txInput.fPPFD;                  
        
    fP_Net	=   ((24 - this.txInput.fPhotoperiod)/(24) + this.txInput.fPhotoperiod * fCUE_24/24 ) * fP_gross;

    % Rate of change of saturation specific humidity with air temperature in [Pa K^-1]
    fD = 1000 * 4098 * 0.6108 * exp(17.27 * this.txPlantParameters.fTemperatureLight / ( this.txPlantParameters.fTemperatureLight + 237.3 )) / (( this.txPlantParameters.fTemperatureLight + 237)^2); 

    % Volumetric latent heat of vaporization in [MJ kg^-1]
    fL_V = 2.45 * 10^6;

    % Psychometric constant in [Pa K^-1]
    fGamma = 0.665 * 10^-3 * fPressureAtmosphere;

    % Avarege wavelenght in [m]
    delta = 535 * 10^-9;
    h_0 = this.oMT.Const.fPlanck * this.oMT.Const.fLightSpeed / delta;

    % Energy per mol PAR in [MJmolSolar^-1]
    fE_M = h_0 * this.oMT.Const.fAvogadro * 10^-6;

    % Netsolar irradiance in [W m^-2]
%     fPARSOL = 0.45
%     fR_Net = (this.txInput.fPPFD / fPARSOL) * fE_M;
    fR_Net = (this.txInput.fPPFD / 0.45) * fE_M;

    % stomatal conductance in [m^2 s mol^-1]
    fG_S = 8.2 * fRelativeHumidityAtmosphere * (fP_Net / fCO2);

    
    %% LAI calculation from master thesis of Aleksandra Nikic (RT-MA 2017/28)
    
    fLightAngle = 0;
    fLeafAngleDistributionPattern = this.txPlantParameters.fLAPD;
    
    % Equation 7-12 from Aleksandra Nikic Master Thesis:
    fLightExtinctionFactor = ((fLeafAngleDistributionPattern^2 + tan(fLightAngle)^2)^0.5) ./ (fLeafAngleDistributionPattern + 1.774*(fLeafAngleDistributionPattern+1.182)^-0.733);
    
    % Equation 7-7 from Aleksandra Nikic Master Thesis:
    fLAI = log(1 - fA) / (-fLightExtinctionFactor);
    
    % Leaf Area Active Index [-]
    fLAI_Active = 0.5 * fLAI;
    %%
    
    % bulk stomatal resistance[s m^-1]
    fR_1 = 1 / (0.025 * fG_S);

    % bulk surface resistance [s m^-1]
    fR_S = fR_1 / fLAI_Active; 

    % soil heat flux in [W m^-2]
    fSoilHeatFlux = 0;
    
    % wind speed in [m s^-1]
    fU = 1.5; 

    % aerodynamic resistance [m s^-1]
    fR_A =  208 / fU;
    
    % Penman-Monteith equation ET_0 in [liter m^-2 s^-1]
    % Atmsophere density from referneced atmosphere
    a = fD * (fR_Net - fSoilHeatFlux) + fDensityAtmosphere * fHeatCapacityAtmosphere * (fE_S - fE_A) / fR_A;
    b = (fD + fGamma * (1 + fR_S / fR_A)) * fL_V;

    fET_0 = a/b; 
    
    % Crop Coefficient development during plant growth
    if fInternalTime < fT_A  
        fKC = this.txPlantParameters.fKC_Mid * (fInternalTime / fT_A) ^ this.txPlantParameters.fN;
    elseif (fT_A <= fInternalTime) && (fInternalTime <= (this.txPlantParameters.fT_Q * 86400))   
        fKC = this.txPlantParameters.fKC_Mid;
    else   
        fKC = this.txPlantParameters.fKC_Mid + (((fInternalTime / 86400) - this.txPlantParameters.fT_Q) / ((this.txPlantParameters.fT_M) - (this.txPlantParameters.fT_Q))) * (this.txPlantParameters.fKC_Late - this.txPlantParameters.fKC_Mid);
        
        if fKC < 0.01 * this.txPlantParameters.fKC_Mid 
            fKC = 0.01 * this.txPlantParameters.fKC_Mid;
        end
    end
    
    % final Water volume evapotranspiration ET_c in [liter m^-2 s^-1]
    fET_C = fKC * fET_0;
    
    % hourly transpiration rate [g m^-2 h^-1]
    % TODO: model from saad, do last
    fHTR = fET_C * fDensityH2O * 1000^-1 * (this.txInput.fPhotoperiod /24);  % [kg m^-2 s^-1]
    
    %% Calculate Water Consumption
    
    % HWC is calculated last as it is used to close the mass balance
    
    % hourly water consumption [g m^-2 h^-1]
    % HWC = HTR + HOP + HCO2P + HWCGR - HOC - HCO2C - HNC (Eq. 16)
%     fHWC = fHTR + fHOP + fHCO2P + fHWCGR - fHOC - fHCO2C - fHNC;    % [kg m^-2 s^-1]


% Since fHWCGR is assumed to be wrong we add the later calculated wet
% edible and inedible mass in order to close the mass balance!
    fHWC = fHTR + fHOP + fHCO2P - fHOC - fHCO2C - fHNC;    % [kg m^-2 s^-1]
    
    %% Write Return Parameter
    
    % attach calculated plant consumsption and production rates to culture 
    % object, further handling on the upper level. also convert to SI units
    
    % It was noticed that the MEC model in the beginning has slight errors
    % because more water is consumed than transpired while no crop growth
    % rate occurs
    if fHCGR == 0
        tfMMECRates.fWC    = fHTR;
        tfMMECRates.fTR    = fHTR;
        tfMMECRates.fOC    = 0;
        tfMMECRates.fOP    = 0;
        tfMMECRates.fCO2C  = 0;
        tfMMECRates.fCO2P  = 0;
        tfMMECRates.fNC    = 0;
        tfMMECRates.fCGR   = 0;
        tfMMECRates.fWCGR  = 0;
    else
        tfMMECRates.fWC    = fHWC;
        tfMMECRates.fTR    = fHTR;
        tfMMECRates.fOC    = fHOC;
        tfMMECRates.fOP    = fHOP;
        tfMMECRates.fCO2C  = fHCO2C;
        tfMMECRates.fCO2P  = fHCO2P;
        tfMMECRates.fNC    = fHNC;

        % growth rate on dry basis because edible and inedible biomass parts
        % have different water contents
        tfMMECRates.fCGR   = fHCGR;
        tfMMECRates.fWCGR  = fHWCGR;
    end
    
	% For debugging, if the mass balance is no longer correct
%     fBalance = fHTR + fHOP + fHCO2P + fHWCGR - fHOC - fHCO2C - fHNC - fHWC;
%     if abs(fBalance) > 1e-10
%         keyboard()
%     end
end

