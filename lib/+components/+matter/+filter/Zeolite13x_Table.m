% Constants from "Additional Developments in Atmosphere Revitalization 
% Modeling and Simulation" 
% p in [Pa], q in [mol/kg], T in [K]

classdef Zeolite13x_Table < handle
    
    properties  
        

        % String containing Names of substances in the feed flow  
        csNames; 
        
         % Constants
        mfToth_table;
        afMolMass;                                          % molar masses of substances in thefeed flow (matching with csNames) [g/mol]
        fUnivGasConst_R = 8.314;                            % universal gas constant [J/(mol*K)]         
        fR_pellet = 1.1*10^-3;                             % pellet radius [m]
        fPelletPorosity = 0.4;                              % pellet porosity [-]
        afD_collision = [2.8, 3.7979, 3.7412, 3.4822];      % collision diameter of [H2O,CO2,N2,O2] in [Angstrom] (molecular diffusion)     
        afLJPotential = [250,223.675,88.9525,103.6955];     % Lennard-Jones potential minima of [H2O,CO2,N2,O2] in [K] (molecular diffusion)
        fR_macropore = 0;                                   % average macropore radius [m]
        fMacroporeTurt_tau = 1;                             % macropore tortuosity [-]
        
        % For MODULATION and VALIDATION:
        % Enter manual values for the constants or leave nan to
        % calculate the values according to theoretical assumptions
        % BUT: Take care of a correct assignment (size, different substances, ... )        
        D_L = nan;         % packed bed axial dispersion Fick's constant [m^2/s]
        k_f = nan;         % fluid film diffusion rate constant [m/s]
        D_p = nan;         % macropore diffusion Fick's constant [m^2/s]
        D_c = nan;         % micropore diffusion Fick's constant [m^2/s]
        k_l = [0.0007, 0, 0, 0];         % LDF model kinetic lumped constant in order (H2O, CO2, N2, O2) [1/s]
        K   = nan;         % linear(ized) isotherm constant [-]
        
    end
        
    
    methods
        function this = Zeolite13x_Table()         
            % Initialize the toth istotherm constants
            % Values taken from: 'Additional Developments in Atmosphere
            % Revitalization Modeling and Simulation' (ICES, 2013)     
                                    %q_si	%b_0i       %Bi     %m_0i   m_Ti
            this.mfToth_table = [   15.0622 2.4100E-07  6852.0  0.390  -4.20        %H2O
                                    5.7117  1.0170E-08  5810.2  0.555  -64.65       %CO2
                                    2.2500  6.9467E-07  2219.9  1.000  0.00         %N2
                                    3.9452  1.0754E-06  1683.1  5.200  -1216.33  ]; %O2
            % Conversion from [1/kPa] to [1/Pa]
            this.mfToth_table(:,2) = this.mfToth_table(:,2)./1000;    
        end
        
        % Linear(ized) isotherm constant
        % Ok took me a while to get through this... So the thermodynamic
        % constant is normally NOT CONSTANT... It is only constant for one
        % time step and then the toth equation is used to calculate the new
        % value for each time step 
        function [K] = get_ThermodynConst_K(this, afC_in, fTemperature, fRhoSorbent, csNames, afMolMass)
            if isnan(this.K) == 0
                K = zeros(size(afC_in));
                for iVari = 1:length (this.K)
                K(iVari, :) = this.K(iVari);
                end
                return;
            end
            % Kind of confusing since the normal toth equation could just
            % be used to calculate the equilibrium loading without all this
            % pseudo constant criss cross conversion. The way it is
            % currently implemented it is very confusing since the constant
            % is not constant and the equlibrium loading is not calculated
            % with the Toth equation...
            K = this.calculate_q_equ(afC_in, fTemperature, fRhoSorbent, csNames, afMolMass) ./ afC_in;        % linearized adsorption equilibrium isotherm slope [-]
            K(isnan(K)|K<0) = 0;
        end
        
        % Equilibrium loading of adsorbent 
        function [q_equ] = calculate_q_equ(this, afC_in, fTemperature, fRhoSorbent, csNames, ~)
            % Build correct Toth table
            mToth_table = zeros(length(this.csNames),5);
            if find(strcmp('H2O', csNames) == 1)
                mToth_table(strcmp('H2O', csNames),:) = this.mfToth_table(1,:);
            end
            if find(strcmp('CO2', csNames) == 1)
                mToth_table(strcmp('CO2', csNames),:) = this.mfToth_table(2,:);
            end
            if find(strcmp('N2', csNames) == 1)
                mToth_table(strcmp('N2', csNames),:) = this.mfToth_table(3,:);
            end
            if find(strcmp('O2', csNames) == 1)
                mToth_table(strcmp('O2', csNames),:) = this.mfToth_table(4,:);
            end
            
            % partial pressures of species
            p_i = afC_in*this.fUnivGasConst_R*fTemperature;   % [Pa]
            
            if(size(fTemperature)==1)  % homogeneours temperature throughout bed
                b = mToth_table(:,2).*exp(mToth_table(:,3)/fTemperature);
                m = mToth_table(:,4) + mToth_table(:,5)/fTemperature;
            else    % temperature varies along length of bed
                b = repmat(mToth_table(:,2),1,size(fTemperature,2)).*exp(repmat(mToth_table(:,3),1,size(fTemperature,2))./repmat(fTemperature,length(csNames),1));
                m = repmat(mToth_table(:,4),1,size(fTemperature,2)) + repmat(mToth_table(:,5),1,size(fTemperature,2))./repmat(fTemperature,length(csNames),1);
            end
            q = mToth_table(:,1);
            summe = sum(repmat(b,1,size(p_i,2)).*p_i,1);
            
            q_equ = zeros(size(p_i));
            for iVar_2 = 1:length(csNames)
                q_equ(iVar_2,:) = b(iVar_2)*p_i(iVar_2,:)*q(iVar_2) ./ ((1+summe.^m(iVar_2)).^(1/m(iVar_2)));
            end
            
            % equilibrium loadings of species in adsorbent
            q_equ = q_equ*fRhoSorbent;     % [mol/m^3]
        end
        % Axial dispersion Fick's coefficient according to Edwards & Richardson
        function [D_L] = get_AxialDispersion_D_L(this, fFluidVelocity, fTemperature, fPressure, afC_in, csNames, afMolMass)     
            if ~isnan(this.D_L)
                D_L = this.D_L; return; 
            end                
            this.csNames = csNames;
            this.afMolMass = afMolMass; 
            
            omega_ij = this.calculate_collision_integral(fTemperature);
            D_m = this.calculate_D_m(fTemperature,fPressure,afC_in,omega_ij);            
            D_L = 0.73*D_m + this.fR_pellet.*fFluidVelocity./(1+4.85*D_m./fFluidVelocity./this.fR_pellet); %axial diffusivity coefficient for [H2O,CO2,N2,O2] [m^2/s]
        end   
        
        % Lumped LDF coefficient according to Glueckauf / Ruthven
        function [k_l] = get_KineticConst_k_l(this, K, fTemperature, fPressure, fDensityFlow, afC_in, fRhoSorbent, fVolumetricFlowRate, e_b, csNames, afMolMass)
            
            this.afMolMass = afMolMass;
            this.csNames = csNames;
            
            % Check for manually set values
            if ~isnan(this.k_l)
                % Initialize
                k_l = zeros(size(K));
                % Assign correct values
                % Etend if other substances shall be adsorped 
                k_l(strcmp('H2O',csNames), :) = this.k_l(1);
                k_l(strcmp('CO2',csNames), :) = this.k_l(2);
                k_l(strcmp('N2',csNames), :) = this.k_l(3);
                k_l(strcmp('O2',csNames), :) = this.k_l(4);
                return;
            end
            
            mu = this.calculate_mu(fTemperature);                                % average fluid dynamic viscosity [Pa s]
            omega_ij = this.calculate_collision_integral(fTemperature);          % collision integrals of species i vs. species j [-]
            D_m = this.calculate_D_m(fTemperature, fPressure, afC_in, omega_ij); % average molecular diffusion Fick's law coefficient of fluid [m^2/s]
            D_k = this.calculate_D_k(fTemperature,afC_in);                       % average Knudsen diffusion Fick's law coefficient [m^2/s]
            D_s = this.calculate_D_s(fTemperature);                              % average Surface diffusion Fick's law coefficient [m^2/s]
            K_avg = this.get_ThermodynConst_K(afC_in',fTemperature,fRhoSorbent, csNames, afMolMass);          % linearized isotherm constant of all species [-]
            
            k_f = this.calculate_k_f(fVolumetricFlowRate,fDensityFlow,e_b,D_m,mu);      % average fluid film diffusion LDF coefficient [1/s]
            D_p = this.calculate_D_p(K_avg,D_m,D_k,D_s,afC_in');                        % average macropore diffusion Fick's law coefficient [m^2/s]
            D_c = this.calculate_D_c(fTemperature);                                     % average micropore diffusion Fick's law coefficient [m^2/s]
            
            % microcrystal radius
            R_c = 30*10^-6;     % [m]
            k_l = 1./((K*this.fR_pellet/3/k_f)+(K*this.fR_pellet^2/13/this.fPelletPorosity./D_p)+(R_c^2/15/D_c));
            k_l(isnan(k_l)|k_l<0) = 0;            
        end
        
        % Cynamic viscosity according to Sutherland
        function fmu = calculate_mu(~,fTemperature)            
            fT_0 = 291.15;                           % Sutherland constant for standard air [K]
            fSutherlConst = 120;                     % Sutherland constant for standard air [K]
            fmu_0 = 18.27*10^-6;                     % Sutherland constant for standard air [Pa*s]
            fmu = fmu_0*(fT_0 + fSutherlConst)./(fTemperature + fSutherlConst).*(fTemperature/fT_0).^1.5;            
        end
        
        
        % Collision integral according to Poling (helper function for axial dispersion coefficient)
        function [omega_ij] = calculate_collision_integral(this, fTemperature)
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
            e_ij = fTemperature./sqrt(e_i'*e_i);     
            % collision integrals of [H2O,CO2,N2,O2] vs N2 [-]
            omega_ij = 0.42541 + (0.82133 - 6.8314*10^-2./e_ij)./e_ij + 0.2668*exp(-0.012733*e_ij);            
        end
        
        % Molceular diffusion Fick's coefficient according to Ruthven
        function [D_m] = calculate_D_m(this, fTemperature, fPressure, afC_in, omega_ij)
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
            
            v_ij = 0.5*(repmat(v_i,length(v_i),1)+repmat(v_i,length(v_i),1)');                      %average collision diameter of species i in species j [Angstrom]
            M_ij = repmat(1./this.afMolMass,length(this.afMolMass),1)+repmat(1./this.afMolMass,length(this.afMolMass),1)';          %helper variable
            D_ij = 10^-4*98.665*1.86*(M_ij).^0.5*fTemperature^1.5./(fPressure*v_ij.^2.*omega_ij);   %molecular diffusivity of component i in component j (Chapman-Enskog-Theory)[m^2/s]
            y_i = afC_in/sum(afC_in);                                                               %mole fraction of component i in fluid [-]
            if(sum(y_i==0) == length(this.csNames)-1)                                                     %only one component (other formula yields nans)
                D_im = y_i.*diag(D_ij)';                                                      %molecular diffusivity coefficient of species i in mixture [m^2/s]
            else
                D_im = (1-y_i)./(sum(repmat(y_i,length(this.csNames),1)./D_ij,2)'-(y_i./diag(D_ij)'));
            end
            D_im(isnan(D_im)) = 0;
            D_im(isinf(D_im)) = 2.9e-3;
            D_m = sum(y_i.*D_im);                                                                   %average molecular diffusivity coefficient of fluid [m^2/s]
        end
        
        % Knudsen diffusion Fick's law coefficient according to Ruthven
        function [D_k] = calculate_D_k(this,fTemperature,afC_in)
            % Knudsen diffusion Fick's law coefficient
            D_k = 970000*this.fR_macropore*(repmat(fTemperature,size(afC_in,2),1).*repmat(this.afMolMass'.^-1,1,size(fTemperature,2))).^0.5;   % [cm^2/s]
            D_k = sum(D_k.*repmat(afC_in',1,size(fTemperature,2)),1)/sum(afC_in) * 10^-4;   % [m^2/s]
        end
        
        % Macroporous surface diffusion Fick's coefficient according to Ruthven (Eyring
        % equation)
        function [D_s] = calculate_D_s(this,fTemperature)
            fD_s_inf = 6.95*10^-7;           % macropore diffusion Eyring equation preexponential factor [m^2/s]
            fE_s_act = 18241;                % macropore diffusion Eyring equation activation Energy [J]
            D_s = fD_s_inf*exp(-fE_s_act/this.fUnivGasConst_R./fTemperature);
        end
        
        % Film diffusion LDF constant according to Wakao & Funazkri
        function [k_f] = calculate_k_f(this,fVolumetricFlowRate,fDensityFlow,e_b,D_m,mu)
            if isnan(this.k_f) == 0
                k_f = this.k_f; return;
            end
            k_f = D_m./this.fR_pellet + 0.55*(mu./fDensityFlow).^(-4/15).*D_m.^(2/3).*this.fR_pellet.^(-0.4).*(2*fVolumetricFlowRate.*e_b).^0.6;
        end

        
        % Macroporous diffusion Fick's coefficient according to Ruthven
        function [D_p] = calculate_D_p(this,K_avg,D_m,D_k,D_s,afC_in)
            if isnan(this.D_p) == 0
                D_p = this.D_p; return;
            end
            D_p = 1./(1./D_m + 1./(D_k + (1-this.fPelletPorosity)/this.fPelletPorosity*K_avg*D_s))*1./this.fMacroporeTurt_tau;                          %molecular + knudsen + surface diffusion
            D_p = sum(afC_in.*D_p)/sum(afC_in);
        end
        
        % Microporous diffusion Fick's coefficient according to Ruthven (Eyring
        % equation)
        function [D_c] = calculate_D_c(this,fTemperature)
            if isnan(this.D_c) == 0
                D_c = this.D_c; return;
            end
            % micropore diffusion Eyring equation preexponential factor
            D_c_inf = 5.9*10^-11;           % [m^2/s]
            % micropore diffusion Eyring equation activation Energy
            E_c_act = 12552;                % [J]
            D_c = D_c_inf*exp(-E_c_act/this.fUnivGasConst_R./fTemperature);
        end
        
        
        % Pressure drop across packed bed according to Ergun
        function [fDeltaP] = calculate_dp(this,fLength,fFluidVelocity,e_b,fTemperature,fDensityFlow)
            % Dynamic viscosity
            fmu = this.calculate_mu(fTemperature); 
            % Pressure drop across the filter bed [Pa]
            fDeltaP = 150*(1-e_b)^2/e_b^2*fmu*fLength*fFluidVelocity/(2*this.fR_pellet)^2 + 1.75*fDensityFlow*fFluidVelocity^2*fLength/(2*this.fR_pellet)*(1-e_b)/e_b;   
        end
        
        function [] = plotIsotherm(this,p,T) 
            q_equ = this.calculate_q_equ(p,T);
            figure();
            plot(p(2,:),q_equ(1,:),'b'); hold on;
            plot(p(2,:),q_equ(2,:),'r'); hold on;
            plot(p(2,:),q_equ(3,:),'g'); hold on;
            plot(p(2,:),q_equ(4,:),'m'); hold on;
        end
       
    end
end

