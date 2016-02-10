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
            
        % toth isotherm parameter in [1/Pa] and its corresponding
        % temperature in [K], both values are reverse engineered
        fb0 = 300e-10;
        fT0 = 762.25;
        
        % Reaction enthalpy for CO2 in [J/mol], also reverse engineered.
        % Heat of adsorption at zero surface coverage in [J/mol].
        % AIAA-2011-5243 gives the isoteric heat of adsorption at 94000
        % J/mol
        fQ_ads = 77500;
        
        % Constants for H2O adsorption:
        
        % Freundlich isotherm parameter [unitless]
        % The value for this parameter was reverse engineered, the
        % value given in AIAA-2011-5243 is 0.00164.
        ralphaH2O = 0.00135;
        
        % Gas constant for water in [J/(kg*K)]
        %TODO use the value from the matter table here instead.
        fRw = 461.52;
        
        % Modification factor to set a more realistic value for the
        % equilibrium concentration of CO2. This value is reverse
        % engineered / fitted to test results.
        fEquilibriumModificationFactor = 0.7;
        
    end
        
    
    methods
        
        function k_l = get_KineticConst_k_l(varargin)
            % Select necessary input parameters
            K = varargin{2};
            csNames = varargin{10};
            
            % Initialize with the right size
            k_l = zeros(size(K)); 
            
            % Both of the following values are reverse enigneered / fitted
            % to test results. 
            % Mass transfer coefficient of H2O
            k_lH2O = 7.4e-03;          %[1/s]
            % Mass transfer coefficient of CO2
            %k_lCO2 = 3.80e-03;         %[1/s]
            k_lCO2 = 7e-03;            %[1/s]
            
            % Assign values
            k_l(strcmp('H2O',csNames), :) = k_lH2O;
            k_l(strcmp('CO2',csNames), :) = k_lCO2;
            
        end
        
        function [D_L] = get_AxialDispersion_D_L(varargin)
            % Dispersion coefficient, value taken from AIAA-2011-5243
            D_L = 2.90e-3;          % [m^2/s]
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
        
        % Linear(ized) isotherm constant
        function [K] = get_ThermodynConst_K(this, afC_in, fTemperature, fRhoSorbent, csNames, afMolMass)
            % This is equation 3.39 from RT-BA 2013/15, modified to
            % calculate K.
            K = this.calculate_q_equ(afC_in, fTemperature, fRhoSorbent, csNames, afMolMass) ./ afC_in; 
            K(isnan(K)|K<0) = 0;
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
                % Assume homogeneours temperature throughout bed Toth
                % parameter. This is equation (2) from Bollini, et al.
                % (2012): Dynamics of CO 2 Adsorption on Amine Adsorbents.
                % DOI: 10.1021/ie301790a.
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
            
            % Equilibrium loadings of substances
            mfQ_equ = mfQ_equ * fRhoSorbent;     % [mol/m^3]
        end
               
    end
end

