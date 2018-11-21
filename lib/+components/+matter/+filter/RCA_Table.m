% pressure in [Pa], loading Q in [mol/kg], Temperature in [K]
classdef RCA_Table < handle
    
    properties  
        
        % universal gas constant [J/(mol*K)]
        fRe = 8.3145;
        
        % Constants for CO2 adsorption:
        
        % ft describes the heterogeneity of the adsorbent surface
        % assumed to be temperature independent
        % ft is unitless
        % The source of this value is not known. It is possible, that it is
        % reverse engineered. 
        ft = 0.22;
        
        % Set saturation capacity of the bed in [mol/kg]. In AIAA-2011-5243
        % this value is given at 1.78. 
        fns = 1.1;
        %fns = 1.78;
        
        % toth isotherm parameter in [1/Pa] and its corresponding
        % temperature in [K], both values are reverse engineered
        fb0 = 300e-10;
        fT0 = 762.25;
        
        % Reaction enthalpy for CO2 in [J/mol], also reverse engineered.
        % Heat of adsorption at zero surface coverage in [J/mol].
        % AIAA-2011-5243 gives the isoteric heat of adsorption at 94000
        % J/mol
        %fQ_ads = 74500;
        fQ_ads = 72000;
        
        % Constants for H2O adsorption:
        
        % Freundlich isotherm parameter [unitless]
        % The value for this parameter was reverse engineered, the
        % value given in AIAA-2011-5243 is 0.0164.
        ralphaH2O = 0.00105;
        %ralphaH2O = 0.0164;
        
        % Gas constant for water in [J/(kg*K)]
        %TODO use the value from the matter table here instead.
        fRw = 461.52;
        
        % Modification factor to set a more realistic value for the
        % equilibrium concentration of CO2. This value is reverse
        % engineered / fitted to test results.
        fEquilibriumModificationFactor = 1;
        
        fR_pellet = 3.14*10^-3;                             % pellet radius [m]
        fPelletPorosity = 0.4;                              % pellet porosity [-]
        
        afD_collision = [2.8, 3.7979, 3.7412, 3.4822];      % collision diameter of [H2O,CO2,N2,O2] in [Angstrom] (molecular diffusion)     
        afLJPotential = [250,223.675,88.9525,103.6955];     % Lennard-Jones potential minima of [H2O,CO2,N2,O2] in [K] (molecular diffusion)
        fR_macropore = 3.2*10^-7;                           % average macropore radius [m]
        fMacroporeTurt_tau = 5;                             % macropore tortuosity [-]
        
        % For MODULATION and VALIDATION:
        % Enter manual values for the constants or leave nan to
        % calculate the values according to theoretical assumptions
        % BUT: Take care of a correct assignment (size, different substances, ... )        
        D_L = nan;         % packed bed axial dispersion Fick's constant [m^2/s]
        k_f = nan;         % fluid film diffusion rate constant [m/s]
        D_p = nan;         % macropore diffusion Fick's constant [m^2/s]
        D_c = nan;         % micropore diffusion Fick's constant [m^2/s]
        k_l = nan;         % LDF model kinetic lumped constant in order (H2O, CO2, N2, O2) [1/s]
        K   = nan;         % linear(ized) isotherm constant [-]
        
        csNames;
        afMolMass;
        
        oParent;
        afConcentrationChangeRate;
        afPreviousConcentration;
        afAverageThermoDymamicConstant;
    end
        
    
    methods
        
        function this = RCA_Table(oParent)
            % Don't have to do anything here, just making sure that all the
            % properties are actually set as they should. 
            
            this.oParent = oParent;
            this.afConcentrationChangeRate = zeros(1, this.oParent.iNumGridPoints - 1);
            this.afPreviousConcentration   = zeros(1, this.oParent.iNumGridPoints - 1);
        end
        
         % Linear(ized) isotherm constant
        function [K] = get_ThermodynConst_K(this, afC_in, fTemperature, fRhoSorbent, csNames, afMolMass)
            if isnan(this.K) == 0
                K = zeros(size(afC_in));
                for iVari = 1:length (this.K)
                K(iVari, :) = this.K(iVari);
                end
                return;
            end
            
            % This is equation 3.39 from RT-BA 2013/15, modified to
            % calculate K.
            K = this.calculate_q_equ(afC_in, fTemperature, fRhoSorbent, csNames, afMolMass) ./ afC_in; 
            K(isnan(K)|K<0) = 0;
            this.afAverageThermoDymamicConstant = K(:,1);
        end
        
        % Calculating the equilibrium values for the loading along the bed
        function [mfQ_equ] = calculate_q_equ(this, mfConcentration, fTemperature, fRhoSorbent, csNames, afMolMass)
            
            % partial pressures of substances [Pa]
            mfPP_i = mfConcentration * this.fRe * fTemperature;
            
            % Initializing the result array
            mfQ_equ = zeros(size(mfPP_i));
            
            % H2O adsorption
            fQ_equ_H2O = 0;
            if find(strcmp('H2O', csNames) == 1)
                % Calculate relative humitidy
                % Saturated vapor pressure in [Pa]
                %TODO use the matter table function for this
                fEw = 610.94 * exp((17.625 * (fTemperature - 273.15)) / (243.04 + fTemperature - 273.15));
                
                % Maximal humidity
                delta_sat = fEw / (this.fRw * fTemperature);

                % RH of the gas flow, factor 100 is necessary because RH
                % needs to be in %
                fRH = mfConcentration(strcmp('H2O',csNames),:) * afMolMass(strcmp('H2O',csNames)) / delta_sat * 100;
                
                % Calculate equilibrium value for H2O
                fQ_equ_H2O = this.ralphaH2O * fRH.^2;
            end
            
            % CO2 adsorption
            fQ_equ_CO2 = 0;
            
            if find(strcmp('CO2', csNames) == 1)
                % Assume homogeneous temperature throughout bed.
                % Calculating Toth parameter. This is equation (2) from
                % Bollini, et al. (2012): Dynamics of CO 2 Adsorption on
                % Amine Adsorbents. DOI: 10.1021/ie301790a.
                fTothParameter_b = this.fb0 * exp((this.fQ_ads / (this.fRe * this.fT0)) * (this.fT0 / fTemperature - 1));
                % Calculate equilibrium value for CO2
                % This is equation (1) from Bollini, et al.
                fQ_equ_CO2 = (fTothParameter_b * mfPP_i(strcmp('CO2',csNames),:) * this.fns) ./ ((1 + (fTothParameter_b * mfPP_i(strcmp('CO2',csNames),:)).^this.ft)).^(1/this.ft);
                
                % The calculated value is an ideal value. It needs to be
                % modified to match the actual equilibrium.
                fQ_equ_CO2 = fQ_equ_CO2 * this.fEquilibriumModificationFactor;
                
            end
            
            % Assign equilibrium values
            mfQ_equ(strcmp('CO2',csNames),:) = fQ_equ_CO2;  % [mol/kg]
            mfQ_equ(strcmp('H2O',csNames),:) = fQ_equ_H2O;  % [mol/kg]
            
            % Convert to mol/m^3
            mfQ_equ = mfQ_equ * fRhoSorbent;     % [mol/m^3]
            
            this.afConcentrationChangeRate = ( mfQ_equ(strcmp('CO2',csNames),:) - this.afPreviousConcentration ) / this.oParent.fTimeStep;
            this.afPreviousConcentration   = mfQ_equ(strcmp('CO2',csNames),:);
        end
        
        % Lumped LDF coefficient according to Glueckauf / Ruthven
        function [k_l] = get_KineticConst_k_l(this, mfThermodynamicConstants, fTemperature, fPressure, fDensityFlow, afC_in, fRhoSorbent, fVolumetricFlowRate, rVoidFraction, csNames, afMolMass)
            
            this.afMolMass = afMolMass;
            this.csNames   = csNames;
            
            % Check for manually set values
            if ~isnan(this.k_l)
                % Initialize
                k_l = zeros(size(mfThermodynamicConstants));
                % Assign correct values
                % Extend if other substances shall be adsorbed 
                k_l(strcmp('H2O',csNames), :) = this.k_l(1);
                k_l(strcmp('CO2',csNames), :) = this.k_l(2);
                k_l(strcmp('N2',csNames), :)  = this.k_l(3);
                k_l(strcmp('O2',csNames), :)  = this.k_l(4);
                return;
            end
            
            %TODO In some better version of this, replace the viscosity
            %calculation with the matter table method using the inflow as
            %argument.
            % Average fluid dynamic viscosity [Pa s]
            fAverageDynamicViscosity = this.calculateDynamicViscosity(fTemperature);
            
            % Collision integrals of species i vs. species j [-]
            afCollisionIntegrals = this.calculateCollisionIntegral(fTemperature);
            
            % Average molecular diffusion Fick's law coefficient of fluid [m^2/s]
            afAverageMolecularDiffusion = this.calculateMolecularDiffusion(fTemperature, fPressure, afC_in, afCollisionIntegrals);
            
            % Average Knudsen diffusion Fick's law coefficient [m^2/s]
            afAverageKnudsenDiffusion = this.calculateKnudsenDiffusion(fTemperature,afC_in);                       
            
            % Average Surface diffusion Fick's law coefficient [m^2/s]
            afAverageSurfaceDiffusion = this.calculateSurfaceDiffusion(fTemperature);
            
            % linearized isotherm constant of all species [-]
            afAverageIsothermConstant = this.get_ThermodynConst_K(afC_in', fTemperature, fRhoSorbent, csNames, afMolMass);
            %afAverageIsothermConstant = this.afAverageThermoDymamicConstant;
            
            % average fluid film diffusion LDF coefficient [1/s]
            afAverageFluidFilmDiffusion = this.calculateFluidFilmDiffusion(fVolumetricFlowRate, fDensityFlow, rVoidFraction, afAverageMolecularDiffusion, fAverageDynamicViscosity);
            
            % average macropore diffusion Fick's law coefficient [m^2/s]
            afMacroporeDiffusionCoefficients = this.calculateMacroporeDiffusion(afAverageIsothermConstant,afAverageMolecularDiffusion,afAverageKnudsenDiffusion,afAverageSurfaceDiffusion,afC_in');
            
            % average micropore diffusion Fick's law coefficient [m^2/s]
            afMicroporeDiffusionCoefficients = this.calculateMicroporeDiffusion(fTemperature);
            
            % microcrystal radius
            %TODO Find out where this number comes from
            R_c = 30 * 1e-6;     % [m]
            
            % Calculating the constants using equation 2.42 from 
            % RT-BA 2013/15
            k_l = 1 ./ ((mfThermodynamicConstants * this.fR_pellet / 3 / afAverageFluidFilmDiffusion) + (mfThermodynamicConstants * this.fR_pellet^2 / 13 / this.fPelletPorosity ./ afMacroporeDiffusionCoefficients) + (R_c^2 / 15 / afMicroporeDiffusionCoefficients));
            
            % Removing illegal values by setting them to zero.
            k_l(isnan(k_l)|k_l<0) = 0;            
        end
        
        % Dynamic viscosity according to Sutherland
        function fmu = calculateDynamicViscosity(~,fTemperature)            
            % Sutherland constant for nitrogen [K]
            fT_0          = 300.55;
            % Sutherland constant for nitrogen [K]
            fSutherlConst = 111;
            % Sutherland constant for nitrogen [Pa*s]
            fmu_0         = 17.81 * 1e-6;
            % Calculating the dynamic viscosity
            % Equation 2.29 in RT-BA 2013/15
            fmu           = fmu_0 * (fT_0 + fSutherlConst) / (fTemperature + fSutherlConst) * (fTemperature / fT_0)^1.5;            
        end
        
        % Collision integral according to Poling (helper function for axial dispersion coefficient)
        function [omega_ij] = calculateCollisionIntegral(this, fTemperature)
            % Assign correct Lenard Jones potentials
            e_i = zeros(1,length(this.csNames));
            if find(strcmp('H2O', this.csNames) == 1)
                e_i(strcmp('H2O', this.csNames)) = this.afLJPotential(1);
            end
            if find(strcmp('CO2', this.csNames) == 1)
                e_i(strcmp('CO2', this.csNames)) = this.afLJPotential(2);
            end
            if find(strcmp('N2', this.csNames) == 1)
                e_i(strcmp('N2', this.csNames)) = this.afLJPotential(3);
            end
            if find(strcmp('O2', this.csNames) == 1)
                e_i(strcmp('O2', this.csNames)) = this.afLJPotential(4);
            end

            % Lennard-Jones potential coefficient of species i in N2 [-]
            e_ij = fTemperature./sqrt(e_i' * e_i);
            
            % collision integrals of [H2O,CO2,N2,O2] vs N2 [-]
            % Equation 2.22 in RT-BA 2013/15
            omega_ij = 0.42541 + (0.82133 - 6.8314 * 10e-2 ./ e_ij) ./ e_ij + 0.2668 * exp(-0.012733 * e_ij);            
        end
        
        % Molceular diffusion Fick's coefficient according to Ruthven
        function [D_m] = calculateMolecularDiffusion(this, fTemperature, fPressure, afC_in, omega_ij)
            v_i = zeros(1,length(this.csNames));
            if find(strcmp('H2O', this.csNames) == 1)
                v_i(strcmp('H2O', this.csNames)) = this.afD_collision(1);
            end
            if find(strcmp('CO2', this.csNames) == 1)
                v_i(strcmp('CO2', this.csNames)) = this.afD_collision(2);
            end
            if find(strcmp('N2', this.csNames) == 1)
                v_i(strcmp('N2', this.csNames)) = this.afD_collision(3);
            end
            if find(strcmp('O2', this.csNames) == 1)
                v_i(strcmp('O2', this.csNames)) = this.afD_collision(4);
            end
            
            % Average collision diameter of species i in species j [Angstrom]
            v_ij = 0.5 * (repmat(v_i, length(v_i), 1) + repmat(v_i, length(v_i), 1)');                      
            
            % Helper variable
            M_ij = repmat(1 ./ this.afMolMass, length(this.afMolMass), 1)+repmat(1 ./ this.afMolMass, length(this.afMolMass), 1)';          
            
            % Molecular diffusivity of component i in component j (Chapman-Enskog-Theory)[m^2/s]
            % Equation 2.20 from RT-BA 2013/15
            D_ij = 1e-4 * 98.665 * 1.86 * (M_ij) .^ 0.5 * fTemperature ^ 1.5 ./ (fPressure * v_ij .^ 2 .* omega_ij);
            
            % Mole fraction of component i in fluid [-]
            y_i = afC_in / sum(afC_in);
            
            % Only one component (other formula yields nans)
            % Equation 2.19 from RT-BA 2013/15
            if(sum(y_i==0) == length(this.csNames)-1)
                % Molecular diffusivity coefficient of species i in mixture [m^2/s]
                D_im = y_i .* diag(D_ij)';
            else
                D_im = (1 - y_i) ./ (sum(repmat(y_i, length(this.csNames), 1) ./ D_ij, 2)' - (y_i ./ diag(D_ij)'));
            end
            
            % Average molecular diffusivity coefficient of fluid [m^2/s]
            % Equation 2.18 from RT-BA 2013/15
            D_m = sum(y_i .* D_im);
        end
        
        % Knudsen diffusion Fick's law coefficient according to Ruthven
        function [D_k] = calculateKnudsenDiffusion(this, fTemperature, afC_in)
            
            % Equation 2.34 from RT-BA 2013/15
            
            % Knudsen diffusion Fick's law coefficient in [cm^2/s]
            D_k = 970000 * this.fR_macropore * (repmat(fTemperature, size(afC_in, 2), 1) .* repmat(this.afMolMass' .^ -1, 1, size(fTemperature, 2))) .^ 0.5;
            % Convert to [m^2/s]
            D_k = sum(D_k .* repmat(afC_in', 1, size(fTemperature, 2)), 1)/sum(afC_in) * 1e-4;
        end
        
        % Macroporous surface diffusion Fick's coefficient according to Ruthven (Eyring
        % equation)
        function [D_s] = calculateSurfaceDiffusion(this,fTemperature)
            
            % The following two constants are taken from P. Schneider, 
            % J. M. Smith: ?Chromatographic Study of Surface Diffusion?, 
            % AIChE Journal, Volume 14, Issue 6, pp. 886?895, November 1968
            % DOI: 10.1002/aic.690140613 
            % RT-BA 2013/15 says, that both values were fitted from this
            % paper, but it is not specified how. The paper is on the
            % adsorption ethane, propane, and n-butane on silica gel. So
            % this might not be the correct values for the amine in the
            % RCA.
            
            % Eyring equation preexponential factor [m^2/s]
            fD_s_inf = 6.95 * 1e-7;
            % macropore diffusion Eyring equation activation Energy [J]
            fE_s_act = 18241;
            
            % Equation 2.36 from RT-BA 2013/15
            D_s = fD_s_inf * exp(-fE_s_act / this.fRe ./ fTemperature);
        end
        
        % Axial dispersion Fick's coefficient according to Edwards & Richardson
        function [D_L] = get_AxialDispersion_D_L(this, fFluidVelocity, fTemperature, fPressure, afC_in, csNames, afMolMass)     
            if ~isnan(this.D_L)
                D_L = this.D_L; return; 
            end                
            this.csNames = csNames;
            this.afMolMass = afMolMass; 
            
            omega_ij = this.calculateCollisionIntegral(fTemperature);
            
            D_m = this.calculateMolecularDiffusion(fTemperature, fPressure, afC_in,omega_ij);            
            
            % axial diffusivity coefficient for [H2O,CO2,N2,O2] [m^2/s]
            D_L = 0.73 * D_m + this.fR_pellet .* fFluidVelocity ./ (1 + 4.85 * D_m ./ fFluidVelocity ./ this.fR_pellet);
        end
        
        % Pressure drop across filter bed
        function [fDeltaP] = calculate_dp(~,fLength,fFluidVelocity,e_b,fTemperature,~)
            
            % Dynamic viscosity according to Sutherland:
            %TODO calculate dynamic viscosity using matter table
            
            % Sutherland constant for standard air [K]
            fConst_T_0     = 291.15;
            % Sutherland constant for standard air [K]
            fSutherlConst  = 120;
            % Sutherland constant for standard air [Pa*s]
            fConst_mu_0    = 18.27*10^-6;
            
            % Calculating the dynamic viscosity
            fViscosity_dyn = fConst_mu_0 * (fConst_T_0 + fSutherlConst) ./ (fTemperature + fSutherlConst) .* (fTemperature / fConst_T_0) .^ 1.5;
            
            % Mean particle diameter of sorbent beds in [m]
            fD_p = 2.04e-3;
            
            % Pressure drop along the filter bed [Pa]
            % This is equation 3 from table 2 in AIAA-2011-5243. It
            % represents the Blake-Kozeny pressure flow relationship
            fDeltaP = (fLength * 150 * fViscosity_dyn * fFluidVelocity  * (1 - e_b)^2) / ((e_b^3) * fD_p^2);
            
        end
        
        % Film diffusion LDF constant according to Wakao & Funazkri
        function [k_f] = calculateFluidFilmDiffusion(this, fVolumetricFlowRate, fDensityFlow, e_b, D_m, mu)
            if isnan(this.k_f) == 0
                k_f = this.k_f; return;
            end
            k_f = D_m ./ this.fR_pellet + 0.55 * (mu ./ fDensityFlow).^(-4/15) .* D_m.^(2/3) .* this.fR_pellet.^(-0.4) .* (2 * fVolumetricFlowRate .* e_b).^0.6;
        end
        
        % Macroporous diffusion Fick's coefficient according to Ruthven
        function [D_p] = calculateMacroporeDiffusion(this, K_avg, D_m, D_k, D_s, afC_in)
            if isnan(this.D_p) == 0
                D_p = this.D_p; return;
            end
            %molecular + knudsen + surface diffusion
            % Equation 2.38 from RT-BA 2013/15
            D_p = 1 ./ (1 ./ D_m + 1 ./ (D_k + (1 - this.fPelletPorosity) / this.fPelletPorosity * K_avg * D_s)) * 1 ./ this.fMacroporeTurt_tau;
            D_p = sum(afC_in .* D_p) / sum(afC_in);
        end
        
        % Microporous diffusion Fick's coefficient according to Ruthven (Eyring
        % equation)
        function [D_c] = calculateMicroporeDiffusion(this,fTemperature)
            if isnan(this.D_c) == 0
                D_c = this.D_c; return;
            end
            
            % The following constants are taken from H. Yucel, D. M.
            % Ruthven: ?Diffusion of CO2 in 4A and 5A Zeolite Crystals?,
            % Journal of Colloid and Interface Science, Volume 74, Issue 1,
            % March 1980, pp. 186-195, DOI: 10.1016/0021- 9797(80)90182-4
            % The values might be vastly different for the amine used in
            % the RCA.
            
            % micropore diffusion Eyring equation preexponential factor
            D_c_inf = 5.9 * 1e-11;           % [m^2/s]
            % micropore diffusion Eyring equation activation Energy
            E_c_act = 12552;                % [J]
            
            % Equation 2.40 from RT-BA 2013/15
            D_c = D_c_inf * exp(-1 * E_c_act / this.fRe ./ fTemperature);
        end
    end
end

