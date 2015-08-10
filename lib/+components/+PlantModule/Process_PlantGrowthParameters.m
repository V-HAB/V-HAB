
function [ aoPlants, INEDIBLE_CGR_d_out, INEDIBLE_CGR_f_out, ED_CGR_d_out, ED_CGR_f_out, O2_exchange, CO2_exchange, water_exchange, WaterNeed, O2_sum_out, CO2_sum_out, H2O_trans_sum_out, H2O_consum_sum_out] = ...
    Process_PlantGrowthParameters(aoPlants, fTime, WaterAvailable, p_atm, RH_day, RH_night, PPF, CO2, CO2_Measured, H , Temp_light, Temp_dark)

% Short description.
%  This function processes the gained plant growth rates  (--> "Calculate_PlantGrowthRates").
%  Time-based values are transformed and finally provided for further
%  computation.



   %growth condition
    WaterNeed           = 0;    % [kg/s]
   %biomass components
    INEDIBLE_CGR_d_out  = 0;    % [kg]
    INEDIBLE_CGR_f_out  = 0;    % [kg]
    ED_CGR_d_out        = 0;    % [kg]
    ED_CGR_f_out        = 0;    % [kg]




%Growth starts, when emerge time (PlantEng setup) of considered culture is
%reached... (or if emerge_time == 0 in setup --> start from 5 minutes on)
    if fTime >= aoPlants.state.emerge_time      &&      fTime > 5       % [min]
        
        if aoPlants.state.internalGeneration <= aoPlants.state.AmountOfConsecutiveGenerations
        
          %Calculating growth until harvest time
            if aoPlants.state.internaltime < aoPlants.state.harv_time   % [min]
            
 
                %Internaltime: internal time of every culture, from planting till harvesting - for each entry in 'PlantEng' setup
                % (starts from 0; when harvested, it will be reseted for the
                % following generation, by inceasing the internal generation when harvesting)
                    if aoPlants.state.emerge_time ~= 0    
                        aoPlants.state.time_since_planting = fTime - (aoPlants.state.internalGeneration - 1) * aoPlants.state.harv_time - aoPlants.state.emerge_time;   % [min]
                    else
                        aoPlants.state.time_since_planting = fTime - (aoPlants.state.internalGeneration - 1) * aoPlants.state.harv_time - 5;                            % [min]
                    end
                %Internaltime
                    aoPlants.state.internaltime = aoPlants.state.time_since_planting;  %[min]

            %If CO2 ppm level is in allowed range
                if CO2_Measured > 350 && CO2_Measured < 1400       % [µmol/mol]


                    
                % tA:time after emergence [UOT]
                    tA = [1/CO2 1 CO2 CO2^2 CO2^3] * aoPlants.plant.matrix_tA * [1/PPF; 1; PPF; PPF^2; PPF^3] * aoPlants.FactorDaysToMinutes;   % [min]

                      

                %Call of function for determining the plant growth- and exchange rates,
                % necessary for and arising with growth of the plants

                        % -Output parameters-
                        [aoPlants,                      ...     % State of cultures - array of object
                         HOP_net,                       ...     % Hourly net oxygen production          [g/m^2/h]
                         HCC_net,                       ...     % Hourly net carbon consumption         [g/m^2/h]
                         HCGR,                          ...     % Hourly net crop growth rate           [g/m^2/h]
                         HTR,                           ...     % Hourly transpiration rate             [g/m^2/h]
                         HWC]                           ...     % Hourly water consumption              [g/m^2/h]
                            = components.PlantModule.Calculate_PlantGrowthRates( ...  % Path to function
                        ... % -Input Parameters-
                            aoPlants,                   ...         % State of cultures (assigned to "aoPlants" herein)
                            aoPlants.state.internaltime,...         % Internal time of growth cycle         [min]
                            tA,                         ...         % Time of canopy closure                [min]
                            aoPlants.plant.tQ,          ...         % Time at onset of canopy senescence    [min]
                            aoPlants.plant.tM_nominal,  ...         % Time at harvest                       [min]
                            PPF,                        ...         % Photosynthetic photon flux            [µmol/m^2/s]
                            CO2,                        ...         % CO2 level                             [µmol/mol]
                            RH_day,                     ...         % Relative humidity day                 [-]
                            RH_night,                   ...         % Relative humidity night               [-]
                            p_atm,                      ...         % Pressure                              [Pa]
                            H,                          ...         % Photoperiod per day                   [h/d]
                            Temp_light,                 ...         % Mean air temperature                  [°C]
                            Temp_dark);                             % Mean air temperature                  [°C]



                % Fresh basis water factor (FBWF) 
                    % - HCGR is the DRY biomass uptake. So with this factor the fluid uptake is estimated
                    %  From plant parameters: FBWF = WBF/(1-WBF),  % [kg_fluid/kg_dry]  (WBF =  water biomass fraction)
                    %  -This fractions are valid for calculating EDIBLE biomass fluid uptake

                    switch aoPlants.plant.name
                        case 'Drybean'
                            FBWF_ed = 1/9;      % [kg_fluid/kg_dry]
                        case 'Lettuce'
                            FBWF_ed = 95/5;     % [kg_fluid/kg_dry]
                        case 'Peanut' 
                            FBWF_ed = 5.6/94.4; % [kg_fluid/kg_dry]
                        case 'Rice'
                            FBWF_ed = 12/88;    % [kg_fluid/kg_dry]
                        case 'Soybean'
                            FBWF_ed = 10/90;    % [kg_fluid/kg_dry]
                        case 'Sweetpotato'
                            FBWF_ed = 71/29;    % [kg_fluid/kg_dry]
                        case 'Tomato'
                            FBWF_ed = 94/6;     % [kg_fluid/kg_dry]
                        case 'Wheat'
                            FBWF_ed = 12/88;    % [kg_fluid/kg_dry]
                        case 'Whitepotato'
                            FBWF_ed = 80/20;    % [kg_fluid/kg_dry]
                    end
                    
                    %  -Inedible biomass water content (WBF) is always assumed to be 90%
                    %   (Source: Baseline values and assumptions document (BVAD). Table 4.98)
                    %   -> so the FBWF factor for INEDIBLE fluid biomass would be 90%/10% = 9                            
                       
                            FBWF_ined = 90/10;  % [kg_fluid/kg_dry]
                        
                        
                        
                        

                % water_exchange: water vapor transpired from the plant
                    aoPlants.state.water_exchange = HTR * aoPlants.FactorHourlyRatesToSeconds * aoPlants.state.extension / 1000; % [kg/s]
                    %--> Sums Up ("Integrates" value) with every call of function
                    %Water Summation Transpiration
                    aoPlants.H2O_trans_sum_out = aoPlants.H2O_trans_sum_out + aoPlants.state.water_exchange * 60; % [kg]




                 %WaterNeed --> HWC [kg/m^2/d]
                    WaterNeed = HWC * aoPlants.FactorHourlyRatesToSeconds * aoPlants.state.extension / 1000;  %[kg/s]

                    %Water Comsumption [kg] - Summation
                     aoPlants.H2O_consum_sum_out = aoPlants.H2O_consum_sum_out + WaterNeed * 60; % [kg]


                     
                 %As long as water is available, conduct growth calculations
                    if (WaterAvailable > WaterNeed) && aoPlants.state.t_without_H2O <= aoPlants.FactorDaysToMinutes

                      % If internaltime of considered culture's growth cycle
                      % exceeds tE (time at onset of edible biomass)
                        if aoPlants.state.internaltime > aoPlants.plant.tE   % [min]

                            %--> Sums Up ("Integrates" value) with every call of function
                            %"plant_model"
                                aoPlants.state.TCB = aoPlants.state.TCB + HCGR/60 * aoPlants.state.extension / 1000 + FBWF_ined * (HCGR - aoPlants.plant.XFRT * HCGR) / 60 * aoPlants.state.extension / 1000 + FBWF_ed * aoPlants.plant.XFRT * HCGR / 60 *aoPlants.state.extension / 1000; % [kg]


                            %--> Sums Up ("Integrates" value) with every call of function
                            % TEB: total edible biomass; dry mass + water mass    
                                aoPlants.state.TEB = aoPlants.state.TEB + aoPlants.plant.XFRT*HCGR*aoPlants.state.extension / 60 / 1000 + FBWF_ed * aoPlants.plant.XFRT * HCGR * aoPlants.state.extension / 60 / 1000; %[kg]

                            % Mass balance of biomass uptake when exceeding tE
                                aoPlants.ED_CGR_d       =   aoPlants.ED_CGR_d + aoPlants.plant.XFRT * HCGR * aoPlants.state.extension / 60 / 1000;                              % [kg]
                                aoPlants.ED_CGR_f       =   aoPlants.ED_CGR_f + FBWF_ed * aoPlants.plant.XFRT * HCGR * aoPlants.state.extension / 60 / 1000;                    % [kg]
                                aoPlants.INEDIBLE_CGR_d =   aoPlants.INEDIBLE_CGR_d + (HCGR - (aoPlants.plant.XFRT * HCGR)) * aoPlants.state.extension / 60 / 1000;             % [kg]
                                aoPlants.INEDIBLE_CGR_f =   aoPlants.INEDIBLE_CGR_f + FBWF_ined * (HCGR - (aoPlants.plant.XFRT * HCGR)) * aoPlants.state.extension / 60 / 1000; % [kg]
                      
                      % If tE is not exceeded yet, only inedible biomass is created 
                      % (and therefore contributes to the total crop biomass (TCB) solely)
                        else
                            % TCB: total crop biomass, dry mass + water mass - For every call of this function
                            % "Process_PlantGrowthParameters", a specific amount of kg will be added to
                            % "TCB"-value from the last call of it.   
                                aoPlants.state.TCB = aoPlants.state.TCB + HCGR * aoPlants.state.extension / 60 / 1000 + FBWF_ined * HCGR * aoPlants.state.extension / 60 / 1000;   % [kg]
                            % TEB: total edible biomass; before tE no edible biomass
                            % produced
                                aoPlants.state.TEB = aoPlants.state.TEB; % [kg]


                            % Mass balance of biomass uptake before tE
                                aoPlants.ED_CGR_d       = 0;                                                                                    % [kg]
                                aoPlants.ED_CGR_f       = 0;                                                                                    % [kg]
                                aoPlants.INEDIBLE_CGR_d = aoPlants.INEDIBLE_CGR_d + HCGR * aoPlants.state.extension / 60 / 1000;                % [kg]
                                aoPlants.INEDIBLE_CGR_f = aoPlants.INEDIBLE_CGR_f + FBWF_ined *(HCGR * aoPlants.state.extension / 60 / 1000);   % [kg]  
                        end


                        %Evaluation with TCB summated separately
                            aoPlants.state.TCB_CGR_test = aoPlants.ED_CGR_d + aoPlants.ED_CGR_f + aoPlants.INEDIBLE_CGR_d + aoPlants.INEDIBLE_CGR_f; % [kg]


                    % O2_exchange: O2 provided to the environment [kg/s]
                        %M(O2)= 32 g/mol                        Zeitteiler d -> s     g/mol 
                            aoPlants.state.O2_exchange = HOP_net * aoPlants.FactorHourlyRatesToSeconds * aoPlants.state.extension / 1000;  %[kg/s]
                        %                                                 Massenteiler g -> kg                                                             
                        %--> Sums Up ("Integrates" value) with every call of function
                        %O2 Summation
                            aoPlants.O2_sum_out = aoPlants.O2_sum_out + aoPlants.state.O2_exchange * 60; % [kg]

                    % CO2_exchange: CO2 subtracted to the environment [kg/s] 
                        %CO2_assimiliation_fct is set in PlantReactor
                        %M(CO2)= 44 g/mol                                           Zeitteiler             d -> s        g/mol 
                            aoPlants.state.CO2_exchange = HCC_net * aoPlants.FactorHourlyRatesToSeconds * aoPlants.state.extension / 1000;  %[kg/s]
                        %                                                          Massenteiler                   g -> kg
                        %--> Sums Up ("Integrates" value) with every call of function
                        %CO2 Summation
                            aoPlants.CO2_sum_out = aoPlants.CO2_sum_out + aoPlants.state.CO2_exchange * 60; % [kg]

                    else % Not enough water available - Needs to be reworked!
                        % Attempt has been to reduce the growth and
                        %  exchange rates slowely by water deficiency 
                        
                        disp('Not Enough Water');

                        aoPlants.state.t_without_H2O = aoPlants.state.t_without_H2O + 1;
                        if  aoPlants.state.t_without_H2O == 1
                            aoPlants.state.TCB_constant = aoPlants.state.TCB; % [kg]
                            aoPlants.state.TEB_constant = aoPlants.state.TEB; % [kg]
                        end
                        if aoPlants.state.t_without_H2O <= 4 * aoPlants.FactorDaysToMinutes;
                            Without_H2O_fct     = 1 - (aoPlants.state.t_without_H2O / (aoPlants.FactorDaysToMinutes * 4));
                            if WaterAvailable - (WaterNeed * Without_H2O_fct) <=0
                                Without_H2O_fct = 0;
                            end
                        else
                            Without_H2O_fct = 0;
                        end
                            WaterNeed                       = WaterNeed * Without_H2O_fct;                      % [kg/s]
                            aoPlants.state.A                = aoPlants.state.A * Without_H2O_fct;               % [min]
                            aoPlants.state.CUE_24           = aoPlants.state.CUE_24 * Without_H2O_fct;          % [-]
                            aoPlants.state.TCB              = aoPlants.state.TCB_constant + (HCGR * Without_H2O_fct * aoPlants.state.extension / 60); % [kg]
                            aoPlants.state.TEB              = aoPlants.state.TEB_constant + (HCGR * Without_H2O_fct * aoPlants.state.extension / 60); % [kg]
                            aoPlants.state.O2_exchange      = aoPlants.state.O2_exchange * Without_H2O_fct;     % [kg/s]
                            aoPlants.state.CO2_exchange     = aoPlants.state.CO2_exchange * Without_H2O_fct;    % [kg/s]
                            aoPlants.state.water_exchange   = aoPlants.state.water_exchange * Without_H2O_fct;  % [kg/s]
                            aoPlants.state.P_net            = aoPlants.state.P_net * Without_H2O_fct;           % [µmol_carbon/m^2/s]
                            aoPlants.state.CQY              = aoPlants.state.CQY * Without_H2O_fct;             % [mumol Carbon Fixed/mumol Absorbed PPF]
                    end

              %If allowed CO2 ppm range is exceeded
                else

                    if CO2_Measured > 1400
                         disp('Warning: CO2ppm > 1400 /n');
                        aoPlants.state.O2_exchange      = 0;    % [kg/s]
                        aoPlants.state.CO2_exchange     = 0;    % [kg/s]
                        aoPlants.state.water_exchange   = 0;    % [kg/s]
                    end

                    if CO2_Measured < 350
                       disp('Warning: CO2ppm < 350 /n');
                        aoPlants.state.O2_exchange      = 0;    % [kg/s]
                        aoPlants.state.CO2_exchange     = 0;    % [kg/s]
                        aoPlants.state.water_exchange   = 0;    % [kg/s]
                    end
                end
           
           %At harvest time reached...
            else

                   disp('Harvesting:'); 
                     %reset growth handling parameters
                    aoPlants.state.A                = 0;    % [min]
                    aoPlants.state.CUE_24           = 0;    % [-]
                    aoPlants.state.TCB              = 0;    % [kg]
                    aoPlants.state.TEB              = 0;    % [kg]
                    aoPlants.state.O2_exchange      = 0;    % [kg/s]
                    aoPlants.state.CO2_exchange     = 0;    % [kg/s]
                    aoPlants.state.water_exchange   = 0;    % [kg/s]
                    aoPlants.state.internaltime     = 0;    % [min]
                    aoPlants.state.P_net            = 0;    % [µmol_carbon/m^2/s]
                    aoPlants.state.CQY              = 0;    % [mumol Carbon Fixed/mumol Absorbed PPF]
                    aoPlants.state.t_without_H2O    = 0;    % [-]

                
                
                    INEDIBLE_CGR_d_out  = aoPlants.INEDIBLE_CGR_d;  % [kg]
                    INEDIBLE_CGR_f_out  = aoPlants.INEDIBLE_CGR_f;  % [kg]
                    ED_CGR_d_out        = aoPlants.ED_CGR_d;        % [kg]
                    ED_CGR_f_out        = aoPlants.ED_CGR_f;        % [kg]
                
                %Displaying harvest information
                    disp(['Culture name: ' num2str(aoPlants.state.plant_name) '  -  Culture number: ' num2str(aoPlants.state.CultureNumber)] );
                    disp([' The cultures internal generation: ' num2str(aoPlants.state.internalGeneration)]);
                    disp(['   Inedible dry biomass harvested: ' num2str(INEDIBLE_CGR_d_out)]);
                    disp(['   Inedible fluid biomass harvested: ' num2str(INEDIBLE_CGR_f_out)]);
                    disp(['   Edible dry biomass harvested: ' num2str(ED_CGR_d_out)]);
                    disp(['   Edible fluid biomass harvested: ' num2str(ED_CGR_f_out)]);
                
                    %reset for next growth cycle
                    aoPlants.INEDIBLE_CGR_d     = 0; % [kg]
                    aoPlants.INEDIBLE_CGR_f     = 0; % [kg]
                    aoPlants.ED_CGR_d           = 0; % [kg] 
                    aoPlants.ED_CGR_f           = 0; % [kg]

                    %set internal generation to the following one (+1)
                        aoPlants.state.internalGeneration = aoPlants.state.internalGeneration + 1; % [-]

            end
            
        end
        
    end


    
   %gas exchanges
    O2_exchange     = aoPlants.state.O2_exchange;      %[kg/s]
    CO2_exchange    = aoPlants.state.CO2_exchange;     %[kg/s]
    water_exchange  = aoPlants.state.water_exchange;   %[kg/s]




% ######################################################
% %CO2 CORRELATION (PLEASE SET CORRELATION FACTORS IN plant_equation to 1 to)
% %Source: BA Mecsaci 2010
% %%%Currently set to 1 - no correlation conducted therefore!
%     if 1
%         CORR_CO2_fct = [1  1  1  1  1  1  1  1  1];
% 
%         CO2_exchange = aoPlants.state.CO2_exchange*CORR_CO2_fct(aoPlants.state.plant_type);  %[kg/s]
%     else
%         CO2_exchange = aoPlants.state.CO2_exchange; %[kg/s]
%     end
% ########################################################


    

    
%Summation of total (net) exchanges
    O2_sum_out          = aoPlants.O2_sum_out;              % [kg]
    CO2_sum_out         = aoPlants.CO2_sum_out;             % [kg]
    H2O_trans_sum_out   = aoPlants.H2O_trans_sum_out;       % [kg]
    H2O_consum_sum_out  = aoPlants.H2O_consum_sum_out;      % [kg]