% pressure in [Pa], loading Q in [mol/kg], Temperature in [K]
classdef RCA_Table < handle
    
    properties  
        
        % universal gas constant [J/(mol*K)]
        fRe = 8.3145;
        
        % constants for CO2 adsorption
        % ft describes the heterogeneity of the adsorbent surface
        % assumed to be temperature independent
        ft = 0.22;                 %[]
        % set saturation capacity of the bed (Paper: AIAA-2011-5243) 
        fns = 1.10;                 %[mol/kg]
        % toth isotherm parameter and its corresponding temperature, which was experimentally determined        
        fb0 = 300e-10;             %[1/Pa]
        fT0 = 762.25;              %[K]
        % Reaction enthalpy for CO2
        fQ_ads = 75000;              %[J/mol]
        
        % constants for H2O adsorption
        % Freundlich isotherm parameter
        ralphaH2O = 0.00135;          %[]
        % gas constant for water
        fRw = 461.52;                %[J/(kg*K)
    end
        
    
    methods
        
        function k_l = get_KineticConst_k_l(varargin)
            % Select necessary input parameters
            K = varargin{2};
            csNames = varargin{10};
            
            % Initialize with the right size
            k_l = zeros(size(K)); 
            
            % Mass transfer coefficient of H2O
            k_lH2O = 7.4e-03;          %[1/s]
            % Mass transfer coefficient of CO2
            k_lCO2 = 3.80e-03;         %[1/s]
            
            % Assigne values
            k_l(strcmp('H2O',csNames), :) = k_lH2O;
            k_l(strcmp('CO2',csNames), :) = k_lCO2;
            
        end
        
        function [D_L] = get_AxialDispersion_D_L(varargin)
            % Dispersion coefficient
            D_L = 2.90e-3;          % [m^2/s]
        end
        
        
        % Pressure drop across filter bed
        function [fDeltaP] = calculate_dp(~,fLength,fFluidVelocity,e_b,fTemperature,~)
            
            % Dynamic viscosity according to Sutherland
            fConst_T_0 = 291.15;                           % Sutherland constant for standard air [K]
            fSutherlConst = 120;                     % Sutherland constant for standard air [K]
            fConst_mu_0 = 18.27*10^-6;                % Sutherland constant for standard air [Pa*s]
            fViscosity_dyn = fConst_mu_0*(fConst_T_0 + fSutherlConst)./(fTemperature + fSutherlConst).*(fTemperature/fConst_T_0).^1.5;
            
            % Mean particle diameter of sorbent beds
            fD_p = 2.04e-3;          % [m]
            % Pressure drop along the filter bed [Pa]
            fDeltaP = (fLength*150*fViscosity_dyn*fFluidVelocity*(1-e_b)^2)/((e_b^3)*fD_p^2);
            
        end
        
        % Linear(ized) isotherm constant
        function [K] = get_ThermodynConst_K(this,afC_in, fTemperature, fRhoSorbent, csNames, afMolMass)
            K = this.calculate_q_equ(afC_in, fTemperature, fRhoSorbent, csNames, afMolMass) ./ afC_in; 
            K(isnan(K)|K<0) = 0;
        end
        
        % Calculating the equilibrium values for the loading along the bed
        function [mfQ_equ] = calculate_q_equ(this, mfConcentration, fTemperature, fRhoSorbent, csNames, afMolMass)
            
            mfPP_i = mfConcentration * this.fRe * fTemperature;   % partial pressures of substances [Pa]
            % Initiazlize
            mfQ_equ = zeros(size(mfPP_i));
            
            % H2O adsorption
            fQ_equ_H2O = 0;
            if find(strcmp('H2O', csNames) == 1)
                % Calculate relative humitidy
                % Saturated vapor pressure
                fEw = 611*exp((17.62*(fTemperature-273.15))/(234.04+fTemperature-273.15));  %[Pa]
                % Maximal humidity
                delta_sat = fEw / (this.fRw*fTemperature);
                % RH of the gas flow
                fRH = mfConcentration(strcmp('H2O',csNames),:) * afMolMass(strcmp('H2O',csNames)) / (10*delta_sat);
                % Calculate equilibrium value for H2O
                fQ_equ_H2O = this.ralphaH2O * fRH.^2;
            end
            
            % CO2 adsorption
            fQ_equ_CO2 = 0;
            if find(strcmp('CO2', csNames) == 1)
                % Assume homogeneours temperature throughout bed
                % Toth parameter
                fTothParameter_b = this.fb0 * exp((this.fQ_ads / (this.fRe*this.fT0)) * (this.fT0/fTemperature - 1));
                % Calculate equilibrium value for CO2
                fQ_equ_CO2 = (fTothParameter_b * mfPP_i(strcmp('CO2',csNames),:) * this.fns) ./ ((1+(fTothParameter_b*mfPP_i(strcmp('CO2',csNames),:)).^this.ft)).^(1/this.ft);
            end            
            
            % Assign equilibrium values
            mfQ_equ(strcmp('CO2',csNames),:) = fQ_equ_CO2;  % [mol/kg]
            mfQ_equ(strcmp('H2O',csNames),:) = fQ_equ_H2O;  % [mol/kg]
            
            % Equilibrium loadings of substances
            mfQ_equ = mfQ_equ * fRhoSorbent;     % [mol/m^3]
        end
               
    end
end

