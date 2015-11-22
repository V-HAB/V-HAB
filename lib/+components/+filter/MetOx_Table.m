classdef MetOx_Table < handle
    
    properties  
      fFrequencyFactor   = 1.9e+10;     % Preexponantional Faktor [??]  
      fActivationEnergy  = 13.3 * 4184; % Activation Energy [J]
      R_m                = 8.3145;      % Universal gas constant [J/(mol*K)]
      fLogistic_1        = 5;           % First Logistic Factor of Coupling Function [-]  
      fLogistic_2        = 50;          % Second Logistic Factor of Coupling Function Absproption [-]      
      mrLoad_saved       = 0;           % matrix that saves the current loading ratio for ['H2O' 'CO2']
      fCO2Capacity       = 0.851;       % Maximum Absorbable Amount of Carbon Dioxide [-]
      fH2OCapacity       = 0.18;        % Maximum Absorbable Amount of Water [-]
      mfAbsorbed;                       
      
      % logical operator to initialize the matix for the loading ratio
      iOnce = 1;
      
    end
        
    
    methods
        
        function [D_L] = get_AxialDispersion_D_L(varargin)
            % dispersion coefficient
            D_L = 0;          % [m^2/s]   
        end
        
        function [mfC_new] = calculate_C_new(this, mfC_in, dt, fTemperature, csNames, fVolSolid, x_length, afMolMass)
            
            % initialize once with the right size
            if this.iOnce == 1
                this.mrLoad_saved = zeros(2,length(mfC_in(2,:,1)));
                this.mfAbsorbed = zeros(2,length(mfC_in(1,:,1)));
                this.iOnce = 2;
            end
            
            mrLoad = ones(size(mfC_in));
            if find(strcmp('H2O', csNames) == 1)
                mrLoad(strcmp('H2O', csNames), :) = this.mrLoad_saved(1,:); % line 1 for H2O
            end
            if find(strcmp('CO2', csNames) == 1)
                mrLoad(strcmp('CO2', csNames), :) = this.mrLoad_saved(2,:); % line 2 for CO2
            end
            
            % Important values for chemical kinetics
            %    The frequency factor and the activation energy  was
            %    taken from Drake et al. (1926).
            mfReactionRateConstant = zeros(size(mfC_in));
            fReactionRateConstant = this.fFrequencyFactor * exp(-this.fActivationEnergy / this.R_m / fTemperature);
            
            % Absorption of CO2
            % Logistic function for coupling
            if find(strcmp('H2O', csNames) == 1)
                mfReactionRateConstant(strcmp('H2O', csNames), :) = fReactionRateConstant;
                rCoupling = 1 ./ (1 + this.fLogistic_1 * exp(-this.fLogistic_2 * mrLoad(strcmp('H2O', csNames) == 1,:)));     % CO2 absorption depends on H2O loading
                fReactionRateConstantEff = fReactionRateConstant * rCoupling;
            else
                fReactionRateConstantEff = fReactionRateConstant;
            end
            if find(strcmp('CO2', csNames) == 1)
                mfReactionRateConstant(strcmp('CO2', csNames), :) = fReactionRateConstantEff;
            end
            
            % Calculation of concentration ratio (concentration out to
            % concentration in) after (Filbum and Cusick, 1992)
            mrConcentrationRatio = exp(-mfReactionRateConstant .* (1-mrLoad) * dt);
            
            % Calculate return value
            mfC_new = mrConcentrationRatio .* mfC_in; 
            
            % Save the loading ratio
            fVol_element = fVolSolid / (x_length-2);
            if find(strcmp('H2O', csNames) == 1)
                this.mfAbsorbed(1,:) = this.mfAbsorbed(1,:) + ...
                    (mfC_in(strcmp('H2O', csNames), :) - mfC_new(strcmp('H2O', csNames), :)) * fVol_element * afMolMass(strcmp('H2O', csNames)) / 1000;
            end
            if find(strcmp('CO2', csNames) == 1)
                this.mfAbsorbed(2,:) = this.mfAbsorbed(2,:) + ...
                    (mfC_in(strcmp('CO2', csNames), :)-mfC_new(strcmp('CO2', csNames), :)) * fVol_element * afMolMass(strcmp('CO2', csNames)) / 1000;
            end
            this.mrLoad_saved(1,:) = this.mfAbsorbed(1,:) / (this.fH2OCapacity / (x_length-2));
            this.mrLoad_saved(2,:) = this.mfAbsorbed(2,:) / (this.fCO2Capacity / (x_length-2));
            
        end
        
        % Pressure drop across filter bed
        function [fDeltaP] = calculate_dp(~)
            % Pressure Drop of METOX 
            fPressureDrop      = 0.785;     % [inH2O]
            fConv_inH2O_Pa     = 248.84;    % Conversion from inH2O to Pa
            fDeltaP = fPressureDrop * fConv_inH2O_Pa; %[Pa]
        end

    end   
end